# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Trackers
        class Create < Base
          def self.tool_name
            'create_tracker'
          end

          def self.description
            'Create a new issue tracker. Requires admin privileges. ' \
            'Trackers define issue types (e.g., Bug, Feature, Task). ' \
            'Requires at least one issue status to exist for the default_status_id. ' \
            'Returns the created tracker on success or validation errors on failure.'
          end

          def self.parameters
            [
              { name: 'name', type: 'string', description: 'Tracker name (required, max 30 chars)', required: true },
              { name: 'default_status_id', type: 'integer', description: 'Default status ID for new issues (required)', required: true },
              { name: 'description', type: 'string', description: 'Tracker description (max 255 chars)', required: false },
              { name: 'is_in_roadmap', type: 'boolean', description: 'Show issues in roadmap (default: true)', required: false },
              { name: 'position', type: 'integer', description: 'Sort order position', required: false }
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

            # Verify default status exists
            default_status = IssueStatus.find_by(id: params['default_status_id'])
            unless default_status
              raise RedmineMcp::ResourceNotFound, "Default status not found: #{params['default_status_id']}"
            end

            # Build tracker
            tracker = Tracker.new
            tracker.name = params['name']
            tracker.default_status_id = params['default_status_id']
            tracker.is_in_roadmap = params['is_in_roadmap'].nil? ? true : params['is_in_roadmap']
            tracker.position = params['position'] if params['position'].present?

            # Handle description if Redmine version supports it
            if tracker.respond_to?(:description=)
              tracker.description = params['description'] if params['description'].present?
            end

            # Save tracker
            if tracker.save
              result = {
                id: tracker.id,
                name: tracker.name,
                default_status: {
                  id: default_status.id,
                  name: default_status.name
                },
                is_in_roadmap: tracker.is_in_roadmap,
                position: tracker.position,
                message: 'Tracker created successfully'
              }
              success(result.to_json)
            else
              error("Failed to create tracker: #{tracker.errors.full_messages.join(', ')}")
            end
          end
        end

        Registry.register_tool(Create)
      end
    end
  end
end
