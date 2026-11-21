require "csv"
require "net/http"

module LaserLog
  # Reads each laser log sheet (LaserLog::SHEETS) and replaces its jobs in
  # LaserJob, cleaned. Run nightly by `bundle exec rails laser:sync` (Coolify
  # scheduled task) and by hand after a deploy. A sheet that cannot be read or
  # looks wrong keeps its old rows; the others still update.
  class Sync
    TOO_FEW = 0.9 # refuse a sheet with under 90% of the rows already held from it

    # texts: { sheet => csv text } to skip the download (tests).
    def initialize(sheets = SHEETS, texts: {})
      @sheets = sheets
      @texts = texts
    end

    # { sheet => { read:, kept:, skipped: } or { error: } }
    def run
      tally = @sheets.to_h do |sheet|
        [sheet, replace(sheet)]
      rescue Error => e
        [sheet, { error: e.message }]
      end
      Rails.cache.delete_matched("laser") rescue nil
      Rails.cache.delete_matched("analytics") rescue nil
      tally
    end

    private

    def replace(sheet)
      rows = Layout.rows(@texts[sheet] || fetch(sheet.csv_url), sheet.layout)
      cleaner = Cleaner.new(overrides: sheet.machine == "large" && sheet.source == LaserJob::FORM)
      now = Time.current
      jobs = rows.each_with_index.filter_map do |(row, kept), i|
        attributes, name = cleaner.call(row, i + 2)
        attributes&.merge(kept)&.merge(machine: sheet.machine_for(attributes[:logged_on]), source: sheet.source, person_key: name.blank? ? "" : LaserLog.person_key(name),
                                       created_at: now, updated_at: now)
      end
      scope = LaserJob.where(machine: sheet.machines, source: sheet.source)
      held = scope.count
      raise Error, "#{jobs.size} jobs, fewer than the #{held} already held" if jobs.size < held * TOO_FEW
      LaserJob.transaction do
        scope.delete_all
        LaserJob.insert_all!(jobs) if jobs.any?
      end
      { read: rows.size, kept: jobs.size, skipped: rows.size - jobs.size }
    end

    def fetch(url, redirects = 3)
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
