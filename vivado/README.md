# Vivado Git Tracking Workflow

`Vivado/vivado-git` is now a real git submodule pointing to:

- https://github.com/barbedo/vivado-git

The exact version is pinned by this repository's submodule SHA.

Submodule initialization commands are documented in the repository root `README.md`.

To pull the latest upstream submodule revision intentionally:

```bash
git submodule update --remote Vivado/vivado-git
```

## Project files in this repo

- `Vivado/vivado-git/` (submodule)
- `Vivado/Vivado_init.tcl` (project-local entry point into submodule)

## One-time Vivado setup (Linux and Windows)

Vivado loads `Vivado_init.tcl` from your user config directory.

- Linux: `~/.Xilinx/Vivado/Vivado_init.tcl`
- Windows: `%APPDATA%/Xilinx/Vivado/Vivado_init.tcl`

Add one source line:

```tcl
source [file normalize "/absolute/path/to/realtime-image-processing/Vivado/Vivado_init.tcl"]
```

Use forward slashes in the path, including on Windows.

For one session only, run the same command directly in the Vivado Tcl console.

## Daily usage

1. Open your project in Vivado.
2. In the Tcl console, load the project-local init (safe to run every session):

```tcl
source [file normalize "/absolute/path/to/realtime-image-processing/Vivado/Vivado_init.tcl"]
```
3. Run `wproj`.
4. This generates `<project_name>.tcl` in the project root (for this repo, under `Vivado/`).
5. Commit sources plus generated project Tcl with your normal git client.

If you commit from Vivado Tcl console instead, you can use wrapped commands:

- `git status`
- `git add ...`
- `git commit -m "message"`

## Important layout note

The `vivado-git` flow is designed around an untracked generated folder named `vivado_project/`.

This repo currently also has a legacy in-place project layout (`hw.*`). The local `Vivado/.gitignore` excludes generated `hw.*` build outputs and keeps source-like content trackable.
