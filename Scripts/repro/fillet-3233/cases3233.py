#!/usr/bin/env python3
"""The #3233 catalog: fillet contours that share a vertex, and the REFERENCE built with no fillet code (removal prisms and balls).

A Case carries the base solid, the kernel's edge list, the reference's removal items (see cdump.cxx), the explanation of the
expected geometry and the data the renderer needs.  `measure(case, cdump)` runs one kernel build and returns its row.
"""
import math, os, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fillet-pivot-edges"))
import oracle


def f3(v):
    return ",".join("%.9g" % x for x in v)


# ---------------------------------------------------------------- polygon helpers (counter-clockwise plan, extruded up from z = 0)
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def norm(a):
    n = math.hypot(*a)
    return (a[0] / n, a[1] / n)
def left(t): return (-t[1], t[0])


def reach(poly, i):
    """Distance from the middle of edge i, along the inward normal, to the polygon boundary (the width of the top face there)."""
    n = len(poly)
    a, b = poly[i], poly[(i + 1) % n]
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    nn = left(norm(sub(b, a)))
    best = 1e300
    for j in range(n):
        if j == i:
            continue
        p, q = poly[j], poly[(j + 1) % n]
        e = sub(q, p)
        den = nn[0] * e[1] - nn[1] * e[0]
        if abs(den) < 1e-12:
            continue
        d = sub(p, mid)
        t = (d[0] * e[1] - d[1] * e[0]) / den
        s = (d[0] * nn[1] - d[1] * nn[0]) / den
        if t > 1e-9 and -1e-9 <= s <= 1 + 1e-9:
            best = min(best, t)
    return best


def is_convex(poly, k):
    n = len(poly)
    t_in = sub(poly[k], poly[k - 1])
    t_out = sub(poly[(k + 1) % n], poly[k])
    return t_in[0] * t_out[1] - t_in[1] * t_out[0] > 0


class Frame:
    """One straight edge between two planar faces at a right angle: p0, unit e, unit d1, d2 into the two faces, length and reaches a, b."""
    def __init__(self, p0, e, d1, d2, length, a, b, name):
        self.p0, self.e, self.d1, self.d2, self.length, self.a, self.b, self.name = p0, e, d1, d2, length, a, b, name

    def mid(self):
        return tuple(self.p0[i] + self.e[i] * self.length / 2 for i in range(3))

    def at(self, s):
        return tuple(self.p0[i] + self.e[i] * s for i in range(3))

    def prism(self, r, s0, s1, clip=None):
        c = oracle.corner(self.a, self.b, r)
        if c is None:
            raise ValueError("no arc for %s r=%g" % (self.name, r))
        cu, cv = c["centre"]
        it = "P:%s:%s:%s:%s:%.9g:%.9g:%.9g:%.9g:%.9g:%.9g:%.9g" % (f3(self.p0), f3(self.e), f3(self.d1), f3(self.d2), s0, s1, c["q1"], c["q2"], cu, cv, r)
        it += ":len=%.9g" % self.length         # the edge's length, for the Shapr3D steps (cdump ignores it)
        return it, c


def top_edge(poly, H, i):
    n = len(poly)
    a, b = poly[i], poly[(i + 1) % n]
    t = norm(sub(b, a))
    nn = left(t)
    return Frame((a[0], a[1], H), (t[0], t[1], 0.0), (nn[0], nn[1], 0.0), (0.0, 0.0, -1.0), math.hypot(*sub(b, a)), reach(poly, i), H, "top edge %d" % i)


def vert_edge(poly, H, k):
    n = len(poly)
    nxt, prv = sub(poly[(k + 1) % n], poly[k]), sub(poly[k - 1], poly[k])
    d1, d2 = norm(nxt), norm(prv)
    return Frame((poly[k][0], poly[k][1], 0.0), (0.0, 0.0, 1.0), (d1[0], d1[1], 0.0), (d2[0], d2[1], 0.0), H, math.hypot(*nxt), math.hypot(*prv), "vertical edge %d" % k)


