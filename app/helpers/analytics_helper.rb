module AnalyticsHelper
  # Calendar categories keep one colour on every chart: the palette slot in
  # app/javascript/charts.js for each category, matching the site's
  # category colours (workshop amber, HYH rust, group violet, recurring
  # green, one-off blue).
  CATEGORY_PALETTE_SLOTS = { "class" => 0, "hack" => 4, "group" => 3, "recurring" => 2, "default" => 1 }.freeze

  # A { date => value } series with its dates written the way the period's
  # axis reads them ("Mar 2026", or "Mar 4" for weeks). Charts drawn from
  # these pass discrete: true, or Chartkick reads the labels as dates again
  # and drops the "(so far)" mark charts.js looks for.
  def by_bucket(series, period)
    series.transform_keys { |date| period.bucket_label(date.to_date) }
  end

  # "Nov 2026", or "Nov 2026 (so far)" for the month we are in (see
  # Analytics::Period::SO_FAR).
  def month_label(month, format = "%b %Y")
    label = month.strftime(format)
    month == Date.current.beginning_of_month ? label + Analytics::Period::SO_FAR : label
  end

  # The same for a list of Chartkick series ({ name:, data: }).
  def by_bucket_series(series_list, period)
    series_list.map { |series| series.merge(data: by_bucket(series[:data], period)) }
  end

  # Table rows [[label, [value, ...]]] for Chartkick series that share their
  # labels (one column per series), for a chart card's numbers.
  def series_rows(series)
    return [] if series.empty?
    series.first[:data].keys.map { |label| [label, series.map { |line| line[:data][label] }] }
  end

  # "12am", "3pm": an hour of the day on the door heatmap.
  def hour_label(hour)
    Time.zone.local(2000, 1, 1, hour).strftime("%-l%P")
  end

  def calendar_palette_order(series)
    series.map { |line| CATEGORY_PALETTE_SLOTS.fetch(LabCalendar::Category.all.find { |c| c.label == line[:name] }&.key, 1) }
  end

  TICKETED_STATUS_TONES = { "held" => :ok, "cancelled" => :err, "upcoming" => :info }.freeze

  def ticketed_status_chip(status)
    render ChipComponent.new(status, tone: TICKETED_STATUS_TONES[status])
  end

  # What the class sign-up numbers cover and leave out.
  def classes_note(classes)
    left_out = classes[:left_out].map { |status, count| "#{count} #{status == "cancelled" ? "cancelled" : "with no sign-ups"}" }
    note = "From guestlist.co, the lab's ticketing site. Each ticket is one person; donation tickets are not counted. "
    note += "Not counted: #{left_out.to_sentence} in this period. " if left_out.any?
    note + "Classes paid for some other way are missing."
  end

  # When the class numbers were read from guestlist, so nobody takes them
  # for live figures.
  def classes_collection_note(collected)
    export, nightly = collected["organizer export"], collected["public pages"]
    parts = []
    parts << "The full history was last exported from the organizer account on #{export.to_date.to_fs(:long)}." if export
    parts << if nightly
               "Since then, new and recent events are read from guestlist's public pages each night (last read #{l(nightly, format: :short)}); " \
                 "their money is ticket price times tickets."
             else
               "Newer events are added by the nightly check of guestlist's public pages once it has run."
             end
    "Not live: these numbers are copied from guestlist. #{parts.join(" ")}"
  end

  def share(value, max)
    max.to_f.zero? ? 0 : (value.to_f / max).round(3)
  end
end
