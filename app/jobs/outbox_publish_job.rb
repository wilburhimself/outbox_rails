class OutboxPublishJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true

  def perform
    processor = Outbox::Processor.new
    processor.process_batch
  end
end
