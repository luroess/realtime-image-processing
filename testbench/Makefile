# cocotb + GHDL simulation entry point.
# This base setup is intentionally simple and can be reused across modules.

SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
TOPLEVEL ?= example_passthrough
MODULE ?= tests.test_example

# Add DUT sources here. Keep both lists available for future VHDL/Verilog DUT swaps.
VHDL_SOURCES += $(abspath ../rtl/**/*.vhd)
VERILOG_SOURCES +=

# Let cocotb discover local testbench modules (drivers/monitors/models).
export PYTHONPATH := $(abspath .):$(PYTHONPATH)

# GHDL specific flags to generate a waveform file
ifeq ($(SIM), ghdl)
    SIM_ARGS += --wave=sim_build/wave.ghw
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
