# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Utility
      class ListCategories < Base
        def self.tool_name
          'list_categories'
        end

        def self.description
          'List issue categories for a project. Categories are used to organize issues within a project.'
        end

        def self.parameters
          [
            {
              name: 'project_id',
              type: 'string',
              description: 'Project identifier or ID',
              required: true
            }
          ]
        end

        def self.execute(params, user)
          project = Project.visible(User.current).find_by(identifier: params['project_id']) ||
                    Project.visible(User.current).find_by(id: params['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project
          categories = project.issue_categories

          result = categories.map do |c|
            {
              id: c.id,
              name: c.name,
              assigned_to_id: c.assigned_to_id
            }
          end

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
        end
      end
      Registry.register_tool(ListCategories)
    end
  end
end
