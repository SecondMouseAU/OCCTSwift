#!/usr/bin/env python3
"""Review renders for the pivot-edge fillets, SVG then PNG (rsvg-convert), and the table behind index.md. Standard library plus numpy.

  render.py <outdir> <meshdump_k5> <meshdump_main> <meshdump_new> [case stem ...]

meshdump_k5   linked against the unmodified v4.0.0-kernel.5 asset
meshdump_main kernel.5 with patch 0059 (what main builds when the kernel is built from source)
meshdump_new  kernel.5 with 0059 and 0060 (this branch)

One image per case, three panels. Left: the cross-section looking along Y, the ANALYTIC profile dashed blue with its
circles dotted, the tangent points (green), pivots (red diamonds), the junction or crossing (blue) and the circle centres
marked, the numbers listed under the panel, and the branch's end face drawn over it. Middle: the branch's 3D result
with edges drawn, or the input with the filleted edges red if the kernel declines. Right: the REFERENCE construction,
the analytic section extruded (what a sketch and an extrude gives in Shapr3D), independent of the fillet code.
Chips state valid / invalid / declined and the volume against the analytic one for kernel.5, main and the branch.
"""
import sys, os, math, subprocess
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle

OUT, MD_K5, MD_MAIN, MD_NEW = sys.argv[1:5]
os.makedirs(OUT, exist_ok=True)
PAL = dict(bg="#ffffff", ink="#1d2430", mute="#6b7280", ok="#2f9e5f", fail="#d64545", warn="#e08a1e",
           face="#9fb4cc", edge="#2b3345", blue="#2563eb", tan="#12805c", piv="#d64545")


# ---------------------------------------------------------------- kernel output
def dump(exe, args):
    p = subprocess.run([exe] + args, capture_output=True, text=True, timeout=180)
    ls = p.stdout.splitlines()
    if not ls or ls[0] == "FAIL":
        return None
    st = dict(t.split("=") for t in ls[0].split()[1:])
    T, E = [], []
    for l in ls[1:]:
        t = l.split()
        if t[0] == "T":
            T.append([tuple(map(float, t[1 + 3 * i:4 + 3 * i])) for i in range(3)])
        elif t[0] == "E":
            E.append((tuple(map(float, t[1:4])), tuple(map(float, t[4:7]))))
    return dict(valid=st["valid"] == "1", vol=float(st["vol"]), faces=int(st["faces"]), T=T, E=E)


# ---------------------------------------------------------------- drawing helpers
def proj(p, az=-38, el=26):
    a, e = math.radians(az), math.radians(el)
    x, y, z = p
    x1 = x * math.cos(a) - y * math.sin(a)
    y1 = x * math.sin(a) + y * math.cos(a)
    return (x1, z * math.cos(e) - y1 * math.sin(e), y1 * math.cos(e) + z * math.sin(e))


def shade(tri):
    a, b, c = tri
    u = [b[i] - a[i] for i in range(3)]
    v = [c[i] - a[i] for i in range(3)]
    n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    m = math.sqrt(sum(x * x for x in n)) or 1
    n = [x / m for x in n]
    L = (-0.35, -0.55, 0.75)
    lm = math.sqrt(sum(x * x for x in L))
    L = [x / lm for x in L]
    return 0.38 + 0.62 * max(0.0, sum(n[i] * L[i] for i in range(3)))


def hexshade(base, f):
    r, g, b = int(base[1:3], 16), int(base[3:5], 16), int(base[5:7], 16)
    return "#%02x%02x%02x" % (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)))


def text(x, y, s, size=13, fill=PAL["ink"], weight="normal", anchor="middle"):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="Helvetica, Arial, sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'


def chip(x, y, w, label, color):
    return f'<rect x="{x - w / 2:.1f}" y="{y - 16}" width="{w}" height="24" rx="12" fill="{color}"/>' + text(x, y, label, 12.5, "#ffffff", "bold")


class Panel:
    def __init__(self, x0, y0, w, h):
        self.x0, self.y0, self.w, self.h = x0, y0, w, h

    def fit(self, pts, pad=0.1):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        self.s = min(self.w * (1 - 2 * pad) / ((max(xs) - min(xs)) or 1), self.h * (1 - 2 * pad) / ((max(ys) - min(ys)) or 1))
        self.cx, self.cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2

    def xy(self, p):
        return (self.x0 + self.w / 2 + (p[0] - self.cx) * self.s, self.y0 + self.h / 2 - (p[1] - self.cy) * self.s)


