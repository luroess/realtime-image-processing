#!/usr/bin/env python3
"""Run a tb-sim target with an additional GHDL --vcd dump."""

from __future__ import annotations

import argparse
from pathlib import Path
import tomllib

from cocotb_tools.runner import get_runner


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--target", required=True)
    p.add_argument("--testcase", required=True)
    p.add_argument("--vcd-name", required=True)
    return p.parse_args()


def parse_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    return False


def collect_sources(repo_root: Path, entries: list[str]) -> list[Path]:
    out: list[Path] = []
    seen: set[Path] = set()
    for entry in entries:
        token = entry.strip()
        has_glob = any(ch in token for ch in "*?[")
        if has_glob:
            matches = sorted(path for path in repo_root.glob(token) if path.is_file())
        else:
            p = (repo_root / token).resolve()
            if p.is_dir():
                matches = sorted(p.glob("*.vhd"))
            else:
                matches = [p]
        for m in matches:
            r = m.resolve()
            if r not in seen:
                seen.add(r)
                out.append(r)
    return out


def main() -> None:
    args = parse_args()

    tb_root = Path(__file__).resolve().parents[3] / "testbench"
    repo_root = tb_root.parent
    targets_file = tb_root / "targets.toml"
    data = tomllib.loads(targets_file.read_text(encoding="utf-8"))
    defaults = data.get("defaults", {})
    targets = data.get("targets", {})

    if args.target not in targets:
        raise SystemExit(f"Unknown target: {args.target}")

    config = dict(defaults)
    config.update(targets[args.target])

    sim = str(config["sim"])
    toplevel = str(config["toplevel"])
    test_module = str(config["test_module"])
    waves = parse_bool(config.get("waves", True))
    parameters = dict(config.get("parameters", {})) if isinstance(config.get("parameters", {}), dict) else {}

    source_entries = config.get("sources")
    if not isinstance(source_entries, list):
        raise SystemExit(f"Target {args.target} has no explicit 'sources' list")

    sources = collect_sources(repo_root, source_entries)

    sim_root = tb_root / "sim_build" / "report_vcd" / f"{args.target}_{toplevel}"
    build_dir = sim_root / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    runner = get_runner(sim)
    hdl_library = "top"

    runner.build(
        sources=sources,
        hdl_toplevel=toplevel,
        hdl_library=hdl_library,
        parameters=parameters,
        build_dir=build_dir,
        always=True,
    )

    runner.test(
        hdl_toplevel=toplevel,
        hdl_toplevel_library=hdl_library,
        test_module=test_module,
        testcase=args.testcase,
        parameters=parameters,
        build_dir=build_dir,
        test_dir=build_dir,
        waves=waves,
        plusargs=[f"--vcd={args.vcd_name}"],
    )

    print(build_dir / args.vcd_name)


if __name__ == "__main__":
    main()
