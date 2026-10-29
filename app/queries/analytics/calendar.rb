module Analytics
  # What the lab put on its calendar, from LabCalendar. Open hours are left
  # out of the counts: they are the lab being open, not events.
  class Calendar
    def initialize(period)
      @period = period
    end

    def events
      @events ||= LabCalendar.between(@period.range).reject { |event| event.open_hours? }
    end

    def total
      events.size
    end

    def hack_your_hackerspace_count
      events.count { |event| event.category.key == "hack" }
    end

    def classes_count
      events.count { |event| event.category.key == "class" }
    end

    # Chartkick series, one per category, counting events per bucket.
    def by_category_series
      buckets = bucket_dates
      LabCalendar::Category.all.reject { |category| category.key == "open" }.map do |category|
        counts = events.select { |event| event.category == category }.group_by { |event| bucket_of(event.day) }
        { name: category.label, data: buckets.to_h { |bucket| [bucket, counts.fetch(bucket, []).size] } }
      end
    end

    def by_weekday
      counts = events.group_by { |event| event.day.wday }
      Date::ABBR_DAYNAMES.each_with_index.to_h { |name, wday| [name, counts.fetch(wday, []).size] }
    end

    # The events that happened most often in the period.
    def top_series(limit = 10)
      events.group_by(&:display_title).map { |title, list| [title, list.size, list.first.category] }
        .sort_by { |_title, count, _category| -count }.first(limit)
    end

    # Average card entries on days with something on the calendar against
    # days with nothing, over the days that have passed.
    def door_entries_on_event_days(entries_by_day)
      event_days = events.map(&:day).to_set
      past = entries_by_day.select { |day, _count| day < Date.current }
      with, without = past.partition { |day, _count| event_days.include?(day) }
      { "Days with an event" => average(with), "Days with nothing on" => average(without) }
    end

    private

    def average(day_counts)
      return 0 if day_counts.empty?
      (day_counts.sum { |_day, count| count }.to_f / day_counts.size).round(1)
    end

    def bucket_of(date)
      @period.unit == :week ? date.beginning_of_week : date.beginning_of_month
    end

    def bucket_dates
      @period.dates.map { |date| bucket_of(date) }.uniq
    end
  end
end
