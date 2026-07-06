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

ActiveRecord::Schema[8.0].define(version: 2026_07_06_143000) do
  create_table "outbox_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.json "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "published_at"
    t.string "processor_id"
    t.string "idempotency_key"
    t.index ["created_at"], name: "index_outbox_events_on_published_and_created_at"
    t.index ["idempotency_key"], name: "index_outbox_events_on_idempotency_key", unique: true
    t.index ["processor_id"], name: "index_outbox_events_on_processor_id"
    t.index ["status"], name: "index_outbox_events_on_status"
  end

  create_table "outbox_rails_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.json "payload", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "published_at"
    t.string "processor_id"
    t.string "idempotency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_outbox_rails_events_on_idempotency_key", unique: true
    t.index ["processor_id"], name: "index_outbox_rails_events_on_processor_id"
    t.index ["status", "created_at"], name: "index_outbox_rails_events_on_status_and_created_at"
    t.index ["status"], name: "index_outbox_rails_events_on_status"
  end
end
