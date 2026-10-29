module Calendar
  # One event on the calendar. style: :pill in the month grid, :line in the
  # this-week card (time and title on one line), :row in the week and list
  # views (icon, title, then time). Clicking opens its details in a dialog;
  # each page renders those once with Calendar::EventDialogComponent.
  class EventComponent < ViewComponent::Base
    include CalendarHelper

    def initialize(event:, style: :row)
      @event = event
      @style = style
    end

    def self.dialog_id(event)
      "event-#{Digest::MD5.hexdigest(event.id)[0, 10]}"
    end

    def dialog_id
      self.class.dialog_id(@event)
    end
  end
end
