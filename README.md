# GitHub Ingestor

An internal service that continuously ingests GitHub Push events, enriches them with actor and repository data, and persists everything to PostgreSQL for analysis.

## Requirements

- Docker Desktop (macOS)
- Docker Compose v2+

## Getting Started

### 1. Start the system

```bash
docker compose up --build
```

This starts the PostgreSQL database and the Rails API server. On first run, the database is created and migrations are applied automatically before the server starts.

The API will be available at `http://localhost:3000`.

### 2. Run ingestion (single cycle)

```bash
docker compose run --rm ingest
```

This fetches the current page of public GitHub events, filters for PushEvents, persists them, and enriches each one with actor and repository data. It then exits.

### 3. Run ingestion continuously

```bash
CONTINUOUS=true docker compose run --rm ingest
```

With `CONTINUOUS=true`, the runner polls every 60 seconds. It uses ETags to avoid redundant processing on unchanged responses.

### 4. Run tests

```bash
docker compose run --rm test
```

## How to verify it's working

**Expected log output during ingestion:**

```
[2025-01-15T10:00:00] INFO: [client] Rate limit: 58/60 remaining (resets at 11:00:00)
[2025-01-15T10:00:00] INFO: [processor] 30 events received, 8 are PushEvents
[2025-01-15T10:00:01] INFO: [processor] Saved event 12345678 (PushEvent) for rails/rails
[2025-01-15T10:00:02] INFO: [enricher] Created actor 1234 (tenderlove)
[2025-01-15T10:00:04] INFO: [enricher] Created repository 5678 (rails/rails)
...
[2025-01-15T10:00:10] INFO: [runner] Cycle complete: 8 new events saved out of 30 fetched
```

**Verify database records:**

Connect to the database:

```bash
docker compose exec db psql -U ingestor -d github_ingestor_development
```

Then query:

```sql
-- Count ingested push events
SELECT count(*) FROM github_events WHERE event_type = 'PushEvent';

-- Inspect structured fields
SELECT event_id, repo_name, ref, head, before FROM github_events LIMIT 5;

-- Check enriched actors
SELECT github_id, login, fetched_at FROM actors LIMIT 5;

-- Check enriched repositories
SELECT github_id, full_name, description FROM repositories LIMIT 5;

-- View events with their enriched data
SELECT ge.event_id, ge.repo_name, a.login AS actor, r.full_name
FROM github_events ge
LEFT JOIN actors a ON a.id = ge.actor_id
LEFT JOIN repositories r ON r.id = ge.repository_id
LIMIT 10;
```

**Query via the API:**

```bash
# List recent events
curl http://localhost:3000/api/v1/events

# Filter by repository
curl "http://localhost:3000/api/v1/events?repo=rails/rails"

# Get a specific event with raw payload
curl http://localhost:3000/api/v1/events/12345678
```

**How long to wait:**

A single ingestion cycle completes in under 2 minutes (the enricher introduces a ~1.5s delay per unique actor/repository to stay within the unauthenticated rate limit of 60 requests/hour). If there are no new PushEvents in the current page of public events, the log will show "No new events since last cycle."

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | — | PostgreSQL connection URL |
| `CONTINUOUS` | `false` | Set to `true` to poll indefinitely |
| `LOG_LEVEL` | `info` | Rails log level (`debug`, `info`, `warn`, `error`) |
| `RAILS_LOG_TO_STDOUT` | — | Set to `true` to force stdout logging |

## Project Layout

```
app/
  controllers/api/v1/events_controller.rb  # Query API
  models/                                   # GithubEvent, Actor, Repository
  services/github/
    client.rb           # HTTP, ETags, rate limit parsing
    enricher.rb         # Actor/repository fetch and caching
    event_processor.rb  # Filters, persists, and enriches events
    ingestion_runner.rb # Orchestrates polling and cycle management
db/migrate/             # Schema migrations
lib/tasks/github.rake   # rake github:ingest
spec/                   # RSpec tests
```
