module OutboxRails
  class SentryMetrics
    def self.gauge(metric_name, value, tags: {})
      Rails.logger.info("[METRIC] #{metric_name}: #{value} #{tags.inspect}")

      if defined?(Sentry)
        Sentry.add_breadcrumb(
          Sentry::Breadcrumb.new(
            category: "metric",
            message: "#{metric_name}: #{value}",
            data: tags,
            level: "info"
          )
        )
      end
    end

    def self.distribution(metric_name, value, unit: nil, tags: {})
      Rails.logger.info("[METRIC] #{metric_name}: #{value}#{unit ? " #{unit}" : ""} #{tags.inspect}")

      if defined?(Sentry)
        Sentry.add_breadcrumb(
          Sentry::Breadcrumb.new(
            category: "metric",
            message: "#{metric_name}: #{value}#{unit ? " #{unit}" : ""}",
            data: tags,
            level: "info"
          )
        )
      end
    end

    def self.increment(metric_name, tags: {})
      Rails.logger.info("[METRIC] #{metric_name}: +1 #{tags.inspect}")

      if defined?(Sentry)
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
end
