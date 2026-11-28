class ReservationsController < ApplicationController
  before_action :set_reservation, only: %i[show cancel checkout]
  rescue_from ReservationService::Error, with: :reservation_failed

  def index
    @reservations = Current.user.reservations.includes(:order, listing: :seller).order(created_at: :desc, id: :desc).limit(50)
    @purchases = Current.user.orders.includes(listing: :seller).order(completed_at: :desc, id: :desc).limit(50)
    @sales = Order.joins(:listing).where(listings: { seller_id: Current.user.id })
      .includes(:buyer, :listing).order(completed_at: :desc, id: :desc).limit(50)
  end

  def show
  end

  def create
    @listing = Listing.find(params[:listing_id])
    reservation = ReservationService.reserve(listing: @listing, buyer: Current.user)
    redirect_to reservation, notice: "Reserved for 15 minutes. Complete your simulated purchase before the deadline.", status: :see_other
  end

  def cancel
    reservation = ReservationService.cancel(reservation: @reservation, buyer: Current.user)
    message = reservation.expired? ? "This reservation has expired." : "Reservation cancelled."
    redirect_to reservation, notice: message, status: :see_other
  end

  def checkout
    order = ReservationService.checkout(reservation: @reservation, buyer: Current.user)
    redirect_to order, notice: "Simulated purchase complete. No payment was taken.", status: :see_other
  end

  private
    def set_reservation
      @reservation = Current.user.reservations.includes(:order, listing: :seller).find(params[:id])
    end

    def reservation_failed(error)
      redirect_to(@reservation || @listing, alert: error.message, status: :see_other)
    end
end
