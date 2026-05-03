# RISC-V Mobile SoC Development Plan

## Executive Summary

This document defines an iterative development approach for evolving the existing RISC-V CPU cores (`secure_riscv_mcu.v` and `pipelined_cached_mmu_cpu.v`) into a full mobile SoC with strong cybersecurity features. The development follows an incremental-verification methodology where each stage must pass Verilator simulation before advancing.

---

## 1. System Architecture

### 1.1 SoC Block Diagram

```
+------------------------------------------------------------------+
|                         Mobile SoC                                |
+------------------------------------------------------------------+
|                                                                  |
|  +-------------+    +------------------------------------------+        |
|  | RISC-V CPU  |    |         Interconnect / NoC          |        |
|  |  Cluster   |<===>|                                  |        |
|  +-------------+    |  - AXI4/AHB crossbar        |        |
|        |            |  - Priority-based QoS        |        |
|  +-----+-----+      |  - Address isolation        |        |
|  | L1 I/D$ |      +----------+---------------+---------+        |
|  +---------+                 |                     |            |
|                            v                     v            |
|  +-------------+    +-------------+    +-------------+             |
|  | L2 Cache   |    |   GPU       |    |  Peripherals|             |
|  | Coherent  |<===>|  Core      |    |  - UART   |             |
|  +---------+   ||   +---------+    |  - SPI    |             |
|       |      ||        |           |  - I2C    |             |
|       v      ||        v           |  - GPIO   |             |
|  +---------+ ||   +---------+    |  - PWM    |             |
|  |  DDR     | ||   |  Display |    |  - Timer  |             |
|  |  Ctrl   |<---+|  Ctrl    |    |  - Crypto |             |
|  +---------+     +---------+    +-------------+             |
|                                                                  |
+------------------------------------------------------------------+
```

### 1.2 CPU Cluster

| Component | Specification |
|-----------|--------------|
| Architecture | RV32GC (IMAFC+Zicsr+Zifencei) |
| Cores | 4x RV32GC in cluster |
| Pipeline | 5-stage in-order with LSU |
| L1 I-Cache | 16KB 4-way set-assoc per core |
| L1 D-Cache | 16KB 4-way set-assoc per core |
| L2 Cache | 256KB 8-way shared |
| MMU | Sv32 page tables per core |
| Privilege | M/S/U modes |
| Frequency Target | 500MHz-1GHz (simulated) |

### 1.3 GPU Architecture

| Component | Specification |
|-----------|--------------|
| Type | Tile-based rendering engine |
| Shader Cores | 4x SIMT cores |
| VRAM | Shared with main DDR |
| API Support | OpenGL ES 2.0 subset via software |
| Display | Single MIPI-DSI output |

### 1.4 Memory Subsystem

| Component | Size | Organization |
|-----------|------|------------|
| L1 I$/D$ | 16KB each | 4-way, 64B line |
| L2 Cache | 256KB | 8-way, 64B line |
| DDR3L Ctrl | 32-bit @ 800MHz | 2-channel |
| SRAM | 64KB | Secure enclave |

### 1.5 Interconnect

| Feature | Implementation |
|---------|-------------|
| Protocol | AXI4-Lite for simplicity |
| Masters | 4x CPU, GPU, DMA |
| Slaves | L2, DDR, Peripherals |
| QoS | Round-robin with priority boost |
| Safety | Address range checking |

---

## 2. Iterative Development Workflow

### Iteration Overview

```
ITERATION 1: Extend Secure MCU → Pipelined Core (DONE)
ITERATION 2: Add Multi-Core Support
ITERATION 3: Add L1 Cache Controllers  
ITERATION 4: Integrate L2 Cache + Coherency
ITERATION 5: Add Bus Interconnect
ITERATION 6: Add Peripherals
ITERATION 7: Integrate Security Subsystem
ITERATION 8: Full SoC Integration
```

Each iteration follows:
1. Implement design changes in RTL
2. Write/update testbench
3. Run Verilator simulation
4. Verify expected outputs
5. Debug if failures occur
6. Only proceed when pass

---

## 3. Iteration Details

### ITERATION 1: Extend Secure MCU → Pipelined Core

**Status**: ✓ ALREADY COMPLETE in existing project

