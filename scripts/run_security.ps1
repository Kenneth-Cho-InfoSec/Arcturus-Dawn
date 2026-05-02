$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$linuxRoot = "/mnt/c/Users/kenneth/Documents/riscv_cpu_verilog"
Write-Host "Running security subsystem simulation..."

wsl -d Ubuntu -- bash -lc "cd '$linuxRoot' && mkdir -p build && iverilog -g2012 -o build/security_tb.vvp rtl/security.v tb/tb_security.v && vvp build/security_tb.vvp"