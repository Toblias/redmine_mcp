# frozen_string_literal: true

module RedmineMcp
  module Tools
    module Users
      class GetCurrent < Base
        def self.tool_name
          'get_current_user'
        end

        def self.description
          'Get full profile of the currently authenticated user. Always returns complete information including preferences and settings.'
        end

        def self.parameters
          []
        end

        def self.execute(params, user)
          current_user = User.current

          result = {
            id: current_user.id,
            login: current_user.login,
            firstname: current_user.firstname,
            lastname: current_user.lastname,
            mail: current_user.mail,
            admin: current_user.admin?,
            status: current_user.status,
            created_on: current_user.created_on,
            last_login_on: current_user.last_login_on,
            language: current_user.language,
            time_zone: current_user.time_zone
            # Note: api_key intentionally excluded for security
          }

          success(result.to_json)
        end
      end
      Registry.register_tool(GetCurrent)
    end
  end
end
