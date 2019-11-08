require 'test_helper'

class RegistrarApiV1ContactsTest < ActionDispatch::IntegrationTest
  def test_creates_contact
    name = 'john'
    email = 'john@inbox.test'
    phone = '+1.2'
    ident = '1'
    ident_type = 'priv'
    ident_country_code = 'US'

    assert_difference 'Contact.count' do
      post registrar_api_v1_contacts_path, { name: name,
                                             email: email,
                                             phone: phone,
                                             identity_code: { value: ident,
                                                              type: ident_type,
                                                              country: ident_country_code } }
    end

    contact = Contact.last
    assert_equal name, contact.name
    assert_equal email, contact.email
    assert_equal phone, contact.phone

    response_json = ActiveSupport::JSON.decode(response.body).deep_symbolize_keys
    assert_equal RegistrarApi::V1::JsonContact.new(contact).as_json, response_json
    assert_response :ok
  end

  def test_returns_contact_details
    contact = contacts(:john)

    get registrar_api_v1_contact_path(contact)

    response_json = ActiveSupport::JSON.decode(response.body).deep_symbolize_keys
    assert_equal RegistrarApi::V1::JsonContact.new(contact).as_json, response_json
    assert_response :ok
  end

  def test_updates_contact
    contact = contacts(:john)
    new_name = 'jane'
    new_email = 'new@inbox.test'
    new_phone = '+1.2'
    assert_not_equal new_name, contact.name
    assert_not_equal new_email, contact.email
    assert_not_equal new_phone, contact.phone

    patch registrar_api_v1_contact_path(contact), { name: new_name,
                                                    email: new_email,
                                                    phone: new_phone }
    contact.reload

    assert_equal new_name, contact.name
    assert_equal new_email, contact.email
    assert_equal new_phone, contact.phone

    response_json = ActiveSupport::JSON.decode(response.body).deep_symbolize_keys
    assert_equal RegistrarApi::V1::JsonContact.new(contact).as_json, response_json
    assert_response :ok
  end

  def test_deletes_contact
    contact = deletable_contact

    assert_difference 'Contact.count', -1 do
      delete registrar_api_v1_contact_path(contact)
    end
    response_json = ActiveSupport::JSON.decode(response.body).deep_symbolize_keys
    assert_equal ({ deleted: true }), response_json
    assert_response :ok
  end

  def test_contact_not_found
    get registrar_api_v1_contact_path('non-existent')
    assert_response :not_found
  end

  private

  def deletable_contact
    Domain.update_all(registrant_id: contacts(:william))
    DomainContact.delete_all
    contacts(:john)
  end
end
