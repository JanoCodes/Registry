require 'rails_helper'
require_relative 'registrar_shared'

RSpec.describe 'mailers/domain_mailer/registrar/_registrar.et.text.erb' do
  include_examples 'domain mailer registrar info'
end
