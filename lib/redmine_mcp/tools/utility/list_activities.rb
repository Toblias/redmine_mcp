# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Utility
      class ListActivities < Base
        def self.tool_name
          'list_activities'
        end

        def self.description
          'List time entry activities. If project_id is provided, returns activities available for that project (including inherited). Otherwise returns system-wide activities.'
        end

        def self.parameters
          [
            {
              name: 'project_id',
              type: 'string',
              description: 'Project identifier or ID (optional)',
              required: false
            }
          ]
        end

        def self.execute(params, user)
          activities = if params['project_id'].present?
            project = Project.visible(User.current).find_by(identifier: params['project_id']) ||
                      Project.visible(User.current).find_by(id: params['project_id'])
            raise ActiveRecord::RecordNotFound unless project
            project.activities
          else
            TimeEntryActivity.active
          end

          result = activities.map do |a|
            {
              id: a.id,
              name: a.name,
              is_default: a.is_default,
              active: a.active?
            }
          end

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
        end
      end
      Registry.register_tool(ListActivities)
    end
  end
end
