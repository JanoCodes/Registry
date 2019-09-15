require 'test_helper'

class Epp::LoginCommandTest < ActiveSupport::TestCase
  def test_password_change
    request = Epp::LoginCommand.new(identifier: 'any', password: 'any')
    assert_not request.password_change?

    request.new_password = 'any'

    assert request.password_change?
  end
end
