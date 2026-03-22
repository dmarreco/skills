---
name: jira-reader
description: >-
  Fetches and reads Jira issues from Avalara's Atlassian Cloud instance using
  REST API v3 and credentials in ~/.atlassian_config. Use when the user asks
  about Jira issues, tickets, epics, stories, sprints, JQL, or references issue
  keys like ELR-, FRMC-, or browse URLs on avalara.atlassian.net. Read-only;
  never create, update, or transition issues.
---

# Jira reader

## Prerequisites

Credentials are shell exports in `~/.atlassian_config`:

- `JIRA_BASE_URL` — e.g. `https://avalara.atlassian.net`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

Always `source ~/.atlassian_config` before `curl`. Never print or log the token.

## Shell execution

When running `curl` against Atlassian from the agent, use **network** permission (e.g. `required_permissions: ["full_network"]`).

## Fetch one issue

**Preferred:** run the helper script (limits fields, keeps responses small):

```bash
~/.cursor/skills/jira-reader/scripts/jira-fetch.sh ELR-32817
```

**Manual:**

```bash
source ~/.atlassian_config
FIELDS="summary,status,issuetype,priority,assignee,reporter,description,subtasks,issuelinks,labels,components,fixVersions,parent,created,updated"
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/ISSUE_KEY?fields=${FIELDS}"
```

Replace `ISSUE_KEY` with the key (e.g. `ELR-32817`). Omitting `fields` can return very large JSON (200KB+).

## Search with JQL

```bash
source ~/.atlassian_config
curl -s -G -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/search" \
  --data-urlencode "jql=YOUR_JQL" \
  --data-urlencode "fields=summary,status,issuetype,priority,assignee,labels" \
  --data-urlencode "maxResults=50"
```

Useful JQL examples:

- Project: `project = ELR ORDER BY updated DESC`
- Epic link field (classic): `"Epic Link" = ELR-32817` (field name may vary by project)
- Labels: `labels = FrancePDP AND project = ELR`
- Open work: `project = ELR AND statusCategory != Done`
- Assignee: `assignee = currentUser()`

## Parse description (ADF)

Issue `fields.description` is **Atlassian Document Format** (JSON). To summarize for the user:

- Recurse into `content` arrays.
- For nodes with `"type": "text"`, read `"text"`.
- `"type": "heading"` with `attrs.level` → markdown `#` … `######`.
- `bulletList` / `orderedList` → bullet or numbered lines.
- Text with `marks` containing `"type": "strong"` → **bold** in markdown.

A one-off Python snippet is fine for flattening ADF when needed.

## Present results

Use a short table plus narrative:

| Field | Value |
|-------|--------|
| Key | … |
| Summary | … |
| Type | … |
| Status | … |
| Priority | … |
| Assignee | … |
| Reporter | … |
| Labels | … |
| Parent | parent key — parent summary (if any) |
| Created / Updated | … |

Then **Issue links** (inward/outward summaries + keys) and **description** as readable markdown.

## Fetch epic/issue snapshot to file

Exports current-state issue data (fields, comments, links, subtasks) as
compact JSON. Used by the **epic-planning** agent to bootstrap
`epic-reference.json`. Strips changelog, renderedFields, avatarUrls, and
API self-links to keep the file concise (~30KB vs ~190KB).

```bash
~/.cursor/skills/jira-reader/scripts/fetch-jira-epic.sh ISSUE_KEY OUTPUT_DIR
# Example:
~/.cursor/skills/jira-reader/scripts/fetch-jira-epic.sh ELR-32817 ./ELR-32817-My-Epic
# → writes OUTPUT_DIR/epic-reference.json
```

The script creates `OUTPUT_DIR` if it doesn't exist. Requires
`full_network` permission and `python3` on PATH.

## Limitations

- **Read-only** — no POST/PUT/DELETE to Jira.
- Do not echo `JIRA_API_TOKEN` or full `Authorization` headers in chat or logs.
- If the API returns 401/403, tell the user to check token scope and site access.

## Additional resources

- Jira REST v3 reference: [Jira Cloud platform REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/)
