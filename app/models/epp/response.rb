module Epp
  class Response
    attr_reader :results
    attr_accessor :extension
    attr_accessor :command_transaction_id
    attr_accessor :transaction_id

    def self.xml_doc(xml_doc)
      result_elements = xml_doc.css('result')
      results = []

      result_elements.each do |result_element|
        code_number = result_element[:code]
        code = Result::Code.new(code_number)
        results << Result.new(code: code)
      end

      new(results: results)
    end

    def initialize(results:)
      @results = results
      @transaction_id = generate_transaction_id
    end

    def code?(code)
      results.any? { |result| result.code == code }
    end

    def to_xml
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.epp('xmlns' => 'https://epp.tld.ee/schema/epp-ee-1.0.xsd',
                'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'xsi:schemaLocation' => 'lib/schemas/epp-ee-1.0.xsd') do
          xml.response do
            results.each do |result|
              xml.result(code: result.code.to_i) do
                xml.msg(result.description)
              end
            end
          end
        end
      end

      builder.to_xml
    end

    private

    def generate_transaction_id
      "ccReg-#{format('%010d', rand(10 ** 10))}"
    end
  end
end
