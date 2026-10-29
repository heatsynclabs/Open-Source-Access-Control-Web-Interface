module Calendar
  # "This week at the lab": the next seven days in a compact list, one line
  # per event, with open hours as a short note on the day. Days with nothing
  # on are left out (today always shows). Drop it into any page through the
  # calendar/week_frame partial, which loads it without holding up the page.
  class WeekComponent < ViewComponent::Base
    include CalendarHelper

    def initialize(days:, events:)
      @days = days
      @events = events
    end

    def shown_days
      @days.select { |day| day == Date.current || events_on(day).any? || open_hours_on(day).any? }
    end

    def events_on(day)
      @events.select { |event| event.day == day && !event.open_hours? }
    end

    def open_hours_on(day)
      @events.select { |event| event.day == day && event.open_hours? }
    end

    def listed_events
      @events.reject { |event| event.open_hours? }.uniq
    end
  end
end
