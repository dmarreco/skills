#!/usr/bin/env bash
# Read-only fetch of a single Confluence page (v2, storage body). Requires ~/.atlassian_config.
set -euo pipefail

CONFIG="${HOME}/.atlassian_config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing ${CONFIG}" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$CONFIG"

if [[ -z "${CONFLUENCE_URL:-}" || -z "${JIRA_EMAIL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo "CONFLUENCE_URL, JIRA_EMAIL, and JIRA_API_TOKEN must be set in ${CONFIG}" >&2
  exit 2
fi

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "Usage: $0 PAGE_ID_OR_CONFLUENCE_URL" >&2
  echo "Examples:" >&2
  echo "  $0 123456789" >&2
  echo "  $0 'https://avalara.atlassian.net/wiki/spaces/FOO/pages/123456789/Title'" >&2
  exit 1
fi

RAW="$1"
PAGE_ID=""

if [[ "$RAW" =~ /pages/([0-9]+) ]]; then
  PAGE_ID="${BASH_REMATCH[1]}"
elif [[ "$RAW" =~ ^[0-9]+$ ]]; then
  PAGE_ID="$RAW"
else
  echo "Could not parse a numeric page ID from: $RAW" >&2
  echo "Provide a number or a URL containing /pages/<id>/" >&2
  exit 1
fi

# Trim trailing slash from CONFLUENCE_URL
BASE="${CONFLUENCE_URL%/}"

exec curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${BASE}/api/v2/pages/${PAGE_ID}?body-format=storage"
