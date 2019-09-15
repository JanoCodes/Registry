module Epp
  class Command
    attr_accessor :extension
    attr_accessor :transaction_id

    # class ParseError < StandardError;
    # end
    #
    # XML_SCHEMA_PATH = 'lib/schemas/all-ee-1.1.xsd'.freeze
    # private_constant :XML_SCHEMA_PATH
    #
    # class << self
    #   def xml_doc(xml_doc)
    #     validate_xml_doc(xml_doc)
    #     new
    #   end
    #
    #   private
    #
    #   def validate_xml_doc(xml_doc)
    #     schema = Nokogiri::XML::Schema(File.read(XML_SCHEMA_PATH))
    #     errors = schema.validate(xml_doc)
    #     raise ParseError unless errors.empty?
    #   end
    # end
  end
end
