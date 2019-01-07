require 'test_helper'

class DNS::DomainNameTest < ActiveSupport::TestCase
  def test_unavailable_when_registered
    domain_name = DNS::DomainName.new('shop.test')
    assert_equal 'shop.test', domains(:shop).name

    assert domain_name.unavailable?
    assert_equal :registered, domain_name.unavailability_reason
  end

  def test_unavailable_when_blocked
    domain_name = DNS::DomainName.new('blocked.test')
    assert_equal 'blocked.test', blocked_domains(:one).name

    assert domain_name.unavailable?
    assert_equal :blocked, domain_name.unavailability_reason
  end
end
