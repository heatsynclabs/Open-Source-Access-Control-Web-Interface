# Who opens and locks up the lab, read from the door board's log.
#
# What the log holds (checked against a year of production rows):
#   - The lab opens when a member unlocks the front door remotely, from the
#     site (rem_u=1) or the phone app (api_rem_u=1); data is their user id.
#     Card swipes only let one person through.
#   - Locks are remote too: a member (rem_l*, their id) or the after-hours
#     lock (user id 468, every 15 minutes from 22:00).
#   - The board reports the front door's state (door_1_locked, 0 or 1) right
#     after each command and every 6 minutes.
#
# So a "period" is a remote unlock the board confirms (reports unlocked within
# ten minutes), lasting until it reports the front door locked again. Periods
# under half an hour are someone being let in, not the lab opening, and do not
# count. Hours go only to whoever both unlocked and locked a period; opening up
# and locking up are counted for everyone.
class DoorActivity
  AUTOMATIC_LOCK_ID = DoorLogsHelper::AUTOMATIC_LOCK_ID
  CARD_HALF = DoorLogsHelper::CARD_HALF

  # Commands that unlock or lock the front door. "u=2" (the rear door) is
  # refused but still logged, so it never counts.
  FRONT_UNLOCK_KEYS = %w[rem_u api_rem_u rem_u=1 api_rem_u=1].freeze
  FRONT_LOCK_KEYS = %w[rem_l api_rem_l rem_l=1 api_rem_l=1].freeze
  # Remote commands that mean the person was dealing with the door that day.
  PRESENCE_KEYS = (FRONT_UNLOCK_KEYS + %w[rem_o1 rem_o2 api_rem_o1 api_rem_o2]).freeze

  CONFIRM_WITHIN = 10.minutes   # the board reports right after a command
  LOCK_BEFORE_CLOSE = 15.minutes # a lock command this close to the locked report caused it
  LONGEST_PERIOD = 14.hours     # nothing open longer than this is trusted
  SHORTEST_PERIOD = 30.minutes  # shorter is letting someone in
  CACHE_FOR = 10.minutes

  WINDOWS = { "month" => "This month", "all" => "All time" }.freeze

  # who: a User, or nil when they cannot be shown.
  Unlock = Struct.new(:who, :at, keyword_init: true)
  # hours, shifts (periods they unlocked and locked), opened, locked.
  Row = Struct.new(:user, :rank, :hours, :shifts, :opened, :locked, :days, keyword_init: true)

  def self.window(key)
    WINDOWS.key?(key) ? key : "month"
  end

  def initialize(now: Time.zone.now)
    @now = now
  end

  # Who unlocked the front door in its current unlocked stretch: the first
  # remote unlock since the board last reported it locked that the board
  # confirmed, the same rule the board uses. nil when the door is locked or
  # nobody unlocked it remotely. status is DoorLog.show_status.
  def front_unlocker(status)
    return nil unless status && status[:door_1_locked] == false

    since = @now - LONGEST_PERIOD
    last_locked = DoorLog.where(key: "door_1_locked", data: 1, created_at: since..@now).maximum(:created_at)
    row = remote_commands(FRONT_UNLOCK_KEYS).where(created_at: (last_locked || since)..@now)
      .where(<<~SQL.squish).order(:created_at, :id).first
        EXISTS (SELECT 1 FROM door_logs s WHERE s.key = 'door_1_locked' AND s.data = 0
          AND s.created_at >= door_logs.created_at AND s.created_at <= door_logs.created_at + #{seconds(CONFIRM_WITHIN)})
      SQL
    row && Unlock.new(who: visible_users([row.data])[row.data], at: row.created_at)
  end

  # opening_stats or day_stats, cached for ten minutes. Only plain numbers
  # are cached; people are looked up on every request.
  def cached_stats(board, window)
    month = @now.to_date.beginning_of_month.iso8601 if window == "month"
    Rails.cache.fetch(["door_activity", "v2", board, window, month], expires_in: CACHE_FOR) do
      case board
      when :opening then opening_stats(window)
      when :days then day_stats(window)
      else raise ArgumentError, "unknown board #{board.inspect}"
      end
    end
  end

  # Ranked Rows for the "kept the lab open" board. Pass stats (from
  # opening_stats, maybe cached) to skip the queries.
  def opened_the_lab(window, limit: 10, stats: nil)
    ranked(stats || opening_stats(window), limit) { |s| [s[:hours], s[:opened] + s[:locked]] }
  end

  # Ranked Rows of days each person was at the lab: a granted card swipe or a
  # remote unlock or open, once per day.
  def days_at_the_lab(window, limit: 10, stats: nil)
    ranked(stats || day_stats(window), limit) { |s| [s[:days]] }
  end

  # Plain numbers per user id, safe to cache: users are looked up fresh on
  # every request, so hiding a profile takes effect at once.
  def opening_stats(window)
    stats = Hash.new { |hash, id| hash[id] = { hours: 0.0, shifts: 0, opened: 0, locked: 0 } }
    periods(range(window)).each do |period|
      stats[period[:opener]][:opened] += 1
      closer = period[:closer]
      stats[closer][:locked] += 1 if closer && closer != AUTOMATIC_LOCK_ID
      next unless closer == period[:opener]
      stats[closer][:shifts] += 1
      stats[closer][:hours] += (period[:locked_at] - period[:unlocked_at]) / 3600.0
    end
    stats.transform_values { |s| s.merge(hours: s[:hours].round(1)) }
  end

  def day_stats(window)
    days = Hash.new { |hash, id| hash[id] = Set.new }
    card_days(range(window)).each { |id, day| days[id] << day }
    remote_days(range(window)).each { |id, day| days[id] << day }
    days.transform_values { |set| { days: set.size } }
  end

  private

  def range(window)
    window == "all" ? nil : (@now.beginning_of_month..@now)
  end

  def remote_commands(keys)
    DoorLog.where(key: keys).where.not(data: AUTOMATIC_LOCK_ID)
  end

  # One hash per opening of the lab, oldest first:
  #   opener, unlocked_at, closer (user id or nil), locked_at (or nil).
  # Built from every confirmed remote unlock; an unlock while the door is
  # already open belongs to the period already running.
  def periods(range)
    current_end = nil
    unlock_rows(range).filter_map do |opener, unlocked_at, confirmed_at, closed_at, closer, locked_at|
      next unless confirmed_at # the board never reported it unlocked
      next if current_end && unlocked_at < current_end

      current_end = closed_at || [unlocked_at + LONGEST_PERIOD, @now].min
      next if current_end - unlocked_at < SHORTEST_PERIOD
      { opener: opener, unlocked_at: unlocked_at, closer: closer, locked_at: locked_at }
    end
  end

  # Each remote front unlock with, from the board's reports: when it was
  # confirmed unlocked, when it was next reported locked, and the lock
  # command (who and when) just before that. All lookups are bounded by time
  # so they stay on the created_at index.
  def unlock_rows(range)
    unlocks = remote_commands(FRONT_UNLOCK_KEYS)
    unlocks = unlocks.where(created_at: range) if range
    conn = DoorLog.connection
    sql = <<~SQL
      SELECT u.data, u.created_at, c.at, cl.at, lk.data, lk.at
      FROM (#{unlocks.select(:id, :data, :created_at).to_sql}) u
      LEFT JOIN LATERAL (
        SELECT s.created_at AS at FROM door_logs s
        WHERE s.created_at >= u.created_at AND s.created_at <= u.created_at + #{seconds(CONFIRM_WITHIN)}
          AND s.key = 'door_1_locked' AND s.data = 0
        ORDER BY s.created_at LIMIT 1) c ON true
      LEFT JOIN LATERAL (
        SELECT s.created_at AS at FROM door_logs s
        WHERE s.created_at > c.at AND s.created_at <= u.created_at + #{seconds(LONGEST_PERIOD)}
          AND s.key = 'door_1_locked' AND s.data = 1
        ORDER BY s.created_at LIMIT 1) cl ON true
      LEFT JOIN LATERAL (
        SELECT l.data, l.created_at AS at FROM door_logs l
        WHERE l.created_at > u.created_at AND l.created_at >= cl.at - #{seconds(LOCK_BEFORE_CLOSE)} AND l.created_at <= cl.at
          AND l.key IN (#{FRONT_LOCK_KEYS.map { |key| conn.quote(key) }.join(", ")})
        ORDER BY l.created_at DESC LIMIT 1) lk ON true
      ORDER BY u.created_at, u.id
    SQL
    conn.select_rows(sql).map do |opener, *rest|
      times = [rest[0], rest[1], rest[2], rest[4]].map { |value| value && Time.find_zone("UTC").parse(value.to_s).in_time_zone }
      [opener.to_i, times[0], times[1], times[2], rest[3]&.to_i, times[3]]
    end
  end

  def seconds(duration)
    "interval '#{duration.to_i} seconds'"
  end

  def remote_days(range)
    scope = remote_commands(PRESENCE_KEYS)
    scope = scope.where(created_at: range) if range
    scope.distinct.pluck(:data, Arel.sql(lab_day_sql("created_at")))
  end

  # [user_id, day] for each card that swiped in on a day. Swipe times are
  # when the board's log was imported (every 6 minutes), close enough for days.
  def card_days(range)
    granted_swipes(range).filter_map { |high, low, day| (id = card_owners.call(high, low)) && [id, day] }
  end

  # Distinct [high half or nil, low half, lab day] for granted swipes. The
  # board logs g (high half) then G (low half) together; a g only pairs with
  # the G right after it, in the same import.
  def granted_swipes(range)
    pairs = DoorLog.where(key: %w[g G r R d D])
    pairs = pairs.where(created_at: (range.first - 1.minute)..range.last) if range
    pairs = pairs.select(<<~SQL.squish)
      key, data, created_at,
      LAG(key) OVER (ORDER BY id) AS prev_key, LAG(data) OVER (ORDER BY id) AS prev_data,
      LAG(created_at) OVER (ORDER BY id) AS prev_at
    SQL
    swipes = DoorLog.unscoped.from(pairs, :door_logs).where(key: "G")
    swipes = swipes.where(created_at: range) if range
    swipes.distinct.pluck(
      Arel.sql("CASE WHEN prev_key = 'g' AND prev_at >= created_at - interval '5 seconds' THEN prev_data END"),
      :data, Arel.sql(lab_day_sql("created_at"))
    )
  end

  # Finds the user id behind a swipe: by the full card number when both
  # halves arrived, else by the low half when only one card matches it.
  def card_owners
    @card_owners ||= begin
      cards = Card.where.not(user_id: nil).pluck(:card_number, :user_id)
      by_number = cards.to_h { |number, id| [number.to_s.downcase.sub(/\A0+/, ""), id] }
      by_low = cards.group_by { |number, _| number.to_s.to_i(16) % CARD_HALF }
                    .transform_values { |list| list.map(&:last).uniq }
                    .select { |_, ids| ids.one? }.transform_values(&:first)
      ->(high, low) { high ? by_number[(high.to_i * CARD_HALF + low.to_i).to_s(16)] : by_low[low.to_i] }
    end
  end

  # Members we may show: not hidden, and never the automatic lock.
  def visible_users(ids)
    ids = ids.compact.uniq - [AUTOMATIC_LOCK_ID]
    return {} if ids.empty?
    User.where(id: ids).where(hidden: [nil, false]).select(:id, :name, :email).index_by(&:id)
  end

  def lab_day_sql(column)
    zone = DoorLog.connection.quote(Time.zone.tzinfo.name)
    "DATE((#{column} AT TIME ZONE 'UTC') AT TIME ZONE #{zone})"
  end

  # Rows for the people we may show, best first, at most limit of them.
  # score gives the sort key (higher is better); equal scores share a rank
  # (1, 2, 2, 4) and names break ties in order.
  def ranked(stats, limit)
    users = visible_users(stats.keys)
    sorted = stats.select { |id, _| users[id] }
                  .map { |id, s| [users[id], s, yield(s)] }
                  .sort_by { |user, _, score| [score.map(&:-@), user.name.to_s.downcase] }
    previous = nil
    rank = 0
    sorted.first(limit).each_with_index.map do |(user, s, score), index|
      rank = index + 1 unless score == previous
      previous = score
      Row.new(user: user, rank: rank, **s.slice(:hours, :shifts, :opened, :locked, :days))
    end
  end
end
