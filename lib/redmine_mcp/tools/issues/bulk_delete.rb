# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class BulkDelete < Base
        def self.tool_name
          'bulk_delete_issues'
        end

        def self.description
          'Delete multiple issues in a single operation. Processes each issue individually to ' \
          'handle partial failures. Checks delete_issues permission for each issue\'s project. ' \
          'Limited to 100 issues per call. This operation cannot be undone.'
        end

        def self.parameters
          [
            { name: 'issue_ids', type: 'array', description: 'Array of issue IDs to delete', required: true }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Check write protection first
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled, "Write operations are disabled by administrator"
          end

          # Validate issue_ids parameter
          issue_ids = params['issue_ids']
          unless issue_ids.is_a?(Array) && issue_ids.any?
            return error("issue_ids must be a non-empty array")
          end

          # Limit batch size
          if issue_ids.size > 100
            return error("Cannot delete more than 100 issues at once. Requested: #{issue_ids.size}")
          end

          # Track results
          deleted_issues = []
          failed_deletions = []

          # Process each issue individually
          issue_ids.each do |issue_id|
            begin
              # Find issue and check visibility
              issue = Issue.visible(user).find(issue_id)

              # Check permission for this specific project
              unless user.allowed_to?(:delete_issues, issue.project)
                failed_deletions << {
                  issue_id: issue_id,
                  reason: "No permission to delete issues in project '#{issue.project.identifier}'"
                }
                next
              end

              # Store info before deletion
              issue_info = {
                id: issue.id,
                subject: issue.subject,
                project: issue.project.identifier
              }

              # Delete the issue
              if issue.destroy
                deleted_issues << issue_info
              else
                # Deletion failed (e.g., callbacks prevented it)
                errors = issue.errors.full_messages.join(", ")
                failed_deletions << {
                  issue_id: issue_id,
                  reason: errors.presence || "Failed to delete issue"
                }
              end

            rescue ActiveRecord::RecordNotFound
              failed_deletions << {
                issue_id: issue_id,
                reason: "Issue not found or not accessible"
              }
            rescue StandardError => e
              failed_deletions << {
                issue_id: issue_id,
                reason: "Error: #{e.message}"
              }
            end
          end

          # Build response
          result = {
            deleted_count: deleted_issues.size,
            failed_count: failed_deletions.size,
            deleted_issues: deleted_issues,
            failed_deletions: failed_deletions
          }

          success(result.to_json)
        end
      end

      Registry.register_tool(BulkDelete)
    end
  end
end
