require "icalendar/recurrence"

module LabCalendar
  # Turns the ICS text into one Event per occurrence. icalendar parses the
  # feed and icalendar-recurrence expands each repeating series (RRULE,
  # EXDATE). Two things are left to us:
  #
  # - Edited occurrences. When one date of a series is changed in Google,
  #   the feed carries a separate VEVENT with the series' UID and a
  #   RECURRENCE-ID naming the date it replaces. We drop that date from the
  #   series and use the edited copy instead.
  # - Cancelled events (STATUS:CANCELLED), which are dropped.
  class Occurrences
    def initialize(ics_text)
      @calendar = Icalendar::Calendar.parse(ics_text).first
    end

    def between(from, to)
      overrides = edited_occurrences
      events = series.flat_map do |vevent|
        replaced = overrides.fetch(uid_of(vevent), []).map { |edit| occurrence_key(edit.recurrence_id) }
        occurrences_of(vevent, from, to).reject { |start, _end| replaced.include?(occurrence_key(start)) }
          .map { |start, finish| build(vevent, start, finish) }
      end
      events += overrides.values.flatten.filter_map do |edit|
        build(edit, edit.dtstart, edit.dtend) if edit.dtstart.to_time.between?(from, to)
      end
      events.reject(&:nil?).sort_by(&:starts_at)
    end

    private

    def series
      @calendar.events.reject(&:recurrence_id)
    end

    def edited_occurrences
      @calendar.events.select(&:recurrence_id).group_by { |vevent| uid_of(vevent) }
    end

    # [[start, end], ...] for every time this VEVENT happens inside the window.
    def occurrences_of(vevent, from, to)
      if vevent.rrule.empty?
        start = vevent.dtstart.to_time
        start.between?(from, to) ? [[vevent.dtstart, vevent.dtend]] : []
      else
        vevent.occurrences_between(from, to).map { |occurrence| [occurrence.start_time, occurrence.end_time] }
      end
    end

    def build(vevent, start, finish)
      return if vevent.status.to_s.upcase == "CANCELLED"
      all_day = vevent.dtstart.is_a?(Icalendar::Values::Date)
      starts_at = all_day ? start.to_date.in_time_zone : start.in_time_zone
      ends_at = finish ? (all_day ? finish.to_date.in_time_zone : finish.in_time_zone) : starts_at
      Event.from_ics(
        uid: uid_of(vevent),
        summary: vevent.summary.to_s,
        description: vevent.description.to_s,
        location: vevent.location.to_s,
        starts_at: starts_at,
        ends_at: ends_at,
        all_day: all_day,
        repeating: vevent.rrule.any? || vevent.recurrence_id.present?
      )
    end

    # Identifies one occurrence of a series: its day for all-day events, its
    # exact start otherwise. Lets an edited copy find the date it replaces.
    def occurrence_key(value)
      value.is_a?(Date) && !value.respond_to?(:hour) ? value.to_date : value.to_time.to_i
    end

    def uid_of(vevent)
      vevent.uid.to_s
    end
  end
end
