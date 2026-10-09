#!/usr/bin/env python3
"""Does any sequence of plain-box fillets reach StartSol's obstacle branch (the one patch 0054 changes)?
Fillets edge-by-edge on a box, every ordered pair and every ordered triple of box edges, each step the same
radius (a new fillet of the radius of one that already exists is the reporter's shape: radius 1.5 against 1.5
arcs). Uses the instrumented probe (prints [STARTSOL] lines) in `seq` mode. One process per sequence.
  search_obstacle.py <outdir> <fprobe_trace> [triples]"""
import sys, os, subprocess, itertools, collections
out, PROBE = sys.argv[1], sys.argv[2]; triples = len(sys.argv) > 3
os.makedirs(out, exist_ok=True)
def mids(b):
    x, y, z = b; m = []
    for a in (0, x):
        for c in (0, y): m.append((a, c, z/2))
    for a in (0, x):
        for c in (0, z): m.append((a, y/2, c))
    for a in (0, y):
        for c in (0, z): m.append((x/2, a, c))
    return m
tally = collections.Counter(); hits = []
w = open(os.path.join(out, "obstacle_search.tsv"), "w"); w.write("box\tradius\tedges\toutcome\tobstacle_lines\n")
for box in ((20, 20, 20), (30, 20, 12)):
    m = mids(box)
    n = 3 if triples else 2
    for r in (1.0, 1.5, 3.0):
        for seq in itertools.permutations(range(12), n):
            args = [str(v) for v in box] + [repr(r)] + [",".join(map(str, m[i])) for i in seq]
            try: p = subprocess.run([PROBE, "seq"] + args, capture_output=True, text=True, timeout=60, start_new_session=True)
            except subprocess.TimeoutExpired: tally["TIMEOUT"] += 1; continue
            res = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
            outc = "SIGSEGV" if (res and "SIGNAL 11" in res[0]) or p.returncode in (139, -11) else ("done" if res and "done=1" in res[0] else "IsDone=false" if res else f"rc{p.returncode}")
            ob = sorted({l for l in p.stderr.splitlines() if "[STARTSOL]" in l})
            tally[(outc, bool(ob))] += 1
            if ob: hits.append((box, r, seq, outc, ob))
            w.write(f"{'x'.join(map(str, box))}\t{r}\t{seq}\t{outc}\t{' | '.join(ob)}\n")
print(dict(tally)); print("sequences reaching an [STARTSOL] line:", len(hits))
for h in hits[:20]: print(h)
