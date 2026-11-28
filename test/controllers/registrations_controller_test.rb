require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signs up and starts an authenticated session" do
    get new_registration_path
    assert_response :success
    assert_difference [ "User.count", "Session.count" ], 1 do
      post registration_path, params: { user: { display_name: "Taylor", email_address: " TAYLOR@example.com ", password: "test-password-123", password_confirmation: "test-password-123" } }
    end
    assert_redirected_to root_path
    assert cookies[:session_id].present?
    get mine_listings_path
    assert_response :success
    assert_equal "taylor@example.com", User.find_by!(display_name: "Taylor").email_address
  end

  test "rejects duplicate email without creating a session" do
    assert_no_difference [ "User.count", "Session.count" ] do
      post registration_path, params: { user: { display_name: "Someone", email_address: "ONE@example.com", password: "test-password-123", password_confirmation: "test-password-123" } }
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors", /Email address has already been taken/
  end

  test "rejects invalid registration" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: { display_name: "", email_address: "bad", password: "short", password_confirmation: "different" } }
    end
    assert_response :unprocessable_entity
  end
end
