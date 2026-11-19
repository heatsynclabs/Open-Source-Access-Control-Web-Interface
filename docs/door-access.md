# Door access

How the members site opens, locks and watches the lab's two doors.

## The short version

- **The door board** (an Arduino at the front door) owns the doors. It keeps the list of
  cards and decides on its own whether a card opens the door. Cards and keys work even if
  the server is off.
- **door-api** is the only thing that talks to the board. The board's network cable goes
  only into the lab server, where door-api runs. Nothing on the Wi-Fi, the lab network or
  the internet can reach it.
- **The members site asks door-api** for everything door-related: remote open and lock,
  card changes, the board's status, and its event log.

```
 member presses "Open front"
   -> members site checks the member may use the remote door
   -> members site asks door-api  (with its API key)
   -> door-api tells the board     (with the board's password, on the private cable)
   -> the front door buzzes for about 5 seconds and locks again
```

## The doors

| Door | Board number | Remote actions on the site |
|---|---|---|
| Front | door 1 | Open (about 5 seconds), Unlock (stays open), Lock |
| Rear | door 2 | Open (about 5 seconds), Lock. Remote unlock of the rear door is refused, by the lab's 2018 rule (`unlock-rear` and `u2`) |

"Lock all" locks both doors. "Unlock all" unlocks both. Remote door control is for
members who hold an active card.

## Things that happen on their own

| Job | When | What it does |
|---|---|---|
| Door log import | every 2 minutes | asks door-api for the board's event log (the board keeps only its last 40 events), saves the events to the database, then confirms so door-api can forget them |
| After-hours lock | every 15 minutes from 22:00 to 08:45 | sends "lock all" as the automatic-lock account (user 468), so the doors are locked overnight even if someone forgot |
| Status | after every door action | stores the board's status (each door locked or not, the alarm fields), which the site and its public status use |

These are Coolify scheduled tasks on the production app. Staging never runs them.

### Why the log import cannot lose events

door-api writes the board's events to its own disk **before** it clears them on the board,
and keeps them until the members site says it has saved them. If the members site is down,
restarting or times out, the events wait in door-api and come back on the next import. A
crash at exactly the wrong moment can save an event twice; it cannot lose one. Two imports
never run at the same time: the site takes a database lock around each one.

One limit comes from the board itself: it holds only 40 log entries between imports, and
each card swipe writes four (the card's two halves, the unlock, the relock). With the import
every 2 minutes, it would take more than about 10 swipes in 2 minutes to push the oldest
entries out. (Until 2026-11-18 the import ran every 6 minutes, and a busy evening could fill
the board's log.)

## The door leaderboard

The leaderboard (`/door_leaderboard`) has two boards, "Kept the lab open" (hours from your
own unlock to your own lock) and "Days at the lab", for this month and for all time. It
reads the door log through `app/queries/door_activity.rb`.

**All time reaches back to 2012.** The live door log starts on 2022-07-30. The years before
were recovered from old backups on 2026-11-19: August 2012 to April 2020 (the log from
April 2020 to July 2022 was lost for good). They were scored once, on a laptop, with the
same rules, and only the per-member totals were loaded into the table
`door_activity_archives`. The all-time boards add those totals, so the server never reads
the old log; the page says which years are included.

**Keeping it light.** This month's numbers are rebuilt at most every 10 minutes and all
time at most every hour (about a second of database work), and only one request rebuilds
while the others are served the old numbers.

**Rebuilding the archive** (only if the rules change):
1. Load the old rows and that era's cards into a scratch database (never production).
   The full log and the card list come from the lab's ops records.
2. `bin/rails runner script/door_activity_archive.rb build archive.json` there.
3. On production: `bin/rails runner script/door_activity_archive.rb load archive.json`.

The archive file holds member ids, so it never goes into git.

## What the board's log entries mean

Each event is a letter and a number, saved as a `door_logs` row.

| Key | Meaning |
|---|---|
| `G` and `g` | access granted; the two halves of the card number (`G` = number mod 32767, `g` = number / 32767) |
| `D` and `d` | access denied (card not on the board); the two halves of the card number |
| `f` | a disabled card was used |
| `U` / `L` | a door was unlocked / locked (the number is the door) |
| `C` and `c` | a keypad command after a card (always 0 here) |
| `a` / `d` (small) | a card slot was written / cleared |
| `F` | a failed or refused console login |
| `rem_...`, `api_rem_...` | a remote command from the site or the phone API; the number is the member's user id |
| `door_1_locked`, `door_2_locked`, `armed`, ... | the board's status after an action |

## Settings

In the production app's Coolify environment (full list: [Configuration](configuration.md)):

| Setting | Production value | Meaning |
|---|---|---|
| `DOOR_BACKEND` | `door_api` (also the default) | send door actions through door-api |
| `DOOR_API_URL` | `http://door-api-prod:3000` | door-api on the server's private network `door-net` |
| `DOOR_API_KEY` | (secret) | the site's key for door-api |
| `DOOR_CONTROLLER` | `front` | door-api's name for the board. It covers both doors |
| `DOOR_DOORS` | `1,2` | the board's doors |
| `DOOR_ACCESS_URL`, `DOOR_ACCESS_PASSWORD` | kept for a rollback only | the old direct path (`DOOR_BACKEND=legacy`), which talked to the board without door-api. It works only if the board is put back on the lab network |

## When it does not work

- **A card does not open the door.**
  - The board decides on its own. Is the card enabled in the site, and was it uploaded?
    See [Access cards](cards.md).
  - Is the board powered?
- **"Failed to connect to door system."** on the remote page: door-api or the board did
  not answer.
  - In Coolify, `door-api-production` and `members-production` should both be "running".
  - The board's cable into the server (port Gb2 on the back) should have a link light.
- **"The door system is busy. Try again in a moment."** Another action was still running
  on the board (it does one thing at a time). door-api drops a door open it cannot start
  within 3 seconds, so a door never opens late when nobody is there.
- **Someone is locked in or out:** cards and physical keys always work, whatever the
  servers are doing.

The lab's operations folder (`docs/24-door-system-now.md`) has the full technical map,
the break-glass steps and how to change the board's password or firmware.
