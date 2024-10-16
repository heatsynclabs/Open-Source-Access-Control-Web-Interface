class MacLog < ActiveRecord::Base
  scope :desc, order("mac_logs.created_at DESC")
end
