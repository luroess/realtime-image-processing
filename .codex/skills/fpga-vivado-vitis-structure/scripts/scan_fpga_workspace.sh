#!/usr/bin/env bash
set -euo pipefail

v_root="${1:-.}"
v_root="$(cd "$v_root" && pwd)"

v_hw_root="vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw"
if [ ! -d "${v_root}/${v_hw_root}" ]; then
  v_hw_root="vivado/hw"
fi
v_hw_xpr="${v_hw_root}/hw.xpr"

section() {
  printf "\n== %s ==\n" "$1"
}

status_path() {
  local v_path="$1"
  if [ -e "${v_root}/${v_path}" ]; then
    printf "ok      %s\n" "$v_path"
  else
    printf "missing %s\n" "$v_path"
  fi
}

count_ext() {
  local v_dir="$1"
  local v_ext="$2"
  if [ -d "$v_dir" ]; then
    find "$v_dir" -type f -name "*.${v_ext}" | wc -l | awk '{print $1}'
  else
    echo 0
  fi
}

checksum_cmd=""
if command -v sha256sum >/dev/null 2>&1; then
  checksum_cmd="sha256sum"
elif command -v md5sum >/dev/null 2>&1; then
  checksum_cmd="md5sum"
fi

section "Root"
echo "$v_root"

section "Anchors"
status_path ".codex/AGENTS.md"
status_path "README.md"
status_path ".codex/Questions.md"
status_path "${v_hw_root}"
status_path "vivado/Zybo-Z7-10-Pcam-5C-sw.ide"
status_path ".external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark"

section "Vivado HW Workspace"
for v_dir in hw.srcs hw.gen hw.runs hw.ipdefs hw.cache; do
  status_path "${v_hw_root}/${v_dir}"
done
status_path "${v_hw_xpr}"
status_path "${v_hw_root}/hw.runs/impl_1/system_wrapper.bit"

section "Vivado Board + Constraints"
if [ -f "${v_root}/${v_hw_xpr}" ]; then
  v_board_part="$(grep -o 'Option Name="BoardPart" Val="[^"]*"' "${v_root}/${v_hw_xpr}" | head -n1 | sed -E 's/.*Val="([^"]+)"/\1/')"
  v_part="$(grep -o 'Option Name="Part" Val="[^"]*"' "${v_root}/${v_hw_xpr}" | head -n1 | sed -E 's/.*Val="([^"]+)"/\1/')"
  [ -n "${v_part:-}" ] && echo "Part: ${v_part}"
  [ -n "${v_board_part:-}" ] && echo "BoardPart: ${v_board_part}"
  sed -n '/<FileSet Name="constrs_1"/,/<\/FileSet>/p' "${v_root}/${v_hw_xpr}" \
    | grep -o '\$PSRCDIR/constrs_1/imports/constraints/[^"]*\.xdc' \
    | sed 's#\$PSRCDIR/constrs_1/imports/constraints/#constrs_1: #' \
    | while read -r v_item; do
        echo "${v_item}"
      done
else
  echo "missing ${v_hw_xpr}"
fi

for v_xdc in "ZyboZ7_A.xdc" "auto.xdc" "timing.xdc"; do
  status_path "vivado/src/constraints/${v_xdc}"
done

section "Vitis IDE Components"
if [ -d "${v_root}/vivado/Zybo-Z7-10-Pcam-5C-sw.ide" ]; then
  find "${v_root}/vivado/Zybo-Z7-10-Pcam-5C-sw.ide" -maxdepth 3 -type f -name "vitis-comp.json" | sort | while read -r v_file; do
    echo "-- ${v_file#$v_root/}"
    grep -nE '"name"|"type"|"platform"|"domain"|"xsa"|"xsaPathInPlatform"' "$v_file" | sed 's/^/   /'
  done
else
  echo "missing vivado/Zybo-Z7-10-Pcam-5C-sw.ide"
fi

section "XSA and BIT Artifacts"
for v_tree in "${v_hw_root}" "vivado/build" "vivado/Zybo-Z7-10-Pcam-5C-sw.ide"; do
  if [ -d "${v_root}/${v_tree}" ]; then
    find "${v_root}/${v_tree}" -type f \( -name "*.xsa" -o -name "*.bit" \) | sort | while read -r v_artifact; do
      local_path="${v_artifact#$v_root/}"
      if [ -n "$checksum_cmd" ]; then
        checksum="$($checksum_cmd "$v_artifact" | awk '{print $1}')"
        printf "%s  %s\n" "$checksum" "$local_path"
      else
        echo "$local_path"
      fi
    done
  fi
done

section "Source File Counts"
printf "%s: vhd=%s tcl=%s xci=%s\n" \
  "${v_hw_root}" \
  "$(count_ext "${v_root}/${v_hw_root}" "vhd")" \
  "$(count_ext "${v_root}/${v_hw_root}" "tcl")" \
  "$(count_ext "${v_root}/${v_hw_root}" "xci")"
printf "vivado/src: xdc=%s bd=%s\n" \
  "$(count_ext "${v_root}/vivado/src" "xdc")" \
  "$(count_ext "${v_root}/vivado/src" "bd")"
printf "vitis .ide: c=%s cc=%s h=%s yaml=%s\n" \
  "$(count_ext "${v_root}/vivado/Zybo-Z7-10-Pcam-5C-sw.ide" "c")" \
  "$(count_ext "${v_root}/vivado/Zybo-Z7-10-Pcam-5C-sw.ide" "cc")" \
  "$(count_ext "${v_root}/vivado/Zybo-Z7-10-Pcam-5C-sw.ide" "h")" \
  "$(count_ext "${v_root}/vivado/Zybo-Z7-10-Pcam-5C-sw.ide" "yaml")"
printf "sobel ref: vhd=%s py=%s\n" \
  "$(count_ext "${v_root}/.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark" "vhd")" \
  "$(count_ext "${v_root}/.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark" "py")"

section "Done"
echo "Use summarize_bd_interfaces.py for a component/interface inventory."
echo "Use references/structure-map.md to interpret ownership and edit policy."
