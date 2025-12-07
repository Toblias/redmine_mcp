# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Users
      class Get < Base
        def self.tool_name
          'get_user'
        end

        def self.description
          'Get details of a specific user by ID. Admins and users viewing their own profile see full details. Others see limited information for users in shared projects only.'
        end

        def self.parameters
          [
            {
              name: 'user_id',
              type: 'integer',
              description: 'User ID to retrieve',
              required: true
            }
          ]
        end

        def self.execute(params, user)
          target_user = User.find(params['user_id'])
          current_user = User.current

          # Check visibility
          unless user_visible_to?(target_user, current_user)
            raise RedmineMcp::ResourceNotFound, "User not found: #{params['user_id']}"
          end

          # Determine privilege level
          is_admin = current_user.admin?
          is_self = target_user.id == current_user.id
          full_access = is_admin || is_self

          result = serialize_user(target_user, full_access)
          success(result.to_json)
        rescue ActiveRecord::RecordNotFound
          raise RedmineMcp::ResourceNotFound, "User not found: #{params['user_id']}"
        end

        def self.user_visible_to?(target_user, requesting_user)
          return true if target_user.id == requesting_user.id
          return true if requesting_user.admin?
          return false unless target_user.active?

          requesting_project_ids = requesting_user.memberships.pluck(:project_id)
          target_project_ids = target_user.memberships.pluck(:project_id)
          (requesting_project_ids & target_project_ids).any?
        end

        def self.serialize_user(user, full_access)
          if full_access
            {
              id: user.id,
              login: user.login,
              firstname: user.firstname,
              lastname: user.lastname,
              mail: user.mail,
              admin: user.admin?,
              status: user.status,
              created_on: user.created_on,
              last_login_on: user.last_login_on,
              language: user.language,
              time_zone: user.time_zone
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
      Registry.register_tool(Get)
    end
  end
end
