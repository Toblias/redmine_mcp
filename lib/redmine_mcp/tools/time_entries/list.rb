# frozen_string_literal: true

module RedmineMcp
  module Tools
    module TimeEntries
      class List < Base
        def self.tool_name
          'list_time_entries'
        end

        def self.description
          'List time entries with optional filters (project, issue, user, date range). Requires time tracking module enabled for project-specific queries.'
        end

        def self.parameters
          [
            {
              name: 'project_id',
              type: 'string',
              description: 'Filter by project identifier or ID',
              required: false
            },
            {
              name: 'issue_id',
              type: 'integer',
              description: 'Filter by issue ID',
              required: false
            },
            {
              name: 'user_id',
              type: 'integer',
              description: 'Filter by user ID',
              required: false
            },
            {
              name: 'from',
              type: 'string',
              description: 'Start date (YYYY-MM-DD)',
              required: false
            },
            {
              name: 'to',
              type: 'string',
              description: 'End date (YYYY-MM-DD)',
              required: false
            },
            {
              name: 'limit',
              type: 'integer',
              description: 'Results per page',
              required: false
            },
            {
              name: 'offset',
              type: 'integer',
              description: 'Pagination offset',
              required: false
            }
          ]
        end

        def self.execute(params, user)
          scope = TimeEntry.visible(User.current)

          # Filter by project
          if params['project_id'].present?
            project = Project.visible(User.current).find_by(identifier: params['project_id']) ||
                      Project.visible(User.current).find_by(id: params['project_id'])
            raise ActiveRecord::RecordNotFound unless project
            requires_module(:time_tracking, project)
            requires_permission(:view_time_entries, project)
            scope = scope.where(project_id: project.id)
          end

          # Filter by issue
          if params['issue_id'].present?
            scope = scope.where(issue_id: params['issue_id'])
          end

          # Filter by user
          if params['user_id'].present?
            scope = scope.where(user_id: params['user_id'])
          end

          # Filter by date range
          from_date = params['from'].present? ? Date.parse(params['from']) : nil
          to_date = params['to'].present? ? Date.parse(params['to']) : nil

          if from_date && to_date
            scope = scope.where(spent_on: from_date..to_date)
          elsif from_date
            scope = scope.where('spent_on >= ?', from_date)
          elsif to_date
            scope = scope.where('spent_on <= ?', to_date)
          end

          # Eager load associations to prevent N+1 queries
          scope = scope.includes(:project, :issue, :user, :activity)

          # Apply pagination
          scope = scope.order(spent_on: :desc, id: :desc)
          paginated_scope, meta = apply_pagination(scope, params)

          # Serialize results
          result = paginated_scope.map do |entry|
            serialize_time_entry(entry)
          end

          success(result.to_json, meta: meta)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
        rescue ArgumentError => e
          error("Invalid date format: #{e.message}")
        end

        def self.serialize_time_entry(entry)
          {
            id: entry.id,
            project: {
              id: entry.project_id,
              name: entry.project.name
            },
            issue: entry.issue ? {
              id: entry.issue_id,
              subject: entry.issue.subject
            } : nil,
            user: {
              id: entry.user_id,
              name: entry.user.name
            },
            activity: entry.activity ? {
              id: entry.activity_id,
              name: entry.activity.name
            } : { id: entry.activity_id, name: '(deleted activity)' },
            hours: entry.hours,
            comments: entry.comments,
            spent_on: entry.spent_on,
            created_on: entry.created_on,
            updated_on: entry.updated_on
          }
        end
      end
      Registry.register_tool(List)
    end
  end
end
