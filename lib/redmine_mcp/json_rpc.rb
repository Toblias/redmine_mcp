# frozen_string_literal: true

require 'cgi'

module RedmineMcp
  # JSON-RPC 2.0 handler for MCP protocol.
  # Implements all MCP methods: initialize, tools/*, resources/*, prompts/*, ping
  #
  class JsonRpc
    PROTOCOL_VERSION = '2024-11-05'
    SERVER_VERSION = '1.0.0'

    class << self
      # Main entry point for JSON-RPC processing.
      # Handles both single requests and batch arrays.
      #
      # @param payload [Hash, Array] Parsed JSON-RPC request(s)
      # @param user [User] Current Redmine user
      # @return [Hash, Array, nil] Response(s) or nil for notifications
      def handle(payload, user)
        if payload.is_a?(Array)
          # Batch request - execute sequentially to protect DB pool
          payload.map { |request| process_single_request(request, user) }.compact
        else
          process_single_request(payload, user)
        end
      end

      private

      # Process a single JSON-RPC request.
      #
      # @param request [Hash] Single JSON-RPC request
      # @param user [User] Current Redmine user
      # @return [Hash, nil] Response or nil for notifications
      def process_single_request(request, user)
        return nil unless request.is_a?(Hash)

        method = request['method']
        id = request['id'] # nil for notifications

        result = case method
                 when 'initialize'
                   handle_initialize(request)
                 when 'notifications/initialized', 'notifications/cancelled', '$/cancelRequest'
                   nil # Notifications - no response
                 when 'ping'
                   {} # Empty result for ping
                 when 'tools/list'
                   handle_tools_list(user)
                 when 'tools/call'
                   handle_tools_call(request['params'], user)
                 when 'resources/list'
                   { resources: [] } # Empty - use templates instead
                 when 'resources/templates/list'
                   handle_resource_templates
                 when 'resources/read'
                   handle_resources_read(request['params'], user)
                 when 'prompts/list'
                   handle_prompts_list
                 when 'prompts/get'
                   handle_prompts_get(request['params'], user)
                 else
                   # Unknown method
                   return nil unless id # Don't respond to unknown notifications
                   return error_response(id, -32601, "Method not found: #{method}")
                 end

        return nil if id.nil? # Notification - no response
        success_response(id, result)
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "[MCP] Resource not found: #{e.message}"
        error_response(id, -32004, "Resource not found: #{e.message}")
      rescue RedmineMcp::WriteOperationsDisabled => e
        error_response(id, -32002, e.message)
      rescue RedmineMcp::PermissionDenied => e
        error_response(id, -32003, e.message)
      rescue RedmineMcp::ResourceNotFound => e
        error_response(id, -32004, e.message)
      rescue StandardError => e
        Rails.logger.error "[MCP] Error processing #{method}: #{e.class.name}: #{e.message}"
        Rails.logger.debug { "[MCP] Backtrace: #{e.backtrace&.first(5)&.join("\n")}" }
        safe_message = sanitize_error_message(e)
        error_response(id, -32603, safe_message)
      end

      # ========== Method Handlers ==========

      def handle_initialize(_request)
        {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: {
            tools: { listChanged: false },
            resources: { subscribe: false, listChanged: false },
            prompts: { listChanged: false }
          },
          serverInfo: {
            name: 'redmine-mcp',
            version: SERVER_VERSION
          }
        }
      end

      def handle_tools_list(user)
        tools = Registry.tools_for_user(user).map(&:to_mcp_tool)
        { tools: tools }
      end

      def handle_tools_call(params, user)
        tool_name = params['name']
        tool_params = params['arguments'] || {}

        # Check write protection for mutating tools
        write_tools = %w[create_issue update_issue delete_issue bulk_update_issues bulk_delete_issues log_time delete_time_entry update_wiki_page]
        if write_tools.include?(tool_name)
          unless Setting.plugin_redmine_mcp['enable_write_operations'] == '1'
            raise RedmineMcp::WriteOperationsDisabled,
                  'Write operations disabled by admin. Contact your Redmine administrator.'
          end
        end

        # Find and execute tool
        tool = Registry.find_tool(tool_name)
        tool.execute(tool_params, user)
      end

      def handle_resource_templates
        {
          resourceTemplates: [
            {
              uriTemplate: 'redmine://issues/{id}',
              name: 'Issue Details',
              description: 'Full issue with journals, attachments, custom fields, and related issues',
              mimeType: 'application/json'
            },
            {
              uriTemplate: 'redmine://projects/{id}',
              name: 'Project Details',
              description: 'Project info including members, versions, and enabled modules',
              mimeType: 'application/json'
            },
            {
              uriTemplate: 'redmine://projects/{project_id}/wiki/{title}',
              name: 'Wiki Page',
              description: 'Wiki page content in Textile/Markdown format with metadata',
              mimeType: 'text/markdown'
            },
            {
              uriTemplate: 'redmine://users/{id}',
              name: 'User Profile',
              description: 'User profile (admin sees all fields, others see limited info)',
              mimeType: 'application/json'
            },
            {
              uriTemplate: 'redmine://users/current',
              name: 'Current User',
              description: "Currently authenticated user's full profile",
              mimeType: 'application/json'
            },
            {
              uriTemplate: 'redmine://time_entries/{id}',
              name: 'Time Entry',
              description: 'Time entry with project, issue, activity, and user details',
              mimeType: 'application/json'
            },
            {
              uriTemplate: 'redmine://attachments/{id}',
              name: 'Attachment',
              description: 'Attachment metadata and download URL with visibility checks',
              mimeType: 'application/json'
            }
          ]
        }
      end

      def handle_resources_read(params, user)
        uri = params['uri']

        contents = case uri
                   when %r{^redmine://issues/(\d+)$}
                     issue = Issue.visible(user).find(::Regexp.last_match(1))
                     [{ uri: uri, mimeType: 'application/json',
                        text: issue_to_json(issue, include: %w[journals attachments relations children changesets], user: user) }]

                   when %r{^redmine://projects/([^/]+)$}
                     project = Project.visible(user).find(::Regexp.last_match(1))
                     [{ uri: uri, mimeType: 'application/json', text: project_to_json(project) }]

                   when %r{^redmine://projects/([^/]+)/wiki/(.+)$}
                     project = Project.visible(user).find(::Regexp.last_match(1))
                     unless project.module_enabled?(:wiki)
                       raise RedmineMcp::PermissionDenied,
                             "Wiki module is disabled for project '#{project.identifier}'"
                     end
                     page = project.wiki&.find_page(CGI.unescape(::Regexp.last_match(2)))
                     raise ActiveRecord::RecordNotFound, 'Wiki page not found' unless page
                     unless page_visible?(page, user, project)
                       raise ActiveRecord::RecordNotFound, 'Wiki page not found'
                     end
                     [{ uri: uri, mimeType: 'text/markdown', text: page.content.text }]

                   when %r{^redmine://users/current$}
                     [{ uri: uri, mimeType: 'application/json', text: user_to_json(user, user) }]

                   when %r{^redmine://users/(\d+)$}
                     target_user = User.find(::Regexp.last_match(1))
                     unless user.admin? || user_visible_to?(target_user, user)
                       raise ActiveRecord::RecordNotFound, 'User not found'
                     end
                     [{ uri: uri, mimeType: 'application/json', text: user_to_json(target_user, user) }]

                   when %r{^redmine://time_entries/(\d+)$}
                     entry = TimeEntry.visible(user).find(::Regexp.last_match(1))
                     [{ uri: uri, mimeType: 'application/json', text: time_entry_to_json(entry) }]

                   when %r{^redmine://attachments/(\d+)$}
                     attachment = Attachment.find(::Regexp.last_match(1))
                     unless attachment_visible?(attachment, user)
                       raise RedmineMcp::PermissionDenied, 'Attachment not accessible'
                     end
                     [{ uri: uri, mimeType: 'application/json', text: attachment_to_json(attachment) }]

                   else
                     raise RedmineMcp::ResourceNotFound, "Unknown resource URI: #{uri}"
                   end

        { contents: contents }
      end

      def handle_prompts_list
        prompts = Registry.prompts.map(&:to_mcp_prompt)
        { prompts: prompts }
      end

      def handle_prompts_get(params, user)
        prompt = Registry.find_prompt(params['name'])
        prompt.execute(params['arguments'] || {}, user)
      end

      # ========== Serialization Helpers ==========

      # Serialize an issue to JSON with optional includes.
      #
      # @param issue [Issue] The issue to serialize
      # @param include [Array<String>] Optional: journals, attachments, relations, children, changesets
      # @param user [User] Requesting user (for permission filtering)
      # @return [String] JSON string
      def issue_to_json(issue, include: [], user: User.current)
        data = {
          id: issue.id,
          project: { id: issue.project_id, name: issue.project.name },
          tracker: { id: issue.tracker_id, name: issue.tracker.name },
          status: { id: issue.status_id, name: issue.status.name },
          priority: { id: issue.priority_id, name: issue.priority.name },
          author: { id: issue.author_id, name: issue.author.name },
          assigned_to: issue.assigned_to ? { id: issue.assigned_to_id, name: issue.assigned_to.name } : nil,
          subject: issue.subject,
          description: issue.description,
          start_date: issue.start_date,
          due_date: issue.due_date,
          done_ratio: issue.done_ratio,
          estimated_hours: issue.estimated_hours,
          created_on: issue.created_on,
          updated_on: issue.updated_on,
          closed_on: issue.closed_on
        }

        # Custom fields (always included if user has visibility)
        data[:custom_fields] = issue.visible_custom_field_values.map do |cfv|
          { id: cfv.custom_field.id, name: cfv.custom_field.name, value: cfv.value }
        end

        # Optional includes
        if include.include?('journals')
          # Filter private notes based on permission
          journals = issue.journals.includes(:user, :details).select do |j|
            !j.private_notes? || user.allowed_to?(:view_private_notes, issue.project)
          end
          data[:journals] = journals.map do |j|
            {
              id: j.id,
              user: { id: j.user_id, name: j.user&.name },
              notes: j.notes,
              private_notes: j.private_notes?,
              created_on: j.created_on,
              details: j.details.map { |d| { property: d.property, name: d.prop_key, old: d.old_value, new: d.value } }
            }
          end
        end

        if include.include?('attachments')
          data[:attachments] = issue.attachments.map do |a|
            {
              id: a.id,
              filename: a.filename,
              filesize: a.filesize,
              content_type: a.content_type,
              author: { id: a.author_id, name: a.author&.name },
              created_on: a.created_on,
              description: a.description
            }
          end
        end

        if include.include?('relations')
          data[:relations] = issue.relations.map do |r|
            {
              id: r.id,
              relation_type: r.relation_type,
              issue_id: r.issue_from_id,
              issue_to_id: r.issue_to_id,
              delay: r.delay
            }
          end
        end

        if include.include?('children')
          # Single-level only (immediate children)
          data[:children] = issue.children.visible.map do |c|
            { id: c.id, subject: c.subject, tracker: c.tracker.name }
          end
        end

        if include.include?('changesets')
          data[:changesets] = issue.changesets.map do |cs|
            {
              revision: cs.revision,
              user: cs.user&.name,
              committed_on: cs.committed_on,
              comments: cs.comments
            }
          end
        end

        data.to_json
      end

      # Serialize a project to JSON.
      #
      # @param project [Project] The project to serialize
      # @return [String] JSON string
      def project_to_json(project)
        {
          id: project.id,
          identifier: project.identifier,
          name: project.name,
          description: project.description,
          status: project.status,
          is_public: project.is_public,
          created_on: project.created_on,
          updated_on: project.updated_on
        }.to_json
      end

      # Serialize a user to JSON with tiered response.
      #
      # @param target_user [User] User to serialize
      # @param requesting_user [User] User making the request
      # @return [String] JSON string
      def user_to_json(target_user, requesting_user)
        if requesting_user.admin? || target_user.id == requesting_user.id
          # Full profile for admins and self-lookup
          {
            id: target_user.id,
            login: target_user.login,
            firstname: target_user.firstname,
            lastname: target_user.lastname,
            mail: target_user.mail,
            admin: target_user.admin,
            status: target_user.status,
            created_on: target_user.created_on,
            last_login_on: target_user.last_login_on
          }.to_json
        else
          # Limited fields for other users
          {
            id: target_user.id,
            login: target_user.login,
            firstname: target_user.firstname,
            lastname: target_user.lastname
          }.to_json
        end
      end

      # Serialize a time entry to JSON.
      #
      # @param entry [TimeEntry] The time entry to serialize
      # @return [String] JSON string
      def time_entry_to_json(entry)
        {
          id: entry.id,
          project: { id: entry.project_id, name: entry.project.name },
          issue: entry.issue ? { id: entry.issue_id, subject: entry.issue.subject } : nil,
          user: { id: entry.user_id, name: entry.user.name },
          activity: { id: entry.activity_id, name: entry.activity.name },
          hours: entry.hours,
          comments: entry.comments,
          spent_on: entry.spent_on,
          created_on: entry.created_on,
          updated_on: entry.updated_on
        }.to_json
      end

      # Serialize an attachment to JSON with download URL.
      #
      # @param attachment [Attachment] The attachment to serialize
      # @return [String] JSON string
      def attachment_to_json(attachment)
        download_url = "/attachments/download/#{attachment.id}/#{attachment.filename}"

        {
          id: attachment.id,
          filename: attachment.filename,
          filesize: attachment.filesize,
          content_type: attachment.content_type,
          description: attachment.description,
          author: attachment.author ? { id: attachment.author_id, name: attachment.author.name } : nil,
          created_on: attachment.created_on,
          container_type: attachment.container_type,
          container_id: attachment.container_id,
          download_url: download_url,
          digest: attachment.digest
        }.to_json
      end

      # Check if attachment is visible to user based on container.
      #
      # @param attachment [Attachment] Attachment to check
      # @param user [User] User to check for
      # @return [Boolean] true if visible
      def attachment_visible?(attachment, user)
        container = attachment.container

        case container
        when Issue
          container.visible?(user)
        when WikiPage
          project = container.wiki.project
          return false unless project.module_enabled?(:wiki)
          page_visible?(container, user, project)
        when Project
          container.visible?(user)
        when Document
          container.project.visible?(user) &&
            user.allowed_to?(:view_documents, container.project)
        when Version
          container.project.visible?(user) &&
            user.allowed_to?(:view_files, container.project)
        when Message
          board = container.board
          board.project.visible?(user) &&
            user.allowed_to?(:view_messages, board.project)
        else
          false
        end
      end

      # Check if target user is visible to requesting user.
      #
      # @param target_user [User] User to check visibility for
      # @param requesting_user [User] User making the request
      # @return [Boolean] true if visible
      def user_visible_to?(target_user, requesting_user)
        return true if target_user.id == requesting_user.id
        return true if requesting_user.admin?
        return false unless target_user.active?

        # Check for shared project membership
        requesting_project_ids = requesting_user.memberships.pluck(:project_id)
        target_project_ids = target_user.memberships.pluck(:project_id)
        (requesting_project_ids & target_project_ids).any?
      end

      # ========== Response Helpers ==========

      def success_response(id, result)
        { jsonrpc: '2.0', id: id, result: result }
      end

      def error_response(id, code, message)
        { jsonrpc: '2.0', id: id, error: { code: code, message: message } }
      end

      # Sanitize error messages to avoid leaking internal details.
      #
      # @param error [StandardError] The error to sanitize
      # @return [String] Safe error message
      def sanitize_error_message(error)
        case error
        when ActiveRecord::RecordInvalid
          error.record.errors.full_messages.join(', ')
        when ActiveRecord::RecordNotFound
          'Resource not found'
        when ArgumentError, TypeError
          'Invalid parameter type or value'
        else
          'An internal error occurred while processing the request'
        end
      end

      # Check if wiki page is visible to user.
      #
      # @param page [WikiPage] Wiki page to check
      # @param user [User] User to check for
      # @param project [Project] Project context
      # @return [Boolean] true if visible
      def page_visible?(page, user, project)
        page.visible?(user)
      rescue StandardError
        # Fallback for Redmine versions where visible? behaves differently
        user.allowed_to?(:view_wiki_pages, project)
      end
    end
  end
end
