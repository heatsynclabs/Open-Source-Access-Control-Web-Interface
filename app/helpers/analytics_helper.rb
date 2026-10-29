module AnalyticsHelper
  # Calendar categories keep one colour on every chart: the palette slot in
  # app/javascript/charts.js for each category, matching the site's
  # category colours (workshop amber, HYH rust, group violet, recurring
  # green, one-off blue).
  CATEGORY_PALETTE_SLOTS = { "class" => 0, "hack" => 4, "group" => 3, "recurring" => 2, "default" => 1 }.freeze

  # A { date => value } series with its dates written the way the period's
  # axis reads them ("Mar 2026", or "Mar 4" for weeks).
  def by_bucket(series, period)
    series.transform_keys { |date| period.bucket_label(date.to_date) }
  end

  # The same for a list of Chartkick series ({ name:, data: }).
  def by_bucket_series(series_list, period)
    series_list.map { |series| series.merge(data: by_bucket(series[:data], period)) }
  end

  # "12am", "3pm": an hour of the day on the door heatmap.
  def hour_label(hour)
    Time.zone.local(2000, 1, 1, hour).strftime("%-l%P")
  end

  def calendar_palette_order(series)
    series.map { |line| CATEGORY_PALETTE_SLOTS.fetch(LabCalendar::Category.all.find { |c| c.label == line[:name] }&.key, 1) }
  end

  def percent(value)
    value.nil? ? "not yet" : "#{value.round}%"
  end

  def share(value, max)
    max.to_f.zero? ? 0 : (value.to_f / max).round(3)
  end
end
