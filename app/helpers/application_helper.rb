module ApplicationHelper
  def euro_price(listing)
    euro_amount(listing.price_cents)
  end
  def euro_amount(cents)
    number_to_currency(BigDecimal(cents.to_s) / 100, unit: "€")
  end

  def utc_time(time)
    time.getutc.strftime("%d %b %Y at %H:%M UTC")
  end
end
