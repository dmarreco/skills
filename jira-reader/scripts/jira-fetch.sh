#!/usr/bin/env bash
# Read-only fetch of a single Jira issue (limited fields). Requires ~/.atlassian_config.
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

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "Usage: $0 ISSUE_KEY" >&2
  echo "Example: $0 ELR-32817" >&2
  exit 1
fi

KEY="$1"
FIELDS="summary,status,issuetype,priority,assignee,reporter,description,subtasks,issuelinks,labels,components,fixVersions,parent,created,updated"

exec curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${KEY}?fields=${FIELDS}"
