# The lab's ticketed classes and workshops from guestlist.co (sign-ups,
# check-ins and money collected per event), for the analytics page. Counts
# only; no attendee names. Run by hand (bin/rails db:migrate); the app works
# before and after.
class CreateTicketedEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :ticketed_events do |t|
      t.integer :guestlist_id, null: false
      t.string :name, null: false
      t.date :held_on, null: false
      t.string :kind, null: false
      t.string :status, null: false
      t.integer :attendees, null: false, default: 0
      t.integer :checked_in, null: false, default: 0
      t.decimal :dollars, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end
    add_index :ticketed_events, :guestlist_id, unique: true
    add_index :ticketed_events, :held_on
  end
end
