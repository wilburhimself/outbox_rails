module OutboxRails
  class Processor
    PROCESSOR_ID = SecureRandom.hex(4).freeze

    def process_batch
      batch_size = OutboxRails.configuration.batch_size
      events = OutboxRails::OutboxEvent.pending.limit(batch_size).lock("FOR UPDATE SKIP LOCKED")

      events.each do |event|
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
        publish_event(event)

        event.update!(
          status: :published,
          published_at: Time.current,
          processor_id: PROCESSOR_ID
        )

        OutboxRails::SentryMetrics.distribution(
          "outbox.processing_latency_seconds",
          event.published_at - event.created_at,
          unit: "second",
          tags: { event_type: event.event_type }
        )

        transaction&.set_status("ok")
      rescue StandardError => e
        OutboxRails::SentryMetrics.increment("outbox.processing_errors", tags: { error_class: e.class.name })

        event.update!(status: :failed, processor_id: PROCESSOR_ID)

        transaction&.set_status("internal_error")

        Rails.logger.error("Failed to process event #{event.id}: #{e.message}")
      ensure
        transaction&.finish
      end
    end

    def publish_event(event)
      OutboxRails.configuration.publish_proc.call(event)
    end
  end
end
