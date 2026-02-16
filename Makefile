SHELL := /bin/bash

.PHONY: context make-context contex

DOCS_PATTERN := *.md|*.png|*.jpg|*.jpeg|*.svg|*.gif|*.webp|*.pdf
RTL_PATTERN := *.md|*.vhd

VIVADO_HW_ROOT := vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw
VIVADO_BD_IP_ROOT := $(VIVADO_HW_ROOT)/hw.srcs/sources_1/bd/system/ip
VITIS_ROOT := vivado/Zybo-Z7-10-Pcam-5C-sw.ide

context:
	@command -v tree >/dev/null 2>&1 || { echo "ERROR: 'tree' is required."; exit 1; }
	@{ \
		echo "# Project Context Snapshot"; \
		echo ""; \
		echo "Generated: $$(date -Iseconds)"; \
		echo ""; \
		echo "## docs (*.md + figures)"; \
		tree docs -P "$(DOCS_PATTERN)" --prune --noreport 2>/dev/null || echo "docs (missing)"; \
		echo ""; \
		echo "## rtl (*.md + *.vhd)"; \
		tree rtl -P "$(RTL_PATTERN)" --prune --noreport 2>/dev/null || echo "rtl (missing)"; \
		echo ""; \
		echo "## testbench (pyproject.toml + targets.toml + *.py)"; \
		tree testbench -P "pyproject.toml|targets.toml|*.py" --prune --noreport 2>/dev/null || echo "testbench (missing)"; \
		echo ""; \
		echo "## testbench/targets.toml (contents)"; \
		if [ -f "testbench/targets.toml" ]; then \
			cat testbench/targets.toml; \
		else \
			echo "testbench/targets.toml (missing)"; \
		fi; \
		echo ""; \
		echo "## vivado (important anchors)"; \
		if [ -d "$(VIVADO_HW_ROOT)" ]; then \
			tree "$(VIVADO_HW_ROOT)" -P "hw.xpr|system.bd|system.vhd|system_wrapper.bit" --prune --noreport; \
			tree "$(VIVADO_BD_IP_ROOT)" -P "system_AXI_BayerToRGB_0_0.xci|system_AXI_GammaCorrection_1_0.xci|system_AXI_RgbToGrayscale_0_0.xci|system_xlconstant_0_0.xci" --prune --noreport 2>/dev/null || true; \
		else \
			echo "$(VIVADO_HW_ROOT) (missing)"; \
		fi; \
		echo ""; \
		echo "## vitis handoff (if present)"; \
		if [ -d "$(VITIS_ROOT)" ]; then \
			tree "$(VITIS_ROOT)" -P "system_wrapper.xsa|vitis-comp.json|launch.json" --prune --noreport; \
		else \
			echo "$(VITIS_ROOT) (missing, skipped)"; \
		fi; \
	}

make-context: context

contex: context
