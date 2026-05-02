# Arcturus Dawn C4-G1-N28
### A Security-First, RISC-V Mobile SoC (Beta)

[![Status](https://img.shields.io/badge/Status-Beta-orange)](#)
[![Architecture](https://img.shields.io/badge/ISA-RISC--V_RV32I-blue)](#)
[![Process](https://img.shields.io/badge/Node-28nm-yellow)](#)
[![Cores](https://img.shields.io/badge/Cores-Quad--Core-green)](#)

<div align="center">
<table border="0">
  <tr>
    <td align="center">
      <img src="https://i.postimg.cc/yN9HcLVV/Chat-GPT-Image-May-2-2026-08-28-07-PM.png" alt="Arcturus Logo 1" width="250"/>
    </td>
    <td align="center">
      <img src="https://i.postimg.cc/26Dfwn6D/Chat-GPT-Image-May-2-2026-08-28-16-PM.png" alt="Arcturus Logo 2" width="250"/>
    </td>
  </tr>
</table>
</div>

**Arcturus Dawn** is a hardware-hardened, quad-core RISC-V processor cluster designed from scratch for security-critical mobile and embedded applications. It features deep integration of hardware security modules, including a Shadow Stack for Control Flow Integrity (CFI), Memory Tagging Extension (MTE), and a dedicated cryptographic accelerator suite (AES-128 + TRNG), all running on a 5-stage in-order pipeline optimized for 28nm technology.

---

## 📖 The Idea: Why Arcturus?

Modern processors are incredibly fast, but security is often an afterthought, patched in via software or bolted on as separate IPs. **Arcturus** started with a different question: *"What if the CPU itself refused to execute malicious code?"*

The concept was simple: **build a RISC-V core where security is woven into the silicon, not layered on top.** 

### The Core Philosophy
1.  **Trust Nothing:** The core treats every instruction as potentially hostile. It uses a hardware Shadow Stack to protect return addresses and MTE to validate memory pointers.
2.  **Zero-Overhead Security:** Security checks happen in the same cycle as execution. There is no "mode switch" penalty.
3.  **Open Architecture:** Based on the open-source RISC-V ISA, allowing full auditability of the hardware logic.
4.  **Mobile-First:** Optimized for 28nm to 5nm process nodes, targeting smartphones and always-on IoT devices where power efficiency and security are equally critical.

**"Dawn"** is the codename for the **beta phase** of the Arcturus family. Every beta prototype in this lineup carries the "Dawn" name, representing the early light of development before the final silicon is realized.

---

## 🚀 Quick Start: Beginner's Tutorial

Never touched a CPU design before? Follow these steps to simulate Arcturus Dawn on your computer.

### Step 1: Set Up Your Environment
You need a Verilog simulator. We use **Icarus Verilog** because it's lightweight and open-source.

#### On Windows (Recommended via WSL)
1.  Open **Windows PowerShell** as Administrator.
2.  Install WSL (Windows Subsystem for Linux):
    ```powershell
    wsl --install
    ```
3.  Restart your computer, then open the "Ubuntu" terminal from your Start Menu.
4.  Install Icarus Verilog:
    ```bash
    sudo apt update
    sudo apt install -y iverilog gtkwave
    ```

#### On Linux (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install -y iverilog gtkwave
```

### Step 2: Clone the Repository
Open your terminal and run:
```bash
git clone https://github.com/Kenneth-Cho-InfoSec/Arcturus-Dawn.git
cd Arcturus-Dawn
```

### Step 3: Run Your First Simulation
The SoC top-level testbench will run the 4-core cluster and halt when it sees the `ebreak` instruction.

```bash
iverilog -o soc_sim tb/tb_soc_top.v rtl/*.v
vvp soc_sim
```
**Expected Output:** You should see `INFO: SoC running, completing test` followed by a `PASS` message.

### Step 4: View the Waveforms (Visual Debugging)
Hardware design isn't just about text; it's about timing. The simulation generates a `.vcd` file that you can view in **GTKWave**.

1.  Run the simulation with VCD dumping enabled (already in our testbenches).
2.  Open the waveform:
    ```bash
    gtkwave build/soc_top.vcd
    ```
3.  In GTKWave:
    *   Expand `tb_soc_top` on the left tree.
    *   Select signals like `clk`, `debug_pc`, and `halted`.
    *   Click **"Append"** to see the clock toggling and the PC incrementing!

---

## 🛡️ Security Feature Deep Dive

How did we build these features into the hardware? Here is the technical breakdown.

### 1. Hardware Shadow Stack (Control Flow Integrity)
**Problem:** Return-Oriented Programming (ROP) attacks overwrite return addresses on the stack to hijack execution.
**Solution:** A dedicated hardware stack that only the CPU can access. Software cannot touch it.

**Implementation Details:**
*   **Push:** When the core decodes a `JAL` (Jump and Link) instruction, it automatically saves the return address (`PC + 4`) into the Shadow Stack.
*   **Pop & Verify:** When it sees a `JALR` with `rd=0` (which is the standard `RET` pattern), it pops the expected address from the Shadow Stack and compares it to the actual target.
*   **Violation:** If `Actual PC != Expected PC`, the `cfi_violation` signal asserts, and the core halts immediately.

**Verilog Snippet:**
```verilog
// Shadow Stack logic in cpu_core.v
cfi_push <= (if_id_valid && id_opcode == OP_JAL);
cfi_pop <= (id_ex_valid && id_ex_opcode == OP_JALR && id_ex_rd == 5'd0);
```

### 2. Memory Tagging Extension (MTE)
**Problem:** Buffer overflows and use-after-free vulnerabilities corrupt memory.
**Solution:** Every 16 bytes of memory gets a 4-bit "color" tag. Pointers carry a tag. If they don't match, the access is denied.

**Implementation Details:**
*   **Tag Table:** A 256-entry SRAM stores tags. Indexing is calculated by `Address / 16`.
*   **Write Access:** When the CPU writes data, the pointer's tag is saved alongside the data in the Tag Table.
*   **Read/Exec Access:** Before any memory access, the hardware compares the pointer tag with the stored tag.
*   **Granularity:** 16-byte alignment ensures low overhead while maintaining strong protection.

### 3. AES-128 Hardware Accelerator
**Problem:** Software encryption is slow and susceptible to timing side-channel attacks.
**Solution:** A dedicated datapath that performs AES encryption in 10 cycles.

**Implementation Details:**
*   **SubBytes:** Implemented using a mathematical Galois Field inversion rather than a lookup table (LUT), making it resistant to cache-based side-channel attacks.
*   **ShiftRows & MixColumns:** Hardwired permutations and matrix multiplications.
*   **Key Expansion:** Performed at the start of encryption to generate round keys.

### 4. True Random Number Generator (TRNG)
**Problem:** Pseudo-random number generators (PRNGs) can be predicted if the seed is known.
**Solution:** An LFSR (Linear Feedback Shift Register) combined with non-deterministic entropy injection.

**Implementation Details:**
*   We use a 32-bit LFSR with polynomial taps.
*   A free-running counter XORs into the LFSR state every 8 cycles to break deterministic patterns, ensuring high entropy output suitable for cryptographic keys.

---

## 🚧 Engineering Challenges & Lessons Learned

Building a CPU is not just about writing code; it's about managing complexity, timing, and the tools themselves.

### 1. The "Pipeline Stall" Nightmare
**Issue:** In the initial optimized core (`cpu_core_optimized.v`), the instruction fetch logic was gated behind too many conditions (`!id_ex_valid && !ex_mem_valid`). This caused the pipeline to starve, fetching only one instruction every few cycles.
**Fix:** We separated the fetch condition from the pipeline stall logic. The fetch unit now runs independently unless there is a genuine hazard (like a Load-Use conflict).

### 2. CFI Violation Timing Bug
**Issue:** The Shadow Stack was clearing the `cfi_violation` flag on the same clock cycle it was set, meaning the core never actually halted.
**Fix:** We changed the logic so that once `cfi_violation` is high, it remains latched until the `rst` signal is asserted, ensuring the core stays halted.

### 3. WSL Catastrophic Failures
**Issue:** During synthesis attempts, downloading massive EDA toolchains (500MB+) or running complex TCL scripts frequently caused the WSL2 virtual machine to crash with `Catastrophic failure: E_UNEXPECTED`.
**Fix:** We implemented a segmented download strategy and increased the WSL2 memory allocation in `.wslconfig` to prevent OOM (Out of Memory) kills.

### 4. Timing Analysis without OpenSTA
**Issue:** Open-source STA tools like OpenSTA are notoriously difficult to compile and configure without a commercial PDK.
**Fix:** We built a custom Python-based STA estimator (`synthesis/sta_parse.py`) that parses the NLDM (Non-Linear Delay Model) tables from the Nangate45 Liberty file. This allowed us to extract accurate per-cell delays and estimate the critical path (~3.8ns @ 28nm) with high confidence.

---

## 📊 Architecture & Synthesis Results

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

### Gate Count (Post-Synthesis via Yosys + ABC)
| Cell Type | Count | Function |
|-----------|-------|----------|
| **DFF_X1** | **491** | Pipeline Registers |
| **OAI21_X1** | 605 | Complex Logic |
| **MUX2_X1** | 487 | Forwarding / Selection |
| **NOR2_X1** | 455 | NOR Logic |
| **AOI21_X1** | 456 | AND-OR-Inverted |
| **NAND2_X1** | 394 | NAND Logic |
| **INV_X1** | 334 | Inversion |
| **Total** | **4,662** | **Logic Gates + FFs** |

### Timing Analysis
| Scenario | Critical Path | Max Frequency | Notes |
|----------|---------------|---------------|-------|
| **45nm (Nangate)** | ~5.4 ns | **~185 MHz** | Baseline synthesis |
| **28nm Scaling** | ~3.8 ns | **~264 MHz** | Estimated ×0.7 delay scaling |
| **28nm (7-Stage Pipe)** | ~3.2 ns | **~310 MHz** | With deeper pipeline optimization |

---

## 🏷️ Naming Convention

The Arcturus series follows a strict technical naming scheme to denote configuration, generation, and process node.

**Format:** `Arcturus Dawn C{Cores}-G{Generation}-N{Node}`

| Parameter | Example | Description |
|-----------|---------|-------------|
| **Series** | `Arcturus` | The family name. |
| **Codename** | `Dawn` | Permanent codename for all **Beta** prototypes. |
| **Cores** | `C4` | Number of active cores in the cluster. |
| **Gen** | `G1` | Architecture generation (Microarch revision). |
| **Node** | `N28` | Target process node (28nm, 12nm, 7nm, etc.). |

**Current Chip:** `Arcturus Dawn C4-G1-N28` (4 Cores, Gen 1, 28nm)

---

## 🗺️ Roadmap

The Arcturus family is committed to continuous hardening and scaling.

| Generation | Cores | Node | Key Focus | Status |
|:----------:|:-----:|:----:|:----------|:------:|
| **Gen 1** | **4** | **28nm** | **Security Foundation (CFI, MTE, AES)** | **🟢 Beta** |
| Gen 2 | 4 | 12nm | Performance / L3 Cache / Branch Prediction | ⚪ Planned |
| Gen 3 | 8 | 5nm | AI Tensor Units / Out-of-Order Execution | ⚪ Planned |
| Gen 4 | 16 | 3nm | Chiplet Interconnect / Server Class | ⚪ Planned |

---

## 📁 Directory Structure

```text
Arcturus-Dawn/
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
│   └── tb_cpu_optimized.v    # Optimized Core Test
├── synthesis/                # Synthesis Scripts & STA
│   ├── nangate45.lib         # Nangate45 Liberty File
│   ├── sta_estimate.py       # Python STA estimator
│   └── run_synth.sh          # Yosys Synthesis runner
├── programs/                 # RISC-V Hex programs for ROM
└── scripts/                  # PowerShell automation scripts
```

---

## 🧪 Detailed Simulation Commands

### Run Full SoC Test
```bash
wsl -d Ubuntu -- bash -lc "
iverilog -o tb_soc tb/tb_soc_top.v rtl/*.v && \
vvp tb_soc && \
gtkwave build/soc_top.vcd
"
```

### Run Security Module Tests
```bash
# Shadow Stack / CFI
wsl -d Ubuntu -- bash -lc "
iverilog -o tb_ss tb/tb_shadow_stack.v rtl/shadow_stack.v && vvp tb_ss
"

# MTE + Crypto
wsl -d Ubuntu -- bash -lc "
iverilog -o tb_sec tb/tb_security_full.v rtl/memory_tagging.v rtl/trng.v rtl/aes128.v && vvp tb_sec
"
```

### Run Synthesis (Yosys)
```bash
wsl -d Ubuntu -- bash -lc "
source ~/eda/oss-cad-suite/environment && \
cd . && \
yosys -p 'read_verilog -sv rtl/cpu_core_synth.v; hierarchy -top cpu_core; proc; flatten; techmap; dfflibmap -liberty synthesis/nangate45.lib; abc -liberty synthesis/nangate45.lib -D 500; stat; write_verilog build/cpu_core_netlist.v'
"
```

---

## 📜 License

**Arcturus Dawn** is released under the **MIT License**.

Copyright (c) 2026 Kenneth Cho (InfoSec)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
