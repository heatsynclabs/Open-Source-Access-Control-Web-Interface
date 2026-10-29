# Formatting for calendar events, in the lab's style: "7pm", "6:30 to 9pm".
module CalendarHelper
  # Events shown in one month-grid day before "N more".
  DAY_CELL_EVENTS = 4

  def event_clock(time)
    format = time.min.zero? ? "%-l%P" : "%-l:%M%P"
    time.strftime(format)
  end

  def event_time_range(event)
    return "All day" if event.all_day
    return event_clock(event.starts_at) if event.ends_at <= event.starts_at
    # Overnight and multi-day events name the day they end on.
    if event.ends_at.to_date > event.starts_at.to_date && event.ends_at.hour >= 6
      return "#{event_clock(event.starts_at)} to #{event.ends_at.strftime('%a')} #{event_clock(event.ends_at)}"
    end
    start = event_clock(event.starts_at)
    finish = event_clock(event.ends_at)
    # "6 to 9pm" when both ends are in the evening, "11am to 2pm" otherwise.
    start = start.delete_suffix(event.starts_at.strftime("%P")) if event.starts_at.strftime("%P") == event.ends_at.strftime("%P")
    "#{start} to #{finish}"
  end

  def event_day_label(day)
    return "Today" if day == Date.current
    return "Tomorrow" if day == Date.current + 1
    day.strftime("%A")
  end

  # The calendar page URL with one setting changed, keeping the others.
  def calendar_link_params(changes)
    params.permit(:view, :start_date, :cat, :open).to_h.merge(changes.stringify_keys).compact_blank
  end
end