def solid(pn, res):
    """Painter's algorithm: triangles and edge segments in one depth-sorted list."""
    prim = []
    for tri in res["T"]:
        P = [proj(v) for v in tri]
        prim.append((sum(q[2] for q in P) / 3, "t", P, shade(tri)))
    for a, b in res["E"]:
        P = [proj(a), proj(b)]
        prim.append(((P[0][2] + P[1][2]) / 2 - 0.05, "e", P, 0))
    pn.fit([q for _, _, P, _ in prim for q in P])
    el = []
    for _, k, P, f in sorted(prim, key=lambda t: t[0]):
        if k == "t":
            c = hexshade(PAL["face"], f)
            el.append(f'<polygon points="{" ".join("%.1f,%.1f" % pn.xy(q) for q in P)}" fill="{c}" stroke="{c}" stroke-width="0.5"/>')
        else:
            p, q = pn.xy(P[0]), pn.xy(P[1])
            el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["edge"]}" stroke-width="1.5" stroke-linecap="round"/>')
    return el


def input_box(pn, box, red):
    w, L, h = box
    V = [(a, b, c) for a in (0, w) for b in (0, L) for c in (0, h)]
    pn.fit([proj(v) for v in V])
    el = []
    for a in V:
        for b in V:
            if a < b and sum(1 for i in range(3) if a[i] != b[i]) == 1:
                mid = tuple((a[i] + b[i]) / 2 for i in range(3))
                isred = any(max(abs(mid[i] - m[i]) for i in range(3)) < 1e-9 for m in red)
                p, q = pn.xy(proj(a)), pn.xy(proj(b))
                el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{PAL["fail"] if isred else PAL["mute"]}" stroke-width="{3.4 if isred else 1.2}"/>')
    return el


# ---------------------------------------------------------------- section geometry (x across the top face, z up)
def arc_mid(c, r, P, Q):
    """Middle of the minor arc P to Q of the circle (c, r)."""
    u = ((P[0] - c[0]) / r + (Q[0] - c[0]) / r, (P[1] - c[1]) / r + (Q[1] - c[1]) / r)
    n = math.hypot(*u)
    return (c[0] + r * u[0] / n, c[1] + r * u[1] / n)


def sample_arc(c, r, P, Q, n=48):
    a0 = math.atan2(P[1] - c[1], P[0] - c[0])
    a1 = math.atan2(Q[1] - c[1], Q[0] - c[0])
    da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi          # the minor arc
    return [(c[0] + r * math.cos(a0 + da * k / n), c[1] + r * math.sin(a0 + da * k / n)) for k in range(n + 1)]


def corner_xz(w, h, a, b, r, left=True):
    """The pivot rule's arc for the corner at the top of the left (or right) wall, in (x, z)."""
    cd = oracle.corner(a, b, r)
    cu, cv = cd["centre"]
    sx = 1 if left else -1
    x0 = 0 if left else w
    return dict(case=cd["case"], c=(x0 + sx * cu, h - cv), q1=(x0 + sx * cd["q1"], h), q2=(x0, h - cd["q2"]), area=cd["area"], cd=cd, r=r, left=left, x0=x0, sx=sx)


def tangent_dir(P, C, toward):
    t = (-(P[1] - C[1]), P[0] - C[0])
    if t[0] * (toward[0] - P[0]) + t[1] * (toward[1] - P[1]) < 0:
        t = (-t[0], -t[1])
    n = math.hypot(*t)
    return (t[0] / n, t[1] / n)


def angle_between(u, v):
    return math.degrees(math.acos(max(-1, min(1, u[0] * v[0] + u[1] * v[1]))))


def z_of(K, h, x):
    """Height of the corner's arc profile at x (h where the arc has ended)."""
    t = (x - K["x0"]) * K["sx"]
    cu, cv = K["cd"]["centre"]
    d = np.clip(cv - np.sqrt(np.maximum(K["r"] ** 2 - (t - cu) ** 2, 0)), 0, K["cd"]["q2"])
    return np.where(t < K["cd"]["q1"], h - d, h)


