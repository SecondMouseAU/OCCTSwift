#!/usr/bin/env python3
"""The pivot-edge cases on the 4 x 10 x 6 box (w = 4 across X, L = 10 along Y, h = 6), one process each.

  cases.py <fprobe> [mode]      prints one row per case: outcome, validity, volume, faces

Edge midpoints: LEFT = (0,5,6) and RIGHT = (4,5,6) are the two top edges along Y.
"""
import subprocess, sys
BOX = ["4", "10", "6"]
LEFT, RIGHT = "0,5,6", "4,5,6"

def cases():
    c = []
    for r1, r2 in [(1.5, 2.5), (1, 3), (0.5, 3.5), (2, 2)]:
        c.append(("A", f"A r1={r1} r2={r2}", [(r1, LEFT), (r2, RIGHT)]))
    for r in [2.2, 2.5, 3.0, 3.5, 3.9]:
        c.append(("B", f"B r={r}", [(r, LEFT), (r, RIGHT)]))
    for r1, r2 in [(2, 2.5), (1, 3.5), (2.5, 3), (0.5, 3.9)]:
        c.append(("B", f"B r1={r1} r2={r2}", [(r1, LEFT), (r2, RIGHT)]))
    for r in [3.9, 4.0, 4.5, 5.0, 6.0]:
        c.append(("C", f"C single r={r}", [(r, LEFT)]))
    return c

def run(probe, mode, edges, timeout=60):
    args = [probe, mode] + BOX + ["1"] + [f"{r!r}:{m}" for r, m in edges]
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout, start_new_session=True)
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    ls = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    return ls[0][7:] if ls else f"NORESULT rc={p.returncode}"

if __name__ == "__main__":
    probe = sys.argv[1]; mode = sys.argv[2] if len(sys.argv) > 2 else "add"
    for grp, name, edges in cases():
        print(f"{name:28s} {run(probe, mode, edges)}", flush=True)