**Files Modified**:
- `rtl/secure_riscv_mcu.v` - Security-focused MCU (multi-cycle)
- `rtl/pipelined_cached_mmu_cpu.v` - Performance core with pipeline/cache/MMU

**Verification**:
```powershell
# Secure MCU
iverilog -o build/secure_cpu_tb.vvp -s tb_secure_mcu rtl/secure_riscv_mcu.v tb/tb_secure_mcu.v
vvp build/secure_cpu_tb.vvp

# Pipeline/Cache/MMU
iverilog -o build/pipelined_cached_mmu_tb.vvp -s tb_pipelined_cached_mmu rtl/pipelined_cached_mmu_cpu.v tb/tb_pipelined_cached_mmu.v
vvp build/pipelined_cached_mmu_tb.vvp
```

**Expected Output**:
```
PASS: secure MCU interrupt, CSR, privilege, PMP, trap, and containment checks passed
PASS: pipelined cached MMU CPU completed benchmark with >=3x modeled speedup
```

---

### ITERATION 2: Add Multi-Core Support

**Goal**: Extend single-core to 4-core cluster with basic coherency

**Design Changes**:
1. Clone `pipelined_cached_mmu_cpu.v` → `cpu_core.v`
2. Add `soc_cluster.v` with 4x instances
3. Add basic L1 cache tag/valid bits per core
4. Add inter-core interrupt (IPI) registers
5. Add core ID CSR (`mhartid` already present)

**RTL Files**:
```
rtl/
  cpu_core.v              # Renamed from pipelined_cached_mmu_cpu
  soc_cluster.v           # 4-core cluster wrapper
```

**Testbench**: `tb/tb_soc_cluster.v`
- Boot all 4 cores
- Verify each core has unique hartid
- Basic IPI: core 0 → core 1 interrupt
- Parallel execution of same program

**Verilator Command**:
```bash
verilator --cc --trace rtl/soc_cluster.v rtl/cpu_core.v
verilator --trace -f soc_cluster.fl rtl/tb/tb_soc_cluster.v
```

**Expected Output**:
```
PASS: 4-core cluster boot
PASS: IPI delivered
PASS: parallel execution
```

**Debugging if Failure**:
- Check `mhartid` uniqueness
- Verify IPI register wiring
- Check clock gating isolation

---

### ITERATION 3: Add L1 Cache Controllers

**Goal**: Full L1 I/D cache with tag arrays and miss logic

**Design Changes**:
1. Expand cache tags to full SRAM (not just valid bit)
2. Add L1 cache controller FSM:
   - Hit: single-cycle
   - Miss: request L2
   - Line fill: multi-cycle
3. Add cache-coherent protocol start
4. Add performance counters

**RTL Files**:
```
rtl/
  l1_cache_ctrl.v        # L1 controller FSM
  cache_tags.v          # Tag array SRAM
```

**Testbench**: `tb/tb_l1_cache.v`
- Write pattern, read back, verify hit/miss counts
- Cache flush/invalidation

**Verilator Command**:
```bash
verilator --trace -f soc_cluster.fl -f l1_cache.rtl rtl/tb/tb_l1_cache.v
```

**Expected Output**:
```
PASS: L1 cache hit/miss accounting
PASS: line fill on miss
```

---

### ITERATION 4: Integrate L2 Cache + Coherency

**Goal**: Shared L2 and basic MESI coherency

**Design Changes**:
1. Add `l2_cache.v`:
   - 256KB, 8-way set-assoc
   - 64B line
2. Add coherency FSM:
   - Observer pattern (simplified MESI)
   - Invalidate on upgrade
3. Connect L1 → L2 via interconnect

**Verilator Command**:
```bash
verilator --trace --cc rtl/l2_cache.v
```

**Expected Output**:
```
PASS: L2 miss → fetch
PASS: L2 hit
```

---

### ITERATION 5: Add Bus Interconnect

**Goal**: Connect CPU cluster, GPU, peripherals via AXI-like bus

**Design Changes**:
1. Add `soc_interconnect.v`:
   - 4 master ports (3 CPU, GPU)
   - 4 slave ports (L2, DDR, SRAM, APB)
   - Round-robin arbitration
2. Add address decode
3. Add basic QoS

