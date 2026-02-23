#!/usr/bin/env python3
"""Build minimal Plotly resource-utilization charts from Vivado reports.

Outputs:
  - docs/report/figures/generated/fig_resource_system_vs_pipeline.png
  - docs/report/figures/generated/fig_resource_pipeline_instance_split.png
  - docs/report/data/resource_split_system_vs_pipeline.csv
  - docs/report/data/resource_split_pipeline_instances.csv
"""

from __future__ import annotations

import csv
import re
from collections import OrderedDict
from pathlib import Path

import plotly.graph_objects as go

ROOT = Path(__file__).resolve().parents[3]

SYSTEM_PLACED_RPT = ROOT / "vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper_utilization_placed.rpt"
PIPELINE_SUMMARY_RPT = ROOT / "docs/report/data/vivado_ooc/pipeline_ip/pipeline_ip_utilization_synth.rpt"
PIPELINE_HIER_RPT = ROOT / "docs/report/data/vivado_ooc/pipeline_ip/pipeline_ip_hier_utilization_synth.rpt"
PIPELINE_VHDL = ROOT / "rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd"

OUT_DATA_DIR = ROOT / "docs/report/data"
OUT_FIG_DIR = ROOT / "docs/report/figures/generated"

OUT_SYSTEM_SPLIT_CSV = OUT_DATA_DIR / "resource_split_system_vs_pipeline.csv"
OUT_INSTANCE_SPLIT_CSV = OUT_DATA_DIR / "resource_split_pipeline_instances.csv"
OUT_SYSTEM_SPLIT_PNG = OUT_FIG_DIR / "fig_resource_system_vs_pipeline.png"
OUT_INSTANCE_SPLIT_PNG = OUT_FIG_DIR / "fig_resource_pipeline_instance_split.png"


def _to_float(value: str) -> float | None:
    text = value.strip().replace(",", "")
    if text in {"", "-", "_"}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def parse_site_type_rows(report_path: Path) -> dict[str, dict[str, float | None]]:
    """Parse table rows that look like: | Site Type | Used | Fixed | Prohibited | Available | Util% |."""
    if not report_path.exists():
        raise FileNotFoundError(f"Missing report: {report_path}")

    rows: dict[str, dict[str, float | None]] = {}
    for raw in report_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            continue

        parts = [p.strip() for p in line.split("|")[1:-1]]
        if len(parts) < 6:
            continue
        if parts[0] in {"Site Type", "Ref Name", "Instance", "Total"}:
            continue

        used = _to_float(parts[1])
        avail = _to_float(parts[4])
        if used is None:
            continue

        label = parts[0].replace("*", "").strip()
        rows[label] = {"used": used, "available": avail}

    return rows


def parse_pipeline_instance_order(vhdl_path: Path) -> list[str]:
    """Extract instance labels in source order from AXI pipeline VHDL."""
    if not vhdl_path.exists():
        raise FileNotFoundError(f"Missing pipeline source: {vhdl_path}")

    pattern = re.compile(r"^\s*(U_[A-Za-z0-9_]+)\s*:\s*entity\b")
    ordered: list[str] = []
    seen: set[str] = set()
    for line in vhdl_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = pattern.match(line)
        if not m:
            continue
        inst = m.group(1)
        if inst not in seen:
            ordered.append(inst)
            seen.add(inst)
    return ordered


def parse_pipeline_hierarchical_rows(report_path: Path) -> OrderedDict[str, dict[str, float]]:
    """Parse direct child instance rows from hierarchical utilization report."""
    if not report_path.exists():
        raise FileNotFoundError(f"Missing report: {report_path}")

    rows: OrderedDict[str, dict[str, float]] = OrderedDict()
    for raw in report_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.rstrip()
        if not line.lstrip().startswith("|"):
            continue

        parts = [p.strip() for p in line.split("|")[1:-1]]
        if len(parts) < 10:
            continue
        if parts[0] == "Instance":
            continue

        instance = parts[0]
        if not instance.startswith("U_"):
            continue

        total_luts = _to_float(parts[2]) or 0.0
        lutrams = _to_float(parts[4]) or 0.0
        srls = _to_float(parts[5]) or 0.0
        ffs = _to_float(parts[6]) or 0.0
        ramb36 = _to_float(parts[7]) or 0.0
        ramb18 = _to_float(parts[8]) or 0.0
        dsp = _to_float(parts[9]) or 0.0

        rows[instance] = {
            "lut": total_luts,
            # Align with report-level category naming where LUTRAM includes memory LUTs and SRL-based LUT memory.
            "lutram": lutrams + srls,
            "srl": srls,
            "ff": ffs,
            # Vivado reports BRAM as RAMB36 and RAMB18. Convert to BRAM tile equivalent.
            "bram": ramb36 + (ramb18 / 2.0),
            "dsp": dsp,
        }

    return rows


