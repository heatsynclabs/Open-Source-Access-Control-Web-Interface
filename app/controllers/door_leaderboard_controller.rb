# Who opens and locks up the lab, for oriented members and cardholders.
# Reads the door log through DoorActivity; names are shortened and hidden
# members are left out.
class DoorLeaderboardController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :door_activity
    @window = DoorActivity.window(params[:window])
    activity = DoorActivity.new
    @opened = activity.opened_the_lab(@window, stats: activity.cached_stats(:opening, @window))
    @days = activity.days_at_the_lab(@window, stats: activity.cached_stats(:days, @window))
  end
end
