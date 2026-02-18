#!/usr/bin/env python3
"""Build structured SQLite knowledge database for AMD docs and local VHDL usage."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from doc_profiles import DOCS, normalize_doc_id

DEFAULT_DB = Path(
    ".codex/skills/fpga-vivado-vitis-structure/references/.cache/skill_knowledge.sqlite",
)
ATTR_SOURCE = Path(".codex/vhdl-attributes.md")

NONSTD_NUMERIC_RE = re.compile(
    r"\buse\s+ieee\.(std_logic_arith|std_logic_unsigned|std_logic_signed)\.all\s*;",
    re.IGNORECASE,
)
NUMERIC_STD_RE = re.compile(r"\buse\s+ieee\.numeric_std\.all\s*;", re.IGNORECASE)
ENTITY_RE = re.compile(
    r"\bentity\s+(?P<name>[A-Za-z][A-Za-z0-9_]*)\s+is\b",
    re.IGNORECASE,
)
ARCH_RE = re.compile(
    r"\barchitecture\s+(?P<name>[A-Za-z][A-Za-z0-9_]*)\s+of\s+(?P<entity>[A-Za-z][A-Za-z0-9_]*)\s+is\b",
    re.IGNORECASE,
)
PROCESS_LABEL_RE = re.compile(
    r"^\s*(?P<label>[A-Za-z][A-Za-z0-9_]*)\s*:\s*process\b",
    re.IGNORECASE,
)
ENTITY_BLOCK_RE = re.compile(
    r"\bentity\s+[A-Za-z][A-Za-z0-9_]*\s+is\b(?P<body>.*?)(?:\bend\s+entity(?:\s+[A-Za-z][A-Za-z0-9_]*)?\s*;|\bend\s*;)",
    re.IGNORECASE | re.DOTALL,
)
PORT_BLOCK_RE = re.compile(
    r"\bport\s*\((?P<ports>.*?)\)\s*;",
    re.IGNORECASE | re.DOTALL,
)
PORT_DECL_RE = re.compile(
    r"(?P<names>[A-Za-z0-9_,\s]+?)\s*:\s*(?P<direction>inout|in|out|buffer)\b\s*(?P<type>[^;]+);",
    re.IGNORECASE | re.DOTALL,
)


@dataclass(frozen=True)
class PortDecl:
    name: str
    direction: str
    type_expr: str
    line_no: int


@dataclass(frozen=True)
class PatternHit:
    pattern_key: str
    line_no: int
    match_text: str
    severity: str
    details_json: str


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build SQLite skill knowledge database.",
    )
    parser.add_argument(
        "--db",
        default=str(DEFAULT_DB),
        help="Output sqlite database path.",
    )
    parser.add_argument(
        "--docs",
        default="all",
        help="Comma-separated doc IDs or 'all'. Default: all configured docs.",
    )
    parser.add_argument("--rtl-root", default="rtl", help="RTL root path. Default: rtl")
    parser.add_argument(
        "--recreate",
        action="store_true",
        help="Delete and recreate DB file before build.",
    )
    parser.add_argument(
        "--backend",
        choices=("regex", "pyvhdlparser"),
        default="regex",
        help="VHDL extraction backend. Default: regex",
    )
    return parser.parse_args(argv)


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def parse_docs_arg(value: str) -> list[str]:
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
            raise ValueError(f"Unknown doc id in --docs: {item!r}")
        if doc_id not in out:
            out.append(doc_id)
    if not out:
        raise ValueError("No valid docs selected")
    return out


def ensure_backend(backend: str) -> str:
    if backend != "pyvhdlparser":
        return "regex"

    try:
        __import__("pyVHDLParser")
        print(
            "[WARN] pyVHDLParser backend is not implemented yet; using regex backend.",
            file=sys.stderr,
        )
        return "regex"
    except Exception:
        print(
            "[WARN] pyVHDLParser not installed; using regex backend.",
            file=sys.stderr,
        )
        return "regex"


def connect_db(db_path: Path, recreate: bool) -> sqlite3.Connection:
    if recreate and db_path.exists():
        db_path.unlink()

    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS documents (
          doc_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          pdf_path TEXT NOT NULL,
          index_json_path TEXT NOT NULL,
          source_dir TEXT NOT NULL,
          chapters_count INTEGER NOT NULL,
          sections_count INTEGER NOT NULL,
          indexed_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS amd_segments (
          segment_uid TEXT PRIMARY KEY,
          doc_id TEXT NOT NULL,
          kind TEXT NOT NULL,
          segment_id TEXT,
          parent_id TEXT,
          title TEXT NOT NULL,
          rel_file TEXT NOT NULL,
          abs_file TEXT NOT NULL,
          start_line INTEGER,
          end_line INTEGER,
          start_page INTEGER,
          end_page INTEGER,
          content TEXT NOT NULL,
          FOREIGN KEY (doc_id) REFERENCES documents(doc_id)
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS amd_segments_fts USING fts5 (
          segment_uid UNINDEXED,
          doc_id UNINDEXED,
          kind UNINDEXED,
          title,
          content
        );

        CREATE TABLE IF NOT EXISTS vhdl_files (
          file_id INTEGER PRIMARY KEY AUTOINCREMENT,
          rel_path TEXT NOT NULL UNIQUE,
          entity_name TEXT,
          architecture_name TEXT,
          uses_numeric_std INTEGER NOT NULL,
          uses_nonstd_numeric INTEGER NOT NULL,
          analyzed_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS vhdl_ports (
          port_id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id INTEGER NOT NULL,
          port_name TEXT NOT NULL,
          direction TEXT NOT NULL,
          type_expr TEXT NOT NULL,
          prefix_class TEXT NOT NULL,
          active_low_suffix INTEGER NOT NULL,
          FOREIGN KEY (file_id) REFERENCES vhdl_files(file_id)
        );

        CREATE TABLE IF NOT EXISTS vhdl_pattern_hits (
          hit_id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id INTEGER NOT NULL,
          pattern_key TEXT NOT NULL,
          line_no INTEGER NOT NULL,
          match_text TEXT NOT NULL,
          severity TEXT NOT NULL,
          details_json TEXT NOT NULL,
          FOREIGN KEY (file_id) REFERENCES vhdl_files(file_id)
        );

        CREATE TABLE IF NOT EXISTS vhdl_attributes_ref (
          attr_name TEXT PRIMARY KEY,
          summary TEXT NOT NULL,
          group_name TEXT,
          source_path TEXT NOT NULL
        );
        """,
    )


