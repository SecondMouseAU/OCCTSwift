#!/usr/bin/env python3
"""Check the newly valid add-mode cases of fuzz.py (FUZZ_JSON) against an independent volume: the union of the
per-edge removal prisms (oracle.corner for each edge), on a grid. Seq cases have no grid oracle here and are skipped.

  fuzz_oracle.py <fuzz.json>      exit 1 if any case differs from the grid estimate by more than 0.4 % of the box volume
"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle

rows = json.load(open(sys.argv[1]))
n, bad, checked, worst = 160, 0, 0, 0.0
for row in rows:
    if row["mode"] != "add":
        continue
    b = row["box"]
    g = [(np.arange(n) + .5) / n * d for d in b]
    X, Y, Z = np.meshgrid(*g, indexing="ij")
    P = [X, Y, Z]
    gone = np.zeros(X.shape, bool)
    for r, m in row["edges"]:
        ax = [i for i in range(3) if 0 < m[i] < b[i]][0]
        u, v = [i for i in range(3) if i != ax]
        # distance along each face from the edge, towards the face interior
        du = P[u] if m[u] == 0 else b[u] - P[u]
        dv = P[v] if m[v] == 0 else b[v] - P[v]
        cd = oracle.corner(b[u], b[v], r)
        if cd is None:
            gone = None
            break
        cu, cv = cd["centre"]
        gone |= (du <= cd["q1"]) & (dv <= cd["q2"]) & ((du - cu) ** 2 + (dv - cv) ** 2 > r * r)
    if gone is None:
        continue
    V0 = b[0] * b[1] * b[2]
    est = V0 * (1 - gone.sum() / gone.size)
    d = abs(est - row["vol"]) / V0
    worst = max(worst, d)
    checked += 1
    if d > 0.004:
        bad += 1
        print("DIFF", row, est, d)
print(f"checked {checked} add-mode newly valid cases against the grid union, worst difference {worst:.2e} of the box volume, {bad} over 0.4 %")
sys.exit(1 if bad else 0)
