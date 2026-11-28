class ReservationService
  class Error < StandardError; end
  class Unavailable < Error; end
  class OwnListing < Error; end
  class NotOwner < Error; end
  class Expired < Error; end
  class InvalidState < Error; end

  DURATION = 15.minutes

  def self.reserve(listing:, buyer:)
    listing = Listing.find(listing.id)
    listing.with_lock(requires_new: true) do
      raise OwnListing, "You cannot reserve your own listing." if listing.seller_id == buyer.id

      now = Time.current
      current = listing.reservations.active.lock.first
      expire_if_due(current, listing, now) if current
      if !listing.available? || current&.active? || Order.where(listing_id: listing.id).exists?
        raise Unavailable, "This item is no longer available."
      end

      reservation = listing.reservations.create!(buyer: buyer, expires_at: now + DURATION,
        agreed_price_cents: listing.price_cents, currency: listing.currency)
      listing.update!(status: :reserved)
      reservation
    end
  end

  def self.cancel(reservation:, buyer:)
    with_reservation_lock(reservation, buyer) do |current, listing|
      next current if current.cancelled? || current.expired?
      raise InvalidState, "A completed purchase cannot be cancelled." if current.completed?

      expire_if_due(current, listing, Time.current)
      if current.active?
        ensure_reserved!(listing)
        current.update!(status: :cancelled)
        listing.update!(status: :available)
      end
      current
    end
  end

  def self.checkout(reservation:, buyer:)
    result = with_reservation_lock(reservation, buyer) do |current, listing|
      next Order.lock.find_by!(reservation_id: current.id) if current.completed?

      now = Time.current
      expire_if_due(current, listing, now)
      next Expired.new("Your reservation has expired. Reserve the item again if it is still available.") if current.expired?
      raise InvalidState, "Only an active reservation can be purchased." unless current.active?
      ensure_reserved!(listing)

      order = Order.create!(listing: listing, buyer: buyer, reservation: current,
        total_cents: current.agreed_price_cents, currency: current.currency, completed_at: now)
      current.update!(status: :completed)
      listing.update!(status: :sold)
      order
    end
    raise result if result.is_a?(Error)

    result
  end

  def self.expire(reservation_id:)
    reservation = Reservation.find_by(id: reservation_id)
    return unless reservation

    listing = Listing.find(reservation.listing_id)
    listing.with_lock(requires_new: true) do
      reservation.reload(lock: true)
      expire_if_due(reservation, listing, Time.current)
      reservation
    end
  end

  def self.with_reservation_lock(reservation, buyer)
    current = Reservation.find(reservation.id)
    listing = Listing.find(current.listing_id)
    listing.with_lock(requires_new: true) do
      current.reload(lock: true)
      raise NotOwner, "This reservation belongs to another buyer." unless current.buyer_id == buyer.id

      yield current, listing
    end
  end
  private_class_method :with_reservation_lock

  def self.expire_if_due(reservation, listing, now)
    return unless reservation.active? && reservation.expires_at <= now

    ensure_reserved!(listing)
    reservation.update!(status: :expired)
    listing.update!(status: :available)
  end
  private_class_method :expire_if_due

  def self.ensure_reserved!(listing)
    raise InvalidState, "The item is not reserved." unless listing.reserved?
  end
  private_class_method :ensure_reserved!
end