def corner_marks(K, side, with_top=True):
    cs = K["case"]
    m = [("C", K["c"], "centre (%.4f, %.4f), r = %g" % (K["c"][0], K["c"][1], K["r"]))]
    if cs == "tangent-tangent":
        m.append(("T", K["q2"], "tangent to the %s wall at (%.4f, %.4f)" % (side, *K["q2"])))
        if with_top:
            m.append(("T", K["q1"], "tangent to the top face at (%.4f, %.4f)" % K["q1"]))
    elif cs == "pivot at the far edge of face 1":
        m.append(("T", K["q2"], "tangent to the %s wall at (%.4f, %.4f)" % (side, *K["q2"])))
        if with_top:
            m.append(("P", K["q1"], "pivot, far edge of the top face (%.4f, %.4f)" % K["q1"]))
    elif cs == "pivot at the far edge of face 2":
        m.append(("P", K["q2"], "pivot, bottom edge of the %s wall (%.4f, %.4f)" % (side, *K["q2"])))
        if with_top:
            m.append(("T", K["q1"], "tangent to the top face at (%.4f, %.4f)" % K["q1"]))
    else:
        m.append(("P", K["q2"], "pivot, bottom edge of the %s wall (%.4f, %.4f)" % (side, *K["q2"])))
        if with_top:
            m.append(("P", K["q1"], "pivot, far edge of the top face (%.4f, %.4f)" % K["q1"]))
    return m


class Geo:
    """A case in section: the path (for the reference extrusion), the outline (for the SVG), marks, circles, notes."""

    def __init__(self):
        self.path, self.pts, self.marks, self.circles, self.notes, self.area, self.recipe = [], [], [], [], [], 0.0, []


def outline(path, arcs):
    pts, cur = [], None
    for seg in path:
        if seg[0] == "S":
            cur = seg[1]
            pts.append(cur)
        elif seg[0] == "L":
            pts.append(seg[1])
            cur = seg[1]
        else:
            c, r = arcs[(round(cur[0], 6), round(cur[1], 6), round(seg[2][0], 6), round(seg[2][1], 6))]
            pts += sample_arc(c, r, cur, seg[2])[1:]
            cur = seg[2]
    return pts


def build_add(w, h, rl, rr):
    """Two fillets on the top edges at once: the intersection of the rounded profiles."""
    g = Geo()
    L = corner_xz(w, h, w, h, rl, True)
    R = corner_xz(w, h, w, h, rr, False)
    xs = np.linspace(0, w, 400001)
    lq1, rq1 = L["cd"]["q1"], R["cd"]["q1"]
    cross = None
    if lq1 > w - rq1 + 1e-9:
        d = z_of(L, h, xs) - z_of(R, h, xs)
        lo, hi = np.searchsorted(xs, w - rq1), np.searchsorted(xs, lq1)
        seg = d[lo:hi + 1]
        sc = np.where(np.sign(seg[:-1]) != np.sign(seg[1:]))[0]
        if len(sc):
            i = lo + sc[0]
            t = d[i] / (d[i] - d[i + 1])
            x = xs[i] + t * (xs[i + 1] - xs[i])
            cross = (float(x), float(z_of(L, h, np.array([x]))[0]))
    arcs = {}
    path = [("S", (0.0, 0.0)), ("L", L["q2"])]
    if cross:
        arcs[(round(L["q2"][0], 6), round(L["q2"][1], 6), round(cross[0], 6), round(cross[1], 6))] = (L["c"], rl)
        arcs[(round(cross[0], 6), round(cross[1], 6), round(R["q2"][0], 6), round(R["q2"][1], 6))] = (R["c"], rr)
        path += [("A", arc_mid(L["c"], rl, L["q2"], cross), cross), ("A", arc_mid(R["c"], rr, cross, R["q2"]), R["q2"])]
        t1 = tangent_dir(cross, L["c"], L["q2"])
        t2 = tangent_dir(cross, R["c"], R["q2"])
        ang = angle_between(t1, t2)
        g.marks.append(("J", cross, "crossing (%.4f, %.4f)" % cross))
        g.notes.append("the arcs cross; %.2f deg between them (included, through the material)" % ang)
        g.angle = ang
        g.marks += corner_marks(L, "left", False) + corner_marks(R, "right", False)
    else:
        arcs[(round(L["q2"][0], 6), round(L["q2"][1], 6), round(L["q1"][0], 6), round(L["q1"][1], 6))] = (L["c"], rl)
        path.append(("A", arc_mid(L["c"], rl, L["q2"], L["q1"]), L["q1"]))
        if abs(L["q1"][0] - R["q1"][0]) > 1e-9:
            path.append(("L", R["q1"]))
        arcs[(round(R["q1"][0], 6), round(R["q1"][1], 6), round(R["q2"][0], 6), round(R["q2"][1], 6))] = (R["c"], rr)
        path.append(("A", arc_mid(R["c"], rr, R["q1"], R["q2"]), R["q2"]))
        g.marks += corner_marks(L, "left", True) + corner_marks(R, "right", True)
        if abs(L["q1"][0] - R["q1"][0]) <= 1e-9:
            g.marks.append(("J", L["q1"], "junction (%.4f, %.4f): the arcs are tangent here" % L["q1"]))
            g.notes.append("the arcs are tangent to each other at the junction (180 deg)")
            g.angle = 180.0
    path.append(("L", (w, 0.0)))
    g.path = path
    g.pts = outline(path, arcs)
    g.circles = [(L["c"], rl), (R["c"], rr)]
    xs2 = (np.arange(2000000) + .5) / 2000000 * w
    g.area = float(np.sum(h - np.minimum(z_of(L, h, xs2), z_of(R, h, xs2))) * (w / 2000000))
    return g


