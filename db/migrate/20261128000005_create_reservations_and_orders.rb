class CreateReservationsAndOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :listing, null: false, foreign_key: true
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "active"
      t.datetime :expires_at, null: false
      t.integer :agreed_price_cents, null: false
      t.string :currency, null: false, default: "EUR", limit: 3
      t.virtual :active_listing_id, type: :bigint,
        as: "CASE WHEN status = 'active' THEN listing_id ELSE NULL END", stored: true
      t.timestamps
    end

    add_index :reservations, :active_listing_id, unique: true
    add_index :reservations, [ :status, :expires_at ]
    add_check_constraint :reservations, "agreed_price_cents >= 0 AND agreed_price_cents <= 99999999", name: "reservations_valid_price"
    add_check_constraint :reservations, "currency = 'EUR'", name: "reservations_eur_currency"
    add_check_constraint :reservations, "status IN ('active', 'completed', 'cancelled', 'expired')", name: "reservations_valid_status"

    create_table :orders do |t|
      t.references :listing, null: false, foreign_key: true, index: { unique: true }
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.references :reservation, null: false, foreign_key: true, index: { unique: true }
      t.integer :total_cents, null: false
      t.string :currency, null: false, default: "EUR", limit: 3
      t.datetime :completed_at, null: false
      t.timestamps
    end

    add_check_constraint :orders, "total_cents >= 0 AND total_cents <= 99999999", name: "orders_valid_total"
    add_check_constraint :orders, "currency = 'EUR'", name: "orders_eur_currency"
  end
end
