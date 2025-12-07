# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Projects
      class Get < Base
        def self.tool_name
          'get_project'
        end

        def self.description
          'Retrieve detailed information about a specific project by identifier or numeric ID. ' \
          'Optionally include related data such as trackers, issue categories, enabled modules, ' \
          'and time entry activities. Returns complete project details and configurations.'
        end

        def self.parameters
          [
            { name: 'project_id', type: 'string', description: 'Project identifier (string) or numeric ID', required: true },
            { name: 'include', type: 'string', description: 'Comma-separated list of associations: trackers, issue_categories, enabled_modules, time_entry_activities', required: false }
          ]
        end

        def self.execute(params, user)
          User.current = user

          # Find project by identifier or ID
          project = Project.visible(user).find_by(identifier: params['project_id']) ||
                    Project.visible(user).find_by(id: params['project_id'])

          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}" unless project

          # Parse include parameter
          includes = parse_includes(params['include'])

          # Serialize project with includes
          result = serialize_project_full(project, includes)

          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Project not found: #{params['project_id']}"
        end

        private

        def self.parse_includes(include_param)
          return [] unless include_param.present?
          include_param.to_s.split(',').map(&:strip).select(&:present?)
        end

        def self.serialize_project_full(project, includes)
          result = {
            id: project.id,
            identifier: project.identifier,
            name: project.name,
            description: project.description,
            homepage: project.homepage,
            status: project.status,
            is_public: project.is_public,
            inherit_members: project.inherit_members,
            created_on: project.created_on,
            updated_on: project.updated_on
          }

          # Add parent project if exists
          if project.parent
            result[:parent] = {
              id: project.parent_id,
              name: project.parent.name,
              identifier: project.parent.identifier
            }
          end

          # Add custom fields
          if project.custom_field_values.present?
            result[:custom_fields] = project.custom_field_values.map do |cfv|
              {
                id: cfv.custom_field.id,
                name: cfv.custom_field.name,
                value: cfv.value
              }
            end
          end

          # Add includes
          result[:trackers] = serialize_trackers(project) if includes.include?('trackers')
          result[:issue_categories] = serialize_issue_categories(project) if includes.include?('issue_categories')
          result[:enabled_modules] = serialize_enabled_modules(project) if includes.include?('enabled_modules')
          result[:time_entry_activities] = serialize_time_entry_activities(project) if includes.include?('time_entry_activities')

          result
        end

        def self.serialize_trackers(project)
          project.trackers.map do |tracker|
            {
              id: tracker.id,
              name: tracker.name,
              default_status_id: tracker.default_status_id
            }
          end
        end

        def self.serialize_issue_categories(project)
          project.issue_categories.map do |category|
            {
              id: category.id,
              name: category.name,
              assigned_to_id: category.assigned_to_id
            }
          end
        end

        def self.serialize_enabled_modules(project)
          project.enabled_modules.map do |mod|
            {
              name: mod.name
            }
          end
        end

        def self.serialize_time_entry_activities(project)
          # Get time entry activities (either project-specific or system-wide)
          activities = project.activities
          activities.map do |activity|
            {
              id: activity.id,
              name: activity.name,
              is_default: activity.is_default,
              active: activity.active
            }
          end
        end
      end

      Registry.register_tool(Get)
    end
  end
end
