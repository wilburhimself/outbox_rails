# OutboxRails: Rails Outbox Pattern with Production Observability

A production-ready implementation of the Outbox Pattern packaged as a Ruby Gem / Rails Engine, featuring comprehensive observability, metrics reporting, and alerting based on [this blog post](https://wilburhimself.github.io/blog/50-after-the-outbox/).

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [The Four Critical Metrics](#the-four-critical-metrics)
- [Background Workers](#background-workers)
- [Monitoring & Alerts](#monitoring--alerts)
- [The Outbox Runbook](#the-outbox-runbook)
- [Testing & Development](#testing--development)
- [Production Scaling & Maintenance](#production-scaling--maintenance)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Outbox Pattern solves transactional consistency in distributed systems (guaranteeing that business database updates and outbound event publications happen atomically) but creates a critical piece of infrastructure that requires deep observability. 

This engine provides:
- ✅ **Transactional consistency** - Events are stored atomically with business data.
- ✅ **At-least-once delivery** - Guaranteed event publishing with background job retries.
- ✅ **Idempotency** - Duplicate prevention via unique database constraint keys.
- ✅ **Concurrency control** - Multiple concurrent processors supported using `SKIP LOCKED`.
- ✅ **Production observability** - Four critical metrics tracked automatically.
- ✅ **Sentry integration** - Automatic breadcrumb reporting and performance tracing.

---

## Installation

Add the gem to your application's `Gemfile`:

```ruby
gem "outbox_rails"
```

Then run the installation generator to copy the migrations to your host application and migrate the database:

```bash
# Copy migrations
bin/rails outbox_rails:install:migrations

# Run migrations
bin/rails db:migrate
```

---

## Configuration

Configure the gem by creating an initializer in your host application:

```ruby
# config/initializers/outbox_rails.rb
OutboxRails.configure do |config|
  # Number of events to process in each batch (default: 100)
  config.batch_size = 100

  # Define how events are published to your message broker (e.g. Kafka, RabbitMQ, AWS SNS, HTTP)
  config.publish_proc = ->(event) do
    # Replace with your actual broker/HTTP publisher. E.g.:
    # KafkaProducer.publish(
    #   topic: event.event_type,
    #   key: event.idempotency_key,
    #   payload: event.payload
    # )
    Rails.logger.info("Publishing event #{event.id}: #{event.event_type} - #{event.payload}")
  end
end
```

---

## Usage

### Publishing Events

Publish events transactionally alongside your business data:

```ruby
ActiveRecord::Base.transaction do
  user = User.create!(email: "user@example.com", name: "User")
  
  # Simple usage (generates a UUID idempotency key automatically)
  OutboxRails::Publisher.publish("user.created", { user_id: user.id, email: user.email })
end
```

#### With Custom Idempotency Key
Specify a custom key to prevent duplicate publishing on the business level:

```ruby
OutboxRails::Publisher.publish(
  "order.completed",
  { order_id: 456, total: 99.99 },
  idempotency_key: "order-completed-456"
)
```

### Checking Queue Status

You can query the database directly using the namespaced engine model:

```ruby
# Count pending events
OutboxRails::OutboxEvent.pending.count

# Inspect recent failures
OutboxRails::OutboxEvent.failed.where("updated_at > ?", 1.hour.ago).count

# Retrieve the oldest pending event
oldest = OutboxRails::OutboxEvent.pending.order(created_at: :asc).first
```

---

## The Four Critical Metrics

### 1. Queue Age ⚠️ (Most Critical)
* **Definition**: `Time.current - oldest_pending_event.created_at`
* **Why**: The primary metric indicating if the pipeline is broken. A high age means the processor is stalled.
* **Alert Threshold**: `> 300 seconds (5 minutes)`

### 2. Queue Depth
* **Definition**: Total count of events in `pending` status.
* **Why**: Indicates overall load. High depth with low age means the system is busy but functioning. High depth with high age means it is broken.
* **Alert Threshold**: `> 3 × baseline`

### 3. Processing Latency (p95)
* **Definition**: Time from event creation (`created_at`) to publication (`published_at`).
* **Why**: Monitors performance. Spikes usually signal downstream broker slowdowns.
* **Alert Threshold**: `> 3 × baseline`

### 4. Error Rate
* **Definition**: `(failed_events / total_processed) × 100` over the last hour.
* **Why**: Detects systemic downstream errors or parsing/serialization issues.
* **Alert Threshold**: `> 5%`

---

## Background Workers

### Event Processing
Whenever an event is published via `OutboxRails::Publisher`, an `OutboxRails::PublishJob` is automatically enqueued after the database transaction commits (utilizing `self.enqueue_after_transaction_commit = true`).

Ensure your queue processor (e.g. Solid Queue, Sidekiq) is running:
```bash
bin/jobs
```

### Periodic Metrics Collection
To report the four critical observability metrics to Sentry, configure the `OutboxRails::MetricsJob` to run periodically (e.g. every minute). 

For Solid Queue recurring jobs, edit `config/recurring.yml`:
```yaml
production:
  outbox_metrics_reporting:
    class: OutboxRails::MetricsJob
    queue: default
    schedule: every minute
```

---

## Monitoring & Alerts

The gem communicates with Sentry to log transaction spans and distribute metric indicators via breadcrumbs.

### Alert Configuration in Sentry
Configure metric alerts in your Sentry console matching these thresholds:
1. **Queue Age**: `max(outbox.queue_age_seconds) > 300` for 5 minutes.
2. **Error Rate**: `outbox.error_rate_percentage > 5` for 10 minutes.
3. **Zero Throughput**: No publications registered in 15 minutes.

---

## The Outbox Runbook

### Alert Fires: `Queue Age > 300 seconds`

#### Step 1: Assess (First 2 minutes)
1. Check if background workers are processing jobs:
   ```ruby
   # Check remaining default jobs
   SolidQueue::Job.where(queue_name: 'default').count
   ```
2. Check the queue depth trend:
   - **Steadily climbing** $\rightarrow$ Worker/processor is down or locked.
   - **Flat but high** $\rightarrow$ Processor is running but bottlenecked.
3. Search Sentry for new exceptions in `OutboxRails::Processor`.

#### Step 2: Isolate (Next 5 minutes)
* **If Processor is Down**:
  ```bash
  # Restart background workers
  bin/rails solid_queue:restart
  
  # Check for a blocking/poison message
  bin/rails runner "puts OutboxRails::OutboxEvent.pending.order(:created_at).first.inspect"
  ```
* **If Processor is Running**:
  Check for locking issues in your PostgreSQL database:
  ```sql
  -- Check for DB lock contention
  SELECT * FROM pg_locks WHERE relation = 'outbox_rails_events'::regclass;

  -- Check for long-running queries
  SELECT pid, now() - query_start as duration, query 
  FROM pg_stat_activity 
  WHERE query LIKE '%outbox_rails_events%' 
  ORDER BY duration DESC;
  ```

#### Step 3: Remediate (Next 15 minutes)
* **Poison Message**: Flag the message as failed to allow the queue to progress, then inspect:
  ```ruby
  OutboxRails::OutboxEvent.pending.order(:created_at).first.update!(status: :failed)
  ```
* **DB Lock Contention**: Terminate the query causing the database block.
* **Downstream Outage**: Broker (Kafka/AWS) is down; pause processing until restored.

---

## Testing & Development

If you are contributing to this gem, you can run database migrations and execute the test suite against the local test dummy application:

```bash
# Prep test database
bin/rails db:test:prepare

# Run all tests
bin/rails test test:system
```

---

## Production Scaling & Maintenance

### Horizontal Scaling
- Scale out background workers.
- The PostgreSQL `SKIP LOCKED` lock strategy guarantees that concurrent workers will never grab the same pending batch events.

### Maintenance Tasks
Clean up published events to prevent database bloat (e.g. via a daily cron/runner script):
```ruby
# Archive events older than 30 days
OutboxRails::OutboxEvent.where("published_at < ?", 30.days.ago).delete_all
```

---

## Troubleshooting

### Events are pending and not being processed
1. Verify background workers are running.
2. Manually trigger processing to trace issues:
   ```ruby
   OutboxRails::Processor.new.process_batch
   ```
3. Check application logs for metric logs prefixed with `[METRIC]`.

---

## Tech Stack
- **Ruby** >= 3.0
- **Rails** >= 8.0.0
- **PostgreSQL** (highly recommended for production concurrency locks via `SKIP LOCKED`)

## License
MIT
