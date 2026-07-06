module OutboxRails
  class PublishJob < ActiveJob::Base
    queue_as :default
    self.enqueue_after_transaction_commit = true

    def perform
      processor = OutboxRails::Processor.new
      processor.process_batch
    end
  end
end
