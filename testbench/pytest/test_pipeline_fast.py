"""Pytest wrappers for fast cocotb tb-sim pipeline orchestration."""

from __future__ import annotations

import ast
import os
import re
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

import pytest
import tomllib

# TODO(config-surface): Keep pytest wrapper defaults aligned with tb-sim target registry and CI expectations.
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
TARGETS_FILE = TESTBENCH_ROOT / "targets.toml"
FAST_TARGETS: tuple[str, ...] = (
    "example_passthrough",
    "test_example",
    "axi_rgb_to_grayscale",
    "window_generator",
    "test_debouncer",
    "test_click_detector",
    "test_debounced_click_detector",
    "axi_sobel_filter",
    "axi_fast_filter",
    "axi_fast_filter_seq",
    "axi_filter_wrapper",
    "axi_filter_wrapper_stress",
    "axi_edge_overlay_pipeline",
    "axi_filter_wrapper_fast",
    "axi_filter_wrapper_fast_seq",
)
# FIXME(filter-drift): Keep these filter expressions synchronized with actual cocotb test names to avoid silently skipping intended coverage.
FAST_TEST_FILTERS: dict[str, str] = {
    "example_passthrough": (
        "test_passthrough_image_file_roundtrip|"
        "test_passthrough_with_backpressure_three_cycle_breaks|"
        "test_passthrough_stress_matrix"
    ),
    "test_example": (
        "test_passthrough_single_frame|test_passthrough_image_file_roundtrip"
    ),
    "axi_rgb_to_grayscale": (
        "test_axi_rgb_to_grayscale_with_backpressure_three_cycle_breaks|"
        "test_axi_rgb_to_grayscale_passthrough_mode|"
        "test_axi_rgb_to_grayscale_stress_matrix"
    ),
    "test_click_detector": "test_click_state_machine",
    "test_debounced_click_detector": "test_debounced_click_detection",
    "window_generator": (
        "test_axi_rgb_to_window_without_pressure|"
        "test_axi_rgb_to_window_with_pressure|"
        "test_axi_rgb_to_window_multi_frame_without_pressure|"
        "test_axi_rgb_to_window_stress_matrix"
    ),
    "axi_sobel_filter": (
        "test_axi_sobel_filter_gradient_gray_windows|test_axi_sobel_filter_stress_fast"
    ),
    "axi_fast_filter": (
        "test_axi_fast_filter_gradient_gray_windows|"
        "test_axi_fast_filter_checkerboard_backpressure_handshake|"
        "test_axi_fast_filter_impulse_mixed_throttle|"
        "test_axi_fast_filter_lenna_end_to_end|"
        "test_axi_fast_filter_mountains_center_crop_end_to_end|"
        "test_axi_fast_filter_stress_fast"
    ),
    "axi_fast_filter_seq": (
        "test_axi_fast_filter_gradient_gray_windows|"
        "test_axi_fast_filter_checkerboard_backpressure_handshake|"
        "test_axi_fast_filter_lenna_end_to_end|"
        "test_axi_fast_filter_mountains_center_crop_end_to_end"
    ),
    "axi_filter_wrapper": (
        "test_axi_windowed_filter_wrapper_simple_image|"
        "test_axi_windowed_filter_wrapper_lenna_end_to_end|"
        "test_axi_windowed_filter_wrapper_backpressure_handshake_only"
    ),
    "axi_filter_wrapper_stress": "test_axi_windowed_filter_wrapper_stress_fast",
    "axi_edge_overlay_pipeline": (
        "test_axi_edge_overlay_pipeline_gradient_overlay|"
        "test_axi_edge_overlay_pipeline_plotly_ours_vs_opencv|"
        "test_axi_edge_overlay_pipeline_overlay_disabled_passthrough|"
        "test_axi_edge_overlay_pipeline_backpressure_protocol|"
        "test_axi_edge_overlay_pipeline_profile_cycles"
    ),
    "axi_filter_wrapper_fast": (
        "test_axi_filter_wrapper_fast_simple_image|"
        "test_axi_filter_wrapper_fast_lenna_end_to_end|"
        "test_axi_filter_wrapper_fast_mountains_center_crop_end_to_end|"
        "test_axi_filter_wrapper_fast_backpressure_handshake_only|"
        "test_axi_filter_wrapper_fast_stress_fast"
    ),
    "axi_filter_wrapper_fast_seq": (
        "test_axi_filter_wrapper_fast_simple_image|"
        "test_axi_filter_wrapper_fast_backpressure_handshake_only"
    ),
}


