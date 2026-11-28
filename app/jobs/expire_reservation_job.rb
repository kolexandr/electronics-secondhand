class ExpireReservationJob < ApplicationJob
  queue_as :default

  def perform(reservation_id)
    ReservationService.expire(reservation_id: reservation_id)
  end
end
