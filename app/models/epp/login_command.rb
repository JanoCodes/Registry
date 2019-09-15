module Epp
  class LoginCommand
    attr_accessor :password
    attr_accessor :new_password

    def initialize(identifier:, password:)
      @identifier = identifier
      @password = password
    end

    def password_change?
      new_password.present?
    end
  end
end
