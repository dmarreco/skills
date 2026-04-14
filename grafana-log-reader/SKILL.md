---
name: grafana-log-reader
description: >-
  Queries Grafana Loki for logs via LogQL through the Grafana datasource
  proxy. Saves output to temp files for agent analysis. Use when the user
  asks to fetch, query, check, or read logs from Grafana, Loki, or mentions
  LogQL, container logs, error logs, or log analysis.
---

# Grafana Log Reader

## Role

This skill handles the **technical mechanics** of querying Grafana Loki:
authentication, API calls, response parsing, and saving output to files.

It does NOT decide:
- Which datasource to query (provide via `--datasource`)
- What LogQL query to run
- How to interpret or act on the results

## Prerequisites

Credentials are shell exports in `~/.grafana_config`:

- `GRAFANA_URL` — base URL, no trailing slash (e.g. `https://grafana.example.com`)
- `GRAFANA_TOKEN` — Grafana service account Bearer token

Always `source ~/.grafana_config` before `curl`. Never print or log the token.

Requires `python3` on PATH (for log extraction).

When running `curl` against Grafana, use `required_permissions: ["full_network"]`.

## Scripts

### `grafana-discover-datasources.sh`

Lists all Loki datasources available in the Grafana instance.

```bash
~/.cursor/skills/grafana-log-reader/scripts/grafana-discover-datasources.sh
```

- Calls `GET /api/datasources` with Bearer token
- Filters for `type == "loki"`
- Prints each datasource's numeric `id`, `name`, and `uid`

Use this to find the datasource name or ID to pass to the query script.

### `grafana-query-logs.sh`

Queries Loki and saves results to a temp directory.

```
grafana-query-logs.sh --datasource NAME_OR_ID "LOGQL_QUERY" [--since DURATION] [--limit N]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--datasource` | yes | — | Loki datasource name or numeric ID |
| query | yes | — | LogQL query string |
| `--since` | no | `1h` | Time window: `30m`, `1h`, `6h`, `24h`, etc. |
| `--limit` | no | `1000` | Max log entries (Loki hard cap: 5000) |

Output goes to `/tmp/grafana-logs/{datasource_hash}-{query_hash}-{timestamp}/`:
- `raw-response.json` — full Loki API response
- `logs.txt` — human-readable `YYYY-MM-DD HH:MM:SS.mmm | log_line`
- `query-info.txt` — metadata (datasource, query, time range, line count)

Auto-cleans directories older than 7 days.

### `extract-log-lines.py`

Reads Loki JSON from stdin, writes sorted log lines to stdout.

```bash
cat raw-response.json | python3 scripts/extract-log-lines.py
```

Format: `YYYY-MM-DD HH:MM:SS.mmm | log_line`

## Output structure

```
/tmp/grafana-logs/a1b2c3-d4e5f6-20260408T143022/
├── query-info.txt
├── raw-response.json
└── logs.txt
```

The directory name uses short hashes of the datasource and query plus the execution timestamp — so different queries never overwrite each other.

## Limitations

- **Read-only** — queries logs only, no writes to Grafana or Loki.
- **5000-entry cap** — Loki API hard limit per request. For larger volumes, suggest narrowing the time window or adding filters.
- **No pagination** — Loki does not support cursor-based pagination in `query_range`.
- Do not echo `GRAFANA_TOKEN` or `Authorization` headers in chat or logs.
- If the API returns 401/403, tell the user to check the service account token scope.

## Additional resources

- Loki HTTP API: [Loki HTTP API reference](https://grafana.com/docs/loki/latest/reference/loki-http-api/)
- LogQL: [Log queries documentation](https://grafana.com/docs/loki/latest/query/log_queries/)
- Grafana auth: [HTTP API authentication](https://grafana.com/docs/grafana/latest/developer-resources/api-reference/http-api/authentication/)
