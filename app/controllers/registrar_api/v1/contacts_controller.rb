module RegistrarApi
  module V1
    class ContactsController < BaseController
      def create
        contact = Contact.new(contact_params.except(:identity_code))
        contact.ident = contact_params[:identity_code][:value]
        contact.ident_type = contact_params[:identity_code][:type]
        contact.ident_country_code = contact_params[:identity_code][:country]
        contact.registrar = current_user.registrar
        contact.generate_code
        contact.save!

        render json: JsonContact.new(contact)
      end

      def show
        contact = Contact.find(params[:id])
        render json: JsonContact.new(contact)
      end

      def update
        contact = Contact.find(params[:id])
        contact.attributes = contact_params.except(:identity_code)
        contact.save!

        render json: JsonContact.new(contact)
      end

      def destroy
        contact = Contact.find(params[:id])
        contact.destroy!

        render json: { deleted: true }
      end

      private

      def contact_params
        params.permit(:name, :email, :phone, identity_code: %i[value type country])
      end
    end
  end
end
