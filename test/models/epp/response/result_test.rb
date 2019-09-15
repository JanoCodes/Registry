require 'test_helper'

class EppResponseResultTest < ActiveSupport::TestCase
  def test_description
    code = Epp::Response::Result::Code.new(:completed_successfully)
    description = 'test description'
    result = Epp::Response::Result.new(code: code)

    code.stub(:description, description) do
      assert_equal description, result.description
    end
  end
end
