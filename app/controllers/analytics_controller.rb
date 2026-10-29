# Aggregate charts for anyone, signed in or not: members, door use and the
# calendar, plus dues for the treasurer and admins. Counts only; nothing on
# this page names a person.
class AnalyticsController < ApplicationController

  CACHE_FOR = 10.minutes

  def index
    @period = Analytics::Period.new(params[:period])
    @members = cached(:members) { members_section(Analytics::Members.new(@period)) }
    @payments = cached(:payments) { payments_section(Analytics::Payments.new(@period)) } if can?(:manage, Payment)
    @door = cached(:door) { door_section(Analytics::Door.new(@period)) }
    @calendar = calendar_section
  end

  private

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
      entries_by_period: door.entries_by_period, denied_by_period: door.denied_by_period,
      cards_by_period: door.distinct_cards_by_period, by_day: door.entries_by_day,
      grid: door.weekday_hour_grid, remote: door.remote_by_source,
    }
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
