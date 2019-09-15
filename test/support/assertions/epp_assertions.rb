module Assertions
  module EppAssertions
    def assert_epp_response(code_key, message = nil)
      code = Epp::Response::Result::Code.new(code_key)
      message = "Expected EPP response to contain code \"#{code.inspect}\"" \
                  " but it wasn't there. #{epp_response.inspect}" unless message

      assert epp_response.code?(code), message
    end

    def assert_no_epp_response(code_key, message = nil)
      code = Epp::Response::Result::Code.new(code_key)
      message = "Expected EPP response to not to contain code \"#{code.inspect}\"" \
                  " but there was one. #{epp_response.inspect}" unless message

      assert_not epp_response.code?(code), message
    end

    private

    def epp_response
      @epp_response = parse_http_response unless @epp_response
      @epp_response
    end

    def parse_http_response
      valid_epp_response = (response.content_type == Mime::EXTENSION_LOOKUP['xml'].to_s)
      raise "Invalid EPP response #{response.body}" unless valid_epp_response

      xml_doc = Nokogiri::XML(response.body)
      Epp::Response.xml_doc(xml_doc)
    end
  end
end
