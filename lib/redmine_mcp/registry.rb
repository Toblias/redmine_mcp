# frozen_string_literal: true

module RedmineMcp
  # Central registry for tools and prompts.
  # Tools and prompts register themselves at load time.
  # Registry is frozen after all classes load for thread safety.
  #
  # Resources are NOT registered here - they use simple URI dispatch
  # in JsonRpc.handle_resources_read.
  #
  class Registry
    @tools = {}
    @prompts = {}
    @frozen = false

    class << self
      # ========== Tool Registration ==========

      # Register a tool class.
      #
      # @param klass [Class] Tool class (subclass of Tools::Base)
      # @raise [RuntimeError] if registry is frozen
      def register_tool(klass)
        raise "Registry is frozen - cannot register #{klass}" if @frozen

        @tools[klass.tool_name] = klass
      end

      # Get all registered tool classes.
      #
      # @return [Array<Class>] All tool classes
      def tools
        @tools.values
      end

      # Get tools available to a specific user.
      # Filters by each tool's available_to? method.
      #
      # @param user [User] Current user
      # @return [Array<Class>] Tool classes available to user
      def tools_for_user(user)
        @tools.values.select { |t| t.available_to?(user) }
      end

      # Find a tool by name.
      #
      # @param name [String] Tool name
      # @return [Class] Tool class
      # @raise [ResourceNotFound] if tool not found
      def find_tool(name)
        @tools[name] or raise RedmineMcp::ResourceNotFound, "Tool not found: #{name}"
      end

      # ========== Prompt Registration ==========

      # Register a prompt class.
      #
      # @param klass [Class] Prompt class (subclass of Prompts::Base)
      # @raise [RuntimeError] if registry is frozen
      def register_prompt(klass)
        raise "Registry is frozen - cannot register #{klass}" if @frozen

        @prompts[klass.prompt_name] = klass
      end

      # Get all registered prompt classes.
      #
      # @return [Array<Class>] All prompt classes
      def prompts
        @prompts.values
      end

      # Find a prompt by name.
      #
      # @param name [String] Prompt name
      # @return [Class] Prompt class
      # @raise [ResourceNotFound] if prompt not found
      def find_prompt(name)
        @prompts[name] or raise RedmineMcp::ResourceNotFound, "Prompt not found: #{name}"
      end

      # ========== Lifecycle ==========

      # Freeze the registry after all classes load.
      # Call this at the end of the loader to ensure thread safety.
      def freeze!
        @tools.freeze
        @prompts.freeze
        @frozen = true
      end

      # Check if registry is frozen.
      #
      # @return [Boolean]
      def frozen?
        @frozen
      end

      # Reset registry for testing.
      # Only use in test environment!
      def reset!
        @tools = {}
        @prompts = {}
        @frozen = false
      end

      # Get registration stats (for debugging/health checks)
      #
      # @return [Hash] Stats including tool and prompt counts
      def stats
        {
          tools: @tools.size,
          prompts: @prompts.size,
          frozen: @frozen
        }
      end
    end
  end
end
