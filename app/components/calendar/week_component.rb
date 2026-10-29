module Calendar
  # "This week at the lab": the next seven days, one row (or column, when the
  # card is wide) per day. Open hours show as a line under the day instead of
  # an event, so the events stand out. Drop it into any page through the
  # calendar/week_frame partial, which loads it without holding up the page.
  class WeekComponent < ViewComponent::Base
    include CalendarHelper

    def initialize(days:, events:)
      @days = days
      @events = events
    end

    def events_on(day)
      @events.select { |event| event.day == day && event.category.key != "open" }
    end

    def open_hours_on(day)
      @events.select { |event| event.day == day && event.category.key == "open" }
    end

    def nothing_on?(day)
      events_on(day).empty? && open_hours_on(day).empty?
    end
  end
end