def make_system_vs_pipeline_plot(rows: list[dict[str, float]]) -> go.Figure:
    labels = [r["primitive"] for r in rows]
    other_pct = [r["other_pct"] for r in rows]
    ours_pct = [r["our_pct"] for r in rows]
    total_pct = [r["total_pct"] for r in rows]

    fig = go.Figure()
    fig.add_trace(
        go.Bar(
            name="Other system components",
            y=labels,
            x=other_pct,
            orientation="h",
            marker_color="#d1d5db",
            hovertemplate="%{y}<br>Other: %{x:.2f}%<extra></extra>",
        )
    )
    fig.add_trace(
        go.Bar(
            name="Our implementation (AXI pipeline)",
            y=labels,
            x=ours_pct,
            orientation="h",
            marker_color="#2563eb",
            hovertemplate="%{y}<br>Pipeline: %{x:.2f}%<extra></extra>",
        )
    )
    fig.add_trace(
        go.Scatter(
            y=labels,
            x=total_pct,
            mode="text",
            text=[f"{v:.1f}%" for v in total_pct],
            textposition="middle right",
            textfont={"color": "#111827", "size": 12},
            showlegend=False,
            hoverinfo="skip",
        )
    )

    fig.update_layout(
        barmode="stack",
        template="plotly_white",
        title=None,
        margin={"l": 120, "r": 40, "t": 25, "b": 65},
        plot_bgcolor="white",
        paper_bgcolor="white",
        font={"family": "DejaVu Sans", "size": 15, "color": "#111827"},
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "xanchor": "left", "x": 0.0, "traceorder": "normal"},
        bargap=0.34,
    )
    fig.update_xaxes(
        title="Utilization of available device resources (%)",
        showgrid=True,
        gridcolor="#e5e7eb",
        zeroline=False,
        ticksuffix="%",
        range=[0, max(105.0, max(total_pct) + 6.0)],
    )
    fig.update_yaxes(autorange="reversed", showgrid=False)
    return fig


def _pretty_instance_name(instance: str) -> str:
    return instance.removeprefix("U_")


