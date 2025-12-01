module Outbox
  class Processor
    PROCESSOR_ID = SecureRandom.hex(4).freeze
    BATCH_SIZE = 100

    def process_batch
      # Concurrency control: SKIP LOCKED ensures multiple workers don't pick up the same events
      events = OutboxEvent.pending.limit(BATCH_SIZE).lock("FOR UPDATE SKIP LOCKED")

      events.each do |event|
        # Sentry: Wrap processing in a transaction for latency tracing.
        process_event_with_instrumentation(event)
      end
    end

    private

    def process_event_with_instrumentation(event)
      if defined?(Sentry) && ENV["SENTRY_DSN"].present?
        Sentry.with_scope do |scope|
          scope.set_tags(processor_id: PROCESSOR_ID, event_type: event.event_type)
          transaction = Sentry.start_transaction(op: "outbox.process", name: "OutboxProcessor")

          process_event_core(event, transaction)
        end
      else
        process_event_core(event, nil)
      end
    end

    def process_event_core(event, transaction = nil)
      begin
        # In a real app, this would be your actual publishing logic (e.g., Kafka, RabbitMQ, HTTP)
        publish_event(event)

        event.update!(
          status: :published,
          published_at: Time.current,
          processor_id: PROCESSOR_ID
        )

        # Instrument on success using Sentry Metrics
        Outbox::SentryMetrics.distribution(
          "outbox.processing_latency_seconds",
          event.published_at - event.created_at,
          unit: "second",
          tags: { event_type: event.event_type }
        )

        transaction&.set_status("ok")
      rescue StandardError => e
        # Sentry will capture the exception automatically.
        # We can add a custom counter for processing errors.
        Outbox::SentryMetrics.increment("outbox.processing_errors", tags: { error_class: e.class.name })

        event.update!(status: :failed, processor_id: PROCESSOR_ID)

        transaction&.set_status("internal_error")

        # Log error but continue processing other events in batch
        Rails.logger.error("Failed to process event #{event.id}: #{e.message}")
      ensure
        transaction&.finish
      end
    end

    def publish_event(event)
      Rails.logger.info("Publishing event #{event.id}: #{event.event_type} - #{event.payload}")
      # Simulate processing time
      sleep(0.05)
    end
  end
end
