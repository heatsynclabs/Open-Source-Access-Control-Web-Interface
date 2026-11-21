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

  def sync(csv, sheet = LaserLog.sheet("large"))
    LaserLog::Sync.new([sheet], texts: { sheet => csv }).run.fetch(sheet)
  end

  test "sync replaces the jobs and keeps no names" do
    LaserJob.delete_all
    csv = CSV.generate { |out| out << HEADER; out << row; out << row(stamp: "3/5/2024 10:00:00", name: "Grace Hopper", result: "Fail") }
    assert_equal({ read: 2, kept: 2, skipped: 0 }, sync(csv))
    assert_equal 2, LaserJob.where(machine: "large", source: LaserJob::FORM).count
    assert_equal 2, LaserJob.distinct.count(:person_key)
    refute LaserJob.all.map(&:attributes).to_s.match?(/Lovelace|Hopper/)
  end

  test "each sheet replaces only its own jobs; the mini laser's current form reads like the large one's" do
    LaserJob.delete_all
    sync(CSV.generate { |out| out << HEADER; out << row })
    sync(CSV.generate { |out| out << HEADER; out << row; out << row(stamp: "3/6/2024 10:00:00") }, LaserLog.sheet("mini"))
    assert_equal 1, LaserJob.where(machine: "large").count
    assert_equal 2, LaserJob.where(machine: "mini").count
  end

  test "the large laser's old form: free-text materials in the form's terms, mm thickness, no results" do
    LaserJob.delete_all
    header = ["Timestamp", "Start Time", "End Time", "Project Title", "Your Name", "Was the laser clean when you started?",
              "Did you clean the laser?", "Laser run time (in minutes) total for all parts", "Material", "Thickness (in mm)",
              "Cutting Speed", "Cutting Power", "What type of use was this?", "Engraving Scan Gap (if engrave)", "Number of passes",
              "Project Notes", "Machine Notes", "Engraving Speed", "Engraving Power"]
    csv = CSV.generate do |out|
      out << header
      out << ["6/1/2016 19:00:00", "", "", "Box", "Ada Lovelace", "Yes", "Yes", "20", "masonite", "3", "12", "70", "", "", "1", "", "", "", ""]
      out << ["6/2/2016 19:00:00", "", "", "Coaster", "Grace Hopper", "No", "Yes", "5", "Baltic birch", "6", "", "", "", "0.1", "", "nice", "", "300", "40"]
    end
    assert_equal 2, sync(csv, LaserLog.sheet("large", LaserJob::OLD))[:kept]
    box, coaster = LaserJob.where(source: LaserJob::OLD).order(:logged_at)
    assert_equal ["MDF / hardboard", "masonite", "3 mm (1/8 in)", "cut", 70, 12], [box.material, box.material_raw, box.bucket, box.cut_op, box.cut_power, box.cut_speed]
    assert_equal ["Plywood / wood", nil, "raster", "unknown", "nice"], [coaster.material, coaster.cut_op, coaster.eng_mode, coaster.result, coaster.notes]
    assert_equal 20, box.minutes
    refute LaserJob.all.map(&:attributes).to_s.match?(/Lovelace|Hopper/)
  end

  test "the mini laser's old form keeps its results and older material names; its 2011 to 2013 jobs are the first laser's" do
    LaserJob.delete_all
    header = ["Timestamp", "Start Time", "Finish Time", "Project Title", "Name", "Laser Run Time (TOTAL for ALL copies)",
              "Was the machine clean when you STARTED?", "Did you clean up the machine and work area when you FINISHED?", "Material",
              "Thickness", "Cutting Power", "Cutting Speed", "Cutting Number of Passes", "Engraving Power", "Engraving Speed",
              "Engraving Gap", "Engraving Number of Passes", "Results", "Project Notes", "Machine Notes", "Software Notes"]
    csv = CSV.generate do |out|
      out << header
      out << ["3/1/2012 19:00:00", "", "", "Box", "Ada Lovelace", "10", "Yes", "Yes", "Cardboard (Corrugated)", "3 mm (1/8\")", "30", "40", "1", "", "", "", "", "Fail", "", "", ""]
    end
    csv += CSV.generate_line(["3/1/2020 19:00:00", "", "", "Tag", "Grace Hopper", "5", "Yes", "Yes", "Acrylic (Plexiglas, Lucite)", "3 mm (1/8\")", "60", "10", "1", "", "", "", "", "Success", "", "", ""])
    sync(csv, LaserLog.sheet("mini", LaserJob::OLD))
    first = LaserJob.find_by!(machine: "first", source: LaserJob::OLD)
    assert_equal ["Corrugated cardboard", "fail", "Cardboard (Corrugated)"], [first.material, first.result, first.material_raw]
    assert_equal [Date.new(2020, 3, 1)], LaserJob.where(machine: "mini").pluck(:logged_on)
    sync(csv, LaserLog.sheet("mini", LaserJob::OLD))
    assert_equal 2, LaserJob.count, "a re-read replaces both machines' rows from that sheet"
  end

  test "sync refuses a sheet that is not the log, or far shorter than what is held, and keeps its jobs" do
    LaserJob.delete_all
    assert sync("Name,Email\nx,y\n")[:error]
    sync(CSV.generate { |out| out << HEADER; 10.times { |i| out << row(stamp: "3/#{i + 1}/2024 10:00:00") } })
    assert_match "fewer", sync(CSV.generate { |out| out << HEADER; out << row })[:error]
    assert_equal 10, LaserJob.count
  end

  test "a sheet that comes back as a web page fails alone; the other sheets still update" do
    LaserJob.delete_all
    large, mini = LaserLog.sheet("large"), LaserLog.sheet("mini")
    page = %(<html><a href="x">Sign in</a>"broken</html>\n)
    good = CSV.generate { |out| out << HEADER; out << row }
    result = LaserLog::Sync.new([large, mini], texts: { large => page, mini => good }).run
    assert result.fetch(large)[:error]
    assert_equal 1, LaserJob.where(machine: "mini").count
  end

  test "the cast stone rows are read from their timestamps, not from who logged them" do
    assert_equal "Cast stone (manufactured)", clean(stamp: "6/1/2022 12:09:41", material: "OTHER", title: "Marker")[:material]
    assert_not_equal "Cast stone (manufactured)", clean(stamp: "6/9/2022 12:00:00", material: "OTHER", title: "Marker")[:material]
  end
end
