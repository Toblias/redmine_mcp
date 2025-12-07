# frozen_string_literal: true

module RedmineMcp
  module Prompts
    # Generate a project status report from live Redmine data.
    # Queries real issue statistics for a specified time period.
    class StatusReport < Base
      def self.prompt_name
        'status_report'
      end

      def self.description
        'Generate a project status report from live Redmine data for a specified period'
      end

      def self.arguments
        [
          { name: 'project_id', description: 'Project identifier to report on', required: true },
          { name: 'period', description: 'Time period (e.g., "2 weeks", "30 days", "1 month")', required: false }
        ]
      end

      def self.execute(args, user)
        # Validate required arguments
        unless args['project_id'].present?
          raise RedmineMcp::InvalidParams, "Missing required argument: project_id"
        end

        project = Project.visible(user).find_by(identifier: args['project_id']) ||
                  Project.visible(user).find_by(id: args['project_id'])
        raise RedmineMcp::ResourceNotFound, "Project not found: #{args['project_id']}" unless project
        period_str = args['period'] || '2 weeks'
        period = parse_period(period_str)
        start_date = period.ago

        # Query real data - filter by user visibility
        closed_statuses = IssueStatus.where(is_closed: true).pluck(:id)
        issues_closed = project.issues.visible(user)
          .where(status_id: closed_statuses)
          .where(updated_on: start_date..Time.now).count
        issues_opened = project.issues.visible(user)
          .where(created_on: start_date..Time.now).count
        active_issues = project.issues.visible(user).open.count

        {
          messages: [
            user_message(<<~PROMPT)
              Generate a status report for project '#{project.name}' covering the last #{period_str}.

              Data summary:
              - Issues closed: #{issues_closed}
              - Issues opened: #{issues_opened}
              - Active issues: #{active_issues}

              Please format as a professional status update including:
              1. Executive summary
              2. Key accomplishments
              3. Current focus areas
              4. Blockers or risks
              5. Next steps
            PROMPT
          ]
        }
      end
    end

    Registry.register_prompt(StatusReport)
  end
end
