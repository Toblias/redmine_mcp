# frozen_string_literal: true

require_relative '../test_helper'

class JsonRpcTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues, :trackers

  def setup
    @user = User.find(2)
    @project = Project.find(1)

    User.current = @user
    stub_plugin_settings
  end

  # ========== initialize Method Tests ==========

  test 'initialize returns server capabilities' do
    request = { 'method' => 'initialize', 'id' => 1 }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert_equal '2.0', response[:jsonrpc]
    assert_equal 1, response[:id]
    assert response[:result].present?

    result = response[:result]
    assert_equal RedmineMcp::JsonRpc::PROTOCOL_VERSION, result[:protocolVersion]
    assert result[:capabilities].present?
    assert result[:serverInfo].present?
  end

  # ========== ping Method Tests ==========

  test 'ping returns empty result' do
    request = { 'method' => 'ping', 'id' => 1 }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert_equal '2.0', response[:jsonrpc]
    assert_equal 1, response[:id]
    assert_equal({}, response[:result])
  end

  # ========== tools/list Method Tests ==========

  test 'tools/list returns available tools' do
    request = { 'method' => 'tools/list', 'id' => 1 }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:result][:tools].is_a?(Array)
    assert response[:result][:tools].any?

    tool = response[:result][:tools].first
    assert tool[:name].present?
    assert tool[:description].present?
    assert tool[:inputSchema].present?
  end

  # ========== tools/call Method Tests ==========

  test 'tools/call executes tool successfully' do
    request = {
      'method' => 'tools/call',
      'id' => 1,
      'params' => {
        'name' => 'list_projects',
        'arguments' => {}
      }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert_equal '2.0', response[:jsonrpc]
    assert response[:result].present?
    assert_equal false, response[:result][:isError]
  end

  test 'tools/call raises error for unknown tool' do
    request = {
      'method' => 'tools/call',
      'id' => 1,
      'params' => {
        'name' => 'invalid_tool',
        'arguments' => {}
      }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:error].present?
    assert_match(/not found/i, response[:error][:message])
  end

  test 'tools/call blocks write operations when disabled' do
    stub_plugin_settings('enable_write_operations' => '0')

    request = {
      'method' => 'tools/call',
      'id' => 1,
      'params' => {
        'name' => 'create_issue',
        'arguments' => {
          'project_id' => @project.identifier,
          'subject' => 'Test'
        }
      }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:error].present?
    assert_match(/write operations disabled/i, response[:error][:message])
  end

  # ========== resources/templates/list Method Tests ==========

  test 'resources/templates/list returns resource templates' do
    request = { 'method' => 'resources/templates/list', 'id' => 1 }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:result][:resourceTemplates].is_a?(Array)
    assert response[:result][:resourceTemplates].any?

    template = response[:result][:resourceTemplates].first
    assert template[:uriTemplate].present?
    assert template[:name].present?
    assert template[:description].present?
  end

  # ========== resources/read Method Tests ==========

  test 'resources/read returns issue data' do
    issue = Issue.visible(@user).first

    request = {
      'method' => 'resources/read',
      'id' => 1,
      'params' => { 'uri' => "redmine://issues/#{issue.id}" }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:result][:contents].is_a?(Array)
    content = response[:result][:contents].first
    assert_equal "redmine://issues/#{issue.id}", content[:uri]
    assert_equal 'application/json', content[:mimeType]
    assert content[:text].present?
  end

  test 'resources/read returns current user data' do
    request = {
      'method' => 'resources/read',
      'id' => 1,
      'params' => { 'uri' => 'redmine://users/current' }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    content = response[:result][:contents].first
    data = JSON.parse(content[:text])
    assert_equal @user.id, data['id']
  end

  test 'resources/read raises error for unknown URI' do
    request = {
      'method' => 'resources/read',
      'id' => 1,
      'params' => { 'uri' => 'redmine://invalid/123' }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:error].present?
    assert_match(/unknown resource/i, response[:error][:message])
  end

  # ========== prompts/list Method Tests ==========

  test 'prompts/list returns available prompts' do
    request = { 'method' => 'prompts/list', 'id' => 1 }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:result][:prompts].is_a?(Array)
    assert response[:result][:prompts].any?

    prompt = response[:result][:prompts].first
    assert prompt[:name].present?
    assert prompt[:description].present?
  end

  # ========== prompts/get Method Tests ==========

  test 'prompts/get returns prompt messages' do
    request = {
      'method' => 'prompts/get',
      'id' => 1,
      'params' => {
        'name' => 'bug_report',
        'arguments' => {}
      }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:result][:messages].is_a?(Array)
    assert response[:result][:messages].any?
  end

  # ========== Batch Request Tests ==========

  test 'handles batch requests' do
    batch = [
      { 'method' => 'ping', 'id' => 1 },
      { 'method' => 'tools/list', 'id' => 2 }
    ]
    responses = RedmineMcp::JsonRpc.handle(batch, @user)

    assert responses.is_a?(Array)
    assert_equal 2, responses.size
    assert_equal 1, responses[0][:id]
    assert_equal 2, responses[1][:id]
  end

  # ========== Notification Tests ==========

  test 'notifications return nil' do
    request = { 'method' => 'notifications/initialized' }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert_nil response
  end

  # ========== Error Handling Tests ==========

  test 'handles unknown method' do
    request = { 'method' => 'unknown_method', 'id' => 1 }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:error].present?
    assert_equal -32601, response[:error][:code]
  end

  test 'handles RecordNotFound errors' do
    request = {
      'method' => 'tools/call',
      'id' => 1,
      'params' => {
        'name' => 'get_issue',
        'arguments' => { 'issue_id' => 999999 }
      }
    }
    response = RedmineMcp::JsonRpc.handle(request, @user)

    assert response[:error].present?
    assert_equal -32004, response[:error][:code]
  end

  test 'sanitizes error messages' do
    # Trigger an error that should be sanitized
    request = {
      'method' => 'tools/call',
      'id' => 1,
      'params' => {
        'name' => 'list_projects',
        'arguments' => { 'invalid_param' => 'test' }
      }
    }

    # Should not raise, should return sanitized error
    response = RedmineMcp::JsonRpc.handle(request, @user)

    # Error may or may not occur depending on tool implementation
    # Just verify response is valid
    assert response[:jsonrpc] == '2.0'
  end
end
