#!/usr/bin/env bash
# List all Loki datasources from a Grafana instance.
# Prints id, name, and uid for each Loki datasource.
# Requires ~/.grafana_config (GRAFANA_URL, GRAFANA_TOKEN) and python3.
set -euo pipefail

CONFIG="${HOME}/.grafana_config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing ${CONFIG}" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$CONFIG"

if [[ -z "${GRAFANA_URL:-}" || -z "${GRAFANA_TOKEN:-}" ]]; then
  echo "GRAFANA_URL and GRAFANA_TOKEN must be set in ${CONFIG}" >&2
  exit 2
fi

BASE="${GRAFANA_URL%/}"

echo "=== Fetching datasources from ${BASE} ==="
echo ""

API_RESPONSE=$(curl -sS -f \
  -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  "${BASE}/api/datasources")

python3 - <<'PYEOF' "$API_RESPONSE"
import json, sys

api_datasources = json.loads(sys.argv[1])
loki_ds = [d for d in api_datasources if d.get("type") == "loki"]

print(f"Found {len(loki_ds)} Loki datasource(s):\n")
for d in sorted(loki_ds, key=lambda x: x["name"]):
    print(f"  id={d['id']}  name={d['name']}  uid={d.get('uid', 'n/a')}")

print(f"\nUse --datasource <name> or --datasource <id> with grafana-query-logs.sh")
PYEOF
