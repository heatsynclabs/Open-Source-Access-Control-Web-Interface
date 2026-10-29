require "test_helper"

# The cases Google's feed actually contains: a weekly series with one date
# skipped (EXDATE) and one date moved (a RECURRENCE-ID copy), a cancelled
# event, an all-day event, and a class that needs registration.
class LabCalendar::OccurrencesTest < ActiveSupport::TestCase
  FEED = <<~ICS.gsub("\n", "\r\n")
    BEGIN:VCALENDAR
    VERSION:2.0
    X-WR-TIMEZONE:America/Phoenix
    BEGIN:VEVENT
    UID:craft@test
    DTSTART;TZID=America/Phoenix:20261005T190000
    DTEND;TZID=America/Phoenix:20261005T220000
    RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4
    EXDATE;TZID=America/Phoenix:20261012T190000
    SUMMARY:Craft Night
    END:VEVENT
    BEGIN:VEVENT
    UID:craft@test
    RECURRENCE-ID;TZID=America/Phoenix:20261019T190000
    DTSTART;TZID=America/Phoenix:20261020T180000
    DTEND;TZID=America/Phoenix:20261020T210000
    SUMMARY:Craft Night (moved to Tuesday)
    END:VEVENT
    BEGIN:VEVENT
    UID:gone@test
    DTSTART:20261007T020000Z
    DTEND:20261007T040000Z
    STATUS:CANCELLED
    SUMMARY:Cancelled talk
    END:VEVENT
    BEGIN:VEVENT
    UID:faire@test
    DTSTART;VALUE=DATE:20261010
    DTEND;VALUE=DATE:20261012
    SUMMARY:Maker Faire
    END:VEVENT
    BEGIN:VEVENT
    UID:laser@test
    DTSTART:20261015T170000Z
    DTEND:20261015T220000Z
    SUMMARY:Laser Design Workshop (Registration Required)
    DESCRIPTION:Bring your files. $70<br>Sign up: https://guestlist.co/events/822550
    END:VEVENT
    BEGIN:VEVENT
    UID:hours@test
    DTSTART;TZID=America/Phoenix:20261016T190000
    DTEND;TZID=America/Phoenix:20261016T220000
    SUMMARY:Open Hours
    END:VEVENT
    END:VCALENDAR
  ICS

  def events
    LabCalendar::Occurrences.new(FEED).between(Time.zone.parse("2026-10-01"), Time.zone.parse("2026-11-01"))
  end

  test "expands a weekly series, skipping excluded dates and using edited copies" do
    craft = events.select { |event| event.title.start_with?("Craft Night") }
    assert_equal [Time.zone.parse("2026-10-05 19:00"), Time.zone.parse("2026-10-20 18:00"), Time.zone.parse("2026-10-26 19:00")],
                 craft.map(&:starts_at)
    assert_equal "Craft Night (moved to Tuesday)", craft[1].title
    assert craft.all?(&:repeating)
  end

  test "drops cancelled events" do
    assert_not events.any? { |event| event.title == "Cancelled talk" }
  end

  test "keeps all-day events on their days, ending at the last day" do
    faire = events.find { |event| event.title == "Maker Faire" }
    assert faire.all_day
    assert_equal Date.new(2026, 10, 10), faire.day
    assert_equal Date.new(2026, 10, 11), faire.last_day
    assert faire.multi_day?
  end

  test "reads UTC times into lab time" do
    laser = events.find { |event| event.title.start_with?("Laser") }
    assert_equal Time.zone.parse("2026-10-15 10:00"), laser.starts_at
  end

  test "pulls registration details out of the title and description" do
    laser = events.find { |event| event.title.start_with?("Laser") }
    assert laser.registration_required?
    assert_equal "Laser Design Workshop", laser.display_title
    assert_equal "https://guestlist.co/events/822550", laser.registration_url
    assert_equal "$70", laser.cost
  end

  test "sorts events into the site's categories" do
    by_title = events.to_h { |event| [event.title, event.category.key] }
    assert_equal "class", by_title["Laser Design Workshop (Registration Required)"]
    assert_equal "open", by_title["Open Hours"]
    assert_equal "recurring", by_title["Craft Night"]
    assert_equal "default", by_title["Maker Faire"]
    assert_equal "scissors", events.find { |event| event.title == "Craft Night" }.icon
  end
end
