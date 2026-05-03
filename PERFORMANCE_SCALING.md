# Arcturus Dawn - Performance Scaling Analysis

## Question: Can Increasing Core Size & Transistors Boost Performance?

**Answer: YES!** More transistors enable more sophisticated microarchitecture.

---

## Current vs. Upgraded Comparison

| Feature | Current | Upgraded | Transistor Cost |
|---------|---------|----------|-----------------|
| Pipeline | 5-stage | 7-10 stage | +50K |
| Branch Predictor | Simple BTB | 2-level + RAS + BHT | +20K |
| Cache | 32KB | 128KB (L1+L2) | +500K |
| Issue Width | Single | Dual-issue | +80K |
| Execution Units | 1 ALU | 2 ALU + MUL/DIV | +40K |
| ROB/OOO | None | 32-entry reorder buffer | +60K |
| FPU | None | FMA + Div/Sqrt | +100K |
| Vector | None | RVV 1.0 (256-bit) | +200K |

---

## Scaling Strategy

### Level 1: Quick Wins (Low Area Cost)

| Feature | Area Added | Frequency Gain | IPC Gain |
|---------|------------|----------------|----------|
| Deeper pipeline | +5K | +20% | +5% |
| Better branch pred | +20K | +10% | +15-20% |
| Larger caches | +300K | +15% | +30% |

### Level 2: Moderate (Medium Area Cost)

| Feature | Area Added | Frequency Gain | IPC Gain |
|---------|------------|----------------|----------|
| Dual-issue | +80K | -5% | +40-50% |
| Out-of-Order | +150K | -15% | +80-100% |
| FPU | +100K | -5% | +20% (FP) |

### Level 3: High Performance (Large Area Cost)

| Feature | Area Added | Frequency Gain | IPC Gain |
|---------|------------|----------------|----------|
| RVV Vector | +200K | -10% | +10-50x (vector) |
| 4-wide issue | +300K | -20% | +150% |
| L2 256KB | +500K | +10% | +15% |

---

## Performance vs. Area Tradeoff

```
                    Performance (DMIPS/MHz)
                          │
    High-Perf     ────────●────────────────── OoO + Vector
    (RVV)         ──────●─────────────────────
    (Dual-Issue)  ────●───────────────────────
    (7-stage)    ──●─────────────────────────
    (Baseline)  ●──────────────────────────────
                          │
                          └────────────────────── Area (mm²)
                           3   5   10   15   20
```

---

## Recommended Upgrade Path

### Phase 1: "Performance" Variant (+0.5mm²)
- 7-stage pipeline
- 2-level branch predictor  
- 64KB total cache
- **Target**: 350 MHz, 1.2 IPC

### Phase 2: "High-Perf" Variant (+1.5mm²)  
- Dual-issue superscalar
- 128KB cache
- FPU
- **Target**: 400 MHz, 1.6 IPC

### Phase 3: "旗舰" Variant (+4mm²)
- Out-of-order (32-entry ROB)
- RVV vector unit
- 256KB cache
- **Target**: 500 MHz, 2.0+ IPC

---

## Power Implications

| Configuration | Area | Transistors | Power (310MHz) | DMIPS |
|---------------|------|-------------|----------------|-------|
| Current (5st) | 2.9mm² | ~500K | 50mW | 200 |
| Phase 1 (7st) | 3.4mm² | ~600K | 70mW | 340 |
| Phase 2 (Dual) | 4.4mm² | ~900K | 120mW | 500 |
| Phase 3 (OoO) | 7.0mm² | ~2M | 250mW | 800 |

---

## Conclusion

**YES** - You can significantly boost performance by increasing core size:

1. **3x more transistors** → 4x performance potential
2. **Area tradeoff**: ~3mm² more for 4x DMIPS
3. **Power increases** but remains manageable for mobile

The main bottlenecks are:
- Pipeline depth → more stages = higher freq
- Issue width → dual-issue = 40%+ IPC
- OoO execution → +80-100% IPC
- Vector → 10-50x on vectorizable code

Want me to implement any of these upgrades?