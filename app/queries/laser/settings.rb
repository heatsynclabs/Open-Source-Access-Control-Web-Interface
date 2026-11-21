module Laser
  # Settings that worked, by material, thickness and job (cut through, or
  # engrave): the laser explorer's "Find a setting", "All settings" and
  # cheat sheet. Typical numbers are medians of the jobs that worked
  # (successes; failing two of those, everything that was not a failure).
  class Settings
    OPS = { "cut" => "Cut through", "engrave" => "Engrave" }.freeze
    RELIABILITY = {
      "good" => "Reliable", "mid" => "Mostly works", "poor" => "Hit or miss",
    }.freeze

    attr_reader :jobs

    def initialize(jobs)
      @jobs = jobs
    end

    # Materials with settings logged, most used first.
    def materials
      @materials ||= LaserLog::Cleaner::FAMILY.keys.reject { |m| m == "Other / unknown" }
        .map { |m| [m, jobs.count { |j| j.material == m && (j.cut_op == "cut" || j.eng_mode) }] }
        .select { |_m, used| used.positive? }.sort_by { |m, used| [-used, LaserLog::Cleaner::FAMILY.keys.index(m)] }.map(&:first)
    end

    def ops_for(material)
      OPS.keys.select { |op| rows_for(material, nil, op).any? }
    end

    # Thicknesses a material has been cut at, in order ("Surface only" only
    # when there is nothing else).
    def buckets_for(material)
      counts = rows_for(material, nil, "cut").map(&:bucket).tally
      real = LaserLog::Cleaner::BUCKET_ORDER.select { |b| counts[b] && b != "Surface only" }
      real.any? ? real : LaserLog::Cleaner::BUCKET_ORDER.select { |b| counts[b] }
    end

    # The choice the finder shows: falls back to a job and thickness that
    # have data, as the explorer does. Returns [material, op, bucket].
    def choose(material, op, bucket)
      material = materials.include?(material) ? material : materials.first
      op = OPS.key?(op) ? op : "cut"
      op = op == "cut" ? "engrave" : "cut" if rows_for(material, nil, op).empty?
      return [material, op, "All"] if op == "engrave"
      counts = rows_for(material, nil, "cut").map(&:bucket).tally
      counts.delete("Surface only") if counts.keys.any? { |b| b != "Surface only" }
      bucket = counts.max_by { |_b, n| n }&.first unless counts.key?(bucket)
      [material, op, bucket]
    end

    def rows_for(material, bucket, op)
      rows = jobs.select { |j| j.material == material && (op == "engrave" ? j.eng_mode : j.cut_op == op) }
      rows = rows.select { |j| j.bucket == bucket } if bucket && bucket != "All"
      if op == "engrave"
        raster = rows.select { |j| j.eng_mode == "raster" }
        rows = raster if raster.any?
      end
      rows
    end

    def stats(rows, op)
      power, speed, passes = op == "engrave" ? %i[eng_power eng_speed eng_passes] : %i[cut_power cut_speed cut_passes]
      counts = { "success" => 0, "conditional" => 0, "fail" => 0, "unknown" => 0 }.merge(rows.map(&:result).tally)
      good = rows.select(&:success?)
      good = rows.select { |j| %w[success conditional].include?(j.result) } if good.size < 2
      good = rows if good.empty?
      p = good.map(&power)
      s = good.map(&speed)
      n = good.map(&passes).compact
      people = good.group_by(&:person).values
      {
        n: rows.size, counts: counts, basis: good.size,
        rate: Stats.percent(counts["success"], [1, counts["success"] + counts["conditional"] + counts["fail"]].max),
        power: Stats.median(p), power_mean: Stats.mean(p), power_lo: Stats.quantile(p, 0.25), power_hi: Stats.quantile(p, 0.75),
        speed: Stats.median(s), speed_mean: Stats.mean(s), speed_lo: Stats.quantile(s, 0.25), speed_hi: Stats.quantile(s, 0.75),
        passes: n.any? ? Stats.median(n) : 1, gap: Stats.median(good.map(&:eng_gap).compact),
        top: good.map { |j| "#{number(j.public_send(power))} / #{number(j.public_send(speed))}" }.tally.max_by { |_k, c| c },
        people: people.size,
        people_power: Stats.median(people.map { |a| Stats.median(a.map(&power)) }),
        people_speed: Stats.median(people.map { |a| Stats.median(a.map(&speed)) }),
        busiest_share: good.any? ? Stats.percent(people.map(&:size).max, good.size) : 0,
        scattered: good.size >= 4 && (Stats.quantile(s, 0.75) / Stats.quantile(s, 0.25) >= 3 || Stats.quantile(p, 0.75) - Stats.quantile(p, 0.25) >= 35),
      }
    end

    # ["thin" | "good" | "mid" | "poor", label]
    def reliability(stats)
      return ["thin", "Few jobs logged"] if stats[:basis] < 5
      return ["thin", "Settings vary a lot"] if stats[:scattered]
      return ["good", RELIABILITY["good"]] if stats[:rate] >= 90
      return ["mid", RELIABILITY["mid"]] if stats[:rate] >= 75
      ["poor", RELIABILITY["poor"]]
    end

    # The last eight jobs that struggled and left a note, newest first.
    def struggled(rows)
      rows.select { |j| !j.success? && (j.notes.present? || j.machine_notes.present? || free_result(j).present?) }.last(8).reverse
    end

    def free_result(job)
      %w[success fail conditional\ success].include?(job.result_raw.downcase) ? "" : job.result_raw
    end

    # Every power and speed tried for a setting: [{power:, speed:, n:, outcome counts}]
    def tried(rows, op)
      power, speed = op == "engrave" ? %i[eng_power eng_speed] : %i[cut_power cut_speed]
      rows.group_by { |j| [j.public_send(power), j.public_send(speed)] }.map do |(p, s), group|
        { power: p, speed: s, n: group.size }.merge(group.map(&:result).tally.transform_keys(&:to_sym))
      end.sort_by { |point| -point[:n] }
    end

    # "All settings": one row per material and thickness with 3 or more jobs.
    def table(op)
      LaserLog::Cleaner::FAMILY.keys.reject { |m| m == "Other / unknown" }.flat_map do |material|
        buckets = op == "cut" ? LaserLog::Cleaner::BUCKET_ORDER - ["Not stated", "Surface only"] : ["All"]
        buckets.filter_map do |bucket|
          rows = rows_for(material, bucket, op)
          next if rows.size < 3 || (op == "engrave" && rows.none? { |j| j.eng_mode == "raster" })
          stats = stats(rows, op)
          { family: LaserLog::Cleaner::FAMILY[material], material: material, bucket: bucket, stats: stats, reliability: reliability(stats) }
        end
      end
    end

    # The cheat sheet: cut tables by family and one raster engrave table.
    def sheet
      families = ["Wood", "Plastic", "Paper and board", "Foam", "Soft goods", "Hard surface"]
      cut = table("cut").select { |row| families.include?(row[:family]) }
      engrave = table("engrave").select { |row| families.include?(row[:family]) && jobs.count { |j| j.material == row[:material] && j.eng_mode == "raster" } >= 3 }
      { cut: cut.group_by { |row| row[:family] }, engrave: engrave }
    end

    # How often each repair was made while cleaning the log.
    def fixes
      jobs.flat_map(&:fixes).tally.sort_by { |_fix, n| -n }
    end

    private

    def number(value)
      value % 1 == 0 ? value.to_i : value
    end
  end
end
