class CreateOutboxRailsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :outbox_rails_events do |t|
      t.string :event_type, null: false
      t.json :payload, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.datetime :published_at
      t.string :processor_id
      t.string :idempotency_key, null: false

      t.timestamps
    end

    add_index :outbox_rails_events, :idempotency_key, unique: true
    add_index :outbox_rails_events, :status
    add_index :outbox_rails_events, :processor_id
    add_index :outbox_rails_events, [ :status, :created_at ], name: "index_outbox_rails_events_on_status_and_created_at"
  end
end
