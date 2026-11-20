require "test_helper"
require "csv"

class LaserLogTest < ActiveSupport::TestCase
  HEADER = ["Timestamp", "Start Time", "Finish Time", "Project Title", "FULL Name", "Laser Run Time (TOTAL for ALL copies",
            "How many COPIES did you make?", "Was the Machine CLEAN when you STARTED?", "Describe the problem with the DIRTY Machine?",
            "Did you CLEAN the Machine AND the Work Area when you FINISHED?", "What MATERIAL did you use?", "What THICKNESS?",
            "Did you use CUTTING?", "Cutting Power", "Cutting Speed", "Cutting Number of Passes", "Did you use ENGRAVING?",
            "Engraving Power", "Engraving Speed", "Engraving Number of Passes", "Engraving Scan Gap", "Results", "Project Notes",
            "Machine Notes", "Software Notes"].freeze

  # A form row; anything not given is blank.
  def row(stamp: "3/4/2024 18:30:00", title: "Sign", name: "Ada Lovelace", material: "Plywood", thickness: "3 mm (1/8\")",
          cut: ["Yes", "60", "15", "1"], engrave: ["No", "", "", "", ""], result: "Success", notes: "", minutes: "12")
    [stamp, "", "", title, name, minutes, "1", "Yes", "", "Yes", material, thickness, *cut, *engrave, result, notes, "", ""]
  end

  def clean(**fields)
    LaserLog::Cleaner.new.call(row(**fields), 2).first
  end

  test "a plain job comes through as logged" do
    job = clean
    assert_equal ["Plywood / wood", "Wood", 3.0, "3 mm (1/8 in)", "cut", 60.0, 15.0, 1.0, "success"],
                 job.values_at(:material, :family, :mm, :bucket, :cut_op, :cut_power, :cut_speed, :cut_passes, :result)
    assert_equal "", job[:fixes]
    assert_equal Date.new(2024, 3, 4), job[:logged_on]
  end

  test "power and speed typed into each other's box are swapped back" do
    job = clean(cut: ["Yes", "150", "60", "1"])
    assert_equal [60.0, 150.0, "score"], job.values_at(:cut_power, :cut_speed, :cut_op)
    assert_includes job[:fixes], "cut power/speed swapped"
  end

  test "a fast vector pass on rigid stock is a score, not a cut" do
    job = clean(cut: ["Yes", "20", "200", "1"])
    assert_equal "score", job[:cut_op]
    assert_includes job[:fixes], "fast vector pass filed as score"
  end

  test "glass settings in the cut boxes are read as engrave" do
    job = clean(material: "Glass", thickness: "Surface Engrave ONLY", cut: ["Yes", "30", "300", "1"])
    assert_nil job[:cut_op]
    assert_equal [30.0, 300.0, "raster"], job.values_at(:eng_power, :eng_speed, :eng_mode)
    assert_includes job[:fixes], "glass: cut boxes read as engrave"
  end

  test "materials logged as OTHER are read from the note, and names merge" do
    assert_equal "Food", clean(material: "OTHER", title: "Graham crackers")[:material]
    assert_equal "Other / unknown", clean(material: "OTHER", title: "Mystery")[:material]
    assert_includes clean(material: "Wood")[:fixes], "material: merged name"
  end

  test "scan gaps, passes and results are tidied" do
    job = clean(cut: ["No", "", "", ""], engrave: ["Yes", "40", "300", "1", "008"])
    assert_in_delta 0.08, job[:eng_gap]
    assert_nil clean(cut: ["No", "", "", ""], engrave: ["Yes", "40", "300", "1", "250"])[:eng_gap]
    assert_nil clean(cut: ["Yes", "60", "15", "40"])[:cut_passes]
    free = clean(result: "Did not cut through, used a knife")
    assert_equal "conditional", free[:result]
    assert_equal "did not cut through", free[:issues]
  end

  test "hand corrections apply to their row" do
    job = clean(stamp: "2/11/2023 17:07:48", cut: ["Yes", "454", "15", "1"])
    assert_equal 45.0, job[:cut_power]
    assert_includes job[:fixes], "cut power 454 read as 45"
  end

  test "a row without a readable date is skipped" do
    assert_nil LaserLog::Cleaner.new.call(row(stamp: "soon"), 2)
  end

  test "the person key tells people apart without naming them" do
    key = LaserLog.person_key("Ada Lovelace")
    assert_equal key, LaserLog.person_key("  ada   LOVELACE ")
    refute_equal key, LaserLog.person_key("Grace Hopper")
    refute_match(/ada|lovelace/i, key)
  end

  test "sync replaces the jobs and keeps no names" do
    LaserJob.delete_all
    csv = CSV.generate { |out| out << HEADER; out << row; out << row(stamp: "3/5/2024 10:00:00", name: "Grace Hopper", result: "Fail") }
    assert_equal({ read: 2, kept: 2, skipped: 0 }, LaserLog::Sync.new(csv).run)
    assert_equal 2, LaserJob.count
    assert_equal 2, LaserJob.distinct.count(:person_key)
    refute LaserJob.all.map(&:attributes).to_s.match?(/Lovelace|Hopper/)
  end

  test "the earlier log loads from its file, cleaned like the form, and the nightly sync leaves it alone" do
    LaserJob.delete_all
    loaded = LaserLog::Archive.new.load!
    assert_equal CSV.read(LaserLog::Archive::FILE, headers: true).size, loaded
    assert_equal loaded, LaserLog::Archive.new.load!, "reloading replaces, never adds"
    earlier = LaserJob.where(source: LaserJob::EARLIER)
    assert_equal ["unknown"], earlier.distinct.pluck(:result)
    assert_equal "", earlier.distinct.pick(:person_key)
    assert_operator earlier.where(material: "Plywood / wood").count, :>, 700
    assert earlier.where(material_raw: "masonite").all? { |job| job.material == "MDF / hardboard" }
    csv = CSV.generate { |out| out << HEADER; out << row }
    LaserLog::Sync.new(csv).run
    assert_equal loaded, LaserJob.where(source: LaserJob::EARLIER).count
    assert_equal 1, LaserJob.where(source: LaserJob::FORM).count
  end

  test "sync refuses a sheet that is not the log, or far shorter than what is held" do
    LaserJob.delete_all
    assert_raises(LaserLog::Error) { LaserLog::Sync.new("Name,Email\nx,y\n").run }
    csv = CSV.generate { |out| out << HEADER; 10.times { |i| out << row(stamp: "3/#{i + 1}/2024 10:00:00") } }
    LaserLog::Sync.new(csv).run
    short = CSV.generate { |out| out << HEADER; out << row }
    assert_raises(LaserLog::Error) { LaserLog::Sync.new(short).run }
    assert_equal 10, LaserJob.count
  end
end
