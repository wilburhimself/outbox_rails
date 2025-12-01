require "test_helper"

class OutboxEventTest < ActiveSupport::TestCase
  test "pending scope returns only unpublished events" do
    published_event = OutboxEvent.create!(event_type: "test", payload: {}, status: :published)
    pending_event = OutboxEvent.create!(event_type: "test", payload: {}, status: :pending)

    assert_includes OutboxEvent.pending, pending_event
    assert_not_includes OutboxEvent.pending, published_event
  end

  test "generates idempotency_key automatically" do
    event = OutboxEvent.create!(event_type: "test", payload: {})

    assert_not_nil event.idempotency_key
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, event.idempotency_key)
  end

  test "accepts custom idempotency_key" do
    custom_key = "custom-key-123"
    event = OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: custom_key)

    assert_equal custom_key, event.idempotency_key
  end

  test "enforces unique idempotency_key" do
    key = "duplicate-key"
    OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: key)

    assert_raises(ActiveRecord::RecordInvalid) do
      OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: key)
    end
  end
end
