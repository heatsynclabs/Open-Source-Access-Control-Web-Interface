module Laser
  # How much the large laser is used, for analytics (Over the years: the
  # laser card and deep dive). Months run from the first full month of the log
  # to the last full month; the month we are in is left out until it is over.
  class Usage
    def initialize(jobs)
      @jobs = jobs.select { |j| j.date < Date.current.beginning_of_month }
      @jobs = @jobs.reject { |j| j.date.beginning_of_month == @jobs.first.date.beginning_of_month } if @jobs.any? && @jobs.first.date.day > 1
    end

    def any? = @jobs.any?

    # { Date (first of month) => value }
    def jobs_by_month = by_month { |js| js.size }
    def people_by_month = by_month { |js| js.map(&:person).uniq.size }
    def hours_by_month = by_month { |js| (js.sum { |j| j.minutes || 0 } / 60.0).round(1) }
    def found_clean_by_month = by_month { |js| Stats.percent(js.count { |j| j.clean_start == "Yes" }, js.size) }

    # { "Success" => { "2023" => n } } and { family => { "2023" => n } }
    def results_by_year
      { "Success" => "success", "Partly worked" => "conditional", "Failed" => "fail" }.to_h do |label, result|
        [label, by_year { |js| js.count { |j| j.result == result } }]
      end
    end

    def families_by_year
      LaserLog::Cleaner::FAMILY.values.uniq.to_h { |family| [family, by_year { |js| js.count { |j| j.family == family } }] }
        .reject { |_family, years| years.values.sum.zero? }
    end

    def totals
      { jobs: @jobs.size, people: @jobs.map(&:person).uniq.size, hours: (@jobs.sum { |j| j.minutes || 0 } / 60.0).round,
        first: @jobs.first&.date, last: @jobs.last&.date,
        one_job: @jobs.map(&:person).tally.count { |_p, n| n == 1 },
        busiest_tenth: busiest_tenth }
    end

    private

    def by_month
      return {} if @jobs.empty?
      groups = @jobs.group_by { |j| j.date.beginning_of_month }
      first, last = groups.keys.min, groups.keys.max
      months = []
      (months << first; first = first.next_month) while first <= last
      months.to_h { |m| [m, yield(groups.fetch(m, []))] }
    end

    def by_year
      @jobs.group_by { |j| j.date.year.to_s }.sort.to_h.transform_values { |js| yield js }
    end

    # Share of jobs logged by the busiest tenth of the people.
    def busiest_tenth
      counts = @jobs.map(&:person).tally.values.sort.reverse
      return 0 if counts.empty?
      Stats.percent(counts.first([counts.size / 10, 1].max).sum, @jobs.size)
    end
  end
end
