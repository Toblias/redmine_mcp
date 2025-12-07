# frozen_string_literal: true

require_relative '../test_helper'

class RegistryTest < ActiveSupport::TestCase
  def setup
    # Reset registry to clean state
    RedmineMcp::Registry.reset!
  end

  def teardown
    # Reset and reload the registry so other tests have tools available
    RedmineMcp::Registry.reset!
    # Reload all tool and prompt implementations
    Dir[File.join(RedmineMcp::ROOT, 'redmine_mcp/tools/**/*.rb')].sort.each do |file|
      next if file.end_with?('/base.rb')
      load file
    end
    Dir[File.join(RedmineMcp::ROOT, 'redmine_mcp/prompts/**/*.rb')].sort.each do |file|
      next if file.end_with?('/base.rb')
      load file
    end
    RedmineMcp::Registry.freeze!
  end

  # ========== Tool Registration Tests ==========

  test 'register_tool adds tool to registry' do
    # Create a mock tool class
    tool_class = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'test_tool'
      end

      def self.description
        'Test tool'
      end

      def self.execute(params, user)
        success('test')
      end
    end

    RedmineMcp::Registry.register_tool(tool_class)

    assert RedmineMcp::Registry.tools.include?(tool_class)
  end

  test 'find_tool returns registered tool' do
    tool_class = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'findable_tool'
      end

      def self.description
        'Findable'
      end
    end

    RedmineMcp::Registry.register_tool(tool_class)

    found = RedmineMcp::Registry.find_tool('findable_tool')
    assert_equal tool_class, found
  end

  test 'find_tool raises error for unknown tool' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Registry.find_tool('nonexistent_tool')
    end
  end

  test 'tools_for_user filters by available_to?' do
    available_tool = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'available_tool'
      end

      def self.description
        'Available'
      end

      def self.available_to?(user)
        true
      end
    end

    unavailable_tool = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'unavailable_tool'
      end

      def self.description
        'Unavailable'
      end

      def self.available_to?(user)
        false
      end
    end

    RedmineMcp::Registry.register_tool(available_tool)
    RedmineMcp::Registry.register_tool(unavailable_tool)

    user = User.anonymous
    available_tools = RedmineMcp::Registry.tools_for_user(user)

    assert available_tools.include?(available_tool)
    assert_not available_tools.include?(unavailable_tool)
  end

  # ========== Prompt Registration Tests ==========

  test 'register_prompt adds prompt to registry' do
    prompt_class = Class.new(RedmineMcp::Prompts::Base) do
      def self.prompt_name
        'test_prompt'
      end

      def self.description
        'Test prompt'
      end

      def self.execute(args, user)
        { messages: [] }
      end
    end

    RedmineMcp::Registry.register_prompt(prompt_class)

    assert RedmineMcp::Registry.prompts.include?(prompt_class)
  end

  test 'find_prompt returns registered prompt' do
    prompt_class = Class.new(RedmineMcp::Prompts::Base) do
      def self.prompt_name
        'findable_prompt'
      end

      def self.description
        'Findable'
      end
    end

    RedmineMcp::Registry.register_prompt(prompt_class)

    found = RedmineMcp::Registry.find_prompt('findable_prompt')
    assert_equal prompt_class, found
  end

  test 'find_prompt raises error for unknown prompt' do
    assert_raises RedmineMcp::ResourceNotFound do
      RedmineMcp::Registry.find_prompt('nonexistent_prompt')
    end
  end

  # ========== Freeze Tests ==========

  test 'freeze! prevents new registrations' do
    RedmineMcp::Registry.freeze!

    assert RedmineMcp::Registry.frozen?

    tool_class = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'late_tool'
      end

      def self.description
        'Late'
      end
    end

    assert_raises RuntimeError do
      RedmineMcp::Registry.register_tool(tool_class)
    end
  end

  test 'reset! allows new registrations after freeze' do
    RedmineMcp::Registry.freeze!
    RedmineMcp::Registry.reset!

    assert_not RedmineMcp::Registry.frozen?

    tool_class = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'reset_tool'
      end

      def self.description
        'Reset'
      end
    end

    # Should not raise
    RedmineMcp::Registry.register_tool(tool_class)
    assert RedmineMcp::Registry.tools.include?(tool_class)
  end

  # ========== Stats Tests ==========

  test 'stats returns registration counts' do
    tool_class = Class.new(RedmineMcp::Tools::Base) do
      def self.tool_name
        'stat_tool'
      end

      def self.description
        'Stat'
      end
    end

    prompt_class = Class.new(RedmineMcp::Prompts::Base) do
      def self.prompt_name
        'stat_prompt'
      end

      def self.description
        'Stat'
      end
    end

    RedmineMcp::Registry.register_tool(tool_class)
    RedmineMcp::Registry.register_prompt(prompt_class)

    stats = RedmineMcp::Registry.stats
    assert_equal 1, stats[:tools]
    assert_equal 1, stats[:prompts]
    assert_equal false, stats[:frozen]
  end
end
