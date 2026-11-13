# door-api integration (this branch)

This branch (`door-api-integration`) lets the members app talk to the door
controller through the external **door-api** service
(https://github.com/heatsynclabs/door-api) instead of driving the board directly,
behind a feature flag. It is **not merged to `main` and not deployed**. The flag
defaults to `legacy`, so merging/deploying it changes nothing until the flag is
flipped.

## What it changes

A single flag, `door_backend`, switches the board-touching paths:

| Operation | `legacy` (default, unchanged) | `door_api` |
|---|---|---|
| `Card#upload_to_door` / `upload_all_to_door` | direct board HTTP (`DoorBoard`) | `PUT card` / `POST cards/sync` to door-api |
| `Card` destroy | board untouched | `DELETE card` (best effort) |
| `DoorLog.execute_command` (remote door control) | direct board | `POST doors/:n/{unlock,lock,open}` |
| `DoorLog.download_status` | direct board | door-api status, written as the same `door_N_locked` rows |
| `DoorLog.download_from_door` (event log) | direct board | **unchanged — stays legacy** (see below) |

Status and the door log stay DB-backed (the app reads `DoorLog` rows), so the UI
is unchanged.

## Enabling it

Set these (config keys, or the matching env vars now that `docker-entrypoint.sh`
maps them, so they can be Coolify environment variables):

| Config key | Env var | Example |
|---|---|---|
| `door_backend` | `DOOR_BACKEND` | `door_api` |
| `door_api_url` | `DOOR_API_URL` | `http://door-api:3000` |
| `door_api_key` | `DOOR_API_KEY` | a `full`-permission door-api key |
| `door_controller` | `DOOR_CONTROLLER` | the controller id in door-api, e.g. `front` |
| `door_doors` | `DOOR_DOORS` | `1,2` |

Roll back instantly by setting `DOOR_BACKEND=legacy`.

## Mapping rules (important)

- **Card number**: the DB stores `card_number` as hex; door-api wants decimal.
  The client sends `card_number.to_i(16)`.
- **Permissions -> doors**: `card_permissions == 1` (enabled) -> the configured
  door list; `255` (disabled) -> `[]` (present, no access).
- **Stats**: the per-card "days used" stat matches `DoorLog` `G` rows with
  `data = card_number.to_i(16) % 32767`.

## The event log stays legacy on purpose

The Arduino's event buffer is clear-on-read with no stable index, so it does not
fit door-api's incremental `events()`. `download_from_door` keeps reading the board
directly. This means in `door_api` mode the board must still be directly reachable
for event ingestion until the UHPPOTE cutover (whose events are index-stable), at
which point this moves to door-api too.

## Tested

- Unit: `test/unit/door_api_client_test.rb` (client verbs, status mapping,
  hex->decimal card routing, command mapping, errors).
- End-to-end in Docker against door-api + a faithful Arduino simulator
  (`door-api/sim`): sign in, `/cards`, create a card, upload-all -> `cards/sync` ->
  board; disable -> mask 255; delete -> removed; door unlock/lock; and legacy mode
  (upload, control, swipe -> door-log rows). Both backends verified.

## Pending (not in this branch)

- **Card-number migration gate**: before syncing real cards to a UHPPOTE board,
  confirm how its card number relates to the stored `card_number` with one physical
  card (door-api `docs/ARCHITECTURE.md`). Do not migrate cards until settled.
- Phase 3+: a per-card sync state (synced/pending/failed) so a door-api outage never
  blocks a DB write, and the "recent unknown swipes" new-card UX. See door-api
  `docs/MEMBERS-INTEGRATION.md`.
