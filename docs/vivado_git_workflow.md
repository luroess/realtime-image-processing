# Vivado Git Workflow (Script-Based + LFS Artifacts)

## Scope and Defaults

- Vivado version pin: `2025.1`
- Canonical model: script-based recreation from tracked sources
- Disposable local build state: `vivado/proj/**`
- Artifact storage: `vivado/artifacts/**` via Git LFS
- IP dependencies:
  - `vivado/ip_repo/vivado-library` (submodule)
  - `vivado/src/ip_local` (local packaged custom IP)

## Migration Snapshot Integrity

SHA256 checksums of the provided migration ZIP inputs:

- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr.zip`
  - `7d77162c17ed347c720729ed48e05c0fbe981343f423a8ffeb9f0066e88ae2b2`
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide.zip`
  - `16aa9a8aee7f4157e51f4e1fac47fd9f187b07491b5ab07c553b3a0fcae3eccd`

Project metadata baseline from migration input:

- Part: `xc7z010clg400-1`
- Board part: `digilentinc.com:zybo-z7-10:part0:1.1`
- Active BD tool version: `2025.1`

## Repository Layout

Canonical Vivado source paths:

- `vivado/src/hdl`
- `vivado/src/constraints`
- `vivado/src/bd/system.tcl`
- `vivado/src/ip_local`
- `vivado/tcl`

Generated/disposable workspace path:

- `vivado/proj/hw`

Artifacts path:

- `vivado/artifacts/handoff/<tag>/`
- `vivado/artifacts/archive/<tag>.zip`

## Bootstrap (Fresh Clone)

1. Install LFS pointers:

```bash
git lfs install
```

2. Pull submodule(s):

```bash
git submodule update --init --recursive
```

3. Launch Vivado `2025.1` and open Tcl console.

## Recreate Project from Git Sources

In Vivado Tcl console:

```tcl
set argv "-repo-root /absolute/path/to/realtime-image-processing"
source vivado/tcl/checkout.tcl
```

Result:

- Recreates project at `vivado/proj/hw/hw.xpr`
- Adds canonical HDL/constraints
- Configures IP repo paths
- Imports BD using `vivado/src/bd/system.tcl`
- Generates and imports `system_wrapper`

## Build and Export Handoff Artifacts

In Vivado Tcl console (project open):

```tcl
set argv "-tag 2026-02-13-main"
source vivado/tcl/build_export.tcl
```

Outputs in `vivado/artifacts/handoff/2026-02-13-main/`:

- `*.bit`
- `*.ltx` (if generated)
- `*.dcp` (impl run outputs)
- `system_wrapper.xsa`

## Create Full Project Archive (Zip)

In Vivado Tcl console (project open):

```tcl
set argv "-tag 2026-02-13-main-full"
source vivado/tcl/archive_full_project.tcl
```

Output:

- `vivado/artifacts/archive/2026-02-13-main-full.zip`

This uses:

```tcl
archive_project -force -include_local_ip_cache <zip>
```

## Block Design Source Policy

Current `vivado/src/bd/system.tcl` is a transitional bootstrap script that imports
`vivado/migration/system.bd` because Vivado was unavailable during migration automation.

When Vivado is available, replace it with direct BD export:

```tcl
write_bd_tcl -force -include_layout vivado/src/bd/system.tcl
```

After replacement, `system.tcl` becomes the canonical BD source in Git.

## Troubleshooting

### Missing IP in catalog

- Verify submodule is checked out: `vivado/ip_repo/vivado-library`
- Verify local IP exists: `vivado/src/ip_local`
- Re-run in Vivado Tcl:

```tcl
update_ip_catalog -rebuild
```

### BD validation updates files

UG892 notes that BD/XCI under BD hierarchy must be writable for validation.
Do not force read-only workspace files during active Vivado sessions.

### Path leakage check

Run this from repo root:

```bash
rg -n "(C:/|E:/|/mnt/)" vivado/src vivado/tcl docs/vivado_git_workflow.md
```

Expected: no matches in canonical tracked source/contracts.

### Artifact policy

- Store milestone artifacts under `vivado/artifacts/**`.
- Avoid committing per-iteration build artifacts.
- Prefer tagged milestone exports.
