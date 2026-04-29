# 7) Capacity and Scaling Model

## Sizing model (initial)

- Stores: 3000
- Daily records per store (avg): 500 to 5000 (depends on assortment)
- Daily ingest volume:
  - Low case: 1.5M rows/day
  - Mid case: 6M rows/day
  - High case: 15M rows/day

## Throughput expectations

- Ingestion:
  - Burst uploads around business open/close windows
  - Chunked writes and upserts reduce transaction pressure
- Search:
  - Read-heavy traffic from analysts and operations users
  - Facets + suggestions optimized by search index

## Scaling strategy

### API tier

- Horizontal pod autoscaling by CPU and request latency
- Stateless service design allows linear scale-out

### Postgres

- Start with vertical scaling + connection pooling
- Add partitioning by `date` as data grows
- Use retention and archival strategy for cold history

### Search tier

- Scale Typesense nodes based on query latency and index size
- Rebuild index from DB snapshot if needed

### Cache tier

- Redis sizing based on key count, TTL, and hit ratio
- Use cache eviction policy tuned for search metadata patterns

## Performance guardrails

- Keep p95 search latency under interactive threshold
- Track ingest rows/min and failed row rate
- Alert on DB slow query percentile and index lag indicators
