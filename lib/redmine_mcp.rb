# frozen_string_literal: true

# Redmine MCP Plugin - Master Loader
#
# This file loads all plugin components in the correct order.
# Order matters! Dependencies must be loaded before dependents.
#
# Load order:
#   1. Errors (other classes raise these)
#   2. Core utilities (SSE, rate limiter, etc.)
#   3. Base classes (Tools::Base, Prompts::Base)
#   4. Registry (references base classes)
#   5. JSON-RPC handler (uses registry)
#   6. Tool implementations (auto-loaded from tools/**)
#   7. Prompt implementations (auto-loaded from prompts/**)
#   8. Freeze registry (thread safety)
#

module RedmineMcp
  # Plugin root directory
  ROOT = File.dirname(__FILE__)
end

# 1. Errors first (other classes raise these)
require_relative 'redmine_mcp/error_classes'

# 2. Core utilities
require_relative 'redmine_mcp/sse'
require_relative 'redmine_mcp/sse_connection_tracker'
require_relative 'redmine_mcp/rate_limiter'

# 3. Base classes before implementations
require_relative 'redmine_mcp/tools/base'
require_relative 'redmine_mcp/prompts/base'

# 4. Registry (references base classes)
require_relative 'redmine_mcp/registry'

# 5. JSON-RPC handler (uses registry, includes inline resource handlers)
require_relative 'redmine_mcp/json_rpc'

# 6. Auto-load all tool implementations
# Tools register themselves with Registry.register_tool at load time
Dir[File.join(RedmineMcp::ROOT, 'redmine_mcp/tools/**/*.rb')].sort.each do |file|
  # Skip base.rb (already loaded)
  next if file.end_with?('/base.rb')

  require file
end

# 7. Auto-load all prompt implementations
# Prompts register themselves with Registry.register_prompt at load time
Dir[File.join(RedmineMcp::ROOT, 'redmine_mcp/prompts/**/*.rb')].sort.each do |file|
  # Skip base.rb (already loaded)
  next if file.end_with?('/base.rb')

  require file
end

# 8. Freeze registry after all classes loaded (thread safety for Puma)
RedmineMcp::Registry.freeze!

Rails.logger.info "[MCP] Plugin loaded: #{RedmineMcp::Registry.stats}"
