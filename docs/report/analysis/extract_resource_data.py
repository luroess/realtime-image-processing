#!/usr/bin/env python3
"""Extract key utilization counters from Vivado .rpt files into CSV/JSON.

This script keeps only LUT/FF/BRAM/DSP metrics needed by docs/report/TODOS.md.
"""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

REPORTS = {
    "rgb_to_grayscale_axi_ooc": ROOT / "docs/report/data/vivado_ooc/rgb_to_grayscale/rgb_to_grayscale_ooc_utilization_synth.rpt",
    "frame_compositor_core_ooc": ROOT / "docs/report/data/vivado_ooc/frame_compositor_core/frame_compositor_core_ooc_utilization_synth.rpt",
    "pl_pipeline_ip_ooc": ROOT / "vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/system_AXI_RgbGrayBlurrSobe_0_0_synth_1/system_AXI_RgbGrayBlurrSobe_0_0_utilization_synth.rpt",
    "system_wrapper_placed": ROOT / "vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper_utilization_placed.rpt",
}

OUT_DIR = ROOT / "docs/report/data"
CSV_OUT = OUT_DIR / "resource_utilization.csv"
JSON_OUT = OUT_DIR / "resource_utilization.json"
SHARE_CSV_OUT = OUT_DIR / "resource_relative_share_vs_system.csv"

KEYS = {
    "Slice LUTs": "lut",
    "Slice Registers": "ff",
    "Block RAM Tile": "bram",
    "DSPs": "dsp",
}

ROW_RE = re.compile(r"^\|\s*(?P<label>[^|]+?)\s*\|\s*(?P<used>[-0-9.]+)\s*\|")


def parse_used_metrics(report_path: Path) -> dict[str, float]:
    if not report_path.exists():
        raise FileNotFoundError(f"Missing report: {report_path}")

    metrics: dict[str, float] = {"lut": 0.0, "ff": 0.0, "bram": 0.0, "dsp": 0.0}
    found_labels: set[str] = set()

    for raw_line in report_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = ROW_RE.match(raw_line.strip())
        if not m:
            continue
        label = m.group("label").replace("*", "").strip()
        used = float(m.group("used"))
        if label in KEYS and label not in found_labels:
            metrics[KEYS[label]] = used
            found_labels.add(label)

    missing = [label for label in KEYS if label not in found_labels]
    if missing:
        raise ValueError(f"Could not find required labels in {report_path}: {missing}")

    return metrics


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, object]] = []
    for module, report_path in REPORTS.items():
        metrics = parse_used_metrics(report_path)
        rows.append(
            {
                "module": module,
                "report_path": str(report_path.relative_to(ROOT)),
                **metrics,
            }
        )

    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["module", "report_path", "lut", "ff", "bram", "dsp"])
        writer.writeheader()
        writer.writerows(rows)

    JSON_OUT.write_text(json.dumps(rows, indent=2), encoding="utf-8")

    system_row = next(r for r in rows if r["module"] == "system_wrapper_placed")

    share_rows: list[dict[str, object]] = []
    for row in rows:
        if row["module"] == "system_wrapper_placed":
            continue
        share_rows.append(
            {
                "module": row["module"],
                "vs_system_lut_pct": round((float(row["lut"]) / float(system_row["lut"])) * 100.0, 3),
                "vs_system_ff_pct": round((float(row["ff"]) / float(system_row["ff"])) * 100.0, 3),
                "vs_system_bram_pct": round((float(row["bram"]) / float(system_row["bram"])) * 100.0, 3)
                if float(system_row["bram"]) > 0
                else 0.0,
                "vs_system_dsp_pct": round((float(row["dsp"]) / float(system_row["dsp"])) * 100.0, 3)
                if float(system_row["dsp"]) > 0
                else 0.0,
            }
        )

    with SHARE_CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["module", "vs_system_lut_pct", "vs_system_ff_pct", "vs_system_bram_pct", "vs_system_dsp_pct"],
        )
        writer.writeheader()
        writer.writerows(share_rows)

    print(f"Wrote {CSV_OUT}")
    print(f"Wrote {JSON_OUT}")
    print(f"Wrote {SHARE_CSV_OUT}")


if __name__ == "__main__":
    main()
