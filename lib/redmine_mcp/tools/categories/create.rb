# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Categories
      class Create < Base
        def self.tool_name
          'create_category'
        end

        def self.description
          'Create a new issue category in a project. Requires manage_issue_categories permission. ' \
          'Categories help organize issues within a project. ' \
          'Returns the created category on success or validation errors on failure.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Project identifier or numeric ID (required)', required: true },
            { name: 'name', type: 'string', description: 'Category name (required, max 60 chars)', required: true },
            { name: 'assigned_to_id', type: 'integer', description: 'Default assignee user ID for issues in this category', required: false }
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
          requires_permission(:manage_issue_categories, project)

          # Build category
          category = IssueCategory.new
          category.project = project
          category.name = params['name']
          category.assigned_to_id = params['assigned_to_id'] if params['assigned_to_id'].present?

          # Save category
          if category.save
            result = {
              id: category.id,
              name: category.name,
              project: {
                id: project.id,
                identifier: project.identifier,
                name: project.name
              },
              assigned_to: category.assigned_to ? {
                id: category.assigned_to.id,
                name: category.assigned_to.name
              } : nil,
              message: 'Category created successfully'
            }
            success(result.to_json)
          else
            error("Failed to create category: #{category.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end
      end

      Registry.register_tool(Create)
    end
  end
end
