#!/usr/bin/env python3
"""Chamfer parity cases on the 4 x 10 x 6 box: the independent reference, and the kernel's answer.

Section looking along Y: X across the top face (w = 4), Z up (h = 6), extruded L = 10 along +Y. The two top edges along Y are
LEFT (x = 0, z = 6) and RIGHT (x = 4, z = 6). Every cut is given as (d1, d2): d1 is measured on the TOP face from the edge,
d2 on the WALL face (the left or right wall) from the edge. Where the case names the wall as the reference face the roles swap.

The reference is plain 2D geometry (Sutherland-Hodgman clipping of the box rectangle by half-planes), turned into a polygon that
the probe extrudes (`cprobe profile`), so nothing here touches the chamfer code. Two candidates for a distance that exceeds its
face, because what is right there is a design choice the maintainer has not made:

  H  the half-space reading. The chamfer is the plane through (d1 on the top, d2 on the wall), extended past the face and
     clipped by the box. Order of two chamfers does not matter (an intersection of half-spaces).
  P  the pivot reading, the analogue of the fillet rule. A face that runs out ends at its far edge, which becomes the pivot:
     the cut line passes through the far edge and keeps the distance that fits. Two chamfers at once are the intersection of
     each one's own pivot result; one after the other differs, because the first chamfer's top edge is the second one's pivot.

Where nothing exceeds its face and the cuts do not touch, H and P are the same shape and there is one right answer.
"""
import math, os, subprocess, sys

W, LEN, H = 4.0, 10.0, 6.0
EDGE = {"L": (0, 5, 6), "R": (4, 5, 6)}
FACE = {"top": (2, 5, 6), "L": (0, 5, 3), "R": (4, 5, 3)}


def fmt(p):
    return "%g,%g,%g" % p


# ---------------------------------------------------------------- 2D geometry
def clip(poly, a, b, corner):
    """Keep the part of poly on the side of line a-b that does NOT hold `corner`, the edge being chamfered (it is cut away)."""
    def side(p):
        return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
    s0 = side(corner)
    sgn = -1 if s0 > 0 else 1
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        sp, sq = sgn * side(p), sgn * side(q)
        if sp >= -1e-12:
            out.append(p)
        if (sp > 1e-12 and sq < -1e-12) or (sp < -1e-12 and sq > 1e-12):
            t = sp / (sp - sq)
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    # drop repeated points
    res = []
    for p in out:
        if not res or math.hypot(p[0] - res[-1][0], p[1] - res[-1][1]) > 1e-12:
            res.append(p)
    if len(res) > 1 and math.hypot(res[0][0] - res[-1][0], res[0][1] - res[-1][1]) <= 1e-12:
        res.pop()
    return res


def area(poly):
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2


def collinear_merge(poly):
    out = []
    n = len(poly)
    for i in range(n):
        a, b, c = poly[i - 1], poly[i], poly[(i + 1) % n]
        if abs((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])) > 1e-10:
            out.append(b)
    return out


BOX = [(0.0, 0.0), (W, 0.0), (W, H), (0.0, H)]
INSIDE = (W / 2, H / 3)


def cut_points(side, d1, d2, model, top_width=W, top_start=0.0):
    """The two points of the cut line for an edge on `side` (L or R). top_start/top_width: the part of the top face still there
    (after an earlier chamfer), measured from the left; used by the pivot reading in sequence."""
    sx = 1 if side == "L" else -1
    x0 = 0.0 if side == "L" else W
    wall_end = H
    if model == "H":
        return (x0 + sx * d1, H), (x0, H - d2)
    # pivot reading: a face that runs out ends at its far edge
    reach = (top_start + top_width - x0) if side == "L" else (x0 - top_start)
    d1p = min(d1, reach)
    d2p = min(d2, wall_end)
    return (x0 + sx * d1p, H), (x0, H - d2p)


def polygon(cuts, model, sequential=False):
    """cuts: [(side, d1, d2)]. Returns the polygon of the section."""
    poly = list(BOX)
    top_left, top_right = 0.0, W  # the extent of the top face still there (pivot reading in sequence)
    for side, d1, d2 in cuts:
        if sequential:
            a, b = cut_points(side, d1, d2, model, top_right - top_left, top_left)
        else:
            a, b = cut_points(side, d1, d2, model)
        poly = clip(poly, a, b, (0.0 if side == 'L' else W, H))
        if side == "L":
            top_left = max(top_left, a[0])
        else:
            top_right = min(top_right, a[0])
    return collinear_merge(poly)


