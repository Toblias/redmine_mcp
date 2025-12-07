# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Utility
      class ListPriorities < Base
        def self.tool_name
          'list_priorities'
        end

        def self.description
          'List all available issue priorities (Low, Normal, High, Urgent, etc.)'
        end

        def self.parameters
          []
        end

        def self.execute(params, user)
          priorities = IssuePriority.active.map do |p|
            {
              id: p.id,
              name: p.name,
              position: p.position,
              is_default: p.is_default
            }
          end
          success(priorities.to_json)
        end
      end
      Registry.register_tool(ListPriorities)
    end
  end
end
