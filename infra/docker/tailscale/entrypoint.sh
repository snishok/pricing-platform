#!/usr/bin/env sh
set -eu

if [ -z "${TS_AUTHKEY:-}" ]; then
  echo "TS_AUTHKEY is required (set it or don't enable the tailscale profile)." 1>&2
  exit 2
fi

STATE_DIR="${TS_STATE_DIR:-/var/lib/tailscale}"
HOSTNAME="${TS_HOSTNAME:-pricing-platform}"

mkdir -p "${STATE_DIR}"

tailscaled --state="${STATE_DIR}/tailscaled.state" --socket="${STATE_DIR}/tailscaled.sock" &

# Wait until the daemon is responsive.
tries=0
until tailscale --socket="${STATE_DIR}/tailscaled.sock" status >/dev/null 2>&1; do
  tries=$((tries + 1))
  if [ "$tries" -gt 50 ]; then
    echo "tailscaled did not become ready" 1>&2
    exit 3
  fi
  sleep 0.2
done

tailscale --socket="${STATE_DIR}/tailscaled.sock" up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${HOSTNAME}" \
  ${TS_EXTRA_ARGS:-}

echo "tailscale up ok (hostname=${HOSTNAME})"

wait

