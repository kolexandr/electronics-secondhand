namespace :reservations do
  desc "Expire overdue reservations using the same listing lock as checkout"
  task expire_overdue: :environment do
    Reservation.active.where(expires_at: ..Time.current).find_each do |reservation|
      ReservationService.expire(reservation_id: reservation.id)
    end
  end
end
