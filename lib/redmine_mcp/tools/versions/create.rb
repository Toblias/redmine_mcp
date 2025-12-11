# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Versions
      class Create < Base
        def self.tool_name
          'create_version'
        end

        def self.description
          'Create a new version/milestone in a project. Requires manage_versions permission. ' \
          'Versions are used to plan releases and track issue targets. ' \
          'Returns the created version on success or validation errors on failure.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Project identifier or numeric ID (required)', required: true },
            { name: 'name', type: 'string', description: 'Version name (required, max 60 chars)', required: true },
            { name: 'description', type: 'string', description: 'Version description', required: false },
            { name: 'status', type: 'string', description: 'Version status: open (default), locked, or closed', required: false, enum: %w[open locked closed] },
            { name: 'due_date', type: 'string', description: 'Target release date (YYYY-MM-DD)', required: false },
            { name: 'sharing', type: 'string', description: 'Sharing scope: none (default), descendants, hierarchy, tree, or system', required: false, enum: %w[none descendants hierarchy tree system] },
            { name: 'wiki_page_title', type: 'string', description: 'Associated wiki page title', required: false }
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
          requires_permission(:manage_versions, project)

          # Check sharing permission for system-wide sharing
          if params['sharing'] == 'system' && !user.admin?
            raise RedmineMcp::PermissionDenied, 'Admin privileges required for system-wide version sharing'
          end

          # Build version
          version = Version.new
          version.project = project
          version.name = params['name']
          version.description = params['description'] if params['description'].present?
          version.status = params['status'] || 'open'
          version.effective_date = params['due_date'] if params['due_date'].present?
          version.sharing = params['sharing'] || 'none'
          version.wiki_page_title = params['wiki_page_title'] if params['wiki_page_title'].present?

          # Save version
          if version.save
            result = {
              id: version.id,
              name: version.name,
              description: version.description,
              status: version.status,
              due_date: version.effective_date,
              sharing: version.sharing,
              project: {
                id: project.id,
                identifier: project.identifier,
                name: project.name
              },
              message: 'Version created successfully'
            }
            success(result.to_json)
          else
            error("Failed to create version: #{version.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end
      end

      Registry.register_tool(Create)
    end
  end
end
