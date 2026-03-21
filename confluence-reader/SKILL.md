---
name: confluence-reader
description: >-
  Fetches and reads Confluence pages and spaces from Avalara's Atlassian Cloud
  instance using REST APIs and credentials in ~/.atlassian_config. Use when the
  user asks about Confluence, wiki pages, documentation, knowledge base, CQL
  search, or URLs under avalara.atlassian.net/wiki. Read-only; never create,
  update, or delete content.
---

# Confluence reader

## Prerequisites

Same file as Jira: `~/.atlassian_config` with:

- `CONFLUENCE_URL` — site wiki root, e.g. `https://avalara.atlassian.net/wiki`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN` (Atlassian API token works for Confluence Cloud REST)

Always `source ~/.atlassian_config` before `curl`. Never print or log the token.

## Shell execution

Use **network** permission when calling Atlassian from the agent (e.g. `required_permissions: ["full_network"]`).

## Base URLs

- **REST API v2** (pages, spaces): `${CONFLUENCE_URL}/api/v2/...`
- **REST API v1** (CQL content search, legacy): `${CONFLUENCE_URL}/rest/api/...`

## Fetch one page by ID

**Preferred:** helper script accepts a numeric page ID or a full Confluence URL containing `/pages/<digits>/`:

```bash
~/.cursor/skills/confluence-reader/scripts/confluence-fetch.sh 123456789
# or
~/.cursor/skills/confluence-reader/scripts/confluence-fetch.sh 'https://avalara.atlassian.net/wiki/spaces/FOO/pages/123456789/Title'
```

**Manual (v2):**

```bash
source ~/.atlassian_config
PAGE_ID=123456789
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${CONFLUENCE_URL}/api/v2/pages/${PAGE_ID}?body-format=storage"
```

`body-format=storage` returns Confluence storage (XHTML-like) in the JSON body for rendering or text extraction.

## Extract page ID from a URL

Cloud UI paths often look like:

- `.../wiki/spaces/{spaceKey}/pages/{pageId}/{title}`
- `.../wiki/pages/{pageId}/{title}`

The page ID is the **numeric** segment after `/pages/`. Regex: `/pages/([0-9]+)/`.

## Search pages (CQL) — v1

```bash
source ~/.atlassian_config
curl -s -G -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${CONFLUENCE_URL}/rest/api/content/search" \
  --data-urlencode "cql=type=page AND space = \"TEAMSPACE\" ORDER BY lastModified DESC" \
  --data-urlencode "limit=25"
```

Useful CQL patterns:

- Title: `type=page AND title = "Exact Title"`
- Space: `type=page AND space = "ENG"`
- Label: `type=page AND label = "architecture"`
- Text: `type=page AND text ~ \"search phrase\"`

Adjust space keys and quoting for your site.

## List spaces (v2)

```bash
source ~/.atlassian_config
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${CONFLUENCE_URL}/api/v2/spaces?limit=25"
```

## Present results

For a page: **title**, **space** (if available in response), **version / last modified**, **author** (if present), then body summarized from storage format (strip tags or convert to markdown for readability).

## Storage format

Page body in storage format is XML/HTML-like. For user-facing summaries, strip tags or map common elements (`p`, `h1`–`h6`, `ul`/`ol`/`li`, `ac:link`, etc.) to markdown. The agent can do this in prose without a fixed script.

## Limitations

- **Read-only** — no create/update/delete.
- Do not echo `JIRA_API_TOKEN` in chat or logs.
- v1 and v2 differ; prefer v2 for single-page fetch when possible; use v1 for CQL search where needed.

## Additional resources

- [Confluence Cloud REST API v2](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/)
- [Confluence REST API (v1) — CQL search](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-content/#api-wiki-rest-api-content-search-get)
