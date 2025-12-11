# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Admin
      module Statuses
        class Create < Base
          def self.tool_name
            'create_status'
          end

          def self.description
            'Create a new issue status. Requires admin privileges. ' \
            'Statuses define issue workflow states (e.g., New, In Progress, Closed). ' \
            'Returns the created status on success or validation errors on failure.'
          end

          def self.parameters
            [
              { name: 'name', type: 'string', description: 'Status name (required, max 30 chars)', required: true },
              { name: 'description', type: 'string', description: 'Status description (max 255 chars)', required: false },
              { name: 'is_closed', type: 'boolean', description: 'Whether this status marks issues as closed (default: false)', required: false },
              { name: 'position', type: 'integer', description: 'Sort order position', required: false },
              { name: 'default_done_ratio', type: 'integer', description: 'Default completion percentage (0-100) when issue has this status', required: false }
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

            # Build status
            status = IssueStatus.new
            status.name = params['name']
            status.is_closed = params['is_closed'] || false
            status.position = params['position'] if params['position'].present?
            status.default_done_ratio = params['default_done_ratio'] if params.key?('default_done_ratio')

            # Handle description if Redmine version supports it
            if status.respond_to?(:description=)
              status.description = params['description'] if params['description'].present?
            end

            # Save status
            if status.save
              result = {
                id: status.id,
                name: status.name,
                is_closed: status.is_closed,
                position: status.position,
                default_done_ratio: status.default_done_ratio,
                message: 'Issue status created successfully'
              }
              success(result.to_json)
            else
              error("Failed to create status: #{status.errors.full_messages.join(', ')}")
            end
          end
        end

        Registry.register_tool(Create)
      end
    end
  end
end
