#!/usr/bin/env python3
"""Validate every pivot-edge case against the analytic oracle (oracle.py), one process per run.

  validate.py <fprobe_patched> [outfile]

For each case: the patched probe three times (determinism), reporting BRepCheck validity, volume against the
oracle, face count, closed shell (no free or non-manifold edge, one solid), BRepMesh tessellation, and the
crease angles between neighbouring faces (0 = tangent). Exit status 1 if any case that answers done is not valid,
closed, tessellated, deterministic and within 1e-7 (relative) of the oracle volume.

A case is (label, mode, box (X, Y, Z), edges [(radius, midpoint)], oracle area). X is the width across the
filleted face, Y the length along the edges, Z the height. Midpoints name the edges.
"""
import math, os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle

PROBE = sys.argv[1]
OUT = open(sys.argv[2], "w") if len(sys.argv) > 2 else sys.stdout


def run(mode, box, edges, env=None):
    e = dict(os.environ, CHECKS="1", MESH="1", TANGENT="1")
    e.update(env or {})
    args = [PROBE, mode] + [repr(float(v)) for v in box] + ["1"] + [f"{r!r}:{m}" for r, m in edges]
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=120, env=e, start_new_session=True)
    except subprocess.TimeoutExpired:
        return {"o": "TIMEOUT", "creases": []}
    d = {"o": "none", "creases": []}
    for l in p.stdout.splitlines():
        if l.startswith("RESULT"):
            if "exception" in l or "SIGNAL" in l:
                d["o"] = "exception"
                continue
            kv = dict(t.split("=") for t in l.split()[2:] if "=" in t)
            d.update(o="false" if kv.get("done") == "0" else ("valid" if kv["valid"] == "1" else "INVALID"),
                     vol=float(kv["vol"]), faces=int(kv["faces"]))
        elif "CHECKS" in l:
            d.update({k: int(v) for k, v in (t.split("=") for t in l.split()[1:])})
        elif "MESH" in l:
            kv = dict(t.split("=") for t in l.split()[1:])
            d["mesh_ok"] = kv["isdone"] == "1" and kv["faces_without_triangulation"] == "0"
        elif "EDGE" in l:
            kv = dict(t.split("=") for t in l.split()[1:] if "=" in t)
            d["creases"].append((kv["types"], float(kv["min"]), float(kv["max"]), float(kv["length"])))
    return d


def depth_fn(w, h, r, left=True):
    """Removed depth across x for one fillet on the left (x = 0) or right (x = w) top edge, pivot rule included."""
    cd = oracle.corner(w, h, r)
    cu, cv, q1, q2 = cd["centre"][0], cd["centre"][1], cd["q1"], cd["q2"]

    def g(x):
        t = x if left else w - x
        v = cv - np.sqrt(np.maximum(r * r - (t - cu) ** 2, 0.0))
        return np.where(t < q1, np.clip(v, 0.0, q2), 0.0)
    return g


def area_add(w, h, rl, rr, n=4000000):
    """Removed area of simultaneous fillets on both top edges: the intersection of the rounded profiles, each
    with the pivot rule."""
    xs = (np.arange(n) + .5) / n * w
    d = np.zeros(n)
    for r, left in ((rl, True), (rr, False)):
        if r:
            d = np.maximum(d, depth_fn(w, h, r, left)(xs))
    return float(d.sum() * (w / n))


def area_single(w, h, r):
    return oracle.corner(w, h, r)["area"]


def area_seq(w, h, r1, r2):
    """Second fillet after the first: the top face left by the first (tangent at x = r1) is w - r1 wide."""
    a1 = oracle.corner(w, h, r1)
    assert a1["case"] == "tangent-tangent", "sequential oracle needs the first fillet to leave a top face"
    return a1["area"] + oracle.corner(w - r1, h, r2)["area"]


CASES = []


def case(label, mode, box, edges, area, env=None, length=None, angles=None):
    CASES.append(dict(label=label, mode=mode, box=box, edges=edges, area=area, env=env or {}, length=length or box[1], angles=angles))


W, L, H = 4.0, 10.0, 6.0
LEFT, RIGHT = "0,5,6", "4,5,6"
for r1, r2 in [(2, 2), (1.5, 2.5), (1, 3), (0.5, 3.5)]:
    case(f"A  r1={r1} r2={r2}", "add", (W, L, H), [(r1, LEFT), (r2, RIGHT)], lambda r1=r1, r2=r2: area_add(W, H, r1, r2), angles=lambda r1=r1, r2=r2: [] if r1 + r2 <= W else [180 - oracle.included_angle_ab(W, r1, r2)])
for r in [2.2, 2.5, 3.0, 3.5, 3.9]:
    case(f"B  r={r}", "add", (W, L, H), [(r, LEFT), (r, RIGHT)], lambda r=r: area_add(W, H, r, r), angles=lambda r=r: [180 - oracle.included_angle_ab(W, r, r)])
for r1, r2 in [(2, 2.5), (1, 3.5), (2.5, 3), (0.5, 3.9), (3.9, 0.5)]:
    case(f"B  r1={r1} r2={r2}", "add", (W, L, H), [(r1, LEFT), (r2, RIGHT)], lambda r1=r1, r2=r2: area_add(W, H, r1, r2), angles=lambda r1=r1, r2=r2: [180 - oracle.included_angle_ab(W, r1, r2)])
case("B  add2 r=3 (Add(r,r,e))", "add2", (W, L, H), [(3.0, LEFT), (3.0, RIGHT)], lambda: area_add(W, H, 3.0, 3.0))
for r in [4.0, 4.0000001, 4.5, 5.0, 6.0, 6.5]:
    case(f"C  single r={r}", "add", (W, L, H), [(r, LEFT)], lambda r=r: area_single(W, H, r), angles=lambda r=r: oracle.pivot_angles(W, H, r))
