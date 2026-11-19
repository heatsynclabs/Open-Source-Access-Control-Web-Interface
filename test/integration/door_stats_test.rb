require "test_helper"

# The Door stats tab of a member's own profile, signed in for real.
class DoorStatsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def member(name)
    user = User.new(name: name, email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                    orientation: Date.current - 30, postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  setup do
    Rails.cache.clear
    DoorLog.delete_all
    DoorActivityArchive.delete_all
  end

  test "the profile has a Door stats tab that loads the member's own stats" do
    ada = member("Ada Lovelace")
    DoorActivityArchive.create!(user_id: ada.id, year: 2014, days: 150, hours: 12.5, shifts: 3, opened: 4, locked: 3,
                                covers_from: Date.new(2012, 9, 15), covers_to: Date.new(2020, 10, 5))
    DoorActivityArchive.create!(user_id: member("Grace Hopper").id, year: 2014, days: 4321,
                                covers_from: Date.new(2012, 9, 15), covers_to: Date.new(2020, 10, 5))
    sign_in ada
    get edit_user_registration_path
    assert_response :success
    assert_select "button[role=tab][data-name=door]", "Door stats"
    assert_select "turbo-frame#door-stats[src=?][loading=lazy]", door_stats_path

    get door_stats_path
    assert_response :success
    assert_select "turbo-frame#door-stats .tile .num", "150"
    assert_select "turbo-frame#door-stats .tile .sub", "#2 on the all-time board"
    assert_no_match "4321", response.body
    assert_match "October 2020 to July 2022", response.body
  end

  test "a member with no door history sees an empty state" do
    sign_in member("New Member")
    get door_stats_path
    assert_response :success
    assert_select ".empty", /No door activity yet/
  end

  test "signed-out visitors cannot load it" do
    get door_stats_path
    assert_response :redirect
  end
end
