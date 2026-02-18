---
name: fpga-vivado-vitis-structure
description: Map and reason about the repository layout for the migrated Vivado project (`vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`), optional migrated Vitis IDE workspace (`vivado/Zybo-Z7-10-Pcam-5C-sw.ide`), and optional external Sobel reference (`.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark`). Use when identifying source-vs-generated files, tracing hardware handoff artifacts (`.xsa`, `.bit`) into Vitis platform/app components, parsing block design connectivity, or comparing local pipeline modules against the Sobel reference flow.
---

# FPGA Vivado/Vitis Structure

## Use this skill when

- You need to navigate Vivado and Vitis project structure quickly.
- You need to debug Vivado -> Vitis handoff (`.bit`, `.xsa`, launch path).
- You need to locate source-controlled vs generated files before editing.
- You need to parse the active block design (`system.bd`) and its generated structural VHDL (`system.vhd`).
- You need protocol-aware context for AXI4-Stream video or cocotb verification.

## Fast path workflow (default)

1. Run `make context` from repo root, then read `.codex/AGENTS.md`, `README.md`, and `.codex/Questions.md`.
2. Create a task note before deeper work:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/new_codex_note.py --category <Category> --type <Type> --label <unique_label>`
- Filename format is enforced as `YYYYMMDD_<Category>_<Type>_<Label>.md`.
3. Resolve active anchors:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd`: Source-controlled block design definition.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/synth/system.vhd`: Generated structural VHDL view of the current BD.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide` (optional)
4. For bitstream/linkage issues, check first:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit`: Vivado-generated implementation bitstream.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa`: Vitis hardware handoff artifact imported from Vivado.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json`: Vitis platform component descriptor and linkage metadata.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json`: Debug/run launch config, including programmed bitstream path.
5. If `vivado/Zybo-Z7-10-Pcam-5C-sw.ide` exists, run `.codex/skills/fpga-vivado-vitis-structure/scripts/check_vitis_handoff.py` for quick handoff sanity checks.
6. For BD topology questions, run:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/summarize_bd_interfaces.py vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd`
 - This extracts components, interfaces, and interconnect from the source BD JSON.
 - Then inspect `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/synth/system.vhd` to confirm generated entity/instance naming in structural VHDL.
7. For AXI protocol questions, use the canonical UG934 scripts:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py --doc ug934 --method markitdown`: Extract UG934 into markdown.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py --doc ug934`: Split extracted UG934 into section files.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/build_rules.py --doc ug934`: Build distilled AXI video rules from UG934.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug934 "SOF" --max-results 5`: Query UG934 section corpus by keyword.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc all "SOF|TLAST" --regex --max-results 10`: Query across all configured AMD docs.
7a. For design-flow/revision-control questions, use the canonical UG892 scripts:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py --doc ug892 --method markitdown`: Extract UG892 into markdown.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py --doc ug892`: Split extracted UG892 into section files.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/build_rules.py --doc ug892`: Build distilled Vivado design-flow and revision-control guidance.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug892 "project mode" --max-results 5`: Query UG892 section corpus by keyword.
7b. For IP design-flow questions, use the canonical UG896 scripts:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py --doc ug896 --method markitdown`: Extract UG896 into markdown.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py --doc ug896`: Split extracted UG896 into section files.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug896 "IP catalog" --max-results 5`: Query UG896 section corpus by keyword.
7c. For custom IP packaging questions, use the canonical UG1118 scripts:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py --doc ug1118 --method markitdown`: Extract UG1118 into markdown.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py --doc ug1118`: Split extracted UG1118 into section files.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug1118 "IP packager" --max-results 5`: Query UG1118 section corpus by keyword.
8. For Tcl command-flow questions, use the UG835 scripts:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py --doc ug835 --method markitdown`: Extract UG835 into markdown.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py --doc ug835`: Split extracted UG835 into section files.
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py --doc ug835 "open_run" --max-results 5`: Query UG835 section corpus by keyword.
9. For structured cross-reference and VHDL pattern queries, build/query the local SQLite knowledge DB:
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/build_skill_db.py --recreate`
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py amd --query "project mode" --docs ug892`
- `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py vhdl --pattern library.nonstd_numeric_disallowed`
10. Before editing, classify each touched path as `source-controlled`, `generated`, or `handoff artifact`.

## Vivado to Vitis handoff chain (required checks)

1. Vivado implementation bitstream:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit`: Primary `.bit` output from current implementation run.
2. Vitis platform handoff artifact:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa`: Hardware platform archive consumed by Vitis.
3. Vitis exported platform SW domain:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/export/hw_pcam/sw/domain_ps7_cortexa9_0/`: Generated BSP headers/libs for app builds.
4. Vitis application launch programming path:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json` -> `targetSetup.bitstreamFile`: Bitstream path used by run/debug programming.

For run/debug sessions, treat `targetSetup.bitstreamFile` as the authoritative bitstream path.

## Missing anchor handling

- If `vivado/Zybo-Z7-10-Pcam-5C-sw.ide` is missing, skip Vitis linkage checks (including the `check_vitis_handoff.py` step).
- If `.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark` is missing, skip Sobel side-by-side comparison.

## Edit boundaries (Vitis)

Safe to edit:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/src/`: Application source code.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json`: Run/debug programming and launch settings.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json`: Platform descriptor (edit only for intentional hardware retargeting).

