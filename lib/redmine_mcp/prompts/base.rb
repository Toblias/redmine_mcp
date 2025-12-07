# frozen_string_literal: true

module RedmineMcp
  module Prompts
    # Abstract base class for all MCP prompts.
    # Prompts generate pre-filled message templates that help LLMs
    # create structured output using live Redmine data.
    #
    # Subclasses must implement: prompt_name, description, execute
    # Optionally override: arguments
    #
    class Base
      class << self
        # @return [String] Prompt name for MCP registration
        def prompt_name
          raise NotImplementedError, "#{self} must implement .prompt_name"
        end

        # @return [String] Human-readable description
        def description
          raise NotImplementedError, "#{self} must implement .description"
        end

        # @return [Array<Hash>] Argument definitions
        #   Each hash: { name:, description:, required: }
        def arguments
          []
        end

        # Execute the prompt with given arguments.
        #
        # @param args [Hash] Prompt arguments from client
        # @param user [User] Current Redmine user
        # @return [Hash] MCP GetPromptResult with :messages array
        def execute(args, user)
          raise NotImplementedError, "#{self} must implement .execute"
        end

        # Generate MCP prompt definition for prompts/list.
        #
        # @return [Hash] MCP prompt definition
        def to_mcp_prompt
          {
            name: prompt_name,
            description: description,
            arguments: arguments.map do |arg|
              {
                name: arg[:name],
                description: arg[:description],
                required: arg[:required] || false
              }
            end
          }
        end

        # ========== Helper Methods ==========

        # Parse period strings like "2 weeks", "30 days", "1 month"
        # into ActiveSupport::Duration.
        #
        # @param period [String] Period string
        # @return [ActiveSupport::Duration] Duration object
        # @raise [RedmineMcp::InvalidParams] If period format is invalid
        def parse_period(period)
          period_str = period.to_s.strip
          return 2.weeks if period_str.blank?

          case period_str
          when /^(\d+)\s*weeks?$/i then $1.to_i.weeks
          when /^(\d+)\s*days?$/i then $1.to_i.days
          when /^(\d+)\s*months?$/i then $1.to_i.months
          else
            raise RedmineMcp::InvalidParams,
                  "Invalid period format: '#{period}'. Use format like '2 weeks', '30 days', or '1 month'"
          end
        end

        # Build a simple user message for the prompt.
        #
        # @param text [String] Message text
        # @return [Hash] MCP message structure
        def user_message(text)
          {
            role: 'user',
            content: { type: 'text', text: text }
          }
        end
      end
    end
  end
end
