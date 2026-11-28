class Order < ApplicationRecord
  belongs_to :listing
  belongs_to :buyer, class_name: "User"
  belongs_to :reservation

  attr_readonly :listing_id, :buyer_id, :reservation_id, :total_cents, :currency, :completed_at

  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: Listing::MAX_PRICE_CENTS }
  validates :currency, inclusion: { in: [ "EUR" ] }
  validates :completed_at, presence: true
  validate :matches_reservation

  private
    def matches_reservation
      return unless reservation

      unless listing_id == reservation.listing_id && buyer_id == reservation.buyer_id &&
          total_cents == reservation.agreed_price_cents && currency == reservation.currency
        errors.add(:base, "Order must match its reservation")
      end
    end
end
