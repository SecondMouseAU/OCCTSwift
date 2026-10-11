#!/usr/bin/env python3
"""The fillet / chamfer comb: shapes x edge subsets x radii (as fractions of the smallest face width) x operation.

  sweep.py <cprobe> <label> <out.csv> [--only family,...] [--jobs N]

One process per case (a kernel crash is uncatchable), a per-case timeout, the outcome class, and the reference volume from
comb_oracle.py where the case is in the unambiguous regime (every filleted edge keeps both its faces, no two fillets share one).
The bridge guard (`occtBlendResultIsValid`, #3200) is BRepCheck_Analyzer::IsValid on a done result, so a done-but-invalid answer is
what the Swift API turns into nil; the sweep records it separately from a declined one.

Outcome classes (column `cls`):
  OK            done, valid, one solid, volume equals the reference
  OK-unref      done, valid, one solid, no reference (policy region or no oracle) and the volume is sane
  DECLINED      IsDone() false (or a C++ exception out of the builder)
  INVALID       done but BRepCheck-invalid: the guard answers nil
  WRONG-VOL     done, valid, one solid, but the volume differs from the reference
  SANITY        done, valid, but not one solid, or removes nothing / everything
  TIMEOUT / SIGNAL / NORESULT   the process hung or died
"""
import csv, math, os, subprocess, sys, itertools, time
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fillet-pivot-edges"))
import comb_oracle as co
import oracle as pivot

FRACTIONS = [0.1, 0.25, 0.4, 0.5, 0.6, 0.9, 1.0, 1.1, 1.5, 2.0, 3.0, 5.0]
TOL = 2e-4                       # of the volume of the input; the oracle's own grid error is below 1e-4 at this spacing
TIMEOUT = 60


def fmt(p):
    return "%.9g,%.9g,%.9g" % tuple(p)


class Case:
    def __init__(self, **kw):
        self.__dict__.update(kw)


# ---------------------------------------------------------------- references
def pivot_pair_area(w, h, r1, r2):
    import numpy as np
    n = 400000
    xs = (np.arange(n) + .5) / n * w
    d = np.zeros(n)
    for r, left in ((r1, True), (r2, False)):
        cd = pivot.corner(w, h, r)
        if cd is None:
            return None
        cu, cv, q1, q2 = cd["centre"][0], cd["centre"][1], cd["q1"], cd["q2"]
        t = xs if left else w - xs
        v = cv - np.sqrt(np.maximum(r * r - (t - cu) ** 2, 0.0))
        d = np.maximum(d, np.where(t < q1, np.clip(v, 0.0, q2), 0.0))
    return float(d.sum() * (w / n))


