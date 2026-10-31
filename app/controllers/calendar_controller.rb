# The lab calendar, open to everyone.
#
# The calendar page (#index) embeds the lab's public calendar from
# heatsynclabs.org so members see the one calendar the rest of the lab uses,
# rather than a second copy that can drift out of step with it. The embed
# needs no server data; the view points an iframe at LabCalendar::PUBLIC_URL.
#
# The home-page "this week" card (#week) still builds from the Google feed
# (LabCalendar), as does the analytics calendar section, so nothing there
# depends on the embedded page being reachable.
class CalendarController < ApplicationController
  def index
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
end
