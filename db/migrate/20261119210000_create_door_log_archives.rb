# The door log rows the analytics page counts (granted swipes and remote
# commands) for 2012 to October 2020, years the live door_logs table does
# not hold (see DoorLogArchive). Run by hand (bin/rails db:migrate); the app
# works before and after.
class CreateDoorLogArchives < ActiveRecord::Migration[7.2]
  def change
    create_table :door_log_archives do |t|
      t.string :key, null: false
      t.integer :data
      t.datetime :created_at, null: false
    end
    add_index :door_log_archives, :created_at
    add_index :door_log_archives, :key
  end
end
