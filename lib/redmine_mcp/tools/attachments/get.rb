# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Attachments
      class Get < Base
        def self.tool_name
          'get_attachment'
        end

        def self.description
          'Retrieve metadata and download URL for a specific attachment by ID. ' \
          'Returns attachment details including filename, size, content type, description, ' \
          'author, and the Redmine download URL. Respects visibility permissions.'
        end

        def self.parameters
          [
            { name: 'attachment_id', type: 'integer', description: 'Attachment ID to retrieve', required: true }
          ]
        end

        def self.execute(params, user)
          User.current = user

          attachment = Attachment.find(params['attachment_id'])

          # Check visibility based on container
          unless attachment_visible?(attachment, user)
            raise RedmineMcp::PermissionDenied,
                  "You don't have permission to view this attachment"
          end

          # Serialize attachment with download URL
          result = serialize_attachment_with_url(attachment)

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound,
                "Attachment ##{params['attachment_id']} not found"
        end

        private

        def self.attachment_visible?(attachment, user)
          container = attachment.container

          case container
          when Issue
            container.visible?(user)
          when WikiPage
            project = container.wiki.project
            return false unless project.module_enabled?(:wiki)
            page_visible?(container, user, project)
          when Project
            container.visible?(user)
          when Document
            # Documents require view_documents permission
            container.project.visible?(user) &&
              user.allowed_to?(:view_documents, container.project)
          when Version
            # Version files require view_files permission
            container.project.visible?(user) &&
              user.allowed_to?(:view_files, container.project)
          when Message
            # Forum messages
            board = container.board
            board.project.visible?(user) &&
              user.allowed_to?(:view_messages, board.project)
          else
            # Unknown container type - deny access to be safe
            false
          end
        end

        def self.serialize_attachment_with_url(attachment)
          # Build download URL: /attachments/download/{id}/{filename}
          download_url = "/attachments/download/#{attachment.id}/#{attachment.filename}"

          {
            id: attachment.id,
            filename: attachment.filename,
            filesize: attachment.filesize,
            content_type: attachment.content_type,
            description: attachment.description,
            author: attachment.author ? { id: attachment.author_id, name: attachment.author.name } : nil,
            created_on: attachment.created_on,
            container_type: attachment.container_type,
            container_id: attachment.container_id,
            download_url: download_url,
            digest: attachment.digest
          }
        end

        def self.page_visible?(page, user, project)
          page.visible?(user)
        rescue StandardError
          # Fallback for Redmine versions where visible? behaves differently
          user.allowed_to?(:view_wiki_pages, project)
        end
      end

      Registry.register_tool(Get)
    end
  end
end
