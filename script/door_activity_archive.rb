# Builds and loads DoorActivityArchive: leaderboard totals for the door logs
# of years the live table no longer holds (August 2012 to April 2020).
#
#   build  bin/rails runner script/door_activity_archive.rb build OUT.json
#          Run against a SCRATCH database holding only the old door logs and
#          the cards of that time, never production. It refuses when it sees
#          logs newer than 2022-01-01. Scores them with DoorActivity's own
#          rules (archive: false) and writes per-member totals.
#   load   bin/rails runner script/door_activity_archive.rb load IN.json
#          On production, after bin/rails db:migrate. Replaces the table's
#          rows in one transaction. Rerunnable.
#
# The JSON holds user ids and totals only, so it is personal data: keep it out
# of git (the ops Omnibus keeps a copy under door-logs/archive/).
require "json"

mode, path = ARGV
abort "usage: build OUT.json | load IN.json" unless %w[build load].include?(mode) && path

if mode == "build"
  newest = DoorLog.maximum(:created_at)
  abort "refusing: this database has door logs from #{newest} (build only on a scratch copy of the old logs)" if newest.nil? || newest > Time.utc(2022, 1, 1)
  oldest = DoorLog.minimum(:created_at)
  activity = DoorActivity.new(now: newest + 1.day)
  opening = activity.opening_stats("all", archive: false)
  days = activity.day_stats("all", archive: false)
  users = (opening.keys | days.keys).compact - [DoorActivity::AUTOMATIC_LOCK_ID]
  rows = users.sort.map do |id|
    o = opening.fetch(id, { hours: 0.0, shifts: 0, opened: 0, locked: 0 })
    { user_id: id, hours: o[:hours], shifts: o[:shifts], opened: o[:opened], locked: o[:locked], days: days.dig(id, :days) || 0 }
  end
  File.write(path, JSON.pretty_generate(
    covers_from: oldest.to_date, covers_to: newest.to_date, built_at: Time.now.utc,
    door_log_rows: DoorLog.count, rows: rows
  ))
  puts "built #{rows.size} members, #{oldest.to_date} to #{newest.to_date}, #{rows.sum { |r| r[:hours] }.round(1)} hours"
else
  abort "run bin/rails db:migrate first (door_activity_archives is missing)" unless DoorActivityArchive.available?
  data = JSON.parse(File.read(path))
  from, to = Date.parse(data.fetch("covers_from")), Date.parse(data.fetch("covers_to"))
  abort "refusing: the archive must end before the live log starts" if to >= Date.new(2022, 7, 30)
  now = Time.current
  records = data.fetch("rows").map do |r|
    { user_id: Integer(r["user_id"]), hours: r["hours"].to_f, shifts: Integer(r["shifts"]), opened: Integer(r["opened"]),
      locked: Integer(r["locked"]), days: Integer(r["days"]), covers_from: from, covers_to: to, created_at: now, updated_at: now }
  end
  DoorActivityArchive.transaction do
    DoorActivityArchive.delete_all
    DoorActivityArchive.insert_all!(records) if records.any?
  end
  Rails.cache.delete_matched("door_activity") rescue nil
  puts "loaded #{records.size} members, #{from} to #{to}"
end
