# frozen_string_literal: true

module RedmineMcp
  # Main MCP controller handling SSE connections and JSON-RPC messages.
  #
  # Endpoints:
  #   GET  /mcp        - SSE stream for server-initiated events
  #   POST /mcp        - JSON-RPC message handling
  #   GET  /mcp/health - Health check for load balancers
  #
  class McpController < ApplicationController
    include ActionController::Live

    # Skip CSRF for API endpoints
    skip_before_action :verify_authenticity_token

    # Enable API key authentication
    accept_api_auth :sse, :message

    # POST /mcp - Handle JSON-RPC messages
    def message
      # Auth check with JSON-RPC error response
      if User.current.anonymous?
        Rails.logger.warn '[MCP] Rejected anonymous request'
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: { code: -32600, message: 'Authentication required' }
        }, status: :unauthorized
      end

      unless mcp_enabled?
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: { code: -32600, message: 'MCP plugin disabled' }
        }, status: :service_unavailable
      end

      # Payload size check (1MB limit)
      if request.content_length.to_i > 1.megabyte
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: { code: -32600, message: 'Payload too large (max 1MB)' }
        }, status: :payload_too_large
      end

      # Parse JSON first (before rate limiting to avoid counting bad requests)
      begin
        payload = JSON.parse(request.body.read)
      rescue JSON::ParserError => e
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: { code: -32700, message: "Parse error: #{e.message}" }
        }
      end

      # Rate limiting (counts each request in batch)
      request_count = payload.is_a?(Array) ? payload.size : 1
      rate_limit = [mcp_settings['rate_limit'].to_i, 1].max
      RedmineMcp::RateLimiter.check!(User.current.id, count: request_count, limit: rate_limit)

      # Synchronous tool execution with timeout
      request_timeout = [mcp_settings['request_timeout'].to_i, 5].max
      Timeout.timeout(request_timeout) do
        Rails.logger.info "[MCP] Processing request from user #{User.current.id}"
        response_payload = RedmineMcp::JsonRpc.handle(payload, User.current)
        render json: response_payload
      end
    rescue RedmineMcp::RateLimitExceeded
      Rails.logger.warn "[MCP] Rate limit exceeded for user #{User.current.id}"
      render json: {
        jsonrpc: '2.0', id: nil,
        error: { code: -32000, message: "Rate limit exceeded (#{mcp_settings['rate_limit']}/min)" }
      }, status: :too_many_requests
    rescue Timeout::Error
      Rails.logger.error "[MCP] Request timeout for user #{User.current.id}"
      render json: {
        jsonrpc: '2.0', id: nil,
        error: { code: -32001, message: "Request timeout (#{mcp_settings['request_timeout']}s limit)" }
      }, status: :gateway_timeout
    end

    # GET /mcp - SSE stream for server-initiated events
    def sse
      # Auth check
      if User.current.anonymous?
        Rails.logger.warn '[MCP] Rejected anonymous SSE connection'
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: { code: -32600, message: 'Authentication required' }
        }, status: :unauthorized
      end

      unless mcp_enabled?
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: { code: -32600, message: 'MCP plugin disabled' }
        }, status: :service_unavailable
      end

      # Connection limit check
      unless RedmineMcp::SseConnectionTracker.acquire(User.current.id)
        return render json: {
          jsonrpc: '2.0', id: nil,
          error: {
            code: -32000,
            message: "Too many SSE connections (max #{RedmineMcp::SseConnectionTracker::MAX_CONNECTIONS_PER_USER} per user)"
          }
        }, status: :too_many_requests
      end

      Rails.logger.info "[MCP] SSE connection opened for user #{User.current.id}"

      # Set SSE headers
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
      response.headers['X-Accel-Buffering'] = 'no' # Nginx buffering off
      response.headers['Last-Modified'] = Time.now.httpdate # Prevent caching

      sse_writer = RedmineMcp::SSE.new(response.stream)
      heartbeat_interval = [mcp_settings['heartbeat_interval'].to_i, 1].max
      sse_timeout = [mcp_settings['sse_timeout'].to_i, 60].max
      deadline = Time.now + sse_timeout

      begin
        loop do
          break if Time.now > deadline

          sse_writer.write(Time.now.to_i.to_s, event: 'ping')
          sleep heartbeat_interval
        end
        Rails.logger.info "[MCP] SSE connection timed out for user #{User.current.id}"
      rescue IOError, ActionController::Live::ClientDisconnected
        Rails.logger.info "[MCP] SSE client disconnected: user #{User.current.id}"
      ensure
        sse_writer.close
        RedmineMcp::SseConnectionTracker.release(User.current.id)
      end
    end

    # GET /mcp/health - Health check for load balancers (no auth required)
    def health
      if mcp_enabled?
        render json: {
          status: 'ok',
          version: RedmineMcp::JsonRpc::SERVER_VERSION,
          redmine_version: Redmine::VERSION.to_s,
          registry: RedmineMcp::Registry.stats
        }
      else
        render json: { status: 'disabled' }, status: :service_unavailable
      end
    end

    private

    def mcp_settings
      @mcp_settings ||= Setting.plugin_redmine_mcp || {}
    end

    def mcp_enabled?
      mcp_settings['enabled'] == '1'
    end
  end
end
