class OutboxPublishJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true

  def perform
    OutboxEvent.pending.order(:created_at).find_each do |event|
      process_event(event)
    end
  end

  private

  def process_event(event)
    Rails.logger.info("Publishing event #{event.id}: #{event.event_type} - #{event.payload}")
    
    # Simulate processing time
    sleep(0.05)
    
    event.update!(published: true)
  rescue StandardError => e
    Rails.logger.error("Failed to publish event #{event.id}: #{e.message}")
  end
end
