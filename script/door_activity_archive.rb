# Loads DoorActivityArchive: per member per year door activity for the years
# the live door_logs table does not hold (2012 to October 2020).
#
#   bin/rails runner script/door_activity_archive.rb load IN.json
#
# On production, after bin/rails db:migrate. Replaces the table's rows in one
# transaction, so it can be rerun; reloading the previous file undoes it.
#
# The file is built off the server, from the fullest door log and the card
# lists of every surviving members backup (a swipe belongs to whoever held
# the card then), scored with DoorActivity's rules. The script and the file
# live in the ops Omnibus (door-logs/); the file holds user ids, so it is
# personal data and stays out of git. Its shape:
#   { "covers_from": "2012-09-15", "covers_to": "2020-10-05",
#     "rows": [{ "user_id": 10, "year": 2014, "hours": 1.5, "shifts": 1,
#                "opened": 2, "locked": 1, "days": 150 }, ...] }
require "json"

mode, path = ARGV
abort "usage: load IN.json" unless mode == "load" && path
abort "run bin/rails db:migrate first (door_activity_archives is missing)" unless DoorActivityArchive.available?
abort "run bin/rails db:migrate first (door_activity_archives has no year)" unless DoorActivityArchive.column_names.include?("year")

data = JSON.parse(File.read(path))
from, to = Date.parse(data.fetch("covers_from")), Date.parse(data.fetch("covers_to"))
abort "refusing: the archive must end before the live log starts" if to >= Date.new(2022, 7, 30)
now = Time.current
records = data.fetch("rows").map do |r|
  year = Integer(r.fetch("year"))
  abort "refusing: a row for #{year} is outside #{from.year} to #{to.year}" unless (from.year..to.year).cover?(year)
  { user_id: Integer(r["user_id"]), year: year, hours: r["hours"].to_f, shifts: Integer(r["shifts"]), opened: Integer(r["opened"]),
    locked: Integer(r["locked"]), days: Integer(r["days"]), covers_from: from, covers_to: to, created_at: now, updated_at: now }
end
DoorActivityArchive.transaction do
  DoorActivityArchive.delete_all
  DoorActivityArchive.insert_all!(records) if records.any?
end
Rails.cache.delete_matched("door_activity") rescue nil
puts "loaded #{records.size} rows for #{records.map { |r| r[:user_id] }.uniq.size} members, #{from} to #{to}, " \
     "#{records.sum { |r| r[:hours] }.round(1)} hours, #{records.sum { |r| r[:days] }} days"
