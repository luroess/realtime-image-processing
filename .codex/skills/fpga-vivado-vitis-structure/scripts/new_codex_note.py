#!/usr/bin/env python3
"""Create ordered `.codex` note files using the enforced naming policy."""

from __future__ import annotations

import argparse
import re
import sys
from datetime import date, datetime
from pathlib import Path

CODEX_DIR = Path(".codex")
DATE_INPUT_FORMATS = ("%Y%m%d", "%Y-%m-%d")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create an ordered .codex note file.")
    parser.add_argument("--category", required=True, help="Category component for filename.")
    parser.add_argument("--type", required=True, help="Type component for filename.")
    parser.add_argument("--label", required=True, help="Unique label component for filename.")
    parser.add_argument("--date", help="Optional date in YYYYMMDD or YYYY-MM-DD.")
    return parser.parse_args(argv)


def sanitize_component(value: str) -> str:
    cleaned = re.sub(r"\s+", "_", value.strip())
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", cleaned)
    cleaned = re.sub(r"_+", "_", cleaned).strip("_")
    if not cleaned:
        raise ValueError("Filename component became empty after sanitization")
    return cleaned


def parse_date(value: str | None) -> str:
    if value is None:
        return date.today().strftime("%Y%m%d")

    text = value.strip()
    for fmt in DATE_INPUT_FORMATS:
        try:
            return datetime.strptime(text, fmt).strftime("%Y%m%d")
        except ValueError:
            pass
    raise ValueError("--date must be YYYYMMDD or YYYY-MM-DD")


def build_template(*, date_token: str, category: str, note_type: str, label: str) -> str:
    return "\n".join(
        [
            f"# {category} {note_type}: {label}",
            "",
            f"Date: {date_token}",
            f"Category: {category}",
            f"Type: {note_type}",
            f"Label: {label}",
            "",
            "## Context",
            "",
            "## Objective",
            "",
            "## Notes",
            "",
            "## Actions",
            "",
        ]
    )


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        date_token = parse_date(args.date)
        category = sanitize_component(args.category)
        note_type = sanitize_component(args.type)
        label = sanitize_component(args.label)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    CODEX_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{date_token}_{category}_{note_type}_{label}.md"
    path = CODEX_DIR / filename

    if path.exists():
        print(f"Refusing to overwrite existing note: {path}", file=sys.stderr)
        return 1

    path.write_text(
        build_template(
            date_token=date_token,
            category=category,
            note_type=note_type,
            label=label,
        ),
        encoding="utf-8",
    )
    print(path.as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
