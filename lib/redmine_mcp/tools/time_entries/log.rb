# frozen_string_literal: true

module RedmineMcp
  module Tools
    module TimeEntries
      class Log < Base
        def self.tool_name
          'log_time'
        end

        def self.description
          'Log time to an issue or project. Requires either issue_id OR project_id (not both). Respects write protection settings.'
        end

        def self.parameters
          [
            {
              name: 'hours',
              type: 'number',
              description: 'Hours to log (e.g., 1.5 for 1 hour 30 minutes)',
              required: true
            },
            {
              name: 'activity_id',
              type: 'integer',
              description: 'Activity ID (use list_activities to get available activities)',
              required: true
            },
            {
              name: 'issue_id',
              type: 'integer',
              description: 'Issue ID to log time against (required if project_id not provided)',
              required: false
            },
            {
              name: 'project_id',
              type: 'string',
              description: 'Project identifier or ID to log time against (required if issue_id not provided)',
              required: false
            },
            {
              name: 'comments',
              type: 'string',
              description: 'Description of work done',
              required: false
            },
            {
              name: 'spent_on',
              type: 'string',
              description: 'Date when time was spent (YYYY-MM-DD, default: today)',
              required: false
            },
            {
              name: 'user_id',
              type: 'integer',
              description: 'User ID to log time for (default: current user, requires special permission for other users)',
              required: false
            }
          ]
        end

        def self.execute(params, user)
          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled,
                  'Write operations are currently disabled by administrator'
          end

          # Validate required parameters
          if params['hours'].blank?
            return error('hours parameter is required')
          end

          # Validate issue_id XOR project_id
          has_issue = params['issue_id'].present?
          has_project = params['project_id'].present?

          if !has_issue && !has_project
            return error('Either issue_id or project_id is required')
          end

          if has_issue && has_project
            return error('Cannot specify both issue_id and project_id')
          end

          # Determine project
          project = if has_issue
            issue = Issue.visible(User.current).find(params['issue_id'])
            issue.project
          else
            Project.visible(User.current).find_by(identifier: params['project_id']) ||
              Project.visible(User.current).find_by(id: params['project_id']) ||
              raise(ActiveRecord::RecordNotFound, "Project not found: #{params['project_id']}")
          end

          # Check module and permissions
          requires_module(:time_tracking, project)
          requires_permission(:log_time, project)

          # Check if logging for another user
          target_user_id = params['user_id'] || User.current.id
          if target_user_id.to_i != User.current.id
            requires_permission(:log_time_for_other_users, project)
          end

          # Validate activity is available for project
          activity = TimeEntryActivity.find(params['activity_id'])
          available_activities = project.activities
          unless available_activities.include?(activity)
            return error("Activity '#{activity.name}' is not available for project '#{project.identifier}'")
          end

          # Build time entry
          entry = TimeEntry.new
          entry.project = project
          entry.issue_id = params['issue_id'] if has_issue
          entry.user_id = target_user_id
          entry.activity_id = params['activity_id']
          entry.hours = params['hours'].to_f
          entry.comments = params['comments'] || ''
          entry.spent_on = params['spent_on'].present? ? Date.parse(params['spent_on']) : Date.today

          # Save
          if entry.save
            result = {
              id: entry.id,
              message: 'Time entry logged successfully',
              hours: entry.hours,
              project: project.identifier,
              issue_id: entry.issue_id,
              spent_on: entry.spent_on
            }
            success(result.to_json)
          else
            error("Failed to log time: #{entry.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        rescue ArgumentError => e
          error("Invalid date format: #{e.message}")
        end
      end
      Registry.register_tool(Log)
    end
  end
end
