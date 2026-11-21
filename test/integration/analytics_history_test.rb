require "test_helper"
require "minitest/mock"

# The analytics page's "Over the years" tab, signed in for real.
class AnalyticsHistoryTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def member(attributes = {})
    user = User.new({ name: "Test Person", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                      orientation: Date.current - 30, postal_code: "85201", current_skills: "x", desired_skills: "x",
                      marketing_source: "x" }.merge(attributes))
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  def metric(key, starts_on, value, label: "", period: "month")
    LabMetric.create!(key: key, label: label, period: period, starts_on: starts_on, value: value, source: "test")
  end

  setup do
    Rails.cache.clear
    LabMetric.delete_all
    metric("dues_payers", Date.new(2016, 3, 1), 43)
    metric("dues_dollars", Date.new(2016, 3, 1), 1850)
    metric("wiki_page_views", Date.new(2026, 10, 21), 152_998, label: "Rules", period: "total")
    metric("wiki_views", Date.new(2026, 10, 21), 5_734_654, period: "total")
    metric("calendar_items_added", Date.new(2025, 1, 1), 100, period: "year")
    metric("calendar_contributors", Date.new(2025, 1, 1), nil, period: "year")
    metric("calendar_items_added", Date.new(2013, 1, 1), 155, period: "year")
    metric("calendar_contributors", Date.new(2013, 1, 1), 20, period: "year")
    metric("members_by_zone", Date.new(2026, 9, 1), 56, label: "Mesa, downtown and west", period: "total")
    metric("members_by_zone", Date.new(2026, 9, 1), nil, label: "Elsewhere in Arizona", period: "total")
  end

  def history_tab
    LabCalendar.stub(:between, ->(_range) { raise LabCalendar::Unavailable }) { get analytics_section_path(section: "history") }
    assert_response :success
  end

  test "members see the long series but not the money" do
    sign_in member
    history_tab
    assert_select "h2", "Since the lab began"
    assert_select "h3", "Paying members"
    assert_select "td", "Mar 2016"
    assert_select "td", "fewer than 5"
    assert_match "Different people added them: 20 in 2013, fewer than 5 in 2025", response.body
    assert_select "h2", text: "Money", count: 0
    assert_no_match "$1,850", response.body
    assert_select ".az-map svg.az-metro .county", 15
    assert_select ".az-map .zone-label", text: /Mesa, downtown and west 56/
    assert_match "fewer than 5 elsewhere in Arizona", response.body
  end

  test "the wiki deep dive lists the most-read pages" do
    sign_in member
    LabCalendar.stub(:between, ->(_range) { raise LabCalendar::Unavailable }) { get analytics_section_path(section: "history", topic: "wiki") }
    assert_select ".bar-list span", "Rules"
    assert_select ".bar-list .value", "152,998"
    assert_match "5,734,654 views in all", response.body
  end

  test "the treasurer and admins also see the money" do
    sign_in member(admin: true)
    history_tab
    assert_select "h2", "Money"
    assert_select "h3", "Dues and donations through PayPal"
    assert_match "2016 have fewer than twelve months", response.body
  end

  test "the tab is listed and has no period buttons" do
    sign_in member
    get analytics_path(section: "history")
    assert_select ".tabs a.on", "Over the years"
    assert_select "nav[aria-label=Period]", count: 0
    get analytics_path(section: "door")
    assert_select "nav[aria-label=Period]"
  end

  test "each chart leads to its deep dive, and the deep dives link to each other" do
    sign_in member
    history_tab
    assert_select ".card-more a[href=?]", analytics_path(section: "history", topic: "members")
    LabCalendar.stub(:between, ->(_range) { raise LabCalendar::Unavailable }) { get analytics_section_path(section: "history", topic: "members") }
    assert_select "h2", "Paying members"
    assert_select "h3", "PayPal against this site's records"
    assert_select "nav[aria-label='Deep dives'] a.on", "Paying members"
    assert_select "nav[aria-label='Deep dives'] a", text: "Money", count: 0
  end

  test "every deep dive renders, and money only for the treasurer and admins" do
    sign_in member(admin: true)
    Analytics::History::TOPICS.each_key do |topic|
      LabCalendar.stub(:between, ->(_range) { raise LabCalendar::Unavailable }) { get analytics_section_path(section: "history", topic: topic) }
      assert_response :success
      assert_select "h2", Analytics::History::TOPICS[topic][:title]
    end
    sign_out :user
    sign_in member
    get analytics_section_path(section: "history", topic: "money")
    assert_select "h2", text: "Money", count: 0
    assert_select "h2", "Since the lab began" # a topic you cannot open falls back to the tab
  end

  test "before the figures are loaded the tab says so" do
    LabMetric.delete_all
    sign_in member
    history_tab
    assert_match "have not been loaded on this site yet", response.body
  end

  test "the All tab ends with it" do
    sign_in member
    LabCalendar.stub(:between, ->(_range) { raise LabCalendar::Unavailable }) { get analytics_section_path }
    assert_select "h2", "Since the lab began"
  end
end
