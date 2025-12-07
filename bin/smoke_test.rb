#!/usr/bin/env ruby
# frozen_string_literal: true

# Redmine MCP Plugin - Quick Smoke Test
#
# This script performs a quick smoke test of the plugin to verify it loads
# correctly and all tools/prompts are registered. Much faster than the full
# validation script.
#
# Usage:
#   From Redmine root directory:
#     ruby plugins/redmine_mcp/bin/smoke_test.rb
#
#   From Rails console:
#     load 'plugins/redmine_mcp/bin/smoke_test.rb'
#
#   From plugin directory:
#     cd plugins/redmine_mcp && ruby bin/smoke_test.rb
#
# The script will:
#   - Load the plugin
#   - List all registered tools (count and names)
#   - List all registered prompts (count and names)
#   - Display registry health status
#
# Exit codes:
#   0 - Smoke test passed
#   1 - Smoke test failed

# Determine if we're in Rails console or standalone
IN_RAILS = defined?(Rails) && Rails.respond_to?(:root)

unless IN_RAILS
  # Running standalone - need to set up load path
  require 'logger'
  require 'pathname'

  PLUGIN_ROOT = if File.exist?('bin/smoke_test.rb')
                  File.expand_path('..')
                elsif File.exist?('plugins/redmine_mcp/bin/smoke_test.rb')
                  File.expand_path('plugins/redmine_mcp')
                else
                  puts "Error: Cannot determine plugin location"
                  puts "Please run from Redmine root or plugin directory"
                  exit 1
                end

  $LOAD_PATH.unshift(File.join(PLUGIN_ROOT, 'lib'))

  # Create minimal stubs for Redmine classes
  module Rails
    def self.logger
      @logger ||= Logger.new($stdout, level: Logger::WARN)
    end

    def self.root
      Pathname.new('.')
    end
  end

  class User
    STATUS_ACTIVE = 1
    STATUS_REGISTERED = 2
    STATUS_LOCKED = 3
  end

  class Issue; end

  class Project
    STATUS_ACTIVE = 1
    STATUS_CLOSED = 5
    STATUS_ARCHIVED = 9
  end

  class TimeEntry; end
  class WikiPage; end

  # Load the plugin
  begin
    require 'redmine_mcp'
  rescue LoadError => e
    puts "Error: Failed to load plugin: #{e.message}"
    exit 1
  end
end

# ANSI colors (simple version)
def color(text, code)
  "\e[#{code}m#{text}\e[0m"
end

def bold(text)
  color(text, '1')
end

def green(text)
  color(text, '32')
end

def red(text)
  color(text, '31')
end

def blue(text)
  color(text, '34')
end

def yellow(text)
  color(text, '33')
end

# Main smoke test
puts bold("=== Redmine MCP Plugin - Smoke Test ===")
puts ""

