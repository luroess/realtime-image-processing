"""Python runner entry point for cocotb simulations."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import tomllib
from cocotb_tools.runner import get_runner


def _parse_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    return False


def _sanitize_name(value: str) -> str:
    sanitized = "".join(ch if ch.isalnum() or ch in {"_", "-"} else "_" for ch in value)
    return sanitized.strip("_") or "tb"


def _derive_tb_name(test_module: str) -> str:
    first_module = test_module.split(",", maxsplit=1)[0].strip()
    leaf = first_module.split(".")[-1] if first_module else "tb"
    return _sanitize_name(leaf)


def _load_targets(tb_root: Path) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    targets_file = tb_root / "targets.toml"
    if not targets_file.exists():
        raise FileNotFoundError(f"Missing target registry file: {targets_file}")

    with targets_file.open("rb") as f:
        data = tomllib.load(f)

    defaults = data.get("defaults", {})
    targets = data.get("targets", {})
    if not isinstance(targets, dict) or not targets:
        raise ValueError("No targets defined in targets.toml")

    return defaults, targets


def _collect_component_sources(repo_root: Path, component: str) -> list[Path]:
    component_hdl = repo_root / "rtl" / component / "hdl"
    if not component_hdl.exists():
        raise FileNotFoundError(
            f"Missing RTL component directory: {component_hdl}. "
            "Expected structure: rtl/<COMPONENT>/hdl/*.vhd",
        )

    sources = sorted(component_hdl.glob("*.vhd"))
    if not sources:
        raise FileNotFoundError(f"No VHDL sources found in {component_hdl}")

    return sources


def _collect_sources_from_entries(repo_root: Path, entries: list[str]) -> list[Path]:
    """Resolve ordered source entries from targets.toml.

    Each entry may be a file path, directory path (collects ``*.vhd``), or glob pattern.
    Paths are resolved relative to the repository root.
    """
    collected: list[Path] = []
    seen: set[Path] = set()

    for entry in entries:
        token = entry.strip()
        if not token:
            raise ValueError("Empty source entry in 'sources'.")

        has_glob = any(ch in token for ch in "*?[")
        if has_glob:
            matches = sorted(path for path in repo_root.glob(token) if path.is_file())
            if not matches:
                raise FileNotFoundError(f"Source glob matched no files: {token}")
        else:
            path = (repo_root / token).resolve()
            if path.is_dir():
                matches = sorted(path.glob("*.vhd"))
                if not matches:
                    raise FileNotFoundError(
                        f"Source directory contains no VHDL files: {path}",
                    )
            elif path.is_file():
                matches = [path]
            else:
                raise FileNotFoundError(f"Source path does not exist: {token}")

        for source in matches:
            resolved = source.resolve()
            if resolved not in seen:
                seen.add(resolved)
                collected.append(resolved)

    if not collected:
        raise ValueError("No HDL sources resolved from 'sources'.")

    return collected


def _collect_sources(repo_root: Path, config: dict[str, Any]) -> list[Path]:
    """Resolve HDL sources from either explicit ``sources`` or legacy ``component``."""
    sources_cfg = config.get("sources")
    if sources_cfg is not None:
        if not isinstance(sources_cfg, list) or not all(
            isinstance(v, str) for v in sources_cfg
        ):
            raise ValueError("'sources' must be a list of path/glob strings.")
        return _collect_sources_from_entries(repo_root=repo_root, entries=sources_cfg)

    component = config.get("component")
    if component:
        return _collect_component_sources(repo_root=repo_root, component=str(component))

    raise ValueError("Target must define either 'sources' or 'component'.")


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run cocotb simulation target.")
    parser.add_argument(
        "--list-targets",
        action="store_true",
        help="List available targets and exit.",
    )
    parser.add_argument("--target", help="Target name from targets.toml.")
    parser.add_argument("--toplevel", help="HDL toplevel entity/module name.")
    return parser


def _resolve_config(tb_root: Path, args: argparse.Namespace) -> dict[str, Any]:
    defaults, targets = _load_targets(tb_root)

    if args.list_targets:
        for name, cfg in sorted(targets.items()):
            description = cfg.get("description", "")
            print(f"{name:28s} {description}")
        raise SystemExit(0)

    target_name = args.target or defaults.get("target")
    if not target_name:
        target_name = "example_passthrough"

    if target_name not in targets:
        valid = ", ".join(sorted(targets.keys()))
        raise ValueError(f"Unknown target '{target_name}'. Valid targets: {valid}")

    config = dict(defaults)
    config.update(targets[target_name])
    config["target"] = target_name

    if args.toplevel:
        config["toplevel"] = args.toplevel

    required_keys = ("sim", "toplevel", "test_module")
    missing = [k for k in required_keys if not config.get(k)]
    if missing:
        raise ValueError(
            f"Target '{target_name}' is missing required fields: {', '.join(missing)}",
        )

    config["waves"] = _parse_bool(config.get("waves", True))
    return config


def main() -> None:
    tb_root = Path(__file__).resolve().parents[1]
    repo_root = tb_root.parent
    args = _build_arg_parser().parse_args()
    config = _resolve_config(tb_root=tb_root, args=args)

    sim = str(config["sim"])
    component = str(config["component"]) if config.get("component") else None
    toplevel = str(config["toplevel"])
    test_module = str(config["test_module"])
    waves = bool(config["waves"])

    sources = _collect_sources(repo_root=repo_root, config=config)

    tb_name = _derive_tb_name(test_module)
    if component:
        build_key = component.lower()
    else:
        build_key = _sanitize_name(str(config["target"])).lower()
    sim_root = tb_root / "sim_build" / tb_name / f"{build_key}_{toplevel}"
    build_dir = sim_root / "build"
    # GHDL resolves the work library from the current working directory.
    # Run tests in build_dir to keep entity/config lookup consistent.
    test_dir = build_dir if sim == "ghdl" else (sim_root / "run")
    runner = get_runner(sim)

    hdl_library = "top"

    runner.build(
        sources=sources,
        hdl_toplevel=toplevel,
        hdl_library=hdl_library,
        build_dir=build_dir,
        always=True,
    )

    runner.test(
        hdl_toplevel=toplevel,
        hdl_toplevel_library=hdl_library,
        test_module=test_module,
        build_dir=build_dir,
        test_dir=test_dir,
        waves=waves,
    )

    if waves:
        wave_name = runner._waves_file()
        if wave_name:
            wave_path = test_dir / wave_name
            if wave_path.exists():
                print(f"Waveform generated: {wave_path}")
            else:
                print(f"Waveform expected at: {wave_path}")


if __name__ == "__main__":
    main()
