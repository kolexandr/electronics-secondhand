require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "persists and queries a category through MySQL" do
    assert_equal "Mysql2", Category.connection.adapter_name
    category = Category.create!(name: "Development boards", slug: "development-boards")

    assert_equal category, Category.find_by!(slug: "development-boards")
  end

  test "requires a name and a URL-safe slug" do
    category = Category.new(name: "", slug: "Not a slug")

    assert_not category.valid?
    assert category.errors[:name].present?
    assert category.errors[:slug].present?
  end

  test "database rejects duplicate slugs even without model validation" do
    Category.create!(name: "Routers", slug: "routers")
    duplicate = Category.new(name: "Other routers", slug: "routers")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
