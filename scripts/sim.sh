#!/bin/bash
mkdir -p sim
ghdl -a src/*.vhd
ghdl -a tb/*.vhd
ghdl -e tb_debouncing
ghdl -r tb_debouncing --vcd=sim/wave.vcd
gtkwave sim/wave.vcd