# ---------------------------------------------------------------- cases
class Case:
    def __init__(self, stem, title, group, cuts, op, sequential=False, note="", ref_wall=False):
        self.stem, self.title, self.group, self.cuts, self.op, self.sequential, self.note, self.ref_wall = stem, title, group, cuts, op, sequential, note, ref_wall
        self.poly = {m: polygon(cuts, m, sequential) for m in ("H", "P")}
        self.vol = {m: area(self.poly[m]) * LEN for m in self.poly}
        self.same = abs(self.vol["H"] - self.vol["P"]) < 1e-9 * W * LEN * H and len(self.poly["H"]) == len(self.poly["P"])
        self.exceeds = any(d1 > W + 1e-12 or d2 > H + 1e-12 for _, d1, d2 in cuts)


def tag(*xs):
    return "_".join(("%g" % x).replace(".", "p") for x in xs)


def op_two(cuts, ref_wall=False):
    """cprobe ops for [(side, d1, d2)] as ONE builder (chamfer2). d1 on the top unless ref_wall (then d1 is on the wall)."""
    out = ["chamfer2"]
    return out


CASES = []


def add(*a, **k):
    CASES.append(Case(*a, **k))


def one(stem, title, group, side, d1, d2, **k):
    """Single chamfer, d1 on the top face, d2 on the wall, reference face = top."""
    add(stem, title, group, [(side, d1, d2)], ["chamfer2", repr(d1), repr(d2), "%s@%s" % (fmt(EDGE[side]), fmt(FACE["top"]))], **k)


# A: one edge, symmetric Add(d, E)
for d in [1, 2, 3.9, 4, 4.5, 5.9, 6, 7]:
    add(f"S-sym-{tag(d)}", f"S: ONE symmetric chamfer, distance {d:g}, on the left top edge of a 4 x 10 x 6 box", "S", [("L", d, d)],
        ["chamfer_sym", repr(float(d)), fmt(EDGE["L"])])

# B: one edge, two distances (reference face = top: d1 on top, d2 on the left wall)
for d1, d2 in [(1, 3), (3, 1), (3.9, 2), (4, 2), (5, 2), (2, 5.9), (2, 6), (2, 7), (5, 7)]:
    one(f"T-{tag(d1, d2)}", f"T: ONE chamfer, {d1:g} on the top face and {d2:g} on the left wall, left top edge of a 4 x 10 x 6 box", "T", "L", float(d1), float(d2))
# reference face = the wall: d1 is on the wall
for d1, d2 in [(2, 5), (5, 2)]:
    add(f"W-{tag(d1, d2)}", f"W: ONE chamfer, reference face = the left WALL: {d1:g} on the wall and {d2:g} on the top, left top edge", "W",
        [("L", d2, d1)], ["chamfer2", repr(float(d1)), repr(float(d2)), "%s@%s" % (fmt(EDGE["L"]), fmt(FACE["L"]))])

# C: both top edges in ONE builder
for d1, d2 in [(1, 1), (1.9, 1.9), (2, 2), (2.1, 2.1), (3, 3), (3.9, 3.9), (4.5, 4.5)]:
    add(f"B-sym-{tag(d1)}", f"B: BOTH top edges at once, {d1:g} on the top face and {d2:g} on each wall, 4 x 10 x 6 box", "B",
        [("L", d1, d2), ("R", d1, d2)],
        ["chamfer2", repr(float(d1)), repr(float(d2)), "%s@%s" % (fmt(EDGE["L"]), fmt(FACE["top"])), "%s@%s" % (fmt(EDGE["R"]), fmt(FACE["top"]))])
add("B-asym-1_3-3_1", "B: BOTH top edges at once, left (1 on top, 3 on the wall), right (3 on top, 1 on the wall)", "B",
    [("L", 1.0, 3.0), ("R", 3.0, 1.0)],
    ["chamfer_pair"])  # filled in below
add("B-asym-1_3-2_2", "B: BOTH top edges at once, left (1, 3), right (2, 2)", "B", [("L", 1.0, 3.0), ("R", 2.0, 2.0)], ["chamfer_pair"])
add("B-asym-3_2-3_2", "B: BOTH top edges at once, each (3 on top, 2 on the wall): the cuts cross", "B", [("L", 3.0, 2.0), ("R", 3.0, 2.0)], ["chamfer_pair"])
add("B-sym-5-2", "B: BOTH top edges at once, each (5 on top, 2 on the wall): each runs past the far edge", "B", [("L", 5.0, 2.0), ("R", 5.0, 2.0)], ["chamfer_pair"])


