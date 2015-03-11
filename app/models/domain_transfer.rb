class DomainTransfer < ActiveRecord::Base
  include Versions # version/domain_transfer_version.rb
  belongs_to :domain

  belongs_to :transfer_from, class_name: 'Registrar'
  belongs_to :transfer_to, class_name: 'Registrar'

  PENDING = 'pending'
  CLIENT_APPROVED = 'clientApproved'
  CLIENT_CANCELLED = 'clientCancelled'
  CLIENT_REJECTED = 'clientRejected'
  SERVER_APPROVED = 'serverApproved'
  SERVER_CANCELLED = 'serverCancelled'

  before_create :set_wait_until
  before_create :set_status

  def set_status
    if Setting.transfer_wait_time > 0
      self.status = PENDING unless status
    else
      self.status = SERVER_APPROVED unless status
      self.transferred_at = Time.zone.now unless transferred_at
    end
  end

  delegate :name, :valid_to, to: :domain, prefix: true

  def set_wait_until
    wait_time = Setting.transfer_wait_time
    return if wait_time == 0
    self.wait_until = transfer_requested_at + wait_time.hours
  end

  def approved?
    status == CLIENT_APPROVED || status == SERVER_APPROVED
  end

  def pending?
    status == PENDING
  end

  def approve_as_client
    transaction do
      self.status = DomainTransfer::CLIENT_APPROVED
      self.transferred_at = Time.zone.now
      save

      domain.generate_auth_info
      domain.registrar = transfer_to
      domain.save(validate: false)
    end
  end
end
