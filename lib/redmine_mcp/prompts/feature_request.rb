# frozen_string_literal: true

module RedmineMcp
  module Prompts
    # Generate a feature request template with acceptance criteria.
    # Optionally includes project context and feature title.
    class FeatureRequest < Base
      def self.prompt_name
        'feature_request'
      end

      def self.description
        'Generate a feature request template with acceptance criteria and user stories'
      end

      def self.arguments
        [
          { name: 'project_id', description: 'Project identifier for context', required: false },
          { name: 'title', description: 'Feature title or brief description', required: false }
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

        title_context = args['title'] ? "Feature: #{args['title']}\n" : ""

        {
          messages: [
            user_message(<<~PROMPT)
              Create a detailed feature request with the following structure:

              #{project_context}#{title_context}
              Please include:
              1. **Feature Title** - Clear, concise name for the feature
              2. **Problem Statement** - What problem does this solve? Why is it needed?
              3. **Proposed Solution** - High-level approach to solving the problem
              4. **User Stories** - Format: "As a [user type], I want [goal], so that [benefit]"
              5. **Acceptance Criteria** - Testable requirements (Given/When/Then format)
              6. **Out of Scope** - What this feature explicitly does NOT include
              7. **Dependencies** - Related features, systems, or requirements
              8. **Additional Context** - Mockups, examples, or related research

              Format as a professional feature specification suitable for development.
            PROMPT
          ]
        }
      end
    end

    Registry.register_prompt(FeatureRequest)
  end
end
