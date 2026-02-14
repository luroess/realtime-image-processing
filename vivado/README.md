# Vivado Workflow (Integrated Project)

This repository already contains an integrated Vivado project description (`vivado/hw.tcl`).
Use that Tcl file to create/recreate the local generated project.

## Prerequisite

From repository root, make sure submodules are present:

```bash
git submodule update --init --recursive
```

## First-Time Setup (New Clone)

1. Open Vivado.
2. Run `Tools -> Run Tcl Script...` and select:

```text
realtime-image-processing/vivado/hw.tcl
```

3. Vivado recreates the generated project under:

```text
realtime-image-processing/vivado/vivado_project/
```

4. In Vivado Tcl console, load project-local commands:

```tcl
source [file normalize "realtime-image-processing/vivado/Vivado_init.tcl"]
```

5. Verify `wproj` exists:

```tcl
info commands wproj
```

## Daily Workflow

1. Open the generated project (`realtime-image-processing/vivado/vivado_project/hw.xpr`).
2. In Tcl console, run:

```tcl
source [file normalize "absolute_path_to_repo/realtime-image-processing/vivado/Vivado_init.tcl"]
```

3. After project changes, regenerate the tracked project script:

```tcl
wproj
```

4. Commit source files + updated `vivado/hw.tcl`.

## Notes

- `wproj` overwrites `vivado/hw.tcl` by design.
- If you get `invalid command name "wproj"`, source `vivado/Vivado_init.tcl` first.
- Do not commit generated build outputs from `vivado/vivado_project/`.
