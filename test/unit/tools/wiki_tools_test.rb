# frozen_string_literal: true

require_relative '../../test_helper'

class WikiToolsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :wikis, :wiki_pages, :wiki_contents

  def setup
    @user = User.find(2)
    @project = Project.find(1)

    @role = Role.find_by(name: 'Manager') || Role.create!(name: 'Manager',
      permissions: [:view_wiki_pages, :edit_wiki_pages])
    Member.create!(user: @user, project: @project, roles: [@role]) unless @user.member_of?(@project)

    # Enable wiki module
    @project.enabled_modules << EnabledModule.new(name: 'wiki') unless @project.module_enabled?(:wiki)

    # Ensure project has a wiki
    @project.wiki ||= Wiki.create!(project: @project, start_page: 'Wiki')

    User.current = @user
    stub_plugin_settings
  end

  # ========== list_wiki_pages Tests ==========

  test 'list_wiki_pages returns pages for project' do
    result = RedmineMcp::Tools::Wiki::List.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    assert_equal false, result[:isError]
    pages = JSON.parse(result[:content].first[:text])
    assert pages.is_a?(Array)
  end

  test 'list_wiki_pages raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Wiki::List.execute({ 'project_id' => 'invalid' }, @user)
    end
  end

  test 'list_wiki_pages fails when module disabled' do
    @project.enabled_modules.where(name: 'wiki').destroy_all

    assert_raises RedmineMcp::PermissionDenied do
      RedmineMcp::Tools::Wiki::List.execute({ 'project_id' => @project.identifier }, @user)
    end
  end

  # ========== get_wiki_page Tests ==========

  test 'get_wiki_page returns page content' do
    # Create a wiki page
    page = create_wiki_page(@project, title: 'TestPage', text: 'Test content')

    result = RedmineMcp::Tools::Wiki::Get.execute(
      {
        'project_id' => @project.identifier,
        'page_title' => 'TestPage'
      },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert_equal 'TestPage', data['title']
    assert_equal 'Test content', data['content']
  end

  test 'get_wiki_page raises error for non-existent page' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Wiki::Get.execute(
        {
          'project_id' => @project.identifier,
          'page_title' => 'NonExistentPage'
        },
        @user
      )
    end
  end

  test 'get_wiki_page fails when module disabled' do
    @project.enabled_modules.where(name: 'wiki').destroy_all

    assert_raises RedmineMcp::PermissionDenied do
      RedmineMcp::Tools::Wiki::Get.execute(
        {
          'project_id' => @project.identifier,
          'page_title' => 'Wiki'
        },
        @user
      )
    end
  end

  # ========== update_wiki_page Tests ==========

  test 'update_wiki_page updates existing page' do
    stub_plugin_settings('enable_write_operations' => '1')
    page = create_wiki_page(@project, title: 'UpdateTest', text: 'Original content')

    result = RedmineMcp::Tools::Wiki::Update.execute(
      {
        'project_id' => @project.identifier,
        'page_title' => 'UpdateTest',
        'content' => 'Updated content',
        'comments' => 'Updated via MCP'
      },
      @user
    )

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])
    assert_match(/success/i, data['message'])

    # Verify update
    page.reload
    assert_equal 'Updated content', page.content.text
  end

  test 'update_wiki_page creates new page if not exists' do
    stub_plugin_settings('enable_write_operations' => '1')

    result = RedmineMcp::Tools::Wiki::Update.execute(
      {
        'project_id' => @project.identifier,
        'page_title' => 'NewPage',
        'content' => 'New page content'
      },
      @user
    )

    assert_equal false, result[:isError]

    # Verify page was created
    page = @project.wiki.find_page('NewPage')
    assert_not_nil page
    assert_equal 'New page content', page.content.text
  end

  test 'update_wiki_page fails when write operations disabled' do
    stub_plugin_settings('enable_write_operations' => '0')

    assert_raises RedmineMcp::WriteOperationsDisabled do
      RedmineMcp::Tools::Wiki::Update.execute(
        {
          'project_id' => @project.identifier,
          'page_title' => 'Test',
          'content' => 'Test'
        },
        @user
      )
    end
  end

  test 'update_wiki_page fails when module disabled' do
    stub_plugin_settings('enable_write_operations' => '1')
    @project.enabled_modules.where(name: 'wiki').destroy_all

    assert_raises RedmineMcp::PermissionDenied do
      RedmineMcp::Tools::Wiki::Update.execute(
        {
          'project_id' => @project.identifier,
          'page_title' => 'Test',
          'content' => 'Test'
        },
        @user
      )
    end
  end
end
