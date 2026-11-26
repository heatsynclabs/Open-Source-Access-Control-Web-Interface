require "net/http"

module LabCalendar
  # Downloads the public ICS feed. A fresh copy is kept for 15 minutes; the
  # last good copy is kept for a week, so if Google does not answer the
  # calendar still shows what it knew, with a note saying how old it is.
  class Feed
    URL = ENV.fetch("GOOGLE_CALENDAR_ICS_URL",
      "https://calendar.google.com/calendar/ical/heatsynclabs.org_p9rcn09d64q56m7rg07jptmrqc%40group.calendar.google.com/public/basic.ics")
    FRESH_FOR = 15.minutes
    KEEP_FOR = 7.days
    FRESH_KEY = "lab_calendar/feed/fresh"
    LAST_GOOD_KEY = "lab_calendar/feed/last_good"

    def text
      Rails.cache.read(FRESH_KEY) || refresh
    end

    # { fetched_at: Time, stale: true/false }, or nil before the first fetch.
    def freshness
      last_good = Rails.cache.read(LAST_GOOD_KEY)
      return unless last_good
      { fetched_at: last_good[:fetched_at], stale: !Rails.cache.exist?(FRESH_KEY) }
    end

    private

    def refresh
      body = download
      Rails.cache.write(FRESH_KEY, body, expires_in: FRESH_FOR)
      Rails.cache.write(LAST_GOOD_KEY, { body: body, fetched_at: Time.zone.now }, expires_in: KEEP_FOR)
      body
    rescue StandardError => error
      Rails.logger.warn("LabCalendar::Feed: #{error.class}: #{error.message}")
      last_good = Rails.cache.read(LAST_GOOD_KEY)
      raise Unavailable, "the lab calendar could not be read" unless last_good
      last_good[:body]
    end

    def download
      uri = URI(URL)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.request_uri)
      end
      # Google answers the public feed with a redirect now and then.
      response = Net::HTTP.get_response(URI(response["location"])) if response.is_a?(Net::HTTPRedirection)
      raise Unavailable, "the calendar feed answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      raise Unavailable, "the calendar feed is not a calendar" unless response.body.include?("BEGIN:VCALENDAR")
      response.body.force_encoding(Encoding::UTF_8)
    end
  end
end
