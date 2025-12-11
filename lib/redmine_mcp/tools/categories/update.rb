# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Categories
      class Update < Base
        def self.tool_name
          'update_category'
        end

        def self.description
          'Update an existing issue category. Requires manage_issue_categories permission on the project. ' \
          'Can modify name and default assignee.'
        end

        def self.parameters
          [
            { name: 'category_id', type: 'integer', description: 'Category ID to update (required)', required: true },
            { name: 'name', type: 'string', description: 'New category name (max 60 chars)', required: false },
            { name: 'assigned_to_id', type: 'integer', description: 'New default assignee user ID (null to clear)', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, 'Write operations are currently disabled by administrator'
          end

          # Find category
          category = IssueCategory.find(params['category_id'])
          project = category.project

          # Check project visibility
          unless project.visible?(user)
            raise RedmineMcp::ResourceNotFound, "Category not found: #{params['category_id']}"
          end

          # Check permission
          requires_permission(:manage_issue_categories, project)

          # Update fields
          category.name = params['name'] if params['name'].present?
          category.assigned_to_id = params['assigned_to_id'] if params.key?('assigned_to_id')

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
              message: 'Category updated successfully'
            }
            success(result.to_json)
          else
            error("Failed to update category: #{category.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Category not found: #{params['category_id']}"
        end
      end

      Registry.register_tool(Update)
    end
  end
end