def clear_dynamic_tables(conn: sqlite3.Connection) -> None:
    conn.execute("DELETE FROM amd_segments_fts")
    conn.execute("DELETE FROM amd_segments")
    conn.execute("DELETE FROM documents")
    conn.execute("DELETE FROM vhdl_ports")
    conn.execute("DELETE FROM vhdl_pattern_hits")
    conn.execute("DELETE FROM vhdl_files")
    conn.execute("DELETE FROM vhdl_attributes_ref")


def load_index(index_path: Path) -> dict:
    if not index_path.exists():
        return {}
    return json.loads(index_path.read_text(encoding="utf-8"))


def ingest_documents(conn: sqlite3.Connection, doc_ids: list[str]) -> tuple[int, int]:
    doc_count = 0
    segment_count = 0
    indexed_at = now_iso()

    for doc_id in doc_ids:
        profile = DOCS[doc_id]
        base = Path(profile.query_dir)
        index_path = base / "index.json"
        data = load_index(index_path=index_path)

        chapters = list(data.get("chapters", []))
        sections = list(data.get("sections", []))

        conn.execute(
            """
            INSERT OR REPLACE INTO documents (
              doc_id, title, pdf_path, index_json_path, source_dir,
              chapters_count, sections_count, indexed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                doc_id,
                profile.extract.title,
                profile.extract.pdf_path,
                str(index_path),
                str(base),
                len(chapters),
                len(sections),
                indexed_at,
            ),
        )
        doc_count += 1

        all_segments: list[tuple[str, dict]] = []
        all_segments.extend(("chapter", item) for item in chapters)
        all_segments.extend(("section", item) for item in sections)

        for kind, item in all_segments:
            rel_file = item.get("file")
            if not rel_file:
                continue
            abs_file = (base / rel_file).resolve()
            content = abs_file.read_text(encoding="utf-8") if abs_file.exists() else ""

            segment_id = item.get("id")
            if segment_id:
                segment_uid = f"{doc_id}:{kind}:{segment_id}"
            else:
                segment_uid = f"{doc_id}:{kind}:{rel_file}"

            conn.execute(
                """
                INSERT OR REPLACE INTO amd_segments (
                  segment_uid, doc_id, kind, segment_id, parent_id,
                  title, rel_file, abs_file,
                  start_line, end_line, start_page, end_page, content
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    segment_uid,
                    doc_id,
                    kind,
                    segment_id,
                    item.get("parent"),
                    item.get("title", ""),
                    rel_file,
                    str(abs_file),
                    item.get("start_line"),
                    item.get("end_line"),
                    item.get("start_page"),
                    item.get("end_page"),
                    content,
                ),
            )
            segment_count += 1

    conn.execute(
        """
        INSERT INTO amd_segments_fts (segment_uid, doc_id, kind, title, content)
        SELECT segment_uid, doc_id, kind, title, content FROM amd_segments
        """,
    )

    return doc_count, segment_count


