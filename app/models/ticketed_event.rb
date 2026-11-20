# One class or workshop sold on guestlist.co, the lab's ticketing site, with
# its sign-ups, check-ins and money collected. Nothing here names a person.
#
# The rows come from two places (docs/analytics.md):
# - the organizer export: every event the lab ever put on guestlist, read by
#   hand while signed in to the organizer account and loaded with
#   script/ticketed_events.rb. Its money figure is what guestlist collected.
# - the nightly check (Guestlist::Sync): guestlist's public pages, for new
#   events and for events in the last REFRESH_FOR. Its money figure is
#   ticket price times tickets.
#
# Events that were cancelled, never published or had no sign-ups are kept
# with that status and left out of the counts.
class TicketedEvent < ActiveRecord::Base
  STATUSES = ["held", "no sign-ups", "cancelled", "never published", "duplicate", "upcoming"].freeze
  SOURCES = ["organizer export", "public pages"].freeze
  CANCELLED = /cancel|postpon|resched/i
  # Ticket types that are money, not a person ("Optional donation").
  DONATION = /donat|tip jar|contribut|sponsor/i
  # Title-only keyword kinds, first match wins. Approximate by design; the
  # operations data scripts (data/scripts/guestlist.py) use the same list.
  KINDS = {
    "Laser" => /laser|engrav/i,
    "3D printing" => /3d|resin print|printer|printing|slic|tinkercad|fusion/i,
    "Metal and wood shop" => /weld|\bmig\b|\btig\b|lathe|mill|cnc|shopbot|wood|metal|plasma|forg|blacksmith|router|silversmith|chainmaille/i,
    "Electronics" => /solder|electron|arduino|circuit|robot|\bbot\b|raspberry|\bpi\b|\bled\b|esp32|microcontroll|radio|antenna|\bham\b|contact mic/i,
    "Crafts and textiles" => /sew|embroid|sublimat|vinyl|textil|cricut|jewel|earring|pendant|kumihimo|knit|crochet|leather|craft|paint|flower|candle|soap|stamp|sock|tie.?d[iy]e|skirt|stuffed|sculpt|glass|nail|card making|bead|lanyard|tombstone|haunt|doll|outhouse|wire skeleton|airplane/i,
    "Kids and family" => /young maker|\bkid|family|lego|graham|teen|scout|beginners day|mother/i,
    "Design software" => /inkscape|blender|projection|logo|photograph/i,
    "Orientation and open hours" => /orientation|open hours/i,
    "Talks, games and social" => /talk|meetup|game|murder|mystery|party|social|lecture|movie|detective|lunch and learn|patent|business|chemistry|adventure/i,
  }.freeze

  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }

  scope :held, -> { where(status: "held") }

  # Deploys do not run migrations; until the table exists the analytics page
  # leaves the classes section out.
  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def self.kind_for(name)
    KINDS.find { |_kind, pattern| name.match?(pattern) }&.first || "Other"
  end

  # The status of an event from what guestlist and the lab calendar say:
  # cancelled when the name says so, or when every calendar entry linking it
  # is titled cancelled.
  def self.status_for(name:, published:, starts_at:, tickets:, calendar_titles: [], now: Time.current)
    return "never published" unless published
    return "cancelled" if name.match?(CANCELLED) || (calendar_titles.any? && calendar_titles.all? { |title| title.match?(CANCELLED) })
    return "upcoming" if starts_at > now
    tickets.positive? ? "held" : "no sign-ups"
  end

  # Row attributes from guestlist's event JSON and its ticket types. dollars
  # is guestlist's collected figure when given (organizer export), otherwise
  # ticket price times tickets.
  def self.attributes_from(event, ticket_types, source:, collected_at:, calendar_titles: [], dollars: nil, now: Time.current)
    count = ->(type) { (type["complete_tickets_count"] || type["tickets_sold"]).to_i }
    tickets = event["complete_tickets_count"].to_i
    donations = ticket_types.select { |type| type["name"].to_s.match?(DONATION) }.sum(&count)
    starts_at = Time.zone.parse(event.fetch("start"))
    name = event.fetch("name").squish
    {
      guestlist_id: Integer(event.fetch("id")), name: name, held_on: starts_at.to_date, kind: kind_for(name),
      status: status_for(name: name, published: event["published_at"].present?, starts_at: starts_at, tickets: tickets,
                         calendar_titles: calendar_titles, now: now),
      attendees: tickets - donations, checked_in: event["check_ins_count"].to_i,
      dollars: dollars || ticket_types.sum { |type| type["price"].to_d * count.call(type) },
      source: source, collected_at: collected_at,
    }
  end

  # When the numbers were last read, from each source: { "organizer export" => Time, "public pages" => Time }.
  def self.collected
    group(:source).maximum(:collected_at).compact
  end
end
