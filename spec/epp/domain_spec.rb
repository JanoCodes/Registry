require 'rails_helper'

describe 'EPP Domain', epp: true do
  let(:server) { server = Epp::Server.new({server: 'localhost', tag: 'gitlab', password: 'ghyt9e4fu', port: 701}) }

  context 'with valid user' do
    before(:each) { Fabricate(:epp_user) }

    it 'returns error if contact does not exists' do
      Fabricate(:contact, code: 'jd1234')

      response = epp_request('domains/create.xml')
      expect(response[:results][0][:result_code]).to eq('2303')
      expect(response[:results][0][:msg]).to eq('Contact was not found')
      expect(response[:results][0][:value]).to eq('sh8013')

      expect(response[:results][1][:result_code]).to eq('2303')
      expect(response[:results][1][:msg]).to eq('Contact was not found')
      expect(response[:results][1][:value]).to eq('sh801333')

      expect(response[:results][2][:result_code]).to eq('2303')
      expect(response[:results][2][:msg]).to eq('Contact was not found')
      expect(response[:results][2][:value]).to eq('sh8013')

      expect(response[:clTRID]).to eq('ABC-12345')
    end

    context 'with citizen as an owner' do
      before(:each) {
        Fabricate(:contact, code: 'jd1234')
        Fabricate(:contact, code: 'sh8013')
        Fabricate(:contact, code: 'sh801333')
      }

      it 'creates a domain' do
        response = epp_request('domains/create.xml')
        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')
        expect(response[:clTRID]).to eq('ABC-12345')

        expect(Domain.first.registrar.name).to eq('Zone Media OÜ')
        expect(Domain.first.tech_contacts.count).to eq 2
        expect(Domain.first.admin_contacts.count).to eq 1

        expect(Domain.first.nameservers.count).to eq(2)
      end

      it 'does not create duplicate domain' do
        epp_request('domains/create.xml')
        response = epp_request('domains/create.xml')
        expect(response[:result_code]).to eq('2302')
        expect(response[:msg]).to eq('Domain name already exists')
        expect(response[:clTRID]).to eq('ABC-12345')
      end

      it 'does not create reserved domain' do
        Fabricate(:reserved_domain)
        response = epp_request('domains/create_reserved.xml')
        expect(response[:result_code]).to eq('2302')
        expect(response[:msg]).to eq('Domain name is reserved or restricted')
        expect(response[:clTRID]).to eq('ABC-12345')
      end

      it 'does not create domain without contacts and registrant' do
        response = epp_request('domains/create_wo_contacts_and_registrant.xml')
        expect(response[:result_code]).to eq('2306')
        expect(response[:msg]).to eq('Required parameter missing - registrant')
      end

      it 'does not create domain without nameservers' do
        response = epp_request('domains/create_wo_nameservers.xml')
        expect(response[:result_code]).to eq('2306')
        expect(response[:msg]).to eq('Required parameter missing - nameserver')
      end

      it 'does not create domain with too many nameservers' do
        response = epp_request('domains/create_w_too_many_nameservers.xml')
        expect(response[:result_code]).to eq('2306')
        expect(response[:msg]).to eq('Domain must have 1-13 nameservers')
      end

      it 'returns error when invalid nameservers are present' do
        response = epp_request('domains/create_w_invalid_nameservers.xml')
        expect(response[:result_code]).to eq('2005')
        expect(response[:msg]).to eq('Hostname is invalid')
      end


      it 'creates domain with nameservers with ips' do
        response = epp_request('domains/create_w_host_attrs.xml')
        expect(Domain.first.nameservers.count).to eq(2)
        ns = Domain.first.nameservers.first
        expect(ns.ip).to eq('192.0.2.2')
      end
    end

    context 'with juridical persion as an owner' do
      before(:each) {
        Fabricate(:contact, code: 'jd1234', ident_type: 'ico')
        Fabricate(:contact, code: 'sh8013')
        Fabricate(:contact, code: 'sh801333')
      }

      it 'creates a domain with contacts' do
        response = epp_request('domains/create_wo_tech_contact.xml')
        expect(response[:result_code]).to eq('1000')
        expect(response[:msg]).to eq('Command completed successfully')
        expect(response[:clTRID]).to eq('ABC-12345')

        expect(Domain.first.tech_contacts.count).to eq 1
        expect(Domain.first.admin_contacts.count).to eq 1

        tech_contact = Domain.first.tech_contacts.first
        expect(tech_contact.code).to eq('jd1234')
      end

      it 'does not create a domain without admin contact' do
        response = epp_request('domains/create_wo_contacts.xml')
        expect(response[:result_code]).to eq('2306')
        expect(response[:msg]).to eq('Required parameter missing - admin contact')
        expect(response[:clTRID]).to eq('ABC-12345')

        expect(Domain.count).to eq 0
        expect(DomainContact.count).to eq 0
      end
    end

    it 'checks a domain' do
      response = epp_request('domains/check.xml')
      expect(response[:result_code]).to eq('1000')
      expect(response[:msg]).to eq('Command completed successfully')

      domain = response[:parsed].css('resData chkData cd name').first
      expect(domain.text).to eq('one.ee')
      expect(domain[:avail]).to eq('1')

      Fabricate(:domain, name: 'one.ee')

      response = epp_request('domains/check.xml')
      domain = response[:parsed].css('resData chkData cd').first
      name = domain.css('name').first
      reason = domain.css('reason').first

      expect(name.text).to eq('one.ee')
      expect(name[:avail]).to eq('0')
      expect(reason.text).to eq('in use') #confirm this with current API
    end

    it 'checks multiple domains' do
      response = epp_request('domains/check_multiple.xml')
      expect(response[:result_code]).to eq('1000')
      expect(response[:msg]).to eq('Command completed successfully')

      domain = response[:parsed].css('resData chkData cd name').first
      expect(domain.text).to eq('one.ee')
      expect(domain[:avail]).to eq('1')

      domain = response[:parsed].css('resData chkData cd name').last
      expect(domain.text).to eq('three.ee')
      expect(domain[:avail]).to eq('1')
    end

    it 'checks invalid format domain' do
      response = epp_request('domains/check_multiple_with_invalid.xml')
      expect(response[:result_code]).to eq('1000')
      expect(response[:msg]).to eq('Command completed successfully')

      domain = response[:parsed].css('resData chkData cd name').first
      expect(domain.text).to eq('one.ee')
      expect(domain[:avail]).to eq('1')

      domain = response[:parsed].css('resData chkData cd').last
      name = domain.css('name').first
      reason = domain.css('reason').first

      expect(name.text).to eq('notcorrectdomain')
      expect(name[:avail]).to eq('0')
      expect(reason.text).to eq('invalid format')
    end

  end
end
