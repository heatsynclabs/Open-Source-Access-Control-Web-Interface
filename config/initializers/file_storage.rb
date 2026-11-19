# Where member files live and how Paperclip reaches them. All of it comes from
# environment variables, so moving from AWS S3 to the lab's own store (Garage on
# the R610) is a configuration change:
#
#   S3_BUCKET            tool photos, and waivers unless S3_DOCUMENTS_BUCKET is set
#   S3_DOCUMENTS_BUCKET  signed waivers: a private bucket (optional)
#   S3_KEY, S3_SECRET    the access key
#   S3_REGION            default us-east-1 (for Garage: s3_region in garage.toml)
#   S3_ENDPOINT          unset for AWS; for Garage e.g. http://members-files:3900
#
# Pages never link to the store. They link to routes in this app
# (ContractsController#document, ResourcesController#photo), which check who is
# asking and stream the file, so waivers stay private whatever the store does.
module FileStorage
  def self.options(bucket:, private_files:)
    opts = {
      storage: :s3,
      s3_protocol: :https,
      s3_credentials: { access_key_id: ENV['S3_KEY'], secret_access_key: ENV['S3_SECRET'] },
      s3_region: ENV['S3_REGION'].presence || 'us-east-1',
      path: ':attachment/:id/:style.:extension',
      bucket: bucket,
      s3_permissions: private_files ? :private : :public_read
    }
    if ENV['S3_ENDPOINT'].present?
      opts[:s3_options] = { endpoint: ENV['S3_ENDPOINT'], force_path_style: true }
      # Garage has no per-object permissions (access is per bucket and key), and
      # Paperclip would otherwise send public-read on every upload.
      opts[:s3_acl_enabled] = false
    end
    opts
  end

  def self.photos_bucket
    ENV['S3_BUCKET']
  end

  def self.documents_bucket
    ENV['S3_DOCUMENTS_BUCKET'].presence || ENV['S3_BUCKET']
  end
end
