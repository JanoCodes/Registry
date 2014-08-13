module Epp
  def read_body filename
    File.read("spec/epp/requests/#{filename}")
  end

  # handles connection and login automatically
  def epp_request(data, type=:filename)
    begin
      return parse_response(server.request(read_body(data))) if type == :filename
      return parse_response(server.request(data))
    rescue Exception => e
      e
    end
  end

  def epp_plain_request filename
    begin
      parse_response(server.send_request(read_body(filename)))
    rescue Exception => e
      e
    end
  end

  def parse_response raw
    res = Nokogiri::XML(raw)

    obj = {
      results: [],
      clTRID: res.css('epp trID clTRID').text,
      parsed: res.remove_namespaces!,
      raw: raw
    }

    res.css('epp response result').each do |x|
      obj[:results] << {result_code: x[:code], msg: x.css('msg').text, value: x.css('value > *').try(:first).try(:text)}
    end

    obj[:result_code] = obj[:results][0][:result_code]
    obj[:msg] = obj[:results][0][:msg]

    obj
  end

  ### REQUEST TEMPLATES ###

  def domain_create_xml(xml_params={})
    xml_params[:nameservers] = xml_params[:nameservers] || [{hostObj: 'ns1.example.net'}, {hostObj: 'ns2.example.net'}]
    xml_params[:contacts] = xml_params[:contacts] || [
      {contact_value: 'sh8013', contact_type: 'admin'},
      {contact_value: 'sh8013', contact_type: 'tech'},
      {contact_value: 'sh801333', contact_type: 'tech'}
    ]

    # {hostAttr: {hostName: 'ns1.example.net', hostAddr_value: '192.0.2.2', hostAddr_ip}}

    xml = Builder::XmlMarkup.new

    xml.instruct!(:xml, :standalone => 'no')
    xml.epp('xmlns' => 'urn:ietf:params:xml:ns:epp-1.0') do
      xml.command do
        xml.create do
          xml.tag!('domain:create', 'xmlns:domain' => 'urn:ietf:params:xml:ns:domain-1.0') do

            xml.tag!('domain:name', (xml_params[:name] || 'example.ee')) if xml_params[:name] != false

            xml.tag!('domain:period', (xml_params[:period_value] || 1), 'unit' => (xml_params[:period_unit] || 'y')) if xml_params[:period] != false

            xml.tag!('domain:ns') do
              xml_params[:nameservers].each do |x|
                xml.tag!('domain:hostObj', x[:hostObj])
              end
            end if xml_params[:nameservers].any?

            xml.tag!('domain:registrant', (xml_params[:registrant] || 'jd1234')) if xml_params[:registrant] != false

            xml_params[:contacts].each do |x|
              xml.tag!('domain:contact', x[:contact_value], 'type' => (x[:contact_type]))
            end if xml_params[:contacts].any?

            xml.tag!('domain:authInfo') do
              xml.tag!('domain:pw', xml_params[:pw] || '2fooBAR')
            end if xml_params[:authInfo] != false
          end
        end
        xml.clTRID 'ABC-12345'
      end
    end
  end

  def domain_renew_xml(xml_params={})
    xml = Builder::XmlMarkup.new

    xml.instruct!(:xml, :standalone => 'no')
    xml.epp('xmlns' => 'urn:ietf:params:xml:ns:epp-1.0') do
      xml.command do
        xml.renew do
          xml.tag!('domain:renew', 'xmlns:domain' => 'urn:ietf:params:xml:ns:domain-1.0') do
            xml.tag!('domain:name', (xml_params[:name] || 'example.ee')) if xml_params[:name] != false
            xml.tag!('domain:curExpDate', (xml_params[:curExpDate] || '2014-08-07')) if xml_params[:curExpDate] != false
            xml.tag!('domain:period', (xml_params[:period_value] || 1), 'unit' => (xml_params[:period_unit] || 'y')) if xml_params[:period] != false
          end
        end
        xml.clTRID 'ABC-12345'
      end
    end
  end

  def domain_check_xml(xml_params={})
    xml_params[:names] = xml_params[:names] || ['example.ee']
    xml = Builder::XmlMarkup.new

    xml.instruct!(:xml, :standalone => 'no')
    xml.epp('xmlns' => 'urn:ietf:params:xml:ns:epp-1.0') do
      xml.command do
        xml.check do
          xml.tag!('domain:check', 'xmlns:domain' => 'urn:ietf:params:xml:ns:domain-1.0') do
            xml_params[:names].each do |x|
              xml.tag!('domain:name', (x || 'example.ee'))
            end if xml_params[:names].any?
          end
        end
        xml.clTRID 'ABC-12345'
      end
    end
  end
end

RSpec.configure do |c|
  c.include Epp, epp: true
end
