require 'test_helper'

class Epp::ResponseTest < ActiveSupport::TestCase
  def test_creates_new_instance_from_xml_doc
    xml = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <epp xmlns="https://epp.tld.ee/schema/epp-ee-1.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="lib/schemas/epp-ee-1.0.xsd">
        <response>
          <result code="1000">
            <msg>any</msg>
          </result>
        </response>
      </epp>
    XML

    response = Epp::Response.xml_doc(Nokogiri::XML(xml))

    assert response.code?(Epp::Response::Result::Code.new(1000))
  end

  def test_code_predicate
    present_code = Epp::Response::Result::Code.new(:completed_successfully)
    absent_code = Epp::Response::Result::Code.new(:required_parameter_missing)

    result = Epp::Response::Result.new(code: present_code)
    response = Epp::Response.new(results: [result])

    assert response.code?(present_code)
    assert_not response.code?(absent_code)
  end

  def test_to_xml
    expected_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <epp xmlns="https://epp.tld.ee/schema/epp-ee-1.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="lib/schemas/epp-ee-1.0.xsd">
        <response>
          <result code="2201">
            <msg>Authorization error</msg>
          </result>
        </response>
      </epp>
    XML

    result = Epp::Response::Result.new(code: Epp::Response::Result::Code.new(:authorization_error))
    response = Epp::Response.new(results: [result])

    assert_equal expected_xml.squish, response.to_xml.squish
  end

  def test_generates_random_transaction_id_for_every_instance
    assert_not_equal Epp::Response.new(results: []).transaction_id,
                     Epp::Response.new(results: []).transaction_id
  end

  def test_keeps_transaction_id_unchanged_when_called_multiple_times
    response = Epp::Response.new(results: [])
    assert_equal response.transaction_id, response.transaction_id
  end
end
