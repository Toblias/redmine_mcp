# frozen_string_literal: true

module RedmineMcp
  module Tools
    module TimeEntries
      class Get < Base
        def self.tool_name
          'get_time_entry'
        end

        def self.description
          'Get details of a specific time entry by ID. Returns full information including project, issue, user, activity, hours, and comments.'
        end

        def self.parameters
          [
            {
              name: 'time_entry_id',
              type: 'integer',
              description: 'Time entry ID to retrieve',
              required: true
            }
          ]
        end

        def self.execute(params, user)
          entry = TimeEntry.visible(User.current)
                           .includes(:project, :issue, :user, :activity)
                           .find(params['time_entry_id'])
          result = serialize_time_entry(entry)
          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Time entry not found: #{params['time_entry_id']}"
        end

        def self.serialize_time_entry(entry)
          {
            id: entry.id,
            project: {
              id: entry.project_id,
              name: entry.project.name,
              identifier: entry.project.identifier
            },
            issue: entry.issue ? {
              id: entry.issue_id,
              subject: entry.issue.subject,
              tracker: entry.issue.tracker.name
            } : nil,
            user: {
              id: entry.user_id,
              name: entry.user.name,
              login: entry.user.login
            },
            activity: entry.activity ? {
              id: entry.activity_id,
              name: entry.activity.name
            } : { id: entry.activity_id, name: '(deleted activity)' },
            hours: entry.hours,
            comments: entry.comments,
            spent_on: entry.spent_on,
            created_on: entry.created_on,
            updated_on: entry.updated_on
          }
        end
      end
      Registry.register_tool(Get)
    end
  end
end