begin
  # Get registry stats
  stats = RedmineMcp::Registry.stats

  # Display overall status
  puts bold("Registry Status:")
  puts "  Frozen: #{stats[:frozen] ? green('Yes') : red('No')}"
  puts "  Tools registered: #{blue(stats[:tools].to_s)}"
  puts "  Prompts registered: #{blue(stats[:prompts].to_s)}"
  puts ""

  # Check if we have expected minimum counts
  min_tools = 28
  min_prompts = 5

  if stats[:tools] < min_tools
    puts red("Warning: Expected at least #{min_tools} tools, found #{stats[:tools]}")
  end

  if stats[:prompts] < min_prompts
    puts red("Warning: Expected at least #{min_prompts} prompts, found #{stats[:prompts]}")
  end

  # List all tools
  puts bold("Registered Tools (#{stats[:tools]}):")
  tools = RedmineMcp::Registry.tools
  tool_list = tools.map do |tool|
    name = tool.respond_to?(:tool_name) ? tool.tool_name : tool.name
    description = tool.respond_to?(:description) ? tool.description : 'N/A'
    { name: name, description: description }
  end.sort_by { |t| t[:name] }

  tool_list.each do |tool|
    puts "  #{green('✓')} #{bold(tool[:name])}"
    if tool[:description] && tool[:description] != 'N/A'
      # Truncate long descriptions
      desc = tool[:description].length > 80 ? "#{tool[:description][0..77]}..." : tool[:description]
      puts "    #{desc}"
    end
  end
  puts ""

  # List all prompts
  puts bold("Registered Prompts (#{stats[:prompts]}):")
  prompts = RedmineMcp::Registry.prompts
  prompt_list = prompts.map do |prompt|
    name = prompt.respond_to?(:prompt_name) ? prompt.prompt_name : prompt.name
    description = prompt.respond_to?(:description) ? prompt.description : 'N/A'
    { name: name, description: description }
  end.sort_by { |p| p[:name] }

  prompt_list.each do |prompt|
    puts "  #{green('✓')} #{bold(prompt[:name])}"
    if prompt[:description] && prompt[:description] != 'N/A'
      # Truncate long descriptions
      desc = prompt[:description].length > 80 ? "#{prompt[:description][0..77]}..." : prompt[:description]
      puts "    #{desc}"
    end
  end
  puts ""

  # Verify JSON-RPC configuration
  puts bold("JSON-RPC Configuration:")
  puts "  Protocol Version: #{blue(RedmineMcp::JsonRpc::PROTOCOL_VERSION)}"
  puts "  Server Version: #{blue(RedmineMcp::JsonRpc::SERVER_VERSION)}"
  puts ""

  # Test tool schema generation (pick first tool)
  if tools.any?
    sample_tool = tools.first
    puts bold("Sample Tool Schema Test:")
    puts "  Testing: #{sample_tool.tool_name}"
    begin
      schema = sample_tool.to_mcp_tool
      puts "  #{green('✓')} Schema generated successfully"
      puts "    Name: #{schema[:name]}"
      puts "    Description: #{schema[:description][0..60]}..."
      puts "    Input schema: #{schema.dig(:inputSchema, :type)}"
    rescue StandardError => e
      puts "  #{red('✗')} Schema generation failed: #{e.message}"
    end
    puts ""
  end

  # Test prompt schema generation (pick first prompt)
  if prompts.any?
    sample_prompt = prompts.first
    puts bold("Sample Prompt Schema Test:")
    puts "  Testing: #{sample_prompt.prompt_name}"
    begin
      schema = sample_prompt.to_mcp_prompt
      puts "  #{green('✓')} Schema generated successfully"
      puts "    Name: #{schema[:name]}"
      puts "    Description: #{schema[:description][0..60]}..." if schema[:description]
    rescue StandardError => e
      puts "  #{red('✗')} Schema generation failed: #{e.message}"
    end
    puts ""
  end

  # Final verdict
  success = stats[:frozen] &&
            stats[:tools] >= min_tools &&
            stats[:prompts] >= min_prompts

  if success
    puts green(bold("✓ Smoke test PASSED"))
    puts ""
    puts "The plugin appears to be working correctly!"
    puts ""
    puts bold("Quick Reference:")
    puts "  Tools: #{stats[:tools]}"
    puts "  Prompts: #{stats[:prompts]}"
    puts "  Protocol: #{RedmineMcp::JsonRpc::PROTOCOL_VERSION}"
    puts ""
    puts bold("Next Steps:")
    puts "  1. Run full validation: ruby plugins/redmine_mcp/bin/validate_installation.rb"
    puts "  2. Test endpoints: bin/test_mcp_endpoint.sh"
    puts "  3. Configure API access in Redmine admin panel"
    exit 0
  else
    puts red(bold("✗ Smoke test FAILED"))
    puts ""
    puts "Issues detected:"
    puts "  - Registry frozen: #{stats[:frozen]}" unless stats[:frozen]
    puts "  - Tools count: #{stats[:tools]} (expected >= #{min_tools})" if stats[:tools] < min_tools
    puts "  - Prompts count: #{stats[:prompts]} (expected >= #{min_prompts})" if stats[:prompts] < min_prompts
    puts ""
    puts "Run full validation for details: ruby plugins/redmine_mcp/bin/validate_installation.rb"
    exit 1
  end

rescue StandardError => e
  puts red(bold("✗ Smoke test ERROR"))
  puts ""
  puts "Exception: #{e.class.name}"
  puts "Message: #{e.message}"
  puts ""
  puts "Backtrace:"
  e.backtrace.first(10).each { |line| puts "  #{line}" }
  puts ""
  puts "This usually indicates a problem with plugin loading or dependencies."
  exit 1
end
