#!/usr/bin/env python3
"""Validate every newly successful exact-meeting case against the analytic oracle (oracle.py).

  validate.py <fprobe_baseline> <fprobe_patched> [outfile]

For each case: baseline outcome, then the patched probe three times (determinism), reporting
BRepCheck validity, volume against the oracle (tolerance 1e-3), face count, closed shell
(no free or non-manifold edge, one solid) and BRepMesh_IncrementalMesh tessellation.
Exit status 1 if any newly successful case fails any of those: done-but-invalid is worse than the
clean IsDone=false the baseline gives.
"""
import math, os, random, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle

BASE, PATCH = sys.argv[1], sys.argv[2]
OUT = open(sys.argv[3], "w") if len(sys.argv) > 3 else sys.stdout

def probe(exe, mode, box, r, mids, env=None):
    e = dict(os.environ, CHECKS="1", MESH="1"); e.update(env or {})
    args = [exe, mode] + [str(v) for v in box] + [repr(r)] + mids
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=90, env=e, start_new_session=True)
    except subprocess.TimeoutExpired:
        return {"o": "TIMEOUT"}
    d = {"o": "none"}
    for l in p.stdout.splitlines():
        if l.startswith("RESULT"):
            kv = dict(t.split("=") for t in l.split()[2:] if "=" in t)
            d = {"o": "false" if kv.get("done") == "0" else ("valid" if kv["valid"] == "1" else "INVALID"),
                 "vol": float(kv["vol"]), "faces": int(kv["faces"])}
        elif "CHECKS" in l:
            kv = dict(t.split("=") for t in l.split()[1:]); d.update({k: int(v) for k, v in kv.items()})
        elif "MESH" in l:
            kv = dict(t.split("=") for t in l.split()[1:]); d.update({"mesh_ok": kv["isdone"] == "1" and kv["faces_without_triangulation"] == "0"})
    return d

def cs(w, h, L, r1, r2=None):
    """Oracle volume for fillets r1, r2 (r1 + r2 <= w) on opposite edges of a w x h face, length L."""
    r2 = r1 if r2 is None else r2
    return w * h * L - L * (1 - math.pi / 4) * (r1 * r1 + r2 * r2)

# (label, mode, box, r, midpoints, oracle volume, env)
CASES = []
def add(label, box, r, mids, vol, mode="add", env=None):
    CASES.append((label, mode, box, r, mids, vol, env or {}))

add("C1 4x10x6 r=2 (forum case)",        (4, 10, 6), 2.0, ["0,5,6", "4,5,6"], cs(4, 6, 10, 2))
add("C1 4x10x6 r=2-1ulp",                (4, 10, 6), math.nextafter(2.0, 0), ["0,5,6", "4,5,6"], cs(4, 6, 10, 2))
add("C1 add2 (FreeCAD Add(r,r,e))",      (4, 10, 6), 2.0, ["0,5,6", "4,5,6"], cs(4, 6, 10, 2), mode="add2")
add("C2 4x10x6 edges along X, w=10 r=5", (4, 10, 6), 5.0, ["2,0,6", "2,10,6"], cs(10, 6, 4, 5))
add("C3 4x10x6 side face w=6 r=3",       (4, 10, 6), 3.0, ["0,5,0", "0,5,6"], cs(6, 4, 10, 3))
add("C9 cube 4 r=2",                     (4, 4, 4), 2.0, ["0,2,4", "4,2,4"], cs(4, 4, 4, 2))
add("vertical edges 4x10x6 r=2",         (4, 10, 6), 2.0, ["0,0,3", "4,0,3"], cs(4, 10, 6, 2) if False else cs(4, 10, 6, 2) )
add("box 10x4x6 edges along X, r=2",     (10, 4, 6), 2.0, ["5,0,6", "5,4,6"], cs(4, 6, 10, 2))
add("scaled x10  40x100x60 r=20",        (40, 100, 60), 20.0, ["0,50,60", "40,50,60"], cs(40, 60, 100, 20))
add("scaled /100 .04x.1x.06 r=.02",      (0.04, 0.1, 0.06), 0.02, ["0,0.05,0.06", "0.04,0.05,0.06"], cs(0.04, 0.06, 0.1, 0.02))
add("unequal r1=1.5 r2=2.5 (r1+r2=w)",   (4, 10, 6), 1.0, ["1.5:0,5,6", "2.5:4,5,6"], cs(4, 6, 10, 1.5, 2.5))
add("unequal r1=1 r2=3",                 (4, 10, 6), 1.0, ["1:0,5,6", "3:4,5,6"], cs(4, 6, 10, 1, 3))
add("unequal r1=.5 r2=3.5",              (4, 10, 6), 1.0, ["0.5:0,5,6", "3.5:4,5,6"], cs(4, 6, 10, 0.5, 3.5))
add("rot z 30 deg",                      (4, 10, 6), 2.0, ["0,5,6", "4,5,6"], cs(4, 6, 10, 2), env={"ROT": "0,0,1,30,0,0,0"})
add("rot x/y 90 deg",                    (4, 10, 6), 2.0, ["0,5,6", "4,5,6"], cs(4, 6, 10, 2), env={"ROT": "1,1,0,90,0,0,0"})

