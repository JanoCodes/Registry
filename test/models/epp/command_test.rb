require 'test_helper'

class Epp::CommandTest < ActiveSupport::TestCase
  def test_creates_new_instance_from_xml_document
    valid_xml = <<-XML
      <?xml version="1.0"?>
      <valid>test</valid>
    XML

    invalid_xml = <<-XML
      <?xml version="1.0"?>
      <invalid>test</invalid>
    XML

    assert_kind_of Epp::Request, Epp::Request.xml_doc(Nokogiri::XML(valid_xml))
    assert_raises Epp::Request::ParseError do
      Epp::Request.xml_doc(Nokogiri::XML(invalid_xml))
    end
  end
end
