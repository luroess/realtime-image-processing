# Setup & Install Instructions

## uv Package Manager

- [Installing uv](https://docs.astral.sh/uv/getting-started/installation/)

Initialize and sync the project environment:

```bash
uv sync
uv run python --version
```

## Vivado & Vitis

- [Digilent install instructions](https://digilent.com/reference/programmable-logic/guides/vitis-unified-installation)
  - Install `2025.1`, choose device family `Zynq-7000`.

Use the migrated Vivado/Vitis workspaces in this repo:
- Vivado project: `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`
- Vitis workspace: `vivado/Zybo-Z7-10-Pcam-5C-sw.ide`

- [TeraTerm5 Terminal Emulator](https://github.com/TeraTermProject/teraterm/releases)
- [Using TeraTerm with Zybo](https://digilent.com/reference/programmable-logic/guides/serial-terminals/windows)
  1. Establish a serial connection to the Zybo's UART (115200 baud, 8N1).

## NVC

- [NVC source + install instructions](https://github.com/nickg/nvc)

## Surfer

- [Surfer Repo + install instructions](https://github.com/ripopov/surfer)
