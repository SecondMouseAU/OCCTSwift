#!/usr/bin/env python3
"""Random polygon prisms for #3234: one or two corners of a random simple polygon (angles 15 to 345 degrees, convex and
concave) filleted with radii from 0.1 to 1.5 times the longest side, the kernel against the pivot rule (section.py).

  fuzzpoly.py <gprobe> [count] [seed]

One process per case. Verdicts: right (done, valid, volume = the rule to 1e-6), declined (IsDone false), WRONG (valid, other
volume), INVALID (done but BRepCheck or closure fails), SIGNAL/exception. Two corners are only drawn when both are convex
(the rule is the intersection of the rounded profiles; compared with an independent polygon intersection at 2e-4).
Prints the tally and every WRONG / INVALID row; exit 1 if there is one.
"""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import section as sec
import cases3234 as C
from shapely.geometry import Polygon

exe = sys.argv[1]
N = int(sys.argv[2]) if len(sys.argv) > 2 else 300
random.seed(int(sys.argv[3]) if len(sys.argv) > 3 else 5)


def rand_poly():
    while True:
        n = random.choice([4, 5, 6, 7])
        angs = sorted(random.uniform(0, 2 * math.pi) for _ in range(n))
        pts = [(round(math.cos(a) * random.uniform(3, 9), 3), round(math.sin(a) * random.uniform(3, 9), 3)) for a in angs]
        P = Polygon(pts)
        if not P.is_valid or P.area < 8:
            continue
        ok = True
        for i in range(n):
            a, b, c = pts[i - 1], pts[i], pts[(i + 1) % n]
            u, v = sec.unit(sec.sub(a, b)), sec.unit(sec.sub(c, b))
            ang = math.degrees(math.acos(max(-1, min(1, sec.dot(u, v)))))
            if ang < 15 or ang > 165 or sec.norm(sec.sub(a, b)) < 1.5:
                ok = False
        if ok:
            return pts


tally, bad = {}, []
for i in range(N):
    pts = rand_poly()
    toks = ["S", *pts[0]] + [t for p in pts[1:] for t in ("L", *p)]
    edges = sec.parse_path(toks)
    n = len(edges)
    longest = max(e.length() for e in edges)
    cand = list(range(n))
    random.shuffle(cand)
    k1 = cand[0]
    r1 = round(random.uniform(0.1, 1.5) * longest, 3)
    fil = [(r1, edges[k1].p1)]
    ed2, sol = sec.fillet_corner(edges, k1, r1)
    want = None if ed2 is None else 10.0 * sec.area(ed2)
    kind = "single"
    if random.random() < 0.4 and sol and sol["side"] > 0:
        k2 = cand[1]
        e1, e2 = edges[k2], edges[(k2 + 1) % n]
        if sec.cross(e1.tan_end(), e2.tan_start()) > 0 and (k2 - k1) % n not in (1, n - 1):
            r2 = round(random.uniform(0.1, 1.5) * longest, 3)
            s2 = sec.solve_corner(e1, e2, r2)
            a1 = sec.fillet_corner(edges, k2, r2)[0]
            if s2 and a1 is not None:
                # independent: polygon intersection of the two single results (arcs sampled)
                A = Polygon(sec.outline(ed2, 800)); B = Polygon(sec.outline(a1, 800))
                want = 10.0 * A.intersection(B).area
                fil.append((r2, edges[k2].p1)); kind = "pair"
    case = C.Case("f", "S", "f", "prism", toks, [fil[0]], L=10.0)
    args = ["prism", "10.0"] + [str(t) for t in toks] + ["--", "add"] + ["%r:%r,5.0,%r" % (r, V[0], V[1]) for r, V in fil]
    s, rc, _ = C.run(exe, args)
    res = C.parse_result(s)
    if want is None:
        cl = "norule:" + C.classify(res, 0.0)
        if cl.startswith("norule:right") or cl == "norule:wrong":
            cl = "norule:built"
    else:
        cl = C.classify(res, want) if kind == "single" else (C.classify(res, res["vol"] if res else 0) if res and abs(res["vol"] - want) < 2e-4 * want else ("wrong" if res and res["done"] else "declined"))
    cl = kind + " " + cl
    if res is None and s and not s.startswith("done"):
        cl = kind + " " + s.split()[0]
    tally[cl] = tally.get(cl, 0) + 1
    if "wrong" in cl.lower() or "INVALID" in cl or "SIGNAL" in cl or "exception" in cl or "built" in cl:
        bad.append((cl, toks, fil, want, s))
for k, v in sorted(tally.items()):
    print(f"{v:5d}  {k}")
for b in bad:
    print("BAD", b)
sys.exit(1 if bad else 0)
