# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Utility
      class ListVersions < Base
        def self.tool_name
          'list_versions'
        end

        def self.description
          'List versions (milestones/releases) for a project. Can filter by status (open, locked, closed, all).'
        end

        def self.parameters
          [
            {
              name: 'project_id',
              type: 'string',
              description: 'Project identifier or ID',
              required: true
            },
            {
              name: 'status',
              type: 'string',
              description: 'Filter by status',
              required: false,
              enum: ['open', 'locked', 'closed', 'all']
            }
          ]
        end

        def self.execute(params, user)
          project = Project.visible(User.current).find_by(identifier: params['project_id']) ||
                    Project.visible(User.current).find_by(id: params['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project
          versions = project.shared_versions

          # Apply status filter
          status = params['status']
          if status.present? && status != 'all'
            versions = versions.select { |v| v.status == status }
          end

          result = versions.map do |v|
            {
              id: v.id,
              name: v.name,
              description: v.description,
              status: v.status,
              due_date: v.due_date,
              sharing: v.sharing
            }
          end

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
        end
      end
      Registry.register_tool(ListVersions)
    end
  end
end
