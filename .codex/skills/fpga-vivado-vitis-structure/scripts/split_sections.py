#!/usr/bin/env python3
"""Split extracted Vivado documentation into chapter and section files."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from doc_profiles import get_profile


@dataclass
class TocEntry:
    title: str
    page: int | None


@dataclass
class Segment:
    kind: str
    id: str
    title: str
    file: str
    start_line: int
    end_line: int
    start_page: int | None
    end_page: int | None
    parent: str | None = None


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Split markdown docs into chapter and section chunks.",
    )
    parser.add_argument("--doc", help="Document ID (ug934|ug835|ug892|ug896|ug1118). Required for canonical entrypoint.")
    parser.add_argument(
        "--input",
        help="Input markdown from extract_markdown.py.",
    )
    parser.add_argument(
        "--out-dir",
        help="Output directory for sections and indexes.",
    )
    return parser.parse_args(argv)


def slugify(text: str) -> str:
    s = text.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s or "section"


def cleaned_title(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip()).rstrip(".")


def normalize_heading(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def parse_toc(lines: list[str], profile) -> list[TocEntry]:
    toc_re = re.compile(profile.split.toc_entry_pattern)
    in_toc = False
    entries: list[TocEntry] = []
    for raw in lines:
        text = raw.strip()
        if not in_toc:
            if text == profile.split.toc_heading:
                in_toc = True
            continue
        if not text:
            continue
        match = toc_re.match(text)
        if not match:
            if text.startswith("Chapter ") and entries:
                break
            continue
        title = cleaned_title(match.group("title"))
        if len(title) < 3:
            continue
        page = int(match.group("page")) if match.groupdict().get("page") else None
        entries.append(TocEntry(title=title, page=page))

    deduped: list[TocEntry] = []
    seen: set[tuple[str, int | None]] = set()
    for entry in entries:
        key = (entry.title.lower(), entry.page)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(entry)
    return deduped


def parse_headings(lines: list[str], profile) -> list[tuple[str, int]]:
    chapter_re = re.compile(profile.split.chapter_pattern)
    appendix_re = re.compile(profile.split.appendix_pattern) if profile.split.appendix_pattern else None
    out: list[tuple[str, int]] = []
    for idx, raw in enumerate(lines, start=1):
        text = raw.strip()
        if not text:
            continue
        if chapter_re.match(text) or (appendix_re and appendix_re.match(text)):
            out.append((text, idx))
    return out


def is_chapter_heading(profile, title: str) -> bool:
    chapter_re = re.compile(profile.split.chapter_pattern, re.IGNORECASE)
    appendix_re = re.compile(profile.split.appendix_pattern, re.IGNORECASE) if profile.split.appendix_pattern else None
    return bool(chapter_re.match(title) or (appendix_re and appendix_re.match(title)))


def find_toc_index_for_chapter(profile, title: str, toc: list[TocEntry], start_at: int = 0) -> int | None:
    chapter_re = re.compile(profile.split.chapter_pattern, re.IGNORECASE)
    appendix_re = re.compile(profile.split.appendix_pattern, re.IGNORECASE) if profile.split.appendix_pattern else None

    target = cleaned_title(title)
    target_norm = normalize_heading(target)

    def entry_title_norm(entry: TocEntry) -> str:
        return normalize_heading(entry.title)

    for idx in range(start_at, len(toc)):
        if entry_title_norm(toc[idx]) == target_norm:
            return idx

    # Try key-based fallback for "Chapter 3" / "Appendix A" style matches.
    chapter_match = chapter_re.match(target)
    if chapter_match:
        groups = chapter_match.groupdict()
        number = groups.get("num")
        if number:
            marker = f"chapter {number}"
            marker_norm = marker.lower()
            for idx in range(start_at, len(toc)):
                if entry_title_norm(toc[idx]).startswith(marker_norm):
                    return idx

    appendix_match = appendix_re.match(target) if appendix_re else None
    if appendix_match:
        groups = appendix_match.groupdict()
        letter = groups.get("letter")
        if letter:
            marker = f"appendix {letter}"
            marker_norm = marker.lower()
            for idx in range(start_at, len(toc)):
                if entry_title_norm(toc[idx]).startswith(marker_norm):
                    return idx

    # Finally accept high-overlap fuzzy heading reuse.
    if len(target_norm) >= 8:
        for idx in range(start_at, len(toc)):
            current = entry_title_norm(toc[idx])
            if target_norm in current or current in target_norm:
                return idx
    return None


def chapter_slug_and_id(title: str) -> tuple[str, str]:
    chapter_re = re.compile(r"^Chapter\s+(?P<num>\d+):?\s*(?P<title>.*)$", re.IGNORECASE)
    appendix_re = re.compile(r"^Appendix\s+(?P<letter>[A-Z])\s*:?\s*(?P<title>.*)$", re.IGNORECASE)
    if match := chapter_re.match(title):
        return (
            f"ch{int(match.group('num')):02d}-{slugify(match.group('title') or 'chapter')}",
            f"chapter-{int(match.group('num'))}",
        )
    if match := appendix_re.match(title):
        letter = match.group("letter").lower()
        return (f"app-{letter}-{slugify(match.group('title') or 'appendix')}", f"appendix-{letter}")
    safe = slugify(title)
    return (safe, f"chapter-{safe}")


def find_title_line(lines: list[str], title: str, start_idx: int) -> int | None:
    needle = normalize_heading(title)
    for idx in range(start_idx, len(lines)):
        current = normalize_heading(lines[idx])
        if not current:
            continue
        if current == needle:
            return idx + 1
        if len(needle) >= 12 and needle in current:
            return idx + 1
    return None


def build_chapters(lines: list[str], profile, toc: list[TocEntry]) -> list[Segment]:
    heading_matches = parse_headings(lines, profile)
    candidates: list[tuple[str, int]] = heading_matches
    if not heading_matches:
        candidates = [
            (entry.title, find_title_line(lines, entry.title, 0) or 1)
            for entry in toc
            if entry.title.lower().startswith(("chapter ", "appendix "))
        ]

    chapters: list[Segment] = []
    for raw_title, start_line in candidates:
        title = cleaned_title(raw_title)
        slug, cid = chapter_slug_and_id(title)
        start_page = None
        for entry in toc:
            if cleaned_title(entry.title).lower() == title.lower():
                start_page = entry.page
                break
        # Keep widest duplicate match for each id.
        segment = Segment(
            kind="chapter",
            id=cid,
            title=title,
            file=f"sections/{slug}.md",
            start_line=start_line,
            end_line=len(lines),
            start_page=start_page,
            end_page=None,
        )
        existing = next((s for s in chapters if s.id == segment.id), None)
        if existing is None:
            chapters.append(segment)
            continue
        if segment.end_line - segment.start_line > existing.end_line - existing.start_line:
            chapters = [s for s in chapters if s.id != segment.id]
            chapters.append(segment)

    chapters.sort(key=lambda s: s.start_line)
    for idx in range(len(chapters) - 1):
        chapters[idx].end_line = chapters[idx + 1].start_line - 1
    if chapters:
        chapters[-1].end_line = max(chapters[-1].end_line, chapters[-1].start_line)
    return chapters


def build_sections(
    lines: list[str],
    profile,
    toc: list[TocEntry],
    chapters: list[Segment],
) -> list[Segment]:
    if not chapters:
        return []

    toc_chapter_indexes = [idx for idx, entry in enumerate(toc) if is_chapter_heading(profile, entry.title)]
    out: list[Segment] = []
    last_toc_idx = -1

    for ci, chapter in enumerate(chapters):
        chap_start = chapter.start_line - 1
        chap_end = chapter.end_line
        next_chapter = chapters[ci + 1] if ci + 1 < len(chapters) else None
        chapter_limit = (next_chapter.start_line - 1) if next_chapter else chap_end
        chapter_text = lines[chap_start:chapter_limit]

        chapter_toc_idx = find_toc_index_for_chapter(profile, chapter.title, toc, start_at=last_toc_idx + 1)
        if chapter_toc_idx is None and toc_chapter_indexes and ci < len(toc_chapter_indexes):
            fallback = toc_chapter_indexes[ci]
            if fallback > last_toc_idx:
                chapter_toc_idx = fallback

        if chapter_toc_idx is not None:
            last_toc_idx = chapter_toc_idx
            toc_start = chapter_toc_idx + 1
            toc_end = len(toc)
            for next_idx in toc_chapter_indexes:
                if next_idx > chapter_toc_idx:
                    toc_end = next_idx
                    break
        else:
            toc_start = ci
            toc_end = toc_chapter_indexes[ci + 1] if ci + 1 < len(toc_chapter_indexes) else len(toc)

        if toc_start < 0:
            toc_start = 0
        if toc_end < toc_start:
            toc_end = toc_start

        section_candidates = [e for e in toc[toc_start:toc_end] if not e.title.lower().startswith(("chapter ", "appendix "))]
        if not section_candidates:
            continue

        candidate_lines: list[tuple[int, int | None, str]] = []
        scan_from = 0
        for entry in section_candidates:
            found = find_title_line(chapter_text, entry.title, scan_from)
            if found is None:
                continue
            absolute = chap_start + found
            if absolute > chapter_limit:
                continue
            absolute = max(chapter.start_line, absolute)
            candidate_lines.append((absolute, entry.page, entry.title))
            scan_from = found + 1

        candidate_lines.sort(key=lambda item: item[0])
        if not candidate_lines:
            continue

        for si, (start_line, page, title) in enumerate(candidate_lines):
            end_line = chapter_limit
            if si + 1 < len(candidate_lines):
                end_line = candidate_lines[si + 1][0] - 1
            if end_line < start_line:
                end_line = start_line
            end_page = page
            if si + 1 < len(candidate_lines):
                next_page = candidate_lines[si + 1][1]
                if next_page is not None and page is not None:
                    end_page = max(page, next_page - 1)
            sid = f"{chapter.id}-sec-{si + 1:02d}"
            out.append(
                Segment(
                    kind="section",
                    id=sid,
                    title=title,
                    file="",
                    start_line=start_line,
                    end_line=end_line,
                    start_page=page,
                    end_page=end_page,
                    parent=chapter.id,
                )
            )

    # Dedupe and sort for deterministic ordering.
    deduped: list[Segment] = []
    seen: set[tuple[str, int]] = set()
    for seg in sorted(out, key=lambda s: (s.parent or "", s.start_line)):
        key = (seg.parent or "", seg.start_line)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(seg)
    return deduped


def write_text(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def write_yaml_index(index_path: Path, data: dict) -> None:
    lines: list[str] = [f"source: {data['source']}"]
    lines.append("generated_by: split_sections.py")
    lines.append("chapters:")
    for ch in data["chapters"]:
        lines.extend(
            [
                f"  - id: {ch['id']}",
                f"    title: \"{ch['title'].replace('\"', '\\\"')}\"",
                f"    file: {ch['file']}",
                f"    start_line: {ch['start_line']}",
                f"    end_line: {ch['end_line']}",
                f"    start_page: {ch['start_page'] if ch['start_page'] is not None else 'null'}",
                f"    end_page: {ch['end_page'] if ch['end_page'] is not None else 'null'}",
            ]
        )
    lines.append("sections:")
    for sec in data["sections"]:
        lines.extend(
            [
                f"  - id: {sec['id']}",
                f"    parent: {sec['parent']}",
                f"    title: \"{sec['title'].replace('\"', '\\\"')}\"",
                f"    file: {sec['file']}",
                f"    start_line: {sec['start_line']}",
                f"    end_line: {sec['end_line']}",
                f"    start_page: {sec['start_page'] if sec['start_page'] is not None else 'null'}",
                f"    end_page: {sec['end_page'] if sec['end_page'] is not None else 'null'}",
            ]
        )
    index_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_outputs(profile, out_dir: Path, lines: list[str], chapters: list[Segment], sections: list[Segment]) -> None:
    sections_dir = out_dir / "sections"
    sections_dir.mkdir(parents=True, exist_ok=True)
    for old in sections_dir.glob("*.md"):
        old.unlink()

    for chapter in chapters:
        chapter_body = [
            f"# {chapter.title}",
            "",
            f"_Source lines: {chapter.start_line}-{chapter.end_line}_",
            "",
        ]
        chapter_body.extend(lines[chapter.start_line - 1 : chapter.end_line])
        write_text(out_dir / chapter.file, chapter_body)

    for chapter in chapters:
        chapter_sections = [s for s in sections if s.parent == chapter.id]
        for idx, section in enumerate(chapter_sections, start=1):
            slug = slugify(section.title)
            chapter_slug = Path(chapter.file).stem
            section.file = f"sections/{chapter_slug}-sec{idx:02d}-{slug}.md"
            section.id = f"{chapter.id}-sec-{idx:02d}"
            section_body = [
                f"# {section.title}",
                "",
                f"_Parent: {chapter.title}_",
                f"_Source lines: {section.start_line}-{section.end_line}_",
                "",
            ]
            section_body.extend(lines[section.start_line - 1 : section.end_line])
            write_text(out_dir / section.file, section_body)

    for idx, chapter in enumerate(chapters):
        if idx + 1 < len(chapters):
            next_chapter = chapters[idx + 1]
            if chapter.start_page is not None:
                if next_chapter.start_page is not None and next_chapter.start_page > chapter.start_page:
                    chapter.end_page = next_chapter.start_page - 1
                else:
                    chapter.end_page = chapter.start_page
        elif chapter.start_page is not None:
            chapter.end_page = chapter.start_page

    for section in sections:
        if section.start_page is not None and section.end_page is None:
            section.end_page = section.start_page

    index_data = {
        "source": str(Path(profile.split.input_markdown)),
        "generated_by": "split_sections.py",
        "chapters": [
            {
                "id": chapter.id,
                "title": chapter.title,
                "file": chapter.file,
                "start_line": chapter.start_line,
                "end_line": chapter.end_line,
                "start_page": chapter.start_page,
                "end_page": chapter.end_page,
            }
            for chapter in sorted(chapters, key=lambda c: c.start_line)
        ],
        "sections": [
            {
                "id": section.id,
                "parent": section.parent,
                "title": section.title,
                "file": section.file,
                "start_line": section.start_line,
                "end_line": section.end_line,
                "start_page": section.start_page,
                "end_page": section.end_page,
            }
            for section in sorted(sections, key=lambda s: (s.parent or "", s.start_line))
        ],
    }

    write_yaml_index(out_dir / "index.yaml", index_data)
    (out_dir / "index.json").write_text(json.dumps(index_data, indent=2), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        profile = get_profile(args.doc)
    except KeyError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    input_path = Path(args.input or profile.split.input_markdown)
    out_dir = Path(args.out_dir or profile.split.out_dir)
    if not input_path.exists():
        print(f"ERROR: Input markdown missing: {input_path}", file=sys.stderr)
        return 1

    lines = input_path.read_text(encoding="utf-8").splitlines()
    toc = parse_toc(lines, profile)
    chapters = build_chapters(lines, profile, toc)
    if not chapters:
        print("ERROR: no chapters found.", file=sys.stderr)
        return 1

    sections = build_sections(lines, profile, toc, chapters)
    write_outputs(profile, out_dir, lines, chapters, sections)
    print(f"Wrote {out_dir / 'index.json'}")
    print(f"Wrote {out_dir / 'index.yaml'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
