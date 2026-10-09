#!/usr/bin/env python3
"""Runs every face pair of several solids through the probe, one process each (a crash is the
exit status, not an exception). usage: scan.py <probe-binary> [shape ...]
The first seven shapes are #3098's scan; the rest are #3105's additions. Set FEAT=1 to make the
probe print the path-phase replay features before the Build call."""
import subprocess, sys, itertools
probe = sys.argv[1]
old = {"box": 6, "cyl": 3, "cone": 2, "octa": 8, "tube": 4, "hex": 8, "lshape": 8}
new = ["tri", "pent", "oct8", "star", "ushape", "sqtube", "frustum", "torus", "bend", "elbow", "capsule"]
shapes = dict(old)
for n in new:
    shapes[n] = int(subprocess.run([probe, "count", n], capture_output=True, text=True).stdout.strip() or 0)
if len(sys.argv) > 2:
    shapes = {k: v for k, v in shapes.items() if k in sys.argv[2:]}
for shape, n in shapes.items():
    for i, j in itertools.combinations_with_replacement(range(n), 2):
        try:
            r = subprocess.run([probe, "pair", shape, str(i), str(j)], capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            print(f"{shape} {i} {j} exit=124 (timeout)", flush=True)
            continue
        line = r.stdout.strip().split("\n")[0] if r.stdout.strip() else f"{shape} {i} {j}"
        print(f"{line}  exit={r.returncode}", flush=True)
