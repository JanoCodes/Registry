require 'rails_helper'

describe Nameserver do
  it { should belong_to(:domain) }

  context 'with invalid attribute' do
    before :all do
      @nameserver = Nameserver.new
    end

    it 'should not be valid' do
      @nameserver.valid?
      @nameserver.errors.full_messages.should match_array([
        "Hostname Hostname is invalid"
      ])
    end

    it 'should not have any versions' do
      @nameserver.versions.should == []
    end
  end

  context 'with valid attributes' do
    before :all do
      @nameserver = Fabricate(:nameserver)
    end

    it 'should be valid' do
      @nameserver.valid?
      @nameserver.errors.full_messages.should match_array([])
    end

    it 'should be valid twice' do
      @nameserver = Fabricate(:nameserver)
      @nameserver.valid?
      @nameserver.errors.full_messages.should match_array([])
    end

    it 'should have one version' do
      with_versioning do
        @nameserver.versions.should == []
        @nameserver.hostname = 'hostname.ee'
        @nameserver.save
        @nameserver.errors.full_messages.should match_array([])
        @nameserver.versions.size.should == 1
      end
    end

    context 'with many nameservers' do
      before :all do
        @api_user = Fabricate(:api_user)
        @domain_1 = Fabricate(:domain, nameservers: [
          Fabricate(:nameserver, hostname: 'ns1.ns.ee'),
          Fabricate(:nameserver, hostname: 'ns2.ns.ee'),
          Fabricate(:nameserver, hostname: 'ns2.test.ee')
        ], registrar: @api_user.registrar)

        @domain_2 = Fabricate(:domain, nameservers: [
          Fabricate(:nameserver, hostname: 'ns1.ns.ee'),
          Fabricate(:nameserver, hostname: 'ns2.ns.ee'),
          Fabricate(:nameserver, hostname: 'ns3.test.ee')
        ], registrar: @api_user.registrar)

        Fabricate(:domain, nameservers: [
          Fabricate(:nameserver, hostname: 'ns1.ns.ee'),
          Fabricate(:nameserver, hostname: 'ns2.ns.ee'),
          Fabricate(:nameserver, hostname: 'ns3.test.ee')
        ])
      end

      it 'should replace hostname ends' do
        res = Nameserver.replace_hostname_ends(@api_user.registrar.domains, 'ns.ee', 'test.ee')
        res.should == false

        @api_user.registrar.nameservers.where("hostname LIKE '%test.ee'").count.should == 4
        @domain_1.nameservers.pluck(:hostname).should include('ns1.ns.ee', 'ns2.ns.ee', 'ns2.test.ee')
        @domain_2.nameservers.pluck(:hostname).should include('ns1.test.ee', 'ns2.test.ee', 'ns3.test.ee')

        res = Nameserver.replace_hostname_ends(@api_user.registrar.domains, 'test.ee', 'testing.ee')
        res.should == true

        @api_user.registrar.nameservers.where("hostname LIKE '%testing.ee'").count.should == 4
        @domain_1.nameservers.pluck(:hostname).should include('ns1.ns.ee', 'ns2.ns.ee', 'ns2.testing.ee')
        @domain_2.nameservers.pluck(:hostname).should include('ns1.testing.ee', 'ns2.testing.ee', 'ns3.testing.ee')

        res = Nameserver.replace_hostname_ends(@api_user.registrar.domains, 'ns.ee', 'test.ee')
        res.should == true

        @api_user.registrar.nameservers.where("hostname LIKE '%test.ee'").count.should == 2
        @domain_1.nameservers.pluck(:hostname).should include('ns1.test.ee', 'ns2.test.ee', 'ns2.testing.ee')
        @domain_2.nameservers.pluck(:hostname).should include('ns1.testing.ee', 'ns2.testing.ee', 'ns3.testing.ee')
      end
    end
  end
end
