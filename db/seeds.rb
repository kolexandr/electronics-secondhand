abort "Demo seeds are only available in development" unless Rails.env.development?

categories = [ "Networking", "Development boards", "Computer components", "Peripherals" ].to_h do |name|
  category = Category.find_or_create_by!(slug: name.parameterize) { |record| record.name = name }
  [ name, category ]
end

sellers = [ [ "alex@example.com", "Alex" ], [ "sam@example.com", "Sam" ] ].map do |email, name|
  User.find_or_create_by!(email_address: email) do |user|
    user.display_name = name
    user.password = "Regear-demo-2026!"
  end
end

items = [
  [ "TP-Link Archer C7 router", "Networking", "good", 2800, "router", "Reliable dual-band router. Reset and tested. Includes its original power adapter; a few marks on the underside." ],
  [ "Raspberry Pi 4 · 4 GB", "Development boards", "good", 4500, "board", "Used for a home automation project. Boots reliably. Board and heatsinks included; bring your own power supply and microSD card." ],
  [ "GeForce GTX 1660 Super", "Computer components", "good", 9500, "gpu", "6 GB graphics card from a desktop upgrade. Both fans work. Tested over HDMI; no original box." ],
  [ "Keychron K2 keyboard", "Peripherals", "like_new", 5500, "keyboard", "Compact mechanical keyboard with brown switches. USB-C cable and spare keycaps included. Cleaned and tested." ],
  [ "Arduino Uno starter board", "Development boards", "fair", 1200, "board", "Working Uno-compatible board with USB cable. Pin labels show some wear. A useful starting point for breadboard experiments." ],
  [ "Netgear GS108 switch", "Networking", "good", 2200, "router", "Eight gigabit ports tested. Metal enclosure with small scratches. Includes 12 V adapter." ],
  [ "ESP32 development board", "Development boards", "like_new", 600, "board", "Unused spare from a workshop. USB-C board with Wi-Fi and Bluetooth; headers already soldered." ],
  [ "Radeon RX 580 · 8 GB", "Computer components", "fair", 6000, "gpu", "Working card with visible cosmetic wear. Cleaned recently. Needs an 8-pin PCIe power connector." ],
  [ "Logitech wired keyboard", "Peripherals", "good", 1500, "keyboard", "Full-size USB keyboard. All keys tested. UK layout, no wireless receiver required." ],
  [ "ASUS RT-AC68U router", "Networking", "fair", 3000, "router", "Dual-band router with working Ethernet ports. One antenna cap is scratched. Power adapter included." ],
  [ "Raspberry Pi Zero W", "Development boards", "good", 1600, "board", "Small Wi-Fi board for a compact project. MicroSD slot and USB tested. Bare board, no accessories." ],
  [ "GTX 970 for repair", "Computer components", "for_parts", 1800, "gpu", "Produces display artifacts under load. Sold for parts or diagnosis, not as a working graphics card." ],
  [ "Ducky One 2 Mini", "Peripherals", "good", 4800, "keyboard", "60% mechanical keyboard with red switches. USB-C cable included. Cleaned keycaps; all switches working." ],
  [ "Five-port gigabit switch", "Networking", "like_new", 1400, "router", "Small fanless desktop switch. Used briefly, with original adapter and box." ],
  [ "Pico W project board", "Development boards", "good", 500, "board", "Working microcontroller board with headers. Firmware erased and ready for a new project." ],
  [ "Spare mechanical keyboard", "Peripherals", "for_parts", 900, "keyboard", "Two keys intermittently fail. Useful for switches, keycaps, or a repair project. USB cable included." ]
]

items.each_with_index do |(title, category, condition, cents, image, description), index|
  seller = sellers[index % sellers.length]
  next if seller.listings.exists?(title: title)

  listing = seller.listings.build(title: title, category: categories.fetch(category), condition: condition,
    price_cents: cents, description: "#{description}\n\nDemo listing: the image is an illustration, not a photograph of an actual item.")
  File.open(Rails.root.join("db/seed_images/#{image}.png")) do |file|
    listing.photo.attach(io: file, filename: "#{image}.png", content_type: "image/png")
    listing.save!
  end
end

puts "Demo accounts: alex@example.com / sam@example.com; password: Regear-demo-2026!"
