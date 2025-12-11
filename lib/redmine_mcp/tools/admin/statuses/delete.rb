# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Statuses
        class Delete < Base
          def self.tool_name
            'delete_status'
          end

          def self.description
            'Delete an issue status. Requires admin privileges. ' \
            'WARNING: Cannot delete if any issues use this status or if it is set as a tracker default. ' \
            'This action cannot be undone.'
          end

          def self.parameters
            [
              { name: 'status_id', type: 'integer', description: 'Status ID to delete (required)', required: true }
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
              raise RedmineMcp::PermissionDenied, 'Admin privileges required to manage issue statuses'
            end

            # Find status
            status = IssueStatus.find(params['status_id'])

            # Store info for response
            deleted_info = {
              id: status.id,
              name: status.name,
              is_closed: status.is_closed
            }

            # Check if status is in use
            if Issue.where(status_id: status.id).exists?
              raise RedmineMcp::PermissionDenied, "Cannot delete status '#{status.name}': it is used by existing issues"
            end

            # Check if status is used as default for any tracker
            if Tracker.where(default_status_id: status.id).exists?
              raise RedmineMcp::PermissionDenied, "Cannot delete status '#{status.name}': it is set as default for one or more trackers"
            end

            # Delete status
            status.destroy

            result = {
              message: 'Issue status deleted successfully',
              deleted_status: deleted_info
            }
            success(result.to_json)
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Issue status not found: #{params['status_id']}"
          end
        end

        Registry.register_tool(Delete)
      end
    end
  end
end
