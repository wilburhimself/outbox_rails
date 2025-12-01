# Rails Outbox Pattern with Production Observability

A production-ready implementation of the Outbox Pattern for Rails with comprehensive observability, monitoring, and alerting based on [this](https://wilburhimself.github.io/blog/38-the-outbox-pattern-reliable-event-publishing-without-distributed-transactions/) and [this blog post](https://wilburhimself.github.io/blog/50-after-the-outbox/).

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [The Four Critical Metrics](#the-four-critical-metrics)
- [Usage](#usage)
- [Configuration](#configuration)
- [Monitoring & Alerts](#monitoring--alerts)
- [The Outbox Runbook](#the-outbox-runbook)
- [Testing](#testing)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

## Overview

The Outbox Pattern solves transactional consistency in distributed systems but creates critical infrastructure that requires deep observability. This implementation provides:

- ✅ **Transactional consistency** - Events stored atomically with business data
- ✅ **At-least-once delivery** - Guaranteed event publishing with retries
- ✅ **Idempotency** - Duplicate prevention via unique keys
- ✅ **Concurrency control** - Multiple workers with `SKIP LOCKED`
- ✅ **Production observability** - Four critical metrics tracked automatically
- ✅ **Sentry integration** - Error tracking and performance monitoring
- ✅ **Forensic runbooks** - Decision trees for incident response

## Quick Start

```bash
# Install dependencies
bundle install

# Setup database and run migrations
bin/rails db:setup
bin/rails db:migrate

# Verify installation
bin/rails runner script/verify_outbox.rb

# Start the server
bin/rails server

# Start background workers (in another terminal)
bin/jobs
```

## Architecture

### Core Components

1. **OutboxEvent Model** (`app/models/outbox_event.rb`)
   - Stores events with status tracking (pending, processing, published, failed)
   - Auto-generates idempotency keys
   - Indexed for efficient querying

2. **Outbox::Publisher** (`app/services/outbox/publisher.rb`)
   - Creates events transactionally
   - Triggers background processing
   - Supports custom idempotency keys

3. **Outbox::Processor** (`app/services/outbox/processor.rb`)
   - Processes events in batches (100 by default)
   - Uses `SKIP LOCKED` for concurrency
   - Sentry transaction wrapping
   - Tracks processing latency

4. **Outbox::MetricsReporter** (`app/services/outbox/metrics_reporter.rb`)
   - Reports queue_age, queue_depth, error_rate
   - Runs every minute via OutboxMetricsJob

5. **OutboxPublishJob** (`app/jobs/outbox_publish_job.rb`)
   - Background job for event processing
   - Enqueued after transaction commit

6. **OutboxMetricsJob** (`app/jobs/outbox_metrics_job.rb`)
   - Periodic metrics collection
   - Configured in `config/recurring.yml`

### Database Schema

```ruby
create_table :outbox_events do |t|
  t.string :event_type, null: false
  t.json :payload, null: false, default: {}
  t.integer :status, null: false, default: 0  # enum: pending, processing, published, failed
  t.datetime :published_at
  t.string :processor_id
  t.string :idempotency_key, null: false      # unique index
  t.timestamps
end
```

## The Four Critical Metrics

### 1. Queue Age ⚠️ (Most Critical)

**What:** `Time.now - oldest_pending_event.created_at`

**Why:** Primary "is it broken?" metric. High age = stalled processor.

**Alert Threshold:** `> 300 seconds (5 minutes)`

### 2. Queue Depth

**What:** Number of events in `pending` status

**Why:** Shows load. High depth with low age = busy system. High depth with high age = broken system.

**Alert Threshold:** `> 3 × baseline`

### 3. Processing Latency (p95)

**What:** Time from `event.created_at` to `event.published_at`

**Why:** Shows performance. Spikes indicate downstream issues.

**Alert Threshold:** `> 3 × baseline`

### 4. Error Rate

**What:** `(failed_events / total_processed) × 100` over last hour

**Why:** Detects systemic downstream failures.

**Alert Threshold:** `> 5%`

## Usage

### Publishing Events

```ruby
# Simple usage (auto-generated idempotency key)
Outbox::Publisher.publish("user.created", { user_id: 123, email: "user@example.com" })

# With custom idempotency key (recommended for business-level idempotency)
Outbox::Publisher.publish(
  "order.completed",
  { order_id: 456, total: 99.99 },
  idempotency_key: "order-completed-456"
)
```

### Manual Processing

```ruby
# Process a batch manually
processor = Outbox::Processor.new
processor.process_batch

# Report metrics manually
Outbox::MetricsReporter.report
```

### Checking Queue Status

```ruby
# Check pending events
OutboxEvent.pending.count

# Check oldest event
oldest = OutboxEvent.pending.order(:created_at).first
queue_age = oldest ? (Time.current - oldest.created_at) : 0

# Check recent failures
OutboxEvent.failed.where("updated_at > ?", 1.hour.ago).count
```

## Configuration

### Environment Variables

```bash
# Required for production
SENTRY_DSN=https://your-key@sentry.io/project-id

# Optional (defaults shown)
SENTRY_TRACES_SAMPLE_RATE=0.1      # 10% of transactions
SENTRY_PROFILES_SAMPLE_RATE=0.1    # 10% of profiles
SENTRY_ENVIRONMENT=production
SENTRY_RELEASE=outbox_rails@v1.0.0
```

### Recurring Jobs

Edit `config/recurring.yml`:

```yaml
production:
  outbox_metrics_reporting:
    class: OutboxMetricsJob
    queue: default
    schedule: every minute  # Adjust as needed (every 30 seconds, etc.)
```

### Processor Configuration

Edit `app/services/outbox/processor.rb`:

```ruby
BATCH_SIZE = 100  # Increase for higher throughput
```

## Monitoring & Alerts

### Sentry Alert Configuration

#### 1. Queue Age Alert (Critical)
```
Metric: max(outbox.queue_age_seconds) > 300
Duration: 5 minutes
Action: Page on-call engineer
```

#### 2. Error Rate Alert (High)
```
Metric: outbox.error_rate_percentage > 5
Duration: 10 minutes
Action: Notify team channel
```

#### 3. Zero Throughput Alert (Critical)
```
Metric: No successful publications in 15 minutes
Action: Page on-call engineer
```

### Viewing Metrics

**In Logs:**
```bash
tail -f log/production.log | grep METRIC
```

**In Sentry:**
- Navigate to Performance → Transactions
- Look for `OutboxProcessor` transactions
- Check breadcrumbs for metric values

## The Outbox Runbook

### Alert Fires: `Queue Age > 300 seconds`

#### First 2 Minutes: Assess

1. **Is the processor running?**
   ```bash
   # Check Solid Queue jobs
   bin/rails runner "puts SolidQueue::Job.where(queue_name: 'default').count"
   ```

2. **Check queue_depth graph:**
   - **Steadily climbing** → Processor down or stuck
   - **Flat but high** → Processor working but can't keep up

3. **Check Sentry for new errors** from `OutboxProcessor`

#### Next 5 Minutes: Isolate

**If Processor is Down:**
```bash
# Restart workers
bin/rails solid_queue:restart

# If it fails again, check for poison message
bin/rails runner "puts OutboxEvent.pending.order(:created_at).first.inspect"
```

**If Processor is Running:**
```sql
-- Check for DB lock contention
SELECT * FROM pg_locks WHERE relation = 'outbox_events'::regclass;

-- Check for long-running queries
SELECT pid, now() - query_start as duration, query 
FROM pg_stat_activity 
WHERE query LIKE '%outbox_events%' 
ORDER BY duration DESC;
```

#### Next 15 Minutes: Remediate

- **Poison Message:** Mark as failed and investigate
  ```ruby
  OutboxEvent.pending.order(:created_at).first.update!(status: :failed)
  ```
- **DB Stall:** Kill blocking query
- **Downstream Outage:** Escalate to owning team

### Common Failure Patterns

**Pattern 1: The Sudden Stop**
- Symptoms: queue_depth climbs linearly, queue_age climbs with real time
- Cause: Processor crashed (bad deploy, faulty dependency)
- Fix: Rollback or fix code issue

**Pattern 2: The Slow Burn**
- Symptoms: queue_depth stable, p95_latency climbs, retry_rate jumps
- Cause: Downstream consumer intermittently failing
- Fix: Identify and fix downstream service

## Testing

```bash
# Run all tests
bin/rails test

# Run verification script
bin/rails runner script/verify_outbox.rb

# Run specific test
bin/rails test test/models/outbox_event_test.rb
```

## Production Deployment

### Pre-Deployment Checklist

- [ ] Set `SENTRY_DSN` environment variable
- [ ] Configure Sentry alerts (queue_age, error_rate, zero throughput)
- [ ] Verify database indexes exist
- [ ] Configure process manager for background workers
- [ ] Set up log aggregation
- [ ] Plan for event archival (> 30 days)

### Deployment Steps

1. **Deploy application:**
   ```bash
   # Your deployment process (Kamal, Capistrano, etc.)
   ```

2. **Run migrations:**
   ```bash
   bin/rails db:migrate
   ```

3. **Start background workers:**
   ```bash
   # Example systemd service
   sudo systemctl start outbox-workers
   ```

4. **Verify metrics:**
   ```bash
   bin/rails runner "Outbox::MetricsReporter.report"
   ```

### Scaling Considerations

**Horizontal Scaling:**
- Run multiple Solid Queue workers
- `SKIP LOCKED` prevents duplicate processing
- Each processor has unique ID for tracing

**Vertical Scaling:**
- Increase `BATCH_SIZE` for higher throughput
- Monitor DB connection pool usage
- Consider table partitioning for > 1M events/day

### Maintenance Tasks

```ruby
# Archive old events (run daily)
OutboxEvent.where("published_at < ?", 30.days.ago).delete_all

# Check table size
ActiveRecord::Base.connection.execute(
  "SELECT pg_size_pretty(pg_total_relation_size('outbox_events'))"
)
```

## Troubleshooting

### Events Not Processing

1. Check workers are running: `ps aux | grep solid_queue`
2. Check for errors: `tail -f log/production.log`
3. Check Sentry for exceptions
4. Run processor manually: `bin/rails runner "Outbox::Processor.new.process_batch"`

### High Queue Age

1. Check queue depth: `OutboxEvent.pending.count`
2. Check oldest event: `OutboxEvent.pending.order(:created_at).first`
3. Follow [The Outbox Runbook](#the-outbox-runbook)

### Database Performance

```sql
-- Check for missing indexes
EXPLAIN ANALYZE 
SELECT * FROM outbox_events 
WHERE status = 0 
ORDER BY created_at 
LIMIT 100;

-- Should use index_outbox_events_on_status
```

### Integration Issues

Update `app/services/outbox/processor.rb` to integrate your message broker:

```ruby
def publish_event(event)
  # Replace with your actual broker
  KafkaProducer.publish(
    topic: event.event_type,
    key: event.idempotency_key,
    payload: event.payload
  )
end
```

## Tech Stack

- **Ruby** 3.4.2
- **Rails** 8.0.3
- **PostgreSQL** (required for `SKIP LOCKED`)
- **Solid Queue** - Background job processing
- **Sentry** - Error tracking and monitoring

## Resources

- [Blog Post: Production Observability for Rails Outbox Pipelines](https://wilburhimself.github.io/blog/50-after-the-outbox/)
- [The Outbox Pattern](https://wilburhimself.github.io/blog/38-the-outbox-pattern-reliable-event-publishing-without-distributed-transactions/)
- [Sentry Ruby Documentation](https://docs.sentry.io/platforms/ruby/)
- [Solid Queue Documentation](https://github.com/basecamp/solid_queue)

## License

MIT
