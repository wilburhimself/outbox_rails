module OutboxRails
  class OutboxEvent < ActiveRecord::Base
    self.table_name = "outbox_rails_events"

    enum :status, { pending: 0, processing: 1, published: 2, failed: 3 }

    scope :pending, -> { where(status: :pending) }

    before_validation :generate_idempotency_key, on: :create

    validates :idempotency_key, presence: true, uniqueness: true

    private

    def generate_idempotency_key
      self.idempotency_key ||= SecureRandom.uuid
    end
  end
end
