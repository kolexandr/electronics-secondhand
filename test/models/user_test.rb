require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email and rejects duplicates" do
    user = User.new(display_name: " Alex ", email_address: " ONE@EXAMPLE.COM ", password: "test-password-123")
    assert_equal "one@example.com", user.email_address
    assert_equal "Alex", user.display_name
    assert_not user.valid?
    assert user.errors[:email_address].present?
  end

  test "requires a display name and strong enough password" do
    user = User.new(email_address: "new@example.com", password: "short")
    assert_not user.valid?
    assert user.errors[:display_name].present?
    assert user.errors[:password].present?
  end
end