case("D1 plate 10x10x3, r=4 > h: pivot at the bottom edge", "add", (10.0, 10.0, 3.0), [(4.0, "0,5,3")], lambda: area_single(10, 3, 4.0))
case("D1 plate 10x10x3, r=5", "add", (10.0, 10.0, 3.0), [(5.0, "0,5,3")], lambda: area_single(10, 3, 5.0))
case("D2 box 4x10x3, r=4.5 > w and > h: both far edges", "add", (4.0, 10.0, 3.0), [(4.5, "0,5,3")], lambda: area_single(4, 3, 4.5))
case("D2 box 4x10x6, r=7 > (a^2+b^2)/(2a): both far edges", "add", (W, L, H), [(7.0, LEFT)], lambda: area_single(4, 6, 7.0))
case("D3 vertical edge, 4 x 10 face and 6 high, r=4.5", "add", (W, L, H), [(4.5, "0,0,3")], lambda: area_single(4, 10, 4.5), length=6.0)
case("D4 pair along X on the 10 wide face, r=7.5 > h", "add", (4.0, 10.0, 6.0), [(7.5, "2,0,6"), (7.5, "2,10,6")], lambda: area_add(10, 6, 7.5, 7.5), length=4.0)
for r1, r2 in [(2.0, 2.0), (2.0, 2.5), (3.0, 3.0), (1.0, 3.5)]:
    case(f"S  seq r1={r1} then r2={r2}", "seq", (W, L, H), [(r1, LEFT), (r2, RIGHT)], lambda r1=r1, r2=r2: area_seq(W, H, r1, r2))
case("B  scaled x10 40x100x60 r=30", "add", (40.0, 100.0, 60.0), [(30.0, "0,50,60"), (30.0, "40,50,60")], lambda: area_add(40, 60, 30.0, 30.0))
case("B  scaled /100 r=.03", "add", (0.04, 0.1, 0.06), [(0.03, "0,0.05,0.06"), (0.03, "0.04,0.05,0.06")], lambda: area_add(0.04, 0.06, 0.03, 0.03))
case("B  rotated 30 deg about z, r=3", "add", (W, L, H), [(3.0, LEFT), (3.0, RIGHT)], lambda: area_add(W, H, 3.0, 3.0), env={"ROT": "0,0,1,30,0,0,0"})
case("C  rotated 90 deg about (1,1,0), r=5", "add", (W, L, H), [(5.0, LEFT)], lambda: area_single(W, H, 5.0), env={"ROT": "1,1,0,90,0,0,0"})
case("B  cube 4 r=3 (C9)", "add", (4.0, 4.0, 4.0), [(3.0, "0,2,4"), (3.0, "4,2,4")], lambda: area_add(4, 4, 3.0, 3.0))
case("X  r > h on both, box 4x10x3, r=3.5", "add", (W, L, 3.0), [(3.5, "0,5,3"), (3.5, "4,5,3")], lambda: area_add(W, 3.0, 3.5, 3.5))
case("X  mixed r1=1, r2=4.5 > w", "add", (W, L, H), [(1.0, LEFT), (4.5, RIGHT)], lambda: area_add(W, H, 1.0, 4.5))

bad = 0


def say(s):
    print(s, file=OUT)
    OUT.flush()


say("case\toutcome\tvol\toracle\t|dvol|/V\tfaces\tclosed\tmesh\tdeterministic\ttangent_max_deg\tother_creases_deg")
for c in CASES:
    runs = [run(c["mode"], c["box"], c["edges"], c["env"]) for _ in range(3)]
    p = runs[0]
    det = all(x.get("o") == p.get("o") and x.get("faces") == p.get("faces") and abs(x.get("vol", 0) - p.get("vol", 0)) < 1e-12 for x in runs)
    if p["o"] != "valid":
        say(f"{c['label']}\t{p['o']}\t-\t-\t-\t-\t-\t-\t{det}\t-\t-")
        if p["o"] == "INVALID":
            bad += 1
        continue
    V0 = c["box"][0] * c["box"][1] * c["box"][2]
    area = c["area"]()
    ov = V0 - area * c["length"]
    dv = abs(p["vol"] - ov) / V0
    closed = p.get("free_edges") == 0 and p.get("non_manifold_edges") == 0 and p.get("solids") == 1 and p.get("shells") == 1
    Lk = c["length"]
    longE = [cr for cr in p["creases"] if cr[0] in ("(0,1)", "(1,0)", "(1,1)") and abs(cr[3] - Lk) < 1e-6 * Lk]
    tang = [cr[2] for cr in longE if cr[2] < 1.0]
    others = sorted(set(round(cr[2], 6) for cr in longE if cr[2] >= 1.0))
    exp = c["angles"]() if c["angles"] else None
    angle_ok = exp is None or (len(exp) == len(others) and all(abs(a - b) < 1e-5 for a, b in zip(sorted(exp), others)))
    ok = closed and p.get("mesh_ok", False) and det and dv < 1e-7 and angle_ok
    if not ok:
        bad += 1
    say(f"{c['label']}\t{'angles ok' if exp is not None and angle_ok else ('ANGLES WRONG ' + str(exp) if exp is not None else 'valid')}\t{p['vol']:.9f}\t{ov:.9f}\t{dv:.1e}\t{p['faces']}\t{closed}\t{p.get('mesh_ok')}\t{det}\t{max(tang, default=float('nan')):.2e}\t{others}")
say("FAILED CASES: %d" % bad)
sys.exit(1 if bad else 0)
