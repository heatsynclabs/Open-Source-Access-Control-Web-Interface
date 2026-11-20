# Analytics: where the numbers come from

The analytics page (`/analytics`, any signed-in member) charts the lab's numbers from
five sources. Some are live, some are copies that have to be refreshed. This guide says
which is which, how each one gets in, and how to refresh the copies. Counts only: nothing
on the page names a person.

The page has a tab per source and an **All** tab. All starts with **Everything together**:
the main numbers on one chart, each line drawn against its own busiest month (= 100) so
lines counted in hundreds and in tens can be compared by shape. Click a name in the legend
to hide or show its line; the real numbers are in the table under the chart.

| Tab | Source | How it gets in | How fresh |
|---|---|---|---|
| Members | the members database (`users`, `payments`, `certifications`) | the site itself | live |
| Lab use | the door log (`door_logs`), plus `door_log_archives` for 2012 to 2020 | the `door-log-import` scheduled task pulls the door board's log every 2 minutes; the archive was loaded once ([Door access](door-access.md)) | live (2 minutes); October 2020 to July 2022 was lost |
| Calendar | the public lab Google Calendar | read from Google's feed, kept 15 minutes (`LabCalendar`) | 15 minutes |
| Classes | guestlist.co, the lab's ticketing site (`ticketed_events`) | an organizer export by hand, plus a nightly check of guestlist's public pages | nightly for new and recent events; the full history as of the last export |
| Dues (treasurer, admins) | `payments`, from PayPal CSV imports and hand entries | the treasurer imports PayPal CSVs on the PayPal page | as of the last import |

Every chart is cached for 10 minutes.

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
4. Copy the file into the production container and load it:

       bin/rails runner script/ticketed_events.rb load guestlist-export-YYYY-MM-DD.json

   It prints how many events were loaded, held and cancelled. Loading replaces every row
   in one transaction, so it can be rerun; the next nightly check brings recent events up
   to date again.

The operations folder keeps a copy of each export and builds a fuller report from it
(`data/scripts/guestlist.py` and `guestlist_report.py`), which also checks the money
against the PayPal export.

### The nightly task

A Coolify scheduled task on members-production, `guestlist-sync`, runs
`bin/rails guestlist:sync` at 03:10 Arizona time. It prints one line, for example
`guestlist sync: 26 read, 1 taken_down`, and fails only when guestlist answered nothing at
all. To run it by hand: `bin/rails guestlist:sync` in the container. It needs nothing but
outbound HTTPS to guestlist.co.
