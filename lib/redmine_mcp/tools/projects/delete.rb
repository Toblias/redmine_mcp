# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Projects
      class Delete < Base
        def self.tool_name
          'delete_project'
        end

        def self.description
          'Delete a project and all its data. Requires admin privileges. ' \
          'WARNING: This permanently deletes the project including all issues, wiki pages, ' \
          'time entries, attachments, and subprojects. This action cannot be undone.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Project identifier or numeric ID (required)', required: true }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, 'Write operations are currently disabled by administrator'
          end

          # Find project (use unscoped to find even closed/archived projects for admins)
          project = if user.admin?
                      Project.find_by(identifier: params['project_id']) ||
                      Project.find_by(id: params['project_id'])
                    else
                      Project.visible(user).find_by(identifier: params['project_id']) ||
                      Project.visible(user).find_by(id: params['project_id'])
                    end

          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project

          # Only admins can delete projects
          unless user.admin?
            raise RedmineMcp::PermissionDenied, 'Only administrators can delete projects'
          end

          # Store info before deletion
          project_info = {
            id: project.id,
            identifier: project.identifier,
            name: project.name
          }

          # Delete the project
          if project.destroy
            result = {
              message: 'Project deleted successfully',
              deleted_project: project_info
            }
            success(result.to_json)
          else
            error("Failed to delete project: #{project.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end
      end

      Registry.register_tool(Delete)
    end
  end
end
