#!/usr/bin/env python3
"""Validate Typst citations in docs/report against references.bib."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

NON_BIB_PREFIXES = ("fig-", "eq-", "alg-", "tbl-", "sec-", "lst-")

BIB_ENTRY_RE = re.compile(r"@\w+\s*\{\s*([^,\s]+)\s*,")
# Keep shorthand syntax conservative; complex keys should use #cite(label("...")).
SHORTHAND_CITE_RE = re.compile(r"(?<![A-Za-z0-9_])@([A-Za-z0-9_:\-/]+)([.,;:])?")
CITE_ANGLE_RE = re.compile(r"#cite\s*\(\s*<([A-Za-z0-9_:\-.]+)>")
CITE_LABEL_RE = re.compile(r'#cite\s*\(\s*label\s*\(\s*"([^"]+)"\s*\)')

QUOTED_STRING_RE = re.compile(r'"(?:[^"\\]|\\.)*"')
LINE_COMMENT_RE = re.compile(r"//[^\n]*")
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", flags=re.DOTALL)


@dataclass(frozen=True)
class Diagnostic:
    path: str
    line: int
    code: str
    message: str


def keep_newline_blank(text: str) -> str:
    """Return spaces while preserving newline positions."""
    return "".join("\n" if ch == "\n" else " " for ch in text)


def masked_text(text: str) -> str:
    """Mask strings/comments to avoid false positives from literals/imports."""
    masked = QUOTED_STRING_RE.sub(lambda m: keep_newline_blank(m.group(0)), text)
    masked = LINE_COMMENT_RE.sub(lambda m: keep_newline_blank(m.group(0)), masked)
    masked = BLOCK_COMMENT_RE.sub(lambda m: keep_newline_blank(m.group(0)), masked)
    return masked


def line_for_offset(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def read_bib_keys(bib_path: Path) -> set[str]:
    data = bib_path.read_text(encoding="utf-8")
    return {match.group(1) for match in BIB_ENTRY_RE.finditer(data)}


def resolve_display_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def iter_typst_files(report_root: Path) -> list[Path]:
    return sorted(path for path in report_root.rglob("*.typ") if path.is_file())


def collect_citations(
    path: Path, text: str, *, strict: bool = True
) -> tuple[list[tuple[str, int]], list[Diagnostic]]:
    citations: list[tuple[str, int]] = []
    diagnostics: list[Diagnostic] = []
    mtext = masked_text(text)
    display_path = resolve_display_path(path)

    for match in SHORTHAND_CITE_RE.finditer(mtext):
        key = match.group(1)
        trailing = match.group(2)
        offset = match.start(1)
        line = line_for_offset(text, offset)

        # Ignore package imports like @preview/booktabs:0.0.4.
        if "/" in key:
            continue

        # Ignore Typst local label refs (figures/equations/etc).
        if key.startswith(NON_BIB_PREFIXES):
            continue

        if strict and trailing:
            diagnostics.append(
                Diagnostic(
                    path=display_path,
                    line=line,
                    code="E002",
                    message=(
                        f"malformed shorthand citation '@{key}{trailing}' "
                        "contains trailing punctuation; use '#cite(<key>).'"
                    ),
                )
            )
            continue

        citations.append((key, line))

    for regex in (CITE_ANGLE_RE, CITE_LABEL_RE):
        for match in regex.finditer(text):
            key = match.group(1)
            line = line_for_offset(text, match.start(1))
            citations.append((key, line))

    return citations, diagnostics


def validate(
    report_root: Path,
    bib_path: Path,
    *,
    strict: bool = True,
) -> list[Diagnostic]:
    if not report_root.exists():
        return [
            Diagnostic(
                path=resolve_display_path(report_root),
                line=1,
                code="E900",
                message="report root does not exist",
            )
        ]
    if not bib_path.exists():
        return [
            Diagnostic(
                path=resolve_display_path(bib_path),
                line=1,
                code="E901",
                message="bibliography file does not exist",
            )
        ]

    diagnostics: list[Diagnostic] = []
    bib_keys = read_bib_keys(bib_path)

    for typ_file in iter_typst_files(report_root):
        text = typ_file.read_text(encoding="utf-8")
        citations, cite_diags = collect_citations(typ_file, text, strict=strict)
        diagnostics.extend(cite_diags)

        display_path = resolve_display_path(typ_file)
        for key, line in citations:
            if key not in bib_keys:
                diagnostics.append(
                    Diagnostic(
                        path=display_path,
                        line=line,
                        code="E001",
                        message=(
                            f"unknown bibliography key '{key}' "
                            f"(missing from {resolve_display_path(bib_path)})"
                        ),
                    )
                )

    diagnostics.sort(key=lambda d: (d.path, d.line, d.code, d.message))
    return diagnostics


def print_diagnostics(diagnostics: Iterable[Diagnostic]) -> None:
    for diag in diagnostics:
        print(f"{diag.path}:{diag.line}: {diag.code} {diag.message}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate Typst citations against docs/report/references.bib"
    )
    parser.add_argument(
        "--report-root",
        default="docs/report",
        help="Root directory containing report Typst files (default: docs/report)",
    )
    parser.add_argument(
        "--bib",
        default=None,
        help="Path to bibliography file (default: <report-root>/references.bib)",
    )
    parser.add_argument(
        "--no-strict",
        action="store_true",
        help="Disable strict malformed shorthand checks (default: strict enabled)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    report_root = Path(args.report_root)
    bib_path = Path(args.bib) if args.bib else report_root / "references.bib"
    strict = not args.no_strict

    diagnostics = validate(report_root=report_root, bib_path=bib_path, strict=strict)
    if diagnostics:
        print_diagnostics(diagnostics)
        return 1

    print(
        "OK: citation integrity check passed "
        f"({len(iter_typst_files(report_root))} typ files, strict={str(strict).lower()})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
