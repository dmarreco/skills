#!/usr/bin/env python3
"""Markdown → Confluence storage HTML (subset).

Converts a limited subset of Markdown to Confluence storage format: headings
(h1–h3), paragraphs, bullet lists, GFM-style tables, horizontal rules, links,
bold, and inline code. For full Markdown publishing, prefer md2conf (see
confluence-writer SKILL.md).

Requires Python 3.9+.
"""
import html
import re
import sys


def linkify(text: str) -> str:
    def repl(m):
        t, u = m.group(1), m.group(2)
        return f'<a href="{html.escape(u, quote=True)}">{process_inline(t)}</a>'

    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", repl, text)


def boldify(text: str) -> str:
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def inline_code(text: str) -> str:
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", text)


def process_inline(text: str) -> str:
    text = inline_code(text)
    text = linkify(text)
    text = boldify(text)
    return text


def is_table_sep(line: str) -> bool:
    s = line.strip()
    if not s.startswith("|"):
        return False
    return bool(re.match(r"^\|[\s\-:|]+\|\s*$", s))


def parse_table_row(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def main():
    if len(sys.argv) < 2:
        print("Usage: md_to_confluence_storage.py INPUT.md", file=sys.stderr)
        sys.exit(1)
    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    out: list[str] = []
    i = 0
    in_ul = False

    def close_ul():
        nonlocal in_ul
        if in_ul:
            out.append("</ul>")
            in_ul = False

    while i < len(lines):
        line = lines[i]
        stripped = line.rstrip("\n").strip()

        # Markdown table block
        if stripped.startswith("|") and i + 1 < len(lines) and is_table_sep(lines[i + 1]):
            close_ul()
            header = parse_table_row(stripped)
            i += 2  # skip separator
            out.append("<table><tbody>")
            out.append("<tr>" + "".join(f"<th><p>{process_inline(html.escape(c))}</p></th>" for c in header) + "</tr>")
            while i < len(lines) and lines[i].strip().startswith("|") and not is_table_sep(lines[i]):
                cells = parse_table_row(lines[i])
                # pad cells if ragged
                while len(cells) < len(header):
                    cells.append("")
                row = "<tr>"
                for c in cells[: len(header)]:
                    row += f"<td><p>{process_inline(html.escape(c))}</p></td>"
                row += "</tr>"
                out.append(row)
                i += 1
            out.append("</tbody></table>")
            continue

        if not stripped:
            close_ul()
            out.append("<p />")
            i += 1
            continue

        if stripped == "---":
            close_ul()
            out.append("<hr />")
            i += 1
            continue

        if stripped.startswith("# "):
            close_ul()
            out.append(f"<h1>{process_inline(html.escape(stripped[2:]))}</h1>")
            i += 1
            continue
        if stripped.startswith("## "):
            close_ul()
            out.append(f"<h2>{process_inline(html.escape(stripped[3:]))}</h2>")
            i += 1
            continue
        if stripped.startswith("### "):
            close_ul()
            out.append(f"<h3>{process_inline(html.escape(stripped[4:]))}</h3>")
            i += 1
            continue

        if stripped.startswith("- ") or (stripped.startswith("* ") and not stripped.startswith("**")):
            if not in_ul:
                out.append("<ul>")
                in_ul = True
            item = stripped[2:].strip()
            out.append(f"<li><p>{process_inline(html.escape(item))}</p></li>")
            i += 1
            continue

        if re.match(r"^\d+\.\s", stripped):
            close_ul()
            rest = re.sub(r"^\d+\.\s", "", stripped)
            out.append(f"<p>{process_inline(html.escape(rest))}</p>")
            i += 1
            continue

        close_ul()
        out.append(f"<p>{process_inline(html.escape(stripped))}</p>")
        i += 1

    close_ul()
    print("".join(out))


if __name__ == "__main__":
    main()
