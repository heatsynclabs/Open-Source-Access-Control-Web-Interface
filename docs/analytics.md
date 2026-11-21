# Analytics: where the numbers come from

The analytics page (`/analytics`, any signed-in member) charts the lab's numbers from
five live sources, plus older records on the **Over the years** tab. Some are live, some are copies that have to be refreshed. This guide says
which is which, how each one gets in, and how to refresh the copies. Counts only: nothing
on the page names a person.

The page has a tab per source, **Over the years**, and an **All** tab, which shows every
section (Dues, and the money on Over the years, only for the treasurer and admins). All starts with **Everything together**: the main numbers
on one chart. They are counted in very different amounts, so each line is measured
against its own busy month (its 90th percentile month = 100, clipped at 200), and starts
when its records do. The tooltip and the table under the chart give the real numbers.
Card swipes (every time a card opened the door), cardholders who came in (each card once
a month, however often it was used), calendar events and class sign-ups show at first; new
accounts, tool sign-offs and, for the treasurer and admins, dues payers and dues recorded
are a click away in the legend. All time is drawn by quarter (the average month in each).

The month or week we are in is labelled "so far" and drawn dashed (lines) or paler
(bars), so a half-counted period does not read as a drop.

New accounts leave out bulk loads: any day with 15 or more new accounts (the 2012 launch
and the 2013 imports of the older member list, 264 accounts on four days). The sign-up
form has never made more than 5 in a day since.

| Tab | Source | How it gets in | How fresh |
|---|---|---|---|
| Members | the members database (`users`, `payments`, `certifications`) | the site itself | live |
| Lab use | the door log (`door_logs`), plus `door_log_archives` for 2012 to 2020 | the `door-log-import` scheduled task pulls the door board's log every 2 minutes; the archive was loaded once ([Door access](door-access.md)) | live (2 minutes); October 2020 to July 2022 was lost |
| Calendar | the public lab Google Calendar | read from Google's feed, kept 15 minutes (`LabCalendar`) | 15 minutes |
| Classes | guestlist.co, the lab's ticketing site (`ticketed_events`) | an organizer export by hand, plus a nightly check of guestlist's public pages | nightly for new and recent events; the full history as of the last export |
| Dues (treasurer, admins) | `payments`, from PayPal CSV imports and hand entries | the treasurer imports PayPal CSVs on the PayPal page | as of the last import |
| Over the years | records the site does not hold (`lab_metrics`): PayPal history, the old Wi-Fi log, utility bills, the mailing list, Slack, the old wiki, the calendar's history, account answers, tax returns | worked out in the operations folder and loaded by hand ([below](#over-the-years-older-records)) | as of each record's copy; not live |

Every chart is cached for 10 minutes. The page itself (header, tabs, period buttons)
shows at once; the numbers load into it from `/analytics/section` in a Turbo Frame, with a
placeholder and a "Working out the numbers" line meanwhile, because the first view after
the cache expires can take a few seconds.

## Classes (guestlist.co)

Guestlist has no API key for organizers, so the site cannot read the organizer account.
Two things fill `ticketed_events` instead:

1. **The nightly check** (`bin/rails guestlist:sync`, `app/models/guestlist/sync.rb`).
   Guestlist's public pages need no login and give, for any event, its name, date, ticket
   count, check-ins and ticket types with prices. The check reads every event that is
   upcoming on the lab's guestlist profile, linked from the lab calendar in the last 45
   days or ahead, or already in the table and less than 45 days old. So a new class gets
   in before it happens, and late check-ins are caught for 45 days after. An upcoming
   event that guestlist no longer has is marked cancelled. Money for these events is ticket
   price times tickets, before refunds and fees.
2. **The organizer export** (by hand, a few times a year). It reads every event the
   account has ever had, with what guestlist actually collected, and replaces the table.
   Use it to catch events the nightly check could not see (never on the calendar and
   created and held between two checks), refunds older than 45 days, and the money.

The page says when each was last read ("Not live: ..."), so nobody takes the numbers for
live figures.

How an event is counted:

- **held**: published, in the past, not cancelled, at least one ticket. Only these count.
- **cancelled**: the guestlist name says cancelled or postponed, every lab calendar entry
  that links it is titled cancelled, or it was taken down from guestlist before it ran.
- **no sign-ups**, **never published**, **upcoming**: shown in the event list, not counted.
- People = tickets, less tickets of a donation ticket type ("Optional donation").
- Show-up is measured only at events where someone checked people in at the door.
- Kinds (Laser, Electronics, ...) are read from the event name (`TicketedEvent::KINDS`).

What cannot be seen: a class called off without being renamed, taken down or refunded
still counts as held; classes paid for some other way (cash at the door, Meetup,
Eventbrite) are not here.

### Running an organizer export

You need the guestlist organizer login (the "GuestList" item in the lab's password
manager) and shell access to run a command on the server.

1. Sign in at https://guestlist.co and open https://guestlist.co/manage/events.
2. Open the browser's developer console (Chrome: Cmd+Option+J on a Mac, Ctrl+Shift+J on
   Windows).
3. Paste the whole of `script/guestlist_export.js` and press Enter. It reads every event
   (a few minutes for about 700; keep the tab in front) and saves
   `guestlist-export-YYYY-MM-DD.json` to your Downloads. It reads no attendee names,
   emails or orders.
