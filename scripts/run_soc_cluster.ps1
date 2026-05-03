$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$linuxRoot = "/mnt/c/Users/kenneth/Documents/riscv_cpu_verilog"
Write-Host "Running 4-core cluster simulation..."

wsl -d Ubuntu -- bash -lc "cd '$linuxRoot' && mkdir -p build && iverilog -g2012 -o build/soc_cluster_tb.vvp rtl/cpu_core.v rtl/soc_cluster.v tb/tb_soc_cluster.v 2>&1 && vvp build/soc_cluster_tb.vvp 2>&1"