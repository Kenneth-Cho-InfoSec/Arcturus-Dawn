# Yosys synthesis script for cpu_core with Nangate45

# Read design
read_verilog -sv rtl/cpu_core_synth.v

# Set top module
hierarchy -check -top cpu_core

# Show statistics before optimization
stat

# High-level synthesis passes
proc
flatten
opt_expr
opt_clean
check
opt

# Memory handling
memory -nomap
opt

# Technology mapping to Nangate45 cells
dfflibmap -liberty synthesis/nangate45.lib
abc -liberty synthesis/nangate45.lib -D 1000

# Clean up
opt_clean
check

# Show post-synthesis statistics
stat

# Write gate-level netlist
write_verilog -attr2comment build/cpu_core_netlist.v
