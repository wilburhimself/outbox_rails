module Outbox
  class Publisher
    def self.publish(event_type, payload, idempotency_key: nil)
      OutboxEvent.create!(
        event_type: event_type,
        payload: payload,
        idempotency_key: idempotency_key
      )

      OutboxPublishJob.perform_later
    end
  end
end
