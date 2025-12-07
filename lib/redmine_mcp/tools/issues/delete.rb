# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class Delete < Base
        def self.tool_name
          'delete_issue'
        end

        def self.description
          'Delete an issue. Requires delete_issues permission and write operations must be enabled. ' \
          'This action is irreversible and will also delete all related journals, attachments, ' \
          'time entries, and relations. Use with caution.'
        end

        def self.parameters
          [
            { name: 'issue_id', type: 'integer', description: 'Issue ID to delete', required: true }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection first
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, "Write operations are disabled by administrator"
          end

          # Find issue with visibility check
          issue = Issue.visible(user).find(params['issue_id'])

          # Check permission
          requires_permission(:delete_issues, issue.project)

          # Store info before deletion for response
          issue_info = {
            id: issue.id,
            project: { id: issue.project_id, name: issue.project.name },
            tracker: { id: issue.tracker_id, name: issue.tracker.name },
            subject: issue.subject
          }

          # Destroy the issue
          if issue.destroy
            result = {
              message: 'Issue deleted successfully',
              deleted_issue: issue_info
            }
            success(result.to_json)
          else
            # Return validation errors (though destroy rarely fails with errors)
            errors = issue.errors.full_messages.join(", ")
            error("Failed to delete issue: #{errors}")
          end
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Issue ##{params['issue_id']} not found or not accessible"
        end
      end

      Registry.register_tool(Delete)
    end
  end
end