def rect(W, D): return [(0.0, 0.0), (W, 0.0), (W, D), (0.0, D)]


class Case:
    def __init__(self, stem, group, title, shape, poly, H, edges, items, expect, kind, notes=(), alt=None, alt_title="", view=225, section=None, focus=None):
        self.stem, self.group, self.title, self.shape, self.poly, self.H = stem, group, title, shape, poly, H
        self.edges, self.items, self.expect, self.kind, self.notes = edges, items, expect, kind, list(notes)
        self.alt, self.alt_title = alt, alt_title        # alternative reference: removal items for the second candidate outcome
        self.view, self.section, self.focus = view, section, focus
        self.ref_label = "removal prisms and balls cut from the base, no fillet code"
        self.decision = False


def spec_of(poly, H):
    if len(poly) == 4 and poly == rect(poly[2][0], poly[2][1]):
        return "box:%g,%g,%g" % (poly[2][0], poly[2][1], H)
    return "poly:%g:%s" % (H, ";".join("%g,%g" % p for p in poly))


def tag(*rs): return "-".join(("%g" % r).replace(".", "_") for r in rs)
CASES = []


def add(c): CASES.append(c); return c


# ---------------------------------------------------------------- E: two adjacent edges at a box corner
W, D, H = 4.0, 10.0, 6.0
BOX = rect(W, D)
FRONT, LEFTE = top_edge(BOX, H, 0), top_edge(BOX, H, 3)      # along +x from (0,0,6), and along -y into (0,0,6)


def ext(fr, r): return -2 * r - 1, fr.length + 2 * r + 1


def e_case(stem, rf, rl, expect, notes=(), alt=None):
    its, cs = [], []
    for fr, r in ((FRONT, rf), (LEFTE, rl)):
        it, c = fr.prism(r, *ext(fr, r)); its.append(it); cs.append(c)
    t = f"E: two adjacent top edges meeting at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii {rf:g} (front, along X) and {rl:g} (left, along Y)"
    return add(Case(stem, "E", t, spec_of(BOX, H), BOX, H, [(rf, FRONT.mid()), (rl, LEFTE.mid())], its, expect, "adjacent", notes, alt, view=225))


e_case("E1-adj-1-1", 1, 1, "Mitre: the two cylinders meet along their intersection curve (the plane through the corner at 45 deg for equal radii). Both radii below every face width, so this is the ordinary fillet; the rule adds nothing.")
e_case("E2-adj-1-2", 1, 2, "The two cylinders (r 1 and r 2) meet along their space intersection curve, not a plane. Both below the face widths: ordinary fillet.")
e_case("E3-adj-3-3", 3, 3, "Mitre of two r = 3 cylinders. 3 is below the 4 mm top face width, so no pivot; the bands overlap over a large part of the corner, which is still just the intersection.")
e_case("E4-adj-1-4_5", 1, 4.5, "The left edge (r 4.5) runs out of the 4 mm top face: tangent to the left wall, pivot at the far top edge (4, y, 6). The front edge (r 1) is ordinary. Where they meet: the intersection of the two surfaces.")
e_case("E5-adj-3-4_5", 3, 4.5, "As E4 with the front fillet r 3: its cylinder crosses the pivot cylinder of the left edge; the corner is their intersection.")
e_case("E6-adj-4_5-4_5", 4.5, 4.5, "Both radii 4.5: the left edge pivots at the far top edge; the front edge (top face reaches 10 along Y, wall 6) is ordinary. Corner is the intersection of the two cylinders.")

# ---------------------------------------------------------------- F: three edges at a box corner
VERT = vert_edge(BOX, H, 0)


