# frozen_string_literal: true

# MCP Plugin Routes
#
# Endpoints:
#   GET  /mcp        - SSE stream for server-initiated events
#   POST /mcp        - JSON-RPC message handling
#   GET  /mcp/health - Health check for load balancers (no auth)
#
# Note: defaults: { format: :json } is required for Redmine's API key
# authentication to work correctly. The SSE endpoint overrides the
# Content-Type to text/event-stream in the controller.
#
RedmineApp::Application.routes.draw do
  scope module: 'redmine_mcp' do
    get  'mcp',        to: 'mcp#sse',     defaults: { format: :json }
    post 'mcp',        to: 'mcp#message', defaults: { format: :json }
    get  'mcp/health', to: 'mcp#health',  defaults: { format: :json }
  end
end
