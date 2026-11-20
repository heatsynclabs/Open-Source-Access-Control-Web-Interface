require "test_helper"
require "minitest/mock"

class GuestlistSyncTest < ActiveSupport::TestCase
  # Answers like guestlist's public pages, from a hash of events.
  class FakeClient
    def initialize(events, types = {}, upcoming = [])
      @events, @types, @upcoming = events, types, upcoming
    end

    def upcoming_event_ids = @upcoming
    def event(id) = @events[id]
    def ticket_types(id) = @types.fetch(id, [])
  end

  NOW = Time.zone.local(2026, 11, 20, 3, 0)

  def guestlist_event(id, name:, start:, tickets: 0, check_ins: 0, published: true, profile: Guestlist::PROFILE_ID)
    { "id" => id, "name" => name, "start" => start.utc.iso8601, "profile_id" => profile, "published_at" => (published ? "2026-10-01T00:00:00Z" : nil),
      "complete_tickets_count" => tickets, "check_ins_count" => check_ins }
  end

  def sync(client, calendar: [])
    LabCalendar.stub(:between, calendar) { Guestlist::Sync.new(client: client, now: NOW).run }
  end

  setup { TicketedEvent.delete_all }

  test "reads new and recent events and works out status, people and money" do
    TicketedEvent.create!(guestlist_id: 10, name: "Old name", held_on: NOW.to_date - 5, kind: "Other", status: "upcoming",
                          attendees: 2, checked_in: 0, dollars: 0, collected_at: NOW - 30.days)
    TicketedEvent.create!(guestlist_id: 11, name: "Long ago", held_on: NOW.to_date - 400, kind: "Other", status: "held",
                          attendees: 9, checked_in: 0, dollars: 90, collected_at: NOW - 400.days)
    client = FakeClient.new(
      {
        10 => guestlist_event(10, name: "Laser Portraits - Fri 11/14 @6pm", start: NOW - 5.days, tickets: 8, check_ins: 6),
        20 => guestlist_event(20, name: "Solder a Robot", start: NOW + 10.days, tickets: 3),
        30 => guestlist_event(30, name: "Someone else's class", start: NOW + 3.days, profile: 1),
      },
      { 10 => [{ "name" => "Portrait", "price" => 10.0, "complete_tickets_count" => 7 },
               { "name" => "Optional donation", "price" => 5.0, "complete_tickets_count" => 1 }] },
      [20, 30]
    )
    tally = sync(client)
    assert_equal({ read: 2, skipped: 1 }, tally.to_h.slice(:read, :skipped).transform_values(&:to_i))

    portraits = TicketedEvent.find_by!(guestlist_id: 10)
    assert_equal ["held", 7, 6, 75.0, "Laser", "public pages"],
                 [portraits.status, portraits.attendees, portraits.checked_in, portraits.dollars.to_f, portraits.kind, portraits.source]
    assert_equal "upcoming", TicketedEvent.find_by!(guestlist_id: 20).status
    assert_nil TicketedEvent.find_by(guestlist_id: 30)
    assert_equal 9, TicketedEvent.find_by!(guestlist_id: 11).attendees # older than REFRESH_FOR: left as it was
  end

  test "an upcoming event guestlist took down is marked cancelled" do
    TicketedEvent.create!(guestlist_id: 40, name: "Kumihimo", held_on: NOW.to_date + 3, kind: "Crafts and textiles", status: "upcoming",
                          attendees: 4, checked_in: 0, dollars: 0)
    assert_equal 1, sync(FakeClient.new({}))[:taken_down]
    assert_equal "cancelled", TicketedEvent.find_by!(guestlist_id: 40).status
  end

  test "a calendar entry titled cancelled cancels the event it links" do
    calendar_event = LabCalendar::Event.new(id: "x", title: "CANCELLED Light Up Graham Cracker Houses", description: "Tickets https://guestli.st/50001",
                                            location: "", starts_at: NOW + 2.days, ends_at: NOW + 2.days + 2.hours, all_day: false, repeating: false)
    client = FakeClient.new({ 50001 => guestlist_event(50001, name: "Light Up Graham Cracker Houses", start: NOW + 2.days, tickets: 5) })
    sync(client, calendar: [calendar_event])
    assert_equal "cancelled", TicketedEvent.find_by!(guestlist_id: 50001).status
  end

  test "status rules" do
    rule = ->(**options) { TicketedEvent.status_for(name: "Laser Class", published: true, starts_at: NOW - 1.day, tickets: 3, now: NOW, **options) }
    assert_equal "held", rule.call
    assert_equal "no sign-ups", rule.call(tickets: 0)
    assert_equal "never published", rule.call(published: false)
    assert_equal "cancelled", rule.call(name: "!Cancelled! Laser Class")
    assert_equal "upcoming", rule.call(starts_at: NOW + 1.day)
    assert_equal "held", rule.call(calendar_titles: ["Laser Class", "CANCELLED Laser Class"]) # one entry still on
  end
end
