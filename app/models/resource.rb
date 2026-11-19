class Resource < ActiveRecord::Base
  belongs_to :owner, :class_name => "ToolshareUser" #TODO: remove owner
  belongs_to :user
  belongs_to :resource_category

  # Tool photos: public, served through ResourcesController#photo.
  PICTURES = %i[picture picture2 picture3 picture4].freeze
  PICTURE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  PICTURE_OPTIONS = FileStorage.options(bucket: FileStorage.photos_bucket, private_files: false).merge(
    :styles => { :medium => "300x300>", :thumb => "100x100>", :tiny => "50x50>" }
  )

  has_attached_file :picture, PICTURE_OPTIONS
  has_attached_file :picture2, PICTURE_OPTIONS
  has_attached_file :picture3, PICTURE_OPTIONS
  has_attached_file :picture4, PICTURE_OPTIONS
  PICTURES.each do |name|
    validates_attachment_content_type name, :content_type => PICTURE_TYPES
    validates_attachment_size name, :less_than => 15.megabytes
  end

  def resource_category_name
    resource_category.name if resource_category
  end
end
