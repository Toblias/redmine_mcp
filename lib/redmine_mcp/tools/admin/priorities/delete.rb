# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Priorities
        class Delete < Base
          def self.tool_name
            'delete_priority'
          end

          def self.description
            'Delete an issue priority. Requires admin privileges. ' \
            'WARNING: Cannot delete if any issues use this priority. ' \
            'This action cannot be undone.'
          end

          def self.parameters
            [
              { name: 'priority_id', type: 'integer', description: 'Priority ID to delete (required)', required: true }
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
              raise RedmineMcp::PermissionDenied, 'Admin privileges required to manage priorities'
            end

            # Find priority
            priority = IssuePriority.find(params['priority_id'])

            # Store info for response
            deleted_info = {
              id: priority.id,
              name: priority.name
            }

            # Check if priority is in use
            if Issue.where(priority_id: priority.id).exists?
              raise RedmineMcp::PermissionDenied, "Cannot delete priority '#{priority.name}': it is used by existing issues"
            end

            # Delete priority
            priority.destroy

            result = {
              message: 'Priority deleted successfully',
              deleted_priority: deleted_info
            }
            success(result.to_json)
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Priority not found: #{params['priority_id']}"
          end
        end

        Registry.register_tool(Delete)
      end
    end
  end
end
