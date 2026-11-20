module Analytics
  # One chart of the lab's main numbers together, to see how they rise and
  # fall with each other. They are counted in very different amounts (card
  # entries in hundreds, class sign-ups in tens, dues in dollars), so each
  # line is drawn against its own busy level: 100 is its 90th percentile
  # bucket, so one freak month does not flatten the rest, and the chart stops
  # at CEILING. A line starts at its first bucket with data, so years before
  # a source existed are blank, not zero. The real numbers go along with each
  # line for the tooltip, and into the table under the chart.
  #
  # All time is grouped by quarter, each the average month in it, so the
  # chart is not 170 jagged points.
  class Overview
    CEILING = 200

    # lines: [[name, { bucket date => count } or nil, shown at first?, prefix]].
    # A nil series (the calendar is down, classes not loaded) is left out.
    def initialize(period, lines)
      @period = period
      @lines = lines.reject { |line| line[1].nil? }.map do |name, data, shown, prefix = nil|
        { name: name, values: regroup(data), shown: shown, prefix: prefix }
      end
    end

    def quarterly?
      @period.key == "all"
    end

    def bucket_name
      quarterly? ? "quarter" : @period.unit.to_s
    end

    def names
      @lines.map { |line| line[:name] }
    end

    # Chartkick series: the scaled line, plus (for charts.js) the real value
    # by label for the tooltip, and whether it starts hidden.
    def chart_series
      @lines.map do |line|
        scaled = scale(line[:values])
        { name: line[:name], data: scaled.transform_keys { |bucket| label(bucket) },
          dataset: { hidden: !line[:shown], valuePrefix: line[:prefix],
                     actualByLabel: line[:values].to_h { |bucket, value| [label(bucket), value.round(1)] } } }
      end
    end

    # { label => [real value per line] }, for the table.
    def table
      buckets.to_h do |bucket|
        [label(bucket), @lines.map { |line| format_value(line[:values][bucket], line[:prefix]) }]
      end
    end

    def label(bucket)
      return @period.bucket_label(bucket) unless quarterly?
      text = "Q#{(bucket.month - 1) / 3 + 1} #{bucket.year}"
      bucket == Date.current.beginning_of_quarter ? text + Period::SO_FAR : text
    end

    private

    def buckets
      @lines.flat_map { |line| line[:values].keys }.uniq.sort
    end

    # { bucket => value }: by the period's own buckets, or by quarter (the
    # average of its months) for all time.
    def regroup(data)
      values = data.transform_keys(&:to_date).transform_values(&:to_f)
      return values unless quarterly?
      values.group_by { |month, _value| month.beginning_of_quarter }
        .transform_values { |pairs| pairs.sum { |_month, value| value } / pairs.size }
    end

    # nil before the line's first bucket with data; otherwise 100 times the
    # value over the line's 90th percentile bucket, at most CEILING.
    def scale(values)
      counted = values.values.select(&:positive?).sort
      return values.transform_values { nil } if counted.empty?
      level = counted[(0.9 * (counted.size - 1)).round]
      first = values.select { |_bucket, value| value.positive? }.keys.min
      values.to_h { |bucket, value| [bucket, bucket < first ? nil : [(100 * value / level).round, CEILING].min] }
    end

    def format_value(value, prefix)
      return "" if value.nil?
      rounded = value.round(value < 10 && quarterly? ? 1 : 0)
      rounded = rounded.to_i if rounded == rounded.to_i
      "#{prefix}#{ActiveSupport::NumberHelper.number_to_delimited(rounded)}"
    end
  end
end
