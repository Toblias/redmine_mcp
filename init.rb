# frozen_string_literal: true

# Exclude plugin lib from Zeitwerk autoloading (Rails 6.1+)
# Our plugin uses explicit requires in redmine_mcp.rb for proper load order
if defined?(Rails) && Rails.respond_to?(:autoloaders) && Rails.autoloaders.respond_to?(:main)
  plugin_lib_path = File.expand_path('lib', __dir__)
  Rails.autoloaders.main.ignore(plugin_lib_path) if File.exist?(plugin_lib_path)
end

# Load the plugin library
require_relative 'lib/redmine_mcp'

Redmine::Plugin.register :redmine_mcp do
  name 'Redmine MCP Server'
  author 'Redmine MCP Contributors'
  description 'Model Context Protocol (MCP) server for AI assistant integration with Redmine. ' \
              'Enables AI tools to read and manage issues, projects, wiki, time entries, and more.'
  version RedmineMcp::JsonRpc::SERVER_VERSION
  url 'https://github.com/redmine/redmine_mcp'
  author_url 'https://github.com/redmine/redmine_mcp'

  # Minimum Redmine version (5.0+ for Ruby 2.7+ compatibility)
  requires_redmine version_or_higher: '5.0'

  # Plugin settings with sensible defaults
  settings default: {
    'enabled' => '1',                    # Plugin enabled by default
    'enable_write_operations' => '0',    # Write ops disabled for safety
    'sse_timeout' => '3600',             # 1 hour max SSE connection
    'heartbeat_interval' => '30',        # 30 second ping interval
    'request_timeout' => '30',           # 30 second tool execution limit
    'default_limit' => '25',             # Default pagination size
    'max_limit' => '100',                # Max pagination size
    'rate_limit' => '60'                 # 60 requests per minute per user
  }, partial: 'settings/mcp_settings'
end
