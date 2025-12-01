module Outbox
  # Wrapper for Sentry metrics that works with older Sentry versions
  # In production, you should upgrade to sentry-ruby >= 6.0 for native metrics support
  # or use a dedicated metrics service like Prometheus, StatsD, or Datadog
  class SentryMetrics
    def self.gauge(metric_name, value, tags: {})
      # Log metrics for now - in production, send to your metrics backend
      Rails.logger.info("[METRIC] #{metric_name}: #{value} #{tags.inspect}")

      # Send as Sentry breadcrumb for visibility
      Sentry.add_breadcrumb(
        Sentry::Breadcrumb.new(
          category: "metric",
          message: "#{metric_name}: #{value}",
          data: tags,
          level: "info"
        )
      )
    end

    def self.distribution(metric_name, value, unit: nil, tags: {})
      # Log metrics for now - in production, send to your metrics backend
      Rails.logger.info("[METRIC] #{metric_name}: #{value}#{unit ? " #{unit}" : ""} #{tags.inspect}")

      # Send as Sentry breadcrumb for visibility
      Sentry.add_breadcrumb(
        Sentry::Breadcrumb.new(
          category: "metric",
          message: "#{metric_name}: #{value}#{unit ? " #{unit}" : ""}",
          data: tags,
          level: "info"
        )
      )
    end

    def self.increment(metric_name, tags: {})
      # Log metrics for now - in production, send to your metrics backend
      Rails.logger.info("[METRIC] #{metric_name}: +1 #{tags.inspect}")

      # Send as Sentry breadcrumb for visibility
      Sentry.add_breadcrumb(
        Sentry::Breadcrumb.new(
          category: "metric",
          message: "#{metric_name}: +1",
          data: tags,
          level: "info"
        )
      )
    end
  end
end