def build_single(w, h, r):
    g = Geo()
    K = corner_xz(w, h, w, h, r, True)
    cs = K["case"]
    arcs = {(round(K["q2"][0], 6), round(K["q2"][1], 6), round(K["q1"][0], 6), round(K["q1"][1], 6)): (K["c"], r)}
    path = [("S", (0.0, 0.0)), ("L", K["q2"]), ("A", arc_mid(K["c"], r, K["q2"], K["q1"]), K["q1"])]
    if abs(K["q1"][0] - w) > 1e-9:
        path.append(("L", (w, h)))
    path += [("L", (w, 0.0))]
    g.path = path
    g.pts = outline(path, arcs) if abs(K["q1"][0] - w) > 1e-9 else outline(path, arcs) + []
    g.circles = [(K["c"], r)]
    g.marks = corner_marks(K, "left", True)
    g.area = K["area"]
    if cs == "tangent-tangent":
        g.notes.append("r = w: the arc ends on the far edge, tangent to the top face as well" if abs(r - w) < 1e-6 else "fits: tangent to both faces")
    elif cs == "pivot at the far edge of face 1":
        a = angle_between(tangent_dir(K["q1"], K["c"], K["q2"]), (0.0, -1.0))
        g.notes.append("meets the far wall at %.2f deg (interior), not tangent" % a)
        g.angle = a
    elif cs == "pivot at the far edge of face 2":
        a = angle_between(tangent_dir(K["q2"], K["c"], K["q1"]), (1.0, 0.0))
        g.notes.append("meets the bottom face at %.2f deg (interior), not tangent" % a)
        g.angle = a
    else:
        a1 = angle_between(tangent_dir(K["q1"], K["c"], K["q2"]), (0.0, -1.0))
        a2 = angle_between(tangent_dir(K["q2"], K["c"], K["q1"]), (1.0, 0.0))
        g.notes.append("tangent to neither face: %.2f deg to the far wall, %.2f deg to the bottom" % (a1, a2))
    return g


