#!/usr/bin/env python3
"""Classify BRepFilletAPI_MakeFillet outcomes for two probe binaries over every edge and radius.

  sweep.py <unpatched-probe> <patched-probe>   run from this directory (needs model.brep)

One probe process per case (a SIGSEGV kills the process), over the model's 42 DRAW-numbered edges
and nine radii. Each case is `identical` when both binaries give the same outcome and result lines,
and `DIFFERENT` otherwise. An outcome is `completed`, `SIGSEGV`, or `uncaught C++ exception`: the
probe has no try/catch, so the second is an ordinary Standard_Failure that the bridge's own
`catch (...)` absorbs and is not a crash.
"""
import re
import subprocess
import sys
from collections import Counter

RADII = [0.3, 0.8, 1.0, 1.2, 1.4999999, 1.5, 1.5000001, 1.8, 2.5]


def run(binary, radius, edge):
    p = subprocess.run([binary, "model.brep", str(radius), str(edge)],
                       capture_output=True, text=True, timeout=120)
    out = p.stdout + p.stderr
    lines = tuple(l.strip() for l in out.splitlines()
                  if re.search(r"IsDone|NbFaultyContours|NbContours|completed|uncaught exception", l))
    if p.returncode == 0:
        kind = "completed"
    elif p.returncode == 139:
        kind = "SIGSEGV"
    elif "uncaught exception" in out:
        kind = "uncaught C++ exception"
    else:
        kind = "rc=%d" % p.returncode
    return kind, lines


def main():
    unpatched, patched = sys.argv[1], sys.argv[2]
    counts, examples = Counter(), {}
    for edge in range(1, 43):
        for radius in RADII:
            a, b = run(unpatched, radius, edge), run(patched, radius, edge)
            key = ("identical", a[0]) if a == b else ("DIFFERENT", "%s -> %s" % (a[0], b[0]))
            counts[key] += 1
            examples.setdefault(key, []).append((edge, radius))
    print("cases: %d" % (42 * len(RADII)))
    for (verdict, detail), n in sorted(counts.items()):
        print("%5d  %-10s %s" % (n, verdict, detail))
    for key, where in examples.items():
        if key[0] == "DIFFERENT":
            print("%s: %s" % (key[1], where))


if __name__ == "__main__":
    main()
