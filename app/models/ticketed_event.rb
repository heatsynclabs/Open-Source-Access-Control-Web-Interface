# One class or workshop sold on guestlist.co, the lab's ticketing site, with
# its sign-ups, check-ins and money collected. Built off the server from the
# organizer account and checked against the lab calendar, so events that
# were cancelled, never published or had no sign-ups are marked and left
# out of the counts. Loaded with script/ticketed_events.rb; nothing here
# names a person.
class TicketedEvent < ActiveRecord::Base
  STATUSES = ["held", "no sign-ups", "cancelled", "never published", "duplicate", "upcoming"].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :held, -> { where(status: "held") }

  # Deploys do not run migrations; until the table exists the analytics page
  # leaves the section out.
  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
