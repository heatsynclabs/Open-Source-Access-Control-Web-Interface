# The large 80 W laser's job log: the Google Sheet behind the form members
# fill in at the laser. Its form responses tab is shared as "anyone with the
# link can view", so the site reads it as CSV with no login (LaserLog::Sync,
# nightly). See docs/laser.md.
module LaserLog
  SHEET_ID = "1BpAYtyFIKQ4UoXv31mKC43YFxfBk34d_q-muw1SP2aU"
  RESPONSES_TAB = "1050947612"
  CSV_URL = ENV.fetch("LASER_LOG_CSV_URL", "https://docs.google.com/spreadsheets/d/#{SHEET_ID}/export?format=csv&gid=#{RESPONSES_TAB}")
  SHEET_URL = "https://docs.google.com/spreadsheets/d/#{SHEET_ID}/edit#gid=#{RESPONSES_TAB}"

  class Error < StandardError; end

  module_function

  # A key that tells one person's jobs from another's without naming them:
  # the explorer's short form of the name (first four letters of the first
  # word, five of the last), hashed with the app's secret. Not reversible
  # without the secret, and stable from night to night.
  def person_key(name)
    words = name.downcase.gsub(/[^a-z ]/, "").split
    short = words.any? ? "#{words.first[0, 4]} #{words.last[0, 5]}" : "?"
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "laser-log:#{short}")[0, 16]
  end
end
