class CreateOutboxEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :outbox_events do |t|
      t.string :event_type, null: false
      t.json :payload, null: false, default: {}
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :outbox_events, [ :published, :created_at ]
  end
end
