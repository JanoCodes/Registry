require 'test_helper'

class PaymentReturnTest < ApplicationIntegrationTest
  def setup
    super

    @user = users(:api_bestnames)
    sign_in @user

    @invoice = invoices(:one)
  end

  def every_pay_request_params
    {
      nonce:               "392f2d7748bc8cb0d14f263ebb7b8932",
      timestamp:           "1524136727",
      api_username:        "ca8d6336dd750ddb",
      transaction_result:  "completed",
      payment_reference:   "fd5d27b59a1eb597393cd5ff77386d6cab81ae05067e18d530b10f3802e30b56",
      payment_state:       "settled",
      amount:              "12.00",
      order_reference:     "e468a2d59a731ccc546f2165c3b1a6",
      account_id:          "EUR3D1",
      cc_type:             "master_card",
      cc_last_four_digits: "0487",
      cc_month:            "10",
      cc_year:             "2018",
      cc_holder_name:      "John Doe",
      hmac_fields:         "account_id,amount,api_username,cc_holder_name,cc_last_four_digits,cc_month,cc_type,cc_year,hmac_fields,nonce,order_reference,payment_reference,payment_state,timestamp,transaction_result",
      hmac:                "efac1c732835668cd86023a7abc140506c692f0d",
      invoice_id:          "12900000",
      payment_method:      "every_pay"
    }
  end

  def bank_link_request_params
    {
      "VK_SERVICE":    "1111",
      "VK_VERSION":    "008",
      "VK_SND_ID":     "testvpos",
      "VK_REC_ID":     "seb",
      "VK_STAMP":      1,
      "VK_T_NO":       "1",
      "VK_AMOUNT":     "12.00",
      "VK_CURR":       "EUR",
      "VK_REC_ACC":    "1234",
      "VK_REC_NAME":   "Eesti Internet",
      "VK_SND_ACC":    "1234",
      "VK_SND_NAME":   "John Doe",
      "VK_REF":        "",
      "VK_MSG":        "Order nr 1",
      "VK_T_DATETIME": "2018-04-01T00:30:00+0300",
      "VK_MAC":        "CZZvcptkxfuOxRR88JmT4N+Lw6Hs4xiQfhBWzVYldAcRTQbcB/lPf9MbJzBE4e1/HuslQgkdCFt5g1xW2lJwrVDBQTtP6DAHfvxU3kkw7dbk0IcwhI4whUl68/QCwlXEQTAVDv1AFnGVxXZ40vbm/aLKafBYgrirB5SUe8+g9FE=",
      "VK_ENCODING":   "UTF-8",
      "VK_LANG":       "ENG",
      payment_method:  "seb"
    }
  end

  def test_every_pay_return_creates_activity_redirects_to_invoice_path
    request_params = every_pay_request_params.merge(invoice_id: @invoice.id)

    post "/registrar/pay/return/every_pay", params: request_params
    assert_equal(302, response.status)
    assert_redirected_to(registrar_invoice_path(@invoice))
  end

  def test_Every_Pay_return_raises_RecordNotFound
    request_params = every_pay_request_params.merge(invoice_id: "178907")
    assert_raises(ActiveRecord::RecordNotFound) do
      post "/registrar/pay/return/every_pay", params: request_params
    end
  end

  def test_bank_link_return_redirects_to_invoice_paths
    request_params = bank_link_request_params.merge(invoice_id: @invoice.id)

    post "/registrar/pay/return/seb", params: request_params
    assert_equal(302, response.status)
    assert_redirected_to(registrar_invoice_path(@invoice))
  end

  def test_bank_link_return
    request_params = bank_link_request_params.merge(invoice_id: "178907")
    assert_raises(ActiveRecord::RecordNotFound) do
      post "/registrar/pay/return/seb", params: request_params
    end
  end
end
