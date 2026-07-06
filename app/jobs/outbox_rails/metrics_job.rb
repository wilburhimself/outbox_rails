module OutboxRails
  class MetricsJob < ActiveJob::Base
    queue_as :default

    def perform
      OutboxRails::MetricsReporter.report
    end
  end
end
