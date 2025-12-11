# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Activities
        class Create < Base
          def self.tool_name
            'create_activity'
          end

          def self.description
            'Create a new time entry activity. Requires admin privileges. ' \
            'Activities categorize time entries (e.g., Development, Design, Testing, Meeting). ' \
            'Returns the created activity on success or validation errors on failure.'
          end

          def self.parameters
            [
              { name: 'name', type: 'string', description: 'Activity name (required, max 30 chars)', required: true },
              { name: 'position', type: 'integer', description: 'Sort order position', required: false },
              { name: 'is_default', type: 'boolean', description: 'Set as default activity (default: false)', required: false },
              { name: 'active', type: 'boolean', description: 'Whether activity is active (default: true)', required: false }
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

            # Build activity (TimeEntryActivity is a type of Enumeration)
            activity = TimeEntryActivity.new
            activity.name = params['name']
            activity.position = params['position'] if params['position'].present?
            activity.is_default = params['is_default'] || false
            activity.active = params['active'].nil? ? true : params['active']

            # Save activity
            if activity.save
              result = {
                id: activity.id,
                name: activity.name,
                position: activity.position,
                is_default: activity.is_default,
                active: activity.active,
                message: 'Activity created successfully'
              }
              success(result.to_json)
            else
              error("Failed to create activity: #{activity.errors.full_messages.join(', ')}")
            end
          end
        end

        Registry.register_tool(Create)
      end
    end
  end
end
