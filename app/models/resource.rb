class Resource < ActiveRecord::Base
  belongs_to :owner, :class_name => "ToolshareUser" #TODO: remove owner
  belongs_to :user
  belongs_to :resource_category

  PICTURE_OPTIONS = { :styles => { :medium => "300x300>",
                                   :thumb => "100x100>",
                                   :tiny => "50x50>"},
                      :storage => :s3,
                      :s3_protocol => :https,
                      :s3_credentials => { :access_key_id     => ENV['S3_KEY'],
                                         :secret_access_key => ENV['S3_SECRET'] },
                      :path => ":attachment/:id/:style.:extension",
                      :bucket => ENV['S3_BUCKET'] }

  has_attached_file :picture, PICTURE_OPTIONS
  has_attached_file :picture2, PICTURE_OPTIONS
  has_attached_file :picture3, PICTURE_OPTIONS
  has_attached_file :picture4, PICTURE_OPTIONS

  def resource_category_name
    resource_category.name if resource_category
  end
end
