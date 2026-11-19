class Contract < ActiveRecord::Base
  # The lab's online waiver (a Google Form). Signing it does not add a record
  # here; a volunteer records it, as with a paper waiver.
  ONLINE_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSdg59iLo5rDZL7f3GvHIVXVu_32vqjwYCCfuRvyMTK1P5RGhg/viewform"

  belongs_to :user
  belongs_to :created_by, :foreign_key => "created_by_id", :class_name => "User"

  validates_presence_of :first_name, :signed_at #, :last_name

  # Signed waivers: personal data. Private in the store, served only through
  # ContractsController#document (admins). Kept in the store when a record is
  # deleted (preserve_files): deleting a waiver is a Board decision.
  DOCUMENT_TYPES = %w[application/pdf image/jpeg image/png].freeze
  IMAGE_STYLES = { :medium => "300x300>", :large => "900x900>" }.freeze

  has_attached_file :document,
                    FileStorage.options(bucket: FileStorage.documents_bucket, private_files: true).merge(
                      # Previews only for scans; a PDF is served as it was uploaded.
                      :styles => ->(a) { a.instance.document_content_type.to_s.start_with?('image/') ? IMAGE_STYLES : {} },
                      :preserve_files => true
                    )
  validates_attachment_content_type :document, :content_type => DOCUMENT_TYPES
  validates_attachment_size :document, :less_than => 20.megabytes
end
