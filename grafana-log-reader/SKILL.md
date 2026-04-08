---
name: grafana-log-reader
description: >-
  Queries Grafana Loki for logs via LogQL across multiple environment
  datasources (dev, qa, sbx, prd). Saves output to temp files for agent
  analysis. Use when the user asks to fetch, query, check, or read logs
  from Grafana, Loki, or mentions LogQL, container logs, error logs, or
  log analysis.
---

# Grafana Log Reader

## Prerequisites

Credentials are shell exports in `~/.grafana_config`:

- `GRAFANA_URL` — base URL, no trailing slash (e.g. `https://grafana.example.com`)
- `GRAFANA_TOKEN` — Grafana service account Bearer token

Always `source ~/.grafana_config` before `curl`. Never print or log the token.

Requires `python3` on PATH (for log extraction).

When running `curl` against Grafana, use `required_permissions: ["full_network"]`.

## Datasource map

The file [`datasources.json`](datasources.json) maps environment aliases to Loki datasource names and numeric IDs. The `id` fields start as `null` and are populated by the discovery script.

Environments: `dev`, `qa`, `sbx`, `prd`. Note that `sbx` and `sbx-b` share the same Loki datasource — they are differentiated by namespace in the LogQL query (e.g. `namespace="elr"` for sbx, `namespace="slr-sbx-b"` for sbx-b).

## Workflow

### Step 1 — Validate

1. Check `~/.grafana_config` exists and has `GRAFANA_URL` and `GRAFANA_TOKEN`.
2. Check `datasources.json` — if any needed environment has `"id": null`, run discovery first:
   ```bash
   ~/.cursor/skills/grafana-log-reader/scripts/grafana-discover-datasources.sh
   ```

### Step 2 — Query

Run the query script with the environment and LogQL string:

```bash
~/.cursor/skills/grafana-log-reader/scripts/grafana-query-logs.sh \
  --env qa \
  '{container="data-ingest-service", namespace="elr"} | json | level = `ERROR` | line_format `{{.log}}`' \
  --since 1h \
  --limit 1000
```

The script prints the output directory path, line count, and file sizes.

### Step 3 — Analyze

Read `logs.txt` selectively — **do not load the entire file into context**:

- Use `Read` with `offset` and `limit` for head/tail
- Use `Grep` to search for patterns within the file
- Read `query-info.txt` to confirm which query produced the output

### Step 4 — Report

Present a concise summary to the user:
- Total log lines found
- Time range covered
- Key patterns (e.g. top error messages, frequency, affected components)
- The output file path so the user can inspect raw data if needed

## Scripts

### `grafana-discover-datasources.sh`

Discovers Loki datasource numeric IDs and updates `datasources.json`.

```bash
~/.cursor/skills/grafana-log-reader/scripts/grafana-discover-datasources.sh
```

- Calls `GET /api/datasources` with Bearer token
- Filters for `type == "loki"`
- Matches each entry in `datasources.json` by name and fills in the numeric `id`
- Prints all discovered Loki datasources
- Warns if any configured name is not found

### `grafana-query-logs.sh`

Main query script.

```
grafana-query-logs.sh --env ENV "LOGQL_QUERY" [--since DURATION] [--limit N]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--env` | yes | — | Environment alias from `datasources.json` |
| query | yes | — | LogQL query string |
| `--since` | no | `1h` | Time window: `30m`, `1h`, `6h`, `24h`, etc. |
| `--limit` | no | `1000` | Max log entries (Loki hard cap: 5000) |

Output goes to `/tmp/grafana-logs/{env}-{hash}-{timestamp}/`:
- `raw-response.json` — full Loki API response
- `logs.txt` — human-readable `YYYY-MM-DD HH:MM:SS.mmm | log_line`
- `query-info.txt` — metadata (env, datasource, query, time range, line count)

Auto-cleans directories older than 7 days.

### `extract-log-lines.py`

Reads Loki JSON from stdin, writes sorted log lines to stdout.

```bash
cat raw-response.json | python3 scripts/extract-log-lines.py
```

Format: `YYYY-MM-DD HH:MM:SS.mmm | log_line`

## Output structure

```
/tmp/grafana-logs/qa-a1b2c3-20260408T143022/
├── query-info.txt
├── raw-response.json
└── logs.txt
```

The directory name encodes the environment, a short MD5 hash of the query, and the execution timestamp — so different queries and repeat runs never overwrite each other.

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
