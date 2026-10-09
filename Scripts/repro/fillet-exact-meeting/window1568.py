#!/usr/bin/env python3
"""Width of the failing window around radius 1.5 on the reporter's model (OCCT#1568), edge 13 alone.
  window1568.py <probe1568_k4> <probe1568_k5> <model.brep>     one process per radius, 120 s limit"""
import subprocess, sys, math
def run(probe, model, r):
    try:
        p = subprocess.run([probe, model, repr(r), "13"], capture_output=True, text=True, timeout=120, start_new_session=True)
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    o = p.stdout + p.stderr
    if p.returncode in (139, 11) or "SIGNAL 11" in o: return "SIGSEGV"
    if "IsDone = true" in o: return "done"
    if "IsDone = false" in o: return "IsDone=false"
    return f"?rc={p.returncode}"
rs = [1.5 - d for d in (1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9, 1e-10, 1e-12)] + [math.nextafter(1.5, 0), 1.5, math.nextafter(1.5, 9)] + [1.5 + d for d in (1e-12, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1)]
print("%-22s %-14s %-14s" % ("radius", "kernel.4", "kernel.5"))
for r in rs:
    print("%-22s %-14s %-14s" % (repr(r), run(sys.argv[1], sys.argv[3], r), run(sys.argv[2], sys.argv[3], r)))
