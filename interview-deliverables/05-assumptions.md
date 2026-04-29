# 5) Assumptions

## Business assumptions

- Each pricing row is a daily observation for a `store_id + sku + date`.
- Store feeds are trusted to provide valid identifiers, but payload quality can vary.
- Edits are operational corrections and must remain auditable.
- The platform is internal-facing for retail operations staff.

## Data assumptions

- CSV headers are exact and required:
  - `store_id`, `sku`, `product_name`, `price`, `date`
- Date uses `YYYY-MM-DD`.
- Price is non-negative and represented in decimal currency.
- Country/currency defaults are acceptable for first release and can be expanded later.

## Scale assumptions

- 3000 stores with daily feed uploads, plus occasional intraday corrections.
- Search workload is read-heavy relative to write operations.
- Historical retention beyond two years is optional and policy-driven.

## Security assumptions

- Corporate network controls and TLS termination are in place at edge/proxy.
- Identity may start local (seeded users) and later integrate with enterprise IdP.
- Admin users are trusted to manage API keys securely.

## Operational assumptions

- Kubernetes and GitOps are acceptable for target production topology.
- Managed Postgres/Redis/search services can be substituted where required.
- SRE team can operate standard observability and on-call practices.

## Scope assumptions for this interview artifact

- The current implementation demonstrates core functional flows and production patterns.
- Advanced cross-region active-active replication is out of scope for baseline release.
- Currency conversion, promotion logic, and downstream repricing automation are future extensions.
