$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$linuxRoot = "/mnt/c/Users/kenneth/Documents/riscv_cpu_verilog"
Write-Host "Running L1 cache simulation..."

wsl -d Ubuntu -- bash -lc "cd '$linuxRoot' && mkdir -p build && iverilog -g2012 -o build/l1_cache_tb.vvp rtl/l1_cache.v tb/tb_l1_cache.v && vvp build/l1_cache_tb.vvp"