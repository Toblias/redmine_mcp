# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Wiki
      class Update < Base
        def self.tool_name
          'update_wiki_page'
        end

        def self.description
          'Update or create a wiki page. Creates the page if it does not exist. Requires wiki module enabled, edit_wiki_pages permission, and write operations enabled.'
        end

        def self.parameters
          [
            {
              name: 'project_id',
              type: 'string',
              description: 'Project identifier or ID',
              required: true
            },
            {
              name: 'page_title',
              type: 'string',
              description: 'Wiki page title (creates if it does not exist)',
              required: true
            },
            {
              name: 'content',
              type: 'string',
              description: 'New page content (supports Textile or Markdown depending on project settings)',
              required: true
            },
            {
              name: 'comments',
              type: 'string',
              description: 'Edit comment for version history',
              required: false
            }
          ]
        end

        def self.execute(params, user)
          # Check write protection
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled,
                  'Write operations are currently disabled by administrator'
          end

          project = Project.visible(User.current).find_by(identifier: params['project_id']) ||
                    Project.visible(User.current).find_by(id: params['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project
          requires_module(:wiki, project)
          requires_permission(:edit_wiki_pages, project)

          # Create wiki if it doesn't exist
          unless project.wiki
            project.wiki = Wiki.new
            project.wiki.save!
          end

          # Find or create page
          page = project.wiki.find_page(params['page_title'])
          is_new = page.nil?

          if is_new
            page = project.wiki.pages.build(title: params['page_title'])
            page.content = WikiContent.new(page: page, author: User.current)
          end

          # Update content
          page.content.text = params['content']
          page.content.comments = params['comments'] || ''
          page.content.author = User.current

          # Save page and content (content must be saved explicitly)
          if page.save && page.content.save
            result = {
              message: is_new ? 'Wiki page created successfully' : 'Wiki page updated successfully',
              title: page.title,
              version: page.content.version,
              updated_on: page.content.updated_on
            }
            success(result.to_json)
          else
            error("Failed to save wiki page: #{page.errors.full_messages.join(', ')}")
          end
        rescue ActiveRecord::StaleObjectError
          error('Page was modified by another user. Please refresh and try again.')
        rescue ActiveRecord::RecordNotFound => e
          if e.message.include?('Project')
            raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
          else
            raise
          end
        end
      end
      Registry.register_tool(Update)
    end
  end
end
