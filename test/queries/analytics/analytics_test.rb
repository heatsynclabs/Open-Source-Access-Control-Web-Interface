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

  test "the bucket we are in is labelled so far" do
    this_month, last_month = Date.current.beginning_of_month, Date.current.beginning_of_month << 1
    assert_equal this_month.strftime("%b %Y") + " (so far)", period.bucket_label(this_month)
    assert_equal last_month.strftime("%b %Y"), period.bucket_label(last_month)
    assert_match(/\(so far\)\z/, period("90d").bucket_label(Date.current.beginning_of_week))
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

  test "door counts include the archived years on the all-time view" do
    DoorLogArchive.delete_all
    DoorLog.where(created_at: Time.zone.local(2014, 1, 1)..Time.zone.local(2015, 1, 1)).delete_all
    at = Time.zone.local(2014, 3, 4, 19)
    DoorLogArchive.create!(key: "G", data: 1234, created_at: at)
    DoorLogArchive.create!(key: "G", data: 1234, created_at: at + 1.hour)
    DoorLogArchive.create!(key: "rem_u=1", data: 7, created_at: at)
    door = Analytics::Door.new(Analytics::Period.new("all"))
    assert_equal 2, door.entries_by_day[Date.new(2014, 3, 4)]
    assert_equal 1, door.distinct_cards_by_period[Date.new(2014, 3, 1)]
    assert_operator door.weekday_hour_grid[[2, 19]].to_i, :>=, 1
    assert_equal 1, door.remote_by_source.find { |s| s[:name] == "Website" }[:data][Date.new(2014, 3, 1)]
    assert_nil Analytics::Door.new(period).entries_by_day[Date.new(2014, 3, 4)] # a recent period leaves it out
  end

  test "door counts fall back to the live log before the archive table exists" do
    DoorLogArchive.stub(:available?, false) do
      assert_kind_of Integer, Analytics::Door.new(Analytics::Period.new("all")).entries_total
    end
  end

  def ticketed(attributes)
    TicketedEvent.create!({ guestlist_id: rand(1..9_999_999), name: "Laser Class", held_on: Date.current - 10, kind: "Laser",
                            status: "held", attendees: 0, checked_in: 0, dollars: 0 }.merge(attributes))
  end

  test "class sign-ups count only events that went ahead" do
    TicketedEvent.delete_all
    ticketed(attendees: 8, checked_in: 6, dollars: 120)
    ticketed(attendees: 4, kind: "Electronics", name: "Solder a Robot")
    ticketed(attendees: 15, status: "cancelled")
    ticketed(status: "no sign-ups")
    ticketed(attendees: 9, held_on: Date.current - 800)
    classes = Analytics::Classes.new(period)
    assert_equal 2, classes.events_count
    assert_equal 12, classes.attendees_total
    assert_equal({ rate: 0.75, events: 1 }, classes.show_up)
    assert_equal({ "Laser" => 8, "Electronics" => 4 }, classes.by_kind)
    assert_equal ["Laser Class", 8], classes.top_events.first
    assert_equal({ "cancelled" => 1, "no sign-ups" => 1 }, classes.left_out)
    assert_equal 120.0, classes.dollars_total
    assert_equal 12, classes.attendees_by_period.values.sum
  end

  test "show-up is unknown when no event checked people in" do
    TicketedEvent.delete_all
    ticketed(attendees: 5)
    assert_nil Analytics::Classes.new(period).show_up
  end

  test "the overview scales each line to its own busy level and starts it with its data" do
    months = (1..12).map { |m| Date.new(2026, m, 1) }
    entries = months.to_h { |month| [month, month.month == 1 ? 0 : 100] }.merge(months.last => 1000)
    overview = Analytics::Overview.new(entries: entries, cards: nil, events: months.to_h { |month| [month, 4] },
                                       signups: {}, accounts: { months.first => 0 })
    lines = overview.indexed.to_h { |line| [line[:name], line[:data]] }
    assert_nil lines["Card entries"][months.first] # before the line's first data
    assert_equal 100, lines["Card entries"][months[5]]
    assert_equal 200, lines["Card entries"][months.last] # one freak month is clipped at the ceiling
    assert_equal [100], lines["Calendar events"].values.uniq
    assert_equal [nil], lines["Class sign-ups"].values.uniq
    assert_equal ["Card entries", "Calendar events", "Class sign-ups", "New accounts"], overview.names
    assert_equal [1000, 4, 0, 0], overview.actual[months.last]
  end
end
