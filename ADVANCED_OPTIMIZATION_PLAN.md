# Arcturus Dawn - Advanced Optimization Plan
## Boosting Performance Without Node Shrink

---

## Overview

This document outlines architectural improvements to achieve **400-500 MHz** and **2x+ IPC** without shrinking from 28nm. Based on latest RISC-V research (2025), these optimizations are proven to deliver significant gains.

**Reference**: CVA6S+ achieved 43.5% IPC gain with 9% area overhead using similar techniques.

---

## Priority Improvements

### Phase A: High-Impact, Low-Area (Immediate)

#### A1. Enhanced Branch Prediction (2-Level BTB)
```verilog
// Add to IF stage - Two-level branch predictor
localparam BTB_L0_SIZE = 16;    // Fully associative
localparam BTB_L1_SIZE = 4096;  // Set-associative
localparam BHT_ENTRIES = 128;   // 3-bit history
localparam RAS_DEPTH = 12;      // Return stack

reg [31:0] btb_l0_tag   [0:15];
reg [31:0] btb_l0_target[0:15];
reg        btb_l0_valid [0:15];

reg [31:0] btb_l1_tag   [0:1023][0:3];
reg [31:0] btb_l1_target[0:1023][0:3];
reg        btb_l1_valid [0:1023][0:3];
reg [2:0]  btb_l1_counter[0:1023][0:3];  // 2-bit saturating

reg [31:0] ras_stack [0:11];
reg [3:0]  ras_top;
```

**Expected**: 30-40% branch misprediction reduction

#### A2. Return Address Stack (RAS)
```verilog
// Dedicated stack for JAL/JALR
reg [31:0] ras [0:11];
reg [3:0]  ras_ptr;

always @(posedge clk) begin
    if (id_opcode == OP_JAL) begin
        ras[ras_ptr] <= id_pc + 4;
        ras_ptr <= ras_ptr + 1;
    end else if (id_opcode == OP_JALR && id_rd == 5'd0) begin
        ras_ptr <= ras_ptr - 1;
    end
end
```

**Expected**: 90%+ return prediction accuracy

#### A3. Loop Buffer
```verilog
// Small loop detection and caching
reg [31:0] loop_buffer [0:15];
reg [4:0]  loop_buffer_start;
reg [4:0]  loop_buffer_end;
reg        loop_buffer_valid;
reg [3:0]  loop_count;

always @(posedge clk) begin
    if (if_valid && (if_pc == loop_buffer_start) && loop_buffer_valid) begin
        // Feed from loop buffer directly
    end
end
```

**Expected**: Zero fetch cycles for small loops

---

### Phase B: Medium-Area, High-Performance

#### B1. Superscalar / Dual-Issue

**Architecture**:
```
        ┌─────────────┐
   ────▶│  Fetch (2) │────┐
        └─────────────┘     │
                            ▼
        ┌─────────────┐  ┌─────────────┐
   ────▶│  Decode (2) │──▶│ Issue Queue │
        └─────────────┘  └─────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
            ┌─────────────┐           ┌─────────────┐
            │    ALU 1    │           │    ALU 2    │
            └─────────────┘           └─────────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                           ┌─────────────┐
                           │  Register   │
                           │   Writeback │
                           └─────────────┘
```

**Changes needed**:
1. Duplicate fetch/decode logic
2. Add issue queue (2-entry FIFO)
3. Add second ALU
4. Extend register file ports (2 read + 2 write)
5. Add scoreboard for hazard checking

**Expected**: +43% IPC, 9% area increase (CVA6S+ results)

#### B2. Register Renaming

```verilog
// Physical register file (PRF) > Architectural
localparam ARCH_REGS = 32;
localparam PHY_REGS = 64;

reg [31:0] phy_reg_file [0:63];
reg [5:0]  arch_to_phy [0:31];  // Mapping table
reg [5:0]  free_list [0:31];
reg [5:0]  free_ptr;

reg [5:0]  rob_head;
reg [5:0]  rob_tail;
reg [31:0] rob_pc [0:31];
reg        rob_ready [0:31];
```

**Expected**: Eliminates WAW hazards, enables better OoO

#### B3. Non-Blocking Cache (MSHR)

```verilog
// Multiple outstanding misses
localparam MSHR_ENTRIES = 8;

reg [31:0] mshr_addr   [0:7];
reg [4:0]  mshr_rsp_id [0:7];
reg        mshr_valid  [0:7];

// When L1 miss occurs, allocate MSHR entry
// Continue processing other loads while waiting
```

**Expected**: 74% memory bandwidth improvement

---

### Phase C: Advanced (Research-Grade)

#### C1. Out-of-Order Execution (OoO)

