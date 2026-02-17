# Investigation Rules

- Prefer active migrated Vivado sources in `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs`.
- Treat `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen` as generated unless explicitly asked to edit generated files.
- Treat `vivado/src` as optional snapshot content for explicit cross-checking only.
- Resolve active constraints from `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr` (`constrs_1`) into `.../hw.srcs/constrs_1/imports/constraints/`.
- For BD questions, analyze `.../hw.srcs/sources_1/bd/system/system.bd` first; compare against `vivado/src/bd/system/system.bd` only if present.
- Use `references/ug934/` outputs for AXI4-Stream protocol questions.
- For Vitis linkage, prioritize:
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/vitis-comp.json`: Platform component metadata and linkage settings.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa`: Imported hardware handoff archive used by Vitis.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json` (`targetSetup.bitstreamFile`): Actual run/debug programmed bitstream path.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit`: Source Vivado implementation bitstream to compare against launch path.
- For run/debug programming path questions, treat `launch.json` `targetSetup.bitstreamFile` as authoritative.
- If `.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark` exists, use:
- `image_processor_top.vhd`: Top-level reference pipeline wiring.
- `rgb_to_gray.vhd`: RGB-to-grayscale conversion reference.
- `line_buffer.vhd`: 3x3 neighborhood buffering/window reference.
- `sobel_core.vhd`: Sobel gradient and thresholding reference behavior.
- `tb_image_processor.vhd`: Reference testbench for expected frame-level behavior.
