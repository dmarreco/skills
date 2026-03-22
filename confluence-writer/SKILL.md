---
name: confluence-writer
description: >-
  Creates and updates Confluence pages in the user's personal space on Avalara's
  Atlassian Cloud instance. Use when the user explicitly asks to create, update,
  publish, or write a Confluence page. NEVER write without explicit user
  authorization. Uses same credentials as confluence-reader
  (~/.atlassian_config).
---

# Confluence writer

## Safety rule — MANDATORY

**Never create or update a Confluence page unless the user explicitly asks or
confirms.** If the context is ambiguous, ask first. Read operations should use
the `confluence-reader` skill instead.

## Prerequisites

Same file as confluence-reader: `~/.atlassian_config` with:

- `CONFLUENCE_URL` — e.g. `https://avalara.atlassian.net/wiki`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

Always `source ~/.atlassian_config` before `curl`. Never print or log the token.

## Shell execution

Use **network** permission when calling Atlassian (e.g. `required_permissions: ["full_network"]`).

## Personal space

- **Space key:** `~7120203cde98c85a0744c99291801a2e40f932`
- **Homepage ID:** `638522164553`

When creating pages, default to this personal space and use the homepage as
the parent unless the user specifies otherwise.

## Create a page

Helper script — accepts title, a file with the body in Confluence storage
format (XHTML), and an optional parent page ID (defaults to homepage):

```bash
~/.cursor/skills/confluence-writer/scripts/confluence-create.sh \
  "Page Title" /tmp/body.html [PARENT_PAGE_ID]
```

**Manual (v1 REST):**

```bash
source ~/.atlassian_config
SPACE_KEY="~7120203cde98c85a0744c99291801a2e40f932"
PARENT_ID=638522164553
TITLE="My Page"
BODY='<p>Hello world</p>'

curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X POST "${CONFLUENCE_URL}/rest/api/content" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "$TITLE" \
    --arg key "$SPACE_KEY" \
    --arg pid "$PARENT_ID" \
    --arg body "$BODY" \
    '{type:"page",title:$title,space:{key:$key},ancestors:[{id:$pid}],body:{storage:{value:$body,representation:"storage"}}}'
  )"
```

## Update a page

Helper script — accepts page ID and a file with the new body. Optionally
accepts a new title (keeps existing title if omitted):

```bash
~/.cursor/skills/confluence-writer/scripts/confluence-update.sh \
  PAGE_ID /tmp/body.html ["New Title"]
```

The script automatically fetches the current version number and increments it.

**Manual (v2 REST):**

```bash
source ~/.atlassian_config
PAGE_ID=123456789

# 1. Get current version
CURRENT=$(curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "${CONFLUENCE_URL}/api/v2/pages/${PAGE_ID}" | jq '.version.number')

# 2. Update
BODY='<p>Updated content</p>'
TITLE="Updated Title"

curl -sS -f -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -X PUT "${CONFLUENCE_URL}/api/v2/pages/${PAGE_ID}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg id "$PAGE_ID" \
    --arg title "$TITLE" \
    --argjson ver "$((CURRENT + 1))" \
    --arg body "$BODY" \
    '{id:$id,status:"current",title:$title,body:{representation:"storage",value:$body},version:{number:$ver}}'
  )"
```

## Preparing the body

Convert markdown content to Confluence storage format before sending. Common
mappings:

| Markdown          | Storage format                         |
|-------------------|----------------------------------------|
| `# Heading`       | `<h1>Heading</h1>`                     |
| `## Heading`      | `<h2>Heading</h2>`                     |
| `**bold**`        | `<strong>bold</strong>`                 |
| `*italic*`        | `<em>italic</em>`                      |
| `- item`          | `<ul><li>item</li></ul>`               |
| `1. item`         | `<ol><li>item</li></ol>`               |
| `` `code` ``      | `<code>code</code>`                    |
| code block        | `<ac:structured-macro ac:name="code">` |
| `[text](url)`     | `<a href="url">text</a>`              |
| `> blockquote`    | `<blockquote><p>text</p></blockquote>` |

For complex content, write the body to a temp file and pass it to the helper
scripts. The agent should generate valid XHTML (self-closing tags like `<br/>`).

## Workflow

1. **Draft** — compose the page content (ask the user to review if the content
   is substantial).
2. **Confirm** — get explicit user approval before writing.
3. **Write** — call the create or update script.
4. **Report** — show the resulting page URL to the user.

The page URL after creation follows the pattern:
`https://avalara.atlassian.net/wiki/spaces/{spaceKey}/pages/{pageId}/{urlTitle}`

## Limitations

- Only targets the user's personal space by default; other spaces require
  explicit space key / parent ID from the user.
- Storage format only (no editor v2 / Fabric format).
- Do not echo `JIRA_API_TOKEN` in chat or logs.
- Large pages may need chunked updates; the scripts do not handle attachments.

## Additional resources

- [Confluence Cloud REST API v2](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/)
- [Confluence REST API v1 — Content](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-content/)
