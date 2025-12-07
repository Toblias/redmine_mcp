# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Wiki
      class List < Base
        def self.tool_name
          'list_wiki_pages'
        end

        def self.description
          'List all wiki pages for a project. Requires wiki module enabled and view_wiki_pages permission.'
        end

        def self.parameters
          [
            {
              name: 'project_id',
              type: 'string',
              description: 'Project identifier or ID',
              required: true
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
            return success([].to_json)
          end

          pages = project.wiki.pages.map do |page|
            {
              title: page.title,
              parent_title: page.parent_title,
              created_on: page.created_on,
              updated_on: page.updated_on
            }
          end

          success(pages.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
        end
      end
      Registry.register_tool(List)
    end
  end
end
