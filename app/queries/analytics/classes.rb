module Analytics
  # Classes and workshops sold on guestlist.co (TicketedEvent). Only events
  # that went ahead with sign-ups count; cancelled ones, drafts and events
  # nobody signed up for are counted apart so the page can say how many
  # were left out.
  class Classes
    def initialize(period)
      @period = period
    end

    def events_count
      held.count
    end

    def attendees_total
      held.sum(:attendees)
    end

    # Share of sign-ups who came, over the events where someone checked
    # people in at the door (most events did not), or nil if none did.
    def show_up
      attendees, came = held.where("checked_in > 0").pick(Arel.sql("SUM(attendees)"), Arel.sql("SUM(checked_in)"))
      return nil unless attendees.to_i.positive?
      { rate: (came.to_f / attendees).round(2), events: held.where("checked_in > 0").count }
    end

    def attendees_by_period
      held.group_by_period(@period.unit, :held_on, range: @period.dates).sum(:attendees)
    end

    def events_by_period
      held.group_by_period(@period.unit, :held_on, range: @period.dates).count
    end

    def by_kind
      held.group(:kind).sum(:attendees).sort_by { |_kind, people| -people }.to_h
    end

    # The best attended events: [[name, attendees], ...].
    def top_events(limit = 10)
      held.order(attendees: :desc, held_on: :desc).limit(limit).pluck(:name, :attendees)
    end

    # { "cancelled" => 2, "no sign-ups" => 5 }: events in the period that are
    # not counted above.
    def left_out
      TicketedEvent.where(held_on: @period.dates, status: ["cancelled", "no sign-ups"]).group(:status).count
    end

    def dollars_total
      held.sum(:dollars).to_f
    end

    def dollars_by_period
      held.group_by_period(@period.unit, :held_on, range: @period.dates).sum(:dollars).transform_values(&:to_f)
    end

    # When the guestlist data was last loaded.
    def loaded_on
      TicketedEvent.maximum(:updated_at)&.to_date
    end

    private

    def held
      TicketedEvent.held.where(held_on: @period.dates)
    end
  end
end
