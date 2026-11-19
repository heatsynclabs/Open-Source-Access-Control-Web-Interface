# One member's own door history, for the Door stats tab of their profile:
# year by year since 2012, when in the week they come in, and the last twelve
# months. Uses DoorActivity's rules, so the numbers add up to the member's
# all-time leaderboard figures.
#
# Old years come from DoorActivityArchive; the live log's openings come from
# DoorActivity's hourly cache, so a profile never scans the whole log. The
# member's own visits are one small query, cached here for ten minutes.
class MemberDoorStats
  CACHE_FOR = 10.minutes
  MONTHS_SHOWN = 12

  Year = Struct.new(:year, :days, :hours, :shifts, :opened, :locked, keyword_init: true)

  def initialize(user, now: Time.zone.now)
    @user = user
    @now = now
    @activity = DoorActivity.new(now: now)
  end

  # Years with any activity, oldest first.
  def years
    @years ||= begin
      archived = DoorActivityArchive.years_for(@user.id).to_h do |row|
        [row.year, Year.new(year: row.year, days: row.days, hours: row.hours.to_f, shifts: row.shifts, opened: row.opened, locked: row.locked)]
      end
      live_days = visit_days.map(&:year).tally
      live_opening = @activity.cached_stats(:opening_by_year, "all").transform_values { |by_user| by_user[@user.id] }.compact
      (live_days.keys | live_opening.keys).each do |year|
        o = live_opening.fetch(year, {})
        live = Year.new(year: year, days: live_days.fetch(year, 0), hours: o.fetch(:hours, 0.0), shifts: o.fetch(:shifts, 0),
                        opened: o.fetch(:opened, 0), locked: o.fetch(:locked, 0))
        archived[year] = archived.key?(year) ? add(archived[year], live) : live
      end
      archived.values.sort_by(&:year)
    end
  end

  # { year => value of attribute } from the first active year to this one,
  # zero for years without any (the lost years show as gaps).
  def by_year(attribute)
    return {} if years.empty?
    found = years.to_h { |year| [year.year, year[attribute]] }
    (years.first.year..@now.year).to_h { |year| [year, found.fetch(year, 0)] }
  end

  # All years together, as one Year (year: nil).
  def total
    years.reduce(Year.new(days: 0, hours: 0.0, shifts: 0, opened: 0, locked: 0)) { |sum, year| add(sum, year) }
  end

  def any?
    years.any?
  end

  # { [weekday (0 = Sunday), hour] => visits } in the live log, lab time.
  def week_grid
    visit_times.map { |at| [at.wday, at.hour] }.tally
  end

  # { first day of month => days at the lab } for the last twelve months,
  # empty months included.
  def recent_months
    first = (@now.to_date << (MONTHS_SHOWN - 1)).beginning_of_month
    counts = visit_days.select { |day| day >= first }.map(&:beginning_of_month).tally
    (0...MONTHS_SHOWN).to_h { |i| month = first >> i; [month, counts.fetch(month, 0)] }
  end

  # Card swipes and remote unlocks or opens in the live log.
  def visit_counts
    visits.map(&:last).tally
  end

  # 1 for the top of the all-time board (score: :days or :hours), nil when
  # the member is hidden or not on it.
  def rank(score)
    return nil if @user.hidden?
    board = score == :days ? :days : :opening
    stats = @activity.cached_stats(board, "all")
    mine = stats.dig(@user.id, score)
    return nil unless mine&.positive?
    ahead = stats.select { |_, s| s[score] > mine }.keys - [DoorActivity::AUTOMATIC_LOCK_ID]
    User.where(id: ahead).where(hidden: [nil, false]).count + 1
  end

  private

  def add(a, b)
    Year.new(year: a.year || b.year, days: a.days + b.days, hours: (a.hours + b.hours).round(1), shifts: a.shifts + b.shifts,
             opened: a.opened + b.opened, locked: a.locked + b.locked)
  end

  # [[time, :card or :remote], ...] (see DoorActivity#visits), as plain values
  # so they cache.
  def visits
    @visits ||= Rails.cache.fetch(["member_door_stats", "v1", @user.id], expires_in: CACHE_FOR) do
      @activity.visits(@user.id).map { |at, kind| [at.to_i, kind] }
    end.map { |seconds, kind| [Time.zone.at(seconds), kind] }
  end

  def visit_times
    visits.map(&:first)
  end

  # Distinct lab days with a visit.
  def visit_days
    @visit_days ||= visit_times.map(&:to_date).uniq
  end
end
