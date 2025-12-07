# frozen_string_literal: true

require_relative '../../test_helper'

class TimeEntriesToolsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues, :trackers,
           :time_entries, :enumerations, :enabled_modules

  def setup
    @user = User.find(2)
    @project = Project.find(1)
    @issue = Issue.find(1)

    @role = Role.find_by(name: 'Manager') || Role.create!(name: 'Manager',
      permissions: [:view_time_entries, :log_time])
    Member.create!(user: @user, project: @project, roles: [@role]) unless @user.member_of?(@project)

    # Enable time tracking module
    @project.enabled_modules << EnabledModule.new(name: 'time_tracking') unless @project.module_enabled?(:time_tracking)

    User.current = @user
    stub_plugin_settings
  end

  # ========== list_time_entries Tests ==========

  test 'list_time_entries returns visible entries' do
    result = RedmineMcp::Tools::TimeEntries::List.execute({}, @user)

    assert_equal false, result[:isError]
    entries = JSON.parse(result[:content].first[:text])
    assert entries.is_a?(Array)
  end

  test 'list_time_entries filters by project' do
    result = RedmineMcp::Tools::TimeEntries::List.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    entries = JSON.parse(result[:content].first[:text])
    assert entries.all? { |e| e['project']['id'] == @project.id } if entries.any?
  end

  test 'list_time_entries filters by issue' do
    result = RedmineMcp::Tools::TimeEntries::List.execute(
      { 'issue_id' => @issue.id.to_s },
      @user
    )

    entries = JSON.parse(result[:content].first[:text])
    assert entries.all? { |e| e['issue'] && e['issue']['id'] == @issue.id } if entries.any?
  end

  test 'list_time_entries respects pagination' do
    result = RedmineMcp::Tools::TimeEntries::List.execute(
      { 'limit' => '1' },
      @user
    )

    assert result[:_meta].present?
    entries = JSON.parse(result[:content].first[:text])
    assert entries.size <= 1
  end

  # ========== get_time_entry Tests ==========

  test 'get_time_entry returns entry details' do
    entry = TimeEntry.visible(@user).first
    skip 'No time entries available' unless entry

    result = RedmineMcp::Tools::TimeEntries::Get.execute(
      { 'time_entry_id' => entry.id },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert_equal entry.id, data['id']
    assert data['hours'].present?
    assert data['activity'].present?
  end

  test 'get_time_entry raises error for invalid entry' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::TimeEntries::Get.execute({ 'time_entry_id' => 999999 }, @user)
    end
  end

  # ========== log_time Tests ==========

  test 'log_time creates time entry for issue' do
    stub_plugin_settings('enable_write_operations' => '1')
    activity = TimeEntryActivity.first

    result = RedmineMcp::Tools::TimeEntries::Log.execute(
      {
        'issue_id' => @issue.id.to_s,
        'hours' => '2.5',
        'activity_id' => activity.id.to_s,
        'comments' => 'Test time log'
      },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert data['id'].present?
    assert_equal 2.5, data['hours']

    # Verify entry was created
    entry = TimeEntry.find(data['id'])
    assert_equal 2.5, entry.hours
    assert_equal 'Test time log', entry.comments
  end

  test 'log_time creates time entry for project' do
    stub_plugin_settings('enable_write_operations' => '1')
    activity = TimeEntryActivity.first

    result = RedmineMcp::Tools::TimeEntries::Log.execute(
      {
        'project_id' => @project.identifier,
        'hours' => '1.0',
        'activity_id' => activity.id.to_s
      },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert_equal 1.0, data['hours']
  end

  test 'log_time fails when write operations disabled' do
    stub_plugin_settings('enable_write_operations' => '0')

    assert_raises RedmineMcp::WriteOperationsDisabled do
      RedmineMcp::Tools::TimeEntries::Log.execute(
        {
          'issue_id' => @issue.id.to_s,
          'hours' => '1.0',
          'activity_id' => TimeEntryActivity.first.id.to_s
        },
        @user
      )
    end
  end

  test 'log_time requires hours parameter' do
    stub_plugin_settings('enable_write_operations' => '1')

    result = RedmineMcp::Tools::TimeEntries::Log.execute(
      {
        'issue_id' => @issue.id.to_s,
        'activity_id' => TimeEntryActivity.first.id.to_s
      },
      @user
    )

    assert_equal true, result[:isError]
  end

  test 'log_time fails when module disabled' do
    stub_plugin_settings('enable_write_operations' => '1')
    @project.enabled_modules.where(name: 'time_tracking').destroy_all

    assert_raises RedmineMcp::PermissionDenied do
      RedmineMcp::Tools::TimeEntries::Log.execute(
        {
          'project_id' => @project.identifier,
          'hours' => '1.0',
          'activity_id' => TimeEntryActivity.first.id.to_s
        },
        @user
      )
    end
  end
end
