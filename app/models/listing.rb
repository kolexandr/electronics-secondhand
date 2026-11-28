class Listing < ApplicationRecord
  CONDITIONS = { "like_new" => "Like new", "good" => "Good", "fair" => "Fair", "for_parts" => "For parts" }.freeze
  MAX_PRICE_CENTS = 99_999_999

  belongs_to :seller, class_name: "User", inverse_of: :listings
  belongs_to :category
  has_one_attached :photo

  enum :status, { available: "available", reserved: "reserved", sold: "sold" }, default: :available, validate: true

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, presence: true, length: { maximum: 5000 }
  validates :condition, inclusion: { in: CONDITIONS.keys }
  validates :currency, inclusion: { in: [ "EUR" ] }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_PRICE_CENTS }
  validate :valid_price_input
  validate :acceptable_photo
  validate :price_is_not_locked
  before_destroy :require_available_status, prepend: true

  def price
    return @price_input if defined?(@price_input)
    format("%.2f", price_cents / 100.0) if price_cents
  end

  def price=(value)
    @price_input = value.to_s.strip
    self.price_cents = self.class.cents_from(@price_input)
  end

  def self.cents_from(value)
    text = value.to_s.strip
    return unless text.match?(/\A\d{1,6}(?:\.\d{1,2})?\z/)

    (BigDecimal(text) * 100).to_i
  end

  private
    def valid_price_input
      if defined?(@price_input) && self.class.cents_from(@price_input).nil?
        errors.add(:price, "must be a positive euro amount or zero, with at most two decimal places")
      end
    end

    def acceptable_photo
      unless photo.attached?
        errors.add(:photo, "is required")
        return
      end

      errors.add(:photo, "must be a JPEG, PNG, or WebP image") unless photo.blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:photo, "must be smaller than 5 MB") if photo.blob.byte_size > 5.megabytes
    end

    def price_is_not_locked
      if persisted? && status_in_database != "available" && (will_save_change_to_price_cents? || will_save_change_to_currency?)
        errors.add(:price, "cannot change while the listing is reserved or sold")
      end
    end

    def require_available_status
      unless available?
        errors.add(:base, "Only available listings can be removed")
        throw :abort
      end
    end
end
