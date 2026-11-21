module Laser
  # The tube reading: how strong the mini laser cuts, in watts, going by the
  # log. Members who cut the same material and thickness on both lasers set
  # the mini to more power per mm/s than the large one, by a steady ratio.
  # Counting the large laser at its rated LaserJob::WATTS, that ratio puts
  # watts on the mini. The rating on the machine stays as it is; this is what
  # the log says the beam does now, read again every night.
  #
  # Each person is one vote: their median gap over the stock they cut on both
  # lasers. The reading is the Hodges-Lehmann middle of those votes (the
  # median of every pair's average), which stays steady when many people
  # copy the same class setting, and the range resamples people.
  #
  # The large laser has nothing to be read against, so it is read against
  # itself (Tube::Own): its last WINDOW months against the energy law fitted
  # to its whole log, that average counted as its rated watts.
  #
  # Both are comparisons, not a power meter. They are only as right as the
  # large laser's rating, they read the whole beam (tube, mirrors, lens, power
  # supply), and the log records habit as well as power. See docs/laser.md.
  class Tube
    YARDSTICK = "large"
    # Tube replacements, [date, what was done]. Add a line when either laser
    # gets a new tube: the reading starts over from that day, because jobs on
    # the old tube say nothing about the new one. The large laser's 80 W tube
    # went in before the current forms began (April 2022).
    REPLACED = { "large" => [], "mini" => [] }.freeze
    PEOPLE = 15 # people who cut the same stock on both lasers, before there is a reading
    STOCK_PEOPLE = 5 # for a stock to be listed
    WINDOW = 12 # months of the large laser's log read against the rest
    RESAMPLES = 400
    SEED = 1

    # kind: :against (the mini, read against the large laser) or :own (the
    # large laser, its last WINDOW months against its own log from `since`).
    # speed: the share of the speed that gives the same cut as on the yardstick.
    Reading = Data.define(:kind, :machine, :rated, :against, :people, :needed, :since, :from, :through, :restart, :watts, :low, :high,
                          :speed, :stocks, :example) do
      def ready? = !watts.nil?
      def own? = kind == :own
    end

    # The reading for a machine, or nil for the yardstick itself. Worked out
    # once per sync (it resamples people); laser:sync warms it. Cached as a
    # plain hash under CACHE, so a changed Reading never meets an old copy.
    CACHE = 2

    def self.summary(machine)
      return nil unless LaserJob::WATTS.key?(machine)
      values = Rails.cache.fetch(["laser", "tube", CACHE, machine, LaserJob.synced_at.to_i]) do
        if machine == YARDSTICK
          restart = REPLACED.fetch(machine).max_by(&:first)
          Own.new(Laser::Log.jobs(machine), since: restart&.first, restart: restart).reading.to_h
        else
          restart = REPLACED.values_at(YARDSTICK, machine).flatten(1).max_by(&:first)
          new(Laser::Log.jobs(YARDSTICK), Laser::Log.jobs(machine), machine: machine, since: restart&.first, restart: restart).reading.to_h
        end
      end
      Reading.new(**values)
    end

    # Clean cuts through rigid stock 2 mm and up, as the laser math uses,
    # from people the log can tell apart, on or after `since`.
    def self.usable(jobs, since)
      jobs.select do |j|
        j.success? && j.cut_op == "cut" && j.mm && j.mm >= 2 && Model::RIGID.include?(j.material) &&
          j.cut_power.to_f.positive? && j.cut_speed.to_f.positive? && j.person.present? && (since.nil? || j.date >= since)
      end
    end

    # Hodges-Lehmann: the median of the averages of every pair (each value
    # with itself included).
    def self.middle(values)
      Stats.median(values.each_with_index.flat_map { |v, i| values[i..].map { |w| (v + w) / 2.0 } })
    end

    # The 90% range of the middle, resampling the votes (people).
    def self.range(votes)
      rng = Random.new(SEED)
      fits = Array.new(RESAMPLES) { middle(Array.new(votes.size) { votes.sample(random: rng) }) }
      [Stats.quantile(fits, 0.05), Stats.quantile(fits, 0.95)]
    end

    def initialize(yardstick_jobs, jobs, machine: "mini", since: nil, restart: nil)
      @machine = machine
      @since = since
      @restart = restart
      @large = usable(yardstick_jobs)
      @mini = usable(jobs)
      @shared = shared_stock
      @votes = @shared.group_by { |(person, _m, _mm), _gap| person }.transform_values { |rows| Stats.median(rows.map(&:last)) }
    end

    def reading
      base = { kind: :against, machine: @machine, rated: LaserJob::WATTS.fetch(@machine), against: LaserJob::WATTS.fetch(YARDSTICK),
               people: @votes.size, needed: PEOPLE, since: (@large + @mini).map(&:date).min, through: (@large + @mini).map(&:date).max,
               from: nil, restart: @restart }
      return Reading.new(**base, watts: nil, low: nil, high: nil, speed: nil, stocks: [], example: nil) if @votes.size < PEOPLE
      gap = middle(@votes.values)
      low, high = Tube.range(@votes.values)
      against = base[:against]
      listed = stocks
      Reading.new(**base, watts: (against * Math.exp(gap)).round(1), low: (against * Math.exp(low)).round(1),
                          high: (against * Math.exp(high)).round(1), speed: Math.exp(gap).round(3), stocks: listed, example: example(listed.first))
    end

    private

    def usable(jobs) = Tube.usable(jobs, @since)
    def middle(values) = Tube.middle(values)

    # log(power x passes / speed): the J/mm yardstick without the watts.
    def effort(job) = Math.log(job.cut_power * job.passes / job.cut_speed)

    def per_stock(jobs) = jobs.group_by { |j| [j.person, j.material, j.mm] }.transform_values { |js| Stats.median(js.map { |j| effort(j) }) }

    # [[person, material, mm], large minus mini] for every stock one person cut on both.
    def shared_stock
      large, mini = per_stock(@large), per_stock(@mini)
      (large.keys & mini.keys).map { |key| [key, large[key] - mini[key]] }
    end

    # Each stock at least STOCK_PEOPLE people cut on both lasers, read on its
    # own the same way, most people first.
    def stocks
      @shared.group_by { |(_p, material, mm), _gap| [material, mm] }.select { |_stock, rows| rows.size >= STOCK_PEOPLE }
        .sort_by { |(material, mm), rows| [-rows.size, Model::RIGID.index(material), mm] }.first(6).map do |(material, mm), rows|
          { material: material, mm: mm, people: rows.size, watts: (LaserJob::WATTS.fetch(YARDSTICK) * Math.exp(middle(rows.map(&:last)))).round(1) }
        end
    end

    # The most used setting on each laser for the stock most people cut on
    # both: the worked example of bringing a setting over.
    def example(stock)
      return nil unless stock
      large, mini = [@large, @mini].map { |jobs| most_used(jobs.select { |j| j.material == stock[:material] && j.mm == stock[:mm] }) }
      { material: stock[:material], mm: stock[:mm], large: large, mini: mini }
    end

    # [power, speed, passes] logged most often, ties to the most recent.
    def most_used(jobs)
      jobs.each_with_index.group_by { |j, _i| [j.cut_power, j.cut_speed, j.passes.to_f] }
        .max_by { |_setting, rows| [rows.size, rows.map(&:last).max] }.first
    end
  end

  # The large laser against itself: the energy law (Laser::Model) fitted to
  # its clean cuts since `since`, and each person's cuts of the last WINDOW
  # months against it, one vote per person. Counting the law (the average of
  # the whole log) as the rated watts, the middle vote is what it cuts like
  # now: 74 W says recent cuts took 80 / 74 times the energy the log's
  # average did for the same stock.
  class Tube::Own
    def initialize(jobs, machine: Tube::YARDSTICK, since: nil, restart: nil)
      @machine, @since, @restart = machine, since, restart
      @rated = LaserJob::WATTS.fetch(machine)
      kept = jobs.select { |j| since.nil? || j.date >= since }
      @cuts = Tube.usable(kept, since)
      @through = @cuts.map(&:date).max
      @from = @through && (@through << Tube::WINDOW) + 1
      model = Model.new(kept, watts: @rated)
      @recent = @through ? @cuts.select { |j| j.date >= @from }.map { |j| [j, model.residual(j)] } : []
      @votes = @recent.group_by { |j, _r| j.person }.transform_values { |rows| Stats.median(rows.map(&:last)) }
    end

    def reading
      base = { kind: :own, machine: @machine, rated: @rated, against: @rated, people: @votes.size, needed: Tube::PEOPLE,
               since: @cuts.map(&:date).min, from: @from, through: @through, restart: @restart, example: nil }
      return Tube::Reading.new(**base, watts: nil, low: nil, high: nil, speed: nil, stocks: []) if @votes.size < Tube::PEOPLE
      mid = Tube.middle(@votes.values)
      low, high = Tube.range(@votes.values)
      Tube::Reading.new(**base, watts: watts(mid), low: watts(high), high: watts(low), speed: Math.exp(-mid).round(3), stocks: stocks)
    end

    private

    def watts(resid) = (@rated * Math.exp(-resid)).round(1)

    def stocks
      @recent.group_by { |j, _r| [j.material, j.mm] }.filter_map do |(material, mm), rows|
        votes = rows.group_by { |j, _r| j.person }.values.map { |rs| Stats.median(rs.map(&:last)) }
        { material: material, mm: mm, people: votes.size, watts: watts(Tube.middle(votes)) } if votes.size >= Tube::STOCK_PEOPLE
      end.sort_by { |s| [-s[:people], Model::RIGID.index(s[:material]), s[:mm]] }.first(6)
    end
  end
end
