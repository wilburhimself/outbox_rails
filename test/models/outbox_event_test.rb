require "test_helper"

class OutboxEventTest < ActiveSupport::TestCase
  test "pending scope returns only unpublished events" do
    published_event = OutboxRails::OutboxEvent.create!(event_type: "test", payload: {}, status: :published)
    pending_event = OutboxRails::OutboxEvent.create!(event_type: "test", payload: {}, status: :pending)

    assert_includes OutboxRails::OutboxEvent.pending, pending_event
    assert_not_includes OutboxRails::OutboxEvent.pending, published_event
  end

  test "generates idempotency_key automatically" do
    event = OutboxRails::OutboxEvent.create!(event_type: "test", payload: {})

    assert_not_nil event.idempotency_key
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, event.idempotency_key)
  end

  test "accepts custom idempotency_key" do
    custom_key = "custom-key-123"
    event = OutboxRails::OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: custom_key)

    assert_equal custom_key, event.idempotency_key
  end

  test "enforces unique idempotency_key" do
    key = "duplicate-key"
    OutboxRails::OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: key)

    assert_raises(ActiveRecord::RecordInvalid) do
      OutboxRails::OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: key)
    end
  end
end
