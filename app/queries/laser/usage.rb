module Laser
  # How much the lab's laser cutters are used, for analytics (Over the years:
  # the laser card and deep dive), from every log of both machines. A machine's
  # months count only inside a stretch of logging (jobs less than GAP days
  # apart); between stretches they are nil, not 0. The first month of each
  # stretch, the last month of a stretch that ended, and the month we are in
  # are left out, being only partly covered. Results come from the current
  # forms only: the large laser's old form never asked.
  class Usage
    GAP = 180

    # jobs: { machine => [Laser::Log::Job] } (both forms)
    def initialize(jobs)
      cutoff = Date.current.beginning_of_month
      @full = jobs
      @machines = jobs.transform_values { |js| js.select { |j| j.date < cutoff }.sort_by(&:date) }
      @covered = @machines.transform_values { |js| covered_months(js) }
      @all = @machines.values.flatten
      @any_covered = @covered.values.reduce(Set.new, :|)
    end

    def any? = @all.any?

    # [{ name: "Large 80W", data: { Date => n or nil } }, ...]
    def jobs_by_machine = per_machine { |js| js.size }
    def hours_by_machine = per_machine { |js| hours(js) }

    # { Date => value or nil }, both machines together.
    def jobs_by_month = series(@all, @any_covered) { |js| js.size }
    def people_by_month = series(@all, @any_covered) { |js| people(js).uniq.size }
    # Of the jobs that answered (the mini's old form added the question in 2011).
    def found_clean_by_month
      series(@all, @any_covered) do |js|
        answered = js.reject { |j| j.clean_start.blank? }
        Stats.percent(answered.count { |j| j.clean_start.start_with?("Yes") }, answered.size) if answered.any?
      end
    end

    # { "Success" => { "2023" => n } }: both machines' current forms.
    def results_by_year
      form = @all.select { |j| j.source == LaserJob::FORM }
      { "Success" => "success", "Partly worked" => "conditional", "Failed" => "fail" }.to_h do |label, result|
        [label, by_year(form) { |js| js.count { |j| j.result == result } }]
      end
    end

    # { family => { "2014" => n } }: every log.
    def families_by_year
      LaserLog::Cleaner::FAMILY.values.uniq.to_h { |family| [family, by_year(@all) { |js| js.count { |j| j.family == family } }] }
        .reject { |_family, years| years.values.sum.zero? }
    end

    # Every logged job, whole months or not.
    def totals
      every = @full.values.flatten
      { jobs: every.size, people: people(every).uniq.size, hours: hours(every).round,
        first: every.map(&:date).min, one_job: people(every).tally.count { |_p, n| n == 1 },
        busiest_tenth: busiest_tenth(every),
        machines: @full.to_h { |machine, js| [machine, { jobs: js.size, first: js.map(&:date).min }] } }
    end

    private

    def per_machine(&block)
      LaserJob::MACHINES.map do |machine, label|
        { name: label, data: series(@machines.fetch(machine, []), @covered.fetch(machine, Set.new), &block) }
      end
    end

    def hours(jobs) = (jobs.sum { |j| j.minutes || 0 } / 60.0).round(1)

    # Person keys, without jobs logged with no name.
    def people(jobs) = jobs.map(&:person).reject(&:blank?)

    # The months inside stretches of logging, without the partial ones.
    def covered_months(jobs)
      return Set.new if jobs.empty?
      stretches = jobs.slice_when { |a, b| (b.date - a.date) > GAP }.to_a
      stretches.each_with_index.each_with_object(Set.new) do |(stretch, i), months|
        month, last = stretch.first.date.beginning_of_month.next_month, stretch.last.date.beginning_of_month
        last = last.prev_month if i < stretches.size - 1
        while month <= last
          months << month
          month = month.next_month
        end
      end
    end

    # Every month from the first covered by any machine to the last.
    def series(jobs, covered)
      return {} if @any_covered.empty?
      groups = jobs.group_by { |j| j.date.beginning_of_month }
      month, last, out = @any_covered.min, @any_covered.max, {}
      while month <= last
        out[month] = covered.include?(month) ? yield(groups.fetch(month, [])) : nil
        month = month.next_month
      end
      out
    end

    def by_year(jobs)
      jobs.group_by { |j| j.date.year.to_s }.sort.to_h.transform_values { |js| yield js }
    end

    # Share of jobs logged by the busiest tenth of the people.
    def busiest_tenth(jobs)
      counts = people(jobs).tally.values.sort.reverse
      return 0 if counts.empty?
      Stats.percent(counts.first([counts.size / 10, 1].max).sum, counts.sum)
    end
  end
end
