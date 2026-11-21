require "test_helper"

class Laser::QueriesTest < ActiveSupport::TestCase
  Job = Laser::Log::Job

  def job(id, material: "Plywood / wood", mm: 3.0, bucket: "3 mm (1/8 in)", power: 60.0, speed: 15.0, result: "success", person: "a", date: Date.new(2024, 1, 1))
    Job.new(machine: "large", source: LaserJob::FORM, id: id, date: date, person: person, title: "t", material_raw: "", material: material, family: LaserLog::Cleaner::FAMILY[material],
            mm: mm, bucket: bucket, cut_op: "cut", cut_power: power, cut_speed: speed, cut_passes: 1.0, eng_mode: nil, eng_power: nil,
            eng_speed: nil, eng_passes: nil, eng_gap: nil, result: result, result_raw: result.capitalize, issues: [], minutes: 10.0,
            clean_start: "Yes", notes: "", machine_notes: "", software_notes: "", fixes: [])
  end

  test "statistics match the explorer's" do
    assert_equal 2.5, Laser::Stats.median([1, 2, 3, 4])
    assert_equal 1.75, Laser::Stats.quantile([1, 2, 3, 4], 0.25)
    assert_in_delta 2.0, Laser::Stats.least_squares([[1.0, 1.0], [2.0, 1.0], [3.0, 1.0]], [3.0, 5.0, 7.0]).first
    assert_in_delta 1.0, Laser::Stats.fisher(5, 5, 5, 5)
    assert_operator Laser::Stats.fisher(10, 0, 0, 10), :<, 0.001
  end

  test "a setting's typical numbers come from the jobs that worked" do
    jobs = [job(1, power: 60, speed: 15), job(2, power: 62, speed: 15, person: "b"), job(3, power: 90, speed: 5, result: "fail", person: "c")]
    settings = Laser::Settings.new(jobs)
    stats = settings.stats(settings.rows_for("Plywood / wood", "3 mm (1/8 in)", "cut"), "cut")
    assert_equal [3, 2, 61.0, 15.0], stats.values_at(:n, :basis, :power, :speed)
    assert_equal 67, stats[:rate]
    assert_equal ["thin", "Few jobs logged"], settings.reliability(stats)
    assert_equal ["Plywood / wood", "cut", "3 mm (1/8 in)"], settings.choose("Nonsense", nil, nil)
  end

  test "usage leaves a machine's months outside its stretches of logging blank, not zero" do
    large = (0..20).map { |i| job(i, date: Date.new(2019, 1, 15) + (i * 40)) } # Jan 15, Feb 24, Apr 5: none in March
    mini = [job(100, date: Date.new(2011, 8, 12)), job(101, date: Date.new(2011, 9, 3)), job(102, date: Date.new(2011, 10, 3)),
            job(103, date: Date.new(2019, 11, 13)), job(104, date: Date.new(2019, 12, 2)), job(105, date: Date.new(2020, 1, 2))]
    large_series, mini_series = Laser::Usage.new("large" => large, "mini" => mini).jobs_by_machine.map { |s| s[:data] }
    assert_nil mini_series[Date.new(2011, 8, 1)] # first month of a stretch: partial
    assert_equal 1, mini_series[Date.new(2011, 9, 1)]
    assert_nil mini_series[Date.new(2011, 10, 1)] # last month of a stretch that ended
    assert_nil mini_series[Date.new(2015, 6, 1)] # nothing logged for years
    assert_equal 1, mini_series[Date.new(2019, 12, 1)]
    assert_nil large_series[Date.new(2011, 9, 1)] # before the large laser's log
    assert_equal 0, large_series[Date.new(2019, 3, 1)] # a quiet month inside a stretch
  end

  test "the tube reading puts watts on the mini from people who cut the same stock on both lasers" do
    large, mini = [], []
    20.times do |p|
      person = "p#{p}"
      large << job(p * 10 + 1, person: person, power: 60, speed: 15) << job(p * 10 + 2, person: person, power: 60, speed: 15)
      mini << job(p * 10 + 3, person: person, power: 60, speed: 10)
      large << job(p * 10 + 4, person: person, material: "Acrylic", power: 80, speed: 10)
      mini << job(p * 10 + 5, person: person, material: "Acrylic", power: 80, speed: 6.6)
    end
    mini << job(999, person: "p1", power: 99, speed: 1, result: "fail") # failures never count
    mini << job(998, person: "nobody else", power: 20, speed: 30) # nor do people who only cut on one laser
    t = Laser::Tube.new(large, mini).reading
    assert t.ready?
    assert_equal [60, 80, 20], [t.rated, t.against, t.people]
    assert_in_delta 53.0, t.watts, 0.4 # 80 W x (60/15) / (60/10)
    assert_in_delta 0.66, t.speed, 0.01
    assert_operator t.low, :<=, t.watts
    assert_operator t.high, :>=, t.watts
    assert_equal [["Plywood / wood", 3.0, 20], ["Acrylic", 3.0, 20]], t.stocks.map { |s| s.values_at(:material, :mm, :people) }
    assert_equal [[60.0, 15.0, 1.0], [60.0, 10.0, 1.0]], t.example.values_at(:large, :mini)
  end

  test "the tube reading waits for enough people, and starts over after a new tube" do
    large = (1..20).map { |p| job(p, person: "p#{p}", date: Date.new(2024, 1, 1)) }
    mini = (1..20).map { |p| job(100 + p, person: "p#{p}", speed: 10, date: Date.new(2024, 1, 2)) }
    refute Laser::Tube.new(large.first(10), mini.first(10)).reading.ready?
    restarted = Laser::Tube.new(large, mini, since: Date.new(2025, 6, 1), restart: [Date.new(2025, 6, 1), "New tube"]).reading
    refute restarted.ready?
    assert_equal [0, 15], [restarted.people, restarted.needed]
    assert_nil Laser::Tube.summary("large"), "the large laser is the yardstick"
  end

  test "the energy law recovers the exponent it was built with" do
    jobs = (1..40).map do |i|
      mm = [2.0, 3.0, 4.0, 6.0, 9.0][i % 5]
      energy = 1.0 * mm**0.9 * (1 + (i % 3 - 1) * 0.02)
      job(i, mm: mm, bucket: "x", power: 50.0, speed: 0.8 * 50 / energy, person: "p#{i % 7}")
    end
    model = Laser::Model.new(jobs)
    assert model.available?
    assert_in_delta 0.9, model.b, 0.02
  end
end
