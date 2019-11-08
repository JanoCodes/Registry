require 'test_helper'

class RegistrarApi::V1::JsonContactTest < ActiveSupport::TestCase
  def test_json_representation
    contact = Contact.new(uuid: 'uuid', name: 'john', email: 'john@inbox.test', phone: '+1.2',
                          ident: '1234', ident_type: 'priv', ident_country_code: 'US')
    json_contact = RegistrarApi::V1::JsonContact.new(contact)

    expected_json_hash = { id: contact.uuid,
                           name: contact.name,
                           email: contact.email,
                           phone: contact.phone,
                           identity_code: { value: contact.ident,
                                            type: contact.ident_type,
                                            country: contact.ident_country_code } }
    assert_equal expected_json_hash, json_contact.as_json
  end
end
