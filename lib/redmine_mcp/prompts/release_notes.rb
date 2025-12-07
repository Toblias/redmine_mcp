# frozen_string_literal: true

module RedmineMcp
  module Prompts
    # Generate release notes from live Redmine data.
    # Queries closed issues in a version, grouped by tracker.
    class ReleaseNotes < Base
      def self.prompt_name
        'release_notes'
      end

      def self.description
        'Generate release notes from live Redmine data for a version'
      end

      def self.arguments
        [
          { name: 'version_id', description: 'Version identifier to generate notes for', required: true },
          { name: 'format', description: 'Output format (markdown, plain, html)', required: false }
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

        format = args['format'] || 'markdown'

        # Query live data - group closed issues by tracker
        closed_statuses = IssueStatus.where(is_closed: true)
        issues_by_tracker = version.fixed_issues.visible(user).where(status: closed_statuses).group_by(&:tracker)

        # Build tracker summaries
        tracker_summaries = issues_by_tracker.map do |tracker, issues|
          issue_list = issues.map { |i| "  - ##{i.id}: #{i.subject}" }.join("\n")
          "#{tracker.name} (#{issues.count} issues):\n#{issue_list}"
        end.join("\n\n")

        # Get overall stats
        total_closed = version.fixed_issues.visible(user).where(status: closed_statuses).count
        total_issues = version.fixed_issues.visible(user).count

        {
          messages: [
            user_message(<<~PROMPT)
              Generate release notes for version '#{version.name}' in project '#{version.project.name}'.

              Release information:
              - Version: #{version.name}
              - Release date: #{version.effective_date || 'Not set'}
              - Description: #{version.description}
              - Total closed issues: #{total_closed} (out of #{total_issues})

              Issues by tracker:
              #{tracker_summaries}

              Please format the release notes in #{format} format including:
              1. Release highlights - key features and improvements
              2. New features - organized by functional area
              3. Bug fixes - critical and notable fixes
              4. Known issues - any unresolved problems
              5. Upgrade notes - breaking changes, migration steps, deprecations
              6. Acknowledgments - contributors if applicable

              Make it professional and user-friendly for end users and developers.
            PROMPT
          ]
        }
      end
    end

    Registry.register_prompt(ReleaseNotes)
  end
end
