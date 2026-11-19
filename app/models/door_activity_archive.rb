# Leaderboard totals for door history the live door_logs table no longer
# holds: the door logs of August 2012 to April 2020, recovered from backups
# and scored once, off the server, with DoorActivity's own rules
# (script/door_activity_archive.rb). One row per member. DoorActivity adds them
# to the "All time" boards, so the server never scans the old logs. April 2020
# to July 2022 was lost and is in neither.
class DoorActivityArchive < ActiveRecord::Base
  # Deploys do not run migrations; until the table exists the boards show the
  # live log only. Asks the database each time (it runs only when the cached
  # board is rebuilt), so a migration is seen without a restart.
  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def self.opening_stats
    return {} unless available?
    all.to_h { |row| [row.user_id, { hours: row.hours.to_f, shifts: row.shifts, opened: row.opened, locked: row.locked }] }
  end

  def self.day_stats
    return {} unless available?
    where("days > 0").to_h { |row| [row.user_id, { days: row.days }] }
  end

  # The span the archive covers, or nil when there is none: for the page note.
  def self.span
    return nil unless available?
    from, to = pick(Arel.sql("MIN(covers_from)"), Arel.sql("MAX(covers_to)"))
    from && (from..to)
  end
end
