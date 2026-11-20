# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_11_21_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.string "event_type"
    t.integer "editor_id"
    t.string "editor_name"
    t.integer "affected_user_id"
    t.string "target_type"
    t.integer "target_id"
    t.string "target_label"
    t.text "summary"
    t.string "ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["affected_user_id"], name: "index_audit_events_on_affected_user_id"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
    t.index ["editor_id"], name: "index_audit_events_on_editor_id"
    t.index ["event_type"], name: "index_audit_events_on_event_type"
    t.index ["target_type", "target_id"], name: "index_audit_events_on_target_type_and_target_id"
  end

  create_table "cards", force: :cascade do |t|
    t.string "card_number"
    t.integer "card_permissions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "name"
  end

  create_table "certifications", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
  end

  create_table "contracts", force: :cascade do |t|
    t.integer "user_id"
    t.string "first_name"
    t.string "last_name"
    t.datetime "signed_at"
    t.string "document_file_name"
    t.string "document_content_type"
    t.integer "document_file_size"
    t.datetime "document_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cosigner"
    t.integer "created_by_id"
  end

  create_table "door_activity_archives", force: :cascade do |t|
    t.integer "user_id", null: false
    t.decimal "hours", precision: 10, scale: 1, default: "0.0", null: false
    t.integer "shifts", default: 0, null: false
    t.integer "opened", default: 0, null: false
    t.integer "locked", default: 0, null: false
    t.integer "days", default: 0, null: false
    t.date "covers_from", null: false
    t.date "covers_to", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["user_id", "year"], name: "index_door_activity_archives_on_user_id_and_year", unique: true
  end

  create_table "door_log_archives", force: :cascade do |t|
    t.string "key", null: false
    t.integer "data"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_door_log_archives_on_created_at"
    t.index ["key"], name: "index_door_log_archives_on_key"
  end

  create_table "door_logs", force: :cascade do |t|
    t.string "key"
    t.integer "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_door_logs_on_created_at"
    t.index ["key"], name: "index_door_logs_on_key"
  end

  create_table "ipns", force: :cascade do |t|
    t.integer "payment_id"
    t.text "data"
    t.string "txn_id"
    t.string "txn_type"
    t.string "first_name"
    t.string "last_name"
    t.string "payer_business_name"
    t.string "payer_email"
    t.string "payer_id"
    t.string "auth_amount"
    t.string "payment_date"
    t.string "payment_fee"
    t.string "payment_gross"
    t.string "payment_status"
    t.string "item_name"
    t.string "payment_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lab_metrics", force: :cascade do |t|
    t.string "key", null: false
    t.string "label", default: "", null: false
    t.string "period", null: false
    t.date "starts_on", null: false
    t.decimal "value", precision: 14, scale: 2
    t.string "source", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key", "label", "starts_on"], name: "index_lab_metrics_on_key_and_label_and_starts_on", unique: true
  end

  create_table "laser_jobs", force: :cascade do |t|
    t.string "source", default: "form", null: false
    t.integer "sheet_row", null: false
    t.datetime "logged_at", null: false
    t.date "logged_on", null: false
    t.string "person_key", default: "", null: false
    t.string "title", default: "", null: false
    t.string "material_raw", default: "", null: false
    t.string "material", null: false
    t.string "family", null: false
    t.string "thickness_raw", default: "", null: false
    t.decimal "mm", precision: 6, scale: 2
    t.string "bucket", null: false
    t.string "cut_op"
    t.decimal "cut_power", precision: 8, scale: 2
    t.decimal "cut_speed", precision: 8, scale: 2
    t.decimal "cut_passes", precision: 6, scale: 2
    t.string "eng_mode"
    t.decimal "eng_power", precision: 8, scale: 2
    t.decimal "eng_speed", precision: 8, scale: 2
    t.decimal "eng_passes", precision: 6, scale: 2
    t.decimal "eng_gap", precision: 6, scale: 3
    t.string "result", null: false
    t.string "result_raw", default: "", null: false
    t.string "issues", default: "", null: false
    t.decimal "minutes", precision: 8, scale: 2
    t.decimal "copies", precision: 8, scale: 2
    t.string "clean_start", default: "", null: false
    t.string "cleaned_after", default: "", null: false
    t.text "notes", default: "", null: false
    t.text "machine_notes", default: "", null: false
    t.text "software_notes", default: "", null: false
    t.text "fixes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["logged_on"], name: "index_laser_jobs_on_logged_on"
    t.index ["material", "bucket"], name: "index_laser_jobs_on_material_and_bucket"
    t.index ["source", "sheet_row"], name: "index_laser_jobs_on_source_and_sheet_row", unique: true
  end

  create_table "mac_logs", force: :cascade do |t|
    t.string "mac"
    t.string "ip"
    t.string "action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "macs", force: :cascade do |t|
    t.integer "user_id"
    t.string "mac"
    t.string "ip"
    t.datetime "since"
    t.datetime "refreshed"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hidden"
    t.string "note"
    t.index ["user_id"], name: "index_macs_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "user_id"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "created_by"
    t.decimal "amount"
    t.index ["amount"], name: "index_payments_on_amount"
    t.index ["date"], name: "index_payments_on_date"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "paypal_csvs", force: :cascade do |t|
    t.integer "payment_id"
    t.text "data"
    t.string "date"
    t.string "_time"
    t.string "_time_zone"
    t.string "_name"
    t.string "_type"
    t.string "_status"
    t.string "_currency"
    t.string "_gross"
    t.string "_fee"
    t.string "_net"
    t.string "_from_email_address"
    t.string "_to_email_address"
    t.string "_transaction_id"
    t.string "_counterparty_status"
    t.string "_address_status"
    t.string "_item_title"
    t.string "_item_id"
    t.string "string"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "resource_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "parent"
  end

  create_table "resources", force: :cascade do |t|
    t.string "supercategory"
    t.integer "owner_id"
    t.integer "resource_category_id"
    t.string "name"
    t.string "serial"
    t.string "specs"
    t.string "status"
    t.boolean "donatable"
    t.string "picture_file_name"
    t.string "picture_content_type"
    t.integer "picture_file_size"
    t.datetime "picture_updated_at"
    t.text "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "estimated_value"
    t.integer "user_id"
    t.datetime "disposed_at"
    t.integer "modified_by"
    t.string "picture2_file_name"
    t.string "picture2_content_type"
    t.integer "picture2_file_size"
    t.datetime "picture2_updated_at"
    t.string "picture3_file_name"
    t.string "picture3_content_type"
    t.integer "picture3_file_size"
    t.datetime "picture3_updated_at"
    t.string "picture4_file_name"
    t.string "picture4_content_type"
    t.integer "picture4_file_size"
    t.datetime "picture4_updated_at"
  end

  create_table "settings", force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.integer "thing_id"
    t.string "thing_type", limit: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["thing_type", "thing_id", "var"], name: "index_settings_on_thing_type_and_thing_id_and_var", unique: true
  end

  create_table "ticketed_events", force: :cascade do |t|
    t.integer "guestlist_id", null: false
    t.string "name", null: false
    t.date "held_on", null: false
    t.string "kind", null: false
    t.string "status", null: false
    t.integer "attendees", default: 0, null: false
    t.integer "checked_in", default: 0, null: false
    t.decimal "dollars", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "organizer export", null: false
    t.datetime "collected_at"
    t.index ["guestlist_id"], name: "index_ticketed_events_on_guestlist_id", unique: true
    t.index ["held_on"], name: "index_ticketed_events_on_held_on"
  end

  create_table "toolshare_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", limit: 128, default: "", null: false
    t.string "password_salt", default: "", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "reset_password_token"
    t.string "remember_token"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
  end

  create_table "user_certifications", force: :cascade do |t|
    t.integer "user_id"
    t.integer "certification_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_by"
    t.integer "created_by"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.boolean "admin"
    t.integer "member"
    t.datetime "waiver"
    t.datetime "orientation"
    t.string "emergency_name"
    t.string "emergency_phone"
    t.string "emergency_email"
    t.integer "member_level"
    t.string "payment_method"
    t.string "phone"
    t.text "current_skills"
    t.text "desired_skills"
    t.boolean "instructor"
    t.boolean "hidden"
    t.text "marketing_source"
    t.string "payee"
    t.boolean "accountant"
    t.text "exit_reason"
    t.string "twitter_url"
    t.string "facebook_url"
    t.string "github_url"
    t.string "website_url"
    t.boolean "email_visible"
    t.boolean "phone_visible"
    t.string "postal_code"
    t.integer "oriented_by_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
