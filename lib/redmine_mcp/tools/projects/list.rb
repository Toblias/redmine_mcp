# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Projects
      class List < Base
        # Project status constants mapping
        PROJECT_STATUS_MAP = {
          'active' => Project::STATUS_ACTIVE,
          'closed' => Project::STATUS_CLOSED,
          'archived' => Project::STATUS_ARCHIVED
        }.freeze

        def self.tool_name
          'list_projects'
        end

        def self.description
          'List all projects visible to the current user. Filter by project status (active, closed, archived). ' \
          'Returns paginated results with project details including identifier, name, description, and status. ' \
          'Projects are ordered hierarchically by their position in the project tree.'
        end

        def self.parameters
          [
            { name: 'status', type: 'string', description: 'Filter by project status: active, closed, archived, or all (default: active)', required: false, enum: %w[active closed archived all] },
            { name: 'limit', type: 'integer', description: 'Maximum number of results per page', required: false },
            { name: 'offset', type: 'integer', description: 'Number of results to skip for pagination', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Start with visible projects
          scope = Project.visible(user)

          # Apply status filter (default: active)
          status_filter = params['status'].presence || 'active'
          scope = apply_status_filter(scope, status_filter)

          # Order by left (nested set ordering - hierarchical order)
          scope = scope.order(:lft)

          # Apply pagination
          paginated, meta = apply_pagination(scope, params)

          # Serialize projects
          projects = paginated.map { |project| serialize_project_basic(project) }

          success(projects.to_json, meta: meta)
        end

        private

        def self.apply_status_filter(scope, status)
          case status
          when 'active'
            scope.where(status: Project::STATUS_ACTIVE)
          when 'closed'
            scope.where(status: Project::STATUS_CLOSED)
          when 'archived'
            scope.where(status: Project::STATUS_ARCHIVED)
          when 'all'
            scope
          else
            scope # Invalid status, return unfiltered
          end
        end

        def self.serialize_project_basic(project)
          {
            id: project.id,
            identifier: project.identifier,
            name: project.name,
            description: project.description,
            status: project.status,
            is_public: project.is_public,
            created_on: project.created_on,
            updated_on: project.updated_on
          }
        end
      end

      Registry.register_tool(List)
    end
  end
end
