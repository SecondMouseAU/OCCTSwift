#!/usr/bin/env python3
"""Dense radius sweep and edge sweep on the reporter's model (OCCT#1568), one process per case.
  sweep.py window <wprobe> <model.brep> <out.tsv> [draw|def]     edge 13, radii through 1.4980..1.5020 and a coarse scan
  sweep.py edges  <wprobe> <model.brep> <out.tsv> [draw|def]     all 42 edges at r = 1.5
Run detached (os.setsid plus a done-file) for the long sets. 60 s limit per case."""
import subprocess, sys, math
from concurrent.futures import ThreadPoolExecutor
mode, probe, model, out = sys.argv[1:5]
par = sys.argv[5] if len(sys.argv) > 5 else "draw"
def run(case):
    r, e = case
    try:
        p = subprocess.run([probe, model, repr(r), str(e), par], capture_output=True, text=True, timeout=60, start_new_session=True)
        o = p.stdout.strip().splitlines()
        line = o[-1] if o else "RESULT status=empty rc=%d" % p.returncode
    except subprocess.TimeoutExpired:
        line = "RESULT status=timeout"
    kv = dict(t.split("=", 1) for t in line.split()[1:] if "=" in t)
    return (r, e, kv.get("status", line), kv.get("valid", ""), kv.get("free", ""), kv.get("vol", ""), kv.get("faces", ""), kv.get("mesh", ""))
if mode == "window":
    rs = [1.4 + 0.01 * i for i in range(0, 41)]
    rs += [1.4980 + 0.0001 * i for i in range(0, 41)]
    rs += [1.49853, 1.4999, 1.499999, 1.5 - 1e-9, math.nextafter(1.5, 0), 1.5, math.nextafter(1.5, 9), 1.5 + 1e-9, 1.5 + 2e-9, 1.5 + 5e-9, 1.5 + 1e-8, 1.5 + 1e-6, 1.5 + 1e-5]
    cases = sorted(set((round(r, 12) if abs(r - 1.5) > 1e-12 else r, 13) for r in rs))
else:
    cases = [(1.5, e) for e in range(1, 43)]
with ThreadPoolExecutor(6) as ex, open(out, "w") as f:
    f.write("radius\tedge\tstatus\tvalid\tfree\tvolume\tfaces\tmesh\n")
    for row in ex.map(run, cases):
        f.write("\t".join(map(str, row)) + "\n"); f.flush()
print("done")