4. Copy the file into the production container (`members_web`) and load it from `/app`:

       bundle exec rails runner script/ticketed_events.rb load guestlist-export-YYYY-MM-DD.json

   It prints how many events were loaded, held and cancelled. Loading replaces every row
   in one transaction, so it can be rerun; the next nightly check brings recent events up
   to date again.

The operations folder keeps a copy of each export and builds a fuller report from it
(`data/scripts/guestlist.py` and `guestlist_report.py`), which also checks the money
against the PayPal export.

### The nightly task

A Coolify scheduled task on members-production, `guestlist-sync`, runs
`sh -c 'cd /app && bundle exec rails guestlist:sync'` in `members_web` at 03:10 Arizona
time (frequency `10 10 * * *`, which Coolify reads as UTC). It prints one line, for example
`guestlist sync: 26 read, 1 taken_down`, and fails only when guestlist answered nothing at
all. To run it by hand, use Execute on the task in Coolify, or run
`bundle exec rails guestlist:sync` in the container from `/app`. It needs nothing but
outbound HTTPS to guestlist.co.

## Over the years (older records)

This tab shows long series from records the site does not keep itself, each over every
year its records reach; it has no period buttons. Each chart has a **Deep dive** link to a
page with everything behind it (`?section=history&topic=`, the list is
`Analytics::History::TOPICS`): paying members against this site's own payment records
and by tier; the Wi-Fi by weekday and arrival hour beside card swipes of the same years;
electricity through the year; the mailing list and Slack with first-time posters; the
wiki; the calendar (the live calendar's all years by kind, hours, weekday and longest-running events, beside the archived tables); the laser cutter (live, with a link to the Laser page); how people find the lab; and money (treasurer and
admins only). The figures are worked out
in the operations folder (`HeatSync Labs Operations 2026/data/`, one script per source,
described in its `README.md`) and loaded into the table `lab_metrics`: one row per metric,
breakdown (for example a building, a ZIP code or a wiki page) and month, year or total.
The table holds counts and totals only. A blank value means fewer than 5 (the operations
data writes any count of people under 5 as "<5"), and the tab says "fewer than 5".

| Chart | Source (operations `data/`) | Period | Left out or partial |
|---|---|---|---|
| Paying members | `membership/paypal_monthly.csv`: every PayPal record (the Board's exports 2014 to 2022, this site's `paypal_csvs` imports, a PayPal download), each transaction counted once | Apr 2013 to Sep 2026 | subscription dues of $25 or more only (cash and checks are never in PayPal); months with missing or part records (Oct and Nov 2025 have none) |
| Laser cutters | live: the table `laser_jobs`, read every night from both lasers' current and old log forms ([Laser settings](laser.md)), not `lab_metrics` | large 80 W from Nov 2013, mini 60 W from Dec 2019, the lab's first laser Sep 2011 to Apr 2013, to last month | only logged jobs; no names; results only from the current forms (April 2022); blank stretches had nothing logged |
| Devices on the lab Wi-Fi | `attendance/wifi_monthly.csv`, from the old `mac_logs` table | Feb 2013 to Feb 2017 | always-on equipment; months with under 15 days of data |
| Electricity used a day | `finances/utilities_monthly.csv`, from the City of Mesa bills on the Board drive | Jun 2011 to Jun 2022 | the two buildings are separate lines |
| Messages and people posting | `community/mailing_list_monthly.csv` (one member's copy of the Google Group, counted from its daily summaries) and `community/slack_monthly.csv` | Aug 2011 to Apr 2026; Slack Apr 2018 to Aug 2026 | Slack's part months at each end |
| Wiki edits, most-read pages | `community/wiki_activity_by_year.csv`, `community/wiki_most_read.csv` | 2009 to 2025; views to Oct 2026 | articles only (no user or talk pages) |
| Where events were held, who keeps the calendar | `events/calendar_places_by_year.csv`, `events/calendar_contributors_by_year.csv`, from the December 2025 calendar download | 2010 to 2025 | 2025 ends on 10 December |
| How people heard about the lab, where members live | `membership/how_heard_by_year.csv`, `membership/members_by_zip.csv` and `members_by_zone.csv` (ZIP codes grouped into areas by USPS ranges, drawn as dots on Arizona's real map with a Phoenix metro view: `ZoneMapHelper`, outlines in `app/models/arizona_map.rb`, generated once by `script/arizona_map.py` from us-atlas 3.0.1, US Census boundaries, public domain; nothing is fetched when the page loads), from the September 2026 database copy | 2012 to 2026 | the free-text answers are never copied, only kinds by keyword; ZIP codes with fewer than 5 people grouped |
| Money (treasurer, admins) | PayPal dues and donations by year, `finances/form990_by_year.csv` (the Form 990-EZ returns, 2010 to 2024), utility bills by year | 2010 to 2026 | donations from mid-2022 to mid-2025 (only dues were imported then) |

### Refreshing the figures

1. In the operations folder, rerun the script for the source that changed (the commands
   are in `data/README.md`, "Regenerating"), for example a new PayPal download for
   `paypal_members.py` or a new Slack export for `slack.py`.
2. Build the file the site loads:

       python3 -I data/scripts/lab_metrics_export.py data lab-metrics-YYYY-MM-DD.json

3. Copy it into the `members_web` container (production or staging) and load it from `/app`:

       bundle exec rails runner script/lab_metrics.rb load lab-metrics-YYYY-MM-DD.json

   Loading replaces the rows of every metric in the file in one transaction, so it can be
   rerun; it prints how many rows and which metrics it loaded. The table must exist first
   (`bundle exec rails db:migrate`).
