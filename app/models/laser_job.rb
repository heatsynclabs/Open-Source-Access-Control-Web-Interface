# One job on one of the lab's laser cutters (MACHINES), as a member logged it
# and LaserLog::Cleaner repaired it, from the machine's current form (FORM) or
# its old one (OLD). Rebuilt nightly by LaserLog::Sync from LaserLog::SHEETS.
# Never holds a name: person_key tells jobs by the same person apart and
# nothing more. The Laser page (Laser::Settings, Laser::Trouble, Laser::Math)
# and analytics (Laser::Usage) read it.
class LaserJob < ActiveRecord::Base
  MACHINES = { "large" => "Large 80W", "mini" => "Mini 60W" }.freeze
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
