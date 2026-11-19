# One archive row per member per year instead of one per member, so a
# member's profile can show their history year by year. Rows from before
# (year empty) still count in the all-time totals until the archive is
# reloaded with script/door_activity_archive.rb. Run by hand
# (bin/rails db:migrate); the app works before and after.
class AddYearToDoorActivityArchives < ActiveRecord::Migration[7.2]
  def change
    add_column :door_activity_archives, :year, :integer
    remove_index :door_activity_archives, :user_id, unique: true
    add_index :door_activity_archives, [:user_id, :year], unique: true
  end
end
