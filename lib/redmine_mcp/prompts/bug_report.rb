# frozen_string_literal: true

module RedmineMcp
  module Prompts
    # Generate a structured bug report template with steps to reproduce.
    # Optionally includes project context and bug summary.
    class BugReport < Base
      def self.prompt_name
        'bug_report'
      end

      def self.description
        'Generate a structured bug report template with steps to reproduce'
      end

      def self.arguments
        [
          { name: 'project_id', description: 'Project identifier for context', required: false },
          { name: 'summary', description: 'Brief summary of the bug', required: false }
        ]
      end

      def self.execute(args, user)
        project_context = if args['project_id'].present?
          project = Project.visible(user).find_by(identifier: args['project_id']) ||
                    Project.visible(user).find_by(id: args['project_id'])
          raise RedmineMcp::ResourceNotFound, "Project not found: #{args['project_id']}" unless project
          "Project: #{project.name}\n"
        else
          ""
        end

        summary_context = args['summary'] ? "Summary: #{args['summary']}\n" : ""

        {
          messages: [
            user_message(<<~PROMPT)
              Create a detailed bug report with the following structure:

              #{project_context}#{summary_context}
              Please include:
              1. **Summary** - One-line description of the issue
              2. **Environment** - Browser, OS, version info
              3. **Steps to Reproduce** - Numbered steps
              4. **Expected Behavior** - What should happen
              5. **Actual Behavior** - What actually happens
              6. **Screenshots/Logs** - Placeholder for attachments
              7. **Severity** - Critical/High/Medium/Low
              8. **Additional Context** - Any other relevant info

              Format as a professional bug report suitable for a developer.
            PROMPT
          ]
        }
      end
    end

    Registry.register_prompt(BugReport)
  end
end
