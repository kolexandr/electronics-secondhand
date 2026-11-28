class Reservation < ApplicationRecord
  belongs_to :listing
  belongs_to :buyer, class_name: "User"
  has_one :order, dependent: :restrict_with_error

  enum :status, { active: "active", completed: "completed", cancelled: "cancelled", expired: "expired" }, default: :active, validate: true

  attr_readonly :listing_id, :buyer_id, :agreed_price_cents, :currency, :expires_at

  validates :expires_at, presence: true
  validates :agreed_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: Listing::MAX_PRICE_CENTS }
  validates :currency, inclusion: { in: [ "EUR" ] }
  validate :buyer_is_not_seller

  def valid_for_checkout?
    active? && expires_at > Time.current
  end

  def display_status
    active? && expires_at <= Time.current ? "expired" : status
  end

  private
    def buyer_is_not_seller
      errors.add(:buyer, "cannot reserve their own listing") if listing && buyer_id == listing.seller_id
    end
end
