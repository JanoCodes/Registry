require 'test_helper'

class ApiV1AuctionDetailsTest < ActionDispatch::IntegrationTest
  setup do
    @auction = auctions(:one)
    ENV['auction_api_allowed_ips'] = '127.0.0.1'
  end

  teardown do
    ENV['auction_api_allowed_ips'] = ''
  end

  def test_returns_auction_details
    assert_equal '1b3ee442-e8fe-4922-9492-8fcb9dccc69c', @auction.uuid
    assert_equal 'auction.test', @auction.domain
    assert_equal Auction.statuses[:no_bids], @auction.status

    get api_v1_auction_path(@auction.uuid), as: :json

    assert_response :ok
    assert_equal ({ 'id' => '1b3ee442-e8fe-4922-9492-8fcb9dccc69c',
                    'domain' => 'auction.test',
                    'status' => Auction.statuses[:no_bids] }), ActiveSupport::JSON
                   .decode(response.body)
  end

  def test_auction_not_found
    assert_raises ActiveRecord::RecordNotFound do
      get api_v1_auction_path('non-existing-uuid'), as: :json
    end
  end
end