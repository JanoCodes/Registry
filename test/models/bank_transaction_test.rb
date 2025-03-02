require 'test_helper'

class BankTransactionTest < ActiveSupport::TestCase
  setup do
    @registrar = registrars(:bestnames)
    @invoice = invoices(:one)
  end

  def test_matches_against_invoice_number_and_reference_number
    create_payable_invoice(number: '2222', total: 10, reference_no: '1111')
    transaction = BankTransaction.new(description: 'invoice #2222', sum: 10, reference_no: '1111')

    assert_difference 'AccountActivity.count' do
      transaction.autobind_invoice
    end
  end

  def test_resets_pending_registrar_balance_reload
    registrar = registrar_with_pending_balance_auto_reload
    create_payable_invoice(number: '2222', total: 10, reference_no: '1111')
    transaction = BankTransaction.new(description: 'invoice #2222', sum: 10, reference_no: '1111')

    transaction.autobind_invoice
    registrar.reload

    assert_nil registrar.settings['balance_auto_reload']['pending']
  end

  def test_does_not_match_against_registrar_reference_number
    @registrar.update!(reference_no: '1111')
    transaction = BankTransaction.new(description: 'invoice #2222', sum: 10, reference_no: '1111')

    assert_no_difference 'AccountActivity.count' do
      transaction.autobind_invoice
    end
  end

  def test_underpayment_is_not_matched_with_invoice
    create_payable_invoice(number: '2222', total: 10)
    transaction = BankTransaction.new(sum: 9)

    assert_no_difference 'AccountActivity.count' do
      transaction.bind_invoice('2222')
    end
    assert transaction.errors.full_messages.include?('Invoice and transaction sums do not match')
  end

  def test_overpayment_is_not_matched_with_invoice
    create_payable_invoice(number: '2222', total: 10)
    transaction = BankTransaction.new(sum: 11)

    assert_no_difference 'AccountActivity.count' do
      transaction.bind_invoice('2222')
    end
    assert transaction.errors.full_messages.include?('Invoice and transaction sums do not match')
  end

  def test_cancelled_invoice_is_not_matched
    @invoice.update!(account_activity: nil, number: '2222', total: 10, cancelled_at: '2010-07-05')
    transaction = BankTransaction.new(sum: 10)

    assert_no_difference 'AccountActivity.count' do
      transaction.bind_invoice('2222')
    end
    assert transaction.errors.full_messages.include?('Cannot bind cancelled invoice')
  end

  private

  def create_payable_invoice(attributes)
    payable_attributes = { account_activity: nil }
    @invoice.update!(payable_attributes.merge(attributes))
    @invoice
  end

  def registrar_with_pending_balance_auto_reload
    @registrar.update!(settings: { balance_auto_reload: { pending: true } })
    @registrar
  end
end