@dataclass(frozen=True, slots=True)
class JunitSummary:
    # TODO(summary-schema): Extend this structure only when parser and failure formatting are updated together.
    tests: int
    failures: int
    errors: int
    skipped: int
    failed_cases: tuple[str, ...]


@lru_cache(maxsize=1)
def _load_target_registry() -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    # TODO(registry-cache): Preserve caching to avoid repeated TOML parsing during repeated target loops.
    with TARGETS_FILE.open("rb") as f:
        data = tomllib.load(f)

    defaults = data.get("defaults", {})
    targets = data.get("targets", {})
    if not isinstance(defaults, dict):
        raise AssertionError("targets.toml [defaults] must be a table.")
    if not isinstance(targets, dict) or not targets:
        raise AssertionError("targets.toml [targets] must define at least one target.")

    return defaults, targets


@lru_cache(maxsize=1)
def _collect_declared_test_names_by_module() -> dict[str, frozenset[str]]:
    declared_by_module: dict[str, frozenset[str]] = {}
    for test_file in sorted((TESTBENCH_ROOT / "tests").glob("test_*.py")):
        declared: set[str] = set()
        source = test_file.read_text()
        try:
            module = ast.parse(source, filename=str(test_file))
        except SyntaxError:
            # Keep filter validation usable even if a local test file is mid-edit.
            declared.update(
                re.findall(
                    r"^\s*async\s+def\s+(test_[A-Za-z0-9_]+)\s*\(",
                    source,
                    re.MULTILINE,
                ),
            )
            declared.update(
                re.findall(
                    r"^\s*def\s+(test_[A-Za-z0-9_]+)\s*\(",
                    source,
                    re.MULTILINE,
                ),
            )
        else:
            for node in module.body:
                if isinstance(node, ast.FunctionDef | ast.AsyncFunctionDef):
                    if node.name.startswith("test_"):
                        declared.add(node.name)

        module_name = f"tests.{test_file.stem}"
        declared_by_module[module_name] = frozenset(declared)

    return declared_by_module


def _validate_filter_tokens(filters: dict[str, str]) -> None:
    _, targets = _load_target_registry()
    declared_by_module = _collect_declared_test_names_by_module()
    missing_by_target: dict[str, tuple[str, list[str]]] = {}
    for target, filter_expr in filters.items():
        target_cfg = targets.get(target)
        if not isinstance(target_cfg, dict):
            missing_by_target[target] = (
                "<unknown-test-module>",
                [f"<unknown target '{target}'>"],
            )
            continue

        test_module = (
            str(target_cfg.get("test_module", "")).split(",", maxsplit=1)[0].strip()
        )
        declared = declared_by_module.get(test_module, frozenset())
        missing = [
            token
            for token in (part.strip() for part in filter_expr.split("|"))
            if token and token not in declared
        ]
        if missing:
            missing_by_target[target] = (test_module or "<unset-test-module>", missing)

    if not missing_by_target:
        return

    details = "\n".join(
        f"- {target} ({test_module}): {', '.join(tokens)}"
        for target, (test_module, tokens) in sorted(missing_by_target.items())
    )
    raise AssertionError(
        "Invalid COCOTB_TEST_FILTER token(s) not found in target test_module:\n"
        f"{details}",
    )


def _sanitize_name(value: str) -> str:
    # TODO(path-safety): Keep build-key sanitization strict so generated paths remain shell-safe across environments.
    sanitized = "".join(ch if ch.isalnum() or ch in {"_", "-"} else "_" for ch in value)
    return sanitized.strip("_") or "tb"


def _derive_tb_name(test_module: str) -> str:
    # TODO(module-derivation): Keep this derivation compatible with comma-separated module lists in targets.toml.
    first_module = test_module.split(",", maxsplit=1)[0].strip()
    leaf = first_module.split(".")[-1] if first_module else "tb"
    return _sanitize_name(leaf)


