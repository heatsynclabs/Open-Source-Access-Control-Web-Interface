# Environments and deploying

There are two copies of the site, both on the lab's server and both run by Coolify
(`http://172.22.110.200:8000`, lab network or VPN).

| | Production | Staging |
|---|---|---|
| Address | https://members.heatsynclabs.org | https://staging.heatsynclabs.org |
| Git branch | `main` | `staging` |
| Coolify app | `members-production`, project Critical Infra, environment production | `members-staging`, project Critical Infra, environment staging |
| Compose file | `docker-compose.production.yml` | `docker-compose.staging.yml` |
| Data | the real database | a fresh copy of last night's production backup, loaded on every staging deploy |
| Doors | the real board, through door-api production | a copy of the board's real firmware running in an emulator, through door-api staging. **Staging never moves a real door** |
| Files | the lab's file store, read and write | tool photos only, read only; no waivers |
| Mail | sent to members | caught by Mailpit (`http://172.22.110.200:8025`), never sent |
| Scheduled door jobs | yes (log import, night lock) | none (`DOOR_JOBS=off` is written in its compose file) |

Every staging page shows a staging bar, and tab titles start with "Staging:".

## How a push deploys

A push to GitHub sends a webhook to Coolify. Coolify rebuilds the app whose branch matches:
- `main` deploys production;
- `staging` deploys staging;
- any other branch deploys nothing.

A build takes 2 to 5 minutes, and the site is briefly unavailable while the new container
starts.

Deploys do **not** run database migrations. A change that needs one must have it run by
hand on production.

## Making a change, testing it, shipping it

1. **Start from `staging`:** `git checkout staging && git pull`, then
   `git checkout -b my-change`. If `main` has moved on, merge `main` into `staging` first.
2. **Test on your laptop** ([Development](development.md)): run the site and the tests.
3. **Put it on staging:** merge your branch into `staging` and push. In a few minutes
   https://staging.heatsynclabs.org has your change, with last night's real data.
4. **Try it on staging** the way members will. Sign in with your normal account. Emails
   appear in Mailpit. Door buttons work against the emulator, so try them freely.
5. **Ship it:** open a pull request from `staging` to `main`, have someone look at it, and
   merge. The merge deploys production. Then check https://members.heatsynclabs.org and the
   app's Logs in Coolify.
6. **Keep staging in step:** after shipping, merge `main` back into `staging`.

## Undoing a change

- **Quickest:** in Coolify, open `members-production`, Deployments, and redeploy the
  previous good one. Or set the app's commit (General, "Git Commit SHA") to the last good
  commit and Deploy.
- **Then** revert the merge on `main` with a pull request, so the next push does not bring
  the change back.
- **Before redeploying:** check the Git Commit SHA setting is `HEAD` (or the commit you
  mean). A redeploy builds whatever that setting says.

## Related services

door-api (doors) and members-files (files) are separate Coolify resources with their own
deploys: door-api from its own repository (`heatsynclabs/door-api`, the same branch rules),
members-files from a compose file kept in the lab's operations folder.
