# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Users
      class List < Base
        USER_STATUS_MAP = {
          'active' => User::STATUS_ACTIVE,
          'locked' => User::STATUS_LOCKED,
          'registered' => User::STATUS_REGISTERED
        }.freeze

        def self.tool_name
          'list_users'
        end

        def self.description
          'List users with optional filters. Admins see all users with full details. Non-admins only see users from shared projects with limited details.'
        end

        def self.parameters
          [
            {
              name: 'status',
              type: 'string',
              description: 'Filter by user status',
              required: false,
              enum: ['active', 'locked', 'registered', 'all']
            },
            {
              name: 'group_id',
              type: 'integer',
              description: 'Filter by group membership',
              required: false
            },
            {
              name: 'limit',
              type: 'integer',
              description: 'Results per page',
              required: false
            },
            {
              name: 'offset',
              type: 'integer',
              description: 'Pagination offset',
              required: false
            }
          ]
        end

        def self.execute(params, user)
          current_user = User.current
          is_admin = current_user.admin?

          # Build scope based on user privileges
          scope = if is_admin
            User.all
          else
            # Non-admins only see users from shared projects
            project_ids = current_user.memberships.pluck(:project_id)
            user_ids = Member.where(project_id: project_ids).pluck(:user_id).uniq
            User.where(id: user_ids).where(status: User::STATUS_ACTIVE)
          end

          # Apply status filter (admin only)
          if is_admin && params['status'].present? && params['status'] != 'all'
            status_code = USER_STATUS_MAP[params['status']]
            scope = scope.where(status: status_code) if status_code
          end

          # Apply group filter
          if params['group_id'].present?
            scope = scope.in_group(params['group_id'])
          end

          # Order by name
          scope = scope.order(:lastname, :firstname, :id)

          # Apply pagination
          paginated_scope, meta = apply_pagination(scope, params)

          # Serialize based on privileges
          result = paginated_scope.map do |u|
            serialize_user(u, is_admin)
          end

          success(result.to_json, meta: meta)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "Group not found: #{params['group_id']}"
        end

        def self.serialize_user(user, is_admin)
          if is_admin
            {
              id: user.id,
              login: user.login,
              firstname: user.firstname,
              lastname: user.lastname,
              mail: user.mail,
              admin: user.admin?,
              status: user.status,
              created_on: user.created_on,
              last_login_on: user.last_login_on
            }
          else
            {
              id: user.id,
              login: user.login,
              firstname: user.firstname,
              lastname: user.lastname
            }
          end
        end
      end
      Registry.register_tool(List)
    end
  end
end
