# Operations

What runs, how to tell it is healthy, and what to do when it is not. Logins and secrets are
held by the IT officers (the operations folder). The full technical map of the door system
is the operations folder's `docs/24-door-system-now.md`.

## What runs (all on the lab's server, in Coolify)

| Resource | What | Healthy looks like |
|---|---|---|
| `members-production` | this site | "running:healthy"; https://members.heatsynclabs.org loads |
| `door-api-production` | the only client of the door board | "running:healthy" |
| `members-files` | the file store and its nightly backup | "running" |
| `members-staging`, `door-api-staging` | the staging copies | "running" |

## Scheduled jobs (members-production, Scheduled Tasks)

| Job | When | Healthy looks like |
|---|---|---|
| `door-log-import` | every 2 minutes | recent executions "success"; Admin > Door logs shows new rows after door use |
| `door-after-hours-lock` | :00, :15, :30, :45 from 22:00 to 08:45 | executions "success"; the doors show locked overnight |
| `guestlist-sync` | 03:10 daily | executions "success", output like `guestlist sync: 26 read`; see [Analytics](analytics.md) |

To pause one (for maintenance), turn it off in Scheduled Tasks and back on afterwards.
Pausing the log import loses nothing unless the board fills its 40 events.

## Logs

- **Coolify, the app, Logs:** the site's log, and door-api's log, which has one line per door
  action with the member.
- **Admin pages:** Door logs (every board event and remote command) and the audit log (admin
  changes).

## Backups

| What | How | Where |
|---|---|---|
| The database | nightly dump (02:00) by the server's backup job | `/data/backups/offsite/members`, uploaded off site by SpiderOak |
| Waivers and photos | nightly copy (01:30) by `members-files-backup` | `/data/backups/offsite/members-files`, uploaded off site by SpiderOak |
| Door board cards | the board keeps them itself; the site can re-upload all of them | the site's database is the master list |

## Class sign-ups on the analytics page

The class numbers are copied from guestlist.co: a nightly check of its public pages
(`guestlist-sync`, below) plus an organizer export by hand. How both work and how to run
an export: [Analytics](analytics.md).

## When something breaks

| Symptom | First checks |
|---|---|
| The site is down | Coolify: `members-production` status and Logs. Recent deploy? Redeploy the last good one ([Environments and deploying](environments-and-deploying.md)) |
| Remote door buttons fail | `door-api-production` running? The board powered, its cable to the server's Gb2 port lit? Cards and keys still work meanwhile ([Door access](door-access.md)) |
| Door logs stop updating | the `door-log-import` executions; door-api's log |
| Photos or waivers missing | `members-files` running? The site's log for "stored file ... not read" ([Files and waivers](files-and-waivers.md)) |
| Emails not arriving | the site's log for mail errors; the SMTP settings ([Configuration](configuration.md)) |
| A member cannot get in with their card | the card is enabled and uploaded ([Access cards](cards.md)) |

Anything involving the board's password, its firmware, or the server's network is in the
operations folder's runbooks. Ask an IT officer.