def corner_items(rs, mitre):
    """Items for the three edges at (0,0,6): front (rs[0]), left (rs[1]), vertical (rs[2]). mitre=True: three extended prisms (the intersection of the singles);
    mitre=False, equal radii: prisms stopped at the corner cube and a cube-minus-ball."""
    rf, rl, rv = rs
    if mitre:
        its = [FRONT.prism(rf, *ext(FRONT, rf))[0], LEFTE.prism(rl, *ext(LEFTE, rl))[0], VERT.prism(rv, -2 * rv - 1, H + 2 * rv + 1)[0]]
        return its
    r = rf
    its = [FRONT.prism(r, r, FRONT.length + 2 * r + 1)[0],      # front edge starts at x = r
           LEFTE.prism(r, 0 - 2 * r - 1, LEFTE.length - r)[0],   # left edge runs along -y from (0,10,6): ends at y = r
           VERT.prism(r, -2 * r - 1, H - r)[0],
           "B:0,0,%.9g,%.9g,%.9g,%.9g:%.9g,%.9g,%.9g:%.9g" % (H - r, r, r, H, r, r, H - r, r)]
    return its


def f_case(stem, rs, expect, notes=(), sphere=True):
    t = "F: all three edges at the corner (0, 0, 6) of a 4 x 10 x 6 box, radii %s (front, left, vertical)" % ", ".join("%g" % r for r in rs)
    equal = len(set(rs)) == 1
    main = corner_items(rs, mitre=not (equal and sphere))
    c = add(Case(stem, "F", t, spec_of(BOX, H), BOX, H, [(rs[0], FRONT.mid()), (rs[1], LEFTE.mid()), (rs[2], VERT.mid())], main, expect, "corner3", notes, None, view=225))
    if not (equal and sphere):
        c.ref_label = "candidate B: intersection of the three fillets (pointed)"
        c.decision = True
    return c


f_case("F1-corner-1", (1, 1, 1), "Spherical corner: a ball of radius 1 centred (1, 1, 5), tangent to all three faces and to the three cylinders (rolling ball).")
f_case("F2-corner-2", (2, 2, 2), "Spherical corner: a ball of radius 2 centred (2, 2, 4), tangent to the three faces and the three cylinders.")
f_case("F3-corner-3_5", (3.5, 3.5, 3.5), "Spherical corner, r 3.5 (below the 4 mm width, above half of it): ball centred (3.5, 3.5, 2.5).")
f_case("F4-corner-unequal", (1, 2, 1.5), "Unequal radii: the three cylinders cannot be joined by a sphere. Candidate A is any smooth blend (the kernel's vertex patch), candidate B is the pointed intersection of the three. A design choice.",
       sphere=False)
f_case("F5-corner-4_5", (4.5, 4.5, 4.5), "r 4.5 is above the 4 mm width of the top face and of the front face: the left and vertical edges pivot on the far edges. No ball of radius 4.5 fits the corner. Candidate B (intersection of the three pivot fillets) is the only outcome the rule defines directly; a vertex blend there is a design choice.",
       sphere=False)

# ---------------------------------------------------------------- G: a full top frame
def frame_case(stem, W, D, H, r, expect, notes=(), r_short=None):
    poly = rect(W, D)
    fr = [top_edge(poly, H, i) for i in range(4)]
    rs = [r_short if (r_short is not None and i % 2 == 0) else r for i in range(4)]      # edges 0 and 2 run along X (the short ones)
    its = [f.prism(q, *ext(f, q))[0] for f, q in zip(fr, rs)]
    t = f"G: all four top edges (a frame), radius {r:g}, of a {W:g} x {D:g} x {H:g} box" if r_short is None else f"G: all four top edges (a frame) of a {W:g} x {D:g} x {H:g} box, radius {r:g} on the two long edges and {r_short:g} on the two short ones"
    c = add(Case(stem, "G", t, spec_of(poly, H), poly, H, [(q, f.mid()) for f, q in zip(fr, rs)], its, expect, "frame", notes, view=225))
    return c


