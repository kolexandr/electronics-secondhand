class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :listings, foreign_key: :seller_id, inverse_of: :seller, dependent: :restrict_with_error

  normalizes :email_address, with: ->(value) { value.strip.downcase }
  normalizes :display_name, with: ->(value) { value.strip }

  validates :email_address, presence: true, uniqueness: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { maximum: 80 }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
