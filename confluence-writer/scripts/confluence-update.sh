#!/usr/bin/env bash
# Update an existing Confluence page. Auto-increments version number.
# Usage: confluence-update.sh PAGE_ID BODY_FILE ["New Title"]
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

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 PAGE_ID BODY_FILE [\"New Title\"]" >&2
  exit 1
fi

PAGE_ID="$1"
BODY_FILE="$2"
BASE="${CONFLUENCE_URL%/}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: ${BODY_FILE}" >&2
  exit 1
fi

BODY=$(<"$BODY_FILE")

CURRENT_PAGE=$(curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${BASE}/api/v2/pages/${PAGE_ID}")

CURRENT_VERSION=$(echo "$CURRENT_PAGE" | jq '.version.number')
CURRENT_TITLE=$(echo "$CURRENT_PAGE" | jq -r '.title')

TITLE="${3:-$CURRENT_TITLE}"
NEW_VERSION=$((CURRENT_VERSION + 1))

PAYLOAD=$(jq -n \
  --arg id "$PAGE_ID" \
  --arg title "$TITLE" \
  --argjson ver "$NEW_VERSION" \
  --arg body "$BODY" \
  '{
    id: $id,
    status: "current",
    title: $title,
    body: { representation: "storage", value: $body },
    version: { number: $ver }
  }')

RESPONSE=$(curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X PUT "${BASE}/api/v2/pages/${PAGE_ID}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

UPDATED_TITLE=$(echo "$RESPONSE" | jq -r '.title')
echo "Updated page: ${UPDATED_TITLE} (ID: ${PAGE_ID}, version: ${NEW_VERSION})"
echo "$RESPONSE"
