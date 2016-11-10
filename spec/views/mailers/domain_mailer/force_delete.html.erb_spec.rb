require 'rails_helper'
require_relative 'force_delete_shared'

RSpec.describe 'mailers/domain_mailer/force_delete.html.erb' do
  before :example do
    stub_template 'mailers/domain_mailer/registrar/_registrar.et.html' => 'test registrar estonian'
    stub_template 'mailers/domain_mailer/registrar/_registrar.en.html' => 'test registrar english'
    stub_template 'mailers/domain_mailer/registrar/_registrar.ru.html' => 'test registrar russian'
  end

  include_examples 'domain mailer force delete'
end
