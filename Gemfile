source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.4", ">= 8.1.4.1"
gem "propshaft"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_cache"
gem "sidekiq", "~> 8.0"
gem "solid_cable"

gem "bootsnap", require: false

gem "kamal", require: false

gem "thruster", require: false

gem "image_processing", "~> 2.2"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  gem "bundler-audit", require: false

  gem "brakeman", require: false

  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "bcrypt", ">= 3.1"
