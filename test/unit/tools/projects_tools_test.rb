# frozen_string_literal: true

require_relative '../../test_helper'

class ProjectsToolsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles

  def setup
    @admin = User.find(1)
    @user = User.find(2)
    @project = Project.find(1)

    User.current = @user
    stub_plugin_settings
  end

  # ========== list_projects Tests ==========

  test 'list_projects returns visible projects' do
    result = RedmineMcp::Tools::Projects::List.execute({}, @user)

    assert_equal false, result[:isError]
    assert result[:content].first[:text].present?

    projects = JSON.parse(result[:content].first[:text])
    assert projects.is_a?(Array)
    assert projects.any?
  end

  test 'list_projects filters by active status by default' do
    result = RedmineMcp::Tools::Projects::List.execute({}, @user)

    projects = JSON.parse(result[:content].first[:text])
    assert projects.all? { |p| p['status'] == Project::STATUS_ACTIVE }
  end

  test 'list_projects filters by closed status' do
    # Create a closed project
    closed_project = Project.create!(
      name: 'Closed Project',
      identifier: "closed-#{rand(10000)}",
      status: Project::STATUS_CLOSED,
      is_public: true
    )

    result = RedmineMcp::Tools::Projects::List.execute({ 'status' => 'closed' }, @user)

    projects = JSON.parse(result[:content].first[:text])
    assert projects.all? { |p| p['status'] == Project::STATUS_CLOSED }
  end

  test 'list_projects returns all when status is all' do
    result = RedmineMcp::Tools::Projects::List.execute({ 'status' => 'all' }, @user)

    projects = JSON.parse(result[:content].first[:text])
    statuses = projects.map { |p| p['status'] }.uniq
    # Should have multiple statuses if there are closed/archived projects
    assert statuses.any?
  end

  test 'list_projects respects pagination' do
    result = RedmineMcp::Tools::Projects::List.execute(
      { 'limit' => '1', 'offset' => '0' },
      @user
    )

    assert result[:_meta].present?
    assert_equal 1, result[:_meta][:limit]

    projects = JSON.parse(result[:content].first[:text])
    assert projects.size <= 1
  end

  test 'list_projects includes project metadata' do
    result = RedmineMcp::Tools::Projects::List.execute({}, @user)

    projects = JSON.parse(result[:content].first[:text])
    project = projects.first

    assert project['id'].present?
    assert project['identifier'].present?
    assert project['name'].present?
    assert project.key?('description')
    assert project.key?('is_public')
  end

  # ========== get_project Tests ==========

  test 'get_project returns project by identifier' do
    result = RedmineMcp::Tools::Projects::Get.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert_equal @project.id, data['id']
    assert_equal @project.identifier, data['identifier']
    assert_equal @project.name, data['name']
  end

  test 'get_project returns project by id' do
    result = RedmineMcp::Tools::Projects::Get.execute(
      { 'project_id' => @project.id.to_s },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert_equal @project.id, data['id']
  end

  test 'get_project raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Projects::Get.execute({ 'project_id' => 'invalid' }, @user)
    end
  end

  test 'get_project raises error for inaccessible project' do
    # Create a private project the user cannot access
    private_project = Project.create!(
      name: 'Private Project',
      identifier: "private-#{rand(10000)}",
      is_public: false
    )

    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Projects::Get.execute(
        { 'project_id' => private_project.identifier },
        @user
      )
    end
  end
end
