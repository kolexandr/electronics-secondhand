require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "converts euro input to exact cents" do
    listing = listings(:router)
    listing.price = "19.99"
    assert_equal 1999, listing.price_cents
    assert listing.valid?
  end

  test "rejects negative fractional and malformed prices" do
    [ "-1", "12.345", "NaN", "1e3", "abc", "1000000", "" ].each do |price|
      listing = listings(:router)
      listing.price = price
      assert_not listing.valid?, price
      assert listing.errors[:price].present?
    end
  end

  test "requires a supported image within the size limit" do
    listing = listings(:router)
    listing.photo = nil
    assert_not listing.valid?
    assert listing.errors[:photo].present?
    listing.photo.attach(io: StringIO.new("not an image"), filename: "file.txt", content_type: "text/plain")
    assert_not listing.valid?
    assert listing.errors[:photo].present?
  end

  test "rejects oversized images" do
    listing = listings(:router)
    listing.photo.blob.byte_size = 6.megabytes
    assert_not listing.valid?
    assert listing.errors[:photo].present?
  end

  test "reserved and sold prices cannot change and listings cannot be destroyed" do
    %w[reserved sold].each do |status|
      listing = listings(:router)
      listing.update_column(:status, status)
      listing.reload.price = "15.00"
      assert_not listing.valid?
      assert_not listing.destroy
    end
  end

  test "MySQL rejects negative prices independently of validations" do
    assert_raises(ActiveRecord::StatementInvalid) { listings(:router).update_column(:price_cents, -1) }
  end
end