**Verilator Command**:
```bash
verilator --trace -f soc_interconnect.rtl rtl/tb/tb_soc_interconnect.v
```

---

### ITERATION 6: Add Peripherals

**Goal**: UART, GPIO, Timer, SPI, I2C

**Design Changes**:
1. Add `peripheral_uart.v`:
   - 115200 baud
   - 8N1
2. Add `peripheral_gpio.v`:
   - 32-bit
3. Add `peripheral_timer.v`:
   - 32-bit counter
   - Compare interrupts
4. Add `peripheral_spi.v`, `peripheral_i2c.v`:
   - Basic host mode

**Verilator Command**:
```bash
verilator --trace rtl/peripheral_uart.v rtl/peripheral_gpio.v rtl/peripheral_timer.v \
    rtl/tb/tb_peripherals.v
```

---

### ITERATION 7: Integrate Security Subsystem

**Goal**: Secure boot, key storage, TEE, side-channel mitigation

**Design Changes**:

#### 7.1 Secure Boot / Root of Trust
```verilog
module secure_boot_rom (
    input        clk,
    input        rst,
    output reg  [31:0] boot_addr,
    output reg         boot_valid
);
    // First 32 instructions: HMAC-signed
    // If signature invalid: halt
    // If valid: jump to flash
```

#### 7.2 Hardware Key Storage (eFuse)
```verilog
module efuse_bank (
    input  wire [7:0] addr,
    input  wire        read,
    output wire [31:0] data,
    output wire        locked   // One-time programmable
);
    // 256-bit key storage
    // Read-only after lock
```

#### 7.3 Secure Enclave / TEE
```verilog
module secure_enclave (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] base_addr,
    input  wire [31:0] limit,
    input  wire        enable,
    // Isolated memory region
    // No DMA, no direct access
```

#### 7.4 MPU/MMU Isolation
- Enhanced PMP: 16 regions (expand from 8)
- Execute-only memory support
- MMU in S-mode with Sv32

#### 7.5 Side-Channel Mitigation
- Constant-time ALU (no data-dependent branching)
- Random wait states for timing leakage
- Cache partitioning for sensitive data

**Testbench Security Tests**:
```
1. Secure boot: verify signature check
2. Key storage: verify lock behavior
3. Enclave: verify isolation from masters
4. PMP: verify denied accesses trap
```

**Verilator Command**:
```bash
verilator --trace -Wall -f soc_security.rtl rtl/tb/tb_soc_security.v
```

---

### ITERATION 8: Full SoC Integration

**Goal**: Complete SoC with all components

**Design Changes**:
1. Integrate all modules in `soc_top.v`
2. Wire full interconnect
3. Add clock/reset distribution
4. Add power management

**RTL Files**:
```
rtl/
  soc_top.v            # Top-level SoC
  soc_packages.v      # Parameter definitions
```

**Full Testbench**: `tb/tb_soc_top.v`
- Boot sequence
- Multi-core startup
- DDR init
- Timer interrupt
- UART echo

**Verilator Command**:
```bash
verilator --trace -Wall --cc rtl/soc_top.v
make -C obj_dir -f Vtop.mk
./obj_dir/Vtop_tb
```

**Expected Output**:
```
PASS: SoC boot
PASS: 4-core execution
PASS: timer interrupt
PASS: peripheral access
```

---

## 4. Security Architecture

### 4.1 Secure Boot Flow

```
Power-On
    ↓
ROM Boot (secure boot_rom)
    ↓
Verify SHA-256 HMAC of flash[0..16KB]
    ↓
[Valid] → Jump to flash @ 0x1000_0000
[Invalid] → Halt + LED error
```

### 4.2 Memory Protection

| Region | Access | Mode |
|--------|--------|------|
| 0x0000_0000 - 0x0FFF_FFFF | RWX | Machine |
| 0x1000_0000 - 0x1FFF_FFFF | RX | All |
| 0x2000_0000 - 0x2FFF_FFFF | RW | Machine/Secure |
| 0x3000_0000 - 0xBFFF_FFFF | - | Reserved |
| 0xC000_0000 - 0xCFFF_FFFF | RW | Peripherals |

### 4.3 Hardware Security Features