def box_cases(out, dims, tag):
    X, Y, Z = dims
    m = min(dims)
    V0 = X * Y * Z
    spec = f"box:{X:g},{Y:g},{Z:g}"
    subsets = {
        "single": [(1, 0, 1)],
        "opposite": [(1, 0, 1), (1, 1, 1)],
        "diagonal": [(1, 0, 1), (1, 1, 0)],
        "adjacent": [(1, 0, 1), (0, 0, 1)],
        "vertex3": [(0, 0, 1), (1, 0, 1), (2, 0, 0)],
        "topface": [(0, 0, 1), (0, 1, 1), (1, 0, 1), (1, 1, 1)],
        "all12": co.box_edges(),
    }
    topfaces = {"single", "opposite", "adjacent", "topface"}
    face_pt = (X / 2, Y / 2, Z)
    for sname, edges in subsets.items():
        rmax = co.r_max_unambiguous(dims, edges)
        vcount = {}
        for e in edges:
            for v in co.edge_vertices(e):
                vcount[v] = vcount.get(v, 0) + 1
        has3 = any(k == 3 for k in vcount.values())
        for op in ("fillet", "chamfer_sym", "chamfer2"):
            if op == "chamfer2" and sname not in topfaces:
                continue
            for f in FRACTIONS:
                p = f * m
                lim = min(rmax, m / 2) if (has3 and op != "fillet") else rmax    # the triangular corner of three chamfers needs 2d <= m
                region = "unamb" if p <= lim + 1e-12 else "policy"
                pts = [fmt(co.edge_mid(dims, e)) for e in edges]
                if op == "fillet":
                    args = ["fillet", repr(p)] + pts
                    d1, d2 = p, p
                elif op == "chamfer_sym":
                    args = ["chamfer_sym", repr(p)] + pts
                    d1, d2 = p, p
                else:
                    d1, d2 = p, p / 2
                    args = ["chamfer2m"] + ["%r:%r:%s@%s" % (d1, d2, pt, fmt(face_pt)) for pt in pts]
                ref, rk = None, "none"
                if region == "unamb":
                    h = m / 128
                    if op == "fillet":
                        rem = co.box_removed_grid(dims, edges, "f", (p,), h)
                    else:
                        # leg on the face normal to b (lb) is d2 (the wall) and on the face normal to c (lc, the top face) is d1
                        rem = co.box_removed_grid(dims, edges, "c", [(d2, d1) if op == "chamfer2" else (p, p)] * len(edges), h)
                    ref, rk = V0 - rem, "grid"
                elif op == "fillet" and sname == "single":
                    cd = pivot.corner(X, Z, p)
                    if cd:
                        ref, rk = V0 - cd["area"] * Y, "pivot-oracle"
                elif op == "fillet" and sname == "opposite":
                    a = pivot_pair_area(X, Z, p, p)
                    if a is not None:
                        ref, rk = V0 - a * Y, "pivot-oracle"
                out.append(Case(family=f"box{tag}", shape=spec, dims=dims, subset=sname, op=op, f=f, param=p, region=region,
                                v0=V0, ref=ref, refkind=rk, args=args, concave=False))


def cylinder_cases(out, R=5.0, H=10.0):
    m = min(R, H)
    V0 = math.pi * R * R * H
    spec = f"cyl:{R:g},{H:g}"
    for sname, pts, nr in (("toprim", [(0, 0, H)], 1), ("bothrims", [(0, 0, H), (0, 0, 0)], 2)):
        rmax = min(R, H) if nr == 1 else min(R, H / 2)
        for op in ("fillet", "chamfer_sym"):
            for f in FRACTIONS:
                p = f * m
                region = "unamb" if p <= rmax + 1e-12 else "policy"
                ref, rk = None, "none"
                if region == "unamb":
                    rem = nr * co.rim_removed(R, p, "f" if op == "fillet" else "c", p)
                    ref, rk = V0 - rem, "pappus"
                out.append(Case(family="cylinder", shape=spec, dims=(R, H), subset=sname, op=op, f=f, param=p, region=region, v0=V0,
                                ref=ref, refkind=rk, args=[op, repr(p)] + [fmt(q) for q in pts], concave=False))


