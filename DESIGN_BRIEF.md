# Design Brief

## Understanding the Problem

The goal is a backend service that ingests GitHub Push activity from the public events API, stores it durably, and enriches it with actor and repository metadata. The service needs to run unattended in Docker, behave predictably under rate limits, and produce clean logs so an operator can understand what it's doing without reading the code.

The main constraints that shaped the design:

- No authentication token means 60 requests per hour to the GitHub API. Every additional call for enrichment eats into that budget.
- The public events endpoint is shared across all unauthenticated clients, so we need to be a polite consumer — avoid hammering it and respect the signals GitHub sends back.
- The system should be restartable without corrupting or duplicating data.

## Architecture

A standard Rails 8 API-only application with PostgreSQL. No separate message queue or background worker process — ingestion runs as a Rake task, either as a one-shot job or a polling loop controlled by an environment variable.

**Core components:**

`Github::Client` handles all HTTP communication. It sends `If-None-Match` headers with the ETag from the previous response, which lets GitHub return a 304 when nothing has changed. A 304 uses no rate limit budget and saves processing. The client parses the `X-RateLimit-*` headers on every response and exposes them to the caller.

`Github::IngestionRunner` orchestrates the polling loop. Before each cycle it checks whether the remaining rate limit is below a safe threshold. If so, it sleeps until the reset time rather than burning through the last few requests. In continuous mode it sleeps 60 seconds between cycles.

`Github::EventProcessor` filters the raw event list for `PushEvent` items, persists each one, and hands off to the enricher. It checks for existing records before inserting and handles `RecordNotUnique` as a safety net for concurrent runs.

`Github::Enricher` fetches actor and repository details using the URLs embedded in each event payload. Before making any API call, it checks whether we already have a record with a `fetched_at` within the last 24 hours. In a batch of 30 events, the same actors and repositories appear repeatedly, so this cache hit rate tends to be high. When a fetch is needed, the enricher introduces a 1.5-second delay between calls to spread the requests over time.

**Data model:**

Three tables: `github_events`, `actors`, and `repositories`.

`github_events` stores the raw JSON payload alongside extracted columns for `event_id`, `repo_identifier`, `push_id`, `ref`, `head`, and `before`. Having these as first-class columns means analysts can query and filter without touching JSONB operators. The `event_id` column has a unique index — this is the primary idempotency mechanism.

`actors` and `repositories` are keyed on `github_id` (unique index). They store a `fetched_at` timestamp used to determine staleness and a `raw_payload` column with the full API response for future use.

`github_events` holds foreign keys to both tables and is populated after enrichment. If enrichment fails, the event record still exists with null foreign keys — it can be enriched later.

## Key Tradeoffs

**Synchronous enrichment vs. background jobs.** Enrichment happens inline during the ingestion cycle. This keeps the system simple — one process, no queue, no Redis dependency. The downside is that each enrichment call adds latency to the ingestion cycle. For the unauthenticated rate limit (60 req/hour) and typical event volume, this is acceptable. If volume increased or a token was added, background jobs (e.g., Solid Queue) would be a straightforward addition.

**Rate limit budget allocation.** With 60 requests per hour and each cycle consuming 1 request for the events list plus up to N requests for enrichment, the service can exhaust its budget quickly if every event involves a new actor and repository. The staleness cache mitigates this. In the worst case (all-new actors and repos), the enricher delays deliberately to spread calls out. The runner also refuses to start a new enrichment cycle if the remaining budget is below the threshold.

**24-hour actor/repo cache.** This is an assumption that actor profiles and repository metadata are stable enough that a day-old snapshot is acceptable for analytical use. If fresher data mattered, this TTL could be shortened or made configurable.

**No pagination.** The public events endpoint returns a single page (up to 30 events). The GitHub documentation notes that only the most recent events are available and pagination is not meaningful for this endpoint. The ETag mechanism covers the "already seen this page" case.

## Rate Limiting and Durability

On every response, the client reads `X-RateLimit-Remaining` and `X-RateLimit-Reset`. If remaining drops below 5, the runner sleeps until the reset timestamp plus a small buffer. This prevents the service from returning 403 errors that would complicate error handling and logging.

ETag handling means that in a continuous polling loop, most cycles will receive a 304 response and return immediately, consuming no budget and no processing.

For durability: events are committed to PostgreSQL before enrichment begins. An enrichment failure does not roll back the event. A process crash mid-cycle will result in some events being saved and some not, but the next cycle will catch any missed events (they'll still be on the events page) and the unique index prevents duplicates.

## What I Intentionally Did Not Build

- **Authentication.** Adding a GitHub token would raise the rate limit to 5,000 req/hour and make the enrichment fan-out concern largely disappear. The design makes it easy to add — just pass a header in the client.
- **Object storage for avatars.** Storing avatar URLs is straightforward; downloading and re-hosting them adds complexity that isn't justified here.
- **A real-time streaming interface.** The query API serves current data over HTTP. Webhooks or Server-Sent Events could be added if consumers needed push-based delivery.
- **Alerting.** The logs contain enough signal (rate limit warnings, error counts) that a log aggregation tool like Datadog or CloudWatch could generate alerts without additional instrumentation.
