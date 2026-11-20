# Where each ticketed event's numbers came from and when they were read:
# the organizer export (the full history, by hand) or guestlist's public
# pages (the nightly check). Run by hand (bin/rails db:migrate).
class AddCollectionToTicketedEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :ticketed_events, :source, :string, null: false, default: "organizer export"
    add_column :ticketed_events, :collected_at, :datetime
    # Rows already loaded came from the organizer export, read the day they were loaded.
    up_only { execute "UPDATE ticketed_events SET collected_at = created_at" }
  end
end
