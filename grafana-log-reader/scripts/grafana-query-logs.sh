#!/usr/bin/env bash
# Query Grafana Loki logs via the datasource proxy and save to temp files.
# Usage: grafana-query-logs.sh --env ENV "LOGQL_QUERY" [--since DURATION] [--limit N]
# Requires ~/.grafana_config and datasources.json with populated IDs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DS_FILE="${SKILL_DIR}/datasources.json"
EXTRACT_SCRIPT="${SCRIPT_DIR}/extract-log-lines.py"
BASE_OUTPUT_DIR="/tmp/grafana-logs"

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

# --- Parse arguments ---
ENV=""
QUERY=""
SINCE="1h"
LIMIT="1000"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)    ENV="$2";   shift 2 ;;
    --since)  SINCE="$2"; shift 2 ;;
    --limit)  LIMIT="$2"; shift 2 ;;
    -*)       echo "Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required (e.g. --env qa)" >&2
  exit 1
fi
if [[ -z "$QUERY" ]]; then
  echo "ERROR: LogQL query string is required" >&2
  echo "Usage: $0 --env ENV \"LOGQL_QUERY\" [--since DURATION] [--limit N]" >&2
  exit 1
fi

# --- Resolve datasource ID ---
if [[ ! -f "$DS_FILE" ]]; then
  echo "Missing ${DS_FILE} — run grafana-discover-datasources.sh first" >&2
  exit 2
fi

read -r DS_ID DS_NAME < <(python3 - "$DS_FILE" "$ENV" <<'PYEOF'
import json, sys

ds_file, env = sys.argv[1], sys.argv[2]
with open(ds_file) as f:
    cfg = json.load(f)

if env not in cfg:
    avail = ", ".join(sorted(cfg.keys()))
    print(f'ERROR: environment "{env}" not found in datasources.json', file=sys.stderr)
    print(f'Available: {avail}', file=sys.stderr)
    sys.exit(1)

entry = cfg[env]
ds_id = entry.get("id")
if ds_id is None:
    print(f'ERROR: datasource ID for "{env}" is null — run grafana-discover-datasources.sh', file=sys.stderr)
    sys.exit(1)

print(ds_id, entry["name"])
PYEOF
)

# --- Compute time range ---
END_NS=$(python3 -c 'import time; print(int(time.time() * 1e9))')
START_NS=$(python3 - "$SINCE" <<'PYEOF'
import re, sys, time

since = sys.argv[1]
m = re.fullmatch(r'(\d+)(m|h|d)', since)
if not m:
    print(f'ERROR: invalid --since format "{since}" (use e.g. 30m, 1h, 6h, 2d)', file=sys.stderr)
    sys.exit(1)

val, unit = int(m.group(1)), m.group(2)
multipliers = {"m": 60, "h": 3600, "d": 86400}
print(int((time.time() - val * multipliers[unit]) * 1e9))
PYEOF
)

# --- Build output directory ---
QUERY_HASH=$(printf '%s' "$QUERY" | md5sum | head -c 6 2>/dev/null || printf '%s' "$QUERY" | md5 | head -c 6)
TIMESTAMP=$(date +%Y%m%dT%H%M%S)
OUTPUT_DIR="${BASE_OUTPUT_DIR}/${ENV}-${QUERY_HASH}-${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# --- Cleanup old results (>7 days) ---
if [[ -d "$BASE_OUTPUT_DIR" ]]; then
  find "$BASE_OUTPUT_DIR" -maxdepth 1 -type d -mtime +7 -not -path "$BASE_OUTPUT_DIR" -exec rm -rf {} + 2>/dev/null || true
fi

# --- Execute query ---
BASE="${GRAFANA_URL%/}"
PROXY_URL="${BASE}/api/datasources/proxy/${DS_ID}/loki/api/v1/query_range"

HTTP_RESPONSE=$(curl -sS -w "\n%{http_code}" -G \
  -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  "$PROXY_URL" \
  --data-urlencode "query=${QUERY}" \
  --data-urlencode "start=${START_NS}" \
  --data-urlencode "end=${END_NS}" \
  --data-urlencode "limit=${LIMIT}" \
  --data-urlencode "direction=backward")

HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  echo "ERROR: HTTP ${HTTP_CODE} from Grafana" >&2
  echo "$BODY" >&2
  rm -rf "$OUTPUT_DIR"
  exit 1
fi

# --- Save raw response ---
echo "$BODY" > "${OUTPUT_DIR}/raw-response.json"

# --- Extract log lines ---
echo "$BODY" | python3 "$EXTRACT_SCRIPT" > "${OUTPUT_DIR}/logs.txt"
LINE_COUNT=$(wc -l < "${OUTPUT_DIR}/logs.txt" | tr -d ' ')

# --- Write query-info.txt ---
cat > "${OUTPUT_DIR}/query-info.txt" <<INFO
env: ${ENV}
datasource: ${DS_NAME}
query: ${QUERY}
since: ${SINCE}
limit: ${LIMIT}
executed: $(date +%Y-%m-%dT%H:%M:%S)
lines: ${LINE_COUNT}
INFO

# --- Report ---
RAW_SIZE=$(du -h "${OUTPUT_DIR}/raw-response.json" | cut -f1)
LOG_SIZE=$(du -h "${OUTPUT_DIR}/logs.txt" | cut -f1)

echo "=== Query complete ==="
echo "Output: ${OUTPUT_DIR}"
echo "Lines:  ${LINE_COUNT}"
echo "Since:  ${SINCE}"
echo "Files:  raw-response.json (${RAW_SIZE})  logs.txt (${LOG_SIZE})"
