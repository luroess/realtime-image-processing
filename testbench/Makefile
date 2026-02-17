# cocotb + GHDL simulation entry point.
# This base setup is intentionally simple and can be reused across modules.

SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
TOPLEVEL ?= debouncedclickdetector
MODULE ?= tests.test_debounced_click_detector

# Add DUT sources here. Keep both lists available for future VHDL/Verilog DUT swaps.
VHDL_SOURCES += $(abspath ../rtl/**/**/**.vhd)
VERILOG_SOURCES +=

# Let cocotb discover local testbench modules (drivers/monitors/models).
export PYTHONPATH := $(abspath .):$(PYTHONPATH)

.PHONY: clean-sim
clean-sim:
	rm -rf sim_build

include $(shell cocotb-config --makefiles)/Makefile.sim
