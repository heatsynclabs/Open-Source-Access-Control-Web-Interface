class CreateAuditEvents < ActiveRecord::Migration
  def change
    create_table :audit_events do |t|
      t.string   :event_type              # e.g. user_update, cert_granted, payment_created
      t.integer  :editor_id               # who performed the action (nil = system/anonymous)
      t.string   :editor_name             # denormalized so the log survives user renames/deletes
      t.integer  :affected_user_id        # which member this action is about (for reporting joins)
      t.string   :target_type             # model class of the precise record changed
      t.integer  :target_id
      t.string   :target_label            # human label of the target at the time
      t.text     :summary                 # what changed / details
      t.string   :ip
      t.timestamps
    end
    add_index :audit_events, :created_at
    add_index :audit_events, :event_type
    add_index :audit_events, [:target_type, :target_id]
    add_index :audit_events, :editor_id
    add_index :audit_events, :affected_user_id
  end
end
