require "test_helper"

class ExpireReservationJobTest < ActiveJob::TestCase
  setup do
    @listing = listings(:router)
    @buyer = users(:two)
  end

  test "new reservations schedule expiration at their deadline" do
    reservation = reserve
    assert_enqueued_with(job: ExpireReservationJob, args: [ reservation.id ], at: reservation.expires_at)
  end

  test "early execution leaves the reservation unchanged" do
    reservation = reserve
    assert_no_changes -> { [ reservation.reload.status, @listing.reload.status, reservation.updated_at ] } do
      ExpireReservationJob.perform_now(reservation.id)
    end
  end

  test "expires a reservation atomically and repeated execution changes nothing" do
    reservation = reserve
    travel_to reservation.expires_at, with_usec: true do
      ExpireReservationJob.perform_now(reservation.id)
    end
    assert reservation.reload.expired?
    assert @listing.reload.available?
    travel_to reservation.expires_at + 1.minute, with_usec: true do
      assert_no_changes -> { [ reservation.reload.updated_at, @listing.reload.updated_at ] } do
        ExpireReservationJob.perform_now(reservation.id)
      end
    end
  end

  test "checkout before expiration protects the completed purchase" do
    reservation = reserve
    order = ReservationService.checkout(reservation: reservation, buyer: @buyer)
    travel_to reservation.expires_at + 1.minute, with_usec: true do
      2.times { ExpireReservationJob.perform_now(reservation.id) }
    end
    assert reservation.reload.completed?
    assert @listing.reload.sold?
    assert_equal order, reservation.order
  end

  test "cancelled reservation stays cancelled when its job runs" do
    reservation = reserve
    ReservationService.cancel(reservation: reservation, buyer: @buyer)
    travel_to reservation.expires_at, with_usec: true do
      ExpireReservationJob.perform_now(reservation.id)
    end
    assert reservation.reload.cancelled?
    assert @listing.reload.available?
  end

  test "old job after cancellation cannot release a newer reservation" do
    old = reserve
    ReservationService.cancel(reservation: old, buyer: @buyer)
    travel_to 5.minutes.from_now do
      current = reserve
      travel_to old.expires_at, with_usec: true
      ExpireReservationJob.perform_now(old.id)
      assert old.reload.cancelled?
      assert current.reload.valid_for_checkout?
      assert @listing.reload.reserved?
    end
  end

  test "old job after lazy expiration cannot release a newer reservation" do
    old = reserve
    travel_to old.expires_at, with_usec: true do
      current = reserve
      2.times { ExpireReservationJob.perform_now(old.id) }
      assert old.reload.expired?
      assert current.reload.active?
      assert @listing.reload.reserved?
    end
  end

  test "missing reservation is harmless" do
    assert_nothing_raised { ExpireReservationJob.perform_now(-1) }
  end

  test "recovery task expires only overdue holds without enqueueing work" do
    overdue = reserve
    travel_to 5.minutes.from_now do
      current = ReservationService.reserve(listing: listings(:board), buyer: users(:one))
      travel_to overdue.expires_at, with_usec: true
      Rails.application.load_tasks unless Rake::Task.task_defined?("reservations:expire_overdue")
      task = Rake::Task["reservations:expire_overdue"]
      assert_no_enqueued_jobs do
        2.times do
          task.reenable
          task.invoke
        end
      end
      assert overdue.reload.expired?
      assert @listing.reload.available?
      assert current.reload.active?
      assert listings(:board).reload.reserved?
    end
  end

  private
    def reserve
      ReservationService.reserve(listing: @listing, buyer: @buyer)
    end
end
