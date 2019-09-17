class EppSession < ActiveRecord::Base
  belongs_to :user, required: true

  validates :session_id, uniqueness: true, presence: true

  class_attribute :sessions_per_registrar
  self.sessions_per_registrar = ENV['epp_sessions_per_registrar'].to_i

  def self.limit_reached?(registrar)
    count = where(user_id: registrar.api_users.ids).count
    count >= sessions_per_registrar
  end
end
