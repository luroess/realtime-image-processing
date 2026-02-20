"""Python runner entry point for cocotb simulations."""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
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


def _resolve_parameters(config: dict[str, Any]) -> dict[str, object]:
    """Resolve HDL generic/parameter overrides for cocotb runner."""
    raw = config.get("generics", {})
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise ValueError("'generics' must be a mapping of name -> value.")

    resolved: dict[str, object] = {}
    for key, value in raw.items():
        if not isinstance(key, str) or not key:
            raise ValueError("Generic names must be non-empty strings.")
        if not isinstance(value, (int, float, bool, str)):
            raise ValueError(
                f"Unsupported generic type for '{key}': {type(value).__name__}",
            )
        resolved[key] = value

    return resolved


def _resolve_cli_args(config: dict[str, Any], field_name: str) -> list[str]:
    raw_args = config.get(field_name, [])
    if raw_args is None:
        return []
    if not isinstance(raw_args, list) or not all(isinstance(v, str) for v in raw_args):
        raise ValueError(f"'{field_name}' must be a list of strings when provided.")
    return list(raw_args)


def _resolve_map(config: dict[str, Any], field_name: str) -> dict[str, object]:
    raw = config.get(field_name, {})
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise ValueError(f"'{field_name}' must be a table/map when provided.")
    return dict(raw)


def _resolve_hdl_library(config: dict[str, Any], field_name: str) -> str:
    raw = config.get(field_name, "top")
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError(f"'{field_name}' must be a non-empty string when provided.")
    return raw.strip()


def _resolve_build_stages(repo_root: Path, config: dict[str, Any]) -> list[dict[str, Any]]:
    raw_stages = config.get("build_stages")
    if raw_stages is None:
        return [
            {
                "name": "default",
                "hdl_library": _resolve_hdl_library(config=config, field_name="hdl_library"),
                "sources": _collect_sources(repo_root=repo_root, config=config),
                "build_args": _resolve_cli_args(config=config, field_name="build_args"),
                "parameters": _resolve_map(config=config, field_name="build_parameters"),
            }
        ]

    if not isinstance(raw_stages, list) or not raw_stages:
        raise ValueError("'build_stages' must be a non-empty list when provided.")

    stages: list[dict[str, Any]] = []
    for idx, raw_stage in enumerate(raw_stages, start=1):
        if not isinstance(raw_stage, dict):
            raise ValueError(f"'build_stages[{idx}]' must be a table/map.")

        sources_cfg = raw_stage.get("sources")
        if not isinstance(sources_cfg, list) or not all(
            isinstance(v, str) for v in sources_cfg
        ):
            raise ValueError(
                f"'build_stages[{idx}].sources' must be a list of path/glob strings.",
            )

        stage_name = raw_stage.get("name")
        if stage_name is None:
            stage_name = f"stage_{idx}"
        elif not isinstance(stage_name, str) or not stage_name.strip():
            raise ValueError(f"'build_stages[{idx}].name' must be a non-empty string.")

        stages.append(
            {
                "name": stage_name.strip(),
                "hdl_library": _resolve_hdl_library(
                    config=raw_stage,
                    field_name="hdl_library",
                ),
                "sources": _collect_sources_from_entries(
                    repo_root=repo_root,
                    entries=sources_cfg,
                ),
                "build_args": _resolve_cli_args(
                    config=raw_stage,
                    field_name="build_args",
                ),
                "parameters": _resolve_map(
                    config=raw_stage,
                    field_name="build_parameters",
                ),
            }
        )

    return stages


def _prepend_ghdl_std_arg(args: list[str]) -> list[str]:
    if any(arg.startswith("--std=") for arg in args):
        return list(args)
    return ["--std=08", *args]


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


def _resolve_config(tb_root: Path, args: argparse.Namespace) -> list[dict[str, Any]]:
    defaults, targets = _load_targets(tb_root)

    if args.list_targets:
        for name, cfg in sorted(targets.items()):
            description = cfg.get("description", "")
            print(f"{name:28s} {description}")
        raise SystemExit(0)

    target_names: list[str]
    if args.target:
        target_names = [args.target]
    else:
        target_names = sorted(targets.keys())

    configs: list[dict[str, Any]] = []
    for target_name in target_names:
        if target_name not in targets:
            valid = ", ".join(sorted(targets.keys()))
            raise ValueError(
                f"Unknown target '{target_name}'. Valid targets: {valid}",
            )

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
        configs.append(config)

    return configs


