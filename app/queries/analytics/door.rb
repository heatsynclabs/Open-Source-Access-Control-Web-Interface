module Analytics
  # Door use from the board's log. Card events store a card code in data,
  # so distinct codes count distinct cards without naming anyone. Counts the
  # live log and the old years in DoorLogArchive together, so every period
  # reaches back to 2012.
  class Door
    GRANTED = "G"

    def initialize(period)
      @period = period
    end

    def entries_total
      granted.count
    end

    def entries_by_period
      by_period(granted)
    end

    def distinct_cards_by_period
      granted.group_by_period(@period.unit, :created_at, range: @period.range).distinct.count(:data)
    end

    # Days with entries only: the lost months and the days before the log
    # began are not quiet days.
    def entries_by_day
      granted.group_by_day(:created_at, range: @period.range, series: false).count
    end

    # { [weekday 0 = Sunday, hour] => entries }
    def weekday_hour_grid
      granted.group_by_day_of_week(:created_at).group_by_hour_of_day(:created_at).count
    end

    # Door commands sent from the members site and from the phone app.
    def remote_by_source
      remote = log.where(created_at: @period.range)
      [
        { name: "Phone app", data: by_period(remote.where("key LIKE ?", "api_rem_%")) },
        { name: "Website", data: by_period(remote.where("key LIKE ?", "rem_%")) },
      ]
    end

    private

    def granted
      log.where(key: GRANTED, created_at: @period.range)
    end

    # door_logs, plus door_log_archives once that table exists.
    def log
      return DoorLog.all unless DoorLogArchive.available?
      DoorLog.unscoped.from(<<~SQL.squish)
        (SELECT key, data, created_at FROM door_logs
         UNION ALL SELECT key, data, created_at FROM door_log_archives) AS door_logs
      SQL
    end

    def by_period(scope)
      scope.group_by_period(@period.unit, :created_at, range: @period.range).count
    end
  end
end
