#!/usr/bin/env bash
# Read-only GitLab API helper (v4). Requires ~/.gitlab_readonly_config.
set -euo pipefail

CONFIG="${HOME}/.gitlab_readonly_config"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing ${CONFIG}" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$CONFIG"

if [[ -z "${GITLAB_BASE_PROJECT_URL:-}" || -z "${GITLAB_READONLY_TOKEN:-}" ]]; then
  echo "GITLAB_BASE_PROJECT_URL and GITLAB_READONLY_TOKEN must be set in ${CONFIG}" >&2
  exit 2
fi

GITLAB_URL="$(dirname "${GITLAB_BASE_PROJECT_URL}")"
API="${GITLAB_URL}/api/v4"

project_enc() {
  local p="$1"
  if [[ "$p" =~ ^[0-9]+$ ]]; then
    printf '%s' "$p"
  else
    printf '%s' "$p" | sed 's|/|%2F|g'
  fi
}

path_enc() {
  printf '%s' "$1" | sed 's|/|%2F|g'
}

curl_gitlab() {
  curl -sS -f -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" "$@"
}

usage() {
  cat >&2 <<'EOF'
Usage:
  gitlab-fetch.sh projects [SEARCH]
  gitlab-fetch.sh tree PROJECT_PATH [DIR] [REF]
  gitlab-fetch.sh file PROJECT_PATH FILE [REF]
  gitlab-fetch.sh mrs PROJECT_PATH [STATE]
  gitlab-fetch.sh mr PROJECT_PATH MR_IID
  gitlab-fetch.sh pipelines PROJECT_PATH
  gitlab-fetch.sh jobs PROJECT_PATH PIPELINE_ID
  gitlab-fetch.sh log PROJECT_PATH JOB_ID

PROJECT_PATH: numeric project id or path like group/subproject/repo
STATE (mrs): opened | closed | merged | all (default: opened)
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

CMD="$1"
shift

case "$CMD" in
  projects)
    SEARCH="${1:-}"
    if [[ -n "$SEARCH" ]]; then
      curl_gitlab -G "${API}/projects" \
        --data-urlencode "membership=true" \
        --data-urlencode "search=${SEARCH}" \
        --data-urlencode "per_page=50"
    else
      curl_gitlab -G "${API}/projects" \
        --data-urlencode "membership=true" \
        --data-urlencode "per_page=50"
    fi
    ;;

  tree)
    [[ $# -lt 1 ]] && usage
    ENC="$(project_enc "$1")"
    DIR="${2:-}"
    REF="${3:-main}"
    curl_gitlab -G "${API}/projects/${ENC}/repository/tree" \
      --data-urlencode "path=${DIR}" \
      --data-urlencode "ref=${REF}" \
      --data-urlencode "per_page=100"
    ;;

  file)
    [[ $# -lt 2 ]] && usage
    ENC="$(project_enc "$1")"
    FILE="$2"
    REF="${3:-main}"
    FENC="$(path_enc "$FILE")"
    curl_gitlab -G "${API}/projects/${ENC}/repository/files/${FENC}/raw" \
      --data-urlencode "ref=${REF}"
    ;;

  mrs)
    [[ $# -lt 1 ]] && usage
    ENC="$(project_enc "$1")"
    STATE="${2:-opened}"
    curl_gitlab -G "${API}/projects/${ENC}/merge_requests" \
      --data-urlencode "state=${STATE}" \
      --data-urlencode "per_page=50"
    ;;

  mr)
    [[ $# -lt 2 ]] && usage
    ENC="$(project_enc "$1")"
    IID="$2"
    printf '%s\n' "=== merge_request ==="
    curl_gitlab "${API}/projects/${ENC}/merge_requests/${IID}"
    printf '%s\n' "=== changes ==="
    curl_gitlab "${API}/projects/${ENC}/merge_requests/${IID}/changes"
    ;;

  pipelines)
    [[ $# -lt 1 ]] && usage
    ENC="$(project_enc "$1")"
    curl_gitlab -G "${API}/projects/${ENC}/pipelines" \
      --data-urlencode "per_page=30"
    ;;

  jobs)
    [[ $# -lt 2 ]] && usage
    ENC="$(project_enc "$1")"
    PID="$2"
    curl_gitlab "${API}/projects/${ENC}/pipelines/${PID}/jobs"
    ;;

  log)
    [[ $# -lt 2 ]] && usage
    ENC="$(project_enc "$1")"
    JID="$2"
    curl_gitlab "${API}/projects/${ENC}/jobs/${JID}/trace"
    ;;

  *)
    usage
    ;;
esac
