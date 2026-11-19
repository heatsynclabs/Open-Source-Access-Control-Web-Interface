# Door activity for the years the live door_logs table no longer holds: the
# door logs of 2012 to October 2020, recovered from backups and scored once,
# off the server, with DoorActivity's rules (script/door_activity_archive.rb
# loads them). One row per member per year. DoorActivity adds them to the
# "All time" boards and MemberDoorStats to a member's own history, so the
# server never scans the old logs. October 2020 to July 2022 was lost and is
# in neither.
class DoorActivityArchive < ActiveRecord::Base
  TOTALS = { hours: "SUM(hours)", shifts: "SUM(shifts)", opened: "SUM(opened)", locked: "SUM(locked)", days: "SUM(days)" }.freeze

  # Deploys do not run migrations; until the table exists the boards show the
  # live log only. Asks the database each time (it runs only when the cached
  # board is rebuilt), so a migration is seen without a restart.
  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end

  # { user_id => { hours:, shifts:, opened:, locked: } }, summed over the years.
  def self.opening_stats
    totals.transform_values { |t| t.slice(:hours, :shifts, :opened, :locked) }
  end

  # { user_id => { days: } } for members with at least one day.
  def self.day_stats
    totals.select { |_, t| t[:days].positive? }.transform_values { |t| t.slice(:days) }
  end

  # One member's archived years, oldest first. Rows loaded before the
  # archive had years (year empty) are left out.
  def self.years_for(user_id)
    return none unless available?
    where(user_id: user_id).where.not(year: nil).order(:year)
  end

  # The span the archive covers, or nil when there is none: for the page notes.
  def self.span
    return nil unless available?
    from, to = pick(Arel.sql("MIN(covers_from)"), Arel.sql("MAX(covers_to)"))
    from && (from..to)
  end

  def self.totals
    return {} unless available?
    group(:user_id).pluck(:user_id, *TOTALS.values.map { |sql| Arel.sql(sql) }).to_h do |id, *sums|
      [id, TOTALS.keys.zip(sums).to_h { |key, sum| [key, key == :hours ? sum.to_f : sum.to_i] }]
    end
  end
  private_class_method :totals
end
