# Old door log rows for the analytics page: the granted swipes (G) and the
# remote commands (rem_*, api_rem_*) of September 2012 to October 2020,
# recovered from backups (the live door_logs table starts in July 2022;
# October 2020 to July 2022 was lost). Same columns and meaning as
# door_logs, so Analytics::Door counts both together. Nothing else reads
# it: the door leaderboard uses DoorActivityArchive's per-member totals.
# Loaded with script/door_log_archive.rb.
class DoorLogArchive < ActiveRecord::Base
  # Deploys do not run migrations; until the table exists analytics shows
  # the live log only.
  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
