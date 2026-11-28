require "test_helper"

class ReservationEnqueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  self.use_transactional_tests = false
  self.fixture_table_names = []

  class InspectingAdapter < ActiveJob::QueueAdapters::TestAdapter
    attr_accessor :failure
    attr_reader :observations

    def initialize
      super
      @observations = []
    end

    def enqueue_at(job, timestamp)
      raise failure if failure

      @observations << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          reservation = Reservation.find_by(id: job.arguments.first)
          [ reservation.present?, reservation&.listing&.status ]
        end
      end.value
      super
    end
  end

  setup do
    @original_adapter = ExpireReservationJob.queue_adapter
    @adapter = InspectingAdapter.new
    ExpireReservationJob.queue_adapter = @adapter
    token = SecureRandom.hex(8)
    @seller = User.create!(display_name: "Seller", email_address: "enqueue-seller-#{token}@example.com", password: "test-password-123")
    @buyer = User.create!(display_name: "Buyer", email_address: "enqueue-buyer-#{token}@example.com", password: "test-password-123")
    @category = Category.create!(name: "Enqueue test", slug: "enqueue-#{token}")
    @listing = @seller.listings.build(category: @category, title: "Enqueue item", description: "Test item", condition: "good", price_cents: 1000)
    File.open(Rails.root.join("test/fixtures/files/listing.png")) do |file|
      @listing.photo.attach(io: file, filename: "listing.png", content_type: "image/png")
      @listing.save!
    end
  end

  teardown do
    ExpireReservationJob.queue_adapter = @original_adapter
    if @listing&.persisted?
      Reservation.where(listing_id: @listing.id).delete_all
      @listing.photo.purge
      Listing.where(id: @listing.id).delete_all
    end
    @category&.destroy!
    @buyer&.reload&.destroy!
    @seller&.reload&.destroy!
  end

  test "enqueues only after the outer transaction commits" do
    reservation = nil
    Listing.transaction do
      reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
      assert_empty @adapter.enqueued_jobs
    end
    assert_equal [ [ true, "reserved" ] ], @adapter.observations
    assert_equal 1, @adapter.enqueued_jobs.length
    assert_equal [ reservation.id ], @adapter.enqueued_jobs.first[:args]
    assert_in_delta reservation.expires_at.to_f, @adapter.enqueued_jobs.first[:at], 0.001
  end

  test "rolling back the outer transaction does not enqueue expiration" do
    Listing.transaction do
      ReservationService.reserve(listing: @listing, buyer: @buyer)
      raise ActiveRecord::Rollback
    end
    assert_empty @adapter.enqueued_jobs
    assert_empty @adapter.observations
    assert_equal 0, @listing.reservations.count
    assert @listing.reload.available?
  end

  test "Redis failure preserves the committed hold and expiration can recover it" do
    @adapter.failure = RedisClient::CannotConnectError.new("Simulated Redis outage")
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    assert reservation.reload.active?
    assert @listing.reload.reserved?
    assert_empty @adapter.enqueued_jobs
    travel_to reservation.expires_at, with_usec: true do
      ReservationService.expire(reservation_id: reservation.id)
    end
    assert reservation.reload.expired?
    assert @listing.reload.available?
  end

  test "an enqueue rejection also preserves the committed hold" do
    @adapter.failure = ActiveJob::EnqueueError.new("Simulated enqueue rejection")
    reservation = ReservationService.reserve(listing: @listing, buyer: @buyer)
    assert reservation.reload.active?
    assert @listing.reload.reserved?
    assert_empty @adapter.enqueued_jobs
  end
end
