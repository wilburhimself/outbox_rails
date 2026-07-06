module OutboxRails
  class Publisher
    def self.publish(event_type, payload, idempotency_key: nil)
      OutboxRails::OutboxEvent.create!(
        event_type: event_type,
        payload: payload,
        idempotency_key: idempotency_key
      )

      OutboxRails::PublishJob.perform_later
    end
  end
end
