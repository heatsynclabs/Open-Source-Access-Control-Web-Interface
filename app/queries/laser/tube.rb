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
  # It is a comparison, not a power meter. It is only as right as the large
  # laser's rating, it reads the whole beam (tube, mirrors, lens, power
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
    RESAMPLES = 400
    SEED = 1

    Reading = Data.define(:machine, :rated, :against, :people, :needed, :since, :through, :restart, :watts, :low, :high,
                          :speed, :stocks, :example) do
      def ready? = !watts.nil?
    end

    # The reading for a machine, or nil for the yardstick itself. Worked out
    # once per sync (it resamples people); laser:sync warms it. Cached as a
    # plain hash under CACHE, so a changed Reading never meets an old copy.
    CACHE = 1

    def self.summary(machine)
      return nil if machine == YARDSTICK || !LaserJob::WATTS.key?(machine)
      values = Rails.cache.fetch(["laser", "tube", CACHE, machine, LaserJob.synced_at.to_i]) do
        restart = REPLACED.values_at(YARDSTICK, machine).flatten(1).max_by(&:first)
        new(Laser::Log.jobs(YARDSTICK), Laser::Log.jobs(machine), machine: machine, since: restart&.first, restart: restart).reading.to_h
      end
      Reading.new(**values)
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
      base = { machine: @machine, rated: LaserJob::WATTS.fetch(@machine), against: LaserJob::WATTS.fetch(YARDSTICK),
               people: @votes.size, needed: PEOPLE, since: (@large + @mini).map(&:date).min, through: (@large + @mini).map(&:date).max,
               restart: @restart }
      return Reading.new(**base, watts: nil, low: nil, high: nil, speed: nil, stocks: [], example: nil) if @votes.size < PEOPLE
      gap = middle(@votes.values)
      low, high = range
      against = base[:against]
      listed = stocks
      Reading.new(**base, watts: (against * Math.exp(gap)).round(1), low: (against * Math.exp(low)).round(1),
                          high: (against * Math.exp(high)).round(1), speed: Math.exp(gap).round(3), stocks: listed, example: example(listed.first))
    end

    private

    # Clean cuts through rigid stock 2 mm and up, as the laser math uses,
    # from people the log can tell apart, since the last tube change.
    def usable(jobs)
      jobs.select do |j|
        j.success? && j.cut_op == "cut" && j.mm && j.mm >= 2 && Model::RIGID.include?(j.material) &&
          j.cut_power.to_f.positive? && j.cut_speed.to_f.positive? && j.person.present? && (@since.nil? || j.date >= @since)
      end
    end

    # log(power x passes / speed): the J/mm yardstick without the watts.
    def effort(job) = Math.log(job.cut_power * job.passes / job.cut_speed)

    def per_stock(jobs) = jobs.group_by { |j| [j.person, j.material, j.mm] }.transform_values { |js| Stats.median(js.map { |j| effort(j) }) }

    # [[person, material, mm], large minus mini] for every stock one person cut on both.
    def shared_stock
      large, mini = per_stock(@large), per_stock(@mini)
      (large.keys & mini.keys).map { |key| [key, large[key] - mini[key]] }
    end

    # Hodges-Lehmann: the median of the averages of every pair (each value
    # with itself included).
    def middle(values)
      Stats.median(values.each_with_index.flat_map { |v, i| values[i..].map { |w| (v + w) / 2.0 } })
    end

    def range
      rng = Random.new(SEED)
      votes = @votes.values
      fits = Array.new(RESAMPLES) { middle(Array.new(votes.size) { votes.sample(random: rng) }) }
      [Stats.quantile(fits, 0.05), Stats.quantile(fits, 0.95)]
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
end
