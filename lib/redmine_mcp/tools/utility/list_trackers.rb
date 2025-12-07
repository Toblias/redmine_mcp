# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Utility
      class ListTrackers < Base
        def self.tool_name
          'list_trackers'
        end

        def self.description
          'List all available issue trackers (Bug, Feature, Task, etc.)'
        end

        def self.parameters
          []
        end

        def self.execute(params, user)
          trackers = Tracker.sorted.map do |t|
            {
              id: t.id,
              name: t.name,
              default_status_id: t.default_status_id
            }
          end
          success(trackers.to_json)
        end
      end
      Registry.register_tool(ListTrackers)
    end
  end
end
