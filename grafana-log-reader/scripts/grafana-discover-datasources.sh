#!/usr/bin/env bash
# Discover Loki datasource numeric IDs from Grafana and update datasources.json.
# Requires ~/.grafana_config (GRAFANA_URL, GRAFANA_TOKEN) and python3.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DS_FILE="${SKILL_DIR}/datasources.json"

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

if [[ ! -f "$DS_FILE" ]]; then
  echo "Missing ${DS_FILE}" >&2
  exit 2
fi

BASE="${GRAFANA_URL%/}"

echo "=== Fetching datasources from ${BASE} ==="
echo ""

API_RESPONSE=$(curl -sS -f \
  -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  "${BASE}/api/datasources")

python3 - "$DS_FILE" <<'PYEOF' "$API_RESPONSE"
import json, sys

ds_file = sys.argv[1]
api_json = sys.argv[2]

api_datasources = json.loads(api_json)
loki_ds = [d for d in api_datasources if d.get("type") == "loki"]

print(f"Found {len(loki_ds)} Loki datasource(s):\n")
for d in sorted(loki_ds, key=lambda x: x["name"]):
    print(f"  id={d['id']}  name={d['name']}  uid={d.get('uid', 'n/a')}")

with open(ds_file) as f:
    config = json.load(f)

name_to_id = {d["name"]: d["id"] for d in loki_ds}

print()
updated = 0
for env, entry in config.items():
    ds_name = entry["name"]
    if ds_name in name_to_id:
        old_id = entry.get("id")
        new_id = name_to_id[ds_name]
        entry["id"] = new_id
        status = "updated" if old_id != new_id else "unchanged"
        print(f"  {env}: id={new_id} ({status})")
        if old_id != new_id:
            updated += 1
    else:
        print(f"  WARNING: {env}: datasource '{ds_name}' not found in Grafana")

with open(ds_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"\n=== Done — {updated} ID(s) updated in {ds_file} ===")
PYEOF