def classify_prefix(name: str) -> str:
    for prefix in ("i_", "o_", "s_", "v_", "P_", "U_", "G_", "C_"):
        if name.startswith(prefix):
            return prefix
    return "other"


def parse_ports(text: str) -> list[PortDecl]:
    entity_match = ENTITY_BLOCK_RE.search(text)
    if not entity_match:
        return []

    body = entity_match.group("body")
    body_start = entity_match.start("body")
    port_match = PORT_BLOCK_RE.search(body)
    if not port_match:
        return []

    ports_block = port_match.group("ports")
    block_abs_start = body_start + port_match.start("ports")
    block_start_line = text[:block_abs_start].count("\n") + 1

    decls: list[PortDecl] = []
    for match in PORT_DECL_RE.finditer(ports_block + ";"):
        names = [
            part.strip() for part in match.group("names").split(",") if part.strip()
        ]
        direction = match.group("direction").lower()
        type_expr = re.sub(r"\s+", " ", match.group("type").strip())
        line_no = block_start_line + ports_block[: match.start()].count("\n")
        for name in names:
            decls.append(
                PortDecl(
                    name=name,
                    direction=direction,
                    type_expr=type_expr,
                    line_no=line_no,
                ),
            )

    return decls


def expected_port_prefix_ok(name: str, direction: str) -> bool:
    if direction == "in":
        return name.startswith("i_")
    if direction in ("out", "buffer"):
        return name.startswith("o_")
    if direction == "inout":
        return name.startswith("io_") or name.startswith("i_") or name.startswith("o_")
    return True


def collect_pattern_hits(
    text: str,
    ports: list[PortDecl],
    uses_numeric_std: bool,
) -> list[PatternHit]:
    hits: list[PatternHit] = []

    for line_no, line in enumerate(text.splitlines(), start=1):
        if NONSTD_NUMERIC_RE.search(line):
            hits.append(
                PatternHit(
                    pattern_key="library.nonstd_numeric_disallowed",
                    line_no=line_no,
                    match_text=line.strip(),
                    severity="error",
                    details_json=json.dumps({"rule": "Use ieee.numeric_std.all only."}),
                ),
            )

        proc = PROCESS_LABEL_RE.search(line)
        if proc:
            label = proc.group("label")
            if not (label.startswith("P_REG_") or label.startswith("P_COMB_")):
                hits.append(
                    PatternHit(
                        pattern_key="process.label.naming_expected",
                        line_no=line_no,
                        match_text=label,
                        severity="warn",
                        details_json=json.dumps({"expected": ["P_REG_*", "P_COMB_*"]}),
                    ),
                )

    if not uses_numeric_std:
        hits.append(
            PatternHit(
                pattern_key="library.numeric_std_missing",
                line_no=1,
                match_text="numeric_std use clause not found",
                severity="warn",
                details_json=json.dumps({"expected": "use ieee.numeric_std.all;"}),
            ),
        )

    for port in ports:
        if not expected_port_prefix_ok(name=port.name, direction=port.direction):
            hits.append(
                PatternHit(
                    pattern_key="naming.port_prefix_expected",
                    line_no=port.line_no,
                    match_text=port.name,
                    severity="warn",
                    details_json=json.dumps(
                        {
                            "direction": port.direction,
                            "expected": "i_ for in, o_ for out/buffer, io_/i_/o_ for inout",
                        },
                    ),
                ),
            )

        low_name = port.name.lower()
        if ("rst" in low_name or "reset" in low_name) and not port.name.endswith("_n"):
            hits.append(
                PatternHit(
                    pattern_key="naming.active_low_reset_suffix_expected",
                    line_no=port.line_no,
                    match_text=port.name,
                    severity="warn",
                    details_json=json.dumps({"expected_suffix": "_n"}),
                ),
            )

    return hits


