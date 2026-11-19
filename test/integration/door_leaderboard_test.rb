require "test_helper"

# The leaderboard page and the home page's door additions, signed in for real.
class DoorLeaderboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def member(name, oriented: true)
    user = User.new(name: name, email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                    orientation: (Date.current - 30 if oriented),
                    postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  setup do
    Rails.cache.clear
    DoorLog.delete_all
    DoorActivityArchive.delete_all
    @ada = member("Ada Lovelace")
    [[0, "rem_u=1", @ada.id], [2, "door_1_locked", 0]].each do |seconds, key, data|
      at = 40.minutes.ago + seconds
      DoorLog.create!(key: key, data: data, created_at: at, updated_at: at)
    end
  end

  test "signed-out visitors are sent to sign in and see no names on the home page" do
    get door_leaderboard_path
    assert_redirected_to new_user_session_path
    get root_path
    assert_response :success
    assert_no_match "Ada L.", response.body
  end

  test "an oriented member sees who unlocked the door and the leaderboard" do
    sign_in member("Grace Hopper")
    get root_path
    assert_response :success
    assert_select ".door.unlocked .unlocked-by strong", "Ada L."
    assert_select "a[href=?]", door_leaderboard_path
    get door_leaderboard_path(window: "all")
    assert_response :success
    assert_select ".leaderboard .name", "Ada L."
    get door_leaderboard_path(window: "nonsense")
    assert_response :success
  end

  test "an account that only signed up sees neither" do
    sign_in member("New Signup", oriented: false)
    get root_path
    assert_response :success
    assert_select ".unlocked-by", false
    assert_select "a[href=?]", door_leaderboard_path, false
    get door_leaderboard_path
    assert_redirected_to root_url
  end

  test "all time shows the archived years with a note about the lost ones" do
    old = member("Old Timer")
    DoorActivityArchive.create!(user_id: old.id, year: 2015, hours: 321.5, shifts: 60, opened: 70, locked: 65, days: 400,
                                covers_from: Date.new(2012, 8, 25), covers_to: Date.new(2020, 4, 13))
    sign_in member("Grace Hopper")
    get door_leaderboard_path(window: "all")
    assert_response :success
    assert_match "Old T.", response.body
    assert_match "August 2012 to April 2020", response.body
    get door_leaderboard_path(window: "month")
    assert_no_match "Old T.", response.body
    assert_no_match "recovered from old backups", response.body
  end
end
