# Arcturus Dawn - Performance Improvement Plan

## Overview
Plan to boost frequency from 264MHz to 400MHz+ and improve IPC through architectural enhancements.

---

## Phase 1: Pipeline Optimization (Week 1-2)

### 1.1 Extend Pipeline to 7-Stage

**Current**: IF → ID → EX → MEM → WB (5 stages)

**Target**: IF → ID → EX1 → EX2 → MEM → WB (7 stages)

```
New Pipeline:
┌─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│  IF │ ID  │EX1  │EX2  │ MEM │ WB  │
└─────┴─────┴─────┴─────┴─────┴─────┴─────┘
       │     │     │     │
       │     ALU   │     L/S
       │   (split) │
```

**Changes to `rtl/cpu_core.v`**:
1. Split `id_ex_alu` computation across EX1/EX2
2. Add pipeline registers: `ex1_ex2_valid`, `ex1_ex2_instr`, etc.
3. Update hazard detection for new stages

**Files to modify**:
- `rtl/cpu_core.v` - Main pipeline split

**Expected gain**: 264MHz → 310MHz

---

## Phase 2: Branch Prediction Enhancement (Week 2-3)

### 2.1 Expand BTB (Branch Target Buffer)

**Current**: 8-entry direct-mapped

**Target**: 32-entry 2-way set-associative BTB

**Implementation**:
```verilog
// In cpu_core.v - IF stage
reg [31:0] btb_tag    [0:31];  // Branch PC tag
reg [31:0] btb_target [0:31];  // Target PC
reg        btb_valid  [0:31];  // Valid bit
reg [1:0]  btb_count [0:31];  // 2-bit saturating counter

wire [4:0] btb_idx = if_id_pc[6:2];  // 32 entries
wire       btb_hit = btb_valid[btb_idx] && (btb_tag[btb_idx] == if_id_pc[31:7]);
```

### 2.2 Add Branch History Register (BHR)

```verilog
reg [7:0] global_history;  // 8-bit global history

// Update on branch resolve
always @(posedge clk) begin
    if (ex_take_branch) global_history <= {global_history[6:0], 1'b1};
    else if (!ex_take_branch && is_branch) global_history <= {global_history[6:0], 1'b0};
end
```

**Files to modify**:
- `rtl/cpu_core.v` - Add BTB/BHR in IF stage

**Expected gain**: 15-20% IPC improvement on branch-heavy code

---

## Phase 3: Cache Hierarchy Upgrade (Week 3-4)

### 3.1 L1 Cache: Direct-Mapped → 4-Way Set-Associative

**Current**: 512 lines × 1 way (direct-mapped)
**Target**: 128 lines × 4 ways × 32 bytes/line = 16KB

```verilog
// New l1_cache.v structure
localparam NUM_WAYS = 4;
localparam NUM_SETS = 128;
localparam LINE_SIZE = 32;

reg [31:0] cache_data [0:NUM_SETS-1][0:NUM_WAYS-1][0:LINE_SIZE/4-1];
reg [31:0] cache_tag  [0:NUM_SETS-1][0:NUM_WAYS-1];
reg        cache_valid[0:NUM_SETS-1][0:NUM_WAYS-1];
reg        cache_dirty [0:NUM_SETS-1][0:NUM_WAYS-1];

wire [6:0] set_idx = addr[9:3];   // 128 sets
wire [1:0] way_sel;                // LRU replacement
```

### 3.2 Add Write Buffer

```verilog
reg [31:0] write_buffer_data [0:3];
reg [31:0] write_buffer_addr [0:3];
reg        write_buffer_valid [0:3];
reg [1:0]  wb_head, wb_tail;

// Drain to L2 when idle
```

### 3.3 L2 Cache Enhancement

- Add MSHR (Miss Status Holding Registers) for non-blocking
- Increase from 64KB to 256KB
- 8-way set-associative

