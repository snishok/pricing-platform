# 10) Risk Register

## Top risks and mitigation

### R1: CSV data quality drift from stores

- Impact: ingestion errors, partial updates, unreliable analytics
- Mitigation:
  - strict column validation
  - upload failure reporting
  - schema contract communication with upstream teams

### R2: Search/index inconsistency with DB

- Impact: stale or incomplete search results
- Mitigation:
  - DB-as-truth rehydration path
  - write-after-commit index sync
  - fallback search path in Postgres

### R3: Performance degradation at growth peaks

- Impact: slow search and delayed uploads
- Mitigation:
  - partitioning strategy
  - autoscaling API
  - cache tuning and query/index optimization

### R4: Privilege misuse or weak credential hygiene

- Impact: unauthorized changes or data exposure
- Mitigation:
  - RBAC and scoped roles
  - credential rotation and audit reviews
  - SSO and MFA integration in production

### R5: Operational complexity across environments

- Impact: deployment failures and long recovery
- Mitigation:
  - GitOps promotion discipline
  - environment overlays and immutable artifacts
  - runbook-based incident handling
