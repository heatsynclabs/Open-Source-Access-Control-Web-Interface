# Configuration

Every setting the site reads, what it does, and where it is set. On the lab's server, all
of them are Coolify environment variables of the app (production or staging), except those
marked "compose file", which are written in `docker-compose.production.yml` or
`docker-compose.staging.yml` so they cannot be changed from the dashboard. Secrets are
never in this repository.

On start, `docker-entrypoint.sh` copies the door and mail settings into `config/config.yml`;
the rest are read straight from the environment.

## Core

| Setting | Meaning | Secret |
|---|---|---|
| `RAILS_ENV` | `production` (compose file) | |
| `SECRET_KEY_BASE` | signs sessions and password-reset links. Changing it signs everyone out | yes |
| `DATABASE_URL` | the PostgreSQL database (built in the compose file from `POSTGRES_PASSWORD`) | yes |
| `POSTGRES_PASSWORD` | the database password | yes |
| `MAIL_HOST`, `MAIL_PROTOCOL` | the address used in links in emails; default `members.heatsynclabs.org`, `https` | |

## Mail

| Setting | Meaning | Secret |
|---|---|---|
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_TLS`, `SMTP_DOMAIN`, `SMTP_AUTHENTICATION`, `SMTP_USER` | outgoing mail (member notices, password resets) | |
| `SMTP_PASSWORD` | the mail account's app password | yes |

## Doors (see [Door access](door-access.md))

| Setting | Meaning | Secret |
|---|---|---|
| `DOOR_BACKEND` | `door_api` (default): doors through door-api. `legacy`: talk to the board directly (only for a rollback, with the board back on the lab network) | |
| `DOOR_API_URL` | door-api's address (production: `http://door-api-prod:3000`) | |
| `DOOR_API_KEY` | the site's key for door-api | yes |
| `DOOR_CONTROLLER` | door-api's name for the board (`front`; it covers both doors) | |
| `DOOR_DOORS` | the board's doors (`1,2`) | |
| `DOOR_ACCESS_URL`, `DOOR_ACCESS_PASSWORD` | the board's address and password for the `legacy` path | password yes |
| `DOOR_CRON_PASSWORD` | the automatic-lock account's password, used by the night-lock job | yes |
| `DOOR_JOBS` | `off` stops the door log import and the night lock (compose file; staging only) | |

## Files (see [Files and waivers](files-and-waivers.md))

| Setting | Meaning | Secret |
|---|---|---|
| `S3_ENDPOINT` | the file store (`http://members-files:3900`). Empty means Amazon S3 | |
| `S3_REGION` | `garage` for the lab's store; `us-east-1` for Amazon | |
| `S3_BUCKET` | tool photos (`members-photos`) | |
| `S3_DOCUMENTS_BUCKET` | signed waivers (`members-waivers`); empty means the same bucket as photos | |
| `S3_KEY`, `S3_SECRET` | the access key for the store | yes |

## Window sign (see [The window sign](window-sign.md))

| Setting | Meaning | Secret |
|---|---|---|
| `MARQUEE_HOST` | default address of the LED sign on the lab network (`172.22.111.158`). The **Marquee host** site setting overrides it without a redeploy | |

## Staging only (compose file or Coolify)

| Setting | Meaning |
|---|---|
| `STAGING_NOTICE` | the text of the staging bar on every page |
| `STAGING_DB_REFRESH` | unset: load last night's production backup on every deploy. `off`: keep staging's data |
| `STAGING_HOST` | staging's address |

## Networks (compose file)

| Network | Joined by | Purpose |
|---|---|---|
| `door-net` | production site, door-api production | the site reaches door-api. Created by door-api's own compose file |
| `files-net` | production and staging sites, members-files | the sites reach the file store. Created once on the server |

A deploy fails with "network ... could not be found" if one is missing.