# D: one after the other (two builders)
def seq_ops(c1, c2):
    ops = []
    for side, d1, d2 in (c1, c2):
        ops += ["chamfer2", repr(d1), repr(d2), "%s@%s" % (fmt(EDGE[side]), fmt(FACE["top"])), "+"]
    return ops[:-1]


for d in [1.5, 2.0, 3.0]:
    add(f"D-seq-{tag(d)}", f"D: {d:g} then {d:g}, left top edge then right, one after the other (symmetric distances)", "D",
        [("L", d, d), ("R", d, d)], seq_ops(("L", d, d), ("R", d, d)), sequential=True)

# E: distance + angle (d on the TOP face, angle between the chamfer face and the top face)
for d, a in [(2, 20), (2, 30), (2, 45), (2, 60), (2, 75), (3.9, 30), (5, 30), (2, 80)]:
    d2 = d * math.tan(math.radians(a))
    add(f"A-{tag(d, a)}", f"A: distance {d:g} on the top face and {a:g} degrees, left top edge (the wall distance is {d2:.4f})", "A",
        [("L", float(d), d2)], ["chamferda", repr(float(d)), repr(float(a)), "%s@%s" % (fmt(EDGE["L"]), fmt(FACE["top"]))])
add("A-both-2p1-45", "A: BOTH top edges at once, distance 2.1 and 45 degrees each", "A", [("L", 2.1, 2.1), ("R", 2.1, 2.1)],
    ["chamferda_pair"])


def finish_ops():
    """Fill in the placeholder ops that need both edges."""
    for c in CASES:
        if c.op == ["chamfer_pair"]:
            (s1, a1, b1), (s2, a2, b2) = c.cuts
            # one builder cannot carry two different (d1, d2): cprobe takes one pair per op, so chain the two Add calls in ONE
            # builder via the dedicated op 'chamfer2m'
            c.op = ["chamfer2m"] + ["%r:%r:%s@%s" % (d1, d2, fmt(EDGE[s]), fmt(FACE["top"])) for s, d1, d2 in c.cuts]
        elif c.op == ["chamferda_pair"]:
            c.op = ["chamfer_dam"] + ["%r:%r:%s@%s" % (d1, math.degrees(math.atan(d2 / d1)), fmt(EDGE[s]), fmt(FACE["top"])) for s, d1, d2 in c.cuts]


finish_ops()


# ---------------------------------------------------------------- the kernel
def run(probe, case, timeout=60, mode="run"):
    args = [probe, mode, f"box:{W:g},{LEN:g},{H:g}"] + case.op
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout, start_new_session=True)
    except subprocess.TimeoutExpired:
        return dict(done="TIMEOUT", valid=0, vol=0.0, faces=0)
    ls = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    if not ls:
        return dict(done="NORESULT", valid=0, vol=0.0, faces=0, rc=p.returncode)
    head, _, note = ls[0].partition(" note=")
    kv = dict(t.split("=", 1) for t in head.split()[1:])
    kv["note"] = note or "-"
    return dict(done=kv["done"], valid=int(kv["valid"]), solids=int(kv["solids"]), faces=int(kv["faces"]), vol=float(kv["vol"]), note=kv.get("note", "-"))


def classify(m, case, tol=1e-6):
    """declined / done-but-invalid / TIMEOUT / valid and matching H and/or P / valid but matching neither."""
    if m["done"] != "1":
        return "declined" if m["done"] == "0" else m["done"]
    if not m["valid"]:
        return "done-but-invalid"
    hit = [mm for mm in ("H", "P") if abs(m["vol"] - case.vol[mm]) <= tol * W * LEN * H]
    if case.same:
        return "valid, matches the reference" if hit else "valid, WRONG volume"
    if len(hit) == 2:
        return "valid, matches H and P"
    if hit:
        return "valid, matches " + hit[0] + " only"
    return "valid, WRONG volume (neither H nor P)"


if __name__ == "__main__":
    probe = sys.argv[1]
    for c in CASES:
        m = run(probe, c)
        print(f"{c.stem:18s} H={c.vol['H']:9.4f} P={c.vol['P']:9.4f} {'same' if c.same else 'DIFF'}  kernel: done={m['done']} valid={m['valid']} vol={m['vol']:.4f} faces={m.get('faces')} -> {classify(m, c)}", flush=True)
