# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class Update < Base
        def self.tool_name
          'update_issue'
        end

        def self.description
          'Update an existing issue. Can modify any issue field including status, assignee, dates, ' \
          'and custom fields. Optionally add a journal note to document the changes. ' \
          'Handles optimistic locking to prevent concurrent update conflicts.'
        end

        def self.parameters
          [
            { name: 'issue_id', type: 'integer', description: 'Issue ID to update', required: true },
            { name: 'subject', type: 'string', description: 'New subject/title', required: false },
            { name: 'description', type: 'string', description: 'New description', required: false },
            { name: 'status_id', type: 'integer', description: 'New status ID', required: false },
            { name: 'priority_id', type: 'integer', description: 'New priority ID', required: false },
            { name: 'assigned_to_id', type: 'integer', description: 'New assignee user ID (null to unassign)', required: false },
            { name: 'category_id', type: 'integer', description: 'New category ID', required: false },
            { name: 'fixed_version_id', type: 'integer', description: 'New target version ID', required: false },
            { name: 'start_date', type: 'string', description: 'New start date (YYYY-MM-DD)', required: false },
            { name: 'due_date', type: 'string', description: 'New due date (YYYY-MM-DD)', required: false },
            { name: 'estimated_hours', type: 'number', description: 'New estimated hours', required: false },
            { name: 'done_ratio', type: 'integer', description: 'New percent complete (0-100)', required: false },
            { name: 'notes', type: 'string', description: 'Journal note to document this change', required: false },
            { name: 'custom_fields', type: 'array', description: 'Array of custom field values: [{id: 1, value: "text"}, ...]', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection first
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, "Write operations are disabled by administrator"
          end

          # Find issue
          issue = Issue.visible(user).find(params['issue_id'])

          # Check permission
          requires_permission(:edit_issues, issue.project)

          # Initialize journal if notes provided or changes will be made
          issue.init_journal(user, params['notes'].to_s)

          # Update only provided attributes
          issue.subject = params['subject'] if params.key?('subject')
          issue.description = params['description'] if params.key?('description')
          issue.status_id = params['status_id'] if params.key?('status_id')
          issue.priority_id = params['priority_id'] if params.key?('priority_id')
          issue.category_id = params['category_id'] if params.key?('category_id')
          issue.fixed_version_id = params['fixed_version_id'] if params.key?('fixed_version_id')
          issue.start_date = params['start_date'] if params.key?('start_date')
          issue.due_date = params['due_date'] if params.key?('due_date')
          issue.estimated_hours = params['estimated_hours'] if params.key?('estimated_hours')
          issue.done_ratio = params['done_ratio'] if params.key?('done_ratio')

          # Handle assigned_to_id specially to allow unsetting (null)
          if params.key?('assigned_to_id')
            issue.assigned_to_id = params['assigned_to_id']
          end

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
              assigned_to: issue.assigned_to ? { id: issue.assigned_to_id, name: issue.assigned_to.name } : nil,
              updated_on: issue.updated_on
            }
            success(result.to_json)
          else
            # Return validation errors
            errors = issue.errors.full_messages.join(", ")
            error("Failed to update issue: #{errors}")
          end
        rescue ActiveRecord::StaleObjectError
          error("Issue was modified by another user. Please reload and try again.")
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Issue ##{params['issue_id']} not found or not accessible"
        end
      end

      Registry.register_tool(Update)
    end
  end
end
