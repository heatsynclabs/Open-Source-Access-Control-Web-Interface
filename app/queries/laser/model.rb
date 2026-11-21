module Laser
  # "Laser math": what the log can say about cutting energy and the machine's
  # health, ported from the laser explorer's model_laser.py (least squares
  # and medians; its job classifier is left out). People, not jobs, are the
  # independent unit, so the intervals resample people.
  #
  # E (J/mm) = watts / 100 x power % / speed mm/s x passes, the energy the
  # beam leaves per millimetre (0.8 on the 80 W tube, 0.6 on the 60 W). The law: log E = log k(material)
  # + b log thickness, fitted to clean cuts through rigid stock.
  class Model
    RIGID = ["Plywood / wood", "MDF / hardboard", "Acrylic", "Softwood (basswood, balsa, pine)", "Hardwood",
             "Melamine / whiteboard"].freeze
    # Optics work noted in each machine's log notes. Add a line when the lens
    # is cleaned or the beam realigned. (None is noted on the mini laser's.)
    OPTICS = {
      "large" => [
        [Date.new(2022, 11, 11), "Realign and repair"], [Date.new(2023, 10, 4), "Optics clean"],
        [Date.new(2023, 12, 12), "Lens clean"], [Date.new(2024, 12, 22), "Lens clean"], [Date.new(2026, 9, 20), "Lens clean"],
      ].freeze,
      "mini" => [].freeze,
    }.freeze
    SEED = 1

    Cut = Data.define(:job, :energy, :resid)

    # Everything the Laser math view shows, worked out once per sync (it
    # resamples people hundreds of times, about two seconds); laser:sync
    # warms it. nil when too few clean cuts are logged.
    # The optics figures are nil for a machine with no optics work noted.
    def self.summary(machine)
      Rails.cache.fetch(["laser", "math", machine, LaserJob.synced_at.to_i]) do
        model = new(Laser::Log.jobs(machine), watts: LaserJob::WATTS.fetch(machine), optics: OPTICS.fetch(machine))
        next nil unless model.available?
        optics = OPTICS.fetch(machine).any?
        { cuts: model.cuts_count, worked: model.worked_count, b: model.b, k: model.k, b_range: model.b_range,
          b_single: model.b_single, b_vote: model.b_vote, spread: model.spread, jobs: model.jobs_per_material,
          thickest: model.thickest, observed: RIGID.first(3).to_h { |m| [m, model.observed(m)] },
          quarters: model.quarters, optics: (model.optics if optics), optics_trouble: (model.optics_trouble if optics),
          hours: (model.hours if optics), per_percent: model.per_percent }
      end
    end

    def initialize(jobs, watts: 80, optics: OPTICS["large"])
      @jobs = jobs
      @per_percent = watts / 100.0
      @optics = optics
      rigid = jobs.select { |j| j.cut_op == "cut" && j.mm && RIGID.include?(j.material) && j.mm >= 2 }
      ok = rigid.select(&:success?)
      @coef = fit(ok.map { |j| [j, energy(j)] })
      @cuts = rigid.map { |j| Cut.new(job: j, energy: energy(j), resid: Math.log(energy(j)) - predict(j)) }
      @ok = @cuts.select { |c| c.job.success? }
    end

    def available?
      @ok.size >= 30
    end

    attr_reader :per_percent

    def cuts_count = @cuts.size
    def worked_count = @ok.size

    # The exponent and the J/mm used on 1 mm of each material.
    def b = @coef.last
    def k = RIGID.each_with_index.to_h { |m, i| [m, Math.exp(@coef[i])] }

    def energy_at(material, mm) = k[material] * mm**b

    # How far a cut's energy sits from the law, in log terms (0 on the line;
    # the tube reading reads recent cuts this way). nil off the law's stock.
    def residual(job)
      return nil unless job.cut_op == "cut" && job.mm && RIGID.include?(job.material) && job.cut_power.to_f.positive? && job.cut_speed.to_f.positive?
      Math.log(energy(job)) - predict(job)
    end

    def jobs_per_material = RIGID.to_h { |m| [m, @ok.count { |c| c.job.material == m }] }
    def thickest = RIGID.to_h { |m| [m, @ok.select { |c| c.job.material == m }.map { |c| c.job.mm }.max] }

    # How much the exponent moves: resampling people, single pass jobs only,
    # and one vote per person per stock.
    def b_range
      rng = Random.new(SEED)
      by_person = @ok.group_by { |c| c.job.person }.values
      fits = Array.new(600) { exponent(Array.new(by_person.size) { by_person.sample(random: rng) }.flatten.map { |c| [c.job, c.energy] }) }.compact
      return [nil, nil] if fits.empty?
      [even(Stats.quantile(fits, 0.05), 2), even(Stats.quantile(fits, 0.95), 2)]
    end

    def b_single
      exponent(@ok.select { |c| c.job.passes == 1 }.map { |c| [c.job, c.energy] })&.then { |v| even(v, 2) }
    end

    def b_vote
      votes = @ok.group_by { |c| [c.job.person, c.job.material, c.job.mm] }.map { |_key, cs| [cs.first.job, Stats.median(cs.map(&:energy))] }
      exponent(votes)&.then { |v| even(v, 2) }
    end

    # Middle 80% of jobs, and half of jobs, around the law.
    def spread
      ratios = @ok.map { |c| Math.exp(c.resid) }
      { low: even(Stats.quantile(ratios, 0.1), 2), high: even(Stats.quantile(ratios, 0.9), 2),
        half: even(Stats.median(ratios.map { |r| (r - 1).abs }), 3) }
    end

    # Median J/mm of jobs at each thickness (3 or more jobs), per material.
    def observed(material)
      @ok.select { |c| c.job.material == material }.group_by { |c| c.job.mm }.select { |_mm, cs| cs.size >= 3 }
        .sort.map { |mm, cs| [mm, even(Stats.median(cs.map(&:energy)), 2), cs.size] }
    end

    # Energy index by quarter, one vote per person: 1.00 is the law.
    def quarters
      @ok.group_by { |c| quarter(c.job.date) }.select { |_q, cs| cs.size >= 5 }.sort.map do |q, cs|
        people = cs.group_by { |c| c.job.person }.values.map { |pcs| Stats.median(pcs.map(&:resid)) }
        { quarter: q, index: even(Math.exp(Stats.median(cs.map(&:resid))), 3), vote: even(Math.exp(Stats.median(people)), 3),
          people: people.size, n: cs.size }
      end
    end

    # Each optics event: energy and trouble 60 days either side, for all jobs,
    # one vote per person, and the same people on both sides.
    def optics
      @optics.map do |day, label|
        before, after = around(day, 60)
        pb, pa = [before, after].map { |side| side.select { |c| c.job.success? }.group_by { |c| c.job.person }.transform_values { |cs| Stats.median(cs.map(&:resid)) } }
        both = pb.keys & pa.keys
        changes = both.map { |p| pa[p] - pb[p] }
        { day: day, label: label, window: window(day, 60),
          vote: pb.any? && pa.any? ? even(100 * (Math.exp(Stats.median(pa.values) - Stats.median(pb.values)) - 1)) : nil,
          same: { n: both.size, change: changes.any? ? even(100 * (Math.exp(Stats.median(changes)) - 1)) : nil,
                  down: changes.count { |d| d < -0.02 }, up: changes.count { |d| d > 0.02 } } }
      end
    end

    # Trouble in the 60 days before optics work against after, all events
    # pooled, with a Fisher exact p.
    def optics_trouble
      totals = @optics.map { |day, _| around(day, 60) }.each_with_object([[0, 0], [0, 0]]) do |(before, after), sums|
        sums[0][0] += before.count { |c| !c.job.success? }
        sums[0][1] += before.size
        sums[1][0] += after.count { |c| !c.job.success? }
        sums[1][1] += after.size
      end
      (b0, b1), (a0, a1) = totals
      { before: [b0, b1], after: [a0, a1], p: even(Stats.fisher(b0, b1 - b0, a0, a1 - a0), 3) }
    end

    # Does the energy people need rise with laser hours since the last optics
    # work? Pooled, per stretch between optics events, and person against the
    # same person.
    def hours
      points, since_last = hour_points
      return nil if points.map(&:first).uniq.size < 3
      slope = Stats.line(points.map(&:first), points.map { |pt| pt[1] }).first
      rng = Random.new(SEED)
      by_person = points.group_by(&:last).values
      boot = Array.new(400) { pooled_slope(Array.new(by_person.size) { by_person.sample(random: rng) }.flatten(1)) }.compact
      stretches = points.group_by { |pt| pt[2] }.sort.map do |stretch, pts|
        counts = pts.map(&:last).tally
        regulars = pts.select { |pt| counts[pt.last] >= 3 }
        { from: @optics[stretch - 1].first, per100: pooled_slope(pts),
          hours: even(pts.map(&:first).max), n: pts.size, people: regulars.map(&:last).uniq.size,
          within: regulars.size > 20 ? person_slope(regulars)&.then { |s| per100(s) } : nil }
      end
      { per100: per100(slope), low: boot.any? ? even(Stats.quantile(boot, 0.05), 1) : nil, high: boot.any? ? even(Stats.quantile(boot, 0.95), 1) : nil,
        r: even(Stats.correlation(points.map(&:first), points.map { |pt| pt[1] }), 2), n: points.size,
        stretches: stretches, since_last: even(since_last), last: @optics.last }
    end

    private

    def energy(job)
      @per_percent * job.cut_power / job.cut_speed * job.passes
    end

    def design(job)
      RIGID.map { |m| job.material == m ? 1.0 : 0.0 } + [Math.log(job.mm)]
    end

    # Least squares on [material dummies, log mm]; materials missing from a
    # resample are left out (their k is then 0, which nothing reads).
    def fit(pairs)
      x = pairs.map { |job, _e| design(job) }
      y = pairs.map { |_job, e| Math.log(e) }
      used = (0...x.first.size).select { |col| x.any? { |row| row[col] != 0 } }
      solved = Stats.least_squares(x.map { |row| row.values_at(*used) }, y)
      Array.new(x.first.size, 0.0).tap { |coef| used.each_with_index { |col, i| coef[col] = solved[i] } }
    end

    # The exponent alone, or nil when the jobs cannot pin it down (all one
    # thickness): such resamples are skipped, as the explorer's script does.
    def exponent(pairs)
      fit(pairs).last if pairs.any?
    rescue ArgumentError
      nil
    end

    def predict(job)
      design(job).zip(@coef).sum { |x, c| x * c }
    end

    def quarter(date) = "#{date.year}Q#{(date.month - 1) / 3 + 1}"

    def around(day, days)
      [@cuts.select { |c| (1..days).cover?((day - c.job.date).to_i) }, @cuts.select { |c| (0..days).cover?((c.job.date - day).to_i) }]
    end

    def window(day, days)
      before, after = around(day, days)
      worked_before, worked_after = [before, after].map { |side| side.select { |c| c.job.success? }.map(&:resid) }
      return nil if worked_before.size < 3 || worked_after.size < 3
      trouble = ->(side) { even(100.0 * side.count { |c| !c.job.success? } / side.size) }
      { before: even(Math.exp(Stats.median(worked_before)), 3), after: even(Math.exp(Stats.median(worked_after)), 3),
        jobs_before: before.size, jobs_after: after.size, trouble_before: trouble.(before), trouble_after: trouble.(after) }
    end

    # [[hours since optics work, resid, stretch, person]], and the hours since
    # the last optics work at the end of the log.
    def hour_points
      residuals = @cuts.to_h { |c| [c.job.id, c] }
      stretch, hours, points = 0, 0.0, []
      @jobs.sort_by { |j| [j.date, j.id] }.each do |job|
        while stretch < @optics.size && job.date >= @optics[stretch].first
          stretch += 1
          hours = 0.0
        end
        hours += (job.minutes || 0) / 60.0
        cut = residuals[job.id]
        points << [hours, cut.resid, stretch, job.person] if cut && job.success? && stretch.positive?
      end
      [points, hours]
    end

    # Per 100 hours, or nil when the hours do not vary.
    def pooled_slope(points)
      per100(Stats.line(points.map(&:first), points.map { |pt| pt[1] }).first)
    rescue ArgumentError
      nil
    end

    # Slope with a baseline per person.
    def person_slope(points)
      people = points.map(&:last).uniq.sort.drop(1)
      x = points.map { |hours, _r, _s, person| [hours, 1.0] + people.map { |p| p == person ? 1.0 : 0.0 } }
      Stats.least_squares(x, points.map { |pt| pt[1] }).first
    rescue ArgumentError
      nil
    end

    def per100(slope) = even(100 * (Math.exp(slope * 100) - 1), 1)

    # Python's round(), which the explorer's numbers came from: halves to even.
    def even(value, digits = 0)
      value.round(digits, half: :even)
    end
  end
end
