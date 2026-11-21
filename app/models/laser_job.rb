# One job on one of the lab's laser cutters, as a member logged it and
# LaserLog::Cleaner repaired it, from the machine's current form (FORM) or its
# old one (OLD). Rebuilt nightly by LaserLog::Sync from LaserLog::SHEETS.
# MACHINES are the lasers the lab has now (the Laser page's switch); LABELS
# adds "first", the lab's first laser, whose 2011 to 2013 jobs are on the
# mini's old form (LaserLog::FIRST_LASER_UNTIL).
# Never holds a name: person_key tells jobs by the same person apart and
# nothing more. The Laser page (Laser::Settings, Laser::Trouble, Laser::Math)
# and analytics (Laser::Usage) read it.
class LaserJob < ActiveRecord::Base
  MACHINES = { "large" => "Large 80W", "mini" => "Mini 60W" }.freeze
  LABELS = MACHINES.merge("first" => "First laser").freeze
  WATTS = { "large" => 80, "mini" => 60 }.freeze
  FORM = "form"
  OLD = "old form"

  scope :cuts, -> { where(cut_op: "cut") }
  scope :with_settings, -> { where.not(cut_op: nil).or(where.not(eng_mode: nil)) }

  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end

  # When the log was last read, for "data through" notes and cache keys.
  def self.synced_at
    maximum(:updated_at)
  end

  def issue_list
    issues.split("; ")
  end

  def fix_list
    fixes.split("; ")
  end

  def success?
    result == "success"
  end
end