def _merged_target_config(target: str) -> dict[str, Any]:
    # FIXME(config-validation): Maintain required-field checks here so invalid target entries fail before spawning simulations.
    defaults, targets = _load_target_registry()
    if target not in targets:
        valid = ", ".join(sorted(targets))
        raise AssertionError(f"Unknown target '{target}'. Valid targets: {valid}")

    config: dict[str, Any] = dict(defaults)
    config.update(targets[target])
    config["target"] = target

    required = ("toplevel", "test_module")
    missing = [key for key in required if not config.get(key)]
    if missing:
        missing_csv = ", ".join(missing)
        raise AssertionError(
            f"Target '{target}' missing required fields: {missing_csv}",
        )

    return config


def _build_dir_for_target(target: str) -> Path:
    # TODO(build-layout): Keep build directory resolution centralized to avoid divergence in XML discovery logic.
    config = _merged_target_config(target)
    toplevel = str(config["toplevel"])
    test_module = str(config["test_module"])
    tb_name = _derive_tb_name(test_module)

    if config.get("component"):
        build_key = _sanitize_name(str(config["component"])).lower()
    else:
        build_key = _sanitize_name(str(config["target"])).lower()

    return TESTBENCH_ROOT / "sim_build" / tb_name / f"{build_key}_{toplevel}" / "build"


def _junit_xml_candidates(build_dir: Path) -> list[Path]:
    # TODO(xml-discovery): Preserve explicit candidate filtering to avoid parsing unrelated XML artifacts.
    if not build_dir.exists():
        return []

    candidates = [
        path
        for path in build_dir.glob("*.xml")
        if path.name == "results.xml" or path.name.endswith(".result.xml")
    ]
    return sorted(candidates, key=lambda path: path.stat().st_mtime, reverse=True)


def _select_results_xml(build_dir: Path, known_xml: set[Path]) -> Path | None:
    # FIXME(result-selection): Revisit newest-file fallback if parallel runs start producing overlapping result sets.
    candidates = _junit_xml_candidates(build_dir)
    if not candidates:
        return None

    new_files = [path for path in candidates if path.resolve() not in known_xml]
    if new_files:
        return new_files[0]

    return candidates[0]


def _read_positive_int_env(name: str, default: int) -> int:
    # TODO(env-guards): Keep strict integer validation so orchestration failures are reported with actionable messages.
    raw = os.getenv(name, str(default)).strip()
    try:
        value = int(raw)
    except ValueError as exc:
        raise AssertionError(
            f"{name} must be a positive integer, got '{raw}'.",
        ) from exc
    if value < 1:
        raise AssertionError(f"{name} must be >= 1, got {value}.")
    return value


def _read_bool_env(name: str, default: bool) -> bool:
    # TODO(env-parsing): Preserve canonical boolean token parsing to keep CI env controls predictable.
    raw = os.getenv(name)
    if raw is None:
        return default
    token = raw.strip().lower()
    if token in {"1", "true", "yes", "y", "on"}:
        return True
    if token in {"0", "false", "no", "n", "off"}:
        return False
    raise AssertionError(f"{name} must be boolean (0/1/true/false), got '{raw}'.")


def _resolve_targets(default_targets: tuple[str, ...]) -> tuple[str, ...]:
    # FIXME(target-coverage): Update default target list when merger modes split into dedicated simulation targets.
    raw_targets = os.getenv("TB_STRESS_TARGETS", "").strip()
    if not raw_targets:
        return default_targets

    candidates = tuple(
        token.strip() for token in raw_targets.split(",") if token.strip()
    )
    if not candidates:
        raise AssertionError(
            "TB_STRESS_TARGETS was set but no non-empty targets were parsed.",
        )

    resolved: list[str] = []
    for target in candidates:
        _merged_target_config(target)
        resolved.append(target)

    return tuple(resolved)


def _format_command_output(
    process: subprocess.CompletedProcess[str],
    *,
    max_lines: int = 60,
) -> str:
    # TODO(log-truncation): Keep bounded output formatting to prevent oversized pytest failure payloads.
    lines: list[str] = []
    if process.stdout:
        lines.extend(f"stdout | {line}" for line in process.stdout.strip().splitlines())
    if process.stderr:
        lines.extend(f"stderr | {line}" for line in process.stderr.strip().splitlines())
    if not lines:
        return "<no process output>"

    if len(lines) > max_lines:
        lines = lines[-max_lines:]
        lines.insert(0, "... output truncated ...")

    return "\n".join(lines)


