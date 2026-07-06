require "test_helper"

class OutboxPublishJobTest < ActiveJob::TestCase
  test "processes pending events" do
    event = OutboxRails::OutboxEvent.create!(event_type: "test", payload: { foo: "bar" }, status: :pending)

    OutboxRails::PublishJob.perform_now

    event.reload
    assert_equal "published", event.status
    assert_not_nil event.published_at
    assert_not_nil event.processor_id
  end

  test "handles multiple events in batch" do
    events = 5.times.map do |i|
      OutboxRails::OutboxEvent.create!(event_type: "test", payload: { index: i }, status: :pending)
    end

    OutboxRails::PublishJob.perform_now

    events.each do |event|
      event.reload
      assert_equal "published", event.status
    end
  end

  test "sets processor_id on events" do
    event = OutboxRails::OutboxEvent.create!(event_type: "test", payload: { foo: "bar" }, status: :pending)

    OutboxRails::PublishJob.perform_now

    event.reload
    assert_not_nil event.processor_id
    assert_match(/\A[0-9a-f]{8}\z/, event.processor_id)
  end
end
