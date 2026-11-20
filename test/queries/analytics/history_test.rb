require "test_helper"

class Analytics::HistoryTest < ActiveSupport::TestCase
  def metric(key, starts_on, value, label: "", period: "month")
    LabMetric.create!(key: key, label: label, period: period, starts_on: starts_on, value: value, source: "test")
  end

  setup { LabMetric.delete_all }

  test "lines share one run of months, with gaps where there is no record" do
    metric("mailing_list_posts", Date.new(2018, 1, 1), 30)
    metric("mailing_list_posts", Date.new(2018, 3, 1), 20)
    metric("slack_messages", Date.new(2018, 2, 1), 400)
    posts, slack = Analytics::History.new.monthly(["Mailing list", "mailing_list_posts"], ["Slack", "slack_messages"])
    assert_equal({ "Jan 2018" => 30, "Feb 2018" => nil, "Mar 2018" => 20 }, posts[:data])
    assert_equal({ "Jan 2018" => nil, "Feb 2018" => 400, "Mar 2018" => nil }, slack[:data])
  end

  test "a breakdown line is one label of a key, and years read as years" do
    metric("calendar_places", Date.new(2020, 1, 1), 98, label: "At the lab", period: "year")
    metric("calendar_places", Date.new(2020, 1, 1), 36, label: "Online", period: "year")
    metric("calendar_places", Date.new(2022, 1, 1), 15, label: "Online", period: "year")
    online = Analytics::History.new.yearly(["Online", "calendar_places", "Online"]).first
    assert_equal({ "2020" => 36, "2021" => nil, "2022" => 15 }, online[:data])
  end

  test "tables say fewer than 5 where the small-cell rule hid a number" do
    metric("calendar_items_added", Date.new(2024, 1, 1), 81, period: "year")
    metric("calendar_contributors", Date.new(2024, 1, 1), nil, period: "year")
    metric("calendar_items_added", Date.new(2023, 1, 1), 160, period: "year")
    metric("calendar_contributors", Date.new(2023, 1, 1), 5, period: "year")
    assert_equal [["2023", [160, 5]], ["2024", [81, "fewer than 5"]]],
                 Analytics::History.new.table("calendar_items_added", "calendar_contributors")
  end

  test "money adds up by year and says which years are short" do
    (1..12).each { |month| metric("dues_dollars", Date.new(2024, month, 1), 3500) }
    metric("dues_dollars", Date.new(2025, 1, 1), 3575.5)
    history = Analytics::History.new
    assert_equal({ "2024" => 42_000, "2025" => 3576 }, history.sum_by_year("dues_dollars"))
    assert_equal [2025], history.short_years("dues_dollars")
  end

  test "breakdowns keep their order, or go largest first with Other last" do
    today = Date.new(2026, 9, 1)
    metric("how_heard_all", today, 146, label: "Other", period: "total")
    metric("how_heard_all", today, 168, label: "Searching online", period: "total")
    metric("how_heard_all", today, 207, label: "A friend or member", period: "total")
    history = Analytics::History.new
    assert_equal ["Other", "Searching online", "A friend or member"], history.totals("how_heard_all").map(&:first)
    assert_equal ["A friend or member", "Searching online", "Other"], history.totals("how_heard_all", largest_first: true).map(&:first)
  end

  test "nothing loaded" do
    history = Analytics::History.new
    assert_not history.loaded?
    assert_equal [], history.monthly(["Paying members", "dues_payers"])
  end
end
