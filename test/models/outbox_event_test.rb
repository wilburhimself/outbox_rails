require "test_helper"

class OutboxEventTest < ActiveSupport::TestCase
  test "pending scope returns only unpublished events" do
    published_event = OutboxEvent.create!(event_type: "test", payload: {}, published: true)
    pending_event = OutboxEvent.create!(event_type: "test", payload: {}, published: false)

    assert_includes OutboxEvent.pending, pending_event
    assert_not_includes OutboxEvent.pending, published_event
  end
end
