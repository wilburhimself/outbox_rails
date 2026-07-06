module OutboxRails
  class MetricsReporter
    def self.report
      new.report
    end

    def report
      report_queue_age
      report_queue_depth
      report_error_rate
    end

    private

    def report_queue_age
      oldest_event = OutboxRails::OutboxEvent.pending.order(created_at: :asc).first
      queue_age = oldest_event ? (Time.current - oldest_event.created_at) : 0

      OutboxRails::SentryMetrics.gauge("outbox.queue_age_seconds", queue_age.round)

      Rails.logger.info("Outbox queue_age: #{queue_age.round}s")
    end

    def report_queue_depth
      queue_depth = OutboxRails::OutboxEvent.pending.count

      OutboxRails::SentryMetrics.gauge("outbox.queue_depth", queue_depth)

      Rails.logger.info("Outbox queue_depth: #{queue_depth}")
    end

    def report_error_rate
      one_hour_ago = 1.hour.ago

      total_processed = OutboxRails::OutboxEvent.where("updated_at > ?", one_hour_ago)
                                         .where(status: [ :published, :failed ])
                                         .count

      failed_count = OutboxRails::OutboxEvent.where("updated_at > ?", one_hour_ago)
                                      .where(status: :failed)
                                      .count

      error_rate = total_processed > 0 ? (failed_count.to_f / total_processed * 100).round(2) : 0

      OutboxRails::SentryMetrics.gauge("outbox.error_rate_percentage", error_rate)

      Rails.logger.info("Outbox error_rate: #{error_rate}%")
    end
  end
end
