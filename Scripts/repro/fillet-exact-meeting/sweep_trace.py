#!/usr/bin/env python3
"""Which OCCT function reports each failure? Runs the instrumented probe (fprobe linked ahead of the
override-compiled ChFi3d_Builder*.cxx from a clean V8_0_1 tree, see run.sh) over the sweep.py cases and
tallies every [TRACE]/[STARTSOL] line against the outcome.

  sweep_trace.py <outdir> <fprobe_trace>
"""
import sys, os, math, subprocess, collections, itertools
sys.argv_saved = sys.argv
out, PROBE = sys.argv[1], sys.argv[2]
sys.argv = [sys.argv[0], out, "-", "-"]          # sweep.py reads argv at import; reuse its case table only
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "sweep.py")).read()
ns = {}
exec(src.split("def run(")[0].replace("rows = open", "#"), ns)
CASES, radii, midpoints_all = ns["CASES"], ns["radii"], ns["midpoints_all"]
os.makedirs(out, exist_ok=True)
tally = collections.defaultdict(collections.Counter)
w = open(os.path.join(out, "trace.tsv"), "w"); w.write("case\tcrit\tlabel\tradius\tedges\toutcome\tfailure_lines\n")
def one(name, box, mids, crit, label, r):
    args = [str(v) for v in box] + [repr(r)] + [",".join(map(str, m)) for m in mids]
    try:
        p = subprocess.run([PROBE, "add"] + args, capture_output=True, text=True, timeout=60, start_new_session=True)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", []
    res = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    outc = "no-result(rc=%d)" % p.returncode if not res else ("SIGSEGV" if "SIGNAL 11" in res[0] else ("done" if "done=1" in res[0] else "IsDone=false"))
    if outc == "done" and "valid=0" in res[0]: outc = "done-INVALID"
    keep = sorted({l.split(": ", 1)[1] if "THREW" in l else l for l in p.stderr.splitlines()
                   if "THREW" in l or "[STARTSOL]" in l or "returned with done=false" in l or "TwoCornerbyInter return" in l})
    return outc, keep
for name, (box, mids, crits, note) in CASES.items():
    mids = mids or midpoints_all(box)
    for crit in crits:
        for label, r in radii(crit):
            outc, keep = one(name, box, mids, crit, label, r)
            w.write(f"{name}\t{crit}\t{label}\t{r!r}\t{len(mids)}\t{outc}\t{' | '.join(keep)}\n"); w.flush()
            tally[outc][" | ".join(keep) or "(no failure lines)"] += 1
# single edge, every edge of both boxes, radius at each face width, half of each and one ulp either side of each
for box in ((4, 10, 6), (4, 4, 4)):
    mids = midpoints_all(box)
    cs = sorted({d for d in box} | {d / 2 for d in box})
    for m in mids:
        for c in cs:
            for label, r in (("c-1ulp", math.nextafter(c, 0)), ("c", c), ("c+1ulp", math.nextafter(c, 1e9))):
                outc, keep = one("single", box, [m], c, label, r)
                w.write(f"single-{'x'.join(map(str, box))}\t{c}\t{label}\t{r!r}\t1\t{outc}\t{' | '.join(keep)}\n"); w.flush()
                tally[outc][" | ".join(keep) or "(no failure lines)"] += 1
with open(os.path.join(out, "tally.txt"), "w") as t:
    for outc, c in tally.items():
        for k, v in c.most_common():
            t.write(f"{v:5d}  {outc:14s}  {k}\n")
print("done")
