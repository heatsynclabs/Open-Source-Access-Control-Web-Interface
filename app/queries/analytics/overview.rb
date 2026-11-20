module Analytics
  # One chart of the lab's main numbers together, to see how they move with
  # each other: card entries, members coming in, calendar events, class
  # sign-ups and new accounts. They are counted in very different amounts,
  # so each line is drawn against its own busy level: 100 is its 90th
  # percentile bucket, so one freak month (the 2012 account import) does not
  # flatten the rest; the chart stops at CEILING. A line starts at its first
  # bucket with data, so years before a source existed are blank, not zero.
  # The real numbers are in the table under the chart.
  class Overview
    LINES = ["Card entries", "Members coming in", "Calendar events", "Class sign-ups", "New accounts"].freeze
    CEILING = 200

    # Each argument is a { bucket date => count } series, or nil when that
    # source is missing (the calendar can be down; classes before the table
    # exists).
    def initialize(entries:, cards:, events:, signups:, accounts:)
      @series = LINES.zip([entries, cards, events, signups, accounts]).to_h.compact
    end

    def buckets
      @series.values.flat_map(&:keys).uniq.sort
    end

    # Chartkick series, each scaled to its own busy level.
    def indexed
      @series.map { |name, data| { name: name, data: scaled(data) } }
    end

    # { bucket => [count per line] }, for the table.
    def actual
      buckets.to_h { |bucket| [bucket, @series.values.map { |data| data.fetch(bucket, 0) }] }
    end

    def names
      @series.keys
    end
  
    private

    # nil before the line's first bucket with data; otherwise 100 times the
    # count over the line's 90th percentile bucket, at most CEILING.
    def scaled(data)
      counted = data.values.select(&:positive?).sort
      return buckets.to_h { |bucket| [bucket, nil] } if counted.empty?
      level = counted[(0.9 * (counted.size - 1)).round].to_f
      first = data.select { |_bucket, count| count.positive? }.keys.min
      buckets.to_h do |bucket|
        [bucket, bucket < first ? nil : [(100 * data.fetch(bucket, 0) / level).round, CEILING].min]
      end
    end
  end
end
