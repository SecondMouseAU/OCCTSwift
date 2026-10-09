#!/usr/bin/env python3
"""Random box cases: nothing that worked on main may change, nothing may become done-but-invalid.

  fuzz.py <fprobe_main> <fprobe_branch> [count] [seed]

Random box (sides 2..12), one to four random box edges (named by midpoint), radii from 0.3 to 1.3 times the
largest side, mode add or seq. One process per run, 60 s limit. Prints the tally and every row that is not
'same' or 'unchanged'; exit 1 on a regression or a done-but-invalid result.
"""
import json, os, random, subprocess, sys
MAIN, BR = sys.argv[1], sys.argv[2]
N = int(sys.argv[3]) if len(sys.argv) > 3 else 300
random.seed(int(sys.argv[4]) if len(sys.argv) > 4 else 11)

def edges(b):
    x, y, z = b
    e = [(a, c, z / 2) for a in (0, x) for c in (0, y)] + [(a, y / 2, c) for a in (0, x) for c in (0, z)] + [(x / 2, a, c) for a in (0, y) for c in (0, z)]
    return e

def run(exe, mode, b, r, es):
    args = [exe, mode] + [repr(v) for v in b] + ["1"] + [f"{rr!r}:{','.join(repr(v) for v in m)}" for rr, m in es]
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=60, start_new_session=True)
    except subprocess.TimeoutExpired:
        return ("TIMEOUT", None, None)
    ls = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    if not ls: return ("NORESULT", None, None)
    l = ls[0]
    if "exception" in l or "SIGNAL" in l: return ("exception", None, None)
    kv = dict(t.split("=") for t in l.split()[2:] if "=" in t)
    if kv["done"] == "0": return ("false", None, None)
    return ("valid" if kv["valid"] == "1" else "INVALID", float(kv["vol"]), int(kv["faces"]))

tally, bad, rows = {}, 0, []
for i in range(N):
    b = tuple(round(random.uniform(2, 12), 2) for _ in range(3))
    k = random.choice([1, 1, 2, 2, 3, 4])
    es = random.sample(edges(b), k)
    m = max(b)
    es = [(round(random.uniform(0.3, 1.3) * m, 3), e) for e in es]
    if random.random() < 0.3:
        r0 = es[0][0]; es = [(r0, e) for _, e in es]
    mode = random.choice(["add", "add", "seq"])
    a, c = run(MAIN, mode, b, 0, es), run(BR, mode, b, 0, es)
    if a[0] == "valid":
        v = "same" if c[0] == "valid" and abs(c[1] - a[1]) <= 1e-9 and c[2] == a[2] else "REGRESSED"
    elif c[0] == "valid": v = "newly-valid"
    elif c[0] == "INVALID" and a[0] != "INVALID": v = "NEWLY-INVALID"
    else: v = "unchanged"
    tally[v] = tally.get(v, 0) + 1
    if v in ("REGRESSED", "NEWLY-INVALID"): bad += 1
    if v == "newly-valid": rows.append(dict(mode=mode, box=b, edges=es, vol=c[1], faces=c[2]))
    if v not in ("same", "unchanged", "newly-valid"): print(i, mode, b, es, a, c, v, flush=True)
print(tally)
if os.environ.get('FUZZ_JSON'): json.dump(rows, open(os.environ['FUZZ_JSON'], 'w'))
sys.exit(1 if bad else 0)
