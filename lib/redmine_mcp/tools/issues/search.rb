# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class Search < Base
        def self.tool_name
          'search_issues'
        end

        def self.description
          'Search issues by text query. Searches both subject and description fields for matching text. ' \
          'Optionally limit search to a specific project. Returns paginated results with basic issue details.'
        end

        def self.parameters
          [
            { name: 'query', type: 'string', description: 'Search text to find in issue subject or description', required: true },
            { name: 'project_id', type: 'string', description: 'Limit search to specific project identifier or numeric ID', required: false },
            { name: 'limit', type: 'integer', description: 'Maximum number of results per page', required: false },
            { name: 'offset', type: 'integer', description: 'Number of results to skip for pagination', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Validate query parameter
          query = params['query'].to_s.strip
          if query.blank?
            return error("Search query cannot be empty")
          end

          # Start with visible issues
          scope = Issue.visible(user)

          # Apply project filter
          if params['project_id'].present?
            project = Project.visible(user).find_by(identifier: params['project_id']) ||
                      Project.visible(user).find_by(id: params['project_id'])
            raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project
            scope = scope.where(project_id: project.id)
          end

          # Apply search filter
          # Sanitize LIKE wildcards to prevent SQL injection via pattern characters
          # Use table prefix to avoid ambiguity with joined tables
          sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
          scope = scope.where("issues.subject LIKE ? OR issues.description LIKE ?", "%#{sanitized_query}%", "%#{sanitized_query}%")

          # Order by relevance (updated_on desc as proxy)
          scope = scope.order('issues.updated_on DESC')

          # Eager load associations to prevent N+1 queries
          scope = scope.includes(:project, :tracker, :status, :priority, :assigned_to)

          # Apply pagination
          paginated, meta = apply_pagination(scope, params)

          # Serialize issues
          issues = paginated.map { |issue| serialize_issue_basic(issue) }

          success(issues.to_json, meta: meta)
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end

        private

        def self.serialize_issue_basic(issue)
          {
            id: issue.id,
            project: { id: issue.project_id, name: issue.project.name },
            tracker: { id: issue.tracker_id, name: issue.tracker.name },
            status: { id: issue.status_id, name: issue.status.name },
            priority: { id: issue.priority_id, name: issue.priority.name },
            subject: issue.subject,
            assigned_to: issue.assigned_to ? { id: issue.assigned_to_id, name: issue.assigned_to.name } : nil,
            created_on: issue.created_on,
            updated_on: issue.updated_on
          }
        end
      end

      Registry.register_tool(Search)
    end
  end
end