def build_seq(w, h, r1, r2):
    """A fillet next to a finished one: the finished fillet's tangent edge is the far edge of the top face."""
    g = Geo()
    A = corner_xz(w, h, w, h, r1, True)
    B = corner_xz(w, h, w - r1, h, r2, False)
    arcs = {(round(A["q2"][0], 6), round(A["q2"][1], 6), round(A["q1"][0], 6), round(A["q1"][1], 6)): (A["c"], r1),
            (round(B["q1"][0], 6), round(B["q1"][1], 6), round(B["q2"][0], 6), round(B["q2"][1], 6)): (B["c"], r2)}
    path = [("S", (0.0, 0.0)), ("L", A["q2"]), ("A", arc_mid(A["c"], r1, A["q2"], A["q1"]), A["q1"])]
    if abs(B["q1"][0] - A["q1"][0]) > 1e-9:
        path.append(("L", B["q1"]))
    path += [("A", arc_mid(B["c"], r2, B["q1"], B["q2"]), B["q2"]), ("L", (w, 0.0))]
    g.path = path
    g.pts = outline(path, arcs)
    g.circles = [(A["c"], r1), (B["c"], r2)]
    g.marks = [("C", A["c"], "centre (%.4f, %.4f), r = %g" % (A["c"][0], A["c"][1], r1)),
               ("C", B["c"], "centre (%.4f, %.4f), r = %g" % (B["c"][0], B["c"][1], r2)),
               ("T", A["q2"], "tangent to the left wall at (%.4f, %.4f)" % A["q2"]),
               ("T", B["q2"], "tangent to the right wall at (%.4f, %.4f)" % B["q2"]),
               ("P", B["q1"], "pivot, the first fillet's tangent edge (%.4f, %.4f)" % B["q1"])]
    ang = angle_between(tangent_dir(B["q1"], B["c"], B["q2"]), (-1.0, 0.0))
    g.notes.append("the second arc leaves the first fillet's tangent edge at %.2f deg to the top plane" % ang)
    g.area = A["area"] + B["area"]
    g.angle = ang
    return g


# ---------------------------------------------------------------- cases
W, LEN, H = 4.0, 10.0, 6.0
LEFT, RIGHT = (0, 5, 6), (4, 5, 6)


class Case:
    def __init__(self, stem, title, box, mode, edges, geo, group, length=None, note=""):
        self.stem, self.title, self.box, self.mode, self.edges, self.geo, self.group = stem, title, box, mode, edges, geo, group
        self.length = length or box[1]
        self.note = note


def tag(r):
    return ("%g" % r).replace(".", "_")


CASES = []
for r1, r2 in [(1.5, 2.5), (1, 3), (2, 2)]:
    CASES.append(Case(f"A-{tag(r1)}-{tag(r2)}", f"A: r1 + r2 = w, radii {r1:g} and {r2:g} on the top edges of a 4 x 10 x 6 box", (W, LEN, H), "add",
                      [(r1, LEFT), (r2, RIGHT)], build_add(W, H, r1, r2), "A",
                      note="(2, 2) is patch 0059's case, unchanged by 0060" if (r1, r2) == (2, 2) else "built by patch 0059 already"))
for r in [2.2, 2.5, 3.0, 3.5]:
    CASES.append(Case(f"B-equal-{tag(r)}", f"B: r1 + r2 > w, equal radii {r:g} on the top edges of a 4 x 10 x 6 box", (W, LEN, H), "add",
                      [(r, LEFT), (r, RIGHT)], build_add(W, H, r, r), "B"))
for r1, r2 in [(2, 2.5), (1, 3.5), (2.5, 3)]:
    CASES.append(Case(f"B-unequal-{tag(r1)}-{tag(r2)}", f"B: r1 + r2 > w, radii {r1:g} and {r2:g} on the top edges of a 4 x 10 x 6 box", (W, LEN, H), "add",
                      [(r1, LEFT), (r2, RIGHT)], build_add(W, H, r1, r2), "B"))
for r in [4.0, 4.5, 5.0, 6.0]:
    CASES.append(Case(f"C-single-{tag(r)}", f"C: ONE fillet of radius {r:g} on the 4 mm wide top face of a 4 x 10 x 6 box", (W, LEN, H), "add",
                      [(r, LEFT)], build_single(W, H, r), "C"))
CASES.append(Case("D1-plate-4", "D1: radius 4 on the edge of a 3 mm thick plate (10 x 10 x 3): the bottom edge is the pivot", (10.0, 10.0, 3.0), "add",
                  [(4.0, (0, 5, 3))], build_single(10.0, 3.0, 4.0), "D"))
CASES.append(Case("D2-both-4_5", "D2: radius 4.5 on a 4 x 10 x 3 box: both far edges are pivots", (4.0, 10.0, 3.0), "add",
                  [(4.5, (0, 5, 3))], build_single(4.0, 3.0, 4.5), "D"))
