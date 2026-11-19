# Development

## Run the site on your laptop

You need Docker.

1. `docker compose up`
2. In another terminal, set up the database once:
   `docker compose exec members_web bundle exec rake db:setup`
3. Open http://localhost:3000 and sign in with the admin in `db/seeds.rb`.
   - **Mail** is caught at http://localhost:10001 (Inbucket).
   - **The database** is at `postgres://postgres:postgres@localhost:5432/members_db_development`.

The code is copied into the image when it is built, so rebuild after changing code
(`docker compose build members_web`).

**Never point a local run at the lab's real door board.** Keep
`DOOR_ACCESS_URL=http://127.0.0.1:9` (an address where nothing answers). For door work, use
the door emulator below.

## Tests

- **Everything:** `docker compose exec members_web bundle exec rails test test/unit test/integration test/models test/queries test/components`
- **One file:** add its path, for example `.../rails test test/unit/door_api_client_test.rb`
- **Covered:** the door paths (every remote command, status, the log import, cards, the
  rear-door rule), the file pages (waiver access, photo caching, upload checks), and the
  calendar, analytics and page components.
- **Older tests:** some scaffold controller tests under `test/functional` were written for
  Rails 4 and still fail. They are not about current behaviour.

## The door emulator

The door-api repository has two board simulators:

- `sim/arduino-openaccess.mjs`: a quick JavaScript copy of the board's replies, for unit
  tests.
- `sim/avr/`: **the board's real firmware**, compiled and run on an emulated Arduino chip,
  with the network chip, clock, card readers and relays modelled around it. It behaves
  exactly like the board, including its timing and quirks. Staging uses it.

The lab's operations folder has an end-to-end test that runs this site through door-api and
through the old direct path against two copies of the emulator, and compares every reply,
every saved row and every relay pulse (`tools/door-cutover/e2e/run.sh avr`).

## Where things are in the code

| Area | Files |
|---|---|
| Door commands, status, log import | `app/models/door_log.rb`, `app/models/door_api_client.rb`, `app/models/concerns/door_board.rb` |
| Cards and slots | `app/models/card.rb`, `app/controllers/cards_controller.rb` |
| Remote door page and phone API | `app/controllers/space_api_controller.rb`, `app/controllers/api/v1/doors_controller.rb` |
| Files and waivers | `config/initializers/file_storage.rb`, `app/models/contract.rb`, `app/models/resource.rb`, `app/controllers/concerns/sends_stored_files.rb` |
| Who may do what | `app/models/ability.rb` |
| Deploy settings | `docker-compose.production.yml`, `docker-compose.staging.yml`, `docker-entrypoint.sh` |
