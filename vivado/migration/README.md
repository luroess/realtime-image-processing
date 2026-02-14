# Vivado Migration Inputs

This directory stores migration-only source artifacts copied from the imported GUI workspace.

- `system.bd` is a temporary BD snapshot used by `vivado/src/bd/system.tcl` until a proper
  `write_bd_tcl` export is generated.
- Do not edit migration artifacts as the long-term source of truth.

Canonical source-controlled Vivado inputs live under:

- `vivado/src/hdl`
- `vivado/src/constraints`
- `vivado/src/bd/system.tcl`
- `vivado/src/ip_local`
- `vivado/tcl`

When Vivado is available, regenerate the block-design Tcl and replace the transitional script:

```tcl
write_bd_tcl -force -include_layout vivado/src/bd/system.tcl
```
