# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Wiki
      class Get < Base
        def self.tool_name
          'get_wiki_page'
        end

        def self.description
          'Get content of a wiki page. Supports retrieving historical versions. Requires wiki module enabled and view_wiki_pages permission.'
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
              description: 'Wiki page title',
              required: true
            },
            {
              name: 'version',
              type: 'integer',
              description: 'Historical version number (optional, defaults to current version)',
              required: false
            }
          ]
        end

        def self.execute(params, user)
          project = Project.visible(User.current).find_by(identifier: params['project_id']) ||
                    Project.visible(User.current).find_by(id: params['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project
          requires_module(:wiki, project)
          requires_permission(:view_wiki_pages, project)

          unless project.wiki
            raise RedmineMcp::ResourceNotFound, "Wiki not found for project: #{params['project_id']}"
          end

          page = project.wiki.find_page(params['page_title'])
          unless page
            raise RedmineMcp::ResourceNotFound, "Wiki page not found: #{params['page_title']}"
          end

          # Get specific version if requested
          if params['version'].present?
            version_number = params['version'].to_i
            content = page.content.versions.find_by(version: version_number)
            unless content
              return error("Version #{version_number} not found for page '#{params['page_title']}'")
            end

            result = {
              title: page.title,
              content: content.text,
              author: content.author ? {
                id: content.author_id,
                name: content.author.name
              } : { id: content.author_id, name: '(deleted user)' },
              version: content.version,
              comments: content.comments,
              created_on: page.created_on,
              updated_on: content.updated_on
            }
          else
            # Get current version
            result = {
              title: page.title,
              content: page.content.text,
              author: page.content.author ? {
                id: page.content.author_id,
                name: page.content.author.name
              } : { id: page.content.author_id, name: '(deleted user)' },
              version: page.content.version,
              comments: page.content.comments,
              created_on: page.created_on,
              updated_on: page.content.updated_on
            }
          end

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound => e
          if e.message.include?('Project')
            raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
          else
            raise RedmineMcp::ResourceNotFound, e.message
          end
        end
      end
      Registry.register_tool(Get)
    end
  end
end
