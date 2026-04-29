# 9) Operability, SLO, and Runbook

## Suggested SLOs

- API availability:
  - 99.9% monthly success ratio for critical endpoints
- Search latency:
  - p95 under 500 ms for common filtered searches
- Ingestion success:
  - 99%+ uploads processed without manual intervention
- Data freshness:
  - Search index update lag under agreed threshold after successful upload

## Golden signals

- Latency
- Traffic
- Errors
- Saturation

## Key dashboards

- API request rate, p50/p95 latency, 4xx/5xx breakdown
- CSV upload counts, success/failure trend, average processing duration
- Search latency and fallback rate to Postgres
- DB health: CPU, connections, slow queries, storage growth
- Cache hit ratio and memory pressure

## Alert examples

- High 5xx error rate for upload or search endpoint
- Search fallback rate spikes above baseline
- DB connection saturation risk
- Index sync failures after write operations

## Runbook (first-response)

1. Confirm service health via `/api/healthz` and `/api/readyz`
2. Check latest deployment and rollback if regression suspected
3. Identify failing dependency (DB, cache, search)
4. If search degraded, verify DB fallback still serving user queries
5. For ingestion failures:
   - inspect upload error reports
   - replay failed files after correction
6. Communicate incident status and ETA to stakeholders
