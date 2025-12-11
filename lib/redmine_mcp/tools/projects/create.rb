# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Projects
      class Create < Base
        def self.tool_name
          'create_project'
        end

        def self.description
          'Create a new project. Requires add_project permission. ' \
          'Supports setting name, identifier, description, parent project, and modules. ' \
          'Returns the created project details on success or validation errors on failure.'
        end

        def self.parameters
          [
            { name: 'name', type: 'string', description: 'Project name (required)', required: true },
            { name: 'identifier', type: 'string', description: 'Project identifier - lowercase letters, numbers, dashes (required)', required: true },
            { name: 'description', type: 'string', description: 'Project description', required: false },
            { name: 'homepage', type: 'string', description: 'Project homepage URL', required: false },
            { name: 'is_public', type: 'boolean', description: 'Whether project is public (default: true)', required: false },
            { name: 'parent_id', type: 'string', description: 'Parent project identifier or ID for subprojects', required: false },
            { name: 'inherit_members', type: 'boolean', description: 'Inherit members from parent project (default: false)', required: false },
            { name: 'enabled_modules', type: 'array', description: 'Array of module names to enable (e.g., ["issue_tracking", "wiki", "time_tracking"])', required: false },
            { name: 'tracker_ids', type: 'array', description: 'Array of tracker IDs to enable for this project', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, 'Write operations are currently disabled by administrator'
          end

          # Check permission to add projects
          unless user.allowed_to_globally?(:add_project)
            raise RedmineMcp::PermissionDenied, 'You do not have permission to create projects'
          end

          # Build project
          project = Project.new
          project.name = params['name']
          project.identifier = params['identifier']
          project.description = params['description'] if params['description'].present?
          project.homepage = params['homepage'] if params['homepage'].present?
          project.is_public = params['is_public'].nil? ? true : params['is_public']
          project.inherit_members = params['inherit_members'] || false

          # Set parent project if specified
          if params['parent_id'].present?
            parent = Project.visible(user).find_by(identifier: params['parent_id']) ||
                     Project.visible(user).find_by(id: params['parent_id'])
            raise RedmineMcp::ResourceNotFound, "Parent project not found: #{params['parent_id']}" unless parent

            unless user.allowed_to?(:add_subprojects, parent)
              raise RedmineMcp::PermissionDenied, 'You do not have permission to add subprojects to this project'
            end
            project.parent = parent
          end

          # Set trackers
          if params['tracker_ids'].present?
            project.tracker_ids = params['tracker_ids']
          else
            # Use all trackers by default
            project.tracker_ids = Tracker.all.pluck(:id)
          end

          # Save project
          if project.save
            # Enable modules after save
            if params['enabled_modules'].present?
              project.enabled_module_names = params['enabled_modules']
            else
              # Enable default modules
              project.enabled_module_names = Redmine::AccessControl.available_project_modules.map(&:to_s)
            end

            result = {
              id: project.id,
              identifier: project.identifier,
              name: project.name,
              description: project.description,
              is_public: project.is_public,
              status: project.status,
              created_on: project.created_on,
              message: 'Project created successfully'
            }
            success(result.to_json)
          else
            error("Failed to create project: #{project.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end
      end

      Registry.register_tool(Create)
    end
  end
end
