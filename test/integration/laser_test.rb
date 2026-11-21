require "test_helper"

# The Laser page, signed in for real.
class LaserPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def member
    user = User.new(name: "Test Person", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                    postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  setup do
    Rails.cache.clear
    LaserJob.delete_all
    rows = (1..40).map do |i|
      mm = [3.0, 6.0][i % 2]
      { sheet_row: i + 1, logged_at: Time.zone.local(2024, 1 + i % 12, 1 + i % 27, 18), logged_on: Date.new(2024, 1 + i % 12, 1 + i % 27),
        person_key: "p#{i % 6}", title: "Sign #{i}", material: "Plywood / wood", family: "Wood", mm: mm,
        bucket: mm == 3 ? "3 mm (1/8 in)" : "6 mm (1/4 in)", cut_op: "cut", cut_power: 60 + i % 3, cut_speed: mm == 3 ? 15 : 8,
        cut_passes: 1, result: i % 10 == 0 ? "fail" : "success", result_raw: i % 10 == 0 ? "Fail" : "Success",
        issues: i % 10 == 0 ? "did not cut through" : "", minutes: 12, clean_start: "Yes", cleaned_after: "Yes",
        notes: i % 10 == 0 ? "Did not cut through" : "", fixes: "", created_at: Time.current, updated_at: Time.current }
    end
    LaserJob.insert_all!(rows)
    earlier = (1..5).map do |i|
      { machine: "large", source: LaserJob::OLD, sheet_row: i + 1, logged_at: Time.zone.local(2015, i, 3, 19), logged_on: Date.new(2015, i, 3),
        person_key: "", material_raw: "birch ply", material: "Plywood / wood", family: "Wood", mm: 6.0, bucket: "6 mm (1/4 in)",
        cut_op: "cut", cut_power: 90, cut_speed: 6, cut_passes: 1, result: "unknown", created_at: Time.current, updated_at: Time.current }
    end
    LaserJob.insert_all!(earlier)
    mini = rows.first(12).map { |r| r.merge(machine: "mini", cut_power: 85, cut_speed: 5) }
    LaserJob.insert_all!(mini)
  end

  test "signed out people are sent to sign in" do
    get laser_path
    assert_redirected_to new_user_session_path
  end

  test "the finder shows the typical setting for the chosen stock" do
    sign_in member
    get laser_path(material: "Plywood / wood", op: "cut", bucket: "6 mm (1/4 in)")
    assert_response :success
    assert_select ".tabs a.on", "Find a setting"
    assert_select "h2", "Plywood / wood, 6 mm (1/4 in)"
    assert_select ".tile .num", "8"
    assert_select "svg.laser-chart circle"
  end

  test "the finder shows what the old form used, as history" do
    sign_in member
    get laser_path(material: "Plywood / wood", op: "cut", bucket: "6 mm (1/4 in)")
    assert_select ".laser-earlier strong", "90% at 6 mm/s"
    assert_select ".tile .num", "8" # the recommendation still comes from the current form
  end

  test "the log includes the old form, and can show one form" do
    sign_in member
    get laser_path(view: "log", log: "old")
    assert_select "tbody tr", 5
    assert_select ".chip", "not recorded"
    assert_match "logged as birch ply", response.body
  end

  test "the mini laser has its own settings, kept apart from the large one's" do
    sign_in member
    get laser_path(machine: "mini", material: "Plywood / wood", op: "cut", bucket: "6 mm (1/4 in)")
    assert_select ".laser-machines a.on", "Mini 60W"
    assert_select ".tile .num", "85"
    assert_select ".laser-earlier", 0
    assert_select ".tabs a[href*='machine=mini']"
    LaserController::VIEWS.each_key do |view|
      get laser_path(view: view, machine: "mini")
      assert_response :success, view
    end
  end

  test "the drift chart reaches back through the old form" do
    sign_in member
    get laser_path(view: "trouble")
    assert_select "svg.laser-chart text", "2015"
  end

  test "the cheat sheet is the explorer's sheet: plate, key, family tables, notes and footer" do
    sign_in member
    get laser_path(view: "sheet", paper: "letter")
    assert_select ".sheet .plate h1", "Cheat sheet"
    assert_select ".sheet .t th.fam", "Wood"
    assert_select ".sheet .t td.v", minimum: 2
    assert_select ".sheet .notes .card.haz h2", "Every job"
    assert_match "the whole sheet on one page", response.body
    assert_match "@page { size: 8.5in 11in", response.body
  end

  test "every view renders" do
    sign_in member
    LaserController::VIEWS.each_key do |view|
      get laser_path(view: view)
      assert_response :success, view
      assert_select ".tabs a.on", LaserController::VIEWS[view]
    end
  end

  test "the drift chart marks optics work with dashed lines" do
    sign_in member
    get laser_path(view: "trouble")
    assert_select "svg.laser-chart line.optics"
    assert_select "svg.laser-chart text.optics-label", text: "Lens clean"
  end

  test "the log searches titles and notes and never shows who logged a job" do
    sign_in member
    get laser_path(view: "log", q: "did not cut")
    assert_select "td strong", "Sign 10"
    assert_select "td strong", count: 4
    assert_match "Names on the form are not shown", response.body
  end

  def cut_on_both(people)
    rows = (0...people).flat_map do |p|
      [["large", 15], ["mini", 10]].map do |machine, speed|
        { machine: machine, sheet_row: 1000 + p * 2 + (machine == "mini" ? 1 : 0), logged_at: Time.zone.local(2025, 3, 1 + p, 18), logged_on: Date.new(2025, 3, 1 + p),
          person_key: "both#{p}", title: "Box #{p}", material: "Plywood / wood", family: "Wood", mm: 3.0, bucket: "3 mm (1/8 in)",
          cut_op: "cut", cut_power: 60, cut_speed: speed, cut_passes: 1, result: "success", result_raw: "Success",
          created_at: Time.current, updated_at: Time.current }
      end
    end
    LaserJob.insert_all!(rows)
    Rails.cache.clear
  end

  test "the mini laser shows its tube reading once enough people cut the same stock on both lasers" do
    sign_in member
    get laser_path(machine: "mini")
    assert_select ".laser-tube", 0, "too few people on both lasers yet"
    cut_on_both(20)
    get laser_path(machine: "mini")
    assert_select ".laser-tube .eyebrow", "Tube reading"
    assert_select ".laser-tube strong", /\A\d+ W\z/
    assert_match "not its rated 60 W", response.body
    assert_select ".laser-tube svg.laser-gauge[aria-label*='rated 60 W']"
    assert_select ".laser-tube a[href*='view=math'][href*='#tube']"
    get laser_path(machine: "mini", view: "math")
    assert_select ".laser-tube", 0, "Laser math has the full card instead"
    assert_select "#tube h2", "Tube reading"
    assert_select "#tube .tile.headline .label", "Cuts like"
    assert_select "#tube tbody tr", minimum: 1
    get laser_path(machine: "mini", view: "sheet")
    assert_match "Coming from the Large 80W? Keep the power", response.body
    get laser_path
    assert_select ".laser-tube", 0, "the large laser is the yardstick"
    get laser_path(view: "math")
    assert_select "#tube", 0
  end

  test "analytics counts the large laser's 2011 to 2013 jobs as the large laser's" do
    first = { machine: LaserJob::FIRST, source: LaserJob::OLD, sheet_row: 900, logged_at: Time.zone.local(2012, 3, 1, 19), logged_on: Date.new(2012, 3, 1),
              person_key: "", material: "Acrylic", family: "Plastic", mm: 3.0, bucket: "3 mm (1/8 in)", cut_op: "cut", cut_power: 40,
              cut_speed: 20, cut_passes: 1, result: "success", created_at: Time.current, updated_at: Time.current }
    LaserJob.insert_all!([first])
    LabMetric.delete_all
    LabMetric.create!(key: "dues_payers", label: "", period: "month", starts_on: Date.new(2016, 3, 1), value: 43, source: "test") # Over the years needs a record
    sign_in member
    get analytics_section_path(section: "history", topic: "laser")
    assert_response :success
    assert_select ".tile .label", "On the Large 80W"
    assert_select ".tile .sub", "since Mar 2012"
    assert_no_match(/first laser/i, response.body)
  end

  test "before the log is read the page says so" do
    LaserJob.delete_all
    sign_in member
    get laser_path
    assert_match "has not been read on this site yet", response.body
  end
end
