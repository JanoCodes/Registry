require 'rails5_api_controller_backport'

module RegistrarApi
  module V1
    class BaseController < ActionController::API
      #rescue_from StandardError, with: :render_server_internal_error_response
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response

      private

      def current_user
        OpenStruct.new(registrar: Registrar.first)
      end

      def render_server_internal_error_response(exception)
        render json: {}, status: :internal_server_error
        log_exception(exception)
      end

      def render_not_found_response
        render json: { error: 'not found' }, status: :not_found
      end

      def log_exception(exception)
        notify_airbrake(exception)
      end
    end
  end
end
