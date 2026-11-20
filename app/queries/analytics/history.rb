module Analytics
  # The "Over the years" tab: long series from LabMetric, each over every
  # year its records reach, whatever period the page is set to. Months and
  # years come back as axis labels ("Apr 2013", "2013"). A month or year with
  # no figure is nil, so a line breaks there instead of dropping to zero; a
  # nil from the table itself means fewer than 5 (FEWER_THAN_FIVE in tables).
  class History
    FEWER_THAN_FIVE = "fewer than 5"

    # The deep dives, one per subject on the tab (?section=history&topic=).
    # Money ones show only to those who can see dues.
    TOPICS = {
      "members" => { title: "Paying members" },
      "wifi" => { title: "Devices on the lab Wi-Fi" },
      "power" => { title: "Electricity" },
      "talk" => { title: "The mailing list and Slack" },
      "wiki" => { title: "The wiki" },
      "calendar" => { title: "The calendar" },
      "laser" => { title: "The laser cutter" },
      "joining" => { title: "How people find the lab" },
      "money" => { title: "Money", money: true },
    }.freeze

    def initialize
      @rows = LabMetric.order(:starts_on, :id).to_a.group_by(&:key)
    end

    def loaded?
      @rows.any?
    end

    # Chartkick series on one shared run of months: lines are [name, key],
    # [name, key, label], or [name, { date => value }] for a live series
    # (clipped to the months the stored lines cover, or those of within:).
    def monthly(*lines, within: nil)
      shared(lines, "%b %Y", within) { |from, to| months(from, to) }
    end

    def yearly(*lines)
      shared(lines, "%Y", nil) { |from, to| (from.year..to.year).map { |year| Date.new(year) } }
    end

    # [[label, value]]: a breakdown read at one date, in the order it was
    # loaded, or largest first with "Other" kept last.
    def totals(key, largest_first: false)
      found = rows(key).map { |row| [row.label, number(row.value)] }
      return found unless largest_first
      found.sort_by { |label, value| [label == "Other" ? 1 : 0, -(value || 0)] }
    end

    # { "2013" => total }: a monthly series added up by year (every label
    # together, or one).
    def sum_by_year(key, label = nil)
      rows(key, label).group_by { |row| row.starts_on.year.to_s }.transform_values { |year| year.sum { |row| row.value.to_f }.round }
    end

    # { "2013" => average } of a monthly series, over the months on record.
    def average_by_year(key, label = "")
      rows(key, label).reject { |row| row.value.nil? }.group_by { |row| row.starts_on.year.to_s }
        .transform_values { |year| (year.sum { |row| row.value.to_f } / year.size).round(1) }
    end

    # { "Jan" => average } of a monthly series over every year: its seasons.
    def average_by_calendar_month(key, label = "")
      by_month = rows(key, label).reject { |row| row.value.nil? }.group_by { |row| row.starts_on.month }
      (1..12).to_h { |m| [Date::ABBR_MONTHNAMES[m], by_month[m] && (by_month[m].sum { |row| row.value.to_f } / by_month[m].size).round(1)] }
    end

    # { "2013" => a / b }, the yearly totals of two monthly series divided
    # (for example dues dollars per paying member a month).
    def ratio_by_year(numerator, denominator)
      below = sum_by_year(denominator)
      sum_by_year(numerator).filter_map { |year, total| [year, (total.to_f / below[year]).round(2)] if below[year].to_f.positive? }.to_h
    end

    # One Chartkick series per year, with the labels along the axis (for
    # example the weekdays of each year).
    def by_year_series(key)
      rows(key).group_by { |row| row.starts_on.year.to_s }.map do |year, year_rows|
        { name: year, data: year_rows.to_h { |row| [row.label, number(row.value)] } }
      end
    end

    # Years in which the series has fewer than twelve months.
    def short_years(key)
      rows(key).group_by { |row| row.starts_on.year }.select { |_year, year| year.map(&:starts_on).uniq.size < 12 }.keys
    end

    # Table rows [[year, [value, ...]]] for yearly counts, one column per key.
    def table(*keys)
      years = keys.flat_map { |key| rows(key).map { |row| row.starts_on.year } }.uniq.sort
      years.map { |year| [year.to_s, keys.map { |key| cell(rows(key).find { |row| row.starts_on.year == year }) }] }
    end

    # Table rows [[year, [value, ...]]] for a yearly breakdown, one column per label.
    def breakdown_table(key)
      rows(key).group_by { |row| row.starts_on.year.to_s }.map do |year, year_rows|
        [year, labels(key).map { |label| cell(year_rows.find { |row| row.label == label }) }]
      end
    end

    # [year, value] of the year with the largest count, or nil.
    def highest(key)
      row = rows(key).reject { |found| found.value.nil? }.max_by(&:value)
      row && [row.starts_on.year, number(row.value)]
    end

    def labels(key)
      rows(key).map(&:label).uniq
    end

    private

    def rows(key, label = nil)
      found = @rows.fetch(key, [])
      label ? found.select { |row| row.label == label } : found
    end

    def shared(lines, format, within)
      stored, live = lines.partition { |_name, key| key.is_a?(String) }
      found = stored.to_h { |name, key, label = ""| [name, rows(key, label).to_h { |row| [row.starts_on, number(row.value)] }] }
      dates = within ? rows(within).map(&:starts_on) : found.values.flat_map(&:keys)
      live.each { |name, series| found[name] = series.transform_keys(&:to_date) }
      return [] if dates.empty?
      periods = yield(dates.min, dates.max)
      found.map do |name, data|
        { name: name, data: periods.to_h { |date| [date.strftime(format), data[date]] } }
      end
    end

    def months(from, to)
      (0..((to.year - from.year) * 12 + to.month - from.month)).map { |i| from.beginning_of_month >> i }
    end

    # A table cell: blank with no record, "fewer than 5" where the
    # small-cell rule hid the number.
    def cell(row)
      row && (number(row.value) || FEWER_THAN_FIVE)
    end

    def number(value)
      return nil if value.nil?
      value % 1 == 0 ? value.to_i : value.to_f
    end
  end
end
