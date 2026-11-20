module Analytics
  # The "Over the years" tab: long series from LabMetric, each over every
  # year its records reach, whatever period the page is set to. Months and
  # years come back as axis labels ("Apr 2013", "2013"). A month or year with
  # no figure is nil, so a line breaks there instead of dropping to zero; a
  # nil from the table itself means fewer than 5 (FEWER_THAN_FIVE in tables).
  class History
    FEWER_THAN_FIVE = "fewer than 5"

    def initialize
      @rows = LabMetric.order(:starts_on, :id).to_a.group_by(&:key)
    end

    def loaded?
      @rows.any?
    end

    # Chartkick series on one shared run of months: lines are [name, key]
    # or [name, key, label].
    def monthly(*lines)
      shared(lines, "%b %Y") { |from, to| months(from, to) }
    end

    def yearly(*lines)
      shared(lines, "%Y") { |from, to| (from.year..to.year).map { |year| Date.new(year) } }
    end

    # [[label, value]]: a breakdown read at one date, in the order it was
    # loaded, or largest first with "Other" kept last.
    def totals(key, largest_first: false)
      found = rows(key).map { |row| [row.label, number(row.value)] }
      return found unless largest_first
      found.sort_by { |label, value| [label == "Other" ? 1 : 0, -(value || 0)] }
    end

    # { "2013" => total }: a monthly money series added up by year, every
    # label together.
    def sum_by_year(key)
      rows(key).group_by { |row| row.starts_on.year.to_s }.transform_values { |year| year.sum { |row| row.value.to_f }.round }
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

    def labels(key)
      rows(key).map(&:label).uniq
    end

    private

    def rows(key, label = nil)
      found = @rows.fetch(key, [])
      label ? found.select { |row| row.label == label } : found
    end

    def shared(lines, format)
      found = lines.to_h { |name, key, label = ""| [name, rows(key, label).to_h { |row| [row.starts_on, number(row.value)] }] }
      dates = found.values.flat_map(&:keys)
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
