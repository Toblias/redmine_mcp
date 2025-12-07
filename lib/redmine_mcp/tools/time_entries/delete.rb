# frozen_string_literal: true

module RedmineMcp
  module Tools
    module TimeEntries
      class Delete < Base
        def self.tool_name
          'delete_time_entry'
        end

        def self.description
          'Delete a time entry. Requires edit_time_entries or edit_own_time_entries permission ' \
          'and write operations must be enabled. Users can delete their own entries with ' \
          'edit_own_time_entries, or any entry with edit_time_entries permission.'
        end

        def self.parameters
          [
            { name: 'time_entry_id', type: 'integer', description: 'Time entry ID to delete', required: true }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection first
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled,
                  'Write operations are currently disabled by administrator'
          end

          # Find time entry with visibility check
          entry = TimeEntry.visible(user).find(params['time_entry_id'])

          # Check if user has permission to edit (and therefore delete) this entry
          unless entry.editable_by?(user)
            raise RedmineMcp::PermissionDenied,
                  "You don't have permission to delete this time entry"
          end

          # Store info before deletion for response
          entry_info = {
            id: entry.id,
            project: { id: entry.project_id, name: entry.project.name },
            issue: entry.issue ? { id: entry.issue_id, subject: entry.issue.subject } : nil,
            user: { id: entry.user_id, name: entry.user.name },
            hours: entry.hours,
            spent_on: entry.spent_on
          }

          # Destroy the time entry
          if entry.destroy && entry.destroyed?
            result = {
              message: 'Time entry deleted successfully',
              deleted_entry: entry_info
            }
            success(result.to_json)
          else
            # Return validation errors
            errors = entry.errors.full_messages
            if errors.any?
              error("Failed to delete time entry: #{errors.join(', ')}")
            else
              error('Unable to delete time entry')
            end
          end
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound,
                "Time entry ##{params['time_entry_id']} not found or not accessible"
        end
      end

      Registry.register_tool(Delete)
    end
  end
end