frame_case("G1-frame-1", 4, 10, 6, 1, "Ordinary: four cylinders, a mitre at each of the four corners, a flat top 2 x 8 left in the middle.")
frame_case("G2-frame-2", 4, 10, 6, 2, "r = w/2 on the 4 mm width: the flat top shrinks to a line along Y at x = 2 (the long edges are exactly tangent to each other there); the end fillets (r 2) meet them in mitres.")
frame_case("G3-frame-2_5", 4, 10, 6, 2.5, "r > w/2: the long edges' arcs cross at x = 2 (included angle 156.93 deg) along a ridge; the two end fillets cut the ridge down to their own mitre curves. The intersection of the four rounded profiles.")
frame_case("G4-frame-3", 4, 10, 6, 3, "r = 3: the arcs cross at an included angle of 141.06 deg; intersection of all four.")
frame_case("G5-frame-3_9", 4, 10, 6, 3.9, "r just below the 4 mm width: the arcs cross low on the wall; intersection of all four.")
frame_case("G6-frame-4_5", 4, 10, 6, 4.5, "r above the 4 mm width: each long edge pivots at the far top edge; the intersection of the two pivot cylinders, plus the end fillets (r 4.5 < the 6 mm wall, the 10 mm top).")
frame_case("G10-frame-3-1", 4, 10, 6, 3, "Unequal radii: the long edges (r 3) cross at x = 2; the end edges (r 1) meet them in mitres whose curves are the intersections of a r = 1 and a r = 3 cylinder. Intersection of the four.", r_short=1)
frame_case("G7-frame-sq-3", 10, 10, 8, 3, "Ordinary frame on a 10 x 10 top: a flat 4 x 4 top.")
frame_case("G8-frame-sq-5", 10, 10, 8, 5, "r = w/2 in both directions: the flat top shrinks to a single point at (5, 5); four cylinders meeting along the two diagonals (a pyramid-like dome with a point).")
frame_case("G9-frame-sq-6", 10, 10, 8, 6, "r > w/2 in both directions: the intersection of four rounded profiles, a ridge-less crossing; the arcs cross at an included angle of 134.9 deg and the top face is gone.")

# ---------------------------------------------------------------- H: L and U extrusions, the whole top contour
def poly_items(poly, H, r, mode):
    """mode 'ridge': at a reflex vertex each band runs r past it and the two meet in the diagonal mitre (the union of the removals);
    mode 'torus': each band stops at the reflex vertex and the corner profile is revolved round the vertical edge (the rolling ball, edge as pivot)."""
    n = len(poly)
    fr = [top_edge(poly, H, i) for i in range(n)]
    its = []
    rr = r if mode == "ridge" else 0.0
    for i, f in enumerate(fr):
        s0 = -2 * r - 1 if is_convex(poly, i) else -rr           # the vertex at the start of edge i is poly[i]
        s1 = f.length + (2 * r + 1 if is_convex(poly, (i + 1) % n) else rr)
        its.append(f.prism(r, s0, s1)[0])
    if mode == "torus":
        for k in range(n):
            if not is_convex(poly, k):
                t_in, t_out = norm(sub(poly[k], poly[k - 1])), norm(sub(poly[(k + 1) % n], poly[k]))
                n_out = left(t_out)
                ang = math.degrees(math.acos(max(-1, min(1, t_in[0] * t_out[0] + t_in[1] * t_out[1]))))
                its.append("V:%s:%s:%.9g:%.9g" % (f3((poly[k][0], poly[k][1], H)), f3((n_out[0], n_out[1], 0.0)), r, ang))
    return its, fr


def poly_case(stem, name, poly, H, r, expect, notes=()):
    n = len(poly)
    its, fr = poly_items(poly, H, r, "torus")
    ridge = poly_items(poly, H, r, "ridge")[0]
    t = f"H: the whole top contour ({n} edges, radius {r:g}) of a {name} extrusion 6 high"
    c = add(Case(stem, "H", t, spec_of(poly, H), poly, H, [(r, f.mid()) for f in fr], its, expect, "poly", notes, view=225))
    c.focus = (3.0, 3.0)
    c.view = 45
    c.ridge = ridge
    c.ref_label = "candidate C: rolling ball round the reflex edge"
    c.decision = True
    return c


