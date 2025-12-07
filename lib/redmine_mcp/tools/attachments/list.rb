# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Attachments
      class List < Base
        def self.tool_name
          'list_attachments'
        end

        def self.description
          'List attachments for a specific issue, project, or wiki page. ' \
          'Returns attachment metadata including filename, size, type, description, author, and creation date. ' \
          'Respects visibility permissions - only shows attachments the user can access.'
        end

        def self.parameters
          [
            { name: 'issue_id', type: 'integer', description: 'Filter by issue ID', required: false },
            { name: 'project_id', type: 'string', description: 'Filter by project identifier or numeric ID', required: false },
            { name: 'wiki_page', type: 'string', description: 'Filter by wiki page title (requires project_id)', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Validate parameters - exactly one of issue_id, project_id, or (project_id + wiki_page)
          if params['issue_id'].present?
            attachments = get_issue_attachments(params['issue_id'], user)
          elsif params['wiki_page'].present?
            unless params['project_id'].present?
              return error('wiki_page requires project_id parameter')
            end
            attachments = get_wiki_attachments(params['project_id'], params['wiki_page'], user)
          elsif params['project_id'].present?
            attachments = get_project_attachments(params['project_id'], user)
          else
            return error('Must specify one of: issue_id, project_id, or (project_id + wiki_page)')
          end

          # Serialize attachments
          result = attachments.map { |attachment| serialize_attachment(attachment) }

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound => e
          raise RedmineMcp::ResourceNotFound, e.message
        end

        private

        def self.get_issue_attachments(issue_id, user)
          issue = Issue.visible(user).find(issue_id)
          issue.attachments.to_a
        end

        def self.get_project_attachments(project_id, user)
          project = Project.visible(user).find_by(identifier: project_id) ||
                    Project.visible(user).find_by(id: project_id)
          raise RedmineMcp::ResourceNotFound, "Project not found: #{project_id}" unless project

          # Get all attachments from issues, wiki pages, documents, etc. in this project
          attachments = []

          # Issues
          issue_ids = Issue.visible(user).where(project_id: project.id).pluck(:id)
          attachments += Attachment.where(container_type: 'Issue', container_id: issue_ids).to_a

          # Wiki pages (if wiki module enabled)
          if project.module_enabled?(:wiki) && project.wiki
            wiki_page_ids = project.wiki.pages.pluck(:id)
            attachments += Attachment.where(container_type: 'WikiPage', container_id: wiki_page_ids).to_a
          end

          # Documents (if documents module enabled)
          if project.module_enabled?(:documents)
            document_ids = project.documents.pluck(:id)
            attachments += Attachment.where(container_type: 'Document', container_id: document_ids).to_a
          end

          # Project files
          attachments += Attachment.where(container_type: 'Project', container_id: project.id).to_a

          # Sort by created_on descending
          attachments.sort_by { |a| a.created_on }.reverse
        end

        def self.get_wiki_attachments(project_id, page_title, user)
          project = Project.visible(user).find_by(identifier: project_id) ||
                    Project.visible(user).find_by(id: project_id)
          raise RedmineMcp::ResourceNotFound, "Project not found: #{project_id}" unless project

          unless project.module_enabled?(:wiki)
            raise RedmineMcp::PermissionDenied,
                  "Wiki module is disabled for project '#{project.identifier}'"
          end

          raise RedmineMcp::ResourceNotFound, 'Wiki not found for project' unless project.wiki

          page = project.wiki.find_page(page_title)
          raise RedmineMcp::ResourceNotFound, "Wiki page not found: #{page_title}" unless page

          # Check visibility
          unless page_visible?(page, user, project)
            raise RedmineMcp::ResourceNotFound, "Wiki page not found: #{page_title}"
          end

          page.attachments.to_a
        end

        def self.serialize_attachment(attachment)
          {
            id: attachment.id,
            filename: attachment.filename,
            filesize: attachment.filesize,
            content_type: attachment.content_type,
            description: attachment.description,
            author: attachment.author ? { id: attachment.author_id, name: attachment.author.name } : nil,
            created_on: attachment.created_on,
            container_type: attachment.container_type,
            container_id: attachment.container_id
          }
        end

        def self.page_visible?(page, user, project)
          page.visible?(user)
        rescue StandardError
          # Fallback for Redmine versions where visible? behaves differently
          user.allowed_to?(:view_wiki_pages, project)
        end
      end

      Registry.register_tool(List)
    end
  end
end
