# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Categories
      class Delete < Base
        def self.tool_name
          'delete_category'
        end

        def self.description
          'Delete an issue category. Requires manage_issue_categories permission on the project. ' \
          'Optionally reassign issues to another category before deletion. ' \
          'If not reassigned, issues will have their category set to none.'
        end

        def self.parameters
          [
            { name: 'category_id', type: 'integer', description: 'Category ID to delete (required)', required: true },
            { name: 'reassign_to_id', type: 'integer', description: 'Category ID to reassign issues to before deletion (optional)', required: false }
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

          # Store info for response
          deleted_info = {
            id: category.id,
            name: category.name,
            project: {
              id: project.id,
              identifier: project.identifier
            }
          }

          # Count affected issues
          affected_issues = Issue.where(category_id: category.id).count

          # Reassign issues if specified
          if params['reassign_to_id'].present?
            reassign_category = IssueCategory.find_by(id: params['reassign_to_id'], project_id: project.id)
            unless reassign_category
              raise RedmineMcp::ResourceNotFound, "Reassign category not found in project: #{params['reassign_to_id']}"
            end
            Issue.where(category_id: category.id).update_all(category_id: reassign_category.id)
            deleted_info[:reassigned_to] = {
              id: reassign_category.id,
              name: reassign_category.name
            }
          end

          # Delete category
          category.destroy

          result = {
            message: 'Category deleted successfully',
            deleted_category: deleted_info,
            affected_issues: affected_issues
          }
          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Category not found: #{params['category_id']}"
        end
      end

      Registry.register_tool(Delete)
    end
  end
end
