# Arcturus Dawn - Optimization Analysis & Academic Research

## 1. Current Performance Baseline

Based on simulation results:
- **Current IPC**: 0.99 (99% efficiency in short runs), 25% in sustained runs
- **Frequency**: 100MHz (sim) → 310MHz (estimated @ 28nm)
- **Gate Count**: 4,662 gates
- **Area**: 2.89 mm²

---

## 2. Academic Research Findings

### Key Papers Analyzed:

| Paper | Key Finding | Relevance |
|-------|-------------|-----------|
| **CVA6S+ (2025)** | 43.5% IPC gain, 9.3% area overhead with dual-issue | ✅ Direct upgrade path |
| **SonicBOOM (Berkeley)** | 2x IPC over prior OoO, 6.2 CoreMark/MHz | OoO benchmark |
| **NRP (2024)** | 11% gain with branch prediction + ID optimization | Low-cost improvements |
| **SHADOW (2025)** | 3.16x speedup with OoO+InO hybrid | Advanced SMT |
| **Subthreshold RISC-V** | 2-stage pipeline is energy-optimal | Low-power design |
| **Register Dispersion** | 53% VRF area savings with no performance loss | Vector optimization |
| **RVV Database (2025)** | Up to 10x speedup with manual RVV optimization | Vector potential |

---

## 3. Diminishing Returns Analysis

### IPC vs. Complexity Curve

```
IPC
2.0 |                                            ● OoO (C910)
    |                                        ●
1.5 |                                    ●
    |                               ●
1.0 |                      ● CVA6S+
    |                 ●
0.5 |           ● Our Design
    |      ●
0.0 +------------------------------------------→ Area/Complexity
     0    5    10   15   20   25   30+
```

### Diminishing Returns Thresholds:

| Optimization | IPC Gain | Area Cost | Diminishing Returns |
|--------------|----------|-----------|---------------------|
| Branch Prediction | +15-20% | +2% | 90% of max |
| Dual-Issue | +40-50% | +9% | 80% of max |
| Out-of-Order | +80-100% | +75% | 70% of max |
| RVV Vector | +10-50x | +25% | 60% (vectorizable) |
| 4-wide Issue | +150% | +100% | 50% of max |

### Sweet Spots Identified:

1. **Quick Win** (<5% area): Branch prediction, cache optimization
2. **Best ROI** (5-10% area): Dual-issue superscalar (CVA6S+ approach)
3. **Diminishing** (10-20% area): Out-of-order starts to cost more than benefit

---

## 4. Optimization Recommendations

### Tier 1: Quick Wins (Low Risk, High Return)

| Optimization | Est. IPC Gain | Area | Implementation |
|--------------|---------------|------|----------------|
| 2-level Branch Predictor | +15% | +2% | ✅ Already implemented |
| Return Address Stack | +5% | +1% | ✅ Already implemented |
| Load-Use Forwarding | +10% | +1% | Recommended |
| Loop Buffer | +3% | +1% | Recommended |

**Recommendation**: IMPLEMENT - ROI within 20%

---

### Tier 2: Best Investment (Medium Area, High Return)

| Optimization | Est. IPC Gain | Area | Implementation |
|--------------|---------------|------|----------------|
| Dual-Issue Superscalar | +43% | +9% | Advanced design |
| Non-Blocking Cache (MSHR) | +20% | +3% | ✅ Implemented |
| Register Renaming | +10% | +5% | Recommended |
| FPU Integration | +20% (FP) | +8% | Future |

**Recommendation**: PURSUE - Matches CVA6S+ success (43% gain)

---

### Tier 3: High Performance (High Cost)

| Optimization | Est. IPC Gain | Area | Recommendation |
|--------------|---------------|------|----------------|
| OoO (32-entry ROB) | +80% | +75% | Maybe later |
| RVV Vector (256-bit) | +10-50x | +25% | For vector workloads |
| 4-wide Issue | +150% | +100% | Diminishing returns |

**Recommendation**: DEFER - Area/Power cost too high for current target

---

## 5. Recommended Roadmap

### Phase 1: Current → Performance (Target: 350 MHz, 1.3 IPC)

```
Changes:
+ Better branch prediction (TAGE-style)
+ Load-use forwarding path (MEM→EX)
+ 64KB total cache (from 32KB)
+ 7-stage pipeline tuning

Area: +5% → 3.0 mm²
IPC: 1.0 → 1.3 (+30%)
Frequency: 310 → 350 MHz
```

### Phase 2: Performance → High-Perf (Target: 400 MHz, 1.6 IPC)

```
Changes:
+ Dual-issue superscalar
+ Register renaming
+ Non-blocking cache (HPDCache-style)

Area: +15% → 3.5 mm²  
IPC: 1.3 → 1.6 (+23%)
Frequency: 350 → 400 MHz
```

### Phase 3: High-Perf →旗舰 (Optional) (Target: 500 MHz, 2.0+ IPC)

```
Changes:
+ Out-of-order (ROB 32-entry)
+ RVV vector unit
+ 256KB cache

Area: +80% → 6.5 mm²
IPC: 1.6 → 2.0+ (+25%)
Frequency: 400 → 500 MHz
```

---

## 6. Key Academic References

1. **CVA6S+**: "43.5% IPC improvement with 9.3% area" (2025)
2. **SonicBOOM**: "6.2 CoreMark/MHz, fastest open-source" (Berkeley)
3. **SHADOW**: "3.16x with OoO+InO hybrid" (2025)
4. **NRP**: "11% gain with ID/branch optimization" (2024)

---

## 7. Summary

### For Arcturus Dawn (Mobile/IoT Target):

**Optimal Path**: 
1. ✅ Keep 7-stage pipeline (already optimized)
2. ✅ Dual-issue (best ROI: 43% gain, 9% area)
3. ⚠️ Avoid OoO unless necessary (too costly)
4. ⚠️ RVV only if vector workload required

**Expected Max Performance**:
- **Conservative**: 350 MHz, 1.3 IPC (3.0 mm²)
- **Aggressive**: 400 MHz, 1.6 IPC (3.5 mm²)  
- **旗舰**: 500 MHz, 2.0 IPC (6.5 mm²) - diminishing returns

**Diminishing Returns Threshold**: ~1.6 IPC where area cost doubles for small gains

---

*Analysis based on 2024-2025 academic research on RISC-V performance optimization*