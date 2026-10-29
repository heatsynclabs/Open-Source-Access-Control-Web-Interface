# Open Access Control Web Interface

Web software for managing a database of members in a collaborative grassroots workshop, and also controlling Arclight of 23b Hackerspace's Arduino access control system via Ethernet ( see: https://github.com/zyphlar/Open_Access_Control_Ethernet )

https://github.com/zyphlar/Open-Source-Access-Control-Web-Interface

Copyright Will Bradley, 2012-2024
Distributed under a Creative Commons Attribution 3.0 license http://creativecommons.org/licenses/by/3.0/

![screenshot](doc/screenshot.png)

Contributions welcome! Simply send a pull request via Github.


## This branch

HeatSync's production members app, brought off Rails 3.2. Now Ruby 3.3 / Rails 7.2 / PostgreSQL, Dockerized, and themed with GANTRY (light or dark, following the device until someone picks one). Same features (members, door logs, payments, certifications, audit log, member signup), current stack, plus a lab calendar and an analytics page.


## How the front end is built

* **One layout** (`app/views/layouts/application.html.erb`) for every page: header, main nav, the role menus (Treasurer, Admin), caution tape, footer.
* **Stylesheets** in `app/assets/stylesheets`, compiled with Dart Sass (`dartsass-sprockets`), so modern CSS works as written. `gantry_tokens.scss` is the GANTRY token set shared with heatsynclabs.org; everything else uses its variables, in cascade layers: `base`, `layout`, `components` (with `forms` and `tables`), `calendar`, `charts`, `pages` (and `pages/*.scss` per area).
* **ViewComponents** in `app/components` for repeated pieces: `PageHeaderComponent` (also sets the tab title), `StatTileComponent`, `ChipComponent`, `MemberBadgeComponent`, `AvatarComponent`, `DoorTileComponent`, `FormErrorsComponent`, `EmptyStateComponent`, `ChartCardComponent`, and the calendar's `Calendar::*` components. Icons are Lucide (`lucide_icon "name"`).
* **JavaScript** through import maps (`config/importmap.rb`), no Node build. Behavior is in Stimulus controllers (`app/javascript/controllers`). Turbo is used only for frames (the calendar card loads after the page); Turbo Drive is off, so jquery_ujs still handles sign out and delete links (`app/assets/javascripts/legacy.js`).
* **Charts** are Chartkick and Chart.js (`app/javascript/charts.js`, loaded only on pages with a chart). Each theme has its own palette, checked for colour-blind separation.


## Lab calendar

`/calendar` shows the lab's public Google Calendar as a month grid, a week or a list, with the same categories and colours as heatsynclabs.org. `Calendar::WeekComponent` is the "this week" card; drop it into a page with `<%= render "calendar/week_frame" %>`, which loads it in a Turbo Frame so the page never waits on Google.

`LabCalendar` (`app/models/lab_calendar*`) reads the public ICS feed on the server, keeps a fresh copy for 15 minutes and the last good copy for a week, and expands repeating events with `icalendar-recurrence`. Set `GOOGLE_CALENDAR_ICS_URL` to read a different calendar. No API key is needed.


## Analytics

`/analytics` is open to everyone and linked in the main nav: members, door use and the calendar, as counts only, plus dues for treasurers and admins. The queries are in `app/queries/analytics`, one small class per subject, grouped in lab time with `groupdate`, and cached for 10 minutes per period.


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
* The calendar, analytics and component tests run green: `... bundle exec rails test test/models/lab_calendar test/queries test/components`. The older scaffold tests predate the Rails 7 upgrade and still need updating.


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
