require 'test_helper'

module RegistrarApi
  module V1
    class DummyController < BaseController
      def internal_error
        raise StandardError
      end
    end
  end
end

class RegistrarApiBaseTest < EppTestCase
  def test_internal_error
    Rails.application.routes.draw do
      get 'registrar_api/internal_error', to: 'registrar_api/v1/dummy#internal_error'
    end

    begin
      get '/registrar_api/internal_error'
      assert_response :internal_server_error
    rescue
      raise
    ensure
      Rails.application.reload_routes!
    end
  end
end