# Vertical edge pair of a 4x10x6 box: the vertical edges at (0,0) and (4,0) lie on the y=0 face, width 4, length 6.
CASES[6] = ("vertical edges 4x10x6 r=2", "add", (4, 10, 6), 2.0, ["0,0,3", "4,0,3"], cs(4, 10, 6, 2), {})

bad = 0
def say(s): print(s, file=OUT); OUT.flush()
say("case\tbaseline\tpatched\tvalid\tvol\toracle\t|dvol|\tfaces\tclosed\tmesh\tdeterministic")
for label, mode, box, r, mids, ov, env in CASES:
    b = probe(BASE, mode, box, r, mids, env)
    runs = [probe(PATCH, mode, box, r, mids, env) for _ in range(3)]
    p = runs[0]
    det = all(x.get("o") == p.get("o") and x.get("faces") == p.get("faces") and abs(x.get("vol", 0) - p.get("vol", 0)) < 1e-12 for x in runs)
    ok = None
    if p["o"] == "valid":
        closed = p.get("free_edges") == 0 and p.get("non_manifold_edges") == 0 and p.get("solids") == 1
        dv = abs(p["vol"] - ov)
        ok = closed and dv < 1e-3 and dv <= 1e-6 * ov and p.get("mesh_ok", False) and det
        say(f"{label}\t{b['o']}\t{p['o']}\tyes\t{p['vol']:.9f}\t{ov:.9f}\t{dv:.2e}\t{p['faces']}\t{closed}\t{p.get('mesh_ok')}\t{det}")
        if not ok: bad += 1
    else:
        say(f"{label}\t{b['o']}\t{p['o']}\t-\t-\t{ov:.9f}\t-\t-\t-\t-\t{det}")
        if p["o"] == "INVALID": bad += 1
# random rigid motions: exact meeting only up to rounding noise. Count outcomes (a clean failure is acceptable, INVALID is not).
random.seed(7)
tally = {}
for i in range(40):
    ax = [random.uniform(-1, 1) for _ in range(3)]; dg = random.uniform(1, 179); t = [random.uniform(-50, 50) for _ in range(3)]
    env = {"ROT": "%g,%g,%g,%.6f,%g,%g,%g" % (*ax, dg, *t)}
    p = probe(PATCH, "add", (4, 10, 6), 2.0, ["0,5,6", "4,5,6"], env)
    key = p["o"] + ("" if p["o"] != "valid" or abs(p["vol"] - cs(4, 6, 10, 2)) < 1e-3 else " WRONG-VOLUME")
    tally[key] = tally.get(key, 0) + 1
    if p["o"] == "INVALID" or "WRONG" in key: bad += 1
say("random rigid motions of the forum box at r = 2 (40): " + str(tally))
say("FAILED CASES: %d" % bad)
sys.exit(1 if bad else 0)
