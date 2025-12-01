class UpgradeOutboxEvents < ActiveRecord::Migration[8.0]
  def change
    change_table :outbox_events do |t|
      t.integer :status, null: false, default: 0
      t.datetime :published_at
      t.string :processor_id
      t.remove :published
    end

    add_index :outbox_events, :status
    add_index :outbox_events, :processor_id
  end
end
