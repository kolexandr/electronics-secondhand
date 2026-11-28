# Electronics Secondhand

A second-hand electronics marketplace. Development proceeds in reviewable phases;
Phases 1–4 cover listings, authentication, simulated checkout, and background expiration.

## Versions

- Ruby 3.4.13 (recorded in `.ruby-version` and enforced by `Gemfile`)
- Rails 8.1.4.1 (resolved dependencies are recorded in `Gemfile.lock`)
- Bundler 4.1.1
- MySQL 8.4 and Redis 7.4, provided by Docker Compose
- Sidekiq 8.1.7, running Active Job

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
docker compose up -d --wait mysql redis
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

Open <http://localhost:3000> to browse listings.
<http://localhost:3000/up> checks application startup; it does not check MySQL.
Run the worker in a separate terminal:

```sh
bin/jobs
```

Both Rails and Sidekiq use `REDIS_URL`, defaulting locally to
`redis://127.0.0.1:6380/0`. Set it explicitly for deployment. Worker concurrency
and the database pool both use `RAILS_MAX_THREADS` (default 5). Stop the worker
with Ctrl-C or SIGTERM so in-progress work has time to finish. Redis uses an
append-only file and a persistent volume. Do not delete that volume to restart
services. Full web/worker container setup is deferred to Phase 6.

## Reservation expiration

The reservation's `expires_at` timestamp in MySQL determines whether checkout
is allowed. An after-create-commit callback schedules `ExpireReservationJob`
for that time, passing only the reservation ID. No job is sent for a transaction
that rolls back. The job locks the listing, reloads the reservation, and expires
an active, overdue hold in the same transaction that releases the listing.
Repeated jobs and old jobs for completed or cancelled holds have no effect.
Sidekiq retries unexpected job failures; processing may happen more than once.

MySQL and Redis do not share a transaction. A reservation can commit and then
fail to enqueue, or the application can stop between those steps. Known enqueue
failures are logged and reported without pretending the reservation rolled back.
The hold remains real, and checkout still rejects it after its deadline. A new
reservation attempt can release an expired hold under the same listing lock.

To recover overdue holds, including ones whose jobs were lost, run:

```sh
bin/rails reservations:expire_overdue
```

This command talks directly to MySQL and does not require Redis or a worker.
It is safe to repeat or overlap with checkout and expiration jobs. For deployed
operation, have the host scheduler run it once per minute from the application
directory with the application's Ruby and environment. A periodic schedule is
not installed by this repository.

Sidekiq's scheduled jobs can run after their requested time; neither the UI nor
checkout treats worker timing as permission to buy an expired reservation.
See [Sidekiq's job safety guidance](https://github.com/sidekiq/sidekiq/wiki/Best-Practices).


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
Tests cover ownership, listing validation, concurrent purchases, expiry, repeated jobs,
and enqueue behavior after real commits and rollbacks. The test adapter keeps unit
tests independent of Redis; development and production use Sidekiq.
