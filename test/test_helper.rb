ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "rails/test_help"
require "ostruct"

# Stub Sentry for tests
module Sentry
  class FakeScope
    def set_tags(*args); end
  end

  class FakeTransaction
    def set_status(*args); end
    def finish; end
  end

  class << self
    def with_scope
      yield FakeScope.new
    end

    def start_transaction(op:, name:)
      FakeTransaction.new
    end

    def add_breadcrumb(*)
      # no-op
    end
  end

  class Breadcrumb
    def initialize(*); end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
