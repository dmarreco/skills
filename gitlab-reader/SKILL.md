---
name: gitlab-reader
description: >-
  Reads corporate GitLab (self-hosted) projects, repository files, code search,
  merge requests, and CI/CD pipelines using the GitLab REST API v4 and
  credentials in ~/.gitlab_readonly_config. Read-only; never push, create, or
  mutate. Use when the user asks about GitLab repos, MRs, pipelines, or code
  under scm.platform or their GitLab namespace.
---

# GitLab reader

## Prerequisites

Shell exports in `~/.gitlab_readonly_config`:

- `GITLAB_BASE_PROJECT_URL` — base URL including your namespace path, e.g. `https://scm.platform.us-west-2.avalara.io/daniel.marreco`
- `GITLAB_READONLY_TOKEN` — personal access token with read scopes

Derive the GitLab instance root (no API path) from the base project URL:

```bash
source ~/.gitlab_readonly_config
GITLAB_URL="$(dirname "${GITLAB_BASE_PROJECT_URL}")"
API="${GITLAB_URL}/api/v4"
```

Always `source ~/.gitlab_readonly_config` before `curl`. Never print or log the token.

## Shell execution

Use **network** permission when calling GitLab from the agent (e.g. `required_permissions: ["full_network"]`).

## Auth header

```bash
-H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}"
```

## Project identifier

Endpoints use `:id` which may be:

- Numeric project ID, or
- URL-encoded path: `namespace%2Fproject-name` (slashes → `%2F`)

## Preferred: helper script

```bash
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh projects [SEARCH]
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh tree PROJECT_PATH [DIR] [REF]
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh file PROJECT_PATH FILE [REF]
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh mrs PROJECT_PATH [STATE]
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh mr PROJECT_PATH MR_IID
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh pipelines PROJECT_PATH
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh jobs PROJECT_PATH PIPELINE_ID
~/.cursor/skills/gitlab-reader/scripts/gitlab-fetch.sh log PROJECT_PATH JOB_ID
```

`PROJECT_PATH` is either a numeric ID or a path like `group/subproject/repo`.

The `mr` subcommand prints two JSON blobs separated by lines `=== merge_request ===` and `=== changes ===` (from the MR and `/changes` endpoints).

Code search is not wrapped in the script; use the curl examples in section 3 below.

## 1. List projects

```bash
source ~/.gitlab_readonly_config
GITLAB_URL="$(dirname "${GITLAB_BASE_PROJECT_URL}")"
curl -sS -G -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects" \
  --data-urlencode "membership=true" \
  --data-urlencode "per_page=50" \
  --data-urlencode "search=KEYWORD"
```

Omit `search` to list projects you are a member of. Use `page=2` etc. for pagination.

## 2. Browse / read files

**List directory:**

```bash
source ~/.gitlab_readonly_config
GITLAB_URL="$(dirname "${GITLAB_BASE_PROJECT_URL}")"
ENC="group%2Fproject"
curl -sS -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/repository/tree?path=src&ref=main"
```

**Raw file:**

```bash
curl -sS -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/repository/files/README.md/raw?ref=main"
```

Encode nested paths in the file segment (e.g. `src%2Fmain%2Fjava%2FFoo.java`).

## 3. Search code

**Global (instance-wide, subject to token visibility):**

```bash
curl -sS -G -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/search" \
  --data-urlencode "scope=blobs" \
  --data-urlencode "search=query string"
```

**Project-scoped:**

```bash
curl -sS -G -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/search" \
  --data-urlencode "scope=blobs" \
  --data-urlencode "search=query"
```

## 4. Merge requests

**List MRs** (`state`: `opened`, `closed`, `merged`, or `all`):

```bash
curl -sS -G -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/merge_requests" \
  --data-urlencode "state=opened" \
  --data-urlencode "per_page=20"
```

**Single MR + diff:**

```bash
IID=42
curl -sS -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/merge_requests/${IID}"
curl -sS -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/merge_requests/${IID}/changes"
```

## 5. Pipelines and job logs

**List pipelines:**

```bash
curl -sS -G -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/pipelines" \
  --data-urlencode "per_page=20"
```

**Jobs in a pipeline:**

```bash
PIPELINE_ID=12345
curl -sS -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/pipelines/${PIPELINE_ID}/jobs"
```

**Job log (trace):**

```bash
JOB_ID=67890
curl -sS -H "PRIVATE-TOKEN: ${GITLAB_READONLY_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${ENC}/jobs/${JOB_ID}/trace"
```

## Present results

- Projects: table of `name`, `path_with_namespace`, `id`, `web_url`.
- Tree: indented paths or bullet list.
- Files: show raw text; truncate very large files with a note.
- MRs: title, state, author, source/target branches, link; summarize `changes` for small diffs.
- Pipelines: status, ref, SHA, web URL; job names and stages from jobs list.

## Limitations

- **Read-only** — no create, update, delete, push, or pipeline triggers.
- Token visibility limits which groups/projects appear in search and project lists.
- Large traces or huge MR diffs may need truncation or asking the user to open the web UI.

## Additional resources

- [GitLab REST API v4](https://docs.gitlab.com/ee/api/rest/)
