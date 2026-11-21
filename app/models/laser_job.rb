# One job on one of the lab's laser cutters, as a member logged it and
# LaserLog::Cleaner repaired it, from the machine's current form (FORM) or its
# old one (OLD). Rebuilt nightly by LaserLog::Sync from LaserLog::SHEETS.
# MACHINES are the lab's two lasers (the Laser page's switch). The large
# laser's jobs of 2011 to 2013 are on the mini's old form and are stored as
# FIRST (LaserLog::FIRST_LASER_UNTIL).
# Never holds a name: person_key tells jobs by the same person apart and
# nothing more. The Laser page (Laser::Settings, Laser::Trouble, Laser::Math)
# and analytics (Laser::Usage) read it.
class LaserJob < ActiveRecord::Base
  MACHINES = { "large" => "Large 80W", "mini" => "Mini 60W" }.freeze
  WATTS = { "large" => 80, "mini" => 60 }.freeze # as rated; the mini's tube reading is Laser::Tube
  # The large laser's jobs of 2011 to 2013: the lab's 2011 Exlas, then on a
  # 100 W tube, logged on the form the mini took over in 2019.
  # They keep their own key so each sheet's nightly replace touches only its
  # own rows (LaserLog::Sync). Analytics counts them as the large laser's
  # (stored); the Laser page leaves them out, its settings being for the
  # tubes the lasers have now.
  FIRST = "first"
  FORM = "form"
  OLD = "old form"

  scope :cuts, -> { where(cut_op: "cut") }
  scope :with_settings, -> { where.not(cut_op: nil).or(where.not(eng_mode: nil)) }

  # The machine keys a laser's jobs are stored under.
  def self.stored(machine) = machine == "large" ? [machine, FIRST] : [machine]

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
