# Streams a Paperclip file from the store to the browser after the controller
# has checked access. Only known-safe types are shown inline; anything else is a
# download. Waivers are never cached; photos are cached for a day.
module SendsStoredFiles
  INLINE_TYPES = %w[application/pdf image/jpeg image/png image/gif image/webp].freeze

  private

  def send_stored_file(attachment, style, basename, private_file:)
    unless private_file
      expires_in 1.day, public: true
      # Paperclip's updated_at is epoch seconds.
      changed = Time.zone.at(attachment.updated_at.to_i)
      return if fresh_when(etag: [attachment.updated_at.to_i, style], last_modified: changed, public: true)
    end

    data = read_stored(attachment, style)
    return head(:not_found) if data.blank?

    type = attachment.content_type.to_s
    inline = INLINE_TYPES.include?(type) && params[:download].blank?
    ext = File.extname(attachment.original_filename.to_s).downcase.gsub(/[^.a-z0-9]/, '')
    response.headers['Cache-Control'] = 'no-store, private' if private_file
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Content-Security-Policy'] = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'" + (type == 'application/pdf' ? '' : '; sandbox')
    send_data data, type: inline ? type : 'application/octet-stream',
                    disposition: inline ? 'inline' : 'attachment',
                    filename: "#{basename}#{ext}"
  end

  def read_stored(attachment, style)
    Tempfile.create(['stored', '.bin']) do |tmp|
      tmp.binmode
      attachment.copy_to_local_file(style, tmp.path)
      File.binread(tmp.path)
    end
  rescue StandardError => e
    Rails.logger.warn("stored file #{attachment.name} #{style} for #{attachment.instance.class.name} #{attachment.instance.id} not read: #{e.class}")
    nil
  end
end
