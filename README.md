# Arcturus Dawn C4-G1-N28
### A Security-First, RISC-V Mobile SoC (Beta)

[![Status](https://img.shields.io/badge/Status-Beta-orange)](#)
[![Architecture](https://img.shields.io/badge/ISA-RISC--V_RV32I-blue)](#)
[![Process](https://img.shields.io/badge/Node-28nm-yellow)](#)
[![Cores](https://img.shields.io/badge/Cores-Quad--Core-green)](#)

**Arcturus Dawn** is the Gen 1 prototype of the **Arcturus Mobile SoC** family. It is a hardware-hardened, quad-core RISC-V processor cluster designed specifically for security-critical mobile and embedded applications. It features deep integration of hardware security modules—including a Shadow Stack for Control Flow Integrity (CFI), Memory Tagging Extension (MTE), and a dedicated cryptographic accelerator suite (AES-128 + TRNG)—all running on a 5-stage in-order pipeline optimized for 28nm technology.

---

## 🚀 Key Features

### 🛡️ Hardware-Enforced Security
*   **Shadow Stack & CFI:** A dedicated 16-entry hardware stack protects return addresses against ROP/JOP attacks. The core automatically pushes on `JAL` and validates on `JALR` (ret), halting on violation.
*   **Memory Tagging Extension (MTE):** 4-bit tags per 16B granule provide spatial and temporal memory safety. Access checks are performed on every load/store in hardware.
*   **Secure Boot & TEE:** Integrated Secure Boot ROM verifies image integrity via hash comparison. An eFuse bank stores cryptographic keys, accessible only by the Trusted Execution Environment (TEE).
*   **Cryptographic Accelerators:**
    *   **AES-128:** 10-round hardware encryption engine.
    *   **TRNG:** 32-bit LFSR-based True Random Number Generator with entropy injection.

### ⚡ Performance Architecture
*   **Quad-Core Cluster:** Four RV32I cores operating in a shared-memory SMP configuration with L1/L2 cache coherence.
*   **5-Stage Pipeline:** IF → ID → EX → MEM → WB with full bypass/forwarding logic.
*   **Branch Target Buffer (BTB):** 8-entry BTB reduces branch penalties in the optimized core variant.
*   **L1/L2 Cache Hierarchy:** Direct-mapped L1 (I/D) + Shared L2 with MESI-like coherency protocol.

---

## 🏗️ Architecture Overview

### SoC Block Diagram
```text
+-----------------------------------------------------------------------+
|                        Arcturus Dawn C4-G1-N28                        |
|                                                                       |
|   +----------+     +---------------------------------------------+     |
|   |   L2     |<--->|          AXI-like Crossbar (4-Master)       |     |
|   |  Cache   |     +---+---+---+----------------------------+----+     |
|   +----------+     |   |   |   |                            |    |     |
|                    |   |   |   |                            |    |     |
|   +-------------+  |   |   |   |   +-------------+          |    |     |
|   | L1 I-Cache  |<--+   |   |   +-->| Core 1      |          |    |     |
|   +-------------+      |   |       +-------------+          |    |     |
|   +-------------+      |   |                                |    |     |
|   | L1 D-Cache  |<-----+   +--------------------------------+    |     |
|   +-------------+      |   |                                |    |     |
|                        |   |                                |    |     |
|   +-------------+      |   |   +-------------+              |    |     |
|   | Core 0      |<-----+   +-->| Core 2      |              |    |     |
|   | (w/ Sec)    |          |   +-------------+              |    |     |
|   +-------------+          |                                |    |     |
|                            |   +-------------+              |    |     |
|                            +-->| Core 3      |              |    |     |
|                                +-------------+              |    |     |
|                                                               |     |
|   +---------------------------------------------------------+ |     |
|   |               Security Subsystem                        | |     |
|   |  [ Shadow Stack ] [ MTE Controller ] [ AES-128 ] [TRNG] | |     |
|   +---------------------------------------------------------+ |     |
|                                                               |     |
|   +---------------------------------------------------------+ |     |
|   |               Peripherals (AHB/APB)                     | |     |
|   |  [ UART ] [ GPIO ] [ Timer ] [ Secure eFuse ]           | |     |
|   +---------------------------------------------------------+ |     |
+---------------------------------------------------------------+-----+
```

### Core Microarchitecture
Each `cpu_core` implements the RV32I base integer instruction set with the following stages:
1.  **Instruction Fetch (IF):** PC generation, BTB lookup, instruction memory read.
2.  **Instruction Decode (ID):** Register file read, immediate generation, hazard detection (Load-Use).
3.  **Execute (EX):** ALU operations (ADD, SUB, Logic, Shift, Compare), Branch/Jump resolution.
4.  **Memory (MEM):** Data memory access (LW, SB, SH, SW), store data write.
5.  **Write Back (WB):** Register file write-back.

### Pipeline Hazard Handling
*   **Structural Hazards:** Resolved via separate I/D cache ports and register file write-port arbitration.
*   **Data Hazards:** Resolved via EX/MEM and MEM/WB forwarding paths. Load-Use stalls insert 1 bubble.
*   **Control Hazards:** Static predict-not-taken for branches. BTB provides dynamic prediction in optimized cores.

---

## 🔐 Security Modules Detail

### 1. Shadow Stack (CFI)
*   **Module:** `shadow_stack.v`
*   **Function:** Maintains a hardware-only copy of return addresses.
*   **Mechanism:**
    *   `JAL` / `CALL`: Pushes `PC+4` to Shadow Stack.
    *   `JALR` (with `rd=0`, i.e., `RET`): Pops stack and compares `PC` against expected return address.
    *   **Violation:** If `PC != Expected`, the `cfi_violation` signal asserts, immediately halting the core to prevent exploit continuation.
*   **Capacity:** 16 entries (configurable). Includes overflow/underflow protection.

### 2. Memory Tagging (MTE)
*   **Module:** `memory_tagging.v`
*   **Function:** Validates pointer integrity against stored memory tags.
*   **Granularity:** 16 Bytes per tag.
*   **Mechanism:**
    *   **Write:** Pointer tag is written to the Tag Table alongside data.
    *   **Read/Access:** Hardware compares pointer tag against stored tag.
    *   **Violation:** Mismatch triggers `tag_violation`.

### 3. Cryptographic Accelerator
*   **AES-128:** Hardware implementation of NIST AES (Rijndael). Supports ECB mode. Latency is 11 cycles per block.
*   **TRNG:** Linear Feedback Shift Register (LFSR) with non-deterministic entropy injection from a free-running counter.

---

## 📊 Synthesis & Timing Analysis

### Toolchain
*   **Synthesis:** Yosys (0.41) + ABC
*   **PDK/Library:** Nangate45 (45nm Open Cell Library)
*   **Analysis:** Liberty (.lib) NLDM table parsing + Custom STA Estimator

### Gate Count (Post-Synthesis)
| Cell Type | Count | Function |
|-----------|-------|----------|
| **DFF_X1** | **491** | Flip-flops (Pipeline registers) |
| **OAI21_X1** | 605 | Complex logic (Inverted-OR-AND) |
| **MUX2_X1** | 487 | Forwarding / Selection logic |
| **NOR2_X1** | 455 | NOR logic |
| **AOI21_X1** | 456 | Complex logic (AND-OR-Inverted) |
| **NAND2_X1** | 394 | NAND logic |
| **INV_X1** | 334 | Inversion |
| **Total** | **4,662** | **Logic Gates + FFs** |

### Timing Results (Critical Path)
The critical path is dominated by the 32-bit ALU adder and branch comparison logic in the EX stage.

| Scenario | Critical Path | Max Frequency | Notes |
|----------|---------------|---------------|-------|
| **45nm (Nangate)** | ~5.4 ns | **~185 MHz** | Baseline synthesis |
| **28nm Scaling** | ~3.8 ns | **~264 MHz** | Estimated ×0.7 delay scaling |
| **28nm (7-Stage Pipe)** | ~3.2 ns | **~310 MHz** | With deeper pipeline optimization |
| **7nm (Projected)** | ~1.5 ns | **~660+ MHz** | Requires advanced node & P&R |

---

## 📁 Directory Structure

```text
riscv_cpu_verilog/
├── rtl/                      # Verilog Source Code
│   ├── cpu_core.v            # Main RISC-V Core (RV32I) with Shadow Stack
│   ├── cpu_core_synth.v      # Synthesis-friendly version (external memory I/F)
│   ├── cpu_core_optimized.v  # Variant with BTB and hazard optimizations
│   ├── shadow_stack.v        # Hardware Shadow Stack implementation
│   ├── memory_tagging.v      # MTE controller
│   ├── aes128.v              # AES-128 Encryption Engine
│   ├── trng.v                # True Random Number Generator
│   ├── soc_cluster.v         # 4-Core Cluster wrapper
│   ├── soc_interconnect.v    # AXI-like Crossbar interconnect
│   ├── l1_cache.v            # Direct-mapped L1 Cache (Split I/D)
│   ├── l2_cache.v            # Shared L2 Cache (Coherent)
│   ├── peripherals.v         # UART, GPIO, Timer, eFuse
│   ├── security.v            # Secure Boot & TEE wrapper
│   └── soc_top.v             # Top-level SoC integration
├── tb/                       # Testbenches
│   ├── tb_soc_top.v          # Full SoC Integration Test
│   ├── tb_shadow_stack.v     # CFI Verification
│   ├── tb_security_full.v    # MTE + AES + TRNG Verification
│   └── ...
├── synthesis/                # Synthesis Scripts & STA
│   ├── nangate45.lib         # Nangate45 Liberty File
│   ├── sta_estimate.py       # Python STA estimator
│   └── run_synth.sh          # Yosys Synthesis runner
└── build/                    # Generated Netlists & VCDs (Git Ignored)
```

---

## 🧪 Simulation & Verification

### Prerequisites
*   **OS:** Windows (WSL2) or Linux
*   **Tools:** Icarus Verilog (`iverilog`), GTKWave

### Run Full SoC Test
```bash
# Using WSL (Windows Subsystem for Linux)
wsl -d Ubuntu -- bash -lc "
cd /mnt/c/Users/kenneth/Documents/riscv_cpu_verilog && \
iverilog -o tb_soc tb/tb_soc_top.v rtl/*.v && \
vvp tb_soc && \
gtkwave build/soc_top.vcd
"
```

### Run Security Module Tests
```bash
# Shadow Stack / CFI
wsl -d Ubuntu -- bash -lc "
iverilog -o tb_ss tb/tb_shadow_stack.v rtl/shadow_stack.v && \
vvp tb_ss
"

# MTE + Crypto
wsl -d Ubuntu -- bash -lc "
iverilog -o tb_sec tb/tb_security_full.v rtl/memory_tagging.v rtl/trng.v rtl/aes128.v && \
vvp tb_sec
"
```

### Run Synthesis (Yosys)
```bash
wsl -d Ubuntu -- bash -lc "
source ~/eda/oss-cad-suite/environment && \
cd /mnt/c/Users/kenneth/Documents/riscv_cpu_verilog && \
yosys -p 'read_verilog -sv rtl/cpu_core_synth.v; hierarchy -top cpu_core; proc; flatten; techmap; dfflibmap -liberty synthesis/nangate45.lib; abc -liberty synthesis/nangate45.lib -D 500; stat; write_verilog build/cpu_core_netlist.v'
"
```

---

## 🗺️ Roadmap

The Arcturus series follows a celestial naming convention reflecting increasing capability and "light" (performance).

| Generation | Codename | Cores | Node | Key Focus | Status |
|:----------:|:--------:|:-----:|:----:|:----------|:------:|
| **Gen 1** | **Dawn** | **4** | **28nm** | **Security Foundation** | **🟢 Beta** |
| Gen 2 | Daybreak | 4+ | 12nm | Performance / L3 Cache | ⚪ Planned |
| Gen 3 | Zenith | 8 | 5nm | AI Tensor Units / ML | ⚪ Planned |
| Gen 4 | Apex | 16 | 3nm | Chiplet / Server Class | ⚪ Planned |

---

## 📜 License

**Arcturus Dawn** is released under the **MIT License**.

Copyright (c) 2026 Kenneth Cho (InfoSec)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
