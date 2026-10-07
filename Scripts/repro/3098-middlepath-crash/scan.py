#!/usr/bin/env python3
"""Runs every face pair of several solids through the probe, one process each (a crash is the
exit status, not an exception). usage: scan.py <probe-binary>"""
import subprocess, sys, itertools
probe = sys.argv[1]
nfaces = {"box": 6, "cyl": 3, "cone": 2, "octa": 8, "tube": 4, "hex": 8, "lshape": 8}
for shape, n in nfaces.items():
    for i, j in itertools.permutations(range(n), 2) if False else itertools.combinations_with_replacement(range(n), 2):
        r = subprocess.run([probe, "pair", shape, str(i), str(j)], capture_output=True, text=True)
        line = r.stdout.strip().split("\n")[0] if r.stdout.strip() else f"{shape} {i} {j}"
        print(f"{line}  exit={r.returncode}")
