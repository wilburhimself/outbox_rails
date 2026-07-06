require "outbox_rails/version"
require "outbox_rails/engine" if defined?(Rails)

module OutboxRails
  class Configuration
    attr_accessor :batch_size, :publish_proc

    def initialize
      @batch_size = 100
      @publish_proc = ->(event) {
        Rails.logger.info("Publishing event #{event.id}: #{event.event_type} - #{event.payload}")
      }
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