def plate_cases(out, X=20.0, Y=20.0, T=4.0, Rh=3.0):
    m = T
    V0 = X * Y * T - math.pi * Rh * Rh * T
    spec = f"plate:{X:g},{Y:g},{T:g},{Rh:g}"
    cx, cy = X / 2, Y / 2
    outer_top = [(cx, 0, T), (cx, Y, T), (0, cy, T), (X, cy, T)]
    outer_bot = [(cx, 0, 0), (cx, Y, 0), (0, cy, 0), (X, cy, 0)]
    outer_vert = [(0, 0, T / 2), (X, 0, T / 2), (0, Y, T / 2), (X, Y, T / 2)]
    hole_top, hole_bot = (cx, cy, T), (cx, cy, 0)
    ring = min(cx, cy) - Rh
    sets = {
        "holetop": ([hole_top], [], 1),
        "holeboth": ([hole_top, hole_bot], [], 2),
        "outertop": ([], outer_top, 0),
        "topall": ([hole_top], outer_top, 1),
        "all": ([hole_top, hole_bot], outer_top + outer_bot + outer_vert, 2),
    }
    for sname, (holes, outers, nh) in sets.items():
        both_faces = len(holes) == 2 or (sname == "all")
        rmax = T / 2 if both_faces else T
        if holes and outers:
            rmax = min(rmax, ring / 2)
        elif holes:
            rmax = min(rmax, ring)
        if outers:
            rmax = min(rmax, min(cx, cy) if len(outers) == 4 and sname not in ("all", "topall") else min(cx, cy) / 1)
            if len(outers) >= 4:
                rmax = min(rmax, cx)         # opposite outer edges share the 20 wide face
        for op in ("fillet", "chamfer_sym"):
            for f in FRACTIONS:
                p = f * m
                region = "unamb" if p <= rmax + 1e-12 else "policy"
                ref, rk = None, "none"
                if region == "unamb":
                    # outer edges on the plain box (the hole is far from them), the hole rims by Pappus
                    outer_edges = []
                    for q in outers:
                        for e in co.box_edges():
                            if max(abs(a - b) for a, b in zip(co.edge_mid((X, Y, T), e), q)) < 1e-9:
                                outer_edges.append(e)
                    rem = 0.0
                    if outer_edges:
                        if op == "fillet":
                            rem += co.box_removed_grid((X, Y, T), outer_edges, "f", (p,), T / 100)
                        else:
                            rem += co.box_removed_grid((X, Y, T), outer_edges, "c", [(p, p)] * len(outer_edges), T / 100)
                    rem += nh * co.hole_rim_removed(Rh, p, "f" if op == "fillet" else "c", p)
                    ref, rk = V0 - rem, "grid+pappus"
                pts = [fmt(q) for q in holes + outers] if sname != "all" else [fmt(q) for q in holes + outers]
                out.append(Case(family="plate-hole", shape=spec, dims=(X, Y, T, Rh), subset=sname, op=op, f=f, param=p, region=region,
                                v0=V0, ref=ref, refkind=rk, args=[op, repr(p)] + pts, concave=False))


def extrusion_cases(out, name, pts, h, rects, top_rmax):
    """A rectilinear polygon (counter-clockwise) extruded h."""
    spec = "poly:%g;%s" % (h, ";".join("%g,%g" % p for p in pts))
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n)) / 2
    V0 = area * h
    segs = [(pts[i], pts[(i + 1) % n]) for i in range(n)]
    seglen = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in segs]
    topmid = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, h) for a, b in segs]
    vert = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        cross = (p1[0] - p0[0]) * (p2[1] - p1[1]) - (p1[1] - p0[1]) * (p2[0] - p1[0])
        vert.append(dict(pt=(p1[0], p1[1], h / 2), concave=cross < 0, walls=(seglen[i - 1], seglen[i])))
    m = min(min(seglen), h, 6.0)
    m = min(w for w in [h] + [r[2] - r[0] for r in rects] + [r[3] - r[1] for r in rects] if w > 0)
    convex_v = [v for v in vert if not v["concave"]]
    concave_v = [v for v in vert if v["concave"]]
    sets = {
        "top-single": dict(top=[0], vert=[], rmax=min(h, m)),
        "top-outline": dict(top=list(range(n)), vert=[], rmax=top_rmax),
        "vert-convex-single": dict(top=[], vert=[convex_v[0]], rmax=min(min(convex_v[0]["walls"]), m)),
        "vert-concave-single": dict(top=[], vert=concave_v[:1], rmax=min(concave_v[0]["walls"])),
        "vert-all": dict(top=[], vert=vert, rmax=min(min(seglen) / 2, 1e9)),
        "all": dict(top=list(range(n)), vert=vert, rmax=0.0, noref=True),      # top outline, verticals and bottom outline
    }
    bottom = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0.0) for a, b in segs]
    for sname, s in sets.items():
        for op in ("fillet", "chamfer_sym"):
            for f in FRACTIONS:
                p = f * m
                region = "unamb" if (p <= s["rmax"] + 1e-12 and not s.get("noref")) else "policy"
                ref, rk = None, "none"
                reentrant_top = bool(concave_v) and len(s["top"]) == n
                if region == "unamb" and reentrant_top:
                    # at a re-entrant plan corner the kernel matches none of three readings (two strips, a patch around the vertex,
                    # two extended strips): the vertex region is a convention, not a defect, so no reference is claimed
                    ref, rk = None, "ambiguous-reentrant-corner"
                elif region == "unamb":
                    rem = 0.0
                    if s["top"]:
                        sg = [segs[i] for i in s["top"]]
                        if op == "fillet":
                            rem += co.extrusion_top_removed(rects, sg, h, "f", (p,), m / 100, len(sg) == n)
                        else:
                            rem += co.extrusion_top_removed(rects, sg, h, "c", (p, p), m / 100, len(sg) == n)
                    unit = (co.fillet_area(p) if op == "fillet" else p * p / 2) * h
                    for v in s["vert"]:
                        rem += -unit if v["concave"] else unit
                    ref, rk = V0 - rem, "grid"
                pts_sel = [fmt(topmid[i]) for i in s["top"]] + [fmt(v["pt"]) for v in s["vert"]]
                if sname == "all":
                    pts_sel += [fmt(q) for q in bottom]
                out.append(Case(family=name, shape=spec, dims=(h,), subset=sname, op=op, f=f, param=p, region=region, v0=V0, ref=ref,
                                refkind=rk, args=[op, repr(p)] + pts_sel, concave=bool(concave_v) and any(v["concave"] for v in s["vert"])))