def ingest_vhdl(
    conn: sqlite3.Connection,
    rtl_root: Path,
    backend: str,
) -> tuple[int, int, int]:
    if not rtl_root.exists():
        print(f"[WARN] RTL root not found: {rtl_root}", file=sys.stderr)
        return 0, 0, 0

    analyzed_at = now_iso()
    file_count = 0
    port_count = 0
    hit_count = 0

    for path in sorted(rtl_root.rglob("*.vhd")):
        text = path.read_text(encoding="utf-8")
        rel_path = path.as_posix()
        entity_match = ENTITY_RE.search(text)
        arch_match = ARCH_RE.search(text)

        entity_name = entity_match.group("name") if entity_match else None
        architecture_name = arch_match.group("name") if arch_match else None
        uses_numeric_std = bool(NUMERIC_STD_RE.search(text))
        uses_nonstd_numeric = bool(NONSTD_NUMERIC_RE.search(text))

        cur = conn.execute(
            """
            INSERT INTO vhdl_files (
              rel_path, entity_name, architecture_name,
              uses_numeric_std, uses_nonstd_numeric, analyzed_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                rel_path,
                entity_name,
                architecture_name,
                int(uses_numeric_std),
                int(uses_nonstd_numeric),
                analyzed_at,
            ),
        )
        file_id = int(cur.lastrowid)
        file_count += 1

        ports = parse_ports(text=text)
        for port in ports:
            conn.execute(
                """
                INSERT INTO vhdl_ports (
                  file_id, port_name, direction, type_expr,
                  prefix_class, active_low_suffix
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    file_id,
                    port.name,
                    port.direction,
                    port.type_expr,
                    classify_prefix(port.name),
                    int(port.name.endswith("_n")),
                ),
            )
            port_count += 1

        hits = collect_pattern_hits(
            text=text,
            ports=ports,
            uses_numeric_std=uses_numeric_std,
        )
        for hit in hits:
            conn.execute(
                """
                INSERT INTO vhdl_pattern_hits (
                  file_id, pattern_key, line_no, match_text, severity, details_json
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    file_id,
                    hit.pattern_key,
                    hit.line_no,
                    hit.match_text,
                    hit.severity,
                    hit.details_json,
                ),
            )
            hit_count += 1

    return file_count, port_count, hit_count


def parse_attribute_groups(lines: list[str]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for line in lines:
        text = line.strip()
        if not text.startswith("- ") or ":" not in text:
            continue
        if "`" not in text:
            continue
        group, values = text[2:].split(":", 1)
        attrs = re.findall(r"`([^`]+)`", values)
        for attr in attrs:
            mapping[attr] = group.strip()
    return mapping


def ingest_attributes(conn: sqlite3.Connection, source_path: Path) -> int:
    if not source_path.exists():
        print(f"[WARN] Attributes source not found: {source_path}", file=sys.stderr)
        return 0

    lines = source_path.read_text(encoding="utf-8").splitlines()
    group_map = parse_attribute_groups(lines=lines)

    count = 0
    for line in lines:
        text = line.strip()
        if not text.startswith("|"):
            continue
        if "`" not in text:
            continue

        parts = [part.strip() for part in text.strip("|").split("|")]
        if len(parts) < 3:
            continue
        if not (parts[0].startswith("`") and parts[0].endswith("`")):
            continue

        attr_name = parts[0].strip("`").strip()
        if not attr_name or attr_name.lower() == "attribute":
            continue

        summary = parts[2].strip()
        if summary.startswith("---"):
            continue

        conn.execute(
            """
            INSERT OR REPLACE INTO vhdl_attributes_ref (attr_name, summary, group_name, source_path)
            VALUES (?, ?, ?, ?)
            """,
            (
                attr_name,
                summary,
                group_map.get(attr_name),
                source_path.as_posix(),
            ),
        )
        count += 1

    return count


def count_rows(conn: sqlite3.Connection, table: str) -> int:
    row = conn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()
    assert row is not None
    return int(row["c"])


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        doc_ids = parse_docs_arg(args.docs)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    backend = ensure_backend(args.backend)
    db_path = Path(args.db)
    rtl_root = Path(args.rtl_root)

    conn = connect_db(db_path=db_path, recreate=args.recreate)
    try:
        init_schema(conn)
        clear_dynamic_tables(conn)

        doc_count, segment_count = ingest_documents(conn=conn, doc_ids=doc_ids)
        file_count, port_count, hit_count = ingest_vhdl(
            conn=conn,
            rtl_root=rtl_root,
            backend=backend,
        )
        attr_count = ingest_attributes(conn=conn, source_path=ATTR_SOURCE)

        conn.commit()

        print(f"Wrote database: {db_path}")
        print(f"documents: {doc_count}")
        print(f"amd_segments: {segment_count}")
        print(f"vhdl_files: {file_count}")
        print(f"vhdl_ports: {port_count}")
        print(f"vhdl_pattern_hits: {hit_count}")
        print(f"vhdl_attributes_ref: {attr_count}")
        print(f"amd_segments_fts: {count_rows(conn, 'amd_segments_fts')}")
    finally:
        conn.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