def main() -> None:
    tb_root = Path(__file__).resolve().parents[1]
    repo_root = tb_root.parent
    args = _build_arg_parser().parse_args()
    configs = _resolve_config(tb_root=tb_root, args=args)

    for config in configs:
        sim = str(config["sim"])
        component = str(config["component"]) if config.get("component") else None
        toplevel = str(config["toplevel"])
        target_name = str(config["target"])
        test_module = str(config["test_module"])
        waves = bool(config["waves"])
        parameters = _resolve_map(config=config, field_name="parameters")
        test_args = _resolve_cli_args(config=config, field_name="test_args")
        build_stages = _resolve_build_stages(repo_root=repo_root, config=config)

        toplevel_library_raw = config.get("toplevel_library")
        if toplevel_library_raw is None:
            hdl_toplevel_library = str(build_stages[-1]["hdl_library"])
        elif not isinstance(toplevel_library_raw, str) or not toplevel_library_raw.strip():
            raise ValueError("'toplevel_library' must be a non-empty string when provided.")
        else:
            hdl_toplevel_library = toplevel_library_raw.strip()

        # Many entities in this repo use dependent generic expressions that require
        # VHDL-2008 semantics with GHDL.
        if sim == "ghdl":
            for stage in build_stages:
                stage["build_args"] = _prepend_ghdl_std_arg(list(stage["build_args"]))
            test_args = _prepend_ghdl_std_arg(test_args)

        tb_name = _derive_tb_name(test_module)
        if component:
            build_key = component.lower()
        else:
            build_key = _sanitize_name(target_name).lower()
        sim_root = tb_root / "sim_build" / tb_name / f"{build_key}_{toplevel}"
        build_dir = sim_root / "build"
        # GHDL library state in top-obj08.cf can retain stale entity/architecture
        # mappings across target/source changes. Recreate the build directory for
        # each GHDL run to avoid stale elaboration failures.
        if sim == "ghdl":
            shutil.rmtree(build_dir, ignore_errors=True)
        build_dir.mkdir(parents=True, exist_ok=True)
        # GHDL resolves the work library from the current working directory.
        # Run tests in build_dir to keep entity/config lookup consistent.
        test_dir = build_dir if sim == "ghdl" else (sim_root / "run")
        runner = get_runner(sim)

        print(f"=== running target '{target_name}' ({test_module}) ===")
        for idx, stage in enumerate(build_stages, start=1):
            stage_name = str(stage["name"])
            stage_library = str(stage["hdl_library"])
            stage_sources = stage["sources"]
            stage_build_args = list(stage["build_args"])
            stage_parameters = dict(stage["parameters"])
            stage_toplevel = toplevel if idx == len(build_stages) else None
            print(
                f"  - build stage {idx}/{len(build_stages)}: "
                f"name={stage_name}, library={stage_library}, sources={len(stage_sources)}",
            )
            runner.build(
                sources=stage_sources,
                hdl_toplevel=stage_toplevel,
                hdl_library=stage_library,
                parameters=stage_parameters,
                build_args=stage_build_args,
                build_dir=build_dir,
                always=True,
            )

        runner.test(
            hdl_toplevel=toplevel,
            hdl_toplevel_library=hdl_toplevel_library,
            test_module=test_module,
            parameters=parameters,
            test_args=test_args,
            build_dir=build_dir,
            test_dir=test_dir,
            waves=waves,
        )

        if waves:
            wave_name = None
            public_waves_file = getattr(runner, "waves_file", None)
            if callable(public_waves_file):
                wave_name = public_waves_file()
            else:
                private_waves_file = getattr(runner, "_waves_file", None)
                if callable(private_waves_file):
                    wave_name = private_waves_file()
            if wave_name:
                wave_path = test_dir / wave_name
                if wave_path.exists():
                    print(f"Waveform generated: {wave_path}")
                else:
                    print(f"Waveform expected at: {wave_path}")


if __name__ == "__main__":
    main()
