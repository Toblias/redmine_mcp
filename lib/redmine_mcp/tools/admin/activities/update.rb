# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Activities
        class Update < Base
          def self.tool_name
            'update_activity'
          end

          def self.description
            'Update an existing time entry activity. Requires admin privileges. ' \
            'Can modify name, position, default flag, and active status.'
          end

          def self.parameters
            [
              { name: 'activity_id', type: 'integer', description: 'Activity ID to update (required)', required: true },
              { name: 'name', type: 'string', description: 'New activity name (max 30 chars)', required: false },
              { name: 'position', type: 'integer', description: 'New sort order position', required: false },
              { name: 'is_default', type: 'boolean', description: 'Set as default activity', required: false },
              { name: 'active', type: 'boolean', description: 'Whether activity is active', required: false }
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

            # Update fields
            activity.name = params['name'] if params['name'].present?
            activity.position = params['position'] if params['position'].present?
            activity.is_default = params['is_default'] if params.key?('is_default')
            activity.active = params['active'] if params.key?('active')

            # Save activity
            if activity.save
              result = {
                id: activity.id,
                name: activity.name,
                position: activity.position,
                is_default: activity.is_default,
                active: activity.active,
                message: 'Activity updated successfully'
              }
              success(result.to_json)
            else
              error("Failed to update activity: #{activity.errors.full_messages.join(', ')}")
            end
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Activity not found: #{params['activity_id']}"
          end
        end

        Registry.register_tool(Update)
      end
    end
  end
end
