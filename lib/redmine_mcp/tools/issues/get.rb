# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Issues
      class Get < Base
        def self.tool_name
          'get_issue'
        end

        def self.description
          'Retrieve a single issue by ID with full details. Optionally include related data such as ' \
          'journals (comments/history), attachments, relations, children, and changesets. ' \
          'Returns complete issue information including custom fields and detailed associations.'
        end

        def self.parameters
          [
            { name: 'issue_id', type: 'integer', description: 'Issue ID to retrieve', required: true },
            { name: 'include', type: 'string', description: 'Comma-separated list of associations to include: journals, attachments, relations, children, changesets', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Find the issue (visibility-filtered)
          issue = Issue.visible(user).find(params['issue_id'])

          # Parse include parameter
          includes = parse_includes(params['include'])

          # Serialize issue with includes
          result = serialize_issue_full(issue, includes, user)

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Issue ##{params['issue_id']} not found or not accessible"
        end

        private

        def self.parse_includes(include_param)
          return [] unless include_param.present?
          include_param.to_s.split(',').map(&:strip).select(&:present?)
        end

        def self.serialize_issue_full(issue, includes, user)
          result = {
            id: issue.id,
            project: { id: issue.project_id, name: issue.project.name, identifier: issue.project.identifier },
            tracker: { id: issue.tracker_id, name: issue.tracker.name },
            status: { id: issue.status_id, name: issue.status.name, is_closed: issue.status.is_closed },
            priority: { id: issue.priority_id, name: issue.priority.name },
            author: { id: issue.author_id, name: issue.author.name },
            assigned_to: issue.assigned_to ? { id: issue.assigned_to_id, name: issue.assigned_to.name } : nil,
            category: issue.category ? { id: issue.category_id, name: issue.category.name } : nil,
            fixed_version: issue.fixed_version ? { id: issue.fixed_version_id, name: issue.fixed_version.name } : nil,
            subject: issue.subject,
            description: issue.description,
            start_date: issue.start_date,
            due_date: issue.due_date,
            done_ratio: issue.done_ratio,
            estimated_hours: issue.estimated_hours,
            created_on: issue.created_on,
            updated_on: issue.updated_on,
            closed_on: issue.closed_on
          }

          # Add custom fields
          if issue.custom_field_values.present?
            result[:custom_fields] = issue.custom_field_values.map do |cfv|
              {
                id: cfv.custom_field.id,
                name: cfv.custom_field.name,
                value: cfv.value
              }
            end
          end

          # Add includes
          result[:journals] = serialize_journals(issue, user) if includes.include?('journals')
          result[:attachments] = serialize_attachments(issue) if includes.include?('attachments')
          result[:relations] = serialize_relations(issue, user) if includes.include?('relations')
          result[:children] = serialize_children(issue) if includes.include?('children')
          result[:changesets] = serialize_changesets(issue, user) if includes.include?('changesets')

          result
        end

        def self.serialize_journals(issue, user)
          can_view_private = user.allowed_to?(:view_private_notes, issue.project)

          issue.journals.includes(:user, :details).map do |journal|
            # Skip private journals if user doesn't have permission
            next if journal.private_notes? && !can_view_private

            {
              id: journal.id,
              user: journal.user ? { id: journal.user_id, name: journal.user.name } : nil,
              notes: journal.notes,
              created_on: journal.created_on,
              private_notes: journal.private_notes,
              details: journal.details.map do |detail|
                {
                  property: detail.property,
                  name: detail.prop_key,
                  old_value: detail.old_value,
                  new_value: detail.value
                }
              end
            }
          end.compact
        end

        def self.serialize_attachments(issue)
          issue.attachments.map do |attachment|
            {
              id: attachment.id,
              filename: attachment.filename,
              filesize: attachment.filesize,
              content_type: attachment.content_type,
              description: attachment.description,
              author: attachment.author ? { id: attachment.author_id, name: attachment.author.name } : nil,
              created_on: attachment.created_on
            }
          end
        end

        def self.serialize_relations(issue, user)
          # Collect all related issue IDs first
          relations = issue.relations.to_a
          related_issue_ids = relations.map do |r|
            r.issue_from_id == issue.id ? r.issue_to_id : r.issue_from_id
          end

          # Batch check visibility (single query instead of N queries)
          visible_issue_ids = Issue.visible(user).where(id: related_issue_ids).pluck(:id).to_set

          # Filter and serialize relations
          relations.select do |relation|
            other_issue_id = relation.issue_from_id == issue.id ? relation.issue_to_id : relation.issue_from_id
            visible_issue_ids.include?(other_issue_id)
          end.map do |relation|
            {
              id: relation.id,
              issue_id: relation.issue_from_id,
              issue_to_id: relation.issue_to_id,
              relation_type: relation.relation_type,
              delay: relation.delay
            }
          end
        end

        def self.serialize_children(issue)
          # Eager load tracker and status to prevent N+1 queries
          issue.children.visible.includes(:tracker, :status).map do |child|
            {
              id: child.id,
              tracker: { id: child.tracker_id, name: child.tracker.name },
              status: { id: child.status_id, name: child.status.name },
              subject: child.subject
            }
          end
        end

        def self.serialize_changesets(issue, user)
          # Only include changesets if user can view the repository
          return [] unless user.allowed_to?(:view_changesets, issue.project)

          issue.changesets.map do |changeset|
            {
              id: changeset.id,
              revision: changeset.revision,
              committed_on: changeset.committed_on,
              comments: changeset.comments
            }
          end
        end
      end

      Registry.register_tool(Get)
    end
  end
end
