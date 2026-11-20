# Loads TicketedEvent from the guestlist events CSV that the ops data
# scripts build (data/scripts/guestlist.py, file guestlist_events.csv).
#
#   bin/rails runner script/ticketed_events.rb load guestlist_events.csv
#
# On production, after bin/rails db:migrate. Replaces the table's rows in
# one transaction, so it can be rerun with a newer pull. The CSV holds
# event names and counts only.
require "csv"

mode, path = ARGV
abort "usage: load guestlist_events.csv" unless mode == "load" && path
abort "run bin/rails db:migrate first (ticketed_events is missing)" unless TicketedEvent.available?

now = Time.current
records = CSV.foreach(path, headers: true).map do |row|
  status = row.fetch("status")
  abort "refusing: unknown status #{status.inspect}" unless TicketedEvent::STATUSES.include?(status)
  { guestlist_id: Integer(row.fetch("guestlist_id")), name: row.fetch("event"), held_on: Date.parse(row.fetch("date")),
    kind: row.fetch("kind"), status: status, attendees: Integer(row.fetch("attendees")), checked_in: Integer(row.fetch("checked_in")),
    dollars: BigDecimal(row.fetch("dollars")), created_at: now, updated_at: now }
end
TicketedEvent.transaction do
  TicketedEvent.delete_all
  TicketedEvent.insert_all!(records) if records.any?
end
Rails.cache.delete_matched("analytics") rescue nil
held = records.select { |r| r[:status] == "held" }
puts "loaded #{records.size} events (#{held.size} held, #{held.sum { |r| r[:attendees] }} attendees), " \
     "#{records.map { |r| r[:held_on] }.min} to #{records.map { |r| r[:held_on] }.max}"
