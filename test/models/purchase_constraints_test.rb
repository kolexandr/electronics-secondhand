require "test_helper"

class PurchaseConstraintsTest < ActiveSupport::TestCase
  setup do
    assert_equal "Mysql2", ActiveRecord::Base.connection.adapter_name
    @reservation = ReservationService.reserve(listing: listings(:router), buyer: users(:two))
  end

  test "reservation constraints reject invalid values without model validations" do
    invalid_values = { agreed_price_cents: [ -1, 100_000_000 ], currency: [ "USD" ], status: [ "unknown" ], expires_at: [ nil ] }
    invalid_values.each do |column, values|
      values.each do |value|
        assert_raises(ActiveRecord::StatementInvalid) do
          Reservation.where(id: @reservation.id).update_all(column => value)
        end
      end
    end
    assert @reservation.reload.active?
    assert_equal 2500, @reservation.agreed_price_cents
  end

  test "order constraints reject invalid values without model validations" do
    order = ReservationService.checkout(reservation: @reservation, buyer: users(:two))
    invalid_values = { total_cents: [ -1, 100_000_000 ], currency: [ "USD" ], completed_at: [ nil ], buyer_id: [ -1 ] }
    invalid_values.each do |column, values|
      values.each do |value|
        assert_raises(ActiveRecord::StatementInvalid) do
          Order.where(id: order.id).update_all(column => value)
        end
      end
    end
    assert_equal 2500, order.reload.total_cents
    assert_equal users(:two).id, order.buyer_id
  end

  test "foreign keys prevent removing reservation purchase history" do
    ReservationService.checkout(reservation: @reservation, buyer: users(:two))
    assert_raises(ActiveRecord::InvalidForeignKey) { Reservation.where(id: @reservation.id).delete_all }
    assert @reservation.reload.completed?
  end
end
