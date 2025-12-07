#!/usr/bin/env ruby
# frozen_string_literal: true

# Redmine MCP Plugin - Installation Validation Script
#
# This script performs comprehensive health checks to validate that the
# Redmine MCP plugin is properly installed and configured.
#
# Usage:
#   From Redmine root directory:
#     ruby plugins/redmine_mcp/bin/validate_installation.rb
#
#   Or from plugin directory:
#     cd plugins/redmine_mcp && ruby bin/validate_installation.rb
#
# The script will check:
#   - Ruby version compatibility (2.7+)
#   - Redmine version compatibility (5.0+)
#   - Plugin file structure integrity
#   - Tool loading and registration
#   - Prompt loading and registration
#   - Registry population and health
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed

require 'fileutils'
require 'json'

# ANSI color codes for pretty output
class Colors
  RESET = "\e[0m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  BOLD = "\e[1m"
end

class ValidationReport
  attr_reader :checks, :failures

  def initialize
    @checks = []
    @failures = []
  end

  def check(name)
    print "Checking #{name}... "
    result = yield
    if result[:success]
      puts "#{Colors::GREEN}OK#{Colors::RESET}"
      @checks << { name: name, success: true, message: result[:message] }
    else
      puts "#{Colors::RED}FAILED#{Colors::RESET}"
      puts "  #{Colors::RED}Error: #{result[:message]}#{Colors::RESET}"
      @checks << { name: name, success: false, message: result[:message] }
      @failures << name
    end
  rescue StandardError => e
    puts "#{Colors::RED}ERROR#{Colors::RESET}"
    puts "  #{Colors::RED}Exception: #{e.message}#{Colors::RESET}"
    @checks << { name: name, success: false, message: "Exception: #{e.message}" }
    @failures << name
  end

  def print_summary
    puts "\n#{Colors::BOLD}=== Validation Summary ===#{Colors::RESET}"
    puts "Total checks: #{@checks.size}"
    puts "#{Colors::GREEN}Passed: #{@checks.count { |c| c[:success] }}#{Colors::RESET}"
    puts "#{Colors::RED}Failed: #{@failures.size}#{Colors::RESET}"

    if @failures.empty?
      puts "\n#{Colors::GREEN}#{Colors::BOLD}All checks passed! Plugin is ready to use.#{Colors::RESET}"
      return 0
    else
      puts "\n#{Colors::RED}#{Colors::BOLD}The following checks failed:#{Colors::RESET}"
      @failures.each { |f| puts "  - #{f}" }
      return 1
    end
  end
end

# Determine plugin root directory
PLUGIN_ROOT = if File.exist?('bin/validate_installation.rb')
                # Running from plugin directory
                File.expand_path('..')
              elsif File.exist?('plugins/redmine_mcp/bin/validate_installation.rb')
                # Running from Redmine root
                File.expand_path('plugins/redmine_mcp')
              else
                puts "#{Colors::RED}Error: Cannot determine plugin location#{Colors::RESET}"
                puts "Please run from Redmine root or plugin directory"
                exit 1
              end

puts "#{Colors::BOLD}Redmine MCP Plugin - Installation Validator#{Colors::RESET}"
puts "Plugin root: #{PLUGIN_ROOT}\n\n"

report = ValidationReport.new

# Check 1: Ruby version
report.check('Ruby version (>= 2.7)') do
  major, minor = RUBY_VERSION.split('.').map(&:to_i)
  version_ok = major > 2 || (major == 2 && minor >= 7)
  {
    success: version_ok,
    message: version_ok ? "Ruby #{RUBY_VERSION}" : "Ruby #{RUBY_VERSION} is too old (need 2.7+)"
  }
end

# Check 2: Redmine availability
report.check('Redmine installation') do
  redmine_root = File.expand_path('../../../..', PLUGIN_ROOT)
  redmine_rb = File.join(redmine_root, 'config/environment.rb')
  {
    success: File.exist?(redmine_rb),
    message: File.exist?(redmine_rb) ? "Found at #{redmine_root}" : 'config/environment.rb not found'
  }
end

# Check 3: Plugin structure - required files
REQUIRED_FILES = %w[
  init.rb
  lib/redmine_mcp.rb
  lib/redmine_mcp/registry.rb
  lib/redmine_mcp/json_rpc.rb
  lib/redmine_mcp/errors.rb
  lib/redmine_mcp/tools/base.rb
  lib/redmine_mcp/prompts/base.rb
  config/routes.rb
  app/controllers/redmine_mcp/mcp_controller.rb
].freeze

report.check('Plugin file structure') do
  missing_files = REQUIRED_FILES.reject { |f| File.exist?(File.join(PLUGIN_ROOT, f)) }
  {
    success: missing_files.empty?,
    message: missing_files.empty? ? "All #{REQUIRED_FILES.size} required files present" : "Missing files: #{missing_files.join(', ')}"
  }
end

# Check 4: Tool files exist
report.check('Tool files') do
  tools_dir = File.join(PLUGIN_ROOT, 'lib/redmine_mcp/tools')
  tool_files = Dir[File.join(tools_dir, '**/*.rb')].reject { |f| f.end_with?('/base.rb') }
  {
    success: tool_files.size > 0,
    message: "Found #{tool_files.size} tool files"
  }
end

# Check 5: Prompt files exist
report.check('Prompt files') do
  prompts_dir = File.join(PLUGIN_ROOT, 'lib/redmine_mcp/prompts')
  prompt_files = Dir[File.join(prompts_dir, '**/*.rb')].reject { |f| f.end_with?('/base.rb') }
  {
    success: prompt_files.size > 0,
    message: "Found #{prompt_files.size} prompt files"
  }
end

# Check 6: Load plugin and verify registry (requires Rails environment)
report.check('Plugin loading and registry') do
  begin
    # Try to load in standalone mode (without Rails)
    $LOAD_PATH.unshift(File.join(PLUGIN_ROOT, 'lib'))

    # Create minimal stubs for Redmine classes if not in Rails env
    unless defined?(Rails)
      require 'logger'

      module Rails
        def self.logger
          @logger ||= Logger.new($stdout, level: Logger::ERROR)
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
    end

    # Load the plugin
    require 'redmine_mcp'

    # Check registry stats
    stats = RedmineMcp::Registry.stats
    tools_count = stats[:tools]
    prompts_count = stats[:prompts]
    is_frozen = stats[:frozen]

    success = tools_count > 0 && prompts_count > 0 && is_frozen

    details = []
    details << "#{tools_count} tools registered"
    details << "#{prompts_count} prompts registered"
    details << (is_frozen ? 'registry frozen' : 'registry NOT frozen')

    {
      success: success,
      message: details.join(', ')
    }
  rescue LoadError => e
    {
      success: false,
      message: "Failed to load plugin: #{e.message}"
    }
  rescue StandardError => e
    {
      success: false,
      message: "Error during loading: #{e.message}"
    }
  end
end

# Check 7: List registered tools
report.check('Tool registration details') do
  begin
    tools = RedmineMcp::Registry.tools
    tool_names = tools.map { |t| t.respond_to?(:tool_name) ? t.tool_name : t.name }

    puts "\n  Registered tools:"
    tool_names.sort.each { |name| puts "    - #{name}" }

    {
      success: tools.size >= 28, # We expect at least 28 tools
      message: "#{tools.size} tools registered (expected >= 28)"
    }
  rescue StandardError => e
    {
      success: false,
      message: "Cannot list tools: #{e.message}"
    }
  end
end

# Check 8: List registered prompts
report.check('Prompt registration details') do
  begin
    prompts = RedmineMcp::Registry.prompts
    prompt_names = prompts.map { |p| p.respond_to?(:prompt_name) ? p.prompt_name : p.name }

    puts "\n  Registered prompts:"
    prompt_names.sort.each { |name| puts "    - #{name}" }

    {
      success: prompts.size >= 5, # We expect at least 5 prompts
      message: "#{prompts.size} prompts registered (expected >= 5)"
    }
  rescue StandardError => e
    {
      success: false,
      message: "Cannot list prompts: #{e.message}"
    }
  end
end

# Check 9: Verify JSON-RPC constants
report.check('JSON-RPC configuration') do
  begin
    protocol_version = RedmineMcp::JsonRpc::PROTOCOL_VERSION
    server_version = RedmineMcp::JsonRpc::SERVER_VERSION

    {
      success: !protocol_version.empty? && !server_version.empty?,
      message: "Protocol: #{protocol_version}, Server: #{server_version}"
    }
  rescue StandardError => e
    {
      success: false,
      message: "Cannot access JSON-RPC constants: #{e.message}"
    }
  end
end

# Check 10: Verify error classes are defined
report.check('Error classes') do
  begin
    errors = [
      RedmineMcp::WriteOperationsDisabled,
      RedmineMcp::PermissionDenied,
      RedmineMcp::ResourceNotFound
    ]

    {
      success: true,
      message: "#{errors.size} error classes defined"
    }
  rescue NameError => e
    {
      success: false,
      message: "Missing error class: #{e.message}"
    }
  end
end

# Print final summary and exit
exit_code = report.print_summary

puts "\n#{Colors::BOLD}Next Steps:#{Colors::RESET}"
if exit_code == 0
  puts "1. Run: ruby plugins/redmine_mcp/bin/smoke_test.rb (quick smoke test)"
  puts "2. Configure your API key in Redmine (Administration > Settings > MCP)"
  puts "3. Run: bin/test_mcp_endpoint.sh (test HTTP endpoints)"
  puts "4. Connect your AI client to the MCP server"
else
  puts "1. Fix the failed checks listed above"
  puts "2. Review plugin installation documentation"
  puts "3. Check Redmine logs for detailed error messages"
end

exit exit_code
