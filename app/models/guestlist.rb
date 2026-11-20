# guestlist.co, where the lab sells tickets for classes. Its public JSON
# pages need no login: the profile's upcoming events, one event's counts,
# and its ticket types. Everything else (the full event list, money
# collected) needs the organizer login; see docs/analytics.md.
module Guestlist
  PROFILE_ID = 5662
  USERNAME = "HeatSyncLabs"
  # Calendar and description links: guestlist.co/events/123 or guestli.st/123.
  LINK = %r{guestli(?:\.st|st\.co(?:/events)?)/(\d{4,9})}i
end
