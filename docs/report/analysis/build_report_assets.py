#!/usr/bin/env python3
"""Build report data tables and Plotly figures for the Typst report."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
import tomllib
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable

import pandas as pd
import plotly.express as px


AUTHOR_MAP = {
    "Lukas": "Lukas Roess",
    "Lukas Roess": "Lukas Roess",
    "Jan Duchscherer": "Jan Duchscherer",
    "JanDuchscherer104": "Jan Duchscherer",
    "ValentinBumeder": "Valentin Bumeder",
    "Valentin Bumeder": "Valentin Bumeder",
    "JustinLoeber": "Justin Loeber",
    "Justin Loeber": "Justin Loeber",
}

TEAM_ORDER = [
    "Lukas Roess",
    "Jan Duchscherer",
    "Valentin Bumeder",
    "Justin Loeber",
]

WORKSTREAM_ORDER = [
    "Verification framework",
    "RGB2Gray",
    "Window Generator",
    "Sobel + Filter Wrapper",
    "Edge Overlay",
    "Debounce/Click/Button path",
    "Documentation/Integration",
]


@dataclass(frozen=True)
class CommitRecord:
    commit: str
    commit_date: date
    member: str
    files: tuple[str, ...]


def canonical_author(name: str) -> str:
    return AUTHOR_MAP.get(name.strip(), name.strip())


def map_workstream(path: str) -> str:
    p = path.replace("\\", "/")
    if p.startswith("rtl/RGB_TO_GRAYSCALE/"):
        return "RGB2Gray"
    if p.startswith("rtl/WINDOW_GENERATOR/"):
        return "Window Generator"
    if p.startswith("rtl/SOBEL_FILTER/") or p.startswith("rtl/FILTER_WRAPPER/"):
        return "Sobel + Filter Wrapper"
    if p.startswith("rtl/EDGE_OVERLAY/"):
        return "Edge Overlay"
    if (
        p.startswith("rtl/DEBOUNCER/")
        or p.startswith("rtl/CLICK_DETECTOR/")
        or p.startswith("rtl/BUTTON_EXAMPLE/")
    ):
        return "Debounce/Click/Button path"
    if p.startswith("testbench/"):
        return "Verification framework"
    if (
        p.startswith("docs/")
        or p.startswith("vivado/")
        or p.startswith("vivado_outputs/")
        or p.startswith("amd-docs/")
        or p in {"README.md", "SETUP.md", "LICENSE"}
    ):
        return "Documentation/Integration"
    return "Documentation/Integration"


def map_target_to_module_area(target_key: str) -> str:
    key = target_key.lower()
    if "rgb_to_grayscale" in key:
        return "RGB2Gray"
    if "window_generator" in key:
        return "Window Generator"
    if "sobel" in key or "filter_wrapper" in key or "windowed_filter_wrapper" in key:
        return "Sobel + Filter Wrapper"
    if "edge_overlay" in key:
        return "Edge Overlay"
    if "click" in key or "debouncer" in key or "button" in key:
        return "Debounce/Click/Button path"
    if "passthrough" in key or "example" in key:
        return "Example Passthrough"
    return "Verification framework"


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=repo_root)
    parser.add_argument("--sim-build", type=Path, default=Path("testbench/sim_build"))
    parser.add_argument("--targets-file", type=Path, default=Path("testbench/targets.toml"))
    parser.add_argument("--out-data-dir", type=Path, default=Path("docs/report/data"))
    parser.add_argument(
        "--out-figures-dir", type=Path, default=Path("docs/report/figures/generated")
    )
    return parser.parse_args()


def run_git(repo_root: Path, args: list[str]) -> str:
    cmd = ["git", "-C", str(repo_root), *args]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return result.stdout


def load_targets(targets_file: Path) -> dict[str, dict[str, str]]:
    with targets_file.open("rb") as f:
        data = tomllib.load(f)
    targets = data.get("targets", {})
    out: dict[str, dict[str, str]] = {}
    for key, value in targets.items():
        out[key] = {
            "toplevel": str(value.get("toplevel", "")).strip(),
            "test_module": str(value.get("test_module", "")).strip(),
        }
    return out


def parse_git_commits(repo_root: Path) -> list[CommitRecord]:
    # Record separator: 0x1e, field separator: 0x1f.
    fmt = "%x1e%H%x1f%ad%x1f%an"
    raw = run_git(
        repo_root,
        [
            "log",
            "--date=short",
            f"--pretty=format:{fmt}",
            "--name-only",
        ],
    )
    commits: list[CommitRecord] = []
    for block in raw.split("\x1e"):
        block = block.strip()
        if not block:
            continue
        lines = block.splitlines()
        header = lines[0]
        parts = header.split("\x1f")
        if len(parts) != 3:
            continue
        commit_hash, day, author = parts
        file_list = tuple(line.strip() for line in lines[1:] if line.strip())
        if not file_list:
            continue
        commits.append(
            CommitRecord(
                commit=commit_hash.strip(),
                commit_date=datetime.strptime(day.strip(), "%Y-%m-%d").date(),
                member=canonical_author(author),
                files=file_list,
            )
        )
    return commits


def infer_target_key(
    bundle: str, test_module_dir: str, targets: dict[str, dict[str, str]]
) -> tuple[str, str, str]:
    for key, cfg in targets.items():
        toplevel = cfg.get("toplevel", "")
        expected_bundle = f"{key}_{toplevel}" if toplevel else key
        if expected_bundle == bundle:
            return key, toplevel, cfg.get("test_module", "")

    if test_module_dir.startswith("test_"):
        fallback = test_module_dir[len("test_") :]
    else:
        fallback = test_module_dir

    if "_" in bundle:
        guessed_top = bundle.rsplit("_", 1)[-1]
    else:
        guessed_top = ""
    return fallback, guessed_top, f"tests.{test_module_dir}"


def parse_junit_metrics(
    sim_build_dir: Path, targets: dict[str, dict[str, str]]
) -> list[dict[str, str | float]]:
    rows: list[dict[str, str | float]] = []
    for xml_path in sorted(sim_build_dir.rglob("results.xml")):
        rel = xml_path.relative_to(sim_build_dir).as_posix()
        parts = rel.split("/")
        if len(parts) < 4:
            continue
        test_module_dir = parts[0]
        bundle = parts[1]
        target_key, toplevel, test_module = infer_target_key(bundle, test_module_dir, targets)
        module_area = map_target_to_module_area(target_key)

        tree = ET.parse(xml_path)
        root = tree.getroot()
        for tc in root.iter("testcase"):
            has_failure = any(child.tag in {"failure", "error"} for child in tc)
            rows.append(
                {
                    "results_xml": xml_path.as_posix(),
                    "target_key": target_key,
                    "toplevel": toplevel,
                    "test_module": test_module or tc.attrib.get("classname", ""),
                    "module_area": module_area,
                    "testcase": tc.attrib.get("name", ""),
                    "classname": tc.attrib.get("classname", ""),
                    "file": tc.attrib.get("file", ""),
                    "lineno": tc.attrib.get("lineno", ""),
                    "time_s": float(tc.attrib.get("time", "0") or 0.0),
                    "sim_time_ns": float(tc.attrib.get("sim_time_ns", "0") or 0.0),
                    "ratio_time": float(tc.attrib.get("ratio_time", "0") or 0.0),
                    "status": "fail" if has_failure else "pass",
                }
            )
    return rows


def write_csv(path: Path, fieldnames: list[str], rows: Iterable[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def ensure_override_csv(path: Path) -> None:
    if path.exists():
        return
    write_csv(
        path,
        ["member", "workstream", "start_date", "end_date", "notes"],
        [],
    )


def parse_override_csv(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            member = canonical_author((row.get("member") or "").strip())
            workstream = (row.get("workstream") or "").strip()
            start_date = (row.get("start_date") or "").strip()
            end_date = (row.get("end_date") or "").strip()
            notes = (row.get("notes") or "").strip()
            if not (member and workstream and start_date and end_date):
                continue
            rows.append(
                {
                    "source": "override",
                    "member": member,
                    "workstream": workstream,
                    "start_date": start_date,
                    "end_date": end_date,
                    "commit_count": "",
                    "files_changed": "",
                    "notes": notes,
                }
            )
    return rows


def create_figures(
    junit_df: pd.DataFrame,
    team_combined_df: pd.DataFrame,
    commit_density_df: pd.DataFrame,
    out_figures_dir: Path,
) -> None:
    out_figures_dir.mkdir(parents=True, exist_ok=True)

    def export(fig, basename: str) -> None:
        svg_path = out_figures_dir / f"{basename}.svg"
        png_path = out_figures_dir / f"{basename}.png"
        fig.write_image(svg_path)
        fig.write_image(png_path, scale=2)

    runtime_by_target = (
        junit_df.groupby("target_key", as_index=False)["time_s"].sum().sort_values("time_s")
    )
    fig1 = px.bar(
        runtime_by_target,
        x="target_key",
        y="time_s",
        title="Runtime Per Simulation Target",
        labels={"target_key": "Target", "time_s": "Wall Time [s]"},
        color="time_s",
        color_continuous_scale="Blues",
    )
    fig1.update_layout(template="plotly_white", width=1150, height=620, coloraxis_showscale=False)
    fig1.update_xaxes(tickangle=-20)
    export(fig1, "fig_test_runtime_by_target")

    fig2 = px.scatter(
        junit_df,
        x="sim_time_ns",
        y="time_s",
        color="module_area",
        hover_data=["target_key", "testcase", "status"],
        title="Wall Time vs Simulated Time",
        labels={"sim_time_ns": "Simulated Time [ns]", "time_s": "Wall Time [s]"},
    )
    fig2.update_layout(template="plotly_white", width=1150, height=620)
    export(fig2, "fig_testcase_wall_vs_sim")

    count_by_module = (
        junit_df.groupby("module_area", as_index=False)["testcase"].count().rename(
            columns={"testcase": "testcase_count"}
        )
    )
    fig3 = px.bar(
        count_by_module,
        x="module_area",
        y="testcase_count",
        title="Testcase Count by Module Area",
        labels={"module_area": "Module Area", "testcase_count": "Number of Testcases"},
        color="module_area",
    )
    fig3.update_layout(template="plotly_white", width=1150, height=620, showlegend=False)
    fig3.update_xaxes(tickangle=-18)
    export(fig3, "fig_testcase_count_by_module")

    gantt_df = team_combined_df.copy()
    gantt_df["start_dt"] = pd.to_datetime(gantt_df["start_date"])
    gantt_df["end_dt"] = pd.to_datetime(gantt_df["end_date"])
    gantt_df["finish_dt"] = gantt_df["end_dt"] + pd.to_timedelta(1, unit="D")
    fig4 = px.timeline(
        gantt_df,
        x_start="start_dt",
        x_end="finish_dt",
        y="member",
        color="workstream",
        hover_data=["source", "commit_count", "files_changed", "notes"],
        title="Team Contribution Timeline by Workstream",
    )
    fig4.update_layout(template="plotly_white", width=1250, height=720)
    fig4.update_yaxes(categoryorder="array", categoryarray=list(reversed(TEAM_ORDER)))
    export(fig4, "fig_team_contribution_gantt")

    fig5 = px.bar(
        commit_density_df,
        x="commit_date",
        y="commit_count",
        color="member",
        barmode="stack",
        title="Daily Commit Density by Team Member",
        labels={"commit_date": "Date", "commit_count": "Commits"},
    )
    fig5.update_layout(template="plotly_white", width=1250, height=620)
    export(fig5, "fig_team_commit_density")


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    sim_build_dir = (repo_root / args.sim_build).resolve()
    targets_file = (repo_root / args.targets_file).resolve()
    out_data_dir = (repo_root / args.out_data_dir).resolve()
    out_figures_dir = (repo_root / args.out_figures_dir).resolve()

    out_data_dir.mkdir(parents=True, exist_ok=True)
    out_figures_dir.mkdir(parents=True, exist_ok=True)

    targets = load_targets(targets_file)
    commits = parse_git_commits(repo_root)
    junit_rows = parse_junit_metrics(sim_build_dir, targets)
    junit_rows.sort(key=lambda r: (str(r["target_key"]), str(r["testcase"])))

    write_csv(
        out_data_dir / "junit_metrics.csv",
        [
            "results_xml",
            "target_key",
            "toplevel",
            "test_module",
            "module_area",
            "testcase",
            "classname",
            "file",
            "lineno",
            "time_s",
            "sim_time_ns",
            "ratio_time",
            "status",
        ],
        junit_rows,
    )

    timeline_agg: dict[tuple[str, str], dict[str, object]] = {}
    commit_density_counter: Counter[tuple[str, date]] = Counter()

    for c in commits:
        commit_density_counter[(c.member, c.commit_date)] += 1
        workstream_file_counts: Counter[str] = Counter(map(map_workstream, c.files))
        for stream, file_count in workstream_file_counts.items():
            key = (c.member, stream)
            row = timeline_agg.setdefault(
                key,
                {
                    "source": "git",
                    "member": c.member,
                    "workstream": stream,
                    "start_date": c.commit_date,
                    "end_date": c.commit_date,
                    "commit_count": 0,
                    "files_changed": 0,
                    "notes": "",
                },
            )
            row["start_date"] = min(row["start_date"], c.commit_date)
            row["end_date"] = max(row["end_date"], c.commit_date)
            row["commit_count"] = int(row["commit_count"]) + 1
            row["files_changed"] = int(row["files_changed"]) + int(file_count)

    team_git_rows: list[dict[str, object]] = []
    for (_, _), row in sorted(
        timeline_agg.items(),
        key=lambda item: (
            TEAM_ORDER.index(item[0][0]) if item[0][0] in TEAM_ORDER else 99,
            WORKSTREAM_ORDER.index(item[0][1]) if item[0][1] in WORKSTREAM_ORDER else 99,
            item[0][0],
            item[0][1],
        ),
    ):
        team_git_rows.append(
            {
                "source": "git",
                "member": row["member"],
                "workstream": row["workstream"],
                "start_date": row["start_date"].isoformat(),
                "end_date": row["end_date"].isoformat(),
                "commit_count": row["commit_count"],
                "files_changed": row["files_changed"],
                "notes": "",
            }
        )

    write_csv(
        out_data_dir / "team_contrib_git.csv",
        [
            "source",
            "member",
            "workstream",
            "start_date",
            "end_date",
            "commit_count",
            "files_changed",
            "notes",
        ],
        team_git_rows,
    )

    override_csv = out_data_dir / "team_contrib_overrides.csv"
    ensure_override_csv(override_csv)
    override_rows = parse_override_csv(override_csv)

    combined_rows = sorted(
        [*team_git_rows, *override_rows],
        key=lambda row: (
            TEAM_ORDER.index(str(row["member"])) if str(row["member"]) in TEAM_ORDER else 99,
            str(row["start_date"]),
            str(row["workstream"]),
            str(row["source"]),
        ),
    )

    write_csv(
        out_data_dir / "team_contrib_combined.csv",
        [
            "source",
            "member",
            "workstream",
            "start_date",
            "end_date",
            "commit_count",
            "files_changed",
            "notes",
        ],
        combined_rows,
    )

    commit_density_rows = [
        {
            "member": member,
            "commit_date": day.isoformat(),
            "commit_count": count,
        }
        for (member, day), count in sorted(
            commit_density_counter.items(),
            key=lambda item: (
                item[0][1],
                TEAM_ORDER.index(item[0][0]) if item[0][0] in TEAM_ORDER else 99,
                item[0][0],
            ),
        )
    ]

    junit_df = pd.DataFrame(junit_rows)
    if junit_df.empty:
        raise RuntimeError("No junit metrics were found under testbench/sim_build.")
    junit_df["time_s"] = pd.to_numeric(junit_df["time_s"], errors="coerce").fillna(0.0)
    junit_df["sim_time_ns"] = pd.to_numeric(junit_df["sim_time_ns"], errors="coerce").fillna(0.0)

    team_combined_df = pd.DataFrame(combined_rows)
    if team_combined_df.empty:
        raise RuntimeError("No team contribution rows were generated.")

    commit_density_df = pd.DataFrame(commit_density_rows)
    if commit_density_df.empty:
        raise RuntimeError("No commit density data was generated.")

    try:
        create_figures(junit_df, team_combined_df, commit_density_df, out_figures_dir)
    except Exception as exc:
        msg = str(exc)
        if "kaleido" in msg.lower():
            raise RuntimeError(
                "Plot export failed because Kaleido is not available. "
                "Install it via `python -m pip install kaleido` and rerun."
            ) from exc
        raise

    print(f"[ok] wrote: {(out_data_dir / 'junit_metrics.csv').as_posix()}")
    print(f"[ok] wrote: {(out_data_dir / 'team_contrib_git.csv').as_posix()}")
    print(f"[ok] wrote: {(out_data_dir / 'team_contrib_overrides.csv').as_posix()}")
    print(f"[ok] wrote: {(out_data_dir / 'team_contrib_combined.csv').as_posix()}")
    print(f"[ok] figure dir: {out_figures_dir.as_posix()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        raise SystemExit(130)
