#!/usr/bin/env bash
# Publish a Markdown file to Confluence using md2conf.
# Usage: confluence-publish-md.sh MARKDOWN_FILE [ROOT_PAGE_ID]
#
# ROOT_PAGE_ID is the parent page under which a new page is created.
# Ignored if the .md file already contains <!-- confluence-page-id: ... -->.
#
# Requires:
#   - ~/.atlassian_config with CONFLUENCE_URL, JIRA_EMAIL, JIRA_API_TOKEN
#   - pip install markdown-to-confluence (Python >= 3.10)
set -euo pipefail

CONFIG="${HOME}/.atlassian_config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing ${CONFIG}" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$CONFIG"

for var in JIRA_EMAIL JIRA_API_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "${var} must be set in ${CONFIG}" >&2
    exit 2
  fi
done

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 MARKDOWN_FILE [ROOT_PAGE_ID]" >&2
  exit 1
fi

MD_FILE="$1"
ROOT_PAGE="${2:-}"

if [[ ! -f "$MD_FILE" ]]; then
  echo "Markdown file not found: ${MD_FILE}" >&2
  exit 1
fi

export CONFLUENCE_DOMAIN="avalara.atlassian.net"
export CONFLUENCE_PATH="/wiki/"
export CONFLUENCE_USER_NAME="${JIRA_EMAIL}"
export CONFLUENCE_API_KEY="${JIRA_API_TOKEN}"
export CONFLUENCE_SPACE_KEY="${CONFLUENCE_SPACE_KEY:-~7120203cde98c85a0744c99291801a2e40f932}"

# Find a working python3 with md2conf
PYTHON=""
for candidate in python3 /Library/Developer/CommandLineTools/usr/bin/python3; do
  if $candidate -m md2conf --version &>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "md2conf not found. Install with: pip install markdown-to-confluence" >&2
  exit 2
fi

ARGS=(
  -m md2conf "$MD_FILE"
  -d "$CONFLUENCE_DOMAIN"
  -s "$CONFLUENCE_SPACE_KEY"
  --no-generated-by
  --ignore-invalid-url
  --heading-anchors
)

if [[ -n "$ROOT_PAGE" ]]; then
  ARGS+=(-r "$ROOT_PAGE")
fi

echo "Publishing ${MD_FILE} to Confluence (space: ${CONFLUENCE_SPACE_KEY})..."
"$PYTHON" "${ARGS[@]}"
echo "Done."
