class Mac < ActiveRecord::Base
  belongs_to :user

  validates_uniqueness_of :mac, :case_sensitive => false
end
