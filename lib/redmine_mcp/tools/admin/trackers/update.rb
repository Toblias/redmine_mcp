# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Trackers
        class Update < Base
          def self.tool_name
            'update_tracker'
          end

          def self.description
            'Update an existing issue tracker. Requires admin privileges. ' \
            'Can modify name, default status, roadmap visibility, and position.'
          end

          def self.parameters
            [
              { name: 'tracker_id', type: 'integer', description: 'Tracker ID to update (required)', required: true },
              { name: 'name', type: 'string', description: 'New tracker name (max 30 chars)', required: false },
              { name: 'default_status_id', type: 'integer', description: 'New default status ID for new issues', required: false },
              { name: 'description', type: 'string', description: 'New tracker description (max 255 chars)', required: false },
              { name: 'is_in_roadmap', type: 'boolean', description: 'Show issues in roadmap', required: false },
              { name: 'position', type: 'integer', description: 'New sort order position', required: false }
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

            # Verify new default status if specified
            if params['default_status_id'].present?
              default_status = IssueStatus.find_by(id: params['default_status_id'])
              unless default_status
                raise RedmineMcp::ResourceNotFound, "Default status not found: #{params['default_status_id']}"
              end
              tracker.default_status_id = params['default_status_id']
            end

            # Update fields
            tracker.name = params['name'] if params['name'].present?
            tracker.is_in_roadmap = params['is_in_roadmap'] if params.key?('is_in_roadmap')
            tracker.position = params['position'] if params['position'].present?

            # Handle description if Redmine version supports it
            if tracker.respond_to?(:description=) && params.key?('description')
              tracker.description = params['description']
            end

            # Save tracker
            if tracker.save
              result = {
                id: tracker.id,
                name: tracker.name,
                default_status: tracker.default_status ? {
                  id: tracker.default_status.id,
                  name: tracker.default_status.name
                } : nil,
                is_in_roadmap: tracker.is_in_roadmap,
                position: tracker.position,
                message: 'Tracker updated successfully'
              }
              success(result.to_json)
            else
              error("Failed to update tracker: #{tracker.errors.full_messages.join(', ')}")
            end
          rescue ActiveRecord::RecordNotFound
            raise RedmineMcp::ResourceNotFound, "Tracker not found: #{params['tracker_id']}"
          end
        end

        Registry.register_tool(Update)
      end
    end
  end
end
