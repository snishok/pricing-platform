# Pricing Platform - Architect Interview Deliverables

This folder contains a complete architecture package for the retail pricing platform.

## Included deliverables

1. `01-context-diagram.md`
2. `02-solution-architecture.md`
3. `03-design-decisions.md`
4. `04-nfrs-and-design-response.md`
5. `05-assumptions.md`
6. `06-source-implementation-map.md`

## Additional architect-level artifacts

7. `07-capacity-and-scaling-model.md`
8. `08-security-and-compliance-model.md`
9. `09-operability-slo-and-runbook.md`
10. `10-risk-register.md`
11. `11-rollout-and-migration-plan.md`

## Scope

- Functional requirements:
  - CSV upload and persistence for pricing feeds
  - Search by multiple criteria
  - Edit and save pricing records
- Non-functional requirements:
  - Design for a 3000-store, multi-country retail enterprise
- Solution style:
  - Single page web application with production-ready backend services

## Source repository

Implementation source is in the same repository root:

- Backend: `backend/` (FastAPI, Postgres, Typesense, Redis)
- Frontend SPA: `frontend/` (Flutter Web SPA)
- Infrastructure: `infra/` (Docker, Kubernetes, Argo CD, GitHub Actions)
