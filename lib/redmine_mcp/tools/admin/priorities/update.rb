# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Priorities
        class Update < Base
          def self.tool_name
            'update_priority'
          end

          def self.description
            'Update an existing issue priority. Requires admin privileges. ' \
            'Can modify name, position, default flag, and active status.'
          end

          def self.parameters
            [
              { name: 'priority_id', type: 'integer', description: 'Priority ID to update (required)', required: true },
              { name: 'name', type: 'string', description: 'New priority name (max 30 chars)', required: false },
              { name: 'position', type: 'integer', description: 'New sort order position', required: false },
              { name: 'is_default', type: 'boolean', description: 'Set as default priority for new issues', required: false },
              { name: 'active', type: 'boolean', description: 'Whether priority is active', required: false }
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

            # Update fields
            priority.name = params['name'] if params['name'].present?
            priority.position = params['position'] if params['position'].present?
            priority.is_default = params['is_default'] if params.key?('is_default')
            priority.active = params['active'] if params.key?('active')

            # Save priority
            if priority.save
              result = {
                id: priority.id,
                name: priority.name,
                position: priority.position,
                is_default: priority.is_default,
                active: priority.active,
                message: 'Priority updated successfully'
              }
              success(result.to_json)
            else
              error("Failed to update priority: #{priority.errors.full_messages.join(', ')}")
            end
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Priority not found: #{params['priority_id']}"
          end
        end

        Registry.register_tool(Update)
      end
    end
  end
end
