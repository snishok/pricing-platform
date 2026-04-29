# 3) Design Decisions

## Decision log (architectural)

### DD-01: Use SPA + API split

- **Decision**: Single page application frontend with independent API backend.
- **Why**: Clear separation of concerns, independent scaling, and simpler team ownership.
- **Trade-off**: Added integration surface (contracts, auth token handling).

### DD-02: Postgres as source of truth

- **Decision**: Persist all canonical records in PostgreSQL.
- **Why**: Strong consistency, transactional updates, reliable auditing.
- **Trade-off**: Search latency for complex text queries would be higher without a dedicated index.

### DD-03: Dedicated search engine (Typesense)

- **Decision**: Index records in Typesense for low-latency filtering/faceting/suggestions.
- **Why**: Better search UX for large catalog and distributed store data.
- **Trade-off**: Eventual consistency concerns between DB and index; mitigated with post-write index updates and DB fallback.

### DD-04: Chunked CSV ingestion with upsert semantics

- **Decision**: Read CSV in chunks and upsert by natural business key.
- **Why**: Handles large files safely, supports idempotent reprocessing, avoids duplicate growth.
- **Trade-off**: Requires careful key design and deduplication handling.

### DD-05: Role-based access control (RBAC)

- **Decision**: Distinct roles (`admin`, `viewer`, `editor`, `uploader`).
- **Why**: Least privilege in global retail operations.
- **Trade-off**: Added permission complexity in API and UI behavior.

### DD-06: Immutable audit records for edits

- **Decision**: Capture old/new values and actor metadata on updates.
- **Why**: Compliance, accountability, forensic traceability.
- **Trade-off**: Additional storage and write overhead.

### DD-07: Cache response metadata and search responses

- **Decision**: Cache selected search results and metadata.
- **Why**: Reduce repeated query load and stabilize response time.
- **Trade-off**: Cache invalidation complexity; addressed via explicit invalidation on write paths.

### DD-08: Multi-env GitOps deployment

- **Decision**: Kustomize overlays plus Argo CD-driven promotion.
- **Why**: Repeatable, auditable environment progression.
- **Trade-off**: Requires platform maturity and disciplined release process.
