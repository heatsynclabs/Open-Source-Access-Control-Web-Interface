module Analytics
  # The span of time an analytics page covers, and the bucket size its
  # charts group by: weeks for short spans, months otherwise.
  class Period
    CHOICES = {
      "90d" => { label: "90 days", length: 90.days, unit: :week },
      "12m" => { label: "12 months", length: 12.months, unit: :month },
      "3y" => { label: "3 years", length: 3.years, unit: :month },
      "all" => { label: "All time", length: nil, unit: :month },
    }.freeze
    DEFAULT = "12m"
    # The members database begins in 2012; the calendar feed in 2010.
    EARLIEST = Time.zone.local(2010, 1, 1)

    attr_reader :key

    def initialize(key)
      @key = CHOICES.key?(key) ? key : DEFAULT
    end

    def label
      CHOICES[@key][:label]
    end

    def unit
      CHOICES[@key][:unit]
    end

    def starts_at
      length = CHOICES[@key][:length]
      length ? (Time.zone.now - length).beginning_of_day : EARLIEST
    end

    def ends_at
      Time.zone.now
    end

    def range
      starts_at..ends_at
    end

    def dates
      starts_at.to_date..ends_at.to_date
    end

    # How a bucket's date reads on an axis or in a table.
    def bucket_label(date)
      unit == :week ? date.strftime("%b %-d") : date.strftime("%b %Y")
    end
  end
end
