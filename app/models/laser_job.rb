# One job on the large 80 W laser, as a member logged it and
# LaserLog::Cleaner repaired it: from the current form (source FORM, rebuilt
# nightly by LaserLog::Sync) or the earlier form of 2013 to 2020 (source
# EARLIER, LaserLog::Archive), which recorded settings but not results.
# Never holds a name: person_key tells jobs by the same person apart and
# nothing more. The Laser page (Laser::Settings, Laser::Trouble, Laser::Math)
# and analytics (Laser::Usage) read it.
class LaserJob < ActiveRecord::Base
  FORM = "form"
  EARLIER = "2013 log"

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
