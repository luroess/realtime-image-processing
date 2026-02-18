#!/usr/bin/env python3
"""Extract AMD Vivado PDF references into page-anchored markdown corpora."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import importlib.util
import subprocess
import sys
from pathlib import Path

from doc_profiles import get_profile


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract a PDF into markdown with explicit page anchors.",
    )
    parser.add_argument(
        "--doc",
        help="Document ID (ug934, ug835, ug892, ug896, ug1118). Required when using canonical entrypoint.",
    )
    parser.add_argument(
        "--pdf",
        help="Input PDF path.",
    )
    parser.add_argument(
        "--out-dir",
        help="Output directory for generated markdown and map files.",
    )
    parser.add_argument(
        "--method",
        choices=("auto", "pdftotext", "markitdown"),
        help="Extraction backend.",
    )
    return parser.parse_args(argv)


def markitdown_available() -> bool:
    try:
        return importlib.util.find_spec("markitdown") is not None
    except Exception:
        return False


def require_command(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise RuntimeError(f"Required command not found: {name}")
    return path


def run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return proc.stdout


def parse_pdfinfo_pages(pdf_path: Path) -> int:
    require_command("pdfinfo")
    out = run(["pdfinfo", str(pdf_path)])
    for line in out.splitlines():
        if line.startswith("Pages:"):
            return int(line.split(":", 1)[1].strip())
    raise RuntimeError("Could not parse page count from pdfinfo output")


def normalize_text(text: str) -> str:
    lines = [ln.rstrip() for ln in text.replace("\x0c", "\n").splitlines()]
    cleaned: list[str] = []
    blank = 0
    for line in lines:
        if not line.strip():
            blank += 1
            if blank <= 2:
                cleaned.append("")
            continue
        blank = 0
        cleaned.append(re.sub(r"[ \t]+", " ", line).strip())
    while cleaned and cleaned[0] == "":
        cleaned.pop(0)
    while cleaned and cleaned[-1] == "":
        cleaned.pop()
    return "\n".join(cleaned)


def extract_with_pdftotext(profile, pdf_path: Path) -> tuple[str, list[dict[str, int]]]:
    require_command("pdftotext")
    total_pages = parse_pdfinfo_pages(pdf_path)
    out_lines: list[str] = [
        f"# {profile.extract.title}",
        "",
        f"_Source PDF: `{pdf_path}`_",
        "",
        "Generated with `pdftotext` and explicit page anchors.",
        "",
    ]
    page_map: list[dict[str, int]] = []
    current_line = len(out_lines)

    for page in range(1, total_pages + 1):
        page_text_raw = run(
            [
                "pdftotext",
                "-f",
                str(page),
                "-l",
                str(page),
                "-layout",
                "-nopgbrk",
                str(pdf_path),
                "-",
            ]
        )
        page_text = normalize_text(page_text_raw)
        out_lines.append(f"## Page {page:03d}")
        out_lines.append(f"<!-- page:{page} -->")
        if page_text:
            out_lines.extend(page_text.splitlines())
        else:
            out_lines.append("_No extractable text on this page._")
        out_lines.append("")

        end_line = len(out_lines)
        page_map.append(
            {
                "page": page,
                "start_line": current_line + 1,
                "end_line": end_line,
                "chars": len(page_text),
            }
        )
        current_line = end_line

    return ("\n".join(out_lines).rstrip() + "\n", page_map)


def extract_with_markitdown(profile, pdf_path: Path) -> tuple[str, list[dict[str, int]]]:
    try:
        import importlib

        markitdown = importlib.import_module("markitdown")
    except Exception as exc:
        raise RuntimeError(f"markitdown Python module unavailable: {exc}") from exc

    converter_cls = getattr(markitdown, "MarkItDown", None)
    if converter_cls is None:
        raise RuntimeError("markitdown.MarkItDown not found")

    converter = converter_cls()
    result = converter.convert(str(pdf_path))
    text = getattr(result, "text_content", None)
    if not isinstance(text, str) or not text.strip():
        raise RuntimeError("markitdown conversion returned empty content")

    # Use pdftotext page map for determinism.
    _, page_map = extract_with_pdftotext(profile, pdf_path)
    header = [
        f"# {profile.extract.title}",
        "",
        f"_Source PDF: `{pdf_path}`_",
        "",
        "Generated with `markitdown` (content) + `pdftotext` (page map).",
        "",
    ]
    body = normalize_text(text)
    full = "\n".join(header + body.splitlines()) + "\n"
    return full, page_map


def write_outputs(
    profile,
    out_dir: Path,
    markdown: str,
    page_map: list[dict[str, int]],
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    markdown_path = out_dir / profile.extract.markdown_name
    page_map_path = out_dir / profile.extract.page_map_name
    markdown_path.write_text(markdown, encoding="utf-8")
    page_map_path.write_text(json.dumps(page_map, indent=2), encoding="utf-8")


def resolve_output_args(args: argparse.Namespace) -> tuple[object, Path, Path, str]:
    profile = get_profile(args.doc)
    pdf_path = Path(args.pdf or profile.extract.pdf_path)
    out_dir = Path(args.out_dir or profile.extract.out_dir)
    method = args.method or profile.extract.default_method
    return profile, pdf_path, out_dir, method


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        profile, pdf_path, out_dir, method = resolve_output_args(args)
    except KeyError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    if not pdf_path.exists():
        print(f"ERROR: PDF not found: {pdf_path}", file=sys.stderr)
        return 1

    selected = method
    if method == "auto":
        selected = "markitdown" if markitdown_available() else "pdftotext"

    try:
        if selected == "markitdown":
            markdown, page_map = extract_with_markitdown(profile, pdf_path)
        else:
            markdown, page_map = extract_with_pdftotext(profile, pdf_path)
    except Exception as exc:
        if method == "auto" and selected == "markitdown":
            markdown, page_map = extract_with_pdftotext(profile, pdf_path)
        else:
            print(f"ERROR: extraction failed: {exc}", file=sys.stderr)
            return 1

    write_outputs(profile, out_dir, markdown, page_map)
    print(f"Wrote {out_dir / profile.extract.markdown_name}")
    print(f"Wrote {out_dir / profile.extract.page_map_name} ({len(page_map)} pages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
