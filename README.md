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
