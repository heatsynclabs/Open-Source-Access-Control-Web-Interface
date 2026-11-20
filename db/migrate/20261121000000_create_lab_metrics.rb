# Counts and totals about the lab from records the site does not hold (old
# backups, PayPal and utility records, the mailing list, the old wiki, tax
# returns), for the analytics page's "Over the years" tab. Totals only; no
# per-person rows. Run by hand (bin/rails db:migrate); the app works before
# and after.
class CreateLabMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :lab_metrics do |t|
      t.string :key, null: false
      t.string :label, null: false, default: ""
      t.string :period, null: false
      t.date :starts_on, null: false
      t.decimal :value, precision: 14, scale: 2
      t.string :source, null: false
      t.timestamps
    end
    add_index :lab_metrics, [:key, :label, :starts_on], unique: true
  end
end
