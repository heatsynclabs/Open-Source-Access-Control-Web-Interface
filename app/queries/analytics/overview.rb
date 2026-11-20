module Analytics
  # One chart of the lab's main numbers together, to see how they move with
  # each other: card entries, members coming in, calendar events, class
  # sign-ups and new accounts. They are counted in very different amounts,
  # so each line is drawn against its own busiest bucket (= 100); the real
  # numbers are in the table under the chart.
  class Overview
    LINES = ["Card entries", "Members coming in", "Calendar events", "Class sign-ups", "New accounts"].freeze

    # Each argument is a { bucket date => count } series, or nil when that
    # source is missing (the calendar can be down; classes before the table
    # exists).
    def initialize(entries:, cards:, events:, signups:, accounts:)
      @series = LINES.zip([entries, cards, events, signups, accounts]).to_h.compact
    end

    def buckets
      @series.values.flat_map(&:keys).uniq.sort
    end

    # Chartkick series, each scaled to its own peak.
    def indexed
      @series.map do |name, data|
        peak = data.values.max.to_f
        { name: name, data: buckets.to_h { |bucket| [bucket, peak.zero? ? 0 : (100 * data.fetch(bucket, 0) / peak).round] } }
      end
    end

    # { bucket => [count per line] }, for the table.
    def actual
      buckets.to_h { |bucket| [bucket, @series.values.map { |data| data.fetch(bucket, 0) }] }
    end

    def names
      @series.keys
    end
  end
end
