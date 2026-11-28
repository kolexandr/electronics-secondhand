require "test_helper"
require "timeout"

class ReservationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    assert_equal "Mysql2", ActiveRecord::Base.connection.adapter_name
    token = SecureRandom.hex(8)
    @users = 3.times.map do |index|
      User.create!(display_name: "Concurrent #{index}", email_address: "concurrent-#{token}-#{index}@example.com", password: "test-password-123")
    end
    @category = Category.create!(name: "Concurrency test", slug: "concurrency-#{token}")
    @listing = @users.first.listings.build(category: @category, title: "Concurrent item", description: "Test item",
      condition: "good", price_cents: 2500)
    File.open(Rails.root.join("test/fixtures/files/listing.png")) do |file|
      @listing.photo.attach(io: file, filename: "listing.png", content_type: "image/png")
      @listing.save!
    end
  end

  teardown do
    if @listing&.persisted?
      Order.where(listing_id: @listing.id).delete_all
      Reservation.where(listing_id: @listing.id).delete_all
      @listing.photo.purge
      Listing.where(id: @listing.id).delete_all
    end
    @category&.destroy!
    @users&.each { |user| user.reload.destroy! }
  end

  test "two simultaneous buyers produce exactly one reservation" do
    results = concurrently(
      -> { ReservationService.reserve(listing: @listing, buyer: @users[1]) },
      -> { ReservationService.reserve(listing: @listing, buyer: @users[2]) }
    )
    assert_equal 1, results.count { |result| result.is_a?(Reservation) }, results.inspect
    assert_equal 1, results.count { |result| result.is_a?(ReservationService::Unavailable) }, results.inspect
    assert_equal 1, Reservation.where(listing_id: @listing.id).count
    assert_equal 1, Reservation.active.where(listing_id: @listing.id).count
    assert @listing.reload.reserved?
  end

  test "two simultaneous checkouts return the same order" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @users[1])
    operation = -> { ReservationService.checkout(reservation: reservation, buyer: @users[1]) }
    results = concurrently(operation, operation)
    assert results.all? { |result| result.is_a?(Order) }, results.inspect
    assert_equal 1, results.map(&:id).uniq.length
    assert_equal 1, Order.where(listing_id: @listing.id).count
    assert reservation.reload.completed?
    assert @listing.reload.sold?
  end

  test "cancellation racing checkout leaves one consistent final state" do
    reservation = ReservationService.reserve(listing: @listing, buyer: @users[1])
    results = concurrently(
      -> { ReservationService.cancel(reservation: reservation, buyer: @users[1]) },
      -> { ReservationService.checkout(reservation: reservation, buyer: @users[1]) }
    )
    assert_equal 1, results.count { |result| result.is_a?(ReservationService::InvalidState) }, results.inspect
    if reservation.reload.completed?
      assert @listing.reload.sold?
      assert_equal 1, Order.where(listing_id: @listing.id).count
    else
      assert reservation.cancelled?
      assert @listing.reload.available?
      assert_equal 0, Order.where(listing_id: @listing.id).count
    end
  end

  private
    def concurrently(*operations)
      ready = Queue.new
      start = Queue.new
      results = Queue.new
      threads = operations.map do |operation|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT CONNECTION_ID()")
            start.pop
            begin
              results << operation.call
            rescue StandardError => error
              results << error
            end
          end
        end
      end
      ids = Timeout.timeout(10) { operations.map { ready.pop } }
      assert_equal operations.length, ids.uniq.length
      operations.length.times { start << true }
      threads.each { |thread| assert thread.join(20), "Concurrent operation timed out" }
      operations.map { results.pop }
    ensure
      threads&.each do |thread|
        thread.kill if thread.alive?
        thread.join
      end
    end
end
