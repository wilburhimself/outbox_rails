OutboxRails.configure do |config|
  config.batch_size = 100
  config.publish_proc = ->(event) do
    Rails.logger.info("Publishing event #{event.id}: #{event.event_type} - #{event.payload}")
    sleep(0.05)
  end
end
