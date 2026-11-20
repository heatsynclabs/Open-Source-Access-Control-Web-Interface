require "test_helper"
require "minitest/mock"

# The class sign-ups section of the analytics page, signed in for real.
class AnalyticsClassesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def member(attributes = {})
    user = User.new({ name: "Test Person", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                      orientation: Date.current - 30, postal_code: "85201", current_skills: "x", desired_skills: "x",
                      marketing_source: "x" }.merge(attributes))
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  setup do
    Rails.cache.clear
    TicketedEvent.delete_all
    TicketedEvent.create!(guestlist_id: 1, name: "Solder a Robot", held_on: Date.current - 20, kind: "Electronics",
                          status: "held", attendees: 17, checked_in: 15, dollars: 340)
    TicketedEvent.create!(guestlist_id: 2, name: "Cancelled Laser Class", held_on: Date.current - 10, kind: "Laser",
                          status: "cancelled", attendees: 6, dollars: 60)
    TicketedEvent.update_all(collected_at: Time.zone.local(2026, 11, 19, 16, 14))
  end

  def analytics_page(**params)
    LabCalendar.stub(:between, ->(_range) { raise LabCalendar::Unavailable }) { get analytics_path(params) }
    assert_response :success
  end

  test "members see sign-ups but not class money" do
    sign_in member
    analytics_page
    assert_select "h2", "Who signs up"
    assert_select ".tile .num", "17"
    assert_select ".tile .num", "88%"
    assert_match "Solder a Robot", response.body
    assert_no_match "Cancelled Laser Class", response.body
    assert_match "1 cancelled in this period", response.body
    assert_no_match "Collected for classes", response.body
  end

  test "admins also see the money" do
    sign_in member(admin: true)
    analytics_page
    assert_select ".tile .label", "Collected for classes"
    assert_select ".tile .num", "$340"
  end

  test "the page says the numbers are copied from guestlist, and when" do
    sign_in member
    analytics_page
    assert_match "Not live", response.body
    assert_match "exported from the organizer account on November 19, 2026", response.body
  end

  test "the Classes tab lists every event with its status" do
    sign_in member
    analytics_page(section: "classes")
    assert_select ".tabs a.on", "Classes"
    assert_select "h3", "By year"
    assert_select "td", "Cancelled Laser Class"
    assert_select ".chip.err", "cancelled"
    assert_select "h2", text: "When people come in", count: 0 # only the classes section
  end

  test "the All tab draws everything together, and Dues is for the treasurer" do
    sign_in member
    analytics_page
    assert_select "h3", "Everything together"
    assert_select ".tabs a", text: "Dues", count: 0
    analytics_page(section: "dues")
    assert_select ".tabs a.on", "All" # an unknown or forbidden tab falls back to All
  end

  test "the section is left out until the table exists" do
    sign_in member
    TicketedEvent.stub(:available?, false) { analytics_page }
    assert_select "h2", text: "Who signs up", count: 0
  end
end
