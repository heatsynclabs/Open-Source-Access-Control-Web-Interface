# The job logs of the lab's two laser cutters: Google Sheets behind the forms
# members fill in at each machine, shared as "anyone with the link can view",
# so the site reads them as CSV with no login (LaserLog::Sync, nightly). Each
# machine has its current form (from April 2022) and the old form it replaced;
# people still log on an old form now and then, so all four are read. The
# wiki's Large 80W Laser and Mini 60W Laser pages link them. See
# docs/laser.md.
module LaserLog
  # The mini laser's old form was first the large laser's: its jobs from
  # 2011 to 2013 are the large one's, stored as LaserJob::FIRST. The large
  # laser is the lab's 2011 Exlas (its manual and import papers are in the
  # Board's records; Slack, January 2020: it came with a 100 W tube). The
  # mini came around 2019 (Slack, October 2019) and its jobs on the form
  # start in November.
  FIRST_LASER_UNTIL = Date.new(2019, 1, 1)

  Sheet = Data.define(:machine, :source, :id, :tab, :layout) do
    # The machines whose jobs this sheet holds.
    def machines = machine == "mini" && source == LaserJob::OLD ? [machine, LaserJob::FIRST] : [machine]

    def machine_for(day) = machines.include?(LaserJob::FIRST) && day < FIRST_LASER_UNTIL ? LaserJob::FIRST : machine

    def csv_url = "https://docs.google.com/spreadsheets/d/#{id}/export?format=csv#{"&gid=#{tab}" if tab}"
    def url = "https://docs.google.com/spreadsheets/d/#{id}/edit#{"#gid=#{tab}" if tab}"
  end

  SHEETS = [
    Sheet.new(machine: "large", source: LaserJob::FORM, id: "1BpAYtyFIKQ4UoXv31mKC43YFxfBk34d_q-muw1SP2aU", tab: "1050947612", layout: :form),
    Sheet.new(machine: "large", source: LaserJob::OLD, id: "0AoBMPvlNCqvldHl5SERwRHVjN09wRHEtODZzd2RXNWc", tab: nil, layout: :old_large),
    Sheet.new(machine: "mini", source: LaserJob::FORM, id: "1tDxqWNbrJ9M5UuvxpV4khA5Drt6HOfNuQRQbdNvYTxM", tab: nil, layout: :form),
    Sheet.new(machine: "mini", source: LaserJob::OLD, id: "1gItwjL4vfXwAsAQZ4dHuAlmoJ7lkLDme82yCei9KeF8", tab: "1432871391", layout: :old_mini),
  ].freeze

  class Error < StandardError; end

  module_function

  def sheet(machine, source = LaserJob::FORM)
    SHEETS.find { |s| s.machine == machine && s.source == source }
  end

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
