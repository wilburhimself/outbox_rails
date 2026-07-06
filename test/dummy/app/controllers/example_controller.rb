class ExampleController < ApplicationController
  def index
  end

  def create
    ActiveRecord::Base.transaction do
      OutboxRails::Publisher.publish("user_created", { user_id: SecureRandom.uuid, email: "test-#{Time.now.to_i}@example.com" })
    end
    redirect_to example_index_path, notice: "Event published!"
  end
end
