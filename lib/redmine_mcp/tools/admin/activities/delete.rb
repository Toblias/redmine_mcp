# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Activities
        class Delete < Base
          def self.tool_name
            'delete_activity'
          end

          def self.description
            'Delete a time entry activity. Requires admin privileges. ' \
            'WARNING: Cannot delete if any time entries use this activity. ' \
            'This action cannot be undone.'
          end

          def self.parameters
            [
              { name: 'activity_id', type: 'integer', description: 'Activity ID to delete (required)', required: true }
            ]
          end

          def self.execute(params, user)
            User.current = user

            # Check write protection
            unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
              raise RedmineMcp::WriteOperationsDisabled, 'Write operations are currently disabled by administrator'
            end

            # Check admin privileges
            unless user.admin?
              raise RedmineMcp::PermissionDenied, 'Admin privileges required to manage activities'
            end

            # Find activity
            activity = TimeEntryActivity.find(params['activity_id'])

            # Store info for response
            deleted_info = {
              id: activity.id,
              name: activity.name
            }

            # Check if activity is in use
            if TimeEntry.where(activity_id: activity.id).exists?
              raise RedmineMcp::PermissionDenied, "Cannot delete activity '#{activity.name}': it is used by existing time entries"
            end

            # Delete activity
            activity.destroy

            result = {
              message: 'Activity deleted successfully',
              deleted_activity: deleted_info
            }
            success(result.to_json)
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Activity not found: #{params['activity_id']}"
          end
        end

        Registry.register_tool(Delete)
      end
    end
  end
end
