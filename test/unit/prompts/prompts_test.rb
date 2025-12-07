# frozen_string_literal: true

require_relative '../../test_helper'

class PromptsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues, :versions

  def setup
    @user = User.find(2)
    @project = Project.find(1)

    User.current = @user
    stub_plugin_settings
  end

  # ========== bug_report Prompt Tests ==========

  test 'bug_report generates template without context' do
    result = RedmineMcp::Prompts::BugReport.execute({}, @user)

    assert result[:messages].is_a?(Array)
    assert result[:messages].any?

    message = result[:messages].first
    assert_equal 'user', message[:role]
    assert message[:content][:text].present?
    assert_match(/bug report/i, message[:content][:text])
  end

  test 'bug_report includes project context when provided' do
    result = RedmineMcp::Prompts::BugReport.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    message = result[:messages].first
    assert_match(/#{@project.name}/, message[:content][:text])
  end

  test 'bug_report includes summary when provided' do
    result = RedmineMcp::Prompts::BugReport.execute(
      { 'summary' => 'Test bug summary' },
      @user
    )

    message = result[:messages].first
    assert_match(/Test bug summary/, message[:content][:text])
  end

  test 'bug_report raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Prompts::BugReport.execute({ 'project_id' => 'invalid' }, @user)
    end
  end

  # ========== feature_request Prompt Tests ==========

  test 'feature_request generates template without context' do
    result = RedmineMcp::Prompts::FeatureRequest.execute({}, @user)

    assert result[:messages].is_a?(Array)
    message = result[:messages].first
    assert_match(/feature request/i, message[:content][:text])
  end

  test 'feature_request includes project context when provided' do
    result = RedmineMcp::Prompts::FeatureRequest.execute(
      { 'project_id' => @project.identifier },
      @user
    )

    message = result[:messages].first
    assert_match(/#{@project.name}/, message[:content][:text])
  end

  test 'feature_request includes title when provided' do
    result = RedmineMcp::Prompts::FeatureRequest.execute(
      { 'title' => 'New Feature' },
      @user
    )

    message = result[:messages].first
    assert_match(/New Feature/, message[:content][:text])
  end

  # ========== status_report Prompt Tests ==========

  test 'status_report generates report for project' do
    result = RedmineMcp::Prompts::StatusReport.execute(
      { 'project_id' => @project.id.to_s },
      @user
    )

    assert result[:messages].is_a?(Array)
    message = result[:messages].first

    assert_match(/status report/i, message[:content][:text])
    assert_match(/#{@project.name}/, message[:content][:text])
  end

  test 'status_report accepts period parameter' do
    result = RedmineMcp::Prompts::StatusReport.execute(
      {
        'project_id' => @project.id.to_s,
        'period' => '1 month'
      },
      @user
    )

    message = result[:messages].first
    assert_match(/1 month/, message[:content][:text])
  end

  test 'status_report raises error for invalid project' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Prompts::StatusReport.execute({ 'project_id' => '999999' }, @user)
    end
  end

  # ========== sprint_summary Prompt Tests ==========

  test 'sprint_summary generates summary for version' do
    version = @project.versions.first || Version.create!(
      project: @project,
      name: 'Test Version'
    )

    result = RedmineMcp::Prompts::SprintSummary.execute(
      { 'version_id' => version.id.to_s },
      @user
    )

    assert result[:messages].is_a?(Array)
    message = result[:messages].first

    assert_match(/sprint/i, message[:content][:text])
    assert_match(/#{version.name}/, message[:content][:text])
  end

  test 'sprint_summary raises error for invalid version' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Prompts::SprintSummary.execute({ 'version_id' => '999999' }, @user)
    end
  end

  # ========== release_notes Prompt Tests ==========

  test 'release_notes generates notes for version' do
    version = @project.versions.first || Version.create!(
      project: @project,
      name: 'Test Release'
    )

    result = RedmineMcp::Prompts::ReleaseNotes.execute(
      { 'version_id' => version.id.to_s },
      @user
    )

    assert result[:messages].is_a?(Array)
    message = result[:messages].first

    assert_match(/release notes/i, message[:content][:text])
    assert_match(/#{version.name}/, message[:content][:text])
  end

  test 'release_notes accepts format parameter' do
    version = @project.versions.first || Version.create!(
      project: @project,
      name: 'Test Release'
    )

    result = RedmineMcp::Prompts::ReleaseNotes.execute(
      {
        'version_id' => version.id.to_s,
        'format' => 'markdown'
      },
      @user
    )

    message = result[:messages].first
    assert_match(/markdown/i, message[:content][:text])
  end

  test 'release_notes raises error for invalid version' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Prompts::ReleaseNotes.execute({ 'version_id' => '999999' }, @user)
    end
  end

  # ========== Prompt Base Class Tests ==========

  test 'parse_period handles week format' do
    duration = RedmineMcp::Prompts::Base.parse_period('2 weeks')
    assert_equal 14.days, duration
  end

  test 'parse_period handles day format' do
    duration = RedmineMcp::Prompts::Base.parse_period('30 days')
    assert_equal 30.days, duration
  end

  test 'parse_period handles month format' do
    duration = RedmineMcp::Prompts::Base.parse_period('1 month')
    assert_equal 1.month, duration
  end

  test 'parse_period raises error for invalid format' do
    assert_raises RedmineMcp::InvalidParams do
      RedmineMcp::Prompts::Base.parse_period('invalid')
    end
  end
end
