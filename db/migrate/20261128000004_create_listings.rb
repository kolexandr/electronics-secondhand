class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false, limit: 120
      t.text :description, null: false
      t.string :condition, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "EUR", limit: 3
      t.string :status, null: false, default: "available"
      t.timestamps
    end

    add_index :listings, [ :status, :created_at, :id ]
    add_index :listings, [ :status, :price_cents, :id ]
    add_check_constraint :listings, "price_cents >= 0 AND price_cents <= 99999999", name: "listings_valid_price"
    add_check_constraint :listings, "currency = 'EUR'", name: "listings_eur_currency"
    add_check_constraint :listings, "status IN ('available', 'reserved', 'sold')", name: "listings_valid_status"
    add_check_constraint :listings, "`condition` IN ('like_new', 'good', 'fair', 'for_parts')", name: "listings_valid_condition"
  end
end