| Feature | Implementation |
|---------|--------------|
| Root of Trust | eFuse-based identity |
| Secure Enclave | Isolated 64KB SRAM |
| Key Storage | 256-bit OTP eFuse |
| Physical Attacks | Mesh/grid sensors |
| Side-Channel | Constant-time ops |

---

## 5. Physical Considerations

### 5.1 Frequency Feasibility

| Pipeline Stage | Target (RTL) | Synthesized (28nm) | Comments |
|--------------|--------------|-------------------|----------|
| Single-cycle | 100-200MHz | ~50-80MHz | Conservative |
| 5-stage | 400-600MHz | ~200-400MHz | With optimization |
| 5-stage + L1 | 300-500MHz | ~150-300MHz | Cache adds ~20% delay |

**Realistic 2GHz Goal**:
- Requires:
  - 10+ stage pipeline
  - Synthesis to 7nm (not 28nm)
  - Careful timing closure
  - Clock tree optimization
- **Assessment**: Achievable in advanced process, not in first iteration

### 5.2 Power Constraints (Mobile)

| Component | Estimate |
|-----------|---------|
| CPU Cluster (4 cores) | 200-500mW @ 1GHz |
| GPU | 100-300mW |
| L2 + Interconnect | 50-150mW |
| Peripherals + PMU | 50mW |
| **Total** | **400-1000mW** |

### 5.3 Fabrication

| Process | Feasibility |
|---------|-----------|
| 180nm | Easy (DIY, MOSIS) |
| 65nm | Moderate (MPW shuttle) |
| 28nm | Hard (tapeout only) |
| 7nm | Not practical (research) |

---

## 6. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Timing closure at >200MHz | High | Reduce frequency, add pipeline stages |
| Coherency bugs | High | Add assertions, formal verification |
| Security vulnerabilities | Medium | Security test suite |
| Simulation vs. synthesis gap | High | Synthesis early |
| Peripheral integration | Low | Iterative testing |

---

## 7. Development Roadmap

### Summary Timeline

```
Phase 1: Single Core (COMPLETE)
  ✓ Secure MCU
  ✓ Pipelined CPU

Phase 2: Multi-Core (TWO WEEKS)
  - CPU cluster
  - Basic coherency

Phase 3: Caches (TWO WEEKS)
  - L1 controller
  - L2 cache

Phase 4: Interconnect + Peripherals (TWO WEEKS)
  - AXI-like bus
  - UART, GPIO, Timer

Phase 5: Security (TWO WEEKS)
  - Secure boot
  - Key storage
  - TEE

Phase 6: Full SoC (ONE WEEK)
  - Integration
  - Validation
```

### Total Estimated Time: 9-10 weeks

---

## 8. Verilator Validation Steps

### Base Commands

```bash
# Compile Verilog to C++
verilator --cc --trace rtl/design.v

# Build simulation
make -C obj_dir -f Vdesign.mk

# Run testbench
./obj_dir/Vdesign_tb

# View waveforms
gtkwave build/design.vcd &
```

### Trace Control

```bash
# Trace with 1ns precision
verilator --trace --trace-underscore -g ...

# Waveform size limit
verilator --trace-limit 10000 ...
```

### Assertions

```verilog
always @(posedge clk) begin
    if (reset && |state_error)
        $fatal(1, "State machine error");
end
```

---

## 9. Extensions for Mobile Features

### GPU Integration

For a mobile SoC, GPU is essential. Two approaches:

1. **Custom Minimal GPU**:
   - Tile-based renderer
   - Software shader execution on RISC-V
   - Framebuffer in DDR
   - Minimal 3D via fixed-function pipeline

2. **External GPU**:
   - Design AXI host interface
   - Use open-source GPU (Mali-T760 with license or Vivante)
   - This is more practical for first tapeout

### Recommendation: Design AXI interface first, integrate open-source GPU later

---

## 10. Output Summary

### Deliverables

| Deliverable | Status | Notes |
|-----------|--------|-------|
| System architecture | ✓ Complete | This document |
| RTL modules | In Progress | CPU cluster |
| Verilator configs | Pending | Per iteration |
| Testbench suite | Pending | Security tests |
| Security subsystem | Pending | TBD |

### Iteration Gates

Each iteration MUST pass:
1. Verilator simulation
2. Expected output match
3. Debug failures before proceeding

No waterfall: no big-bang integration.