# Leaderboard totals for door history the live door_logs table no longer holds
# (see DoorActivityArchive). Deploys do not run migrations: run this by hand
# (bin/rails db:migrate). The app works before and after.
class CreateDoorActivityArchives < ActiveRecord::Migration[7.2]
  def change
    create_table :door_activity_archives do |t|
      t.integer :user_id, null: false
      t.decimal :hours, precision: 10, scale: 1, null: false, default: 0
      t.integer :shifts, null: false, default: 0
      t.integer :opened, null: false, default: 0
      t.integer :locked, null: false, default: 0
      t.integer :days, null: false, default: 0
      t.date :covers_from, null: false
      t.date :covers_to, null: false
      t.timestamps
    end
    add_index :door_activity_archives, :user_id, unique: true
  end
end
