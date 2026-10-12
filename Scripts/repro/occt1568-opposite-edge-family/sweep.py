#!/usr/bin/env python3
"""Radius sweep around the critical value for fillets that meet exactly on a box.

  sweep.py <outdir> <fprobe_k4> <fprobe_k5> [swiftprobe]

One process per case with a time limit (OCCT#1568 is an uncatchable SIGSEGV). Writes
<outdir>/results.tsv. Detach it (os.setsid plus a done-file) per the repo's long-run rule.
"""
import math, subprocess, sys, os, itertools
import numpy as np

out, K4, K5 = sys.argv[1], sys.argv[2], sys.argv[3]
SW = sys.argv[4] if len(sys.argv) > 4 else None
os.makedirs(out, exist_ok=True)

B1 = (4, 10, 6)
CUBE = (4, 4, 4)
# name: (box, [edge midpoints], [critical radii], note)
CASES = {
 "C1-opposite-top-w4":   (B1, [(0,5,6),(4,5,6)], [2], "two parallel edges either side of a 4 wide face: forum case"),
 "C2-opposite-top-w10":  (B1, [(2,0,6),(2,10,6)], [5], "two parallel edges either side of a 10 wide face"),
 "C3-opposite-side-w6":  (B1, [(0,5,0),(0,5,6)], [3], "two parallel edges either side of a 6 wide face"),
 "C4-adjacent-top":      (B1, [(4,5,6),(2,10,6)], [2,3,4,5,6], "two edges meeting at a corner, sharing the top face"),
 "C5-adjacent-vertical": (B1, [(4,5,6),(4,10,3)], [2,3,4,5,6], "two edges meeting at a corner, sharing the x=4 face"),
 "C6-three-at-corner":   (B1, [(4,5,6),(2,10,6),(4,10,3)], [2,3,4,5,6], "three edges at one vertex (vertex blend)"),
 "C7-top-frame":         (B1, [(0,5,6),(4,5,6),(2,0,6),(2,10,6)], [2,3,5], "all four edges of the 4x10 top face"),
 "C8-all-12-edges":      (B1, None, [2,3], "every edge (Shape.filleted(radius:))"),
 "C9-cube-opposite":     (CUBE, [(0,2,4),(4,2,4)], [2], "two 2 mm fillets on a 4 mm face of a cube"),
 "C10-cube-top-frame":   (CUBE, [(0,2,4),(4,2,4),(2,0,4),(2,4,4)], [2], "four fillets round a 4x4 face"),
}

def midpoints_all(box):
    x, y, z = box
    pts = []
    for a in (0, x):
        for b in (0, y): pts.append((a, b, z/2))
    for a in (0, x):
        for c in (0, z): pts.append((a, y/2, c))
    for b in (0, y):
        for c in (0, z): pts.append((x/2, b, c))
    return pts

def radii(crit):
    up = math.nextafter(crit, 1e9); dn = math.nextafter(crit, 0)
    return [("0.5c", 0.5*crit), ("c-1e-3", crit-1e-3), ("c-1e-4", crit-1e-4), ("c-1e-8", crit-1e-8),
            ("c-1ulp", dn), ("c", crit), ("c+1ulp", up), ("c+1e-8", crit+1e-8), ("c+1e-4", crit+1e-4),
            ("c+1e-3", crit+1e-3), ("1.5c", 1.5*crit)]

def removed_fraction_volume(box, mids, r, n=400):
    """Volume of the box minus the union of the edge-removal regions (a grid estimate, slabs of x)."""
    x, y, z = box
    g = [(np.arange(n) + .5) / n * d for d in box]
    kept = 0
    step = 25
    for s0 in range(0, n, step):
        X, Y, Z = np.meshgrid(g[0][s0:s0+step], g[1], g[2], indexing="ij")
        P = [X, Y, Z]
        gone = np.zeros(X.shape, bool)
        for m in mids:
            ax = [i for i in range(3) if 0 < m[i] < box[i]][0]
            u, v = [i for i in range(3) if i != ax]
            du = np.abs(P[u] - m[u]); dv = np.abs(P[v] - m[v])
            gone |= (du < r) & (dv < r) & ((r - du)**2 + (r - dv)**2 > r*r)
        kept += (~gone).sum()
    return x*y*z * kept / (n**3)

def run(cmd, timeout=60):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, start_new_session=True)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", ""
    lines = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    if not lines:
        return f"NORESULT(rc={p.returncode})", p.stderr[-200:]
    return lines[0], p.stdout

def classify(line):
    if line.startswith("RESULT SIGNAL"): return "SIGSEGV" if "SIGNAL 11" in line else line[7:]
    if "exception" in line: return "exception: " + line.split("exception", 1)[1].strip()
    if line in ("TIMEOUT",) or line.startswith("NORESULT"): return line
    kv = dict(t.split("=") for t in line.split()[2:] if "=" in t)
    if kv.get("done") == "0": return "IsDone=false"
    if kv.get("valid") in ("0", "false"): return "done, INVALID"
    return "valid"

rows = open(os.path.join(out, "results.tsv"), "w")
rows.write("kernel\tmode\tcase\tcrit\tlabel\tradius\toutcome\tvolume\texpected\tdelta_pct_of_removed\tfaces\n")
exp_cache = {}
for name, (box, mids, crits, note) in CASES.items():
    mids = mids or midpoints_all(box)
    for crit in crits:
        for label, r in radii(crit):
            args = [str(v) for v in box] + [repr(r)] + [",".join(map(str, m)) for m in mids]
            jobs = [("k4", "add", [K4, "add"] + args), ("k5", "add", [K5, "add"] + args),
                    ("k4", "add2", [K4, "add2"] + args), ("k5", "add2", [K5, "add2"] + args)]
            if len(mids) == 2 or name.startswith("C10"):
                jobs += [("k4", "seq", [K4, "seq"] + args), ("k5", "seq", [K5, "seq"] + args)]
            if SW:
                jobs.append(("k5", "swift", [SW] + args))
            for kern, mode, cmd in jobs:
                line, full = run(cmd)
                outc = classify(line.replace("RESULT swift nonnil", "RESULT swift done=1").replace("RESULT swift nil", "RESULT swift done=0")if mode == "swift" else line)
                vol = exp = delta = ""; faces = ""
                if "vol=" in line:
                    kv = dict(t.split("=") for t in line.split() if "=" in t)
                    vol = float(kv["vol"]); faces = kv.get("faces", "")
                    if vol > 0:
                        key = (name, r)
                        if key not in exp_cache: exp_cache[key] = removed_fraction_volume(box, mids, r)
                        exp = exp_cache[key]
                        removed = box[0]*box[1]*box[2] - exp
                        delta = f"{100*(vol-exp)/removed:.2f}" if removed > 0 else ""
                rows.write(f"{kern}\t{mode}\t{name}\t{crit}\t{label}\t{r!r}\t{outc}\t{vol}\t{exp}\t{delta}\t{faces}\n"); rows.flush()
print("done")
