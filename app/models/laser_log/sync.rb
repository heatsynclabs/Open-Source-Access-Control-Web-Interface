require "csv"
require "net/http"

module LaserLog
  # Reads the whole laser log form and replaces its jobs in LaserJob (source
  # FORM; the earlier log is LaserLog::Archive's), cleaned. Run
  # nightly by `bundle exec rails laser:sync` (Coolify scheduled task) and by
  # hand after a deploy. Keeps the old rows if the sheet cannot be read or
  # looks wrong.
  class Sync
    HEADER = "Timestamp"
    TOO_FEW = 0.9 # refuse a sheet with under 90% of the rows already held

    def initialize(csv_text = nil)
      @csv_text = csv_text
    end

    # { read:, kept:, skipped: } or raises LaserLog::Error
    def run
      rows = CSV.parse(@csv_text || fetch)
      raise Error, "the sheet does not look like the laser log" unless rows.first&.first.to_s.strip == HEADER
      cleaner = Cleaner.new
      now = Time.current
      jobs = rows.drop(1).each_with_index.filter_map do |row, i|
        attributes, name = cleaner.call(row, i + 2)
        attributes&.merge(source: LaserJob::FORM, person_key: LaserLog.person_key(name), created_at: now, updated_at: now)
      end
      held = LaserJob.where(source: LaserJob::FORM).count
      raise Error, "the sheet has #{jobs.size} jobs, fewer than the #{held} already held" if jobs.size < held * TOO_FEW
      LaserJob.transaction do
        LaserJob.where(source: LaserJob::FORM).delete_all
        LaserJob.insert_all!(jobs) if jobs.any?
      end
      Rails.cache.delete_matched("laser") rescue nil
      Rails.cache.delete_matched("analytics") rescue nil
      { read: rows.size - 1, kept: jobs.size, skipped: rows.size - 1 - jobs.size }
    end

    private

    def fetch(url = CSV_URL, redirects = 3)
      response = Net::HTTP.get_response(URI(url))
      if response.is_a?(Net::HTTPRedirection) && redirects.positive?
        return fetch(response["location"], redirects - 1)
      end
      raise Error, "the sheet answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      response.body.force_encoding("UTF-8")
    rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
      raise Error, "could not reach the sheet (#{e.class})"
    end
  end
end
