# The job logs of the lab's two laser cutters (machine "large", the 80 W, and
# "mini", the 60 W), cleaned (LaserLog::Cleaner), for the Laser page and
# analytics. Each machine has a current form (source "form") and an old one
# ("old form"); laser:sync rebuilds all four from their sheets every night
# (LaserLog::SHEETS). No names: person_key is a keyed hash that only tells
# jobs by the same person apart. Run by hand (rails db:migrate); the app works
# before and after.
class CreateLaserJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :laser_jobs do |t|
      t.string :machine, null: false, default: "large"
      t.string :source, null: false, default: "form"
      t.integer :sheet_row, null: false
      t.datetime :logged_at, null: false
      t.date :logged_on, null: false
      t.string :person_key, null: false, default: ""
      t.string :title, null: false, default: ""
      t.string :material_raw, null: false, default: ""
      t.string :material, null: false
      t.string :family, null: false
      t.string :thickness_raw, null: false, default: ""
      t.decimal :mm, precision: 6, scale: 2
      t.string :bucket, null: false
      t.string :cut_op
      t.decimal :cut_power, precision: 8, scale: 2
      t.decimal :cut_speed, precision: 8, scale: 2
      t.decimal :cut_passes, precision: 6, scale: 2
      t.string :eng_mode
      t.decimal :eng_power, precision: 8, scale: 2
      t.decimal :eng_speed, precision: 8, scale: 2
      t.decimal :eng_passes, precision: 6, scale: 2
      t.decimal :eng_gap, precision: 6, scale: 3
      t.string :result, null: false
      t.string :result_raw, null: false, default: ""
      t.string :issues, null: false, default: ""
      t.decimal :minutes, precision: 8, scale: 2
      t.decimal :copies, precision: 8, scale: 2
      t.string :clean_start, null: false, default: ""
      t.string :cleaned_after, null: false, default: ""
      t.text :notes, null: false, default: ""
      t.text :machine_notes, null: false, default: ""
      t.text :software_notes, null: false, default: ""
      t.text :fixes, null: false, default: ""
      t.timestamps
    end
    add_index :laser_jobs, [:machine, :source, :sheet_row], unique: true
    add_index :laser_jobs, :logged_on
    add_index :laser_jobs, [:material, :bucket]
  end
end