**Components needed**:
- Reorder Buffer (ROB): 64 entries
- Reservation Stations: 16 entries per execution unit
- Physical Register File: 64 registers
- Load/Store Queue (LSQ): 16 entries
- Common Data Bus (CDB): Broadcast results

**Architecture**:
```
                    ┌───────────────┐
                    │   Fetch/Dec  │
                    └───────────────┘
                            │
                    ┌───────────────┐
          ┌───────▶│  Dispatch/RF │
          │        └───────────────┘
          │                │
    ┌─────┴─────┐         │
    ▼           ▼         ▼
┌───────┐ ┌───────┐ ┌───────────┐
│ ALU RS│ │ MEM RS│ │ BRANCH RS │
└───────┘ └───────┘ └───────────┘
    │           │          │
    └─────┬─────┴──────────┘
          │         CDB (Result Broadcast)
          ▼
    ┌───────────────┐
    │      ROB      │◀── Track in-flight instructions
    └───────────────┘
          │
          ▼
    ┌───────────────┐
    │   Commit      │
    │  (In Order)   │
    └───────────────┘
```

**Expected**: +119% IPC over in-order (C910 benchmark)
**Risk**: High area (75%+ over scalar)

#### C2. Hardware Prefetcher

```verilog
// Stream prefetcher
reg [31:0] stream_base [0:3];
reg [31:0] stream_stride [0:3];
reg [1:0]  stream_confidence [0:3];

// Stride detection
always @(posedge clk) begin
    if (mem_valid) begin
        if (last_addr + stride == current_addr)
            stream_confidence <= stream_confidence + 1;
    end
end
```

**Expected**: 10-20% memory stall reduction

#### C3. RISC-V Vector Extension (RVV 1.0)

**Add**:
- 32x 256-bit vector registers (v0-v31)
- Vector ALU instructions (vadd, vmul, etc.)
- Vector load/store units
- Vector length register (vl), vector mask (v0)

**Expected**: 10-16x speedup on vectorizable workloads

---

## Summary Table

| Optimization | IPC Gain | Area Overhead | Complexity |
|--------------|----------|---------------|------------|
| Enhanced BTB/RAS | 5-10% | <2% | Low |
| Loop Buffer | 3-5% | <1% | Low |
| **Dual-Issue (Superscalar)** | **+43%** | **9%** | Medium |
| MSHR/Non-blocking Cache | +15% | 3% | Medium |
| Register Renaming | +10% | 8% | Medium |
| **Out-of-Order (OoO)** | **+119%** | **75%** | High |
| Hardware Prefetcher | +10% | 2% | Medium |
| RVV Vector | 10-16x | 25% | High |

---

## Target Specifications

### Current (Baseline)
- Frequency: 264 MHz @ 28nm
- IPC: 0.7
- Pipeline: 5-stage in-order
- Cores: 4 (quad-core)

### Phase A Target
- Frequency: 300 MHz
- IPC: 0.85
- Area: +3%

### Phase B Target
- Frequency: 350 MHz
- IPC: 1.0 (1.43x baseline)
- Area: +15%

### Phase C Target
- Frequency: 400-500 MHz
- IPC: 1.5-2.0 (2-3x baseline)
- Area: +80-100%

---

## Implementation Roadmap

```
Month 1-2:  Phase A - Branch prediction + RAS + Loop buffer
Month 3-4:  Phase B1 - Superscalar dual-issue
Month 5-6:  Phase B2 - Register renaming + MSHR
Month 7-8:  Phase C1 - Out-of-Order core (research)
Month 9-10: Phase C2 - Prefetcher integration
Month 11-12: Phase C3 - RVV vector extension
```

---

## Key References

1. **CVA6S+** (2025): 43.5% IPC gain, 9% area, superscalar in-order
2. **RSD** (GitHub): RISC-V OoO superscalar, FPGA-optimized
3. **C910** (Alibaba): 119% IPC over scalar, 12-stage OoO
4. **LLVM RISC-V** (2025): 15-16% improvement via compiler optimization

---

## Compiler Co-Optimization

### LLVM Scheduler Model
```c
// Add to LLVM/llvm/lib/Target/RISCV/RISCVSchedX60.td
def X60Pipeline : ProcResource<4>;
def X60ALU1 : ProcResource<1>;
def X60ALU2 : ProcResource<1>;
def X60Mul : ProcResource<1>;
def X60Div : ProcResource<1>;
def X60Load : ProcResource<1>;
def X60Store : ProcResource<1>;
```

### IPRA (Inter-Procedural Register Allocation)
- Reduces callee-saved register spills
- 3% average improvement

---

*Document generated: Arcturus Dawn Advanced Optimization*
*Based on 2025 RISC-V research (CVA6S+, RSD, LLVM improvements)*