# The window sign

The LED sign in the front window (30 by 8 pixels, an ESP8266) is driven from
**Devices** in the site's menu. Its firmware, its own control page and its API
are in [heatsynclabs/marquee](https://github.com/heatsynclabs/marquee).

## Who can do what

| | Door-card holders | Admins |
|---|---|---|
| Put a message up (rate limited to 6 a minute each) | yes | yes |
| One-tap buttons: Open Hours, Robot, Clock, Back to normal | yes | yes |
| Brightness: Low, Normal, Bright | yes | yes |
| What it shows between messages | | yes |
| Check lab status now, restart the sign | | yes |
| Recent messages | | yes |

Every action goes in the audit log (`marquee.message`, `marquee.preset`,
`marquee.brightness`, `marquee.rotation`, `marquee.poll`, `marquee.restart`)
with the member's name and the text sent.

## How it talks to the sign

- The site calls the sign over plain HTTP on the lab network
  (`app/models/marquee/client.rb`): 2 s to connect, 4 s to answer, no retries.
  Anything that goes wrong is shown on the page; nothing is raised.
- The page loads without waiting for the sign. Its status (refreshed every
  15 s while the tab is open) and the admin rotation form load into Turbo
  Frames.
- Messages are cleaned to printable ASCII (the sign's font), 100 characters at
  most, and only the offered colours and repeat counts are sent.
- The address is the **Marquee host** setting (Admin, Settings), defaulting to
  `MARQUEE_HOST`. The sign holds a fixed address, 172.22.110.185, set in its
  own firmware (outside the DHCP pool), so it does not move.

## Lab open and the closing time

The sign polls `space_api.json` every five minutes. While the doors are
unlocked, the space API also carries `"open_until": "21:00"` when a calendar
event in the Open hours category is running, and the sign then scrolls
`... COME IN UNTIL 9 PM`. The lookup reads only the calendar copy already
cached by the calendar pages, so the space API never waits on Google
(`LabCalendar.open_hours_until`).

## Staging

Staging uses the same default address, so the staging Devices page drives the
real sign. That is harmless (it is a sign, not a door), but everything sent
from staging shows in the window.
