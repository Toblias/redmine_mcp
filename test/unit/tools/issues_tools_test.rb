# frozen_string_literal: true

require_relative '../../test_helper'

class IssuesToolsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues, :issue_statuses,
           :trackers, :enumerations, :enabled_modules

  def setup
    @admin = User.find(1)
    @user = User.find(2)
    @project = Project.find(1)

    # Ensure issue tracking module is enabled
    @project.enable_module!(:issue_tracking) unless @project.module_enabled?(:issue_tracking)

    # Ensure user has proper roles with add_issues permission
    @role = Role.find_by(name: 'Manager')
    if @role
      # Ensure the role has add_issues permission
      @role.add_permission!(:add_issues) unless @role.has_permission?(:add_issues)
      @role.add_permission!(:view_issues) unless @role.has_permission?(:view_issues)
      @role.add_permission!(:edit_issues) unless @role.has_permission?(:edit_issues)
    else
      @role = Role.create!(name: 'Manager', permissions: [:view_issues, :add_issues, :edit_issues])
    end

    # Ensure user is member of project with proper role
    member = Member.find_by(user: @user, project: @project)
    if member
      member.roles << @role unless member.roles.include?(@role)
    else
      Member.create!(user: @user, project: @project, roles: [@role])
    end

    User.current = @user
    stub_plugin_settings
  end

  # ========== list_issues Tests ==========

  test 'list_issues returns visible issues' do
    result = RedmineMcp::Tools::Issues::List.execute({}, @user)

    assert_equal false, result[:isError]
    assert result[:content].first[:text].present?

    issues = JSON.parse(result[:content].first[:text])
    assert issues.is_a?(Array)
    assert issues.any?
  end

  test 'list_issues filters by project' do
    result = RedmineMcp::Tools::Issues::List.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    assert_equal false, result[:isError]
    issues = JSON.parse(result[:content].first[:text])
    assert issues.all? { |i| i['project']['id'] == @project.id }
  end

  test 'list_issues filters by status open' do
    result = RedmineMcp::Tools::Issues::List.execute({ 'status' => 'open' }, @user)

    assert_equal false, result[:isError]
    issues = JSON.parse(result[:content].first[:text])
    assert issues.all? { |i| !IssueStatus.find(i['status']['id']).is_closed }
  end

  test 'list_issues filters by status closed' do
    result = RedmineMcp::Tools::Issues::List.execute({ 'status' => 'closed' }, @user)

    issues = JSON.parse(result[:content].first[:text])
    # All returned issues should have closed status
    issues.each do |i|
      assert IssueStatus.find(i['status']['id']).is_closed
    end if issues.any?
  end

  test 'list_issues respects pagination' do
    result = RedmineMcp::Tools::Issues::List.execute(
      { 'limit' => '2', 'offset' => '0' },
      @user
    )

    assert_equal false, result[:isError]
    assert result[:_meta].present?
    assert_equal 2, result[:_meta][:limit]

    issues = JSON.parse(result[:content].first[:text])
    assert issues.size <= 2
  end

  test 'list_issues sorts by created_on desc' do
    result = RedmineMcp::Tools::Issues::List.execute(
      { 'sort' => 'created_on:desc' },
      @user
    )

    issues = JSON.parse(result[:content].first[:text])
    if issues.size > 1
      dates = issues.map { |i| Time.parse(i['created_on']) }
      assert_equal dates.sort.reverse, dates
    end
  end

  test 'list_issues raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Issues::List.execute({ 'project_id' => 'invalid' }, @user)
    end
  end

  # ========== get_issue Tests ==========

  test 'get_issue returns issue details' do
    issue = Issue.visible(@user).first
    result = RedmineMcp::Tools::Issues::Get.execute({ 'issue_id' => issue.id }, @user)

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert_equal issue.id, data['id']
    assert_equal issue.subject, data['subject']
    assert data['project'].present?
    assert data['tracker'].present?
  end

  test 'get_issue includes journals when requested' do
    issue = Issue.visible(@user).first
    result = RedmineMcp::Tools::Issues::Get.execute(
      { 'issue_id' => issue.id, 'include' => 'journals' },
      @user
    )

    data = JSON.parse(result[:content].first[:text])
    assert data.key?('journals')
  end

  test 'get_issue includes attachments when requested' do
    issue = Issue.visible(@user).first
    result = RedmineMcp::Tools::Issues::Get.execute(
      { 'issue_id' => issue.id, 'include' => 'attachments' },
      @user
    )

    data = JSON.parse(result[:content].first[:text])
    assert data.key?('attachments')
  end

  test 'get_issue raises error for invalid issue' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Issues::Get.execute({ 'issue_id' => 999999 }, @user)
    end
  end

  # ========== create_issue Tests ==========

  test 'create_issue creates new issue' do
    stub_plugin_settings('enable_write_operations' => '1')

    result = RedmineMcp::Tools::Issues::Create.execute(
      {
        'project_id' => @project.identifier,
        'subject' => 'Test issue from MCP',
        'description' => 'Test description'
      },
      @user
    )

    assert_equal false, result[:isError], "Error: #{result[:content]&.first&.dig(:text)}"
    data = JSON.parse(result[:content].first[:text])

    assert data['id'].present?
    assert_equal 'Test issue from MCP', data['subject']

    # Verify issue was actually created
    issue = Issue.find(data['id'])
    assert_equal 'Test issue from MCP', issue.subject
  end

  test 'create_issue fails when write operations disabled' do
    stub_plugin_settings('enable_write_operations' => '0')

    assert_raises RedmineMcp::WriteOperationsDisabled do
      RedmineMcp::Tools::Issues::Create.execute(
        {
          'project_id' => @project.identifier,
          'subject' => 'Test'
        },
        @user
      )
    end
  end

  test 'create_issue returns validation errors' do
    stub_plugin_settings('enable_write_operations' => '1')

    result = RedmineMcp::Tools::Issues::Create.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    assert_equal true, result[:isError]
    assert_match(/subject/i, result[:content].first[:text])
  end

  test 'create_issue raises error for invalid project' do
    stub_plugin_settings('enable_write_operations' => '1')

    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Issues::Create.execute(
        { 'project_id' => 'invalid', 'subject' => 'Test' },
        @user
      )
    end
  end

  # ========== update_issue Tests ==========

  test 'update_issue updates existing issue' do
    stub_plugin_settings('enable_write_operations' => '1')
    issue = Issue.visible(@user).where(project: @project).first

    result = RedmineMcp::Tools::Issues::Update.execute(
      {
        'issue_id' => issue.id,
        'subject' => 'Updated subject',
        'notes' => 'Updated via MCP'
      },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert_equal 'Updated subject', data['subject']

    # Verify update
    issue.reload
    assert_equal 'Updated subject', issue.subject
    assert issue.journals.any? { |j| j.notes.include?('Updated via MCP') }
  end

  test 'update_issue fails when write operations disabled' do
    stub_plugin_settings('enable_write_operations' => '0')
    issue = Issue.visible(@user).first

    assert_raises RedmineMcp::WriteOperationsDisabled do
      RedmineMcp::Tools::Issues::Update.execute(
        { 'issue_id' => issue.id, 'subject' => 'Test' },
        @user
      )
    end
  end

  test 'update_issue raises error for invalid issue' do
    stub_plugin_settings('enable_write_operations' => '1')

    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Issues::Update.execute(
        { 'issue_id' => 999999, 'subject' => 'Test' },
        @user
      )
    end
  end

  # ========== search_issues Tests ==========

  test 'search_issues finds issues by subject' do
    # Create a test issue with unique subject
    stub_plugin_settings('enable_write_operations' => '1')
    unique_subject = "SearchTest#{rand(100000)}"

    # Use first status (typically the default) or the one with lowest position
    default_status = IssueStatus.order(:position).first || IssueStatus.first

    issue = Issue.create!(
      project: @project,
      tracker: @project.trackers.first,
      author: @user,
      subject: unique_subject,
      status: default_status
    )

    result = RedmineMcp::Tools::Issues::Search.execute(
      { 'query' => unique_subject },
      @user
    )

    assert_equal false, result[:isError]
    issues = JSON.parse(result[:content].first[:text])
    assert issues.any? { |i| i['subject'].include?(unique_subject) }
  end

  test 'search_issues scopes to project when specified' do
    result = RedmineMcp::Tools::Issues::Search.execute(
      { 'query' => 'issue', 'project_id' => @project.identifier },
      @user
    )

    issues = JSON.parse(result[:content].first[:text])
    assert issues.all? { |i| i['project']['id'] == @project.id } if issues.any?
  end
end
