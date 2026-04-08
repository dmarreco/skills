#!/usr/bin/env python3
"""Extract readable log lines from a Loki query_range JSON response.

Reads JSON from stdin, writes sorted log lines to stdout.
Format: YYYY-MM-DD HH:MM:SS.mmm | log_line

No external dependencies — stdlib only.
"""

import json
import sys
from datetime import datetime, timezone


def extract(response: dict) -> list[tuple[int, str]]:
    """Return (nanosecond_ts, log_line) pairs from all streams."""
    entries: list[tuple[int, str]] = []
    results = response.get("data", {}).get("result", [])
    for stream in results:
        for ts_ns_str, line in stream.get("values", []):
            entries.append((int(ts_ns_str), line))
    return entries


def format_ts(ns: int) -> str:
    dt = datetime.fromtimestamp(ns / 1e9, tz=timezone.utc)
    return dt.strftime("%Y-%m-%d %H:%M:%S.") + f"{dt.microsecond // 1000:03d}"


def main() -> None:
    raw = sys.stdin.read()
    if not raw.strip():
        return

    try:
        response = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON from Loki: {e}", file=sys.stderr)
        sys.exit(1)

    status = response.get("status")
    if status and status != "success":
        print(f"ERROR: Loki response status: {status}", file=sys.stderr)
        sys.exit(1)

    entries = extract(response)
    entries.sort(key=lambda e: e[0])

    for ts_ns, line in entries:
        sys.stdout.write(f"{format_ts(ts_ns)} | {line}\n")


if __name__ == "__main__":
    main()
