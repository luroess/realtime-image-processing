#!/usr/bin/env python3
"""Query the structured SQLite skill knowledge database."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path

from doc_profiles import DOCS, normalize_doc_id

DEFAULT_DB = Path(
    ".codex/skills/fpga-vivado-vitis-structure/references/.cache/skill_knowledge.sqlite"
)
REGEX_META_RE = re.compile(r"[.\^$*+?{}\[\]\\|()]")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Query VHDL/AMD skill SQLite database.")
    parser.add_argument("--db", default=str(DEFAULT_DB), help="Database path.")

    subparsers = parser.add_subparsers(dest="command")
    subparsers.required = True

    amd = subparsers.add_parser("amd", help="Query AMD doc segments.")
    amd.add_argument("--query", required=True, help="FTS query string.")
    amd.add_argument("--docs", default="all", help="Comma-separated doc IDs or 'all'.")
    amd.add_argument("--kind", choices=("section", "chapter", "all"), default="all")
    amd.add_argument("--limit", type=int, default=10)

    vhdl = subparsers.add_parser("vhdl", help="Query VHDL pattern hits.")
    vhdl.add_argument("--pattern", required=True, help="Pattern key or regex.")
    vhdl.add_argument("--severity", choices=("info", "warn", "error"))
    vhdl.add_argument("--limit", type=int, default=20)

    attr = subparsers.add_parser("attr", help="Query VHDL attributes reference.")
    attr.add_argument("--query", required=True, help="Substring query.")
    attr.add_argument("--limit", type=int, default=20)

    subparsers.add_parser("stats", help="Show database table statistics.")

    return parser.parse_args(argv)


def parse_doc_ids(value: str) -> list[str]:
    token = value.strip().lower()
    if token == "all":
        return sorted(DOCS)

    out: list[str] = []
    for raw in value.split(","):
        item = raw.strip()
        if not item:
            continue
        doc_id = normalize_doc_id(item)
        if doc_id is None or doc_id not in DOCS:
            raise ValueError(f"Unknown doc id: {item!r}")
        if doc_id not in out:
            out.append(doc_id)

    if not out:
        raise ValueError("No valid docs selected")
    return out


def format_ref(path: str | None, line_no: int | None) -> str:
    if not path:
        return "(unknown)"
    if line_no is None:
        return path
    return f"{path}:{line_no}"


def run_amd(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    try:
        doc_ids = parse_doc_ids(args.docs)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    clauses = ["amd_segments_fts MATCH ?"]
    params: list[object] = [args.query]

    if doc_ids:
        placeholders = ",".join("?" for _ in doc_ids)
        clauses.append(f"f.doc_id IN ({placeholders})")
        params.extend(doc_ids)

    if args.kind != "all":
        clauses.append("f.kind = ?")
        params.append(args.kind)

    where_sql = " AND ".join(clauses)
    sql = f"""
        SELECT
          f.doc_id,
          f.kind,
          s.title,
          s.rel_file,
          s.abs_file,
          s.start_line,
          snippet(amd_segments_fts, 4, '[', ']', ' ... ', 16) AS snippet
        FROM amd_segments_fts AS f
        JOIN amd_segments AS s
          ON s.segment_uid = f.segment_uid
        WHERE {where_sql}
        ORDER BY bm25(amd_segments_fts)
        LIMIT ?
    """
    params.append(args.limit)

    try:
        rows = conn.execute(sql, params).fetchall()
    except sqlite3.OperationalError as exc:
        print(f"FTS query error: {exc}", file=sys.stderr)
        return 1

    if not rows:
        print("No AMD matches.")
        return 0

    for row in rows:
        line_no = row["start_line"] if row["start_line"] is not None else None
        ref = format_ref(row["abs_file"], line_no)
        print(f"[{row['doc_id']}][{row['kind']}] {row['title']} :: {ref}")
        print(f"  snippet: {row['snippet']}")

    return 0


def run_vhdl(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    clauses = ["1=1"]
    params: list[object] = []

    if args.severity:
        clauses.append("p.severity = ?")
        params.append(args.severity)

    sql = f"""
        SELECT
          p.pattern_key,
          p.line_no,
          p.match_text,
          p.severity,
          p.details_json,
          f.rel_path
        FROM vhdl_pattern_hits AS p
        JOIN vhdl_files AS f
          ON f.file_id = p.file_id
        WHERE {' AND '.join(clauses)}
        ORDER BY f.rel_path, p.line_no
    """

    rows = conn.execute(sql, params).fetchall()
    if not rows:
        print("No VHDL pattern hits.")
        return 0

    regex_mode = bool(REGEX_META_RE.search(args.pattern))
    if regex_mode:
        try:
            regex = re.compile(args.pattern)
        except re.error as exc:
            print(f"Invalid regex for --pattern: {exc}", file=sys.stderr)
            return 1

        filtered = [
            row
            for row in rows
            if regex.search(row["pattern_key"]) or regex.search(row["match_text"])
        ]
    else:
        filtered = [row for row in rows if row["pattern_key"] == args.pattern]

    if not filtered:
        print("No VHDL matches.")
        return 0

    for row in filtered[: args.limit]:
        ref = format_ref(row["rel_path"], row["line_no"])
        print(f"[{row['severity']}] {row['pattern_key']} :: {ref}")
        print(f"  match: {row['match_text']}")
        details = row["details_json"]
        if details:
            try:
                parsed = json.loads(details)
                print(f"  details: {json.dumps(parsed, sort_keys=True)}")
            except json.JSONDecodeError:
                print(f"  details: {details}")

    return 0


def run_attr(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    query = f"%{args.query.lower()}%"
    rows = conn.execute(
        """
        SELECT attr_name, summary, group_name, source_path
        FROM vhdl_attributes_ref
        WHERE lower(attr_name) LIKE ? OR lower(summary) LIKE ?
        ORDER BY attr_name
        LIMIT ?
        """,
        (query, query, args.limit),
    ).fetchall()

    if not rows:
        print("No attribute matches.")
        return 0

    for row in rows:
        group = row["group_name"] or "ungrouped"
        print(f"[{group}] {row['attr_name']} :: {row['summary']}")
        print(f"  source: {row['source_path']}")

    return 0


def run_stats(conn: sqlite3.Connection) -> int:
    tables = (
        "documents",
        "amd_segments",
        "amd_segments_fts",
        "vhdl_files",
        "vhdl_ports",
        "vhdl_pattern_hits",
        "vhdl_attributes_ref",
    )

    for table in tables:
        row = conn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()
        assert row is not None
        print(f"{table}: {row['c']}")

    row = conn.execute("SELECT COUNT(DISTINCT doc_id) AS c FROM amd_segments").fetchone()
    assert row is not None
    print(f"amd_docs_indexed: {row['c']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    db_path = Path(args.db)

    if not db_path.exists():
        print(f"Database not found: {db_path}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        if args.command == "amd":
            return run_amd(conn=conn, args=args)
        if args.command == "vhdl":
            return run_vhdl(conn=conn, args=args)
        if args.command == "attr":
            return run_attr(conn=conn, args=args)
        if args.command == "stats":
            return run_stats(conn=conn)

        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
