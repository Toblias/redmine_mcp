# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class Create < Base
        def self.tool_name
          'create_issue'
        end

        def self.description
          'Create a new issue in a project. Requires at minimum a project and subject. ' \
          'Supports setting tracker, priority, assignee, dates, custom fields, and other issue attributes. ' \
          'Returns the created issue details on success or validation errors on failure.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Project identifier or numeric ID where issue will be created', required: true },
            { name: 'subject', type: 'string', description: 'Issue subject/title (required)', required: true },
            { name: 'description', type: 'string', description: 'Issue description/details', required: false },
            { name: 'tracker_id', type: 'integer', description: 'Tracker ID (uses project default if omitted)', required: false },
            { name: 'priority_id', type: 'integer', description: 'Priority ID (uses system default if omitted)', required: false },
            { name: 'assigned_to_id', type: 'integer', description: 'Assignee user ID', required: false },
            { name: 'category_id', type: 'integer', description: 'Issue category ID', required: false },
            { name: 'fixed_version_id', type: 'integer', description: 'Target version/milestone ID', required: false },
            { name: 'start_date', type: 'string', description: 'Start date in YYYY-MM-DD format', required: false },
            { name: 'due_date', type: 'string', description: 'Due date in YYYY-MM-DD format', required: false },
            { name: 'estimated_hours', type: 'number', description: 'Estimated hours (decimal)', required: false },
            { name: 'done_ratio', type: 'integer', description: 'Percent complete (0-100)', required: false },
            { name: 'custom_fields', type: 'array', description: 'Array of custom field values: [{id: 1, value: "text"}, ...]', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection first
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, "Write operations are disabled by administrator"
          end

          # Find project
          project = Project.visible(user).find_by(identifier: params['project_id']) ||
                    Project.visible(user).find_by(id: params['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project

          # Check permission
          requires_permission(:add_issues, project)

          # Build issue
          issue = project.issues.build
          issue.author = user

          # Set subject (required)
          issue.subject = params['subject']

          # Set tracker (required - use project's first tracker as default)
          if params['tracker_id'].present?
            issue.tracker_id = params['tracker_id']
          else
            issue.tracker = project.trackers.first
          end

          # Set status (required - use first status by position as default)
          issue.status = IssueStatus.order(:position).first

          # Set optional attributes
          issue.description = params['description'] if params['description'].present?
          issue.priority_id = params['priority_id'] if params['priority_id'].present?
          issue.assigned_to_id = params['assigned_to_id'] if params['assigned_to_id'].present?
          issue.category_id = params['category_id'] if params['category_id'].present?
          issue.fixed_version_id = params['fixed_version_id'] if params['fixed_version_id'].present?
          issue.start_date = params['start_date'] if params['start_date'].present?
          issue.due_date = params['due_date'] if params['due_date'].present?
          issue.estimated_hours = params['estimated_hours'] if params['estimated_hours'].present?
          issue.done_ratio = params['done_ratio'] if params['done_ratio'].present?

          # Handle custom fields - accumulate all values first, then assign once
          if params['custom_fields'].is_a?(Array)
            cf_values = {}
            params['custom_fields'].each do |cf|
              if cf.is_a?(Hash) && cf['id'].present?
                cf_values[cf['id']] = cf['value']
              end
            end
            issue.custom_field_values = cf_values if cf_values.any?
          end

          # Save issue
          if issue.save
            result = {
              id: issue.id,
              project: { id: issue.project_id, name: issue.project.name },
              tracker: { id: issue.tracker_id, name: issue.tracker.name },
              status: { id: issue.status_id, name: issue.status.name },
              priority: { id: issue.priority_id, name: issue.priority.name },
              subject: issue.subject,
              author: { id: issue.author_id, name: issue.author.name },
              created_on: issue.created_on
            }
            success(result.to_json)
          else
            # Return validation errors
            errors = issue.errors.full_messages.join(", ")
            error("Failed to create issue: #{errors}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end
      end

      Registry.register_tool(Create)
    end
  end
end
