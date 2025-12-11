# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Versions
      class Delete < Base
        def self.tool_name
          'delete_version'
        end

        def self.description
          'Delete a version/milestone. Requires manage_versions permission on the project. ' \
          'WARNING: Cannot delete if issues are assigned to this version. ' \
          'This action cannot be undone.'
        end

        def self.parameters
          [
            { name: 'version_id', type: 'integer', description: 'Version ID to delete (required)', required: true }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, 'Write operations are currently disabled by administrator'
          end

          # Find version
          version = Version.find(params['version_id'])
          project = version.project

          # Check project visibility
          unless project.visible?(user)
            raise RedmineMcp::ResourceNotFound, "Version not found: #{params['version_id']}"
          end

          # Check permission
          requires_permission(:manage_versions, project)

          # Store info for response
          deleted_info = {
            id: version.id,
            name: version.name,
            status: version.status,
            project: {
              id: project.id,
              identifier: project.identifier
            }
          }

          # Check if version has assigned issues
          fixed_issues_count = Issue.where(fixed_version_id: version.id).count
          if fixed_issues_count > 0
            raise RedmineMcp::PermissionDenied, "Cannot delete version '#{version.name}': #{fixed_issues_count} issue(s) are assigned to it"
          end

          # Delete version
          version.destroy

          result = {
            message: 'Version deleted successfully',
            deleted_version: deleted_info
          }
          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Version not found: #{params['version_id']}"
        end
      end

      Registry.register_tool(Delete)
    end
  end
end