L = [(0.0, 0.0), (8.0, 0.0), (8.0, 3.0), (3.0, 3.0), (3.0, 8.0), (0.0, 8.0)]
U = [(0.0, 0.0), (9.0, 0.0), (9.0, 7.0), (6.0, 7.0), (6.0, 3.0), (3.0, 3.0), (3.0, 7.0), (0.0, 7.0)]
poly_case("H1-L-1", "L-shaped (arms 3 wide)", L, 6, 1, "Five convex corners are mitres. At the reflex corner (3, 3) the two fillets do not meet on their own: this is a design choice (candidates A, B, C in the decision image). r = 1 is below half the arm width.")
poly_case("H2-L-1_5", "L-shaped (arms 3 wide)", L, 6, 1.5, "r = w/2 on 3 mm arms: each arm's top shrinks to a ridge line; reflex corner as H1 (decision).")
poly_case("H3-L-2", "L-shaped (arms 3 wide)", L, 6, 2, "r > w/2: the opposite arcs cross along each arm; the intersection of the rounded profiles; reflex corner as H1 (decision).")
poly_case("H4-U-1", "U-shaped (arms 3 wide)", U, 6, 1, "Two reflex corners, each a design choice as in H1; r = 1 below half the arm width.")
poly_case("H5-U-1_5", "U-shaped (arms 3 wide)", U, 6, 1.5, "r = w/2: every arm top shrinks to a line; two reflex corners.")
poly_case("H6-L-3_5", "L-shaped (arms 3 wide)", L, 6, 3.5, "r above the 3 mm arm width: every arm edge pivots at the far edge of the arm; the intersection; reflex corner as H1 (decision).")

# ---------------------------------------------------------------- I: the convex edges plus the corner blend
def rounded_case(stem, rt, rv, expect, notes=()):
    poly = rect(W, D)
    tops = [top_edge(poly, H, i) for i in range(4)]
    verts = [vert_edge(poly, H, k) for k in range(4)]
    its = []
    if rt == rv:
        r = rt
        for f in tops:
            if f.length - 2 * r > 1e-9:
                its.append(f.prism(r, r, f.length - r)[0])
        for v in verts:
            its.append(v.prism(r, -2 * r - 1, H - r)[0])
        for (x, y) in poly:
            cx = x + (r if x == 0 else -r); cy = y + (r if y == 0 else -r)
            x0, x1 = (0, r) if x == 0 else (W - r, W)
            y0, y1 = (0, r) if y == 0 else (D - r, D)
            its.append("B:%g,%g,%g,%g,%g,%g:%g,%g,%g:%g" % (x0, y0, H - r, x1, y1, H, cx, cy, H - r, r))
        alt = None
    else:
        for f in tops:
            its.append(f.prism(rt, *ext(f, rt))[0])
        for v in verts:
            its.append(v.prism(rv, -2 * rv - 1, H + 2 * rv + 1)[0])
        alt = None
    t = f"I: the four top edges (radius {rt:g}) and the four vertical edges (radius {rv:g}) of a 4 x 10 x 6 box: four corner blends"
    equal = rt == rv
    c = add(Case(stem, "I", t, spec_of(poly, H), poly, H, [(rt, f.mid()) for f in tops] + [(rv, v.mid()) for v in verts], its, expect, "rounded", notes, None, view=225))
    if rt != rv:
        c.ref_label = "candidate B: intersection of the eight fillets (pointed)"
        c.decision = True
    return c


rounded_case("I1-round-1-1", 1, 1, "Four spherical corners (balls of radius 1 at the corners of the inner box), cylinders between them: the rolling ball over the box.")
rounded_case("I2-round-1_5-1_5", 1.5, 1.5, "As I1 with r 1.5.")
rounded_case("I3-round-2-2", 2, 2, "r = w/2 on the 4 mm width: the ridge along Y meets the spheres; the vertical edges r 2 make the two ends full half cylinders in plan.")
rounded_case("I4-round-1-2", 1, 2, "Unequal radii at each corner (top r 1, vertical r 2): no sphere joins them. The reference shown is the pointed intersection of the eight single-edge fillets (candidate B); candidate A is whatever blend the kernel gives. A design choice.")
