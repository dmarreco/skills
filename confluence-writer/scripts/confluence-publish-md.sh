#!/usr/bin/env bash
# Publish a Markdown file to Confluence using md2conf.
# Usage: confluence-publish-md.sh MARKDOWN_FILE [ROOT_PAGE_ID] [--local]
#
# ROOT_PAGE_ID is the parent page under which a new page is created.
# Ignored if the .md file already contains <!-- confluence-page-id: ... -->.
#
# --local  Convert to .csf (Confluence Storage Format) only; no network call.
#          Use this when the target is a Confluence folder (not a page).
#          Follow up with confluence-create.sh to publish the .csf file.
#
# Requires:
#   - ~/.atlassian_config with JIRA_EMAIL, JIRA_API_TOKEN; md2conf env vars
#     (CONFLUENCE_DOMAIN, CONFLUENCE_PATH, CONFLUENCE_USER_NAME, CONFLUENCE_API_KEY,
#     CONFLUENCE_SPACE_KEY) when not using --local
#   - markdown-to-confluence installed on the Python used below (often macOS
#     CommandLineTools: /Library/Developer/CommandLineTools/usr/bin/python3)
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

LOCAL_ONLY=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) LOCAL_ONLY=true; shift ;;
    *)       POSITIONAL+=("$1"); shift ;;
  esac
done

if [[ ${#POSITIONAL[@]} -lt 1 ]]; then
  echo "Usage: $0 MARKDOWN_FILE [ROOT_PAGE_ID] [--local]" >&2
  exit 1
fi

MD_FILE="${POSITIONAL[0]}"
ROOT_PAGE="${POSITIONAL[1]:-}"

if [[ ! -f "$MD_FILE" ]]; then
  echo "Markdown file not found: ${MD_FILE}" >&2
  exit 1
fi

if [[ "$LOCAL_ONLY" == false ]]; then
  for var in CONFLUENCE_DOMAIN CONFLUENCE_SPACE_KEY CONFLUENCE_USER_NAME CONFLUENCE_API_KEY; do
    if [[ -z "${!var:-}" ]]; then
      echo "${var} must be set in ${CONFIG}" >&2
      exit 2
    fi
  done
  export CONFLUENCE_DOMAIN CONFLUENCE_PATH CONFLUENCE_USER_NAME CONFLUENCE_API_KEY CONFLUENCE_SPACE_KEY
fi

# Find a working python3 with md2conf (prefer macOS CommandLineTools — matches
# typical pip3 install location; fall back to python3 on PATH)
PYTHON=""
for candidate in /Library/Developer/CommandLineTools/usr/bin/python3 python3; do
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
  --no-generated-by
  --ignore-invalid-url
  --heading-anchors
)

if [[ "$LOCAL_ONLY" == true ]]; then
  ARGS+=(--local)
else
  ARGS+=(-d "$CONFLUENCE_DOMAIN" -s "$CONFLUENCE_SPACE_KEY")
  if [[ -n "$ROOT_PAGE" ]]; then
    ARGS+=(-r "$ROOT_PAGE")
  fi
fi

if [[ "$LOCAL_ONLY" == true ]]; then
  echo "Converting ${MD_FILE} to Confluence storage format (local only)..."
else
  echo "Publishing ${MD_FILE} to Confluence (space: ${CONFLUENCE_SPACE_KEY})..."
fi

"$PYTHON" "${ARGS[@]}"

if [[ "$LOCAL_ONLY" == true ]]; then
  CSF_FILE="${MD_FILE%.md}.csf"
  if [[ -f "$CSF_FILE" ]]; then
    echo "Generated: ${CSF_FILE}"
    echo "Next: confluence-create.sh \"Page Title\" ${CSF_FILE} PARENT_ID"
  fi
else
  echo "Done."
fi
