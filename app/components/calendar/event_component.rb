module Calendar
  # One event on the calendar: a compact pill in the month grid, or a row
  # with time and icon in the week and list views. Clicking opens its details
  # in a dialog (Calendar::EventDialogComponent).
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

    def pill?
      @style == :pill
    end
  end
end
