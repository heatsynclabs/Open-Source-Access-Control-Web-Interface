# The lab's public Google Calendar, read from its ICS feed.
#
#   LabCalendar.between(Time.zone.today.all_week)   # events starting this week
#   LabCalendar.upcoming(5)
#
# The feed is fetched at most every 15 minutes (LabCalendar::Feed), and the
# repeating events in it are expanded once per version of the feed
# (LabCalendar::Occurrences), so pages only filter an array in memory.
module LabCalendar
  # Expanded events reach back far enough for the analytics page's
  # "all time", and a year ahead for the calendar page.
  HISTORY_START = Date.new(2010, 1, 1)
  LOOKAHEAD = 13.months

  class Unavailable < StandardError; end

  module_function

  # Every event that starts inside the range (Dates or Times), in start order.
  def between(range)
    from = range.begin.in_time_zone
    to = range.end.is_a?(Date) ? range.end.end_of_day.in_time_zone : range.end.in_time_zone
    events.select { |event| event.starts_at >= from && event.starts_at <= to }
  end

  def upcoming(limit, after: Time.zone.now)
    events.lazy.select { |event| event.ends_at > after }.first(limit)
  end

  def events
    feed = Feed.new
    text = feed.text
    Rails.cache.fetch(["lab_calendar/events", Digest::SHA256.hexdigest(text)], expires_in: 1.day) do
      Occurrences.new(text).between(HISTORY_START.in_time_zone, LOOKAHEAD.from_now)
    end
  end

  # When the feed was last read from Google, and whether that copy is older
  # than it should be (Google did not answer the last time we asked).
  def freshness
    Feed.new.freshness
  end
end
