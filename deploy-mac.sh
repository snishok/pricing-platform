#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "Docker Compose not found. Install Docker Desktop (with Compose)." 1>&2
    exit 1
  fi
}

wait_http_ok() {
  local url="$1"
  local timeout_s="${2:-180}"
  local deadline=$((SECONDS + timeout_s))
  while [ $SECONDS -lt $deadline ]; do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for $url" 1>&2
  return 1
}

profiles=()
if [ -n "${TS_AUTHKEY:-}" ]; then
  profiles+=(--profile tailscale)
fi

echo "Starting Docker stack..."
compose "${profiles[@]}" up -d --build

echo "Waiting for API readiness..."
wait_http_ok "http://localhost:8080/api/readyz" 240

echo "Seeding demo data (10,000 products)..."
compose exec -T backend python -m app.cli.seed_demo_data --products 10000

echo "Running backend tests..."
compose exec -T backend pytest -q

echo "Smoke check search endpoint..."
wait_http_ok "http://localhost:8080/api/healthz" 30
wait_http_ok "http://localhost:8080/api/pricing/search?q=Demo&per_page=1&page=1" 30

cat <<EOF

Deployed successfully.
- App:  http://localhost:8080
- API:  http://localhost:8080/api/docs

To stop: docker compose down
EOF

