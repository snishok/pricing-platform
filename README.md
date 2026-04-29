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

### Endpoints
- **Docs**: `GET /api/docs`
- **Health**: `GET /api/healthz`, `GET /api/readyz`
- **Auth**: `POST /api/auth/login`
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

### Kubernetes
Manifests are in `infra/k8s/`.

- Apply:

```bash
kubectl apply -f infra/k8s/namespace.yaml
kubectl apply -f infra/k8s/secrets.example.yaml
kubectl apply -f infra/k8s/postgres-statefulset.yaml
kubectl apply -f infra/k8s/typesense-deployment.yaml
kubectl apply -f infra/k8s/backend-deployment.yaml
kubectl apply -f infra/k8s/frontend-deployment.yaml
kubectl apply -f infra/k8s/ingress.yaml
```

