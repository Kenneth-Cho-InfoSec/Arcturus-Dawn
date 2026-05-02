$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$linuxRoot = "/mnt/c/Users/kenneth/Documents/riscv_cpu_verilog"
Write-Host "Running L2 cache simulation..."

wsl -d Ubuntu -- bash -lc "cd '$linuxRoot' && mkdir -p build && iverilog -g2012 -o build/l2_cache_tb.vvp rtl/l2_cache.v tb/tb_l2_cache.v && vvp build/l2_cache_tb.vvp"