def model_cases(out, path):
    # the #2881 model: no oracle, outcome only. Edge 13 (index 12) across the vertex-snap window, plus the neighbours.
    spec = f"brep:{path}"
    lst = subprocess.run([PROBE, "list", spec], capture_output=True, text=True).stdout.splitlines()
    edges = {}
    for l in lst:
        t = l.split()
        if t[0] == "E":
            edges[int(t[1])] = (float(t[2]), float(t[3]), float(t[4]))
    pts = list(edges.values())
    uniq = {i: all(max(abs(a - b) for a, b in zip(pts[i], q)) > 1e-7 for j, q in enumerate(pts) if j != i) for i in range(len(pts))}
    radii = [0.3, 0.6, 1.0, 1.4, 1.4982, 1.4983, 1.4985, 1.49853, 1.4986, 1.499, 1.5, 1.500000002, 1.5001, 1.501, 1.5018, 1.5019, 1.52, 1.6, 2.0, 3.0]
    for op in ("fillet", "chamfer_sym"):
        for r in radii:
            out.append(Case(family="model2881", shape=spec, dims=(), subset="edge13", op=op, f=r, param=r, region="model", v0=None, ref=None,
                            refkind="none", args=[op, repr(r), fmt(edges[12])], concave=False))
    for ei in sorted(edges):
        if not uniq.get(ei - 0, True):
            continue
        for op in ("fillet", "chamfer_sym"):
            for r in (0.3, 1.0, 2.0):
                out.append(Case(family="model2881", shape=spec, dims=(), subset=f"edge{ei + 1}", op=op, f=r, param=r, region="model", v0=None,
                                ref=None, refkind="none", args=[op, repr(r), fmt(edges[ei])], concave=False))


def _box_job(dims):
    out = []
    box_cases(out, dims, "-%gx%gx%g" % dims)
    return out


def all_cases(only=None):
    out = []
    import multiprocessing
    with multiprocessing.get_context("fork").Pool(5) as pool:
        for part in pool.map(_box_job, [(10, 10, 10), (4, 10, 6), (20, 20, 2), (30, 10, 5), (5, 5, 40)]):
            out += part
    cylinder_cases(out)
    plate_cases(out)
    extrusion_cases(out, "L-extrusion", [(0, 0), (20, 0), (20, 6), (6, 6), (6, 20), (0, 20)], 8.0, [(0, 0, 20, 6), (0, 0, 6, 20)], 3.0)
    extrusion_cases(out, "U-extrusion", [(0, 0), (24, 0), (24, 18), (18, 18), (18, 6), (6, 6), (6, 18), (0, 18)], 8.0,
                    [(0, 0, 24, 6), (0, 0, 6, 18), (18, 0, 24, 18)], 3.0)
    model_cases(out, os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "model2881.brep")))
    if only:
        out = [c for c in out if any(c.family.startswith(o) for o in only)]
    for i, c in enumerate(out):
        c.id = i
    return out


