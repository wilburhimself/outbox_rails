module Outbox
  class Publisher
    def self.publish(event_type, payload)
      OutboxEvent.create!(event_type: event_type, payload: payload)

      OutboxPublishJob.perform_later
    end
  end
end
