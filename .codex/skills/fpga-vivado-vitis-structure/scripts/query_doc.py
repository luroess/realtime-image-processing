#!/usr/bin/env python3
"""Search extracted Vivado documentation sections by keyword."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from doc_profiles import DOCS, normalize_doc_id


@dataclass(frozen=True)
class SearchEntry:
    doc_id: str
    kind: str
    title: str
    rel_file: str
    abs_file: Path


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Search split AMD doc corpora for matching text.")
    parser.add_argument("query", nargs="?", help="Query string or regex pattern.")
    parser.add_argument(
        "--doc",
        help="Document ID (ug934|ug835|ug892|ug896|ug1118) or 'all'.",
    )
    parser.add_argument(
        "--docs",
        help="Optional comma-separated doc subset (e.g. ug934,ug892).",
    )
    parser.add_argument(
        "--scope",
        choices=("sections", "chapters", "all"),
        default="sections",
        help="Search scope. Default: sections.",
    )
    parser.add_argument(
        "--include-chapters",
        action="store_true",
        help="Compatibility flag. Equivalent to --scope all.",
    )
    parser.add_argument(
        "--list-docs",
        action="store_true",
        help="List configured docs and exit.",
    )
    parser.add_argument(
        "--regex",
        action="store_true",
        help="Treat query as regex.",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=20,
        help="Maximum number of matching lines to print.",
    )
    parser.add_argument(
        "--context",
        type=int,
        default=1,
        help="Context lines before/after each match.",
    )
    return parser.parse_args(argv)


def compile_pattern(query: str, is_regex: bool) -> re.Pattern[str]:
    if is_regex:
        return re.compile(query, re.IGNORECASE)
    if re.fullmatch(r"[A-Za-z0-9_]+", query):
        return re.compile(rf"\b{re.escape(query)}\b", re.IGNORECASE)
    return re.compile(re.escape(query), re.IGNORECASE)


def parse_doc_subset(value: str | None) -> list[str] | None:
    if value is None:
        return None
    normalized: list[str] = []
    for raw in value.split(","):
        token = raw.strip()
        if not token:
            continue
        doc_id = normalize_doc_id(token)
        if doc_id is None or doc_id not in DOCS:
            raise ValueError(f"Unknown doc id in --docs: {token!r}")
        if doc_id not in normalized:
            normalized.append(doc_id)
    return normalized


def determine_scope(args: argparse.Namespace) -> str:
    if args.include_chapters:
        return "all"
    return args.scope


def list_docs() -> int:
    for doc_id in sorted(DOCS):
        print(f"{doc_id}: {DOCS[doc_id].extract.title}")
    return 0


def resolve_doc_ids(args: argparse.Namespace) -> list[str]:
    if args.doc is None:
        raise ValueError("--doc is required unless --list-docs is used")

    if args.doc.strip().lower() == "all":
        doc_ids = sorted(DOCS)
    else:
        one = normalize_doc_id(args.doc)
        if one is None or one not in DOCS:
            raise ValueError(f"Unknown --doc value: {args.doc!r}")
        doc_ids = [one]

    subset = parse_doc_subset(args.docs)
    if subset is not None:
        allowed = set(subset)
        doc_ids = [doc_id for doc_id in doc_ids if doc_id in allowed]

    if not doc_ids:
        raise ValueError("No documents selected after applying filters")
    return doc_ids


def load_index_data(index_path: Path) -> dict:
    if not index_path.exists():
        return {}
    return json.loads(index_path.read_text(encoding="utf-8"))


def select_entries(doc_id: str, data: dict, scope: str) -> tuple[list[tuple[str, dict]], bool]:
    sections = list(data.get("sections", []))
    chapters = list(data.get("chapters", []))

    if scope == "sections":
        if sections:
            return [("section", sec) for sec in sections], False
        if chapters:
            return [("chapter", ch) for ch in chapters], True
        return [], False

    if scope == "chapters":
        return [("chapter", ch) for ch in chapters], False

    # scope == "all"
    out: list[tuple[str, dict]] = []
    out.extend(("section", sec) for sec in sections)
    out.extend(("chapter", ch) for ch in chapters)
    return out, False


def gather_search_entries(doc_ids: list[str], scope: str) -> list[SearchEntry]:
    entries: list[SearchEntry] = []
    for doc_id in doc_ids:
        profile = DOCS[doc_id]
        base = Path(profile.query_dir)
        index_path = base / "index.json"
        data = load_index_data(index_path=index_path)
        if not data:
            print(f"[WARN][{doc_id}] missing or empty index: {index_path}", file=sys.stderr)
            continue

        selected, fell_back = select_entries(doc_id=doc_id, data=data, scope=scope)
        if fell_back:
            print(
                f"[WARN][{doc_id}] --scope sections found no sections; falling back to chapters.",
                file=sys.stderr,
            )

        for kind, item in selected:
            rel_file = item.get("file")
            title = item.get("title")
            if not rel_file or not title:
                continue
            abs_file = base / rel_file
            entries.append(
                SearchEntry(
                    doc_id=doc_id,
                    kind=kind,
                    title=title,
                    rel_file=rel_file,
                    abs_file=abs_file,
                )
            )

    return entries


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if args.list_docs:
        return list_docs()

    if not args.query:
        print("query is required unless --list-docs is used", file=sys.stderr)
        return 1

    try:
        doc_ids = resolve_doc_ids(args)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    scope = determine_scope(args)
    pattern = compile_pattern(args.query, args.regex)
    entries = gather_search_entries(doc_ids=doc_ids, scope=scope)

    if not entries:
        print("No index entries found.", file=sys.stderr)
        return 0

    hits = 0
    for entry in entries:
        if not entry.abs_file.exists():
            print(
                f"[WARN][{entry.doc_id}] missing section file: {entry.abs_file}",
                file=sys.stderr,
            )
            continue

        lines = entry.abs_file.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            if not pattern.search(line):
                continue

            print(f"[{entry.doc_id}][{entry.kind}] {entry.title} :: {entry.rel_file} :: line {i + 1}")
            start = max(0, i - args.context)
            end = min(len(lines), i + args.context + 1)
            for j in range(start, end):
                prefix = ">" if j == i else " "
                print(f"{prefix} {j + 1:04d}: {lines[j]}")
            print("")

            hits += 1
            if hits >= args.max_results:
                print(f"Reached max results ({args.max_results}).")
                return 0

    if hits == 0:
        print("No matches.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
