## Production-grade retail pricing platform

### Architecture (high level)

```
Browser
  |
  |  http://localhost:8080
  v
Nginx reverse proxy
  |-- /api/*  ---> FastAPI (JWT + rate limit) ---> Postgres
  |                                  |
  |                                  +--> Typesense (search index)
  |
  +-- /*      ---> Flutter Web (static via nginx)
```

### Local dev (Docker Compose)

1) Copy env (optional; defaults exist in compose):

```bash
cp backend/.env.example backend/.env
```

2) Start stack:

```bash
docker compose up --build
```

### One-command Docker deploy (with seed + tests)
These scripts are designed for a fresh clone: they build + start the full Docker stack, wait for `/api/readyz`, seed **10,000 demo products** (Postgres + Typesense), run backend tests, and do a small smoke check.

- **Windows (PowerShell)**:

```powershell
cd pricing-platform
.\deploy-windows.ps1
```

- **macOS / Linux (bash)**:

```bash
cd pricing-platform
chmod +x ./deploy-mac.sh
./deploy-mac.sh
```

Optional: if you want the Compose **Tailscale** service to join your tailnet, export `TS_AUTHKEY` before running (this enables the `tailscale` Compose profile):

```bash
export TS_AUTHKEY="tskey-auth-..."
export TS_HOSTNAME="pricing-platform-dev" # optional
./deploy-mac.sh
```

### Demo users (seeded)
When running via Docker Compose, the backend seeds 4 demo users (one per role):

- **Admin** (`admin@example.com` / `change_me_please`)
  - Can search, upload CSV, edit records, and create API keys
- **Viewer** (`viewer@example.com` / `change_me_please`)
  - Can search only (no upload, no edit)
- **Editor** (`editor@example.com` / `change_me_please`)
  - Can search + edit records (no upload)
- **Uploader** (`uploader@example.com` / `change_me_please`)
  - Can search + upload CSV (no edit)

You can override these via env vars in `docker-compose.yml`:
`SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`, `SEED_VIEWER_EMAIL`, `SEED_VIEWER_PASSWORD`, `SEED_EDITOR_EMAIL`, `SEED_EDITOR_PASSWORD`, `SEED_UPLOADER_EMAIL`, `SEED_UPLOADER_PASSWORD`.

### Endpoints
- **Docs**: `GET /api/docs`
- **Health**: `GET /api/healthz`, `GET /api/readyz`
- **Auth**: `POST /api/auth/login`
- **Me**: `GET /api/auth/me`
- **Create API key (admin)**: `POST /api/auth/api-keys`
- **Upload CSV**: `POST /api/upload-csv`
- **Search**: `GET /api/pricing/search`
- **Get/Update**: `GET /api/pricing/{id}`, `PUT /api/pricing/{id}`

### CSV format
Columns required:
- `store_id`
- `sku`
- `product_name`
- `price`
- `date` (YYYY-MM-DD)

### Upload automation (optional API key)
If you want a non-human credential for automated uploads:

1) Login as admin and create an API key:

```bash
curl -sS -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"change_me_please"}'

# then call /api/auth/api-keys with the Bearer token you got back
```

2) Upload using the `X-API-Key` header:

```bash
curl -sS -X POST http://localhost:8080/api/upload-csv \
  -H "X-API-Key: <paste_api_key_here>" \
  -F "file=@scripts/sample_pricing.csv"
```

### Kubernetes
Manifests are in `infra/k8s/`.

- Apply:

```bash
kubectl apply -f infra/k8s/namespace.yaml
kubectl apply -f infra/k8s/secrets.example.yaml
kubectl apply -f infra/k8s/postgres-statefulset.yaml
kubectl apply -f infra/k8s/typesense-deployment.yaml
kubectl apply -f infra/k8s/redis-deployment.yaml
kubectl apply -f infra/k8s/backend-deployment.yaml
kubectl apply -f infra/k8s/frontend-deployment.yaml
kubectl apply -f infra/k8s/retention-cronjob.yaml
kubectl apply -f infra/k8s/ingress.yaml
```

### Partitioning & retention (production knobs)
- **Pricing table partitioning**: set `ENABLE_PRICING_PARTITIONING=true` to convert `pricing_records` to **monthly partitions** (RANGE by `date`) and auto-create partitions around “now”.
- **Retention**: set `PRICING_RETENTION_DAYS` (default `730`). A Kubernetes CronJob manifest is provided at `infra/k8s/retention-cronjob.yaml`.

