require "test_helper"

class ReservationServiceTest < ActiveSupport::TestCase
  setup do
    @listing = listings(:router)
    @buyer = users(:two)
    @other_buyer = User.create!(display_name: "Morgan", email_address: "morgan@example.com", password: "test-password-123")
  end

  test "reserves one item for fifteen minutes and captures the price" do
    freeze_time do
      reservation = reserve
      assert_equal @buyer, reservation.buyer
      assert_equal 15.minutes.from_now, reservation.expires_at
      assert_equal 2500, reservation.agreed_price_cents
      assert_equal "EUR", reservation.currency
      assert reservation.active?
      assert @listing.reload.reserved?
    end
  end

  test "seller cannot reserve their own item" do
    assert_no_difference "Reservation.count" do
      assert_raises(ReservationService::OwnListing) do
        ReservationService.reserve(listing: @listing, buyer: users(:one))
      end
    end
    assert @listing.reload.available?
  end

  test "another reservation and a sold listing are rejected" do
    reservation = reserve
    assert_raises(ReservationService::Unavailable) { ReservationService.reserve(listing: @listing, buyer: @other_buyer) }
    ReservationService.checkout(reservation: reservation, buyer: @buyer)
    assert_raises(ReservationService::Unavailable) { ReservationService.reserve(listing: @listing, buyer: @other_buyer) }
  end

  test "cancellation releases the item and can be repeated" do
    reservation = reserve
    2.times { ReservationService.cancel(reservation: reservation, buyer: @buyer) }
    assert reservation.reload.cancelled?
    assert @listing.reload.available?
    assert_equal 1, @listing.reservations.count
  end

  test "another buyer cannot cancel or complete the reservation" do
    reservation = reserve
    assert_raises(ReservationService::NotOwner) { ReservationService.cancel(reservation: reservation, buyer: @other_buyer) }
    assert_raises(ReservationService::NotOwner) { ReservationService.checkout(reservation: reservation, buyer: @other_buyer) }
    assert reservation.reload.active?
    assert @listing.reload.reserved?
  end

  test "purchase uses agreed price and repeat checkout returns the same order" do
    reservation = reserve
    @listing.update_column(:price_cents, 9000)
    order = ReservationService.checkout(reservation: reservation, buyer: @buyer)
    assert_equal 2500, order.total_cents
    assert_equal reservation.id, order.reservation_id
    assert_equal @listing.id, order.listing_id
    assert_equal @buyer.id, order.buyer_id
    assert reservation.reload.completed?
    assert @listing.reload.sold?
    travel_to 1.hour.from_now do
      assert_no_difference "Order.count" do
        assert_equal order, ReservationService.checkout(reservation: reservation, buyer: @buyer)
      end
    end
  end

  test "checkout at the exact expiry time rejects the purchase and releases the item" do
    reservation = reserve
    travel_to reservation.expires_at, with_usec: true do
      assert_not reservation.valid_for_checkout?
      assert_equal "expired", reservation.display_status
      assert_no_difference "Order.count" do
        assert_raises(ReservationService::Expired) { ReservationService.checkout(reservation: reservation, buyer: @buyer) }
      end
    end
    assert reservation.reload.expired?
    assert @listing.reload.available?
  end

  test "new buyer can replace an expired reservation without a worker" do
    old = reserve
    travel_to old.expires_at, with_usec: true do
      new_reservation = ReservationService.reserve(listing: @listing, buyer: @other_buyer)
      assert old.reload.expired?
      assert new_reservation.active?
      assert_equal @other_buyer.id, new_reservation.buyer_id
      assert_equal 1, @listing.reservations.active.count
      assert @listing.reload.reserved?
      ReservationService.cancel(reservation: old, buyer: @buyer)
      assert_raises(ReservationService::Expired) { ReservationService.checkout(reservation: old, buyer: @buyer) }
      assert new_reservation.reload.active?
      assert @listing.reload.reserved?
    end
  end

  test "repeating an old cancellation cannot release a new buyer's reservation" do
    old = reserve
    ReservationService.cancel(reservation: old, buyer: @buyer)
    current = ReservationService.reserve(listing: @listing, buyer: @other_buyer)
    ReservationService.cancel(reservation: old, buyer: @buyer)
    assert_raises(ReservationService::InvalidState) { ReservationService.checkout(reservation: old, buyer: @buyer) }
    assert current.reload.active?
    assert @listing.reload.reserved?
  end

  test "cancelling an overdue reservation expires it" do
    reservation = reserve
    travel_to reservation.expires_at, with_usec: true do
      ReservationService.cancel(reservation: reservation, buyer: @buyer)
    end
    assert reservation.reload.expired?
    assert @listing.reload.available?
  end

  test "completed purchase cannot be cancelled or deleted" do
    reservation = reserve
    order = ReservationService.checkout(reservation: reservation, buyer: @buyer)
    assert_raises(ReservationService::InvalidState) { ReservationService.cancel(reservation: reservation, buyer: @buyer) }
    assert_not @listing.reload.destroy
    @listing.update_column(:status, "available")
    assert_not @listing.reload.destroy
    assert_raises(ActiveRecord::InvalidForeignKey) { Listing.where(id: @listing.id).delete_all }
    assert Order.exists?(order.id)
  end

  test "database allows only one active reservation per listing" do
    reservation = reserve
    duplicate = Reservation.new(listing: @listing, buyer: @other_buyer, status: :active,
      expires_at: reservation.expires_at, agreed_price_cents: 2500, currency: "EUR")
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "database prevents duplicate orders for a listing and a reservation" do
    reservation = reserve
    order = ReservationService.checkout(reservation: reservation, buyer: @buyer)
    attributes = order.attributes.except("id")
    another_reservation = Reservation.create!(listing: @listing, buyer: @buyer, status: :cancelled,
      expires_at: 15.minutes.from_now, agreed_price_cents: 2500, currency: "EUR")
    assert_raises(ActiveRecord::RecordNotUnique) do
      Order.insert_all!([ attributes.merge("reservation_id" => another_reservation.id) ])
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      Order.insert_all!([ attributes.merge("listing_id" => listings(:board).id) ])
    end
  end

  test "failure while selling the listing rolls back the order and reservation" do
    reservation = reserve
    Listing.where(id: @listing.id).update_all(description: "")
    assert_no_difference "Order.count" do
      assert_raises(ActiveRecord::RecordInvalid) { ReservationService.checkout(reservation: reservation, buyer: @buyer) }
    end
    assert reservation.reload.active?
    assert @listing.reload.reserved?
  end

  private
    def reserve
      ReservationService.reserve(listing: @listing, buyer: @buyer)
    end
end
