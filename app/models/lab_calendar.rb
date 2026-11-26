# The lab's public Google Calendar, read from its ICS feed.
#
#   LabCalendar.between(Time.zone.today.all_week)   # events starting this week
#
# The feed is fetched at most every 15 minutes (LabCalendar::Feed), and the
# repeating events in it are expanded once per version of the feed
# (LabCalendar::Occurrences), so pages only filter an array in memory.
module LabCalendar
  # Expanded events reach back far enough for the analytics page's
  # "all time", and a year ahead for the calendar page.
  # The lab's public calendar page; the members site links people there (new
  # tab) to see the calendar in its full site context.
  PUBLIC_URL = "https://www.heatsynclabs.org/calendar/"
  # The same calendar with no site chrome, built for framing. The members
  # /calendar page embeds this so members stay in the members site and see the
  # one calendar the lab uses, never a second copy. Overridable for local dev.
  EMBED_URL = ENV.fetch("CALENDAR_EMBED_URL", "https://www.heatsynclabs.org/calendar/embed/")
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

  # Each server process keeps the expanded list for a minute, so a page does
  # not reload thousands of events from the cache on every request.
  MEMO_FOR = 1.minute
  MEMO_LOCK = Mutex.new

  def events
    MEMO_LOCK.synchronize do
      @memo = nil if @memo && @memo[:until] < Time.current
      @memo ||= { events: expanded_events, until: MEMO_FOR.from_now }
      @memo[:events]
    end
  end

  # Expanded once per version of the feed.
  def expanded_events(text = Feed.new.text)
    Rails.cache.fetch(events_cache_key(text), expires_in: 1.day) do
      Occurrences.new(text).between(HISTORY_START.in_time_zone, LOOKAHEAD.from_now)
    end
  end

  # When the Open Hours event running at `at` ends, or nil when none is.
  # The space API adds it as "open_until" so the window sign can say UNTIL
  # 9 PM. Uses only what is already cached (the calendar pages and the home
  # week card keep it current) so the door status never waits, and never
  # raises: a calendar problem must not break what everything else reads.
  def open_hours_until(at = Time.current)
    text = Feed.new.cached_text
    return nil unless text
    Rails.cache.fetch("lab_calendar/open_hours_until/#{at.to_i / 60}", expires_in: 2.minutes) do
      # Only a list some page already expanded; expanding here could take
      # seconds after the feed changes.
      expanded = Rails.cache.read(events_cache_key(text)) || []
      event = expanded.find do |e|
        !e.all_day && e.open_hours? && e.starts_at <= at && e.ends_at > at
      end
      event&.ends_at&.in_time_zone
    end
  rescue StandardError => e
    Rails.logger.warn "open_hours_until: #{e.class}: #{e.message}"
    nil
  end

  def events_cache_key(text)
    ["lab_calendar/events/v2", Digest::SHA256.hexdigest(text)]
  end

  # When the feed was last read from Google, and whether that copy is older
  # than it should be (Google did not answer the last time we asked).
  def freshness
    Feed.new.freshness
  end
end
