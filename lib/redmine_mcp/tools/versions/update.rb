# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Versions
      class Update < Base
        def self.tool_name
          'update_version'
        end

        def self.description
          'Update an existing version/milestone. Requires manage_versions permission on the project. ' \
          'Can modify name, description, status, due date, sharing scope, and wiki page link.'
        end

        def self.parameters
          [
            { name: 'version_id', type: 'integer', description: 'Version ID to update (required)', required: true },
            { name: 'name', type: 'string', description: 'New version name (max 60 chars)', required: false },
            { name: 'description', type: 'string', description: 'New version description', required: false },
            { name: 'status', type: 'string', description: 'New status: open, locked, or closed', required: false, enum: %w[open locked closed] },
            { name: 'due_date', type: 'string', description: 'New target release date (YYYY-MM-DD, empty to clear)', required: false },
            { name: 'sharing', type: 'string', description: 'New sharing scope: none, descendants, hierarchy, tree, or system', required: false, enum: %w[none descendants hierarchy tree system] },
            { name: 'wiki_page_title', type: 'string', description: 'Associated wiki page title (empty to clear)', required: false }
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

          # Check sharing permission for system-wide sharing
          if params['sharing'] == 'system' && !user.admin?
            raise RedmineMcp::PermissionDenied, 'Admin privileges required for system-wide version sharing'
          end

          # Update fields
          version.name = params['name'] if params['name'].present?
          version.description = params['description'] if params.key?('description')
          version.status = params['status'] if params['status'].present?
          version.effective_date = params['due_date'].presence if params.key?('due_date')
          version.sharing = params['sharing'] if params['sharing'].present?
          version.wiki_page_title = params['wiki_page_title'] if params.key?('wiki_page_title')

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
              message: 'Version updated successfully'
            }
            success(result.to_json)
          else
            error("Failed to update version: #{version.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Version not found: #{params['version_id']}"
        end
      end

      Registry.register_tool(Update)
    end
  end
end
