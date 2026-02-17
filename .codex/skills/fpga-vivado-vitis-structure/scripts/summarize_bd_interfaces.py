#!/usr/bin/env python3
"""Summarize a Vivado block design JSON file (.bd) for quick interface review."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    default_bd = (
        "vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/"
        "hw.srcs/sources_1/bd/system/system.bd"
    )
    parser = argparse.ArgumentParser(
        description="Summarize components, ports, and interfaces from a Vivado .bd JSON file.",
    )
    parser.add_argument(
        "bd_file",
        nargs="?",
        default=default_bd,
        help=f"Path to the .bd file (default: {default_bd})",
    )
    return parser.parse_args()


def port_width(port_obj: dict) -> int:
    if "left" not in port_obj or "right" not in port_obj:
        return 1
    try:
        left = int(port_obj["left"])
        right = int(port_obj["right"])
    except (TypeError, ValueError):
        return 1
    return abs(left - right) + 1


def is_component_endpoint(endpoint: str) -> bool:
    return "/" in endpoint and not endpoint.startswith("/")


def main() -> int:
    args = parse_args()
    bd_path = Path(args.bd_file)
    if not bd_path.exists():
        print(f"ERROR: missing BD file: {bd_path}", file=sys.stderr)
        return 1

    with bd_path.open("r", encoding="utf-8") as f:
        bd = json.load(f)

    design = bd.get("design", {})
    design_info = design.get("design_info", {})
    components = design.get("components", {})
    interface_ports = design.get("interface_ports", {})
    ports = design.get("ports", {})
    interface_nets = design.get("interface_nets", {})
    nets = design.get("nets", {})

    print("== Design ==")
    print(f"name: {design_info.get('name', '-')}")
    print(f"device: {design_info.get('device', '-')}")
    print(f"tool_version: {design_info.get('tool_version', '-')}")
    print(f"validated: {design_info.get('validated', '-')}")
    print(f"components: {len(components)}")
    print(f"interface_ports: {len(interface_ports)}")
    print(f"ports: {len(ports)}")
    print(f"interface_nets: {len(interface_nets)}")
    print(f"nets: {len(nets)}")

    print("\n== Top Interface Ports ==")
    if not interface_ports:
        print("(none)")
    else:
        for name in sorted(interface_ports):
            obj = interface_ports[name]
            mode = obj.get("mode", "-")
            vlnv = obj.get("vlnv", "-")
            print(f"- {name}: mode={mode}, vlnv={vlnv}")

    print("\n== Top Scalar/Vector Ports ==")
    if not ports:
        print("(none)")
    else:
        for name in sorted(ports):
            obj = ports[name]
            direction = obj.get("direction", "-")
            width = port_width(obj)
            print(f"- {name}: dir={direction}, width={width}")

    print("\n== Components ==")
    if not components:
        print("(none)")
    else:
        for name in sorted(components):
            obj = components[name]
            vlnv = obj.get("vlnv", "-")
            xci_path = obj.get("xci_path", "-")
            print(f"- {name}: {vlnv} [{xci_path}]")

    print("\n== Interface Nets ==")
    if not interface_nets:
        print("(none)")
    else:
        for net_name in sorted(interface_nets):
            endpoints = interface_nets[net_name].get("interface_ports", [])
            joined = ", ".join(endpoints)
            print(f"- {net_name}: {joined}")

    print("\n== Component Interface Endpoints ==")
    per_component: dict[str, set[str]] = {}
    for net_name, obj in interface_nets.items():
        for endpoint in obj.get("interface_ports", []):
            if is_component_endpoint(endpoint):
                comp, pin = endpoint.split("/", 1)
                per_component.setdefault(comp, set()).add(f"{pin} ({net_name})")

    if not per_component:
        print("(none)")
    else:
        for comp_name in sorted(per_component):
            entries = sorted(per_component[comp_name])
            if not entries:
                continue
            print(f"- {comp_name}:")
            for entry in entries:
                print(f"  - {entry}")

    print("\n== Scalar Nets (sample) ==")
    if not nets:
        print("(none)")
    else:
        for net_name in sorted(nets)[:20]:
            endpoints = nets[net_name].get("ports", [])
            print(f"- {net_name}: {', '.join(endpoints)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
