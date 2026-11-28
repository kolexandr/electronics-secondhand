require "test_helper"

class ListingQueriesTest < ActionDispatch::IntegrationTest
  test "browse query count stays constant with twelve distinct sellers categories and photos" do
    create_listing(0)
    get listings_path, params: { q: "Query measurement" }
    small = listing_queries { get listings_path, params: { q: "Query measurement" } }
    assert_select ".listing-card", count: 1

    11.times { |index| create_listing(index + 1) }
    full = listing_queries { get listings_path, params: { q: "Query measurement" } }
    assert_select ".listing-card", count: 12
    assert_equal small.size, full.size, full.join("\n")
    assert_equal 1, full.count { |sql| sql.include?("FROM `users`") }
    assert_equal 2, full.count { |sql| sql.include?("FROM `active_storage_attachments`") }
    assert_equal 1, full.count { |sql| sql.include?("FROM `active_storage_blobs`") }
    assert_equal 2, full.count { |sql| sql.include?("FROM `listings`") }
  end

  test "my listings query count stays constant as the page fills" do
    seller = users(:two)
    sign_in_as(seller)
    get mine_listings_path
    small = listing_queries { get mine_listings_path }
    assert_select ".listing-card", count: 1

    11.times { |index| create_listing(index, seller: seller) }
    full = listing_queries { get mine_listings_path }
    assert_select ".listing-card", count: 12
    assert_equal small.size, full.size, full.join("\n")
    assert_equal 2, full.count { |sql| sql.include?("FROM `listings`") }
  end

  private
    def create_listing(index, seller: nil)
      seller ||= User.create!(email_address: "query-#{index}@example.com", display_name: "Seller #{index}", password: "query-password-123")
      category = Category.create!(name: "Query category #{index}", slug: "query-category-#{index}")
      listing = seller.listings.build(title: "Query measurement #{index}", description: "Working electronics", category: category, condition: "good", price_cents: 2500)
      File.open(file_fixture("listing.png")) do |file|
        listing.photo.attach(io: file, filename: "query-#{index}.png", content_type: "image/png")
        listing.save!
      end
    end

    def listing_queries
      queries = []
      subscriber = ->(_name, _start, _finish, _id, payload) do
        sql = payload[:sql]
        queries << sql if !payload[:cached] && payload[:name] != "SCHEMA" && sql.match?(/\ASELECT/i)
      end
      ActiveRecord::Base.uncached do
        ActiveRecord::Base.connection_pool.clear_query_cache
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
      end
      assert_response :success
      queries
    end
end
