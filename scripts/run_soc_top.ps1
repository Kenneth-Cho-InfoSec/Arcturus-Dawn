$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$linuxRoot = "/mnt/c/Users/kenneth/Documents/riscv_cpu_verilog"
Write-Host "Running Full SoC simulation..."

wsl -d Ubuntu -- bash -lc "cd '$linuxRoot' && mkdir -p build && iverilog -g2012 -Wall -o build/soc_top_tb.vvp rtl/cpu_core.v rtl/soc_cluster.v rtl/l1_cache.v rtl/l2_cache.v rtl/soc_interconnect.v rtl/peripherals.v rtl/security.v rtl/soc_top.v tb/tb_soc_top.v && vvp build/soc_top_tb.vvp"