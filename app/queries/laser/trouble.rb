module Laser
  # "What goes wrong": trouble rates across the log and the drift of the 3 mm
  # plywood setting, as in the laser explorer. Trouble needs results, so only
  # the current form counts; the drift reaches back through the earlier log.
  class Trouble
    def initialize(jobs, earlier: [])
      @jobs = jobs
      @earlier = earlier
      @cuts = jobs.select { |j| j.cut_op == "cut" }
    end

    def with_settings
      @with_settings ||= @jobs.select(&:settings?)
    end

    def clean_share
      Stats.percent(with_settings.count(&:success?), with_settings.size)
    end

    # How many jobs' notes mention each kind of trouble (keywords; approximate).
    def issues
      @issues ||= @jobs.flat_map(&:issues).tally
    end

    # [percent with trouble, jobs] for the cuts that match.
    def rate(&filter)
      rows = @cuts.select(&filter)
      [Stats.percent(rows.count { |j| !j.success? }, rows.size), rows.size]
    end

    def by_material
      { mdf: rate { |j| j.material == "MDF / hardboard" }, plywood: rate { |j| j.material == "Plywood / wood" },
        acrylic: rate { |j| j.material == "Acrylic" }, thick_plywood: rate { |j| j.material == "Plywood / wood" && j.mm.to_f >= 9 },
        passes: rate { |j| j.passes >= 2 }, single: rate { |j| j.passes < 2 } }
    end

    # [trouble after starting dirty, trouble after starting clean], percents
    def dirty_start
      [%w[No], %w[Yes]].map do |answers|
        rows = with_settings.select { |j| answers.include?(j.clean_start) }
        Stats.percent(rows.count { |j| !j.success? }, rows.size)
      end
    end

    # Power divided by speed that 3 mm plywood took to cut through, by half
    # year: { "2023 H1" => { ratio:, power:, speed:, earlier: } }, nil where
    # nothing was logged. Higher is a weaker beam. The current form counts the
    # jobs that worked; the earlier log, which has no results, every job.
    def drift
      plywood = ->(j) { j.cut_op == "cut" && j.material == "Plywood / wood" && j.bucket == "3 mm (1/8 in)" }
      groups = (@earlier.select(&plywood) + @jobs.select { |j| plywood.(j) && j.success? }).group_by { |j| half_of(j.date) }
      first = (@earlier.first || @jobs.first).date
      halves = (first.year..@jobs.last.date.year).flat_map { |y| ["#{y} H1", "#{y} H2"] }
      halves = halves.drop_while { |half| half < half_of(first) }
      halves.to_h do |half|
        rows = groups.fetch(half, [])
        [half, rows.any? ? { ratio: Stats.median(rows.map { |j| j.cut_power / j.cut_speed }).round(2),
                             power: Stats.median(rows.map(&:cut_power)), speed: Stats.median(rows.map(&:cut_speed)),
                             earlier: rows.first.source == LaserJob::EARLIER } : nil]
      end
    end

    private

    def half_of(date) = "#{date.year} H#{date.month < 7 ? 1 : 2}"
  end
end
