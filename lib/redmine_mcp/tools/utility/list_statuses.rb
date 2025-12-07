# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Utility
      class ListStatuses < Base
        def self.tool_name
          'list_statuses'
        end

        def self.description
          'List all available issue statuses (New, In Progress, Resolved, etc.)'
        end

        def self.parameters
          []
        end

        def self.execute(params, user)
          statuses = IssueStatus.sorted.map do |s|
            {
              id: s.id,
              name: s.name,
              is_closed: s.is_closed
            }
          end
          success(statuses.to_json)
        end
      end
      Registry.register_tool(ListStatuses)
    end
  end
end
