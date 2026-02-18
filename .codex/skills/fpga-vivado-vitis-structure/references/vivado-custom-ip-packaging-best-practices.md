# Vivado Custom IP Packaging Best Practices (UG1118)

Use this checklist when creating or maintaining custom AXI/AXIS IP.

1. Scope project model correctly.
- Use `Edit IP` for single-IP packaging.
- Use a separate consumer project for multi-IP integration checks.

2. Set packager defaults once.
- Configure `Tools -> Settings -> Project Settings -> IP -> Packager`.
- Set vendor/library/category and external `ip_repo` location.

3. Keep IP repository external and version controlled.
- Keep packaged IP out of transient build trees.
- Version/tag releases explicitly.

4. Fix top-level definition in File Groups.
- Set `Model Name` for synthesis/simulation/implementation groups.

5. Keep packaged IP self-contained.
- Copy sources into IP directory.
- Ensure all HDL/XDC/include paths are local to packaged IP.

6. Make AXI/AXIS inference deterministic.
- Use naming convention `<interface_name>_<axi_signal_name>`.
- Manually map interfaces if inference fails.

7. Make clock/reset association explicit.
- Use recognized reset names and clear polarity.
- Set `ASSOCIATED_BUSIF` where needed.

8. Add out-of-context constraints intentionally.
- Provide OOC clocks and correct `USED_IN` settings.

9. Avoid global include assumptions.
- Add explicit `` `include `` lines.
- Mark headers correctly in File Groups.

10. Package an Example Design.
- Include a minimal reproducible instantiation for smoke tests.

11. Configure consumer project IP repository.
- Add root `ip_repo` path in project IP repository settings.

Official references:
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Creating-a-New-AXI4-Peripheral
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Using-the-Packager-Settings
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Versioning-and-Revision-Control
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/File-Groups
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Top-Level-HDL-Requirements
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Inferring-AXI-Signals
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Ports-and-Interfaces
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Inferring-Clock-and-Reset-Interfaces
- https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip/Managing-Out-of-Context-Constraints
