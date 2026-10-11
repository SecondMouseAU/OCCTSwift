#!/usr/bin/env python3
"""The Swift-side cross-check: the sweep's cases through the public API and the #3200 guard (swift-harness/combswift).

  crosscheck.py <cprobe> <combswift> <sweep.csv> <out.csv> [--sample N]

For each selected case: write the input as a BREP with cprobe, map the case's edge and face points to the 0-based indices
`cprobe list` prints, run combswift, and compare with the sweep row: the API must answer a shape exactly when the builder was done
and BRepCheck-valid (the guard), with the same volume. Disagreements are printed and written."""
import csv, os, random, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

PROBE, SWIFT, SWEEP, OUT = sys.argv[1:5]
N = int(sys.argv[sys.argv.index("--sample") + 1]) if "--sample" in sys.argv else 300
rows = list(csv.DictReader(open(SWEEP)))
random.seed(7)
chosen = [r for r in rows if r["region"] == "unamb" or r["cls"] == "INVALID"]
rest = [r for r in rows if r not in chosen]
chosen += random.sample(rest, min(N, len(rest)))
tmp = tempfile.mkdtemp(prefix="crosscheck-")
lists = {}


def listing(spec):
    if spec not in lists:
        out = subprocess.run([PROBE, "list", spec], capture_output=True, text=True).stdout.splitlines()
        E, F = {}, {}
        for l in out:
            t = l.split()
            (E if t[0] == "E" else F)[int(t[1])] = tuple(map(float, t[2:5]))
        lists[spec] = (E, F)
    return lists[spec]


def near(table, p):
    return min(table, key=lambda i: sum((a - b) ** 2 for a, b in zip(table[i], p)))


def pt(s):
    return tuple(map(float, s.split(",")))


def one(r):
    spec = r["shape"]
    E, F = listing(spec)
    brep = os.path.join(tmp, "shape%d.brep" % (abs(hash(spec)) % 10 ** 8))
    if not os.path.exists(brep):
        subprocess.run([PROBE, "brep", spec, brep], check=True)
    a = r["args"].split()
    op = a[0]
    if op == "fillet":
        cmd = ["fillet", a[1], ",".join(str(near(E, pt(p))) for p in a[2:])]
    elif op == "chamfer_sym":
        if r["subset"] in ("all12",):
            cmd = ["chamfer_all", a[1]]
        else:
            top = near(F, (0, 0, 0)) if False else None
            # symmetric chamfer on a subset: the two-distance API with d1 = d2 and the first face found next to the edge is not
            # reachable by point, so use the face whose centre is nearest the edge's middle
            cmd = ["chamfer2m"]
            for p in a[2:]:
                e = near(E, pt(p))
                f = min(F, key=lambda i: sum((x - y) ** 2 for x, y in zip(F[i], E[e])))
                cmd.append("%d:%d:%s:%s" % (e, f, a[1], a[1]))
    elif op == "chamfer2m":
        cmd = ["chamfer2m"]
        for t in a[1:]:
            d1, d2, ef = t.split(":")
            e, f = ef.split("@")
            cmd.append("%d:%d:%s:%s" % (near(E, pt(e)), near(F, pt(f)), d1, d2))
    else:
        return None
    try:
        p = subprocess.run([SWIFT, brep] + cmd, capture_output=True, text=True, timeout=120)
        line = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
        res = line[0] if line else "RESULT swift=NORESULT"
    except subprocess.TimeoutExpired:
        res = "RESULT swift=TIMEOUT"
    kernel_ok = r["done"] == "1" and r["valid"] == "1"
    swift_shape = "swift=shape" in res
    vol = None
    if swift_shape:
        vol = float(res.split("vol=")[1].split()[0])
    agree = (kernel_ok == swift_shape) and (not swift_shape or abs(vol - float(r["vol"])) <= 1e-6 * max(1.0, abs(vol)))
    return dict(id=r["id"], family=r["family"], subset=r["subset"], op=r["op"], fraction=r["fraction"], cprobe_cls=r["cls"], swift=res[7:], agree=int(agree))


with ThreadPoolExecutor(6) as ex:
    out = [o for o in ex.map(one, chosen) if o]
with open(OUT, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
    w.writeheader()
    w.writerows(out)
bad = [o for o in out if not o["agree"]]
print(f"{len(out)} cases through the public API, {len(out) - len(bad)} agree with the sweep, {len(bad)} disagree")
for o in bad[:40]:
    print(o)
