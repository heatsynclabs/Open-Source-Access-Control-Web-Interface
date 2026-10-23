# Open Access Control Web Interface

Web software for managing a database of members in a collaborative grassroots workshop, and also controlling Arclight of 23b Hackerspace's Arduino access control system via Ethernet ( see: https://github.com/zyphlar/Open_Access_Control_Ethernet )

https://github.com/zyphlar/Open-Source-Access-Control-Web-Interface

Copyright Will Bradley, 2012-2024
Distributed under a Creative Commons Attribution 3.0 license http://creativecommons.org/licenses/by/3.0/

![screenshot](doc/screenshot.png)

Contributions welcome! Simply send a pull request via Github.


## This branch

HeatSync's production members app, brought off Rails 3.2. Now Ruby 3.3 / Rails 7.2 / PostgreSQL, Dockerized, and themed with GANTRY (light by default, dark toggle). Same features (members, door logs, payments, certifications, audit log, member signup), current stack.


## Run locally (Docker)

* `docker compose up`
* Seed the (development, right?) database: `docker compose exec members_web bundle exec rake db:setup`
* Serves on http://localhost:3000. This machine maps it to 3001 via a gitignored `docker-compose.override.yml` to dodge a local port conflict; do the same if 3000 is taken.
* Sign in with the seeded admin in `db/seeds.rb`.
* Postgres is at `postgres://postgres:postgres@localhost:5432/members_db_development`. The DB persists in the `db_data` volume; source is copied at build, so rebuild `members_web` after code changes.
* Inbucket (dev mail catcher) is at http://localhost:10001.


## Tests

* `docker compose exec members_web bundle exec rails test` (Test::Unit, under `test/`)
* One file: append the path, e.g. `... bundle exec rails test test/unit/user_test.rb`
* The suite predates the Rails 7 upgrade and needs updating before it runs green. The app itself is verified working.


## Configuration

For a real deploy (the Docker dev defaults aside), create these from their `.example` templates. All are gitignored; keep the secrets in a password manager, not the repo.

* `config/database.yml`: Postgres per environment (`database`, `host`, `username`, `password`, `pool`).
* `config/config.yml`, per environment:
  * `door_access_url`: the access-control board's HTTP address.
  * `door_access_password`: its admin password. Secret.
  * `smtp_address`, `smtp_port`, `smtp_domain`, `smtp_authentication`, `smtp_tls`, `smtp_user`, `smtp_password`: outbound mail for member notices and password resets. `smtp_password` is a secret (a Gmail app password in practice).
* `.env` (from `env.example`):
  * `S3_BUCKET`, `S3_KEY`, `S3_SECRET`: AWS S3 for member photo uploads via Paperclip. Secrets. Or skip S3 and point Paperclip at local storage in the `resource` and `contract` models.
  * `DOORACCESS_DATABASE_USERNAME`, `DOORACCESS_DATABASE_PASSWORD`: the Postgres credentials the Docker compose reads.
* `config/initializers/secret_token.rb`: `secret_token`, a 30 character or longer random string that signs session cookies. Secret. Generate with `rake secret`; rotating it signs everyone out.
* `SECRET_KEY_BASE` (environment variable, production): backs Devise's reset and confirmation tokens. Set it for a current Rails 7 deploy; the legacy `secret_token.rb` above still handles session signing.
* `config/initializers/devise.rb`: password hashing. `config.stretches` is the bcrypt cost (10 here; bcrypt salts each password itself, so there is no salt to set). `config.pepper` is an optional secret mixed into every password before hashing. It ships commented out, and once set it must stay fixed or every stored password stops matching.
* `db/seeds/admin.rb`: the initial admin email and password created by `rake db:seed`. Change it before production.


## Manual setup

* Install Imagemagick (for Paperclip / image uploads)
* Install arp-scan (for LAN Mac address scanning)
* Load into a Ruby 3.3 / Rails 7.2 environment
* Copy config/config.yml.example to config/config.yml and edit appropriately
* Copy config/database.yml.example to config/database.yml and edit appropriately
* Copy env.example to .env and edit appropriately for your Amazon S3 account OR adjust the resource.rb and contract.rb model settings to use different storage for picture attachments (via Paperclip)
* Copy config/initializers/secret_token.rb.example to config/initializers/secret_token.rb and edit appropriately
* See/edit db/seeds.rb for the initial admin account info.
* Run bundle install, rake db:migrate, rake db:seed, etc.
