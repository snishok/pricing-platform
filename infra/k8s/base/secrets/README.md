## Secrets (GitOps-safe)

This repository intentionally **does not** deploy runtime secrets as part of the GitOps Kustomize bases/overlays.

### Why
- Applying committed Secret YAML from CI/CD is risky (easy to overwrite production secrets).
- GitOps should keep sensitive values in a dedicated secret store and only reconcile **references**.

### Recommended options
- **External Secrets Operator** (preferred): sync from your cloud secret manager into Kubernetes `Secret`s.
- **Sealed Secrets**: commit encrypted secrets that can only be decrypted by the controller in-cluster.

### Required secret
The workloads expect a Kubernetes Secret named **`pricing-secrets`** in each environment namespace, with keys:
- `DATABASE_URL`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `JWT_SECRET_KEY`
- `TYPESENSE_API_KEY`
- `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`
- `SEED_VIEWER_EMAIL`, `SEED_VIEWER_PASSWORD`
- `SEED_EDITOR_EMAIL`, `SEED_EDITOR_PASSWORD`
- `SEED_UPLOADER_EMAIL`, `SEED_UPLOADER_PASSWORD`

For local/dev bootstrapping only, see `infra/k8s/secrets.example.yaml` (do **not** use in production).

