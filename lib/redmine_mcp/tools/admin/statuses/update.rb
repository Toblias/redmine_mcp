# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Statuses
        class Update < Base
          def self.tool_name
            'update_status'
          end

          def self.description
            'Update an existing issue status. Requires admin privileges. ' \
            'Can modify name, closed flag, position, and default done ratio.'
          end

          def self.parameters
            [
              { name: 'status_id', type: 'integer', description: 'Status ID to update (required)', required: true },
              { name: 'name', type: 'string', description: 'New status name (max 30 chars)', required: false },
              { name: 'description', type: 'string', description: 'New status description (max 255 chars)', required: false },
              { name: 'is_closed', type: 'boolean', description: 'Whether this status marks issues as closed', required: false },
              { name: 'position', type: 'integer', description: 'New sort order position', required: false },
              { name: 'default_done_ratio', type: 'integer', description: 'Default completion percentage (0-100, null to clear)', required: false }
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

            # Update fields
            status.name = params['name'] if params['name'].present?
            status.is_closed = params['is_closed'] if params.key?('is_closed')
            status.position = params['position'] if params['position'].present?
            status.default_done_ratio = params['default_done_ratio'] if params.key?('default_done_ratio')

            # Handle description if Redmine version supports it
            if status.respond_to?(:description=) && params.key?('description')
              status.description = params['description']
            end

            # Save status
            if status.save
              result = {
                id: status.id,
                name: status.name,
                is_closed: status.is_closed,
                position: status.position,
                default_done_ratio: status.default_done_ratio,
                message: 'Issue status updated successfully'
              }
              success(result.to_json)
            else
              error("Failed to update status: #{status.errors.full_messages.join(', ')}")
            end
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Issue status not found: #{params['status_id']}"
          end
        end

        Registry.register_tool(Update)
      end
    end
  end
end
