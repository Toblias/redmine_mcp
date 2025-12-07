# frozen_string_literal: true

module RedmineMcp
  module Prompts
    # Generate a sprint/version summary from live Redmine data.
    # Queries real version data including issue counts and completion status.
    class SprintSummary < Base
      def self.prompt_name
        'sprint_summary'
      end

      def self.description
        'Generate a sprint/version summary from live Redmine data'
      end

      def self.arguments
        [
          { name: 'version_id', description: 'Version/sprint identifier', required: true }
        ]
      end

      def self.execute(args, user)
        # Validate required arguments
        unless args['version_id'].present?
          raise RedmineMcp::InvalidParams, "Missing required argument: version_id"
        end

        version = Version.find_by(id: args['version_id'])
        raise RedmineMcp::ResourceNotFound, "Version not found: #{args['version_id']}" unless version

        # Check visibility - version's project must be visible to user
        unless version.project.visible?(user)
          raise RedmineMcp::ResourceNotFound, "Version not found: #{args['version_id']}"
        end

        # Query live data
        total_issues = version.fixed_issues.visible(user).count
        closed_issues = version.fixed_issues.visible(user).where(status: IssueStatus.where(is_closed: true)).count
        open_issues = total_issues - closed_issues
        completion_pct = total_issues > 0 ? (closed_issues * 100.0 / total_issues).round(1) : 0

        # Get issues by status
        status_breakdown = version.fixed_issues.visible(user)
          .group(:status_id)
          .count
          .map { |status_id, count|
            status = IssueStatus.find(status_id)
            "  - #{status.name}: #{count}"
          }.join("\n")

        {
          messages: [
            user_message(<<~PROMPT)
              Generate a sprint summary for version '#{version.name}' in project '#{version.project.name}'.

              Sprint data:
              - Total issues: #{total_issues}
              - Closed issues: #{closed_issues}
              - Open issues: #{open_issues}
              - Completion: #{completion_pct}%
              - Due date: #{version.due_date || 'Not set'}
              - Status: #{version.status}

              Issue breakdown by status:
              #{status_breakdown}

              Please format as a professional sprint summary including:
              1. Sprint overview (goals, timeline)
              2. Completion metrics
              3. Completed work highlights
              4. Remaining work
              5. Blockers or issues
              6. Sprint velocity insights
            PROMPT
          ]
        }
      end
    end

    Registry.register_prompt(SprintSummary)
  end
end
