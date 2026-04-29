# 4) Non-Functional Requirements and Design Response

## NFR baseline for a 3000-store multi-country chain

### Availability and reliability

- Target:
  - 99.9%+ monthly availability for user-facing APIs
  - Graceful degradation when search index is unavailable
- Design response:
  - Stateless API service suitable for horizontal scaling
  - Read fallback from Typesense to Postgres
  - Health/readiness endpoints for orchestrator-driven self-healing
  - Retry logic for startup dependencies

### Performance and scalability

- Target:
  - Fast search response under interactive workloads
  - Ingestion that can process high-volume daily store feeds
- Design response:
  - Search served by dedicated index with facets/suggestions
  - Chunked CSV ingestion to avoid memory spikes
  - DB indexes including trigram and BRIN for fallback and time-range efficiency
  - Partition-ready pricing table for large data growth
  - Response caching for repeated search/meta requests

### Data integrity and consistency

- Target:
  - No duplicate business records for same store/SKU/date combination
  - Controlled consistency between DB and search index
- Design response:
  - Unique key enforced on `(country_code, store_id, sku, date)`
  - Upsert semantics for re-upload/idempotency
  - Index synchronization after database commit
  - DB remains the canonical source in query hydration path

### Security and access control

- Target:
  - Principle of least privilege
  - Strong authentication and protected APIs
  - Abuse protection
- Design response:
  - JWT-based user authentication
  - RBAC role checks for upload/edit/admin operations
  - API key support for automation use cases
  - Request rate limiting at application layer
  - Centralized exception handling to avoid data leakage

### Auditability and compliance

- Target:
  - Full traceability for manual edits and uploaded feed processing
- Design response:
  - Audit trail with actor identity and old/new payload snapshots
  - Upload manifest with file hash, source, status, and error report
  - Structured logging integration pattern for SIEM ingestion

### Operability and maintainability

- Target:
  - Rapid diagnosis and low operational toil
  - Predictable promotion from dev to prod
- Design response:
  - Standard health endpoints and explicit readiness checks
  - Infra-as-code via Kubernetes manifests and overlays
  - GitHub Actions CI/CD and GitOps-compatible Argo definitions
  - Separation by modules (API/service/repository/core)

### Globalization and multi-country readiness

- Target:
  - Cross-country data handling with country and currency awareness
- Design response:
  - Country and currency fields in canonical model
  - Configurable default country/currency for ingestion pipeline
  - Extensible model for future locale and tax policy expansion

### Disaster recovery and resilience

- Target:
  - Recoverable operations for critical pricing data
- Design response:
  - Database-centric persistence model supports backup/restore strategy
  - Search index is rebuildable from canonical database state
  - Environment overlays support multi-cluster deployment evolution

### Cost efficiency

- Target:
  - Reasonable cost at scale with predictable growth path
- Design response:
  - Horizontal scaling for stateless services
  - Partitioning and retention controls for long-term data volume
  - Cache and indexing reduce expensive repeated DB scans
