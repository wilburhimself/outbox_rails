#!/usr/bin/env ruby
# Verification script for Outbox Pipeline implementation
# Run with: bin/rails runner script/verify_outbox.rb

puts "=" * 80
puts "Outbox Pipeline Verification Script"
puts "=" * 80
puts

# 1. Check database schema
puts "1. Checking database schema..."
required_columns = %w[id event_type payload status published_at processor_id idempotency_key created_at updated_at]
actual_columns = OutboxEvent.column_names

missing_columns = required_columns - actual_columns
if missing_columns.empty?
  puts "   ✅ All required columns present"
else
  puts "   ❌ Missing columns: #{missing_columns.join(', ')}"
end
puts

# 2. Check indexes
puts "2. Checking database indexes..."
connection = ActiveRecord::Base.connection
indexes = connection.indexes(:outbox_events)
index_columns = indexes.map(&:columns).flatten.uniq

required_indexes = %w[status processor_id idempotency_key]
missing_indexes = required_indexes - index_columns

if missing_indexes.empty?
  puts "   ✅ All required indexes present"
  indexes.each do |idx|
    puts "      - #{idx.name}: #{idx.columns.join(', ')}#{idx.unique ? ' (UNIQUE)' : ''}"
  end
else
  puts "   ❌ Missing indexes on: #{missing_indexes.join(', ')}"
end
puts

# 3. Test event creation
puts "3. Testing event creation..."
begin
  event = OutboxEvent.create!(
    event_type: "test.verification",
    payload: { timestamp: Time.current.to_i }
  )

  if event.persisted? && event.idempotency_key.present?
    puts "   ✅ Event created successfully"
    puts "      - ID: #{event.id}"
    puts "      - Status: #{event.status}"
    puts "      - Idempotency Key: #{event.idempotency_key}"
  else
    puts "   ❌ Event creation failed"
  end

  # Clean up
  event.destroy
rescue => e
  puts "   ❌ Error creating event: #{e.message}"
end
puts

# 4. Test idempotency
puts "4. Testing idempotency..."
begin
  key = "test-#{SecureRandom.hex(8)}"
  event1 = OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: key)

  begin
    event2 = OutboxEvent.create!(event_type: "test", payload: {}, idempotency_key: key)
    puts "   ❌ Duplicate idempotency_key was allowed"
  rescue ActiveRecord::RecordInvalid
    puts "   ✅ Idempotency constraint working"
  end

  # Clean up
  event1.destroy
rescue => e
  puts "   ❌ Error testing idempotency: #{e.message}"
end
puts

# 5. Test processor
puts "5. Testing processor..."
begin
  # Clean up any existing test events first
  OutboxEvent.where(event_type: "test.processor").destroy_all

  # Create test events
  test_events = []
  3.times do |i|
    test_events << OutboxEvent.create!(
      event_type: "test.processor",
      payload: { index: i }
    )
  end

  initial_count = test_events.count
  puts "   - Created #{initial_count} test events"

  # Process batch
  processor = Outbox::Processor.new
  processor.process_batch

  # Check results
  published_count = test_events.count { |e| e.reload.status == "published" }

  if published_count > 0
    puts "   ✅ Processor working (processed #{published_count} events)"
  else
    puts "   ❌ Processor did not process any events"
  end

  # Clean up
  OutboxEvent.where(event_type: "test.processor").destroy_all
rescue => e
  puts "   ❌ Error testing processor: #{e.message}"
  puts "      #{e.backtrace.first}"
  # Clean up on error
  OutboxEvent.where(event_type: "test.processor").destroy_all rescue nil
end
puts

# 6. Test metrics reporter
puts "6. Testing metrics reporter..."
begin
  # Create some test data
  OutboxEvent.create!(event_type: "test", payload: {}, status: :pending)
  OutboxEvent.create!(event_type: "test", payload: {}, status: :published, published_at: 1.hour.ago)

  Outbox::MetricsReporter.report
  puts "   ✅ Metrics reporter executed successfully"

  # Clean up
  OutboxEvent.where(event_type: "test").destroy_all
rescue => e
  puts "   ❌ Error testing metrics reporter: #{e.message}"
end
puts

# 7. Check recurring jobs configuration
puts "7. Checking recurring jobs..."
if File.exist?(Rails.root.join("config/recurring.yml"))
  recurring_config = YAML.load_file(Rails.root.join("config/recurring.yml"))

  if recurring_config.dig("production", "outbox_metrics_reporting")
    puts "   ✅ Metrics reporting job configured"
    job_config = recurring_config["production"]["outbox_metrics_reporting"]
    puts "      - Class: #{job_config['class']}"
    puts "      - Schedule: #{job_config['schedule']}"
  else
    puts "   ❌ Metrics reporting job not configured"
  end
else
  puts "   ❌ recurring.yml not found"
end
puts

# 8. Check Sentry configuration
puts "8. Checking Sentry configuration..."
if ENV["SENTRY_DSN"].present?
  puts "   ✅ SENTRY_DSN configured"
  puts "      - Traces Sample Rate: #{ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', '0.1')}"
else
  puts "   ⚠️  SENTRY_DSN not set (optional for development)"
end
puts

# Summary
puts "=" * 80
puts "Verification Complete!"
puts "=" * 80
puts
puts "Next Steps:"
puts "1. Set SENTRY_DSN environment variable for production"
puts "2. Configure alerts in Sentry (see docs/OUTBOX_OBSERVABILITY.md)"
puts "3. Start background workers: bin/jobs"
puts "4. Monitor metrics in logs or Sentry"
puts
puts "Documentation:"
puts "- Setup Guide: docs/SETUP.md"
puts "- Observability Guide: docs/OUTBOX_OBSERVABILITY.md"
puts "- Implementation Summary: docs/IMPLEMENTATION_SUMMARY.md"
puts
