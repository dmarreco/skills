#!/usr/bin/env bash
# Create a Confluence page in the user's personal space.
# Usage: confluence-create.sh "Title" BODY_FILE [PARENT_PAGE_ID] [--labels l1,l2] [--json]
# Requires ~/.atlassian_config with CONFLUENCE_URL, JIRA_EMAIL, JIRA_API_TOKEN.
set -euo pipefail

CONFIG="${HOME}/.atlassian_config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing ${CONFIG}" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$CONFIG"

for var in CONFLUENCE_URL JIRA_EMAIL JIRA_API_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "${var} must be set in ${CONFIG}" >&2
    exit 2
  fi
done

LABELS=""
JSON_OUTPUT=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --labels) LABELS="$2"; shift 2 ;;
    --json)   JSON_OUTPUT=true; shift ;;
    *)        POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
  echo "Usage: $0 \"Page Title\" BODY_FILE [PARENT_PAGE_ID] [--labels l1,l2] [--json]" >&2
  exit 1
fi

TITLE="${POSITIONAL[0]}"
BODY_FILE="${POSITIONAL[1]}"
SPACE_KEY="${CONFLUENCE_SPACE_KEY:?CONFLUENCE_SPACE_KEY must be set in ${CONFIG}}"
PARENT_ID="${POSITIONAL[2]:-${CONFLUENCE_HOMEPAGE_ID:-}}"

if [[ -z "$PARENT_ID" ]]; then
  echo "No parent page ID provided and CONFLUENCE_HOMEPAGE_ID not set in ${CONFIG}." >&2
  echo "Usage: $0 \"Page Title\" BODY_FILE PARENT_PAGE_ID" >&2
  exit 1
fi

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: ${BODY_FILE}" >&2
  exit 1
fi

BODY=$(<"$BODY_FILE")
BASE="${CONFLUENCE_URL%/}"

LABELS_JSON="[]"
if [[ -n "$LABELS" ]]; then
  LABELS_JSON=$(echo "$LABELS" | tr ',' '\n' | jq -R '{prefix:"global",name:.}' | jq -s '.')
fi

PAYLOAD=$(jq -n \
  --arg title "$TITLE" \
  --arg key "$SPACE_KEY" \
  --arg pid "$PARENT_ID" \
  --arg body "$BODY" \
  --argjson labels "$LABELS_JSON" \
  '{
    type: "page",
    title: $title,
    space: { key: $key },
    ancestors: [{ id: $pid }],
    body: { storage: { value: $body, representation: "storage" } }
  } + (if ($labels | length) > 0 then { metadata: { labels: $labels } } else {} end)')

RESPONSE=$(curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X POST "${BASE}/rest/api/content" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

PAGE_ID=$(echo "$RESPONSE" | jq -r '.id')
PAGE_TITLE=$(echo "$RESPONSE" | jq -r '.title')
PAGE_URL="${BASE}$(echo "$RESPONSE" | jq -r '._links.webui')"

echo "Created page: ${PAGE_TITLE} (ID: ${PAGE_ID})"
echo "URL: ${PAGE_URL}"
echo ""
echo "Pin in your Markdown file:"
echo "<!-- confluence-page-id: ${PAGE_ID} -->"

if [[ "$JSON_OUTPUT" == true ]]; then
  echo ""
  echo "$RESPONSE"
fi
