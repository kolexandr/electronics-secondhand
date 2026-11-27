# Electronics Secondhand

A second-hand electronics marketplace. Development proceeds in reviewable phases;
Phase 1 establishes Rails, MySQL, and a persistent Category model.

## Versions

- Ruby 3.4.13 (recorded in `.ruby-version` and enforced by `Gemfile`)
- Rails 8.1.4.1 (resolved dependencies are recorded in `Gemfile.lock`)
- Bundler 4.1.1
- MySQL 8.4, provided by Docker Compose

Use the [Rails 8.1 guides](https://guides.rubyonrails.org/v8.1/)
and [getting started guide](https://guides.rubyonrails.org/v8.1/getting_started.html).
Commit both `.ruby-version` and `Gemfile.lock` so other developers use the same versions.

## Local setup

Run commands from this directory. Install the recorded Ruby version with your Ruby
version manager, then run `bundle install`. With mise, use `mise install` and
prefix Ruby commands with `mise exec --` if your shell hasn't activated mise.
Building the mysql2 gem requires MySQL client development headers and a compiler.

```sh
ruby --version
bundle install
docker compose up -d --wait mysql
```

The development connection defaults to `127.0.0.1:3307`, user `regear`, password
`local_app_password`. These are disposable local credentials. Override `DB_HOST`,
`DB_PORT`, `DB_USERNAME`, and `DB_PASSWORD` for another local MySQL installation.
Never use these sample passwords for a deployed database.

The MySQL initialization script creates `regear_test` and grants the app user
access to it. Initialization scripts only run on an empty MySQL volume. If you
already started this project's database before adding the script, apply it once:

```sh
docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot' < db/docker-init/01-test-database.sql
```

If Docker reports socket permission denied, use `sudo` for the Docker commands
or configure Docker access for your user. Keep the volume: deleting it deletes data.

```sh
bin/rails db:prepare
bin/rails server
```

Open <http://localhost:3000> for the generated Rails welcome page.
<http://localhost:3000/up> checks application startup; it does not check MySQL.
Redis is already declared in Compose but is not needed for Phase 1. Sidekiq and
reservation expiration will be configured in Phase 4, replacing generated Solid
Queue configuration. Full web/worker container setup is deferred to Phase 6.

## Verify persistence in the Rails console

```sh
bin/rails console
```

```ruby
ActiveRecord::Base.connection.select_value("SELECT VERSION()")
category = Category.create!(name: "Console check", slug: "console-check")
Category.find_by!(slug: "console-check").name
category.destroy!
```

Category is the first domain model. Required columns and a unique slug index
protect the database, while model validations provide useful errors to callers.

## Checks

```sh
RAILS_ENV=test bin/rails db:prepare
PARALLEL_WORKERS=1 bin/rails test
bin/rails zeitwerk:check
bin/rubocop
```

Tests use MySQL and a separate `regear_test` database. For now, use one worker so
the local database user only needs access to the two explicitly created databases.
The category tests check persistence, validation, and the database uniqueness constraint.
Authentication and listing pages begin in Phase 2.
