module Analytics
  # Door use from the board's log. Card events store a card code in data,
  # so distinct codes count distinct cards without naming anyone.
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

    def entries_by_day
      granted.group_by_day(:created_at, range: @period.range).count
    end

    # { [weekday 0 = Sunday, hour] => entries }
    def weekday_hour_grid
      granted.group_by_day_of_week(:created_at).group_by_hour_of_day(:created_at).count
    end

    # Door commands sent from the members site and from the phone app.
    def remote_by_source
      remote = DoorLog.where(created_at: @period.range)
      [
        { name: "Phone app", data: by_period(remote.where("key LIKE ?", "api_rem_%")) },
        { name: "Website", data: by_period(remote.where("key LIKE ?", "rem_%")) },
      ]
    end

    private

    def granted
      DoorLog.where(key: GRANTED, created_at: @period.range)
    end

    def by_period(scope)
      scope.group_by_period(@period.unit, :created_at, range: @period.range).count
    end
  end
end
