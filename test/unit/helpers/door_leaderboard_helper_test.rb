require "test_helper"

class DoorLeaderboardHelperTest < ActionView::TestCase
  test "hours drop a trailing .0" do
    assert_equal "0 h", door_hours(0.0)
    assert_equal "4 h", door_hours(4.0)
    assert_equal "4.5 h", door_hours(4.5)
  end

  test "the detail line leaves out zeros" do
    row = DoorActivity::Row.new(hours: 4.5, shifts: 2, opened: 5, locked: 0)
    assert_equal "2 full shifts, opened 5", door_leaderboard_detail(row)
    row = DoorActivity::Row.new(hours: 0.0, shifts: 0, opened: 0, locked: 1)
    assert_equal "locked up 1", door_leaderboard_detail(row)
  end
end
