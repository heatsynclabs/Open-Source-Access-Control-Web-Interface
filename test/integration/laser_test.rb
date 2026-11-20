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

  test "every view renders" do
    sign_in member
    LaserController::VIEWS.each_key do |view|
      get laser_path(view: view)
      assert_response :success, view
      assert_select ".tabs a.on", LaserController::VIEWS[view]
    end
  end

  test "the log searches titles and notes and never shows who logged a job" do
    sign_in member
    get laser_path(view: "log", q: "did not cut")
    assert_select "td strong", "Sign 10"
    assert_select "td strong", count: 4
    assert_match "Names on the form are not shown", response.body
  end

  test "before the log is read the page says so" do
    LaserJob.delete_all
    sign_in member
    get laser_path
    assert_match "has not been read on this site yet", response.body
  end
end
