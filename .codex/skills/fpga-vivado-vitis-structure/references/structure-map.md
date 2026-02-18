# Structure Map

## Table of contents
- Vivado HW Workspace
- Vitis IDE Workspace
- Optional Anchors in This Checkout
- Current BD Connectivity
- Local IP Repo Reference Map
- UG934 AXI Video Docs
- External Sobel Reference
- Handoff and Ownership Checks
- Quick Command Recipes

## Vivado HW Workspace

Target path: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw`

Use this tree as the active migrated Vivado project workspace for this checkout.

Key anchors:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`: Vivado project file.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/`: imported project sources inside the workspace.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/`: generated HDL/IP/BD outputs.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/`: synthesis/implementation run outputs (`synth_1`, `impl_1`, IP OOC runs).
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.cache/`: cache and compiled library data.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/*`: local packaged IP snapshots.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit`: bitstream artifact.

Constraints for this project are attached through `constrs_1` in `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`.
In the current workspace they include:
- `auto.xdc`
- `timing.xdc`
- `ZyboZ7_A.xdc`

Active imported constraint files are under:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/auto.xdc`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/timing.xdc`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/ZyboZ7_A.xdc`

Important distinction:
- Treat `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs` as the active source-controlled project content in this checkout.
- Treat `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen` as generated artifacts and handoff context.
- Treat `vivado/src` as optional snapshot content only when present.

Top-level BD artifact map (curated):
- `source-controlled`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd`
- `source-controlled`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/imports/hdl/system_wrapper.vhd`
- `source-controlled`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/auto.xdc`
- `source-controlled`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/timing.xdc`
- `source-controlled`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/ZyboZ7_A.xdc`
- `generated`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/system.bxml`
- `handoff artifact`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/system.bda`
- `generated`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/system_ooc.xdc`
- `generated`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/synth/system.vhd`
- `generated`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/hdl/system_wrapper.vhd`
- `handoff artifact`: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/hw_handoff/system.hwh`

## Vitis IDE Workspace

Target path: `vivado/Zybo-Z7-10-Pcam-5C-sw.ide` (optional)

This workspace currently contains two components:
- Platform: `hw_pcam`
- Application (host): `pcam_hdmi`

Component metadata:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/comp-info.json` lists workspace components and original migrated absolute paths.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json` declares platform settings and XSA metadata.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/vitis-comp.json` declares app-domain linkage to `hw_pcam`.

Hardware handoff paths inside workspace:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa`
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/export/hw_pcam/hw/system_wrapper.xsa`
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/export/hw_pcam/hw/system_wrapper.bit`

Interpretation rule:
- The `xsa` field in `vitis-comp.json` can point to an old absolute path from the migration machine.
- The active workspace copy is represented by `xsaPathInPlatform` and the local `hw/system_wrapper.xsa`.

Build/source split in the app (when present):
- Sources: `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/src`
- Build outputs: `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/build`
- FSBL domain sources: `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/zynq_fsbl`

## Optional Anchors in This Checkout

- If `vivado/Zybo-Z7-10-Pcam-5C-sw.ide` is missing, continue with Vivado-only structure and skip Vitis linkage checks.
- If `.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark` is missing, continue without Sobel side-by-side file checks.

## Current BD Connectivity

Primary BD source:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd`
- Optional fallback (if present): `vivado/src/bd/system/system.bd`

This `.bd` is JSON and includes:
- `components`: instantiated IP/core modules and VLNVs
- `interface_ports`: top-level bus interfaces
- `ports`: top-level scalar/vector ports
- `interface_nets`: bus-level connectivity between interface endpoints
- `nets`: scalar connectivity between port endpoints

For deterministic extraction of interfaces and component connectivity, run:

```bash
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/summarize_bd_interfaces.py vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd
```

## Local IP Repo Reference Map

Repository root:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo`

Custom/local IP (primary references):
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_BayerToRGB/component.xml`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_BayerToRGB/hdl/AXI_BayerToRGB.vhd`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_BayerToRGB/hdl/LineBuffer.vhd`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_GammaCorrection/component.xml`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_GammaCorrection/hdl/AXI_GammaCorrection.vhd`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_GammaCorrection/hdl/StoredGammaCoefs.vhd`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_GammaCorrection/xdc/AXI_GammaCorrection.xdc`

Reference-only packaged vendor/library IP markers:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/MIPI_CSI_2_RX/component.xml`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/MIPI_D_PHY_RX/component.xml`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/rgb2dvi/component.xml`

## UG934 AXI Video Docs

Authoritative PDF:
- `amd-docs/ug934_axi_videoIP.pdf`

Generated local markdown corpus (via `markitdown`):
- `references/ug934/ug934.full.md`
- `references/ug934/page_map.json`
- `references/ug934/index.json`
- `references/ug934/index.yaml`
- `references/ug934/sections/*.md`
- `references/ug934/axi_video_musts.md`
- `references/ug934/axi_video_musts.json`

Generate/update corpus:

```bash
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py --doc ug934 --method markitdown
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py --doc ug934
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/build_rules.py --doc ug934
```

Query corpus:

```bash
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug934 "TUSER[0]"
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug934 "TLAST|EOL" --regex
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc all "SOF" --max-results 10
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc all --docs ug892,ug1118 --scope chapters "project mode|IP packager" --regex
```

Structured knowledge DB (generated locally, not committed):

```bash
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/build_skill_db.py --recreate
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py amd --query "ready valid propagation" --docs ug934
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py vhdl --pattern library.nonstd_numeric_disallowed
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py attr --query stable
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py stats
```

DB artifact path:
- `.codex/skills/fpga-vivado-vitis-structure/references/.cache/skill_knowledge.sqlite`
- This path is intentionally ignored by Git and rebuilt on demand.

## External Sobel Reference

Target path: `.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark`

This anchor is optional in this checkout; skip this section if the path is absent.

Primary VHDL reference modules:
- `image_processor_top.vhd`
- `rgb_to_gray.vhd`
- `line_buffer.vhd`
- `sobel_core.vhd`
- `tb_image_processor.vhd`

Reference flow:
- `RGB -> Grayscale -> 3x3 Line Buffer/Window -> Sobel (Gx/Gy) -> Threshold`
- 1 pixel/clock target after fill latency.

Use this tree as a behavioral/algorithm reference. Do not assume naming/style matches project conventions.

## Handoff and Ownership Checks

Before editing:
- Confirm whether requested changes belong in active source-controlled paths (`vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs`) or generated/handoff paths (`vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen`).
- If `vivado/src` is present for comparison, treat it as optional snapshot data unless explicitly selected as the edit target.

To validate Vitis hardware linkage:
1. If `vivado/Zybo-Z7-10-Pcam-5C-sw.ide` exists, read `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json`.
2. Check `xsaPathInPlatform` and confirm that file exists under workspace.
3. Compare checksums between any duplicate XSA copies under `hw/` and `export/`.
4. Treat stale absolute Windows paths in JSON/YAML as migration metadata unless requested to normalize.

To validate active board constraints:
1. Read `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr` and locate `FileSet Name="constrs_1"`.
2. Confirm required `.xdc` files exist in `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/`.
3. Treat `ZyboZ7_A.xdc` as the board pin-constraint base, with `auto.xdc` and `timing.xdc` as additional timing/debug/project constraints.

## Quick Command Recipes

Run from repo root.

List key files in all three target trees:

```bash
find vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw -maxdepth 3 -type f | sort
[ -d vivado/Zybo-Z7-10-Pcam-5C-sw.ide ] && find vivado/Zybo-Z7-10-Pcam-5C-sw.ide -maxdepth 3 -type f | sort
[ -d .external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark ] && find .external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark -maxdepth 3 -type f | sort
```

Inspect Vitis component links:

```bash
[ -d vivado/Zybo-Z7-10-Pcam-5C-sw.ide ] && grep -nE '"name"|"type"|"platform"|"xsa"|"xsaPathInPlatform"' vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/vitis-comp.json
```

Find XSA artifacts:

```bash
find vivado -type f -name '*.xsa' | sort
```

Run this skill's scanner:

```bash
bash .codex/skills/fpga-vivado-vitis-structure/scripts/scan_fpga_workspace.sh
```

Summarize current BD components and interfaces:

```bash
python3 .codex/skills/fpga-vivado-vitis-structure/scripts/summarize_bd_interfaces.py vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd
```
