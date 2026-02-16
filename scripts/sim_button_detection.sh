#!/bin/bash

echo "==========================================="
echo "GHDL Simulation Script"
echo "==========================================="

echo "Step 1: Creating sim directory..."
mkdir -p sim

echo "Step 2: Analyzing source files..."
ghdl -a src/*.vhd

echo "Step 3: Analyzing testbench files..."
ghdl -a tb/*.vhd

echo "Step 4: Elaborating testbench..."
ghdl -e tb_button_detection

echo "Step 5: Running simulation..."
ghdl -r tb_button_detection --vcd=sim/wave.vcd

echo "==========================================="
echo "Simulation finished!"
echo "Waveform file: $(pwd)/sim/wave.vcd"
echo "==========================================="
