#!/usr/bin/env ruby
# frozen_string_literal: true

# Redmine MCP Plugin - Test Data Setup Script
#
# Creates sample data for testing the MCP plugin
#
# Usage:
#   Docker:
#     docker-compose exec redmine bundle exec rails runner plugins/redmine_mcp/bin/setup_test_data.rb
#
#   Manual install:
#     bundle exec rails runner plugins/redmine_mcp/bin/setup_test_data.rb

puts "=== Setting up Redmine MCP Test Data ==="
puts ""

# Ensure we have default data
if Tracker.count.zero?
  puts "Loading default configuration data..."
  Redmine::DefaultData::Loader.load('en')
end

# Create test project
project = Project.find_by(identifier: 'mcp-test')
if project
  puts "Project 'mcp-test' already exists, skipping..."
else
  project = Project.create!(
    name: 'MCP Test Project',
    identifier: 'mcp-test',
    description: 'Test project for MCP plugin development',
    is_public: true
  )
  project.enabled_module_names = %w[issue_tracking time_tracking wiki]
  puts "Created project: #{project.name}"
end

# Create test user
test_user = User.find_by(login: 'mcptest')
if test_user
  puts "User 'mcptest' already exists, skipping..."
else
  test_user = User.new(
    login: 'mcptest',
    firstname: 'MCP',
    lastname: 'Tester',
    mail: 'mcptest@example.com',
    admin: false,
    language: 'en'
  )
  test_user.password = 'mcptest123'
  test_user.password_confirmation = 'mcptest123'
  test_user.save!
  test_user.update_column(:status, User::STATUS_ACTIVE)
  puts "Created user: mcptest (password: mcptest123)"
end

# Add user to project
unless Member.exists?(user: test_user, project: project)
  developer_role = Role.find_by(name: 'Developer') || Role.where(builtin: 0).first
  if developer_role
    Member.create!(
      user: test_user,
      project: project,
      roles: [developer_role]
    )
    puts "Added user to project with role: #{developer_role.name}"
  end
end

# Create sample issues
admin = User.find_by(admin: true) || User.first
tracker = Tracker.first
status_new = IssueStatus.find_by(name: 'New') || IssueStatus.first
status_closed = IssueStatus.where(is_closed: true).first
priority_normal = IssuePriority.find_by(name: 'Normal') || IssuePriority.default || IssuePriority.first
priority_high = IssuePriority.find_by(name: 'High') || IssuePriority.where.not(id: priority_normal.id).first

existing_issues = Issue.where(project: project).count
if existing_issues >= 10
  puts "Project already has #{existing_issues} issues, skipping issue creation..."
else
  issues_to_create = [
    { subject: 'Implement user authentication', description: 'Add login/logout functionality', priority: priority_high },
    { subject: 'Fix navigation bug', description: 'Menu not displaying correctly on mobile', priority: priority_high },
    { subject: 'Add dashboard widgets', description: 'Create customizable dashboard with widgets', priority: priority_normal },
    { subject: 'Improve search performance', description: 'Search is slow on large datasets', priority: priority_normal },
    { subject: 'Update documentation', description: 'Docs need to be updated for v2.0', priority: priority_normal },
    { subject: 'Add export to CSV feature', description: 'Users want to export data as CSV', priority: priority_normal },
    { subject: 'Security audit findings', description: 'Address issues from security audit', priority: priority_high },
    { subject: 'Database optimization', description: 'Optimize slow queries', priority: priority_normal },
    { subject: 'Add dark mode support', description: 'Users requested dark theme option', priority: priority_normal },
    { subject: 'API rate limiting', description: 'Implement rate limiting for API endpoints', priority: priority_normal }
  ]

  issues_to_create.each_with_index do |issue_data, index|
    # Alternate between open and closed for variety
    status = index < 7 ? status_new : (status_closed || status_new)

    Issue.create!(
      project: project,
      subject: issue_data[:subject],
      description: issue_data[:description],
      tracker: tracker,
      author: admin,
      assigned_to: index.even? ? test_user : nil,
      status: status,
      priority: issue_data[:priority] || priority_normal,
      done_ratio: status.is_closed ? 100 : (index * 10) % 100
    )
  end
  puts "Created 10 sample issues"
end

# Create wiki page
wiki = project.wiki || project.create_wiki
unless WikiPage.exists?(wiki: wiki, title: 'MCP_Test_Page')
  page = WikiPage.new(wiki: wiki, title: 'MCP_Test_Page')
  page.build_content(
    text: <<~WIKI,
      h1. MCP Test Wiki Page

      This is a test wiki page for the Redmine MCP plugin.

      h2. Features

      * Issue management
      * Time tracking
      * Wiki editing
      * Project navigation

      h2. API Endpoints

      * @GET /mcp@ - SSE stream
      * @POST /mcp@ - JSON-RPC messages
      * @GET /mcp/health@ - Health check

      h2. Testing

      Use this page to test the @get_wiki_page@ and @update_wiki_page@ tools.
    WIKI
    author: admin
  )
  page.save!
  puts "Created wiki page: MCP_Test_Page"
end

# Create time entries
existing_time_entries = TimeEntry.where(project: project).count
if existing_time_entries >= 5
  puts "Project already has #{existing_time_entries} time entries, skipping..."
else
  activity = TimeEntryActivity.first || Enumeration.where(type: 'TimeEntryActivity').first
  if activity
    issues = Issue.where(project: project).limit(5)
    issues.each_with_index do |issue, index|
      TimeEntry.create!(
        project: project,
        issue: issue,
        user: test_user,
        activity: activity,
        hours: 1.5 + (index * 0.5),
        comments: "Work on #{issue.subject}",
        spent_on: Date.today - index.days
      )
    end
    puts "Created #{issues.count} time entries"
  else
    puts "No time entry activities found, skipping time entries..."
  end
end

# Create a version/milestone
unless Version.exists?(project: project, name: 'v1.0.0')
  Version.create!(
    project: project,
    name: 'v1.0.0',
    description: 'Initial release',
    status: 'open',
    due_date: Date.today + 30.days
  )
  puts "Created version: v1.0.0"
end

puts ""
puts "=== Test Data Setup Complete ==="
puts ""
puts "Summary:"
puts "  Project: #{project.name} (#{project.identifier})"
puts "  Test user: mcptest (password: mcptest123)"
puts "  Issues: #{Issue.where(project: project).count}"
puts "  Time entries: #{TimeEntry.where(project: project).count}"
puts "  Wiki pages: #{project.wiki&.pages&.count || 0}"
puts "  Versions: #{Version.where(project: project).count}"
puts ""
puts "Next steps:"
puts "  1. Get API key: Login as admin > My Account > Show API key"
puts "  2. Configure plugin: Administration > Plugins > Redmine MCP Server"
puts "  3. Test: curl http://localhost:3000/mcp/health"
