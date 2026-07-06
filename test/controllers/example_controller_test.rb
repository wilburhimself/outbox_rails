require_relative "../test_helper"

class ExampleControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "create action publishes event" do
    assert_difference "OutboxRails::OutboxEvent.count", 1 do
      post example_index_path
    end

    assert_redirected_to example_index_path
    assert_equal "Event published!", flash[:notice]

    event = OutboxRails::OutboxEvent.last
    assert_equal "user_created", event.event_type
    assert_not event.published?

    # Verify job is enqueued
    assert_enqueued_with(job: OutboxRails::PublishJob)
  end
end
