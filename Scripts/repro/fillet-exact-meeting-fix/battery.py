#!/usr/bin/env python3
"""Before/after battery: every sweep.py box case, baseline kernel against patched, one process per case.

  battery.py <outdir> <fprobe_baseline> <fprobe_patched>

Reuses sweep.py's case table (the ten box cases C1..C10 and their radius lists). Writes
<outdir>/battery.tsv and prints the verdict counts. A row is "regressed" if a case that was
valid at baseline is not valid, or not identical in volume to 1e-9, afterwards; "newly valid" if
it was IsDone=false (or done and invalid) and is now valid; "newly invalid" if it was IsDone=false
and is now done but invalid (the outcome the patch must never produce).
"""
import sys, os, subprocess, re
out, BASE, PATCH = sys.argv[1], sys.argv[2], sys.argv[3]
sys.argv = [sys.argv[0], out, "-", "-"]
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "sweep.py")).read()
ns = {}
exec(src.split("def run(")[0].replace("rows = open", "#"), ns)
CASES, radii, midpoints_all = ns["CASES"], ns["radii"], ns["midpoints_all"]
os.makedirs(out, exist_ok=True)

def run(cmd, timeout=90):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, start_new_session=True)
    except subprocess.TimeoutExpired:
        return {"o": "TIMEOUT", "vol": None, "faces": None}
    ls = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    if not ls:
        return {"o": "NORESULT(rc=%d)" % p.returncode, "vol": None, "faces": None}
    l = ls[0]
    if "SIGNAL" in l: return {"o": "SIGNAL", "vol": None, "faces": None}
    if "exception" in l: return {"o": "exception", "vol": None, "faces": None}
    kv = dict(t.split("=") for t in l.split()[2:] if "=" in t)
    if kv["done"] == "0": return {"o": "false", "vol": None, "faces": None}
    return {"o": "valid" if kv["valid"] == "1" else "INVALID", "vol": float(kv["vol"]), "faces": int(kv["faces"])}

w = open(os.path.join(out, "battery.tsv"), "w")
w.write("case\tmode\tlabel\tradius\tbase\tbase_vol\tbase_faces\tpatched\tpatched_vol\tpatched_faces\tverdict\n")
tally = {}
for name, (box, mids, crits, note) in CASES.items():
    mids = mids or midpoints_all(box)
    modes = ["add", "add2"] + (["seq"] if len(mids) == 2 or name.startswith("C10") else [])
    for crit in crits:
        for label, r in radii(crit):
            args = [str(v) for v in box] + [repr(r)] + [",".join(map(str, m)) for m in mids]
            for mode in modes:
                b = run([BASE, mode] + args); p = run([PATCH, mode] + args)
                if b["o"] == "valid":
                    v = "same" if p["o"] == "valid" and abs(p["vol"] - b["vol"]) <= 1e-9 and p["faces"] == b["faces"] else "REGRESSED"
                elif p["o"] == "valid": v = "newly-valid"
                elif p["o"] == b["o"]: v = "unchanged"
                elif p["o"] == "INVALID" and b["o"] == "false": v = "NEWLY-INVALID"
                else: v = "changed"
                tally[v] = tally.get(v, 0) + 1
                w.write("\t".join(str(x) for x in [name, mode, label, repr(r), b["o"], b["vol"], b["faces"], p["o"], p["vol"], p["faces"], v]) + "\n"); w.flush()
print(tally)
