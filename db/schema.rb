ActiveRecord::Schema[8.1].define(version: 2026_11_28_000005) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "listings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.bigint "category_id", null: false
    t.string "title", limit: 120, null: false
    t.text "description", null: false
    t.string "condition", null: false
    t.integer "price_cents", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "status", default: "available", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_listings_on_category_id"
    t.index ["seller_id"], name: "index_listings_on_seller_id"
    t.index ["status", "created_at", "id"], name: "index_listings_on_status_and_created_at_and_id"
    t.index ["status", "price_cents", "id"], name: "index_listings_on_status_and_price_cents_and_id"
    t.check_constraint "(`price_cents` >= 0) and (`price_cents` <= 99999999)", name: "listings_valid_price"
    t.check_constraint "`condition` in (_utf8mb4'like_new',_utf8mb4'good',_utf8mb4'fair',_utf8mb4'for_parts')", name: "listings_valid_condition"
    t.check_constraint "`currency` = _utf8mb4'EUR'", name: "listings_eur_currency"
    t.check_constraint "`status` in (_utf8mb4'available',_utf8mb4'reserved',_utf8mb4'sold')", name: "listings_valid_status"
  end

  create_table "orders", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "buyer_id", null: false
    t.bigint "reservation_id", null: false
    t.integer "total_cents", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
    t.index ["listing_id"], name: "index_orders_on_listing_id", unique: true
    t.index ["reservation_id"], name: "index_orders_on_reservation_id", unique: true
    t.check_constraint "(`total_cents` >= 0) and (`total_cents` <= 99999999)", name: "orders_valid_total"
    t.check_constraint "`currency` = _utf8mb4'EUR'", name: "orders_eur_currency"
  end

  create_table "reservations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "buyer_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "expires_at", null: false
    t.integer "agreed_price_cents", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.virtual "active_listing_id", type: :bigint, as: "(case when (`status` = _utf8mb4'active') then `listing_id` else NULL end)", stored: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_listing_id"], name: "index_reservations_on_active_listing_id", unique: true
    t.index ["buyer_id"], name: "index_reservations_on_buyer_id"
    t.index ["listing_id"], name: "index_reservations_on_listing_id"
    t.index ["status", "expires_at"], name: "index_reservations_on_status_and_expires_at"
    t.check_constraint "(`agreed_price_cents` >= 0) and (`agreed_price_cents` <= 99999999)", name: "reservations_valid_price"
    t.check_constraint "`currency` = _utf8mb4'EUR'", name: "reservations_eur_currency"
    t.check_constraint "`status` in (_utf8mb4'active',_utf8mb4'completed',_utf8mb4'cancelled',_utf8mb4'expired')", name: "reservations_valid_status"
  end

  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "display_name", limit: 80, null: false
    t.string "email_address", limit: 254, null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "listings", "categories"
  add_foreign_key "listings", "users", column: "seller_id"
  add_foreign_key "orders", "listings"
  add_foreign_key "orders", "reservations"
  add_foreign_key "orders", "users", column: "buyer_id"
  add_foreign_key "reservations", "listings"
  add_foreign_key "reservations", "users", column: "buyer_id"
  add_foreign_key "sessions", "users"
end
