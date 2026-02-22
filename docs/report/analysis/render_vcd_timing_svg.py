#!/usr/bin/env python3
"""Render simple digital timing diagrams from VCD into SVG/PNG-friendly assets."""

from __future__ import annotations

import argparse
import html
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SignalDef:
    code: str
    name: str
    width: int


def parse_vcd(path: Path) -> tuple[dict[str, SignalDef], list[tuple[int, str, str]]]:
    signals: dict[str, SignalDef] = {}
    events: list[tuple[int, str, str]] = []

    time_fs = 0
    in_header = True
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue

            if in_header:
                if line.startswith("$var"):
                    # $var reg 1 ! i_aclk $end
                    parts = line.split()
                    if len(parts) >= 6:
                        width = int(parts[2])
                        code = parts[3]
                        name = parts[4]
                        signals[code] = SignalDef(code=code, name=name, width=width)
                elif line == "$enddefinitions $end":
                    in_header = False
                continue

            if line.startswith("#"):
                time_fs = int(line[1:])
                continue

            if line[0] in {"0", "1", "x", "z"}:
                value = line[0]
                code = line[1:]
                events.append((time_fs, code, value))
            elif line.startswith("b"):
                # vector: b1010 <code>
                parts = line.split()
                if len(parts) == 2:
                    value = parts[0][1:]
                    code = parts[1]
                    events.append((time_fs, code, value))

    return signals, events


def value_to_bit(value: str) -> int:
    if value in {"1", "H", "h"}:
        return 1
    if value in {"0", "L", "l"}:
        return 0
    # vectors: treat any non-zero as high for timing visualization
    if all(ch in "01" for ch in value):
        return 1 if any(ch == "1" for ch in value) else 0
    return 0


def render_svg(
    *,
    signals: dict[str, SignalDef],
    events: list[tuple[int, str, str]],
    selected_signal_names: list[str],
    start_ns: float,
    end_ns: float,
    out_svg: Path,
    title: str,
) -> None:
    ns_to_fs = 1_000_000
    start_fs = int(start_ns * ns_to_fs)
    end_fs = int(end_ns * ns_to_fs)

    # Collect transitions per selected signal.
    name_to_code = {sd.name: sd.code for sd in signals.values()}
    selected_codes = [name_to_code[name] for name in selected_signal_names if name in name_to_code]

    transitions: dict[str, list[tuple[int, int]]] = {code: [(start_fs, 0)] for code in selected_codes}
    current: dict[str, int] = {code: 0 for code in selected_codes}

    # Initialize from pre-window events.
    for t_fs, code, value in events:
        if code not in current:
            continue
        bit = value_to_bit(value)
        if t_fs < start_fs:
            current[code] = bit
            transitions[code][0] = (start_fs, bit)
        else:
            break

    for t_fs, code, value in events:
        if code not in current:
            continue
        if t_fs < start_fs or t_fs > end_fs:
            continue
        bit = value_to_bit(value)
        if bit != current[code]:
            current[code] = bit
            transitions[code].append((t_fs, bit))

    for code in selected_codes:
        if transitions[code][-1][0] < end_fs:
            transitions[code].append((end_fs, transitions[code][-1][1]))

    # Layout constants.
    left = 210
    top = 52
    row_h = 52
    wave_h = 22
    width = 1600
    height = top + row_h * len(selected_codes) + 80

    def x_at(t_fs: int) -> float:
        span = max(1, end_fs - start_fs)
        return left + (t_fs - start_fs) * (width - left - 80) / span

    def y_at(row: int, bit: int) -> float:
        y_base = top + row * row_h
        return y_base + (6 if bit else (6 + wave_h))

    parts: list[str] = []
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">')
    parts.append('<rect x="0" y="0" width="100%" height="100%" fill="white"/>')
    parts.append(f'<text x="24" y="30" font-family="Libertinus Serif" font-size="20" font-weight="bold">{html.escape(title)}</text>')

    # Vertical grid every 20 ns.
    step_ns = 20
    tick = int(start_ns // step_ns) * step_ns
    if tick < start_ns:
        tick += step_ns
    while tick <= end_ns:
        x = x_at(int(tick * ns_to_fs))
        parts.append(f'<line x1="{x:.2f}" y1="{top-10}" x2="{x:.2f}" y2="{height-30}" stroke="#d8d8d8" stroke-width="1"/>')
        parts.append(f'<text x="{x-12:.2f}" y="{height-10}" font-family="monospace" font-size="12">{tick}ns</text>')
        tick += step_ns

    # Draw each signal row.
    for row, code in enumerate(selected_codes):
        name = signals[code].name
        parts.append(f'<text x="20" y="{top + row*row_h + 18}" font-family="monospace" font-size="14">{html.escape(name)}</text>')
        parts.append(
            f'<line x1="{left}" y1="{top + row*row_h + 17}" x2="{width-40}" y2="{top + row*row_h + 17}" stroke="#f1f1f1" stroke-width="1"/>'
        )

        pts = transitions[code]
        d = []
        for i, (t_fs, bit) in enumerate(pts):
            x = x_at(t_fs)
            y = y_at(row, bit)
            if i == 0:
                d.append(f"M {x:.2f} {y:.2f}")
            else:
                prev_t, prev_bit = pts[i - 1]
                x_prev = x_at(prev_t)
                y_prev = y_at(row, prev_bit)
                d.append(f"L {x:.2f} {y_prev:.2f}")
                d.append(f"L {x:.2f} {y:.2f}")

        parts.append(f'<path d="{" ".join(d)}" fill="none" stroke="#004b8d" stroke-width="2"/>')

    parts.append("</svg>")
    out_svg.parent.mkdir(parents=True, exist_ok=True)
    out_svg.write_text("\n".join(parts), encoding="utf-8")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--vcd", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--start-ns", type=float, required=True)
    p.add_argument("--end-ns", type=float, required=True)
    p.add_argument("--signal", action="append", required=True)
    args = p.parse_args()

    signals, events = parse_vcd(args.vcd)
    render_svg(
        signals=signals,
        events=events,
        selected_signal_names=args.signal,
        start_ns=args.start_ns,
        end_ns=args.end_ns,
        out_svg=args.out,
        title=args.title,
    )


if __name__ == "__main__":
    main()