CASES.append(Case("D3-seq-3-3", "D3: radius 3, THEN radius 3, on the top edges of a 4 x 10 x 6 box (one after the other)", (W, LEN, H), "seq",
                  [(3.0, LEFT), (3.0, RIGHT)], build_seq(W, H, 3.0, 3.0), "D",
                  note="both at once (case B, r = 3) gives volume 202.502076; one after the other gives this, the order matters"))
CASES.append(Case("D4-pair-7_5", "D4: radii 7.5 on both edges of the 10 mm wide top face of a 10 x 4 x 6 box (7.5 > the 6 mm wall)", (10.0, 4.0, 6.0), "add",
                  [(7.5, (0, 2, 6)), (7.5, (10, 2, 6))], build_add(10.0, 6.0, 7.5, 7.5), "D", length=4.0))


# ---------------------------------------------------------------- figure
def section_panel(pn, case, res):
    g = case.geo
    w, h = case.box[0], case.box[2]
    pn.fit([(-0.12 * w - 0.3, -0.5), (1.12 * w + 0.3, h + 0.7)], pad=0.03)
    el = [f'<rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}" fill="#f6f8fb" stroke="#d5dbe5"/>']
    box = [(0, 0), (w, 0), (w, h), (0, h), (0, 0)]
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in box)}" fill="none" stroke="{PAL["mute"]}" stroke-width="1" stroke-dasharray="2 4"/>')
    el.append(f'<clipPath id="cp"><rect x="{pn.x0}" y="{pn.y0}" width="{pn.w}" height="{pn.h}"/></clipPath><g clip-path="url(#cp)">')
    for c, r in g.circles:
        cx, cy = pn.xy(c)
        el.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r * pn.s:.1f}" fill="none" stroke="{PAL["blue"]}" stroke-width="0.8" stroke-dasharray="1 4" opacity="0.55"/>')
    el.append(f'<path d="M {" L ".join("%.1f,%.1f" % pn.xy(p) for p in g.pts)} Z" fill="{PAL["blue"]}" fill-opacity="0.07" stroke="{PAL["blue"]}" stroke-width="2.2" stroke-dasharray="7 4"/>')
    if res:
        col = PAL["ok"] if res["valid"] else PAL["warn"]
        for a, b in res["E"]:
            if abs(a[1]) < 1e-6 and abs(b[1]) < 1e-6:
                p, q = pn.xy((a[0], a[2])), pn.xy((b[0], b[2]))
                el.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}" stroke="{col}" stroke-width="3.2" stroke-linecap="round"/>')
    for kind, p, lab in g.marks:
        x, y = pn.xy(p)
        if kind == "C":
            el.append(f'<path d="M {x - 5:.1f},{y:.1f} L {x + 5:.1f},{y:.1f} M {x:.1f},{y - 5:.1f} L {x:.1f},{y + 5:.1f}" stroke="{PAL["blue"]}" stroke-width="1.6"/>')
            continue
        col = {"T": PAL["tan"], "P": PAL["piv"], "J": PAL["blue"]}[kind]
        if kind == "P":
            el.append(f'<rect x="{x - 5:.1f}" y="{y - 5:.1f}" width="10" height="10" fill="{col}" transform="rotate(45 {x:.1f} {y:.1f})"/>')
        else:
            el.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4.8" fill="{col}"/>')
    el.append("</g>")
    return el


def legend(case, x, y):
    g = case.geo
    el = []
    order = {"T": 0, "P": 1, "J": 2, "C": 3}
    for i, (kind, p, lab) in enumerate(sorted(g.marks, key=lambda t: order[t[0]])):
        col = {"T": PAL["tan"], "P": PAL["piv"], "J": PAL["blue"], "C": PAL["blue"]}[kind]
        sym = {"T": "o", "P": "<>", "J": "o", "C": "+"}[kind]
        el.append(text(x, y + 16 * i, ("%s  " % sym) + lab, 11.5, col, "normal", "start"))
    for j, n in enumerate(g.notes):
        el.append(text(x, y + 16 * (len(g.marks) + j), "- " + n, 11.5, PAL["ink"], "bold", "start"))
    return el


