# The lab calendar, open to everyone. Events come from the public Google
# Calendar feed (LabCalendar); nothing here touches the database.
class CalendarController < ApplicationController
  VIEWS = %w[month week list].freeze
  LIST_DAYS = 30
  # How far the earlier and later buttons move each view.
  STEPS = { "month" => 1.month, "week" => 1.week, "list" => LIST_DAYS.days }.freeze

  def index
    @view = VIEWS.include?(params[:view]) ? params[:view] : "month"
    @date = selected_date
    @step = STEPS[@view]
    @category = LabCalendar::Category.find(params[:cat])
    @show_open_hours = params[:open] == "1" || @category&.key == "open"
    @events = visible(LabCalendar.between(range_for(@view, @date)))
    @freshness = LabCalendar.freshness
  rescue LabCalendar::Unavailable
    @events = []
    @unavailable = true
  end

  # The "this week" card that other pages load into a Turbo Frame.
  def week
    @days = Date.current..(Date.current + 6)
    @events = LabCalendar.between(@days)
    render layout: false
  rescue LabCalendar::Unavailable
    @events = nil
    render layout: false
  end

  private

  def selected_date
    Date.iso8601(params[:start_date].to_s)
  rescue Date::Error
    Date.current
  end

  # The days a view shows. The month grid includes the days of the first
  # and last weeks that spill into the neighbouring months.
  def range_for(view, date)
    case view
    when "month" then date.beginning_of_month.beginning_of_week..date.end_of_month.end_of_week
    when "week" then date.beginning_of_week..date.end_of_week
    else date..(date + LIST_DAYS)
    end
  end

  def visible(events)
    events = events.reject { |event| event.open_hours? } unless @show_open_hours
    events = events.select { |event| event.category == @category } if @category
    events
  end
end