**Files to modify**:
- `rtl/l1_cache.v` - Complete rewrite
- `rtl/l2_cache.v` - Add MSHR

**Expected gain**: 20-30% memory access performance

---

## Phase 4: ALU Pipelining (Week 4)

### 4.1 Split Multi-cycle Operations

**Current**: All ALU ops in 1 cycle

**Target**:
- Add/Sub/Logic/Shift: 1 cycle
- Multiply: 2 cycles (EX1 → EX2)
- Divide: 16 cycles (iterative)

```verilog
// EX1: Start multiply
reg mul_start;
reg [31:0] mul_a, mul_b;
reg [63:0] mul_result;

always @(posedge clk) begin
    if (mul_start) begin
        mul_result <= mul_a * mul_b;
        ex1_ex2_valid <= 1'b0;  // Stall pipeline
    end
end

// EX2: Complete multiply
always @(posedge clk) begin
    if (mul_result_ready) begin
        ex2_alu <= mul_result[31:0];
    end
end
```

**Files to modify**:
- `rtl/cpu_core.v` - ALU state machine

**Expected gain**: 2-3x faster on integer multiply/divide

---

## Phase 5: Hazard Resolution (Week 5)

### 5.1 Load-Use Forwarding (1-cycle bypass)

**Current**: Pipeline stalls on load-use hazard

**Target**: Forward from MEM to EX stage

```verilog
// Forwarding logic - add in EX stage
wire [31:0] fwd_from_mem = (ex_mem_valid && ex_mem_mem_read &&
                             ex_mem_rd == id_ex_rs1) ? ex_mem_alu :
                            fwd_rs1_a;

// Remove load-use stall condition
wire load_use_hazard = 1'b0;  // Now handled by forwarding
```

### 5.2 Register File Dual-Port

```verilog
// Two read ports, one write port
reg [31:0] regs [0:31];

// Read port 1 (combinational)
wire [31:0] rs1_data = (rs1_addr == 0) ? 0 : regs[rs1_addr];

// Read port 2 (combinational)
wire [31:0] rs2_data = (rs2_addr == 0) ? 0 : regs[rs2_addr];

// Write port (sequential)
always @(posedge clk) begin
    if (reg_write_en && rd_addr != 0)
        regs[rd_addr] <= rd_data;
end
```

**Files to modify**:
- `rtl/cpu_core.v` - Forwarding logic, register file

**Expected gain**: Eliminate most pipeline stalls

---

## Phase 6: Security Module Pipelining (Week 5-6)

### 6.1 Async MTE Comparison

Move tag comparison to separate cycle:

```verilog
// EX1: Start MTE check (non-blocking)
reg mte_check_pending;
reg [31:0] mte_check_addr;
reg [3:0]  mte_check_tag;

always @(posedge clk) begin
    if (mem_access && mte_enable) begin
        mte_check_pending <= 1'b1;
        mte_check_addr <= mem_addr;
        mte_check_tag <= ptr_tag;
    end
end

// MEM: Capture MTE result (1 cycle later)
wire mte_violation_async = mte_check_pending && (stored_tag != mte_check_tag);
```

### 6.2 Pipeline Shadow Stack

Move CFI check to EX/MEM boundary:

```verilog
// Decode stage: Identify RET (JALR x0, rs1)
wire is_ret = (id_opcode == OP_JALR) && (id_rd == 5'd0);

// MEM stage: Verify return address
reg [31:0] shadow_pop_addr;

always @(posedge clk) begin
    if (cfi_pop && !cfi_violation_latched) begin
        shadow_pop_addr <= ss_pop_value;
    end
end
```

**Files to modify**:
- `rtl/memory_tagging.v` - Async interface
- `rtl/shadow_stack.v` - Pipelined push/pop

**Expected gain**: Zero performance penalty for security

---

## Phase 7: Synthesis Optimization (Week 6-7)

### 7.1 Multi-Vt Cell Usage

