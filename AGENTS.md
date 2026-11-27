The project is second-hand electronics marketplace using Ruby on Rails, MySQL, Redis, and Sidekiq. 

1. The product and its scope

Project lets people sell used routers, development boards, computer components, and other electronics.

The main user journey:

    A seller publishes an item with a photo, condition, and price.
    A buyer searches and filters listings.
    The buyer reserves an item for 15 minutes.
    The buyer completes a simulated purchase.
    If they abandon the purchase, the reservation expires.
    Both users can see the order in their account.

Build these pages:

    Browse listings.
    Listing details.
    Create/edit a listing.
    My listings.
    My reservations and purchases.
    Sign up/sign in.

Keep payments simulated and shipping out of the first version. A complete, reliable purchase flow already gives you substantial backend work.
2. The technology stack
Technology	Its specific job
Ruby on Rails	Routes, controllers, business logic, rendered pages
MySQL	Users, listings, reservations, orders, constraints and transactions
Active Record	Models, associations, migrations and database queries
Redis + Sidekiq	Background jobs, particularly reservation expiration
Active Job	Rails interface for defining and enqueueing those jobs
Active Storage	Listing photos
ERB + Turbo	A usable interface with minimal custom JavaScript
Minitest	Business-rule, request, job and integration tests
Docker Compose	Reproducible MySQL, Redis, web and worker setup
GitHub Actions	Automated tests and code checks

MySQL is a sensible choice here. It gives you exposure to the database mentioned in the vacancy, while your existing PostgreSQL experience remains useful.

One Rails detail to know: Rails 8 uses Solid Queue by default, which stores jobs in a database. To learn Redis and Sidekiq, deliberately configure Sidekiq as the Active Job adapter. You only need one job backend.

Redis already has a meaningful purpose as Sidekiq’s backing store. You don’t need to add caching immediately to justify it.
3. The database models and fields

Start with these five domain models. Rails authentication and Active Storage will introduce their own supporting tables.
Model	Main fields
User	email_address, password_digest, display_name
Category	name, slug
Listing	seller_id, category_id, title, description, condition, price_cents, currency, status
Reservation	listing_id, buyer_id, status, expires_at, agreed_price_cents, currency
Order	listing_id, buyer_id, reservation_id, total_cents, currency, completed_at

Use Rails timestamps on all models.

Decisions to make explicitly:

    Each listing represents one physical item.
    Use EUR only initially, while retaining a currency field.
    Store money as integer cents.
    Listing states: available, reserved, sold.
    Reservation states: active, completed, cancelled, expired.
    Capture the agreed price when creating the reservation.
    Prevent price changes while reserved and prevent deleting listings with purchase history.
    Add foreign keys, required-column constraints, and appropriate unique indexes.

For this simplified model, unique indexes on an order’s listing_id and reservation_id provide database protection against duplicate purchases.