class MacLogsController < ApplicationController
load_and_authorize_resource :mac_log
before_action :authenticate_user!

def index
  @mac_logs = MacLog.desc.limit(1000)
  # one lookup for all macs instead of a query per log row; the view
  # handles macs that have no Mac record (nil)
  @macs = {}
  Mac.where(:mac => @mac_logs.map(&:mac).uniq).includes(:user).each do |m|
    @macs[m.mac] ||= m
  end
end

  private

  def mac_log_params
    params.require(:mac_log).permit(:action, :ip, :mac)
  end
end
