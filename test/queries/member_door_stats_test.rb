require "test_helper"

class MemberDoorStatsTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 11, 15, 20, 0)
  AUTO = DoorActivity::AUTOMATIC_LOCK_ID

  setup do
    DoorLog.delete_all
    DoorActivityArchive.delete_all
    Rails.cache.clear
  end

  def member(name, hidden: false, card: nil)
    user = User.new(name: name, email: "#{SecureRandom.hex(6)}@example.invalid", password: "password", hidden: hidden,
                    orientation: Date.current - 30, postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    Card.create!(user: user, card_number: card, card_permissions: 1) if card
    user
  end

  def log(key, data, at)
    DoorLog.create!(key: key, data: data, created_at: at, updated_at: at)
  end

  def swipe(card, at)
    number = card.to_i(16)
    log("g", number / DoorActivity::CARD_HALF, at)
    log("G", number % DoorActivity::CARD_HALF, at)
  end

  def open_and_lock(user_id, from, to)
    log("rem_u=1", user_id, from)
    log("door_1_locked", 0, from + 2.seconds)
    log("rem_l", user_id, to)
    log("door_1_locked", 1, to + 2.seconds)
  end

  def archive(user, year, days:, hours: 0, shifts: 0, opened: 0, locked: 0)
    DoorActivityArchive.create!(user_id: user.id, year: year, days: days, hours: hours, shifts: shifts, opened: opened, locked: locked,
                                covers_from: Date.new(2012, 9, 15), covers_to: Date.new(2020, 10, 5))
  end

  def stats(user)
    MemberDoorStats.new(user, now: NOW)
  end

  test "years join the archive and the live log, and the total adds them up" do
    ada = member("Ada Lovelace", card: "5a1f00")
    archive(ada, 2014, days: 150, hours: 1.5, shifts: 1, opened: 2, locked: 1)
    swipe("5a1f00", Time.zone.local(2025, 6, 1, 18))
    swipe("5a1f00", Time.zone.local(2025, 6, 1, 19)) # same day
    open_and_lock(ada.id, NOW - 5.hours, NOW - 2.hours)
    years = stats(ada).years
    assert_equal [2014, 2025, 2026], years.map(&:year)
    assert_equal [150, 1, 1], years.map(&:days)
    assert_equal [1.5, 0.0, 3.0], years.map(&:hours)
    total = stats(ada).total
    assert_equal [152, 4.5, 2, 3, 2], [total.days, total.hours, total.shifts, total.opened, total.locked]
  end

  test "by year runs from the first active year to now, zero where nothing was logged" do
    ada = member("Ada Lovelace")
    archive(ada, 2019, days: 10)
    assert_equal({ 2019 => 10, 2020 => 0, 2021 => 0, 2022 => 0, 2023 => 0, 2024 => 0, 2025 => 0, 2026 => 0 }, stats(ada).by_year(:days))
    assert_equal({}, stats(member("Nobody")).by_year(:days))
  end

  test "the week grid and the last twelve months come from the member's own visits" do
    ada = member("Ada Lovelace", card: "5a1f00")
    swipe("5a1f00", Time.zone.local(2026, 11, 10, 18, 30)) # a Tuesday
    log("rem_o1", ada.id, Time.zone.local(2026, 10, 3, 9))
    log("rem_o1", member("Grace Hopper").id, Time.zone.local(2026, 11, 10, 18))
    s = stats(ada)
    assert_equal({ [2, 18] => 1, [6, 9] => 1 }, s.week_grid)
    months = s.recent_months
    assert_equal 12, months.size
    assert_equal [Date.new(2025, 12, 1), 0], months.first
    assert_equal 1, months[Date.new(2026, 10, 1)]
    assert_equal 1, months[Date.new(2026, 11, 1)]
  end

  test "rank counts visible members ahead; hidden members get none" do
    ada, grace = member("Ada Lovelace"), member("Grace Hopper")
    shy = member("Shy Person", hidden: true)
    archive(ada, 2015, days: 10)
    archive(grace, 2015, days: 30)
    archive(shy, 2015, days: 50)
    assert_equal 2, stats(ada).rank(:days)
    assert_equal 1, stats(grace).rank(:days)
    assert_nil stats(shy).rank(:days)
    assert_nil stats(ada).rank(:hours)
  end

  test "a member with no door history has nothing to show" do
    refute stats(member("New Member")).any?
  end
end
