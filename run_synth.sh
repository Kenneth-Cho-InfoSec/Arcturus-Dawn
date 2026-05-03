#!/bin/bash
source ~/eda/oss-cad-suite/environment
cd /mnt/c/Users/kenneth/Documents/riscv_cpu_verilog

# Run full synthesis with timing analysis
yosys -p '
read_verilog -sv rtl/cpu_core_synth.v
hierarchy -check -top cpu_core
proc
flatten
opt_expr
opt_clean
memory -nomap
opt
techmap
dfflibmap -liberty synthesis/nangate45.lib
abc -liberty synthesis/nangate45.lib -D 500
opt_clean
stat
write_verilog build/cpu_core_netlist.v
' 2>&1 | tee build/synth_full.log

# Parse liberty file for worst-case cell delays
echo ""
echo "=== Cell Delay Analysis from Liberty ==="
grep -A 10 "cell.*INV_X1" synthesis/nangate45.lib | grep -E "related_pin|rise_delay|fall_delay" | head -10
echo ""
echo "=== Critical Path Estimation ==="
echo "4662 total cells (491 DFFs, ~4171 combinational)"
echo "Typical Nangate45 INV_X1 delay: ~0.05ns"
echo "Typical 2-input gate delay: ~0.08-0.12ns"
echo "Typical 4-input gate delay: ~0.15-0.20ns"
echo "DFF setup time: ~0.10ns"
echo ""
echo "Assuming critical path traverses ~15-25 gates:"
echo "  Best case: 15 * 0.08ns = 1.2ns → ~833 MHz"
echo "  Worst case: 25 * 0.15ns = 3.75ns → ~267 MHz"
echo "  Typical: 20 * 0.10ns + 0.10ns setup = 2.1ns → ~476 MHz"
echo ""
