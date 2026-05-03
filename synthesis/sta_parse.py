#!/usr/bin/env python3
"""Parse Nangate45 liberty NLDM tables and estimate STA timing."""
import re
import sys

def parse_liberty_delays(libfile):
    """Extract min/max delays from liberty NLDM tables."""
    cells = {}
    with open(libfile, 'r') as f:
        content = f.read()
    
    for cell_match in re.finditer(r'cell\s*\((\w+)\)\s*\{(.*?)^\s*\}', content, re.DOTALL | re.MULTILINE):
        name = cell_match.group(1)
        body = cell_match.group(2)
        
        # Extract cell_rise and cell_fall tables
        delays = []
        for table_match in re.finditer(r'cell_(rise|fall)\([^)]*\)[^}]*values\s*\(\s*"([^"]+)"', body):
            vals = [float(v.strip()) for v in table_match.group(2).split(',') if v.strip()]
            delays.extend(vals)
        
        if delays:
            cells[name] = {
                'min_ns': min(delays),
                'max_ns': max(delays),
                'avg_ns': sum(delays) / len(delays)
            }
    
    return cells

def main():
    libfile = sys.argv[1] if len(sys.argv) > 1 else 'synthesis/nangate45.lib'
    cells = parse_liberty_delays(libfile)
    
    # Read netlist to count actual cells used
    with open('build/cpu_core_netlist.v', 'r') as f:
        netlist = f.read()
    
    # Count cells by type
    cell_counts = {}
    total_comb_cells = 0
    for name in cells:
        count = netlist.count(name + '(')
        if count > 0:
            cell_counts[name] = count
            total_comb_cells += count
    
    print("=== Nangate45 Cell Delays (extracted from NLDM tables) ===")
    print(f"{'Cell':20s} {'Count':>6s} {'Min(ps)':>10s} {'Avg(ps)':>10s} {'Max(ps)':>10s}")
    print("-" * 60)
    
    weighted_sum = 0
    for name in sorted(cells.keys(), key=lambda x: cells[x]['avg_ns']):
        if name in cell_counts:
            c = cell_counts[name]
            d = cells[name]
            weighted_sum += d['avg_ns'] * c
            print(f"{name:20s} {c:6d} {d['min_ns']*1000:10.2f} {d['avg_ns']*1000:10.2f} {d['max_ns']*1000:10.2f}")
    
    print(f"\nTotal combinational cells: {total_comb_cells}")
    print(f"Weighted avg delay sum:    {weighted_sum:.2f} ns")
    
    # Critical path analysis
    print("\n=== Critical Path Analysis ===")
    print("The critical path in this 5-stage RISC-V core is in the EX stage:")
    print("  PC register → IF/ID latch → ID/EX latch →")
    print("  Forwarding mux (4:1) → ALU adder → WB result mux → EX/MEM latch")
    print()
    
    # Extract relevant cell delays
    inv_avg = cells.get('INV_X1', {}).get('avg_ns', 0.05) * 1000
    nand2_avg = cells.get('NAND2_X1', {}).get('avg_ns', 0.06) * 1000
    nor2_avg = cells.get('NOR2_X1', {}).get('avg_ns', 0.08) * 1000
    mux2_avg = cells.get('MUX2_X1', {}).get('avg_ns', 0.10) * 1000
    xor2_avg = cells.get('XOR2_X1', {}).get('avg_ns', 0.15) * 1000
    oai21_avg = cells.get('OAI21_X1', {}).get('avg_ns', 0.09) * 1000
    aoi21_avg = cells.get('AOI21_X1', {}).get('avg_ns', 0.08) * 1000
    
    # Count logic depth for critical path
    # The 32-bit adder is the longest combinational chain
    # Using ripple carry: 32 × (carry gen + carry prop)
    
    print("Critical path components (45nm):")
    print(f"  1. PC+4 increment (32-bit adder):")
    print(f"     ~32 stages × carry chain ≈ 32 × {nand2_avg*2:.1f} ps = {32*nand2_avg*2:.0f} ps")
    print(f"  2. Branch comparison (32-bit eq/lt):")
    print(f"     ~32 bits × XNOR + tree reduction ≈ {(32*xor2_avg + 5*oai21_avg):.0f} ps")
    print(f"  3. Forwarding mux tree:")
    print(f"     4:1 mux = ~{mux2_avg*2:.0f} ps per stage × 2 = {mux2_avg*4:.0f} ps")
    print(f"  4. ALU operand select:")
    print(f"     ~{aoi21_avg*3:.0f} ps")
    print(f"  5. DFF clk-to-Q + setup:")
    dff_clk2q = cells.get('DFF_X1', {}).get('avg_ns', 0.12)
    print(f"     {dff_clk2q*1000:.0f} ps + {dff_clk2q*1000*0.8:.0f} ps = {dff_clk2q*1000*1.8:.0f} ps")
    
    # Calculate critical path
    # For a 5-stage pipeline, critical path = longest stage
    # EX stage is typically the longest due to ALU
    alu_delay = 32 * nand2_avg * 2 + mux2_avg * 4 + aoi21_avg * 3  # ps
    t_clkq = dff_clk2q * 1000 * 1.8  # ps
    wire_est = alu_delay * 0.15  # 15% wire overhead
    skew_margin = 50  # ps clock skew
    
    critical_path = alu_delay + wire_est + t_clkq + skew_margin
    fmax = 1e6 / critical_path  # ps → MHz
    
    print(f"\n  Critical path: {critical_path:.0f} ps")
    print(f"  ────────────────────────────────")
    print(f"  f_max (45nm):  {fmax:.0f} MHz")
    
    # Scale to 28nm (roughly 0.65-0.75x delay)
    scale = 0.70
    critical_28 = critical_path * scale
    fmax_28 = 1e6 / critical_28
    print(f"\n=== Scaled to 28nm (×{scale}) ===")
    print(f"  Critical path: {critical_28:.0f} ps")
    print(f"  f_max (28nm):  {fmax_28:.0f} MHz")
    
    # With optimizations (7-stage pipeline)
    scale_opt = 0.85  # Less logic per stage
    critical_opt = critical_28 * scale_opt
    fmax_opt = 1e6 / critical_opt
    print(f"\n=== With 7-stage pipeline (28nm, less logic/stage) ===")
    print(f"  Critical path: {critical_opt:.0f} ps")
    print(f"  f_max (28nm):  {fmax_opt:.0f} MHz")

if __name__ == '__main__':
    main()
