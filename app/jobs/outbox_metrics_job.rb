class OutboxMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Outbox::MetricsReporter.report
  end
end
