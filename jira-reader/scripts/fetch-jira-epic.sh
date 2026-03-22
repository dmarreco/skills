#!/usr/bin/env bash
# Fetch Jira epic/issue snapshot as JSON (REST API v3).
# Requires ~/.atlassian_config (JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN).
# Usage: fetch-jira-epic.sh ISSUE_KEY OUTPUT_DIR
set -euo pipefail

CONFIG="${HOME}/.atlassian_config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing ${CONFIG}" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$CONFIG"

if [[ -z "${JIRA_BASE_URL:-}" || -z "${JIRA_EMAIL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo "JIRA_BASE_URL, JIRA_EMAIL, and JIRA_API_TOKEN must be set in ${CONFIG}" >&2
  exit 2
fi

if [[ $# -lt 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  echo "Usage: $0 ISSUE_KEY OUTPUT_DIR" >&2
  echo "Example: $0 PROJ-1234 ./epic-planning/PROJ-1234-short-name" >&2
  exit 1
fi

KEY="$1"
OUT="$2"
BASE="${JIRA_BASE_URL%/}"

mkdir -p "$OUT"

# Broad field set + comments (ADF); expand changelog for history
FIELDS="summary,description,status,priority,assignee,reporter,comment,issuelinks,subtasks,labels,issuetype,parent,created,updated,fixVersions,components,creator"
JSON_URL="${BASE}/rest/api/3/issue/${KEY}?expand=changelog,renderedFields&fields=${FIELDS}"

curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" "$JSON_URL" \
  | python3 -m json.tool > "${OUT}/epic-reference.json.tmp"
mv "${OUT}/epic-reference.json.tmp" "${OUT}/epic-reference.json"

echo "Wrote ${OUT}/epic-reference.json"
