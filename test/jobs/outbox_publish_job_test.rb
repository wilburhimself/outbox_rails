require "test_helper"

class OutboxPublishJobTest < ActiveJob::TestCase
  test "processes pending events" do
    event = OutboxEvent.create!(event_type: "test", payload: { foo: "bar" }, published: false)
    
    perform_enqueued_jobs do
      OutboxPublishJob.perform_now
    end
    
    event.reload
    assert event.published?
  end
end
