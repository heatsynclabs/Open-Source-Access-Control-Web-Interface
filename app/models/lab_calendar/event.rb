module LabCalendar
  # One occurrence of a calendar event, cleaned up for display the same way
  # heatsynclabs.org does it (new-hsl src/services/calendarService.ts): the
  # "(registration required)" note comes off the title, and the sign-up link
  # and price are pulled out of the description.
  class Event < Data.define(:id, :title, :description, :location, :starts_at, :ends_at, :all_day, :repeating)
    REGISTRATION_NOTE = /[\s\u00b7\u2022|,\u2013\u2014-]*\(?registration required\)?[\s\u00b7\u2022|,\u2013\u2014-]*/i
    GUESTLIST_URL = %r{https?://guestli(?:\.st|st\.co)/[^\s<>"')]+}i
    SIGNUP_URL = /guestli|eventbrite|meetup\.com|lu\.ma|luma\.com|tickettailor|ti\.to|humanitix|forms\.gle|docs\.google\.com\/forms|signup|sign-up|register|rsvp|ticket/i
    PRICE = /\$\d+(?:\.\d{2})?/

    def self.from_ics(uid:, summary:, description:, location:, starts_at:, ends_at:, all_day:, repeating:)
      new(id: "#{uid}@#{starts_at.to_i}", title: summary.presence || "Untitled event", description: description,
          location: location, starts_at: starts_at, ends_at: ends_at, all_day: all_day, repeating: repeating)
    end

    def display_title
      cleaned = title.gsub(REGISTRATION_NOTE, " ").gsub(/\(\s*\)/, "").squish
      cleaned.presence || title
    end

    def registration_required?
      title.match?(REGISTRATION_NOTE) || description.match?(GUESTLIST_URL)
    end

    # The sign-up page: a Guestlist link first, then any link that looks like
    # a registration page.
    def registration_url
      description[GUESTLIST_URL] || links.find { |url| url.match?(SIGNUP_URL) }
    end

    def cost
      plain_description[PRICE]
    end

    def links
      URI.extract(plain_description + " " + description.scan(/href="([^"]+)"/).join(" "), %w[http https])
        .map { |url| url.sub(/[.,;:!?)]+\z/, "") }.uniq
    end

    # The description as text, with HTML from Google's editor removed.
    def plain_description
      Rails::HTML5::FullSanitizer.new.sanitize(description.gsub(/<br\s*\/?>/i, "\n")).to_s
        .gsub("&nbsp;", " ").gsub("&amp;", "&").strip
    end

    def category
      Category.for(self)
    end

    def icon
      Category.icon_for(self)
    end

    def day
      starts_at.to_date
    end

    # The last calendar day the event covers. All-day events end at the next
    # midnight, and an evening event ending at midnight belongs to its own day.
    def last_day
      return day if ends_at <= starts_at
      [(ends_at - 1.second).to_date, day].max
    end

    def multi_day?
      last_day > day
    end

    # A link that opens Google Calendar's "add event" page with this event filled in.
    def add_to_google_url
      format = all_day ? "%Y%m%d" : "%Y%m%dT%H%M%SZ"
      dates = [starts_at, ends_at].map { |time| all_day ? time.strftime(format) : time.utc.strftime(format) }.join("/")
      query = { action: "TEMPLATE", text: display_title, dates: dates, location: location, details: plain_description.truncate(1500) }
      "https://calendar.google.com/calendar/render?#{query.to_query}"
    end
  end
end