# ---------------------------------------------------------------- running and classifying
def run_one(c):
    cmd = [PROBE, "run", c.shape] + c.args
    t0 = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT, start_new_session=True)
    except subprocess.TimeoutExpired:
        return dict(done="TIMEOUT", valid=0, solids=0, faces=0, vol=0.0, ms=(time.time() - t0) * 1000, note="timeout %ds" % TIMEOUT)
    ls = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    if not ls:
        return dict(done="NORESULT", valid=0, solids=0, faces=0, vol=0.0, ms=0, note="rc=%d" % p.returncode)
    head, _, note = ls[0].partition(" note=")
    kv = dict(t.split("=", 1) for t in head.split()[1:])
    kv["note"] = note or "-"
    return dict(done=kv["done"], valid=int(kv["valid"]), solids=int(kv["solids"]), faces=int(kv["faces"]), vol=float(kv["vol"]),
                ms=float(kv["ms"]), note=kv.get("note", "-"))


def classify(c, r):
    d = r["done"]
    if d == "TIMEOUT":
        return "TIMEOUT"
    if d == "NORESULT":
        return "NORESULT"
    if d.startswith("SIGNAL"):
        return "SIGNAL"
    if d == "0":
        return "DECLINED"
    if not r["valid"]:
        return "INVALID"
    v = r["vol"]
    if r["solids"] != 1:
        return "SANITY"
    if c.ref is not None:
        scale = c.v0
        return "OK" if abs(v - c.ref) <= TOL * scale else "WRONG-VOL"
    if c.v0 is not None:
        # no reference: it must remove material and not all of it; concave-edge sets may add
        if v <= 0 or v >= c.v0 * (1 + 1e-9) and not c.concave or (c.concave and v > 2 * c.v0):
            return "SANITY"
    elif v <= 0:
        return "SANITY"
    return "OK-unref"


def main():
    global PROBE
    PROBE, label, outpath = sys.argv[1:4]
    only = None
    jobs = 6
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1].split(",")
    if "--jobs" in sys.argv:
        jobs = int(sys.argv[sys.argv.index("--jobs") + 1])
    cache = os.path.join(os.path.dirname(os.path.abspath(outpath)), "cases.pkl")
    import pickle
    if os.path.exists(cache) and "--regen" not in sys.argv:
        cases = pickle.load(open(cache, "rb"))
        if only:
            cases = [c for c in cases if any(c.family.startswith(o) for o in only)]
    else:
        cases = all_cases(None)
        pickle.dump(cases, open(cache, "wb"))
        if only:
            cases = [c for c in cases if any(c.family.startswith(o) for o in only)]
    print(f"{len(cases)} cases on {label}", flush=True)
    t0 = time.time()
    rows = []
    with ThreadPoolExecutor(jobs) as ex:
        for c, r in zip(cases, ex.map(run_one, cases)):
            cls = classify(c, r)
            dv = (r["vol"] - c.ref) if (c.ref is not None and r["done"] == "1") else ""
            rows.append(dict(id=c.id, kernel=label, family=c.family, shape=c.shape, subset=c.subset, op=c.op, fraction=c.f,
                             param="%.9g" % c.param, region=c.region, v0=c.v0, ref=c.ref, refkind=c.refkind, done=r["done"], valid=r["valid"],
                             solids=r["solids"], faces=r["faces"], vol=r["vol"], dvol=dv, ms=int(r["ms"]), note=r["note"], cls=cls,
                             args=" ".join(c.args)))
            if len(rows) % 100 == 0:
                print(len(rows), "done", int(time.time() - t0), "s", flush=True)
    with open(outpath, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    from collections import Counter
    print(Counter((r["region"], r["cls"]) for r in rows))
    print("done", int(time.time() - t0), "s")


if __name__ == "__main__":
    main()
