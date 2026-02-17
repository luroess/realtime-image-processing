#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CheckItem:
    label: str
    path: Path


def _status(path: Path) -> str:
    if not path.exists():
        return f"MISSING: {path}"
    mtime = int(path.stat().st_mtime)
    return f"OK: {path} (mtime={mtime})"


def _load_launch_bitstream(launch_path: Path) -> tuple[str | None, Path | None]:
    if not launch_path.exists():
        return None, None

    try:
        data = json.loads(launch_path.read_text(encoding="utf-8"))
    except Exception:
        return None, None

    value = data.get("targetSetup", {}).get("bitstreamFile")
    if not isinstance(value, str) or not value.strip():
        return None, None

    normalized = value.replace("\\", "/")
    resolved = (launch_path.parent / normalized).resolve()
    return value, resolved


def main() -> int:
    repo_root = Path(__file__).resolve().parents[4]

    vivado_bit = repo_root / "vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit"
    vitis_xsa = repo_root / "vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa"
    vitis_comp = repo_root / "vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json"
    launch_json = repo_root / "vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json"

    checks = [
        CheckItem("Vivado impl_1 bitstream", vivado_bit),
        CheckItem("Vitis platform XSA", vitis_xsa),
        CheckItem("Vitis platform descriptor", vitis_comp),
        CheckItem("Vitis app launch config", launch_json),
    ]

    print("Vitis/Vivado handoff check")
    for item in checks:
        print(f"- {item.label}: {_status(item.path)}")

    raw_value, resolved_launch_bit = _load_launch_bitstream(launch_json)
    if raw_value is None or resolved_launch_bit is None:
        print("- launch.json targetSetup.bitstreamFile: MISSING or unreadable")
        return 1

    print(f"- launch.json targetSetup.bitstreamFile: {raw_value}")
    print(f"- Resolved launch bitstream path: {resolved_launch_bit}")

    if not vivado_bit.exists():
        print("RESULT: Cannot compare launch path to Vivado impl_1 bitstream (Vivado .bit missing).")
        return 1

    if resolved_launch_bit == vivado_bit.resolve():
        print("RESULT: launch bitstream matches Vivado impl_1 bitstream.")
        return 0

    print("RESULT: launch bitstream does NOT match Vivado impl_1 bitstream.")
    return 2


if __name__ == "__main__":
    sys.exit(main())
