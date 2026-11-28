require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @listing = listings(:router)
    @buyer = users(:two)
  end

  test "sign in is required for all reservation actions" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    get reservations_path
    assert_redirected_to new_session_path
    get reservation_path(reservation)
    assert_redirected_to new_session_path
    post listing_reservations_path(listings(:board))
    assert_redirected_to new_session_path
    post cancel_reservation_path(reservation)
    assert_redirected_to new_session_path
    post checkout_reservation_path(reservation)
    assert_redirected_to new_session_path
    assert reservation.reload.active?
  end

  test "reservation derives buyer and price from the authenticated account and listing" do
    sign_in_as(@buyer)
    assert_difference "Reservation.count", 1 do
      post listing_reservations_path(@listing), params: {
        buyer_id: users(:one).id, agreed_price_cents: 1, currency: "USD", expires_at: 1.year.from_now,
        reservation: { buyer_id: users(:one).id, status: "completed" }
      }
    end
    reservation = Reservation.order(:id).last
    assert_redirected_to reservation_path(reservation)
    assert_equal @buyer.id, reservation.buyer_id
    assert_equal 2500, reservation.agreed_price_cents
    assert_equal "EUR", reservation.currency
    assert reservation.active?
    follow_redirect!
    assert_response :success
    assert_select "button", "Complete simulated purchase"
  end

  test "seller reservation is rejected with a useful message" do
    sign_in_as(users(:one))
    assert_no_difference "Reservation.count" do
      post listing_reservations_path(@listing)
    end
    assert_redirected_to listing_path(@listing)
    follow_redirect!
    assert_select "[role=alert]", /cannot reserve your own/
  end

  test "another user cannot view cancel or complete the reservation" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    sign_in_as(users(:one))
    get reservation_path(reservation)
    assert_response :not_found
    post cancel_reservation_path(reservation)
    assert_response :not_found
    assert_no_difference "Order.count" do
      post checkout_reservation_path(reservation)
      assert_response :not_found
    end
    assert reservation.reload.active?
    assert @listing.reload.reserved?
  end

  test "buyer can cancel their reservation" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    sign_in_as(@buyer)
    post cancel_reservation_path(reservation)
    assert_redirected_to reservation_path(reservation)
    assert reservation.reload.cancelled?
    assert @listing.reload.available?
  end

  test "checkout uses stored terms and repeated requests show the same order" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    sign_in_as(@buyer)
    assert_difference "Order.count", 1 do
      post checkout_reservation_path(reservation), params: { total_cents: 1, buyer_id: users(:one).id }
    end
    order = Order.find_by!(reservation: reservation)
    assert_equal 2500, order.total_cents
    assert_equal @buyer.id, order.buyer_id
    assert_redirected_to order_path(order)
    assert_no_difference "Order.count" do
      post checkout_reservation_path(reservation)
    end
    assert_redirected_to order_path(order)
    follow_redirect!
    assert_response :success
    assert_select "h1", "Order ##{order.id}"
  end

  test "late checkout cannot create an order even without an expiration job" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    sign_in_as(@buyer)
    travel_to reservation.expires_at, with_usec: true do
      assert_no_difference "Order.count" do
        post checkout_reservation_path(reservation)
      end
      assert_redirected_to reservation_path(reservation)
      follow_redirect!
      assert_select "[role=alert]", /reservation has expired/
      assert_select "button", text: "Complete simulated purchase", count: 0
    end
    assert reservation.reload.expired?
    assert @listing.reload.available?
  end

  test "buyer and seller can see the order but an unrelated user cannot" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    order = ReservationService.checkout(reservation: reservation, buyer: @buyer)
    [ @buyer, users(:one) ].each do |user|
      sign_in_as(user)
      get order_path(order)
      assert_response :success
      get reservations_path
      assert_response :success
      assert_select "a[href=?]", order_path(order)
    end
    outsider = User.create!(display_name: "Outsider", email_address: "outsider@example.com", password: "test-password-123")
    sign_in_as(outsider)
    get order_path(order)
    assert_response :not_found
    get reservations_path
    assert_response :success
    assert_select "a[href=?]", order_path(order), count: 0
  end

  test "listing offers the current buyer their reservation and an expired hold can be reserved again" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    sign_in_as(@buyer)
    get listing_path(@listing)
    assert_select "a[href=?]", reservation_path(reservation), text: "View your reservation"
    travel_to reservation.expires_at, with_usec: true do
      get listing_path(@listing)
      assert_select "form[action=?]", listing_reservations_path(@listing)
      post listing_reservations_path(@listing)
      assert_response :see_other
      assert reservation.reload.expired?
      assert_equal 1, @listing.reservations.active.count
    end
  end
end