def status(res, oracle_vol):
    if res is None:
        return "declined (IsDone false)", PAL["fail"]
    d = res["vol"] - oracle_vol
    if res["valid"]:
        return "valid, %.6f (%+.1e)" % (res["vol"], d), PAL["ok"]
    return "done but INVALID, %.3f (%+.3f)" % (res["vol"], d), PAL["warn"]


def kargs(case):
    w, L, h = case.box
    return ["kernel", repr(w), repr(L), repr(h), case.mode] + ["%r:%s" % (r, ",".join(map(repr, m))) for r, m in case.edges]


def pargs(case):
    a = ["profile", repr(case.length)]
    for seg in case.geo.path:
        if seg[0] == "S":
            a += ["S", repr(seg[1][0]), repr(seg[1][1])]
        elif seg[0] == "L":
            a += ["L", repr(seg[1][0]), repr(seg[1][1])]
        else:
            a += ["A", repr(seg[1][0]), repr(seg[1][1]), repr(seg[2][0]), repr(seg[2][1])]
    return a


def figure(case):
    w, L, h = case.box
    ov = w * L * h - case.length * case.geo.area
    k5 = dump(MD_K5, kargs(case))
    main = dump(MD_MAIN, kargs(case))
    new = dump(MD_NEW, kargs(case))
    ref = dump(MD_NEW, pargs(case))
    Wd, Hd = 1560, 700
    el = [text(Wd / 2, 34, case.title, 19, weight="bold"),
          text(Wd / 2, 56, "analytic volume %.6f; analytic profile dashed blue, circles dotted; the end view looks along Y" % ov, 13, PAL["mute"])]
    A, B, C = Panel(20, 80, 480, 400), Panel(520, 80, 520, 400), Panel(1060, 80, 480, 400)
    el += section_panel(A, case, new)
    el += legend(case, 28, 502)
    if new:
        el += solid(B, new)
    else:
        el += input_box(B, case.box, [m for _, m in case.edges])
    s, c = status(new, ov)
    el.append(chip(780, 510, 470, "this branch (0060): " + s, c))
    s, c = status(main, ov)
    el.append(chip(780, 546, 470, "main (0059): " + s, c))
    s, c = status(k5, ov)
    el.append(chip(780, 582, 470, "kernel.5 (pinned): " + s, c))
    el.append(text(780, 612, "3D result with edges drawn" if new else "declined: the input, filleted edges red", 12, PAL["mute"]))
    if ref:
        el += solid(C, ref)
    s2, c2 = status(ref, ov)
    el.append(chip(1300, 510, 470, "reference (sketch + extrude): " + s2, c2))
    el.append(text(1300, 546, "the analytic section extruded: what Shapr3D gives", 12, PAL["mute"]))
    if case.note:
        el.append(text(Wd / 2, 668, case.note, 12.5, PAL["ink"]))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}"><rect width="{Wd}" height="{Hd}" fill="{PAL["bg"]}"/>{"".join(el)}</svg>'
    path = os.path.join(OUT, case.stem + ".svg")
    open(path, "w").write(svg)
    subprocess.run(["rsvg-convert", "-z", "1.3", "-o", path[:-4] + ".png", path], check=True)
    return ov, k5, main, new, ref


def fmt(x, ov):
    if x is None:
        return "declined"
    return ("valid %.6f" % x["vol"]) if x["valid"] else ("INVALID %.3f" % x["vol"])


if __name__ == "__main__":
    rows = []
    only = sys.argv[5:] if len(sys.argv) > 5 else None
    for case in CASES:
        if only and case.stem not in only:
            continue
        ov, k5, main, new, ref = figure(case)
        rows.append((case, ov, k5, main, new, ref))
        print(case.stem, fmt(k5, ov), "|", fmt(main, ov), "|", fmt(new, ov), "|", fmt(ref, ov), flush=True)
    with open(os.path.join(OUT, "table.tsv"), "w") as f:
        f.write("file\tcase\tkernel5\tmain_0059\tbranch_0060\treference\tanalytic\n")
        for case, ov, k5, main, new, ref in rows:
            f.write(f"{case.stem}.png\t{case.title}\t{fmt(k5, ov)}\t{fmt(main, ov)}\t{fmt(new, ov)}\t{fmt(ref, ov)}\t{ov:.6f}\n")