Generated/build artifacts (do not hand-edit unless explicitly required):
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/build/`: Generated application build directory.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/**/bsp/`: Generated BSP sources and libs.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/**/build/`: Generated platform/BSP build outputs.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/export/`: Generated exported platform artifacts.

Handoff artifacts:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa`: Vivado-to-Vitis hardware handoff archive.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit`: Vivado implementation bitstream.

## Deep references

- `.codex/skills/fpga-vivado-vitis-structure/references/structure-map.md`: High-level path map with ownership/source-vs-generated context.
- `.codex/skills/fpga-vivado-vitis-structure/references/top-level-bd-inspection-order.md`: Recommended file-inspection order for complete Vivado understanding.
- `.codex/skills/fpga-vivado-vitis-structure/references/local-ip-repo-reference-map.md`: Local/custom IP repository entry points.
- `.codex/skills/fpga-vivado-vitis-structure/references/current-video-ip-reference.md`: Active video pipeline and official AMD IP doc links.
- `.codex/skills/fpga-vivado-vitis-structure/references/vivado-custom-ip-packaging-best-practices.md`: Condensed UG1118 packaging workflow and guardrails.
- `.codex/skills/fpga-vivado-vitis-structure/references/ug835`: Vivado Tcl command reference digest (`ug835.full.md`, `index.yaml/json`, and split chapter files).
- `.codex/skills/fpga-vivado-vitis-structure/references/ug896`: Vivado IP design flow reference digest (`ug896.full.md`, `index.yaml/json`, and split chapter files).
- `.codex/skills/fpga-vivado-vitis-structure/references/ug1118`: Vivado custom IP packaging reference digest (`ug1118.full.md`, `index.yaml/json`, and split chapter files).
- `.codex/skills/fpga-vivado-vitis-structure/references/vivado-tcl-recovery-and-export.md`: Tcl-first recovery flow for locked BD IP and reliable project export via `wproj`/`vivado-git`.
- `.codex/skills/fpga-vivado-vitis-structure/references/verification-docs-index.md`: Required cocotb/cocotbext-axi docs and testbench guidance.
- `.codex/skills/fpga-vivado-vitis-structure/references/investigation-rules.md`: Investigation and precedence rules for this repository layout.

## Scripts

- `.codex/skills/fpga-vivado-vitis-structure/scripts/check_vitis_handoff.py`: Validates `.bit`, `.xsa`, and launch-bitstream linkage.
- `.codex/skills/fpga-vivado-vitis-structure/scripts/scan_fpga_workspace.sh`: Quick workspace tree/ownership scan.
- `.codex/skills/fpga-vivado-vitis-structure/scripts/summarize_bd_interfaces.py`: Extracts top-level BD components/interfaces/nets.
- `.codex/skills/fpga-vivado-vitis-structure/scripts/extract_markdown.py`: Canonical extractor (`--doc ug934|ug835|ug892|ug896|ug1118`).
- `.codex/skills/fpga-vivado-vitis-structure/scripts/split_sections.py`: Canonical splitter (`--doc ug934|ug835|ug892|ug896|ug1118`).
- `.codex/skills/fpga-vivado-vitis-structure/scripts/query_doc.py`: Canonical corpus search (`--doc ug934|ug835|ug892|ug896|ug1118|all`, `--docs`, `--scope`, `--list-docs`).
- `.codex/skills/fpga-vivado-vitis-structure/scripts/build_skill_db.py`: Build local SQLite FTS5 knowledge DB from AMD indices + local RTL VHDL patterns.
- `.codex/skills/fpga-vivado-vitis-structure/scripts/query_skill_db.py`: Query AMD segments, VHDL pattern hits, attribute references, and DB stats.
- `.codex/skills/fpga-vivado-vitis-structure/scripts/new_codex_note.py`: Create ordered `.codex` note files with enforced naming.
- `.codex/skills/fpga-vivado-vitis-structure/scripts/build_rules.py`: Canonical rule builder (`--doc ug934|ug892`).
