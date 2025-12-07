# frozen_string_literal: true

require_relative '../../test_helper'

class UsersToolsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles

  def setup
    @admin = User.find(1)
    @user = User.find(2)
    @other_user = User.find(3)
    @project = Project.find(1)

    User.current = @user
    stub_plugin_settings
  end

  # ========== get_current_user Tests ==========

  test 'get_current_user returns current user profile' do
    result = RedmineMcp::Tools::Users::GetCurrent.execute({}, @user)

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert_equal @user.id, data['id']
    assert_equal @user.login, data['login']
    assert_equal @user.mail, data['mail']
    assert data.key?('admin')
  end

  test 'get_current_user includes full profile data' do
    result = RedmineMcp::Tools::Users::GetCurrent.execute({}, @user)

    data = JSON.parse(result[:content].first[:text])

    # Should include sensitive fields for self
    assert data.key?('mail')
    assert data.key?('status')
    assert data.key?('admin')
  end

  # ========== get_user Tests ==========

  test 'get_user returns full profile for self' do
    result = RedmineMcp::Tools::Users::Get.execute({ 'user_id' => @user.id }, @user)

    assert_equal false, result[:isError]
    data = JSON.parse(result[:content].first[:text])

    assert_equal @user.id, data['id']
    assert data.key?('mail')
    assert data.key?('admin')
  end

  test 'get_user returns full profile for admin' do
    User.current = @admin

    result = RedmineMcp::Tools::Users::Get.execute({ 'user_id' => @user.id }, @admin)

    data = JSON.parse(result[:content].first[:text])

    # Admin should see all fields
    assert data.key?('mail')
    assert data.key?('admin')
    assert data.key?('status')
  end

  test 'get_user returns limited profile for other users' do
    result = RedmineMcp::Tools::Users::Get.execute({ 'user_id' => @other_user.id }, @user)

    data = JSON.parse(result[:content].first[:text])

    # Should only have basic fields
    assert_equal @other_user.id, data['id']
    assert_equal @other_user.login, data['login']

    # Should NOT have sensitive fields for non-admin users viewing other users
    # (mail visibility depends on Redmine settings, just check we don't expose admin flag)
    assert_nil data['admin'], "Non-admin should not see admin flag for other users"
  end

  test 'get_user raises error for invalid user' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Tools::Users::Get.execute({ 'user_id' => 999999 }, @user)
    end
  end

  # ========== list_users Tests ==========

  test 'list_users returns users for admin' do
    User.current = @admin

    result = RedmineMcp::Tools::Users::List.execute({}, @admin)

    assert_equal false, result[:isError]
    users = JSON.parse(result[:content].first[:text])
    assert users.is_a?(Array)
    assert users.any?
  end

  test 'list_users returns limited data for non-admin' do
    result = RedmineMcp::Tools::Users::List.execute({}, @user)

    assert_equal false, result[:isError]
    users = JSON.parse(result[:content].first[:text])

    # Should return users visible to the current user
    assert users.is_a?(Array)
  end

  test 'list_users filters by status' do
    User.current = @admin

    result = RedmineMcp::Tools::Users::List.execute({ 'status' => 'active' }, @admin)

    users = JSON.parse(result[:content].first[:text])
    assert users.all? { |u| u['status'] == User::STATUS_ACTIVE } if users.any?
  end

  test 'list_users respects pagination' do
    User.current = @admin

    result = RedmineMcp::Tools::Users::List.execute({ 'limit' => '1' }, @admin)

    assert result[:_meta].present?
    users = JSON.parse(result[:content].first[:text])
    assert users.size <= 1
  end
end
