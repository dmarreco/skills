---
name: jira-reader
description: >-
  Fetches and reads Jira issues from a Jira Cloud instance using REST API v3
  and credentials in ~/.atlassian_config. Use when the user asks about Jira
  issues, tickets, epics, stories, sprints, JQL, or references Jira issue
  keys or browse URLs. Read-only; never create, update, or transition issues.
---

# Jira reader

## Role

This skill handles the **technical mechanics** of reading Jira issues:
authentication, REST API calls, JQL search, ADF parsing.

It does NOT decide:
- Which projects or issues are relevant
- What JQL queries to run
- How to present or act on the results

## Prerequisites

Credentials are shell exports in `~/.atlassian_config`:

- `JIRA_BASE_URL` — e.g. `https://your-site.atlassian.net`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

Always `source ~/.atlassian_config` before `curl`. Never print or log the token.

## Shell execution

When running `curl` against Atlassian from the agent, use **network** permission (e.g. `required_permissions: ["full_network"]`).

## Fetch one issue

**Preferred:** run the helper script (limits fields, keeps responses small):

```bash
~/.cursor/skills/jira-reader/scripts/jira-fetch.sh PROJECT-123
```

**Manual:**

```bash
source ~/.atlassian_config
FIELDS="summary,status,issuetype,priority,assignee,reporter,description,subtasks,issuelinks,labels,components,fixVersions,parent,created,updated"
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/ISSUE_KEY?fields=${FIELDS}"
```

Replace `ISSUE_KEY` with the actual key (e.g. `PROJECT-123`). Omitting `fields` can return very large JSON (200KB+).

## Search with JQL

```bash
source ~/.atlassian_config
curl -s -G -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/search" \
  --data-urlencode "jql=YOUR_JQL" \
  --data-urlencode "fields=summary,status,issuetype,priority,assignee,labels" \
  --data-urlencode "maxResults=50"
```

Useful JQL patterns:

- Project: `project = PROJ ORDER BY updated DESC`
- Epic link field (classic): `"Epic Link" = PROJ-123` (field name may vary by project)
- Labels: `labels = "some-label" AND project = PROJ`
- Open work: `project = PROJ AND statusCategory != Done`
- Assignee: `assignee = currentUser()`

## Parse description (ADF)

Issue `fields.description` is **Atlassian Document Format** (JSON). To summarize for the user:

- Recurse into `content` arrays.
- For nodes with `"type": "text"`, read `"text"`.
- `"type": "heading"` with `attrs.level` → markdown `#` … `######`.
- `bulletList` / `orderedList` → bullet or numbered lines.
- Text with `marks` containing `"type": "strong"` → **bold** in markdown.

A one-off Python snippet is fine for flattening ADF when needed.

## Fetch epic/issue snapshot to file

Exports current-state issue data (fields, comments, links, subtasks) as
compact JSON. Strips changelog, renderedFields, avatarUrls, and API
self-links to keep the file concise (~30KB vs ~190KB).

```bash
~/.cursor/skills/jira-reader/scripts/fetch-jira-epic.sh ISSUE_KEY OUTPUT_DIR
# Example:
~/.cursor/skills/jira-reader/scripts/fetch-jira-epic.sh PROJECT-123 ./PROJECT-123-snapshot
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
