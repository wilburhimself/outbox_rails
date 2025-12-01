class AddIdempotencyKeyToOutboxEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :outbox_events, :idempotency_key, :string
    add_index :outbox_events, :idempotency_key, unique: true
  end
end