def _parse_results_xml(results_xml: Path) -> JunitSummary:
    # FIXME(junit-schema): Adjust parser if junit emitter format changes, otherwise failed-case extraction can degrade.
    try:
        root = ET.parse(results_xml).getroot()
    except ET.ParseError as exc:
        raise AssertionError(
            f"Unable to parse junit XML at {results_xml}: {exc}",
        ) from exc

    testcases = root.findall(".//testcase")
    failures = root.findall(".//failure")
    errors = root.findall(".//error")
    skipped = root.findall(".//skipped")

    failed_cases: list[str] = []
    for testcase in testcases:
        name = testcase.attrib.get("name", "<unnamed>")
        classname = testcase.attrib.get("classname", "<no-class>")

        node = testcase.find("failure")
        status = "failure"
        if node is None:
            node = testcase.find("error")
            status = "error"

        if node is None:
            continue

        message = node.attrib.get("message")
        if not message:
            message = (node.text or "").strip()
        if not message:
            message = "no message"

        first_line = message.splitlines()[0][:220]
        failed_cases.append(f"{classname}::{name} [{status}] {first_line}")

    return JunitSummary(
        tests=len(testcases),
        failures=len(failures),
        errors=len(errors),
        skipped=len(skipped),
        failed_cases=tuple(failed_cases),
    )


def _run_tb_target(
    *,
    target: str,
    tier: str,
    iteration: int,
    test_filter: str | None = None,
) -> None:
    # TODO(run-orchestration): Keep target execution, XML parsing, and failure aggregation in one place for consistent behavior across tiers.
    env = os.environ.copy()
    env["TB_STRESS_TIER"] = tier
    env.pop("COCOTB_TESTCASE", None)
    if test_filter:
        env["COCOTB_TEST_FILTER"] = test_filter
    else:
        env.pop("COCOTB_TEST_FILTER", None)

    build_dir = _build_dir_for_target(target)
    known_xml: set[Path] = set()
    for path in _junit_xml_candidates(build_dir):
        known_xml.add(path.resolve())

    cmd = ["uv", "run", "tb-sim", "--target", target]
    process = subprocess.run(
        cmd,
        cwd=TESTBENCH_ROOT,
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )

    results_xml = _select_results_xml(build_dir, known_xml=known_xml)
    problems: list[str] = []

    if results_xml is None:
        problems.append(
            "Missing junit results file "
            f"for target '{target}' (iteration {iteration}) under {build_dir} "
            "(expected *.result.xml or results.xml).",
        )
        summary = None
    else:
        summary = _parse_results_xml(results_xml)
        if summary.tests == 0:
            problems.append(
                f"No testcase entries found in junit results for target '{target}': {results_xml}",
            )
        if summary.failures > 0 or summary.errors > 0:
            failed_list = "\n".join(summary.failed_cases[:10])
            if len(summary.failed_cases) > 10:
                failed_list += "\n... additional failures omitted ..."
            problems.append(
                f"JUnit reports failures for target '{target}' (iteration {iteration}): "
                f"tests={summary.tests}, failures={summary.failures}, errors={summary.errors}, "
                f"skipped={summary.skipped}\n{failed_list}",
            )

    if process.returncode != 0:
        problems.append(
            f"tb-sim exited with non-zero status for target '{target}' "
            f"(iteration {iteration}): rc={process.returncode}",
        )

    if problems:
        details = _format_command_output(process)
        problem_text = "\n".join(problems)
        raise AssertionError(f"{problem_text}\nCommand output:\n{details}")

    assert summary is not None


@pytest.mark.fast
def test_pipeline_fast_tier_targets() -> None:
    # FIXME(filter-maintenance): Correct stale filter tokens promptly (for example missing passthrough test names) to avoid false confidence in fast-tier coverage.
    _validate_filter_tokens(FAST_TEST_FILTERS)
    targets = _resolve_targets(default_targets=FAST_TARGETS)
    repeat = _read_positive_int_env("TB_STRESS_REPEAT", default=1)
    keep_going = _read_bool_env("TB_STRESS_KEEP_GOING", default=True)

    failures: list[str] = []
    for target in targets:
        test_filter = FAST_TEST_FILTERS.get(target)
        for iteration in range(1, repeat + 1):
            try:
                _run_tb_target(
                    target=target,
                    tier="fast",
                    iteration=iteration,
                    test_filter=test_filter,
                )
            except AssertionError as exc:
                if not keep_going:
                    raise
                failures.append(str(exc))

    if failures:
        joined = "\n\n".join(failures)
        pytest.fail(f"Fast tier encountered one or more target failures:\n\n{joined}")
