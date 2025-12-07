# frozen_string_literal: true

require_relative '../test_helper'

class McpControllerTest < ActionDispatch::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles, :issues

  def setup
    @user = User.find(2)
    @project = Project.find(1)

    stub_plugin_settings
    clear_rate_limiter

    # Generate API key for user if not present
    unless @user.api_token
      @user.generate_api_token
      @user.save!
    end
  end

  # ========== Authentication Tests ==========

  test 'message endpoint rejects anonymous requests' do
    post '/mcp', params: { method: 'ping', id: 1 }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert json['error'].present?
    assert_match(/authentication required/i, json['error']['message'])
  end

  test 'message endpoint accepts API key authentication' do
    post '/mcp', params: { method: 'ping', id: 1 }.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal '2.0', json['jsonrpc']
  end

  # ========== Message Endpoint Tests ==========

  test 'message endpoint processes initialize request' do
    post '/mcp', params: { method: 'initialize', id: 1 }.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json['id']
    assert json['result'].present?
    assert json['result']['serverInfo'].present?
    assert_equal 'redmine-mcp', json['result']['serverInfo']['name']
  end

  test 'message endpoint processes tools/list request' do
    post '/mcp', params: { method: 'tools/list', id: 1 }.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :success
    json = JSON.parse(response.body)

    assert json['result']['tools'].is_a?(Array)
    assert json['result']['tools'].any?
  end

  test 'message endpoint processes tools/call request' do
    post '/mcp', params: {
      method: 'tools/call',
      id: 1,
      params: {
        name: 'list_projects',
        arguments: {}
      }
    }.to_json, headers: {
      'Content-Type' => 'application/json',
      'X-Redmine-API-Key' => @user.api_token
    }

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal false, json['result']['isError']
  end

  test 'message endpoint handles batch requests' do
    batch = [
      { method: 'ping', id: 1 },
      { method: 'tools/list', id: 2 }
    ]

    post '/mcp', params: batch.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :success
    json = JSON.parse(response.body)

    assert json.is_a?(Array)
    assert_equal 2, json.size
  end

  # ========== Rate Limiting Tests ==========

  test 'message endpoint enforces rate limiting' do
    stub_plugin_settings('rate_limit' => '5')

    # Make 5 successful requests
    5.times do |i|
      post '/mcp', params: { method: 'ping', id: i }.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'X-Redmine-API-Key' => @user.api_token
           }

      assert_response :success
    end

    # 6th request should be rate limited
    post '/mcp', params: { method: 'ping', id: 6 }.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert_match(/rate limit/i, json['error']['message'])
  end

  # ========== Payload Size Tests ==========

  test 'message endpoint rejects oversized payloads' do
    # Create a payload larger than 1MB
    large_payload = { method: 'ping', id: 1, data: 'x' * (1024 * 1024 + 1) }

    post '/mcp', params: large_payload.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :payload_too_large
  end

  # ========== Plugin Disabled Tests ==========

  test 'message endpoint returns 503 when plugin disabled' do
    stub_plugin_settings('enabled' => '0')

    post '/mcp', params: { method: 'ping', id: 1 }.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    assert_response :service_unavailable
    json = JSON.parse(response.body)
    assert_match(/plugin disabled/i, json['error']['message'])
  end

  # ========== Health Check Tests ==========

  test 'health endpoint returns ok when enabled' do
    stub_plugin_settings('enabled' => '1')

    get '/mcp/health'

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 'ok', json['status']
    assert json['version'].present?
    assert json['redmine_version'].present?
  end

  test 'health endpoint returns disabled when plugin disabled' do
    stub_plugin_settings('enabled' => '0')

    get '/mcp/health'

    assert_response :service_unavailable
    json = JSON.parse(response.body)
    assert_equal 'disabled', json['status']
  end

  test 'health endpoint does not require authentication' do
    get '/mcp/health'

    # Should respond (success or unavailable depending on settings)
    # but should NOT return unauthorized
    assert_not_equal :unauthorized, response.status
  end

  # ========== SSE Endpoint Tests (Mock-based) ==========

  test 'sse endpoint rejects anonymous requests' do
    get '/mcp'

    assert_response :unauthorized
  end

  test 'sse endpoint returns 503 when plugin disabled' do
    stub_plugin_settings('enabled' => '0')

    get '/mcp', headers: { 'X-Redmine-API-Key' => @user.api_token }

    assert_response :service_unavailable
  end

  # Note: Full SSE testing requires ActionController::Live support
  # which is complex to test in integration tests. The spec calls for
  # "SSE Testing: Use mocks with StringIO, don't test network layer"
  # See test_helper.rb for mock_sse_stream and parse_sse_events helpers

  # ========== Error Handling Tests ==========

  test 'message endpoint returns JSON-RPC error for invalid JSON' do
    post '/mcp', params: 'invalid json',
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    json = JSON.parse(response.body)
    assert json['error'].present?
    assert_equal -32700, json['error']['code']
  end

  test 'message endpoint handles unknown methods gracefully' do
    post '/mcp', params: { method: 'unknown_method', id: 1 }.to_json,
         headers: {
           'Content-Type' => 'application/json',
           'X-Redmine-API-Key' => @user.api_token
         }

    json = JSON.parse(response.body)
    assert json['error'].present?
    assert_equal -32601, json['error']['code']
  end
end
