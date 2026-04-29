# 6) Source Implementation Map

This section ties the requirements directly to code in this repository.

## Requirement: Upload and persist CSV pricing feeds

- API endpoint:
  - `backend/app/api/upload.py`
- Core ingestion logic:
  - CSV parsing and validation
  - Chunked processing
  - DB upsert + search indexing
- Service:
  - `backend/app/services/pricing_service.py`
- Data models:
  - `backend/app/models/pricing_record.py`
  - `backend/app/models/pricing_feed_upload.py`

## Requirement: Search records by criteria

- API endpoint:
  - `backend/app/api/pricing.py` (`/pricing/search`, `/pricing/search/meta`)
- Search service:
  - `backend/app/services/typesense_service.py`
- DB fallback search:
  - `backend/app/services/pricing_service.py`
  - `backend/app/repositories/pricing_repository.py`
- Cache:
  - `backend/app/services/pricing_search_cache.py`

## Requirement: Edit and save record changes

- API endpoint:
  - `backend/app/api/pricing.py` (`PUT /pricing/{record_id}`)
- Update + audit:
  - `backend/app/services/pricing_service.py`
  - `backend/app/models/pricing_record_audit.py`

## SPA implementation (single page web app)

- Main app entry:
  - `frontend/packages/app/lib/main.dart`
- Search and edit UI:
  - `frontend/packages/app/lib/src/ui/search_page.dart`
- Upload UI:
  - `frontend/packages/app/lib/src/ui/upload_page.dart`
- Frontend state:
  - `frontend/packages/app/lib/src/state/pricing_state.dart`
- API client:
  - `frontend/packages/core/lib/src/api/api_client.dart`

## Infrastructure and operations

- Docker/local:
  - `docker-compose.yml`
- Kubernetes:
  - `infra/k8s/base/`
  - `infra/k8s/overlays/dev/`
  - `infra/k8s/overlays/staging/`
  - `infra/k8s/overlays/prod/`
- CI/CD:
  - `.github/workflows/`
