module Guestlist
  # The nightly check (bin/rails guestlist:sync): reads guestlist's public
  # pages for every event that is new or recent, so the analytics page keeps
  # up without the organizer export. An event is read while it is upcoming
  # and for REFRESH_FOR after it, so late check-ins and refunds are caught;
  # after that its numbers stay as last read.
  #
  # Events come from guestlist's list of upcoming events, from guestlist
  # links on the lab calendar, and from the table itself. An upcoming event
  # that guestlist no longer has was taken down, and is marked cancelled.
  class Sync
    REFRESH_FOR = 45.days

    def initialize(client: Client.new, now: Time.current)
      @client = client
      @now = now
    end

    # { read:, skipped:, failed:, taken_down: } for the task's log line.
    def run
      tally = Hash.new(0)
      calendar = calendar_titles
      ids = (@client.upcoming_event_ids | calendar.keys | recent_ids).sort
      ids.each { |id| tally[refresh(id, calendar.fetch(id, []))] += 1 }
      Rails.cache.delete_matched("analytics") rescue nil
      tally
    end

    private

    def since
      (@now - REFRESH_FOR).to_date
    end

    def recent_ids
      TicketedEvent.where(held_on: since..).or(TicketedEvent.where(status: "upcoming")).pluck(:guestlist_id)
    end

    # { guestlist id => [titles of the calendar entries linking it] } for
    # calendar events from REFRESH_FOR ago on. Without the calendar, guestlist
    # alone decides.
    def calendar_titles
      LabCalendar.between(since..LabCalendar::LOOKAHEAD.from_now.to_date).each_with_object(Hash.new { |h, k| h[k] = [] }) do |event, links|
        event.description.scan(LINK).flatten.uniq.each { |id| links[Integer(id)] << event.title }
      end
    rescue LabCalendar::Unavailable
      {}
    end

    def refresh(id, titles)
      event = @client.event(id)
      return taken_down(id) unless event
      return :skipped unless event["profile_id"] == PROFILE_ID
      attributes = TicketedEvent.attributes_from(event, @client.ticket_types(id), source: "public pages", collected_at: @now,
                                                 calendar_titles: titles, now: @now)
      TicketedEvent.upsert(attributes, unique_by: :guestlist_id)
      :read
    rescue Client::Error => error
      Rails.logger.warn("Guestlist::Sync #{id}: #{error.message}")
      :failed
    end

    def taken_down(id)
      TicketedEvent.where(guestlist_id: id, status: "upcoming").update_all(status: "cancelled", collected_at: @now, updated_at: @now)
      :taken_down
    end
  end
end
