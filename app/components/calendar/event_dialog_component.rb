module Calendar
  # The details of one event: when, where, how to sign up, and the
  # description, in a native <dialog>.
  class EventDialogComponent < ViewComponent::Base
    include CalendarHelper

    # Google's description editor allows these; anything else is removed.
    DESCRIPTION_TAGS = %w[a b strong i em u br p ul ol li].freeze

    # Render once per page for all its events:
    #   render Calendar::EventDialogComponent.with_collection(events.uniq)
    with_collection_parameter :event

    def initialize(event:)
      @event = event
      @id = EventComponent.dialog_id(event)
    end

    def when_text
      date = @event.starts_at.strftime("%A, %B %-d, %Y")
      return "#{date} to #{@event.last_day.strftime('%A, %B %-d')}" if @event.multi_day? && @event.all_day
      "#{date}, #{event_time_range(@event)}"
    end

    def description_html
      helpers.sanitize(@event.description.gsub("\n", "<br>"), tags: DESCRIPTION_TAGS, attributes: %w[href])
    end
  end
end