def make_pipeline_instance_plot(instance_rows: OrderedDict[str, dict[str, float]], ordered_instances: list[str]) -> go.Figure:
    primitive_pairs = [("LUT", "lut"), ("LUTRAM", "lutram"), ("FF", "ff")]
    totals_by_key = {key: sum(instance_rows[inst][key] for inst in ordered_instances) for _, key in primitive_pairs}
    filtered_pairs = [(label, key) for label, key in primitive_pairs if totals_by_key[key] > 0]
    if not filtered_pairs:
        filtered_pairs = primitive_pairs

    primitives = [label for label, _ in filtered_pairs]
    primitive_keys = [key for _, key in filtered_pairs]

    palette = ["#1d4ed8", "#0f766e", "#9333ea", "#ea580c", "#0ea5e9", "#be123c", "#4d7c0f"]

    fig = go.Figure()
    for idx, inst in enumerate(ordered_instances):
        metrics = instance_rows[inst]
        fig.add_trace(
            go.Bar(
                name=_pretty_instance_name(inst),
                y=primitives,
                x=[metrics[key] for key in primitive_keys],
                orientation="h",
                marker_color=palette[idx % len(palette)],
                hovertemplate=(
                    f"Instance: {_pretty_instance_name(inst)}"
                    "<br>Primitive: %{y}<br>Count: %{x:.1f}<extra></extra>"
                ),
            )
        )

    totals = [totals_by_key[key] for key in primitive_keys]
    fig.add_trace(
        go.Scatter(
            y=primitives,
            x=totals,
            mode="text",
            text=[f"{int(v)}" if float(v).is_integer() else f"{v:.1f}" for v in totals],
            textposition="middle right",
            textfont={"color": "#111827", "size": 12},
            showlegend=False,
            hoverinfo="skip",
        )
    )

    fig.update_layout(
        barmode="stack",
        template="plotly_white",
        title=None,
        margin={"l": 120, "r": 40, "t": 25, "b": 65},
        plot_bgcolor="white",
        paper_bgcolor="white",
        font={"family": "DejaVu Sans", "size": 15, "color": "#111827"},
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "xanchor": "left", "x": 0.0, "traceorder": "normal"},
        bargap=0.34,
    )
    fig.update_xaxes(title="Primitive count in AXI pipeline IP (synthesized)", showgrid=True, gridcolor="#e5e7eb", zeroline=False)
    fig.update_yaxes(autorange="reversed", showgrid=False)
    return fig


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, float | str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    OUT_DATA_DIR.mkdir(parents=True, exist_ok=True)
    OUT_FIG_DIR.mkdir(parents=True, exist_ok=True)

    system_rows = parse_site_type_rows(SYSTEM_PLACED_RPT)
    pipeline_rows = parse_site_type_rows(PIPELINE_SUMMARY_RPT)

    primitive_specs = [
        ("LUT", "Slice LUTs", "Slice LUTs"),
        ("LUTRAM", "LUT as Memory", "LUT as Memory"),
        ("FF", "Slice Registers", "Slice Registers"),
        ("BRAM", "Block RAM Tile", "Block RAM Tile"),
        ("IO", "Bonded IOB", "Bonded IOB"),
        ("BUFG", "BUFGCTRL", "BUFGCTRL"),
        ("MMCM", "MMCME2_ADV", "MMCME2_ADV"),
    ]

    system_split_rows: list[dict[str, float]] = []
    for primitive, system_key, pipeline_key in primitive_specs:
        if system_key not in system_rows:
            raise KeyError(f"Missing '{system_key}' in {SYSTEM_PLACED_RPT}")
        if pipeline_key not in pipeline_rows:
            raise KeyError(f"Missing '{pipeline_key}' in {PIPELINE_SUMMARY_RPT}")

        system_used = float(system_rows[system_key]["used"] or 0.0)
        available = float(system_rows[system_key]["available"] or 0.0)
        our_used = float(pipeline_rows[pipeline_key]["used"] or 0.0)

        if available <= 0:
            total_pct = 0.0
            our_pct = 0.0
            other_pct = 0.0
            other_used = 0.0
        else:
            total_pct = (system_used / available) * 100.0
            our_used = min(our_used, system_used)
            other_used = max(system_used - our_used, 0.0)
            our_pct = (our_used / available) * 100.0
            other_pct = (other_used / available) * 100.0

        system_split_rows.append(
            {
                "primitive": primitive,
                "system_used": round(system_used, 3),
                "our_used": round(our_used, 3),
                "other_used": round(other_used, 3),
                "available": round(available, 3),
                "total_pct": round(total_pct, 3),
                "our_pct": round(our_pct, 3),
                "other_pct": round(other_pct, 3),
            }
        )

    hier_rows = parse_pipeline_hierarchical_rows(PIPELINE_HIER_RPT)
    pipeline_instance_order = parse_pipeline_instance_order(PIPELINE_VHDL)
    ordered_instances = [inst for inst in pipeline_instance_order if inst in hier_rows]
    ordered_instances += [inst for inst in hier_rows if inst not in ordered_instances]

    if not ordered_instances:
        raise RuntimeError(f"No pipeline instances parsed from {PIPELINE_HIER_RPT}")

    instance_split_rows: list[dict[str, float | str]] = []
    for inst in ordered_instances:
        metrics = hier_rows[inst]
        instance_split_rows.append(
            {
                "instance": inst,
                "component": _pretty_instance_name(inst),
                "lut": round(metrics["lut"], 3),
                "lutram": round(metrics["lutram"], 3),
                "srl": round(metrics["srl"], 3),
                "ff": round(metrics["ff"], 3),
                "bram": round(metrics["bram"], 3),
                "dsp": round(metrics["dsp"], 3),
            }
        )

    write_csv(
        OUT_SYSTEM_SPLIT_CSV,
        ["primitive", "system_used", "our_used", "other_used", "available", "total_pct", "our_pct", "other_pct"],
        system_split_rows,
    )
    write_csv(
        OUT_INSTANCE_SPLIT_CSV,
        ["instance", "component", "lut", "lutram", "srl", "ff", "bram", "dsp"],
        instance_split_rows,
    )

    fig1 = make_system_vs_pipeline_plot(system_split_rows)
    fig2 = make_pipeline_instance_plot(hier_rows, ordered_instances)

    fig1.write_image(str(OUT_SYSTEM_SPLIT_PNG), width=1400, height=680, scale=2)
    fig2.write_image(str(OUT_INSTANCE_SPLIT_PNG), width=1400, height=760, scale=2)

    print(f"Wrote {OUT_SYSTEM_SPLIT_CSV}")
    print(f"Wrote {OUT_INSTANCE_SPLIT_CSV}")
    print(f"Wrote {OUT_SYSTEM_SPLIT_PNG}")
    print(f"Wrote {OUT_INSTANCE_SPLIT_PNG}")


if __name__ == "__main__":
    main()
