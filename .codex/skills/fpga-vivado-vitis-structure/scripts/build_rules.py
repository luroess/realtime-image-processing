#!/usr/bin/env python3
"""Build distilled rule summaries from extracted Vivado documentation."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from doc_profiles import get_profile


TOC_DOTS_RE = re.compile(r"(?:\.\s*){3,}\d+\s*$")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate distilled guidance rules from extracted AMD doc markdown.",
    )
    parser.add_argument(
        "--doc",
        help="Document ID (ug934|ug892). Required for canonical entrypoint.",
    )
    parser.add_argument(
        "--input",
        help="Input markdown file. Defaults from profile for the selected document.",
    )
    parser.add_argument(
        "--index",
        help="Optional section index file path for context suggestions.",
    )
    parser.add_argument(
        "--out",
        help="Output markdown path. Defaults from profile for the selected document.",
    )
    parser.add_argument(
        "--out-json",
        help="Output JSON path. Defaults from profile for the selected document.",
    )
    return parser.parse_args(argv)


def load_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def find_snippets(lines: list[str], patterns: list[str], window: int = 2, limit: int = 4) -> list[str]:
    compiled = [re.compile(p, re.IGNORECASE) for p in patterns]
    snippets: list[str] = []
    seen: set[str] = set()
    for i, line in enumerate(lines):
        if not any(c.search(line) for c in compiled):
            continue
        if TOC_DOTS_RE.search(line):
            continue
        start = max(0, i - window)
        end = min(len(lines), i + window + 1)
        chunk = []
        for x in lines[start:end]:
            t = x.strip()
            if not t:
                continue
            if TOC_DOTS_RE.search(t):
                continue
            chunk.append(t)
        block = re.sub(r"\s+", " ", " ".join(chunk)).strip()
        if not block:
            continue
        if block.lower().startswith("table of contents"):
            continue
        if block in seen:
            continue
        seen.add(block)
        snippets.append(block)
        if len(snippets) >= limit:
            break
    return snippets


def infer_sections(profile, index_path: Path, keywords: list[str]) -> list[str]:
    if not index_path.exists():
        return []
    data = json.loads(index_path.read_text(encoding="utf-8"))
    hits: list[str] = []
    normalized = [k.lower() for k in keywords]
    for sec in data.get("sections", []):
        title = sec.get("title", "")
        t = title.lower()
        if any(k in t for k in normalized):
            hits.append(f"{sec.get('title')} ({sec.get('file')})")
    return hits[:8]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        profile = get_profile(args.doc)
    except KeyError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if profile.build is None:
        print(f"No rule profile configured for {profile.doc_id}", file=sys.stderr)
        return 1

    input_path = Path(args.input or profile.build.input_markdown)
    index_path = Path(args.index or profile.build.index_path)
    out_md = Path(args.out or profile.build.out_markdown)
    out_json = Path(args.out_json or profile.build.out_json)
    if not input_path.exists():
        raise SystemExit(f"Missing input file: {input_path}")

    lines = load_lines(input_path)
    generated: list[dict] = []
    md_lines: list[str] = [
        profile.build.heading,
        "",
        profile.build.intro[0],
        "",
        profile.build.intro[1] if len(profile.build.intro) > 1 else "",
        "",
    ]
    if len(profile.build.intro) <= 1:
        md_lines.insert(2, "")

    for rule_idx, rule in enumerate(profile.build.rules, start=1):
        snippets = find_snippets(lines, list(rule.patterns), limit=rule.snippet_limit)
        related_sections = infer_sections(profile, index_path, list(rule.keywords))
        generated.append(
            {
                "id": rule.id,
                "rule": rule.rule,
                "snippets": snippets,
                "related_sections": related_sections,
            }
        )
        md_lines.append(f"{rule_idx}. {rule.rule}")
        if related_sections:
            md_lines.append(f"   Related sections: {', '.join(related_sections)}")
        if snippets:
            md_lines.append("   Evidence snippets:")
            for snippet in snippets:
                md_lines.append(f"   - {snippet}")
        md_lines.append("")

    md_lines.append("## Usage")
    md_lines.append("")
    md_lines.extend(profile.build.usage)
    md_lines.append("")

    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(md_lines), encoding="utf-8")
    out_json.write_text(json.dumps(generated, indent=2), encoding="utf-8")
    print(f"Wrote {out_md}")
    print(f"Wrote {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
