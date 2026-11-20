require "test_helper"

class Laser::QueriesTest < ActiveSupport::TestCase
  Job = Laser::Log::Job

  def job(id, material: "Plywood / wood", mm: 3.0, bucket: "3 mm (1/8 in)", power: 60.0, speed: 15.0, result: "success", person: "a", date: Date.new(2024, 1, 1))
    Job.new(id: id, date: date, person: person, title: "t", material_raw: "", material: material, family: LaserLog::Cleaner::FAMILY[material],
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
