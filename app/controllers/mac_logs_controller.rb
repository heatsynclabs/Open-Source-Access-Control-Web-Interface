class MacLogsController < ApplicationController
load_and_authorize_resource :mac_log
before_filter :authenticate_user!

def index
  @mac_logs = MacLog.desc.limit(1000)
  @macs = {}
  @mac_logs.each do |log|
    @macs.merge!({log.mac => Mac.find_by_mac(log.mac)})
  end
end

  private

  def mac_log_params
    params.require(:mac_log).permit(:action, :ip, :mac)
  end
end
