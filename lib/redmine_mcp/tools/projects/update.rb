# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Projects
      class Update < Base
        def self.tool_name
          'update_project'
        end

        def self.description
          'Update an existing project. Requires edit_project permission on the project. ' \
          'Can modify name, description, visibility, parent, and enabled modules. ' \
          'Returns the updated project details on success.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Project identifier or numeric ID (required)', required: true },
            { name: 'name', type: 'string', description: 'New project name', required: false },
            { name: 'description', type: 'string', description: 'New project description', required: false },
            { name: 'homepage', type: 'string', description: 'New project homepage URL', required: false },
            { name: 'is_public', type: 'boolean', description: 'Change project visibility', required: false },
            { name: 'parent_id', type: 'string', description: 'Move project under different parent (use empty string to make root)', required: false },
            { name: 'inherit_members', type: 'boolean', description: 'Inherit members from parent project', required: false },
            { name: 'enabled_modules', type: 'array', description: 'Array of module names to enable', required: false },
            { name: 'tracker_ids', type: 'array', description: 'Array of tracker IDs to enable', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, 'Write operations are currently disabled by administrator'
          end

          # Find project
          project = Project.visible(user).find_by(identifier: params['project_id']) ||
                    Project.visible(user).find_by(id: params['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project

          # Check permission
          requires_permission(:edit_project, project)

          # Update attributes
          project.name = params['name'] if params.key?('name')
          project.description = params['description'] if params.key?('description')
          project.homepage = params['homepage'] if params.key?('homepage')
          project.is_public = params['is_public'] if params.key?('is_public')
          project.inherit_members = params['inherit_members'] if params.key?('inherit_members')

          # Handle parent change
          if params.key?('parent_id')
            if params['parent_id'].blank?
              project.parent = nil
            else
              parent = Project.visible(user).find_by(identifier: params['parent_id']) ||
                       Project.visible(user).find_by(id: params['parent_id'])
              raise RedmineMcp::ResourceNotFound, "Parent project not found: #{params['parent_id']}" unless parent

              # Check permission to move
              unless user.allowed_to?(:add_subprojects, parent)
                raise RedmineMcp::PermissionDenied, 'You do not have permission to move project under this parent'
              end
              project.parent = parent
            end
          end

          # Update trackers
          if params['tracker_ids'].present?
            project.tracker_ids = params['tracker_ids']
          end

          # Save project
          if project.save
            # Update modules after save
            if params['enabled_modules'].present?
              project.enabled_module_names = params['enabled_modules']
            end

            result = {
              id: project.id,
              identifier: project.identifier,
              name: project.name,
              description: project.description,
              homepage: project.homepage,
              is_public: project.is_public,
              status: project.status,
              updated_on: project.updated_on,
              message: 'Project updated successfully'
            }
            success(result.to_json)
          else
            error("Failed to update project: #{project.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end
      end

      Registry.register_tool(Update)
    end
  end
end
