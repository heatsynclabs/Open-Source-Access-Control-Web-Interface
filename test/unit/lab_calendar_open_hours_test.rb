require 'test_helper'

# LabCalendar.open_hours_until: only what is already cached, never a download,
# never an exception.
class LabCalendarOpenHoursTest < ActiveSupport::TestCase
  TEXT = "BEGIN:VCALENDAR\nEND:VCALENDAR\n".freeze

  def event(title, starts_at, ends_at, all_day: false)
    LabCalendar::Event.new(id: SecureRandom.hex(4), title: title, description: "", location: "",
                           starts_at: starts_at, ends_at: ends_at, all_day: all_day, repeating: false)
  end

  setup do
    Rails.cache.clear
    @now = Time.zone.parse("2026-11-25 19:30")
  end

  def cache(events)
    Rails.cache.write(LabCalendar::Feed::FRESH_KEY, TEXT)
    Rails.cache.write(LabCalendar.events_cache_key(TEXT), events)
  end

  test 'the end of the Open Hours event running now' do
    cache([event("Laser class", @now - 1.hour, @now + 3.hours),
           event("Open Hours", @now - 2.hours, @now + 90.minutes),
           event("Open Hours", @now + 1.day, @now + 1.day + 3.hours)])
    assert_equal @now + 90.minutes, LabCalendar.open_hours_until(@now)
  end

  test 'nil when no Open Hours event is running, or it is all day' do
    cache([event("Open Hours", @now + 1.hour, @now + 3.hours),
           event("Open Hours", @now.beginning_of_day, @now.end_of_day, all_day: true)])
    assert_nil LabCalendar.open_hours_until(@now)
  end

  test 'nil, without downloading, when nothing is cached' do
    Net::HTTP.stub(:start, ->(*) { flunk "downloaded" }) do
      assert_nil LabCalendar.open_hours_until(@now)
      Rails.cache.write(LabCalendar::Feed::FRESH_KEY, TEXT) # feed cached, events not expanded yet
      assert_nil LabCalendar.open_hours_until(@now + 2.minutes)
    end
  end

  test 'a broken cache entry gives nil, not an error' do
    Rails.cache.write(LabCalendar::Feed::FRESH_KEY, TEXT)
    Rails.cache.write(LabCalendar.events_cache_key(TEXT), [:not_an_event])
    assert_nil LabCalendar.open_hours_until(@now)
  end
end
