# frozen_string_literal: true

module RedmineMcp
  module Tools
    # Abstract base class for all MCP tools.
    # Subclasses must implement: tool_name, description, execute
    # Optionally override: parameters, available_to?
    #
    class Base
      class << self
        # @return [String] Tool name for MCP registration
        def tool_name
          raise NotImplementedError, "#{self} must implement .tool_name"
        end

        # @return [String] Human-readable description for LLMs
        def description
          raise NotImplementedError, "#{self} must implement .description"
        end

        # @return [Array<Hash>] Parameter definitions
        #   Each hash: { name:, type:, description:, required:, enum: (optional) }
        def parameters
          []
        end

        # Execute the tool with given parameters.
        #
        # @param params [Hash] Tool parameters from client
        # @param user [User] Current Redmine user
        # @return [Hash] MCP tool result: { content: [...], isError: false, _meta: (optional) }
        def execute(params, user)
          raise NotImplementedError, "#{self} must implement .execute"
        end

        # Check if this tool is available to the user.
        # Override in subclasses for permission-based filtering in tools/list.
        #
        # @param user [User] Current Redmine user
        # @return [Boolean] true if tool should appear in tools/list
        def available_to?(user)
          true
        end

        # ========== Permission Helpers ==========

        # Verify user has permission, raise if not.
        #
        # @param permission [Symbol] Redmine permission (e.g., :view_issues)
        # @param project [Project] Project context
        # @raise [PermissionDenied] if user lacks permission
        def requires_permission(permission, project)
          unless user_allowed?(permission, project)
            raise RedmineMcp::PermissionDenied,
                  "You don't have permission to #{permission.to_s.humanize.downcase}"
          end
        end

        # Verify module is enabled for project, raise if not.
        #
        # @param mod [Symbol] Module name (:wiki, :time_tracking, :issue_tracking, etc.)
        # @param project [Project] Project to check
        # @raise [PermissionDenied] if module is disabled
        def requires_module(mod, project)
          unless project.module_enabled?(mod)
            raise RedmineMcp::PermissionDenied,
                  "#{mod.to_s.humanize} module is disabled for project '#{project.identifier}'"
          end
        end

        # ========== Pagination Helper ==========

        # Apply pagination to a scope using plugin settings.
        #
        # @param scope [ActiveRecord::Relation] Query scope to paginate
        # @param params [Hash] Tool params (may contain 'limit', 'offset')
        # @return [Array<ActiveRecord::Relation, Hash>] [paginated_scope, meta]
        def apply_pagination(scope, params)
          settings = Setting.plugin_redmine_mcp
          default_limit = [settings['default_limit'].to_i, 1].max
          max_limit = [settings['max_limit'].to_i, 1].max

          limit = (params['limit'] || default_limit).to_i
          limit = [[limit, 1].max, max_limit].min # Clamp between 1 and max

          offset = (params['offset'] || 0).to_i
          offset = [offset, 0].max # No negative offset

          total_count = scope.count
          paginated = scope.limit(limit).offset(offset)

          meta = {
            total: total_count,
            limit: limit,
            offset: offset,
            has_more: (offset + limit) < total_count
          }

          [paginated, meta]
        end

        # ========== Sort Helper ==========

        # Sort field mapping for issues (friendly name -> SQL column)
        ISSUE_SORT_FIELD_MAP = {
          'id' => 'issues.id',
          'project' => 'issues.project_id',
          'tracker' => 'issues.tracker_id',
          'status' => 'issues.status_id',
          'priority' => 'issues.priority_id',
          'author' => 'issues.author_id',
          'assigned_to' => 'issues.assigned_to_id',
          'updated_on' => 'issues.updated_on',
          'created_on' => 'issues.created_on',
          'start_date' => 'issues.start_date',
          'due_date' => 'issues.due_date',
          'estimated_hours' => 'issues.estimated_hours',
          'done_ratio' => 'issues.done_ratio'
        }.freeze

        # Parse sort parameter into SQL ORDER BY clause.
        # Override in tools with different sortable fields.
        #
        # @param sort_param [String, nil] Sort param (e.g., "created_on:desc")
        # @param field_map [Hash] Mapping of field names to SQL columns
        # @param default [String] Default ORDER BY clause
        # @return [String] SQL ORDER BY clause
        def parse_sort(sort_param, field_map: ISSUE_SORT_FIELD_MAP, default: 'issues.id DESC')
          return default unless sort_param.present?

          field, direction = sort_param.to_s.split(':')
          column = field_map[field]
          return default unless column

          direction = direction&.downcase == 'desc' ? 'DESC' : 'ASC'
          "#{column} #{direction}"
        end

        # ========== Response Helpers ==========

        # Build a success response.
        #
        # @param message [String] Response text (typically JSON for list tools)
        # @param meta [Hash, nil] Optional pagination metadata
        # @return [Hash] MCP tool result
        def success(message, meta: nil)
          response = {
            content: [{ type: 'text', text: message }],
            isError: false
          }
          response[:_meta] = meta if meta # Underscore prefix = non-MCP extension
          response
        end

        # Build an error response (for validation errors, not exceptions).
        #
        # @param message [String] Error message
        # @return [Hash] MCP tool result with isError: true
        def error(message)
          {
            content: [{ type: 'text', text: message }],
            isError: true
          }
        end

        # ========== MCP Format ==========

        # Generate MCP tool definition for tools/list.
        #
        # @return [Hash] MCP tool definition
        def to_mcp_tool
          {
            name: tool_name,
            description: description,
            inputSchema: {
              type: 'object',
              properties: parameters.to_h do |p|
                schema = { type: p[:type], description: p[:description] }
                schema[:enum] = p[:enum] if p[:enum]
                [p[:name], schema]
              end,
              required: parameters.select { |p| p[:required] }.map { |p| p[:name] }
            }
          }
        end

        private

        def user_allowed?(permission, project)
          User.current.allowed_to?(permission, project)
        end
      end
    end
  end
end
