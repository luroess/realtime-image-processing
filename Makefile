SHELL := /bin/bash

.PHONY: context make-context contex skill-db skill-query codex-note skill-test report-check

DOCS_PATTERN := *.md|*.png|*.jpg|*.jpeg|*.svg|*.gif|*.webp|*.pdf
RTL_PATTERN := *.md|*.vhd

VIVADO_HW_ROOT := vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw
VIVADO_BD_IP_ROOT := $(VIVADO_HW_ROOT)/hw.srcs/sources_1/bd/system/ip
VITIS_ROOT := vivado/Zybo-Z7-10-Pcam-5C-sw.ide
SKILL_SCRIPTS_DIR := .codex/skills/fpga-vivado-vitis-structure/scripts
SKILL_DB_PATH := .codex/skills/fpga-vivado-vitis-structure/references/.cache/skill_knowledge.sqlite

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

skill-db:
	@python3 $(SKILL_SCRIPTS_DIR)/build_skill_db.py \
		--db "$${DB:-$(SKILL_DB_PATH)}" \
		--docs "$${DOCS:-all}" \
		--rtl-root "$${RTL_ROOT:-rtl}" \
		--backend "$${BACKEND:-regex}" \
		$${RECREATE:+--recreate}

skill-query:
	@if [ -z "$$CMD" ]; then \
		echo "Usage: make skill-query CMD='amd --query \"SOF\" --docs ug934' [DB=path]"; \
		exit 1; \
	fi
	@python3 $(SKILL_SCRIPTS_DIR)/query_skill_db.py --db "$${DB:-$(SKILL_DB_PATH)}" $$CMD

codex-note:
	@if [ -z "$$CATEGORY" ] || [ -z "$$TYPE" ] || [ -z "$$LABEL" ]; then \
		echo "Usage: make codex-note CATEGORY=Research TYPE=Report LABEL=my_note [DATE=YYYYMMDD]"; \
		exit 1; \
	fi
	@python3 $(SKILL_SCRIPTS_DIR)/new_codex_note.py \
		--category "$$CATEGORY" \
		--type "$$TYPE" \
		--label "$$LABEL" \
		$${DATE:+--date "$$DATE"}

skill-test:
	@python3 -m unittest discover -s .codex/skills/fpga-vivado-vitis-structure/scripts/tests -p "test_*.py"

report-check:
	@mkdir -p docs/report/build
	@python3 docs/report/analysis/check_citations.py
	@set -euo pipefail; \
		root_out="$$(typst compile --root . docs/report/report.typ docs/report/build/report.pdf 2>&1)"; \
		local_out="$$(cd docs/report && typst compile report.typ build/report_from_report_dir.pdf 2>&1)"; \
	if [ -n "$$root_out" ]; then \
		echo "ERROR: report root compile produced diagnostics:"; \
		echo "$$root_out"; \
		exit 1; \
	fi; \
	if [ -n "$$local_out" ]; then \
		echo "ERROR: report local compile produced diagnostics:"; \
		echo "$$local_out"; \
		exit 1; \
	fi; \
	echo "OK: report compile is warning-free in both modes."
