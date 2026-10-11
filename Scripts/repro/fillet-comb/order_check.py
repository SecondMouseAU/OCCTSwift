#!/usr/bin/env python3
"""Does the order the edges are added change the outcome? Box subsets, several radii, 8 random orders each (cprobe fillet / chamfer_sym).
  order_check.py <cprobe> <out.tsv>"""
import itertools, random, subprocess, sys
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import comb_oracle as co
PROBE, OUT = sys.argv[1:3]
random.seed(3)
rows = []
for dims in [(10, 10, 10), (4, 10, 6), (20, 20, 2)]:
    m = min(dims)
    subsets = {"topface": [(0, 0, 1), (0, 1, 1), (1, 0, 1), (1, 1, 1)], "all12": co.box_edges(), "adjacent": [(1, 0, 1), (0, 0, 1)], "vertex3": [(0, 0, 1), (1, 0, 1), (2, 0, 0)]}
    for sname, edges in subsets.items():
        for op in ("fillet", "chamfer_sym"):
            for f in (0.1, 0.25, 0.4, 0.5, 0.6, 0.9):
                outs = {}
                for t in range(8):
                    order = edges[:]
                    random.shuffle(order)
                    pts = ["%g,%g,%g" % co.edge_mid(dims, e) for e in order]
                    p = subprocess.run([PROBE, "run", "box:%g,%g,%g" % dims, op, repr(f * m)] + pts, capture_output=True, text=True, timeout=60)
                    l = [x for x in p.stdout.splitlines() if x.startswith("RESULT")][0]
                    kv = dict(x.split("=", 1) for x in l.split()[1:5])
                    key = (kv["done"], kv["valid"], round(float(l.split("vol=")[1].split()[0]), 4))
                    outs[key] = outs.get(key, 0) + 1
                if len(outs) > 1:
                    rows.append((dims, sname, op, f, outs))
with open(OUT, "w") as fh:
    fh.write("dims\tsubset\top\tfraction\toutcomes (done, valid, volume): count of 8 orders\n")
    for r in rows:
        fh.write("%s\t%s\t%s\t%g\t%s\n" % r)
print(len(rows), "order-dependent cases")
for r in rows: print(r)
