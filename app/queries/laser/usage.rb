module Laser
  # How much the large laser is used, for analytics (Over the years: the
  # laser card and deep dive). Jobs reach back through the earlier log
  # (2013-10 to 2020-06); people, hours, results and cleanliness are only on
  # the current form (from 2022-04). Months between the logs are nil, not 0:
  # nothing was logged. Each log's first and last month, and the month we
  # are in, are left out when they are only partly covered.
  class Usage
    def initialize(jobs, earlier = [])
      @logs = [whole_months(earlier, ended: true), whole_months(jobs.select { |j| j.date < Date.current.beginning_of_month })]
      @jobs = @logs.last
      @all = @logs.flatten
      @full = [earlier, jobs] # every job, for the totals
    end

    def any? = @all.any?

    # { Date (first of month) => value }; nil for months no log covers.
    def jobs_by_month = by_month(@logs) { |js| js.size }
    def people_by_month = by_month([@jobs]) { |js| js.map(&:person).uniq.size }
    def hours_by_month = by_month([@jobs]) { |js| (js.sum { |j| j.minutes || 0 } / 60.0).round(1) }
    def found_clean_by_month = by_month([@jobs]) { |js| Stats.percent(js.count { |j| j.clean_start == "Yes" }, js.size) }

    # { "Success" => { "2023" => n } }: current form only.
    def results_by_year
      { "Success" => "success", "Partly worked" => "conditional", "Failed" => "fail" }.to_h do |label, result|
        [label, by_year(@jobs) { |js| js.count { |j| j.result == result } }]
      end
    end

    # { family => { "2014" => n } }: both logs.
    def families_by_year
      LaserLog::Cleaner::FAMILY.values.uniq.to_h { |family| [family, by_year(@all) { |js| js.count { |j| j.family == family } }] }
        .reject { |_family, years| years.values.sum.zero? }
    end

    # Every logged job, whole months or not.
    def totals
      earlier, form = @full
      { jobs: form.size, people: form.map(&:person).uniq.size, hours: (form.sum { |j| j.minutes || 0 } / 60.0).round,
        first: form.first&.date, last: form.last&.date,
        one_job: form.map(&:person).tally.count { |_p, n| n == 1 }, busiest_tenth: busiest_tenth(form),
        earlier: earlier.size, earlier_first: earlier.first&.date, earlier_last: earlier.last&.date }
    end

    private

    # A log's jobs without its partly covered months: the first month when the
    # log starts after the 1st, and, for a log that has ended, its last month.
    def whole_months(jobs, ended: false)
      return [] if jobs.empty?
      drop = []
      drop << jobs.first.date.beginning_of_month if jobs.first.date.day > 1
      drop << jobs.last.date.beginning_of_month if ended
      jobs.reject { |j| drop.include?(j.date.beginning_of_month) }
    end

    def by_month(logs)
      logs = logs.reject(&:empty?)
      return {} if logs.empty?
      covered = logs.map { |js| js.first.date.beginning_of_month..js.last.date.beginning_of_month }
      groups = logs.flatten.group_by { |j| j.date.beginning_of_month }
      month, last, out = covered.first.begin, covered.last.end, {}
      while month <= last
        out[month] = covered.any? { |range| range.cover?(month) } ? yield(groups.fetch(month, [])) : nil
        month = month.next_month
      end
      out
    end

    def by_year(jobs)
      jobs.group_by { |j| j.date.year.to_s }.sort.to_h.transform_values { |js| yield js }
    end

    # Share of jobs logged by the busiest tenth of the people.
    def busiest_tenth(jobs)
      counts = jobs.map(&:person).tally.values.sort.reverse
      return 0 if counts.empty?
      Stats.percent(counts.first([counts.size / 10, 1].max).sum, jobs.size)
    end
  end
end
