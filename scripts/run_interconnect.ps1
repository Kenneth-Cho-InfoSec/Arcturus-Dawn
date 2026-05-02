$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$linuxRoot = "/mnt/c/Users/kenneth/Documents/riscv_cpu_verilog"
Write-Host "Running interconnect simulation..."

wsl -d Ubuntu -- bash -lc "cd '$linuxRoot' && mkdir -p build && iverilog -g2012 -o build/interconnect_tb.vvp rtl/soc_interconnect.v tb/tb_interconnect.v && vvp build/interconnect_tb.vvp"