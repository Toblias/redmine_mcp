# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class BulkUpdate < Base
        def self.tool_name
          'bulk_update_issues'
        end

        def self.description
          'Update multiple issues in a single operation. Can modify common fields like status, ' \
          'assignee, priority, and target version across multiple issues. Adds an optional note ' \
          'to all updated issues. Processes each issue individually to handle partial failures. ' \
          'Limited to 100 issues per call.'
        end

        def self.parameters
          [
            { name: 'issue_ids', type: 'array', description: 'Array of issue IDs to update', required: true },
            { name: 'status_id', type: 'integer', description: 'New status ID for all issues', required: false },
            { name: 'assigned_to_id', type: 'integer', description: 'New assignee user ID for all issues (null to unassign)', required: false },
            { name: 'priority_id', type: 'integer', description: 'New priority ID for all issues', required: false },
            { name: 'fixed_version_id', type: 'integer', description: 'New target version ID for all issues', required: false },
            { name: 'notes', type: 'string', description: 'Journal note to add to all updated issues', required: false }
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
            return error("Cannot update more than 100 issues at once. Requested: #{issue_ids.size}")
          end

          # Validate that we have at least one field to update
          updateable_fields = %w[status_id assigned_to_id priority_id fixed_version_id notes]
          has_updates = updateable_fields.any? { |field| params.key?(field) }
          unless has_updates
            return error("At least one field to update must be provided")
          end

          # Track results
          updated_issues = []
          failed_updates = []

          # Process each issue individually
          issue_ids.each do |issue_id|
            begin
              # Find issue and check visibility
              issue = Issue.visible(user).find(issue_id)

              # Check permission for this specific project
              unless user.allowed_to?(:edit_issues, issue.project)
                failed_updates << {
                  issue_id: issue_id,
                  reason: "No permission to edit issues in project '#{issue.project.identifier}'"
                }
                next
              end

              # Initialize journal if notes provided or changes will be made
              issue.init_journal(user, params['notes'].to_s)

              # Apply updates
              issue.status_id = params['status_id'] if params.key?('status_id')
              issue.priority_id = params['priority_id'] if params.key?('priority_id')
              issue.fixed_version_id = params['fixed_version_id'] if params.key?('fixed_version_id')

              # Handle assigned_to_id specially to allow unsetting (null)
              if params.key?('assigned_to_id')
                issue.assigned_to_id = params['assigned_to_id']
              end

              # Save issue
              if issue.save
                updated_issues << {
                  id: issue.id,
                  subject: issue.subject,
                  project: issue.project.identifier
                }
              else
                # Validation errors
                errors = issue.errors.full_messages.join(", ")
                failed_updates << {
                  issue_id: issue_id,
                  reason: errors
                }
              end

            rescue ActiveRecord::RecordNotFound
              failed_updates << {
                issue_id: issue_id,
                reason: "Issue not found or not accessible"
              }
            rescue StandardError => e
              failed_updates << {
                issue_id: issue_id,
                reason: "Error: #{e.message}"
              }
            end
          end

          # Build response
          result = {
            updated_count: updated_issues.size,
            failed_count: failed_updates.size,
            updated_issues: updated_issues,
            failed_updates: failed_updates
          }

          success(result.to_json)
        end
      end

      Registry.register_tool(BulkUpdate)
    end
  end
end
