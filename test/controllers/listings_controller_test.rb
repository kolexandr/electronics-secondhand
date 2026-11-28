require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  test "public browse and detail pages are accessible" do
    get root_path
    assert_response :success
    assert_select ".listing-card", count: 2
    assert_select ".listing-card h3", text: "Sold switch", count: 0
    get listing_path(listings(:router))
    assert_response :success
    assert_select "h1", "Used router"
    assert_select "a", text: "Edit listing", count: 0
  end

  test "anonymous visitors cannot create update or delete listings" do
    get new_listing_path
    assert_redirected_to new_session_path
    get mine_listings_path
    assert_redirected_to new_session_path
    assert_no_difference "Listing.count" do
      post listings_path, params: { listing: { title: "Unauthorized" } }
      assert_redirected_to new_session_path
      delete listing_path(listings(:router))
      assert_redirected_to new_session_path
    end
    patch listing_path(listings(:router)), params: { listing: { title: "Unauthorized" } }
    assert_redirected_to new_session_path
    assert_equal "Used router", listings(:router).reload.title
  end

  test "one seller cannot edit update or delete another seller's listing" do
    sign_in_as(users(:two))
    listing = listings(:router)
    get edit_listing_path(listing)
    assert_response :not_found
    patch listing_path(listing), params: { listing: { title: "Stolen", seller_id: users(:two).id } }
    assert_response :not_found
    assert_equal "Used router", listing.reload.title
    assert_no_difference "Listing.count" do
      delete listing_path(listing)
      assert_response :not_found
    end
    assert_equal users(:one), listing.reload.seller
  end

  test "creates a listing for the signed in seller regardless of forged fields" do
    sign_in_as(users(:one))
    assert_difference "Listing.count", 1 do
      post listings_path, params: { listing: valid_attributes.merge(seller_id: users(:two).id, status: "sold", currency: "USD", price_cents: 1) }
    end
    listing = Listing.order(:id).last
    assert_redirected_to listing_path(listing)
    assert_equal users(:one), listing.seller
    assert_equal "available", listing.status
    assert_equal "EUR", listing.currency
    assert_equal 1999, listing.price_cents
    assert listing.photo.attached?
  end

  test "seller can edit without reuploading and remove an available listing" do
    sign_in_as(users(:one))
    listing = listings(:router)
    get edit_listing_path(listing)
    assert_response :success
    patch listing_path(listing), params: { listing: { title: "Updated router", price: "20.00", photo: "", seller_id: users(:two).id } }
    assert_redirected_to listing_path(listing)
    assert_equal "Updated router", listing.reload.title
    assert_equal 2000, listing.price_cents
    assert_equal users(:one), listing.seller
    assert listing.photo.attached?
    assert_difference "Listing.count", -1 do
      delete listing_path(listing)
    end
    assert_redirected_to mine_listings_path
  end

  test "replacing the photo keeps one attachment" do
    sign_in_as(users(:one))
    listing = listings(:router)
    previous_blob_id = listing.photo.blob_id
    patch listing_path(listing), params: { listing: { photo: fixture_file_upload("listing.png", "image/png") } }
    assert_redirected_to listing_path(listing)
    assert_not_equal previous_blob_id, listing.reload.photo.blob_id
    assert_equal 1, ActiveStorage::Attachment.where(record: listing, name: "photo").count
  end

  test "invalid listings show errors without being saved" do
    sign_in_as(users(:one))
    assert_no_difference "Listing.count" do
      post listings_path, params: { listing: valid_attributes.merge(price: "-5.00") }
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors", /Price/
  end

  test "reserved and sold listings cannot be edited or removed" do
    sign_in_as(users(:one))
    listing = listings(:router)
    %w[reserved sold].each do |status|
      listing.update_column(:status, status)
      get edit_listing_path(listing)
      assert_redirected_to listing_path(listing)
      patch listing_path(listing), params: { listing: { price: "1.00", title: "Changed" } }
      assert_redirected_to listing_path(listing)
      assert_equal 2500, listing.reload.price_cents
      assert_equal "Used router", listing.title
      assert_no_difference "Listing.count" do
        delete listing_path(listing)
      end
      assert_redirected_to listing_path(listing)
    end
  end

  test "my listings only shows the authenticated seller's items including sold ones" do
    sign_in_as(users(:one))
    get mine_listings_path
    assert_response :success
    assert_select ".listing-card", count: 2
    assert_select ".listing-card h3", text: "Development board", count: 0
    assert_select ".listing-card h3", text: "Sold switch", count: 1
  end

  test "filters by search category condition and inclusive price boundaries" do
    get listings_path, params: { q: "router", category_id: categories(:networking).id, condition: "good", min_price: "25.00", max_price: "25.00" }
    assert_response :success
    assert_select ".listing-card", count: 1
    assert_select ".listing-card h3", "Used router"
    get listings_path, params: { max_price: "24.99" }
    assert_select ".listing-card", count: 0
    get listings_path, params: { min_price: "invalid" }
    assert_select "[role=alert]", /valid euro amount/
    assert_select ".listing-card", count: 0
    get listings_path, params: { q: "%" }
    assert_select ".listing-card", count: 0
  end

  test "sorts by price in both directions" do
    get listings_path, params: { sort: "price_low" }
    assert_equal [ "Used router", "Development board" ], css_select(".listing-card h3").map(&:text)
    get listings_path, params: { sort: "price_high" }
    assert_equal [ "Development board", "Used router" ], css_select(".listing-card h3").map(&:text)
    get listings_path, params: { sort: "price_cents; DROP TABLE listings" }
    assert_response :success
  end

  test "paginates results and keeps filters in navigation" do
    13.times do |index|
      listing = listings(:router).dup
      listing.title = "Extra router #{index}"
      listing.photo.attach(listings(:router).photo.blob)
      listing.save!
    end
    get listings_path, params: { q: "router", sort: "price_low" }
    assert_select ".listing-card", count: 12
    assert_select "a[rel=next]" do |links|
      assert_includes links.first["href"], "q=router"
      assert_includes links.first["href"], "sort=price_low"
    end
    get listings_path, params: { q: "router", page: 2 }
    assert_select ".listing-card", count: 2
    get listings_path, params: { page: "-1" }
    assert_response :success
  end

  test "signing out prevents further edits" do
    post session_path, params: { email_address: users(:one).email_address, password: "test-password-123" }
    delete session_path
    patch listing_path(listings(:router)), params: { listing: { title: "Changed" } }
    assert_redirected_to new_session_path
    assert_equal "Used router", listings(:router).reload.title
  end

  test "two independent signed in browsers retain their own permissions" do
    seller_browser = open_session
    other_browser = open_session
    seller_browser.post session_path, params: { email_address: users(:one).email_address, password: "test-password-123" }
    other_browser.post session_path, params: { email_address: users(:two).email_address, password: "test-password-123" }

    seller_browser.get edit_listing_path(listings(:router))
    seller_browser.assert_response :success
    other_browser.patch listing_path(listings(:router)), params: { listing: { title: "Taken over" } }
    other_browser.assert_response :not_found
    seller_browser.patch listing_path(listings(:router)), params: { listing: { title: "Still mine" } }
    seller_browser.assert_redirected_to listing_path(listings(:router))
    assert_equal "Still mine", listings(:router).reload.title
  end

  test "a signed blob id cannot replace a photo through the upload form" do
    sign_in_as(users(:one))
    listing = listings(:router)
    patch listing_path(listing), params: { listing: { photo: listing.photo.blob.signed_id } }
    assert_response :bad_request
  end

  private
    def valid_attributes
      { title: "Test router", description: "Working router with adapter", category_id: categories(:networking).id,
        condition: "good", price: "19.99", photo: fixture_file_upload("listing.png", "image/png") }
    end
end
