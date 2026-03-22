# Cursor skills

Personal [Agent Skills](https://docs.cursor.com) for this machine. Each skill lives in its own directory with a `SKILL.md` (and optional `scripts/`). Credentials stay **outside** this repo (e.g. `~/.atlassian_config`, `~/.gitlab_readonly_config`).

## Skills

| Skill | Description |
|-------|-------------|
| **confluence-reader** | Read Confluence pages and spaces (REST v1/v2), CQL search. Uses `~/.atlassian_config`. Read-only. |
| **confluence-writer** | Publish Markdown files to Confluence via md2conf (preferred) or raw storage HTML via curl. Same credentials as confluence-reader; writes only with explicit user authorization. |
| **epic-planning** | Structure epic planning under `epic-planning/` in a workspace: Jira exports, decisions log, `PLAN.md`, local commits. No confidential keys in the skill file. |
| **gitlab-reader** | Read-only GitLab API v4: projects, repo files, code search, MRs, pipelines/job logs. Uses `~/.gitlab_readonly_config`. |
| **jira-reader** | Read Jira issues, search with JQL (REST v3). Uses `~/.atlassian_config`. Read-only. |
| **skill-maintainer** | Workflow to stage, commit, and push changes in this repo, and to keep this README aligned with the skills list. |

## Credential files

Credentials stay **outside** this repo. Create the files below and never commit them.

### `~/.atlassian_config`

Used by: **jira-reader**, **confluence-reader**, **confluence-writer**, **epic-planning**.

```bash
# Jira + Confluence (core — used by all Atlassian skills)
export JIRA_BASE_URL="https://<org>.atlassian.net"
export CONFLUENCE_URL="https://<org>.atlassian.net/wiki"
export JIRA_EMAIL="<your-email>"
export JIRA_API_TOKEN="<your-atlassian-api-token>"

# md2conf aliases (used by confluence-writer / markdown-to-confluence CLI)
export CONFLUENCE_DOMAIN="<org>.atlassian.net"
export CONFLUENCE_PATH="/wiki/"
export CONFLUENCE_USER_NAME="${JIRA_EMAIL}"
export CONFLUENCE_API_KEY="${JIRA_API_TOKEN}"

# Personal Confluence space (used by confluence-writer scripts)
export CONFLUENCE_SPACE_KEY="~<your-account-id>"
export CONFLUENCE_HOMEPAGE_ID="<numeric-page-id>"
```

Generate an API token at <https://id.atlassian.com/manage-profile/security/api-tokens>.

### `~/.gitlab_readonly_config`

Used by: **gitlab-reader**.

```bash
export GITLAB_BASE_PROJECT_URL="https://<gitlab-host>/api/v4/projects/<project-id>"
export GITLAB_READONLY_TOKEN="<personal-access-token>"
```

Create a **read_api** scoped token in GitLab → User Settings → Access Tokens.

## Layout

```
~/.cursor/skills/
├── README.md
├── confluence-reader/
├── confluence-writer/
├── epic-planning/
├── gitlab-reader/
├── jira-reader/
└── skill-maintainer/
```
