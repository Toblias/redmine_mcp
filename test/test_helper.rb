# frozen_string_literal: true

# Load Redmine test helper
require File.expand_path('../../../test/test_helper', __dir__)

# Ensure the plugin is fully loaded with all tools and prompts
# The check for empty registry handles case where Registry class exists but isn't populated
if !defined?(RedmineMcp::Registry) || RedmineMcp::Registry.tools.empty?
  require_relative '../lib/redmine_mcp'
end

module RedmineMcp
  module TestHelper
    # Create a test user with specified permissions
    #
    # @param attributes [Hash] User attributes
    # @param permissions [Array<Symbol>] Permissions to grant
    # @return [User] Created user
    def create_user(attributes = {}, permissions: [])
      user = User.new(
        {
          login: "test_user_#{rand(10000)}",
          firstname: 'Test',
          lastname: 'User',
          mail: "test#{rand(10000)}@example.com",
          status: User::STATUS_ACTIVE
        }.merge(attributes)
      )
      user.save!

      if permissions.any?
        role = Role.new(name: "Test Role #{rand(10000)}", permissions: permissions)
        role.save!
        user.update_attribute(:admin, false)
        user.roles << role
      end

      user
    end

    # Create a test project
    #
    # @param attributes [Hash] Project attributes
    # @param user [User] User to add as member
    # @param role [Role] Role for user membership
    # @return [Project] Created project
    def create_project(attributes = {}, user: nil, role: nil)
      project = Project.new(
        {
          name: "Test Project #{rand(10000)}",
          identifier: "test-project-#{rand(10000)}",
          is_public: false,
          status: Project::STATUS_ACTIVE
        }.merge(attributes)
      )
      project.save!

      if user && role
        Member.create!(project: project, principal: user, roles: [role])
      end

      project
    end

    # Create a test issue
    #
    # @param project [Project] Project to create issue in
    # @param attributes [Hash] Issue attributes
    # @return [Issue] Created issue
    def create_issue(project, attributes = {})
      issue = Issue.new(
        {
          project: project,
          tracker: project.trackers.first || Tracker.first,
          author: User.current,
          subject: "Test Issue #{rand(10000)}",
          priority: IssuePriority.default || IssuePriority.first,
          status: IssueStatus.default || IssueStatus.first
        }.merge(attributes)
      )
      issue.save!
      issue
    end

    # Create a test wiki page
    #
    # @param project [Project] Project to create wiki page in
    # @param attributes [Hash] Wiki page attributes
    # @return [WikiPage] Created wiki page
    def create_wiki_page(project, attributes = {})
      project.wiki ||= Wiki.create!(project: project, start_page: 'Wiki')

      page = WikiPage.new(
        {
          wiki: project.wiki,
          title: "TestPage#{rand(10000)}"
        }.merge(attributes.except(:text, :content))
      )
      page.save!

      content = WikiContent.new(
        page: page,
        author: User.current,
        text: attributes[:text] || attributes[:content] || "Test wiki content"
      )
      content.save!
      page.reload
      page
    end

    # Create a test time entry
    #
    # @param attributes [Hash] Time entry attributes
    # @return [TimeEntry] Created time entry
    def create_time_entry(attributes = {})
      defaults = {
        user: User.current,
        hours: 1.0,
        spent_on: Date.today,
        activity: TimeEntryActivity.first || TimeEntryActivity.create!(name: 'Development', active: true)
      }

      entry = TimeEntry.new(defaults.merge(attributes))
      entry.save!
      entry
    end

    # Mock StringIO for SSE testing (no network)
    #
    # @return [StringIO] Mock stream
    def mock_sse_stream
      StringIO.new
    end

    # Parse SSE events from StringIO
    #
    # @param stream [StringIO] SSE stream
    # @return [Array<Hash>] Parsed events with :event and :data keys
    def parse_sse_events(stream)
      stream.rewind
      content = stream.read
      events = []

      content.split("\n\n").each do |block|
        event = {}
        block.lines.each do |line|
          if line.start_with?('event: ')
            event[:event] = line.sub('event: ', '').chomp
          elsif line.start_with?('data: ')
            event[:data] ||= ''
            event[:data] += line.sub('data: ', '').chomp
          end
        end
        events << event if event.any?
      end

      events
    end

    # Stub plugin settings
    #
    # @param settings [Hash] Settings to stub
    def stub_plugin_settings(settings = {})
      defaults = {
        'enabled' => '1',
        'enable_write_operations' => '1',
        'rate_limit' => '60',
        'max_limit' => '100',
        'default_limit' => '25',
        'request_timeout' => '30',
        'heartbeat_interval' => '15',
        'sse_timeout' => '300'
      }
      Setting.stubs(:plugin_redmine_mcp).returns(defaults.merge(settings))
    end

    # Clear rate limiter cache
    def clear_rate_limiter
      RedmineMcp::RateLimiter.clear!
    end

    # Reset registry for testing
    def reset_registry
      RedmineMcp::Registry.reset!
    end
  end
end

# Include helper in test classes
class ActiveSupport::TestCase
  include RedmineMcp::TestHelper

  # Setup: Reset registry before each test
  setup do
    stub_plugin_settings
    clear_rate_limiter
  end
end
