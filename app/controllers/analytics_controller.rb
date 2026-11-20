# Aggregate charts for signed-in members: members, door use, the calendar
# and class sign-ups, plus dues and class money for the treasurer and
# admins. Counts only; nothing on this page names a person.
#
# The page has one tab per source (section) and "All". The page itself is
# only the header, tabs and period buttons, so it shows at once; the numbers
# load into it from #section (a Turbo Frame), which works out only the
# sections the tab shows. The first view after the cache expires can take a
# few seconds, and the frame shows a placeholder meanwhile.
class AnalyticsController < ApplicationController
  before_action :authenticate_user!

  CACHE_FOR = 10.minutes
  SECTIONS = {
    "all" => "All", "door" => "Lab use", "calendar" => "Calendar", "classes" => "Classes",
    "members" => "Members", "dues" => "Dues",
  }.freeze

  before_action :choose_section

  def index
  end

  def section
    all = @section == "all"

    @members = cached(:members) { members_section(Analytics::Members.new(@period)) } if all || @section == "members"
    @door = cached(:door) { door_section(Analytics::Door.new(@period)) } if all || @section.in?(%w[door calendar])
    @calendar = calendar_section if all || @section.in?(%w[door calendar])
    classes_sections if (all || @section == "classes") && TicketedEvent.available?
    @payments = cached(:payments) { payments_section(Analytics::Payments.new(@period)) } if (all || @section == "dues") && @sections.key?("dues")
    @overview = overview if all
    render layout: false
  end

  private

  def choose_section
    @period = Analytics::Period.new(params[:period])
    @sections = SECTIONS.reject { |key, _label| key == "dues" && !can?(:manage, Payment) }
    @section = @sections.key?(params[:section]) ? params[:section] : "all"
  end

  def cached(section, &block)
    Rails.cache.fetch(["analytics", section, @period.key], expires_in: CACHE_FOR, &block)
  end

  def members_section(members)
    {
      paid_up: members.paid_up_count, active: members.active_count,
      cardholders: members.cardholder_count,
      signups: members.signups, orientations: members.orientations, waivers: members.waivers_signed,
      certifications: members.certifications_granted, level_mix: members.level_mix,
      top_certifications: members.top_certifications, funnel: members.funnel,
    }
  end

  def payments_section(payments)
    {
      total: payments.dues_total, average: payments.average_payment,
      dues: payments.dues_by_period, payers: payments.payers_by_period,
      tiers: payments.tier_mix, methods: payments.methods, paypal_waiting: payments.paypal_waiting_count,
    }
  end

  def door_section(door)
    {
      entries: door.entries_total,
      entries_by_period: door.entries_by_period,
      cards_by_period: door.distinct_cards_by_period, by_day: door.entries_by_day,
      grid: door.weekday_hour_grid, remote: door.remote_by_source,
    }
  end

  def classes_sections
    classes = Analytics::Classes.new(@period)
    @classes = cached(:classes) { classes_section(classes) }
    @classes_detail = cached(:classes_detail) { { by_year: classes.by_year, events: classes.events.to_a } } if @section == "classes"
    return unless can?(:manage, Payment)
    @class_money = cached(:class_money) { { total: classes.dollars_total, by_period: classes.dollars_by_period } }
  end

  def classes_section(classes)
    {
      events: classes.events_count, attendees: classes.attendees_total, show_up: classes.show_up,
      by_period: classes.attendees_by_period, by_kind: classes.by_kind, top: classes.top_events,
      left_out: classes.left_out, collected: classes.collected,
    }
  end

  # The lines of the Everything together chart: the four main ones shown at
  # first, the rest a click away in the legend; money only for those who
  # can see dues.
  def overview
    calendar_counts = @calendar && @calendar[:series].each_with_object(Hash.new(0)) do |series, totals|
      series[:data].each { |bucket, count| totals[bucket] += count }
    end
    lines = [
      ["Card swipes", @door[:entries_by_period], true],
      ["Cardholders who came in", @door[:cards_by_period], true],
      ["Calendar events", calendar_counts, true],
      ["Class sign-ups", @classes&.dig(:by_period), true],
      ["New accounts", @members[:signups], false],
      ["Tool sign-offs", @members[:certifications], false],
    ]
    lines += [["People paying dues", @payments[:payers], false], ["Dues recorded", @payments[:dues], false, "$"]] if @payments
    Analytics::Overview.new(@period, lines)
  end

  # The calendar section reads the Google feed. If that is down the rest of
  # the page still shows.
  def calendar_section
    cached(:calendar) do
      calendar = Analytics::Calendar.new(@period)
      {
        total: calendar.total, hyh: calendar.hack_your_hackerspace_count, classes: calendar.classes_count,
        series: calendar.by_category_series,
        weekdays: calendar.by_weekday, top: calendar.top_series,
        door_on_event_days: calendar.door_entries_on_event_days(@door[:by_day]),
      }
    end
  rescue LabCalendar::Unavailable
    nil
  end
end
