require 'auth_token/auth_token_decryptor'

module Api
  module V1
    module Registrant
      class BaseController < ActionController::API
        before_action :set_cors_header
        before_action :authenticate
        before_action :set_paper_trail_whodunnit

        rescue_from ActiveRecord::RecordNotFound, with: :show_not_found_error
        rescue_from ActiveRecord::RecordInvalid, with: :show_invalid_record_error
        rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
          error = {}
          error[parameter_missing_exception.param] = ['parameter is required']
          response = { errors: [error] }
          render json: response, status: :unprocessable_entity
        end

        private

        def set_cors_header
          response.headers['Access-Control-Allow-Origin'] = request.headers['Origin']
        end

        def bearer_token
          pattern = /^Bearer /
          header  = request.headers['Authorization']
          header.gsub(pattern, '') if header&.match(pattern)
        end

        def authenticate
          decryptor = AuthTokenDecryptor.create_with_defaults(bearer_token)
          decryptor.decrypt_token

          if decryptor.valid?
            sign_in(:registrant_user, decryptor.user)
          else
            render json: { errors: [{ base: ['Not authorized'] }] },
                   status: :unauthorized
          end
        end

        # This controller does not inherit from ApplicationController,
        # so user_for_paper_trail method is not usable.
        def set_paper_trail_whodunnit
          ::PaperTrail.whodunnit = current_registrant_user.id_role_username
        end

        def show_not_found_error
          render json: { errors: [{ base: ['Not found'] }] }, status: :not_found
        end

        def show_invalid_record_error(exception)
          render json: { errors: exception.record.errors }, status: :bad_request
        end
      end
    end
  end
end
