# Overview

The members site (https://members.heatsynclabs.org) is where HeatSync Labs keeps its
member records and runs the front and back doors. Members sign in to see their account,
open the door remotely and check who is at the lab. Admins manage members, access cards,
payments, certifications, signed waivers and the tool list.

## The parts

```
 Members and admins (browser, phone)
        |  https://members.heatsynclabs.org (Cloudflare, then the lab's router)
        v
 Members site (this repository: Ruby on Rails 7.2, PostgreSQL)
   runs on the lab's server (a Dell R610) under Coolify
        |                         |                              |
        | doors, cards,           | waivers and tool photos      | mail
        | door log                |                              |
        v                         v                              v
 door-api                  members-files (Garage)          Gmail (SMTP)
 (repo heatsynclabs/       the lab's own file store
  door-api)
        |
        v
 Door board (Arduino) at the front door: two doors, two card readers,
 the list of cards. It checks cards on its own, so cards and keys keep
 working even when every server is down.
```

- **Members site:** this code. The pages, the database, and the jobs that keep the door log
  and status up to date.
- **door-api:** a small service that is the only thing allowed to talk to the door board.
  The members site asks door-api to open, lock or unlock a door, to write or remove a card,
  or to collect the board's event log. See [Door access](door-access.md).
- **The door board:** an Arduino "Open Access Control" board. It has its own network cable
  into the server, so nothing else on the lab network can reach it.
- **members-files:** the lab's own file store (Garage, an S3-compatible server) on the same
  machine. It holds signed waivers (private) and tool photos. See
  [Files and waivers](files-and-waivers.md).
- **Coolify:** the dashboard on the lab server that builds and runs everything:
  production, staging, door-api and the file store. A push to this repository's `main`
  branch updates the live site. See [Environments and deploying](environments-and-deploying.md).

## Who can do what on the site

| Who | Can |
|---|---|
| Anyone | sign up, see the public status ("is the lab open"), see tool photos |
| A signed-in member | see their account; if they hold a card, open the doors remotely (front: open, unlock, lock; rear: open and lock, never unlock) |
| Instructors | manage certifications and see members |
| Admins | everything, including cards, waivers, payments and the audit log |

## Where to look next

- Something is broken: [Operations](operations.md).
- You are an admin who manages cards: [Access cards](cards.md).
- You want to change the code: [Development](development.md), then
  [Environments and deploying](environments-and-deploying.md).
