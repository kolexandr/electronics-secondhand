module ApplicationHelper
  def euro_price(listing)
    number_to_currency(BigDecimal(listing.price_cents.to_s) / 100, unit: "€")
  end
end
