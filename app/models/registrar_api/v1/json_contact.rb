module RegistrarApi
  module V1
    class JsonContact
      attr_reader :contact

      def initialize(contact)
        @contact = contact
      end

      def as_json(_options = {})
        { id: contact.uuid,
          name: contact.name,
          email: contact.email,
          phone: contact.phone,
          identity_code: identity_code(contact) }
      end

      private

      def identity_code(contact)
        { value: contact.ident,
          type: contact.ident_type,
          country: contact.ident_country_code }
      end
    end
  end
end
