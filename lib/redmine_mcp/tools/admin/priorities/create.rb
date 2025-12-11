# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Priorities
        class Create < Base
          def self.tool_name
            'create_priority'
          end

          def self.description
            'Create a new issue priority. Requires admin privileges. ' \
            'Priorities define issue urgency levels (e.g., Low, Normal, High, Urgent). ' \
            'Returns the created priority on success or validation errors on failure.'
          end

          def self.parameters
            [
              { name: 'name', type: 'string', description: 'Priority name (required, max 30 chars)', required: true },
              { name: 'position', type: 'integer', description: 'Sort order position', required: false },
              { name: 'is_default', type: 'boolean', description: 'Set as default priority for new issues (default: false)', required: false },
              { name: 'active', type: 'boolean', description: 'Whether priority is active (default: true)', required: false }
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

            # Build priority (IssuePriority is a type of Enumeration)
            priority = IssuePriority.new
            priority.name = params['name']
            priority.position = params['position'] if params['position'].present?
            priority.is_default = params['is_default'] || false
            priority.active = params['active'].nil? ? true : params['active']

            # Save priority
            if priority.save
              result = {
                id: priority.id,
                name: priority.name,
                position: priority.position,
                is_default: priority.is_default,
                active: priority.active,
                message: 'Priority created successfully'
              }
              success(result.to_json)
            else
              error("Failed to create priority: #{priority.errors.full_messages.join(', ')}")
            end
          end
        end

        Registry.register_tool(Create)
      end
    end
  end
end
