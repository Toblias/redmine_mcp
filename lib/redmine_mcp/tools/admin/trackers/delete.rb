# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Trackers
        class Delete < Base
          def self.tool_name
            'delete_tracker'
          end

          def self.description
            'Delete an issue tracker. Requires admin privileges. ' \
            'WARNING: Cannot delete if any issues use this tracker. ' \
            'This action cannot be undone.'
          end

          def self.parameters
            [
              { name: 'tracker_id', type: 'integer', description: 'Tracker ID to delete (required)', required: true }
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
              raise RedmineMcp::PermissionDenied, 'Admin privileges required to manage trackers'
            end

            # Find tracker
            tracker = Tracker.find(params['tracker_id'])

            # Store info for response
            deleted_info = {
              id: tracker.id,
              name: tracker.name
            }

            # Check if tracker is in use
            if Issue.where(tracker_id: tracker.id).exists?
              raise RedmineMcp::PermissionDenied, "Cannot delete tracker '#{tracker.name}': it is used by existing issues"
            end

            # Delete tracker
            tracker.destroy

            result = {
              message: 'Tracker deleted successfully',
              deleted_tracker: deleted_info
            }
            success(result.to_json)
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Tracker not found: #{params['tracker_id']}"
          end
        end

        Registry.register_tool(Delete)
      end
    end
  end
end