```tcl
# In synth.tcl
# Use HVT (high-Vt) for critical path
set_attr -cell INV_X1_HVT -liberty nangate28_hvt.lib
set_attr -cell AND2_X1_HVT -liberty nangate28_hvt.lib

# Use LVT (low-Vt) for performance-critical
set_attr -cell DFF_X1_LVT -liberty nangate28_lvt.lib
```

### 7.2 Clock Gating

```verilog
// Auto-clock-gating enable
// Insert CG cells around idle modules

always @(posedge clk) begin
    if (!rst) begin
        core_clk_en <= (if_id_valid || id_ex_valid || ex_mem_valid || mem_wb_valid);
    end
end
```

### 7.3 Physical Optimization

- Add buffer insertion for long nets
- Floorplan-aware placement
- Useful skew scheduling

**Files to modify**:
- `synth.tcl` - Updated for 28nm libraries
- New `synth_optimize.tcl`

**Expected gain**: 10-15% frequency boost from physical

---

## Testing Plan

### Test Matrix

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| `tb_cpu_7stage` | 7-stage pipeline | Cycle count similar to 5-stage |
| `tb_btb` | BTB hit/miss | 90%+ hit rate on loops |
| `tb_l1_4way` | 4-way cache | LRU eviction working |
| `tb_mul_pipe` | Pipelined multiply | 2x throughput vs single-cycle |
| `tb_fwd_load` | Load-use forward | No stall on lw->add |
| `tb_cfi_pipe` | Pipelined CFI | No false positives |
| `tb_mte_async` | Async MTE | No false violations |

### Benchmark Suite

```c
// dhrystone.c - Integer performance
// coremark.c - Mixed workload
// memory_test.c - Cache performance
// branch_test.c - Branch predictor
```

---

## Expected Results

| Metric | Current | Target | Gain |
|--------|---------|--------|------|
| Frequency | 264 MHz | 400 MHz | +51% |
| IPC (estimated) | 0.7 | 0.9 | +28% |
| DMIPS/MHz | 0.7 | 1.0 | +43% |
| Cache Miss Rate (L1) | 15% | 5% | 67% reduction |

---

## Implementation Order

```
Week 1:   Phase 1 - 7-stage pipeline
Week 2:   Phase 2 - Branch prediction
Week 3:   Phase 3 - L1 cache upgrade
Week 4:   Phase 4 - ALU pipelining
Week 5:   Phase 5 - Hazard resolution
Week 6:   Phase 6 - Security pipelining
Week 7:   Phase 7 - Synthesis optimization
Week 8:   Full integration + benchmarks
```

---

## Files to Create/Modify

### New Files
- `rtl/cpu_core_7stage.v` - New 7-stage pipeline
- `rtl/btb.v` - Branch target buffer module
- `rtl/l1_cache_4way.v` - 4-way associative cache
- `rtl/mshr_l2.v` - L2 cache MSHR
- `rtl/alu_pipe.v` - Pipelined ALU

### Modify
- `rtl/cpu_core.v` - Forwarding, dual-port RF
- `rtl/l1_cache.v` - Complete rewrite
- `rtl/l2_cache.v` - Add MSHR
- `rtl/memory_tagging.v` - Async mode
- `rtl/shadow_stack.v` - Pipeline stage
- `synth.tcl` - 28nm optimization

### Testbenches
- `tb/tb_cpu_7stage.v`
- `tb/tb_btb.v`
- `tb/tb_l1_4way.v`
- `tb/tb_fwd_load.v`

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Long wire delays | Frequency drop | Pipeline repeaters |
| Cache coherence | L2 misses | Add snoop filter |
| Security overhead | IPC loss | Async pipeline |
| 28nm library unavailable | Can't synthesize | Use 45nm Nangate |

---

*Document generated for Arcturus Dawn C4-G1-N28*
*Target: 400MHz @ 28nm Process Node*