class Certification < ActiveRecord::Base
  has_many :user_certifications
  has_many :users, :through => :user_certifications

  validates_presence_of :name, :slug
end
