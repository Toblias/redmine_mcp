# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class List < Base
        def self.tool_name
          'list_issues'
        end

        def self.description
          'List issues with optional filters for project, status, assignee, tracker, and priority. ' \
          'Returns paginated results with issue details including project, tracker, status, priority, ' \
          'subject, assignee, and timestamps.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Filter by project identifier or numeric ID', required: false },
            { name: 'status', type: 'string', description: 'Filter by status: open, closed, or all (default: open)', required: false, enum: %w[open closed all] },
            { name: 'assigned_to_id', type: 'integer', description: 'Filter by assignee user ID', required: false },
            { name: 'tracker_id', type: 'integer', description: 'Filter by tracker ID', required: false },
            { name: 'priority_id', type: 'integer', description: 'Filter by priority ID', required: false },
            { name: 'limit', type: 'integer', description: 'Maximum number of results per page (respects server max_limit setting)', required: false },
            { name: 'offset', type: 'integer', description: 'Number of results to skip for pagination', required: false },
            { name: 'sort', type: 'string', description: 'Sort field with optional :desc suffix (e.g., "created_on:desc", "priority")', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Start with visible issues
          scope = Issue.visible(user)

          # Apply project filter
          if params['project_id'].present?
            project = Project.visible(user).find_by(identifier: params['project_id']) ||
                      Project.visible(user).find_by(id: params['project_id'])
            raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project
            scope = scope.where(project_id: project.id)
          end

          # Apply status filter (default: open)
          status_filter = params['status'].presence || 'open'
          scope = apply_status_filter(scope, status_filter)

          # Apply assignee filter
          if params['assigned_to_id'].present?
            scope = scope.where(assigned_to_id: params['assigned_to_id'])
          end

          # Apply tracker filter
          if params['tracker_id'].present?
            scope = scope.where(tracker_id: params['tracker_id'])
          end

          # Apply priority filter
          if params['priority_id'].present?
            scope = scope.where(priority_id: params['priority_id'])
          end

          # Apply sorting
          sort_clause = parse_sort(params['sort'])
          scope = scope.order(sort_clause)

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

        def self.apply_status_filter(scope, status)
          case status
          when 'open'
            scope.open
          when 'closed'
            scope.where(status: IssueStatus.where(is_closed: true))
          when 'all'
            scope
          else
            scope # Invalid status, return unfiltered
          end
        end

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

      Registry.register_tool(List)
    end
  end
end
