class Contract < ActiveRecord::Base
  # The lab's online waiver (a Google Form). Signing it does not add a record
  # here; a volunteer records it, as with a paper waiver.
  ONLINE_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSdg59iLo5rDZL7f3GvHIVXVu_32vqjwYCCfuRvyMTK1P5RGhg/viewform"

  belongs_to :user
  belongs_to :created_by, :foreign_key => "created_by_id", :class_name => "User"

  validates_presence_of :first_name, :signed_at #, :last_name

  has_attached_file :document,
                    { :styles =>
                      {
                        :medium => "300x300>",
                        :large => "900x900>"
                      },
                      :storage => :s3,
                      :s3_protocol => :https,
                      :s3_credentials => { :access_key_id     => ENV['S3_KEY'],
                                         :secret_access_key => ENV['S3_SECRET'] },
                      :path => ":attachment/:id/:style.:extension",
                      :bucket => ENV['S3_BUCKET']
                    }
end
