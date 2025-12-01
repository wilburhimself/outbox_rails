class OutboxEvent < ApplicationRecord
  scope :pending, -> { where(published: false) }
end
