# frozen_string_literal: true

require_relative '../../test_helper'

class UtilityToolsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :trackers, :issue_statuses, :enumerations

  def setup
    @user = User.find(2)
    @project = Project.find(1)

    User.current = @user
    stub_plugin_settings
  end

  # ========== list_trackers Tests ==========

  test 'list_trackers returns all trackers' do
    result = RedmineMcp::Tools::Utility::ListTrackers.execute({}, @user)

    assert_equal false, result[:isError]
    trackers = JSON.parse(result[:content].first[:text])

    assert trackers.is_a?(Array)
    assert trackers.any?
    assert trackers.first.key?('id')
    assert trackers.first.key?('name')
  end

  # ========== list_statuses Tests ==========

  test 'list_statuses returns all issue statuses' do
    result = RedmineMcp::Tools::Utility::ListStatuses.execute({}, @user)

    assert_equal false, result[:isError]
    statuses = JSON.parse(result[:content].first[:text])

    assert statuses.is_a?(Array)
    assert statuses.any?
    assert statuses.first.key?('id')
    assert statuses.first.key?('name')
    assert statuses.first.key?('is_closed')
  end

  # ========== list_priorities Tests ==========

  test 'list_priorities returns all issue priorities' do
    result = RedmineMcp::Tools::Utility::ListPriorities.execute({}, @user)

    assert_equal false, result[:isError]
    priorities = JSON.parse(result[:content].first[:text])

    assert priorities.is_a?(Array)
    assert priorities.any?
    assert priorities.first.key?('id')
    assert priorities.first.key?('name')
  end

  # ========== list_activities Tests ==========

  test 'list_activities returns system activities without project' do
    result = RedmineMcp::Tools::Utility::ListActivities.execute({}, @user)

    assert_equal false, result[:isError]
    activities = JSON.parse(result[:content].first[:text])

    assert activities.is_a?(Array)
    # Should only include active system-wide activities
    assert activities.all? { |a| a['active'] == true } if activities.any?
  end

  test 'list_activities returns project-specific activities' do
    result = RedmineMcp::Tools::Utility::ListActivities.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    activities = JSON.parse(result[:content].first[:text])

    assert activities.is_a?(Array)
    # Should include activities available for the project
  end

  # ========== list_versions Tests ==========

  test 'list_versions returns project versions' do
    result = RedmineMcp::Tools::Utility::ListVersions.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    assert_equal false, result[:isError]
    versions = JSON.parse(result[:content].first[:text])

    assert versions.is_a?(Array)
    # May be empty if project has no versions
  end

  test 'list_versions filters by status' do
    # Create a version
    version = Version.create!(
      project: @project,
      name: "Test Version #{rand(10000)}",
      status: 'open'
    )

    result = RedmineMcp::Tools::Utility::ListVersions.execute(
      {
        'project_id' => @project.identifier,
        'status' => 'open'
      },
      @user
    )

    versions = JSON.parse(result[:content].first[:text])
    assert versions.all? { |v| v['status'] == 'open' } if versions.any?
  end

  test 'list_versions raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Utility::ListVersions.execute({ 'project_id' => 'invalid' }, @user)
    end
  end

  # ========== list_categories Tests ==========

  test 'list_categories returns project categories' do
    result = RedmineMcp::Tools::Utility::ListCategories.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    assert_equal false, result[:isError]
    categories = JSON.parse(result[:content].first[:text])

    assert categories.is_a?(Array)
    # May be empty if project has no categories
  end

  test 'list_categories raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Utility::ListCategories.execute({ 'project_id' => 'invalid' }, @user)
    end
  end
end
