#!/usr/bin/env bash
# Create a Confluence page in the user's personal space.
# Usage: confluence-create.sh "Title" BODY_FILE [PARENT_PAGE_ID]
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
  echo "Usage: $0 \"Page Title\" BODY_FILE [PARENT_PAGE_ID]" >&2
  exit 1
fi

TITLE="$1"
BODY_FILE="$2"
SPACE_KEY="~7120203cde98c85a0744c99291801a2e40f932"
PARENT_ID="${3:-638522164553}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: ${BODY_FILE}" >&2
  exit 1
fi

BODY=$(<"$BODY_FILE")
BASE="${CONFLUENCE_URL%/}"

PAYLOAD=$(jq -n \
  --arg title "$TITLE" \
  --arg key "$SPACE_KEY" \
  --arg pid "$PARENT_ID" \
  --arg body "$BODY" \
  '{
    type: "page",
    title: $title,
    space: { key: $key },
    ancestors: [{ id: $pid }],
    body: { storage: { value: $body, representation: "storage" } }
  }')

RESPONSE=$(curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X POST "${BASE}/rest/api/content" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

PAGE_ID=$(echo "$RESPONSE" | jq -r '.id')
PAGE_TITLE=$(echo "$RESPONSE" | jq -r '.title')
PAGE_URL="${BASE}/spaces/${SPACE_KEY}/pages/${PAGE_ID}"

echo "Created page: ${PAGE_TITLE} (ID: ${PAGE_ID})"
echo "URL: ${PAGE_URL}"
echo "$RESPONSE"
