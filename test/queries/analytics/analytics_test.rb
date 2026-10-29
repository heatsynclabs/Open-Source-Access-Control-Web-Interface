require "test_helper"
require "minitest/mock"

class Analytics::QueriesTest < ActiveSupport::TestCase
  def period(key = "12m")
    Analytics::Period.new(key)
  end

  def member(attributes = {})
    user = User.new({ name: "Test Person", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                      postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x" }.merge(attributes))
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  test "unknown periods fall back to twelve months, grouped by month" do
    assert_equal "12m", period("nonsense").key
    assert_equal :month, period("12m").unit
    assert_equal :week, period("90d").unit
  end

  test "level mix bands members the way the site names levels" do
    member(member_level: 100)
    member(member_level: 50)
    member(member_level: 75)
    member(member_level: 10)
    mix = Analytics::Members.new(period).level_mix
    assert_operator mix["Plus"], :>=, 1
    assert_operator mix["Basic"], :>=, 2
    assert_operator mix["Volunteer"], :>=, 1
  end

  test "the funnel counts each step among people who joined in the period" do
    joined = member(created_at: 10.days.ago, orientation: 5.days.ago)
    Payment.create!(user: joined, date: Date.current, amount: 50)
    member(created_at: 3.years.ago, orientation: 3.years.ago)
    funnel = Analytics::Members.new(period).funnel
    assert_operator funnel["Signed up"], :>=, 1
    assert_operator funnel["Came to orientation"], :>=, 1
    assert_operator funnel["Paid dues"], :>=, 1
    assert_operator funnel["Signed up"], :>=, funnel["Paid dues"]
  end

  test "payments are tallied by tier price, with other amounts as Other" do
    payer = member(member_level: 50)
    Payment.create!(user: payer, date: Date.current, amount: 50)
    Payment.create!(user: payer, date: Date.current - 31, amount: 35)
    mix = Analytics::Payments.new(period).tier_mix
    assert_operator mix["$50"], :>=, 1
    assert_operator mix["Other"], :>=, 1
  end

  test "door entries land in their weekday and hour, lab time" do
    sunday_evening = Time.zone.local(2026, 10, 25, 19, 30)
    DoorLog.create!(key: "G", data: 1234, created_at: sunday_evening)
    grid = Analytics::Door.new(period).weekday_hour_grid
    assert_operator grid[[0, 19]].to_i, :>=, 1
  end

  test "door use on event days is compared with days with nothing on" do
    event = LabCalendar::Event.new(id: "a", title: "Craft Night", description: "", location: "",
                                   starts_at: Time.zone.local(2026, 10, 5, 19), ends_at: Time.zone.local(2026, 10, 5, 22),
                                   all_day: false, repeating: true)
    LabCalendar.stub(:between, [event]) do
      comparison = Analytics::Calendar.new(period).door_entries_on_event_days(
        { Date.new(2026, 10, 5) => 30, Date.new(2026, 10, 6) => 10, Date.new(2026, 10, 7) => 20 }
      )
      assert_equal 30.0, comparison["Days with an event"]
      assert_equal 15.0, comparison["Days with nothing on"]
    end
  end
end
