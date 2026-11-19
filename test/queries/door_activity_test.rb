require "test_helper"

class DoorActivityTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 11, 15, 20, 0)
  AUTO = DoorActivity::AUTOMATIC_LOCK_ID

  setup do
    DoorLog.delete_all
    DoorActivityArchive.delete_all
    Rails.cache.clear
  end

  def archive(user, year: 2015, hours: 0, shifts: 0, opened: 0, locked: 0, days: 0)
    DoorActivityArchive.create!(user_id: user.id, year: year, hours: hours, shifts: shifts, opened: opened, locked: locked, days: days,
                                covers_from: Date.new(2012, 8, 25), covers_to: Date.new(2020, 4, 13))
  end

  def member(name, hidden: false, card: nil, oriented: true)
    user = User.new(name: name, email: "#{SecureRandom.hex(6)}@example.invalid", password: "password", hidden: hidden,
                    orientation: (Date.current - 30 if oriented),
                    postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    Card.create!(user: user, card_number: card, card_permissions: 1) if card
    user
  end

  def log(key, data, at)
    DoorLog.create!(key: key, data: data, created_at: at, updated_at: at)
  end

  # A remote command and the status report the board writes right after it.
  def unlock(user_id, at, key: "rem_u=1")
    log(key, user_id, at)
    log("door_1_locked", 0, at + 2.seconds)
  end

  def lock(user_id, at, key: "rem_l")
    log(key, user_id, at)
    log("door_1_locked", 1, at + 2.seconds)
  end

  # The board logs a swipe as g (high half) then G (low half).
  def swipe(card, at, halves: true)
    number = card.to_i(16)
    log("g", number / DoorActivity::CARD_HALF, at) if halves
    log("G", number % DoorActivity::CARD_HALF, at)
  end

  def activity
    DoorActivity.new(now: NOW)
  end

  def board
    activity.opened_the_lab("all").map { |row| [row.user, row.hours, row.shifts, row.opened, row.locked] }
  end

  # ---------------------------------------------------------- who unlocked it

  test "names whoever unlocked the front door since it was last locked, not a later re-unlock" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    unlock(grace.id, NOW - 6.hours)
    lock(grace.id, NOW - 5.hours)
    unlock(ada.id, NOW - 2.hours)
    unlock(grace.id, NOW - 1.hour) # already open
    assert_equal ada, activity.front_unlocker(DoorLog.show_status).who
  end

  test "says nothing while the front door is locked" do
    unlock(member("Ada Lovelace").id, NOW - 1.hour)
    lock(AUTO, NOW - 10.minutes)
    assert_nil activity.front_unlocker(DoorLog.show_status)
  end

  test "keeps the time but not the name of a hidden member" do
    unlock(member("Vik Prakash", hidden: true).id, NOW - 5.minutes)
    found = activity.front_unlocker(DoorLog.show_status)
    assert_nil found.who
    assert_equal NOW - 5.minutes, found.at
  end

  test "skips an unlock the board never confirmed" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    log("rem_u=1", grace.id, NOW - 20.minutes) # board offline: no status report
    unlock(ada.id, NOW - 10.minutes)
    assert_equal ada, activity.front_unlocker(DoorLog.show_status).who
  end

  test "is nil when the door is unlocked but nobody unlocked it remotely" do
    log("door_1_locked", 0, NOW - 5.minutes)
    assert_nil activity.front_unlocker(DoorLog.show_status)
  end

  # ---------------------------------------------------------- kept the lab open

  test "hours go to someone who unlocked and locked up themselves" do
    ada = member("Ada Lovelace")
    unlock(ada.id, NOW - 6.hours)
    lock(ada.id, NOW - 3.hours, key: "api_rem_l=1")
    assert_equal [[ada, 3.0, 1, 1, 1]], board
  end

  test "when someone else locks up, the opener gets the opening and the closer the locking, and no hours" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    unlock(ada.id, NOW - 6.hours)
    lock(grace.id, NOW - 1.hour)
    assert_equal [[ada, 0.0, 0, 1, 0], [grace, 0.0, 0, 0, 1]], board
  end

  test "a night ended by the after-hours lock earns the opener an opening and no hours" do
    ada = member("Ada Lovelace")
    unlock(ada.id, NOW - 6.hours)
    lock(AUTO, NOW - 1.hour)
    assert_equal [[ada, 0.0, 0, 1, 0]], board
  end

  test "an unlock while the door is open does not start a new period" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    unlock(ada.id, NOW - 6.hours)
    unlock(grace.id, NOW - 5.hours)
    lock(ada.id, NOW - 2.hours)
    assert_equal [[ada, 4.0, 1, 1, 1]], board
  end

  test "letting someone in, an unlock the board never confirmed, and the rear door do not count" do
    ada = member("Ada Lovelace")
    unlock(ada.id, NOW - 8.hours)
    lock(ada.id, NOW - 8.hours + 1.minute)       # let someone in
    log("rem_u=1", ada.id, NOW - 6.hours)          # board offline: no status report
    log("rem_u=2", ada.id, NOW - 5.hours)          # rear unlock, refused
    assert_empty board
  end

  test "an opening from the door tablet is nobody's, but locking it up counts" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    unlock(AUTO, NOW - 6.hours)                 # the door tablet, 2013 to 2016
    unlock(grace.id, NOW - 5.hours)             # the door is already open
    lock(ada.id, NOW - 2.hours)
    assert_equal [[ada, 0.0, 0, 0, 1]], board
  end

  test "opening stats by year split the live log by the year each period started" do
    ada = member("Ada Lovelace")
    unlock(ada.id, Time.zone.local(2025, 3, 1, 18))
    lock(ada.id, Time.zone.local(2025, 3, 1, 21))
    unlock(ada.id, NOW - 6.hours)
    lock(AUTO, NOW - 1.hour)
    by_year = activity.opening_stats_by_year
    assert_equal({ hours: 3.0, shifts: 1, opened: 1, locked: 1 }, by_year[2025][ada.id])
    assert_equal({ hours: 0.0, shifts: 0, opened: 1, locked: 0 }, by_year[2026][ada.id])
  end

  test "a period still open counts as an opening once it passes half an hour" do
    ada = member("Ada Lovelace")
    unlock(ada.id, NOW - 45.minutes)
    assert_equal [[ada, 0.0, 0, 1, 0]], board
    unlock(member("Grace Hopper").id, NOW - 10.minutes)
    assert_equal 1, board.size
  end

  test "the after-hours lock and hidden members never rank" do
    hidden = member("Vik Prakash", hidden: true)
    unlock(hidden.id, NOW - 6.hours)
    lock(hidden.id, NOW - 2.hours)
    assert_empty board
    assert_empty activity.days_at_the_lab("all")
  end

  test "the month window leaves out last month" do
    ada = member("Ada Lovelace")
    unlock(ada.id, NOW.beginning_of_month - 5.hours)
    lock(ada.id, NOW.beginning_of_month - 2.hours)
    assert_empty activity.opened_the_lab("month")
    assert_equal 1, activity.opened_the_lab("all").size
  end

  test "hours rank first, then openings and lockings, then names; ties share a rank and the list stops at the limit" do
    a, b, c, d = %w[Ann Bob Cy Di].map { |name| member("#{name} Test") }
    [[a, 10], [b, 20], [c, 30]].each do |user, hours_ago|
      unlock(user.id, NOW - hours_ago.hours)
      lock(user.id, NOW - hours_ago.hours + 2.hours)
    end
    unlock(d.id, NOW - 40.hours)
    lock(AUTO, NOW - 38.hours)
    rows = activity.opened_the_lab("all")
    assert_equal [a, b, c, d], rows.map(&:user)
    assert_equal [1, 1, 1, 4], rows.map(&:rank)
    assert_equal [a, b], activity.opened_the_lab("all", limit: 2).map(&:user)
  end

  test "the numbers behind a board can be cached" do
    ada = member("Ada Lovelace", card: "5a1f00")
    unlock(ada.id, NOW - 3.hours)
    lock(ada.id, NOW - 1.hour)
    swipe("5a1f00", NOW - 3.hours)
    stats = activity.opening_stats("all")
    assert_equal stats, Marshal.load(Marshal.dump(stats))
    assert_equal({ ada.id => { days: 1 } }, Marshal.load(Marshal.dump(activity.day_stats("all"))))
  end

  test "cached stats match fresh ones, per board and window" do
    ada = member("Ada Lovelace", card: "5a1f00")
    unlock(ada.id, NOW - 3.hours)
    lock(ada.id, NOW - 1.hour)
    swipe("5a1f00", NOW - 3.hours)
    assert_equal activity.opening_stats("month"), activity.cached_stats(:opening, "month")
    unlock(ada.id, Time.zone.local(2024, 5, 1, 18))  # another year, and the archive
    lock(ada.id, Time.zone.local(2024, 5, 1, 20, 30))
    archive(ada, hours: 4.5, shifts: 2, opened: 3, locked: 2)
    assert_equal activity.opening_stats("all"), activity.cached_stats(:opening, "all")
    assert_equal activity.day_stats("all"), activity.cached_stats(:days, "all")
    assert_raises(ArgumentError) { activity.cached_stats(:nonsense, "all") }
  end

  # ---------------------------------------------------------- days at the lab

  test "days count once per day across swipes and remote opens" do
    ada = member("Ada Lovelace", card: "5a1f00")
    grace = member("Grace Hopper", card: "71c2e4")
    swipe("5a1f00", NOW - 2.days)
    swipe("5a1f00", NOW - 2.days + 1.hour)
    log("rem_o1", ada.id, NOW - 1.day)
    swipe("71c2e4", NOW - 1.day, halves: false) # lone G: matched by the low half
    rows = activity.days_at_the_lab("all")
    assert_equal [[ada, 2], [grace, 1]], rows.map { |row| [row.user, row.days] }
  end

  test "a lone G does not pair with an older swipe's high half" do
    grace = member("Grace Hopper", card: "71c2e4")
    member("Ada Lovelace", card: "5a1f00")
    log("g", "5a1f00".to_i(16) / DoorActivity::CARD_HALF, NOW - 1.day)  # Ada's G lost
    log("G", "71c2e4".to_i(16) % DoorActivity::CARD_HALF, NOW - 1.day + 1.minute)
    assert_equal [grace], activity.days_at_the_lab("all").map(&:user)
  end

  test "visits are one member's own swipes and remote unlocks or opens" do
    ada = member("Ada Lovelace", card: "5a1f00")
    grace = member("Grace Hopper", card: "71c2e4")
    swipe("5a1f00", NOW - 2.days)
    swipe("71c2e4", NOW - 2.days + 1.minute)
    log("rem_o1", ada.id, NOW - 1.day)
    log("rem_l", ada.id, NOW - 1.day + 1.minute) # a lock is not a visit
    log("rem_o1", grace.id, NOW - 1.hour)
    assert_equal [[NOW - 2.days, :card], [NOW - 1.day, :remote]], activity.visits(ada.id)
    assert_empty activity.visits(member("No Card").id)
  end

  # ---------------------------------------------------------- who may see it

  test "oriented members and cardholders may see door activity, sign-ups may not" do
    assert Ability.new(member("Ada Lovelace")).can?(:read, :door_activity)
    assert Ability.new(member("Card Holder", oriented: false, card: "abc123")).can?(:read, :door_activity)
    assert Ability.new(member("New Signup", oriented: false)).cannot?(:read, :door_activity)
  end

  test "short names keep the first name and last initial" do
    assert_equal "Ada L.", User.new(name: "Ada King Lovelace").short_name
    assert_equal "Cher", User.new(name: "Cher").short_name
    assert_equal "", User.new(name: nil).short_name
  end

  # ---------------------------------------------------------- archived years

  test "all time adds the archived years to the live log; this month does not" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    unlock(ada.id, NOW - 3.hours)
    lock(ada.id, NOW - 1.hour)
    archive(ada, hours: 100.5, shifts: 40, opened: 50, locked: 45, days: 200)
    archive(grace, hours: 10.0, shifts: 4, opened: 6, locked: 5, days: 30) # only in the archive
    all = activity.opening_stats("all")
    assert_equal({ hours: 102.5, shifts: 41, opened: 51, locked: 46 }, all[ada.id])
    assert_equal({ hours: 10.0, shifts: 4, opened: 6, locked: 5 }, all[grace.id])
    assert_equal({ hours: 2.0, shifts: 1, opened: 1, locked: 1 }, activity.opening_stats("month")[ada.id])
    assert_nil activity.opening_stats("month")[grace.id]
    assert_equal [ada, grace], activity.opened_the_lab("all").map(&:user)
  end

  test "days from the archive add to live days on the all-time board only" do
    ada = member("Ada Lovelace", card: "1a2b3c")
    swipe("1a2b3c", NOW - 2.hours)
    archive(ada, days: 300)
    assert_equal 301, activity.day_stats("all")[ada.id][:days]
    assert_equal 1, activity.day_stats("month")[ada.id][:days]
  end

  test "archive: false scores the live log alone" do
    ada = member("Ada Lovelace")
    archive(ada, hours: 50, shifts: 5, opened: 5, locked: 5, days: 9)
    assert_empty activity.opening_stats("all", archive: false)
    assert_empty activity.day_stats("all", archive: false)
  end

  test "hidden members in the archive stay off the boards" do
    shy = member("Shy Person", hidden: true)
    archive(shy, hours: 500, shifts: 90, opened: 90, locked: 90, days: 900)
    assert_empty activity.opened_the_lab("all")
    assert_empty activity.days_at_the_lab("all")
  end

  test "without the archive table the boards show the live log" do
    ada = member("Ada Lovelace")
    unlock(ada.id, NOW - 3.hours)
    lock(ada.id, NOW - 1.hour)
    DoorActivityArchive.stub(:available?, false) do
      assert_equal({ hours: 2.0, shifts: 1, opened: 1, locked: 1 }, activity.opening_stats("all")[ada.id])
      assert_nil DoorActivityArchive.span
    end
  end

  test "the archive's years add up per member" do
    ada = member("Ada Lovelace")
    archive(ada, year: 2014, hours: 1.5, shifts: 1, opened: 2, locked: 1, days: 100)
    archive(ada, year: 2015, hours: 2.0, shifts: 1, opened: 1, locked: 0, days: 50)
    assert_equal({ hours: 3.5, shifts: 2, opened: 3, locked: 1 }, DoorActivityArchive.opening_stats[ada.id])
    assert_equal({ days: 150 }, DoorActivityArchive.day_stats[ada.id])
    assert_equal [2014, 2015], DoorActivityArchive.years_for(ada.id).map(&:year)
  end

  test "the archive span comes from its rows" do
    assert_nil DoorActivityArchive.span
    archive(member("Ada Lovelace"), hours: 1)
    assert_equal Date.new(2012, 8, 25)..Date.new(2020, 4, 13), DoorActivityArchive.span
  end
end
