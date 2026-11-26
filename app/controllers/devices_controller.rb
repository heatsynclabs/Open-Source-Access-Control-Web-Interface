# Devices at the lab that the members site can drive. One for now, the LED
# marquee in the front window; each device gets a tile here and its own page.
class DevicesController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :use, :marquee
  end
end
