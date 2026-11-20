# Loads TicketedEvent from a guestlist organizer export: the full history of
# the lab's classes, with what guestlist collected for each. How to make the
# export (signed in to guestlist, script/guestlist_export.js in the browser
# console): docs/analytics.md.
#
#   bin/rails runner script/ticketed_events.rb load guestlist-export.json
#
# Replaces every row in one transaction, so it can be rerun; the nightly
# check (bin/rails guestlist:sync) then keeps recent events current. The
# export holds event names and counts only, no attendee data.
require "json"

mode, path = ARGV
abort "usage: load guestlist-export.json" unless mode == "load" && path
abort "run bin/rails db:migrate first (ticketed_events is missing)" unless TicketedEvent.available?

export = JSON.parse(File.read(path))
abort "refusing: not a guestlist export (no events list)" unless export["events"].is_a?(Array)
collected_at = Time.zone.parse(export.fetch("exported_at"))
calendar = begin
  LabCalendar.events.each_with_object(Hash.new { |h, k| h[k] = [] }) do |event, links|
    event.description.scan(Guestlist::LINK).flatten.uniq.each { |id| links[Integer(id)] << event.title }
  end
rescue LabCalendar::Unavailable
  warn "the lab calendar could not be read; statuses come from guestlist alone"
  {}
end

records = export["events"].filter_map do |event|
  next unless event["profile_id"] == Guestlist::PROFILE_ID
  TicketedEvent.attributes_from(event, event.fetch("ticket_types"), source: "organizer export", collected_at: collected_at,
                                calendar_titles: calendar.fetch(event["id"], []), dollars: event["dollars"]&.to_d, now: collected_at)
end
abort "refusing: the export has no HeatSync events" if records.empty?
TicketedEvent.transaction do
  TicketedEvent.delete_all
  TicketedEvent.insert_all!(records)
end
Rails.cache.delete_matched("analytics") rescue nil
held = records.select { |r| r[:status] == "held" }
puts "loaded #{records.size} events (#{held.size} held, #{held.sum { |r| r[:attendees] }} people, " \
     "#{records.count { |r| r[:status] == "cancelled" }} cancelled), exported #{collected_at}"
