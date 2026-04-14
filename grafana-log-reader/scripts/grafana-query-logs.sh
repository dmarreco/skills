#!/usr/bin/env bash
# Query Grafana Loki logs via the datasource proxy and save to temp files.
# Usage: grafana-query-logs.sh --datasource NAME_OR_ID "LOGQL_QUERY" [--since DURATION] [--limit N]
# Requires ~/.grafana_config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
DATASOURCE=""
QUERY=""
SINCE="1h"
LIMIT="1000"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --datasource) DATASOURCE="$2"; shift 2 ;;
    --since)      SINCE="$2";      shift 2 ;;
    --limit)      LIMIT="$2";      shift 2 ;;
    -*)           echo "Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi
      ;;
  esac
done

if [[ -z "$DATASOURCE" ]]; then
  echo "ERROR: --datasource is required (name or numeric ID)" >&2
  echo "Usage: $0 --datasource NAME_OR_ID \"LOGQL_QUERY\" [--since DURATION] [--limit N]" >&2
  exit 1
fi
if [[ -z "$QUERY" ]]; then
  echo "ERROR: LogQL query string is required" >&2
  echo "Usage: $0 --datasource NAME_OR_ID \"LOGQL_QUERY\" [--since DURATION] [--limit N]" >&2
  exit 1
fi

# --- Resolve datasource: if numeric use as ID, otherwise resolve name to ID ---
BASE="${GRAFANA_URL%/}"

if [[ "$DATASOURCE" =~ ^[0-9]+$ ]]; then
  DS_ID="$DATASOURCE"
  DS_LABEL="$DATASOURCE"
else
  DS_ID=$(curl -sS -f \
    -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    "${BASE}/api/datasources/name/${DATASOURCE}" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' 2>/dev/null) || true

  if [[ -z "$DS_ID" ]]; then
    echo "ERROR: could not resolve datasource name '${DATASOURCE}'" >&2
    echo "Run grafana-discover-datasources.sh to list available datasources." >&2
    exit 1
  fi
  DS_LABEL="$DATASOURCE"
fi

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
DS_HASH=$(printf '%s' "$DS_LABEL" | md5sum | head -c 6 2>/dev/null || printf '%s' "$DS_LABEL" | md5 | head -c 6)
QUERY_HASH=$(printf '%s' "$QUERY" | md5sum | head -c 6 2>/dev/null || printf '%s' "$QUERY" | md5 | head -c 6)
TIMESTAMP=$(date +%Y%m%dT%H%M%S)
OUTPUT_DIR="${BASE_OUTPUT_DIR}/${DS_HASH}-${QUERY_HASH}-${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# --- Cleanup old results (>7 days) ---
if [[ -d "$BASE_OUTPUT_DIR" ]]; then
  find "$BASE_OUTPUT_DIR" -maxdepth 1 -type d -mtime +7 -not -path "$BASE_OUTPUT_DIR" -exec rm -rf {} + 2>/dev/null || true
fi

# --- Execute query ---
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
datasource: ${DS_LABEL}
datasource_id: ${DS_ID}
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
