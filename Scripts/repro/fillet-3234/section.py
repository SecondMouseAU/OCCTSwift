#!/usr/bin/env python3
"""The pivot rule on a plane section: corners of a profile of lines and circular arcs, any angle, convex or concave.

The rule (the maintainer's, #3208): wherever a fillet meets a face it is filleting it is tangent to that face; where
the face runs out and there is an edge instead, the edge is the pivot and the arc passes through it.

A prism (the section extruded) and a solid of revolution (the section turned about an axis) both reduce to it, because
a ball rolling between two faces of a body of revolution touches both in the meridian plane. So an edge shared by a plane
and a cylinder, a cone, a sphere, or two planes at any dihedral angle is one corner of one section.

Profiles are closed, traversed counter-clockwise (material on the left). A corner V joins the incoming edge e_in
(which came from S1, its far end) and the outgoing edge e_out (which goes on to E2). The fillet circle has radius r, its
centre on the material side at a convex corner (a left turn) and on the air side at a concave one (a right turn).
Candidates, in the order the rule prefers them:
  TT    tangent to both faces                       centre on both offset curves
  P1T2  e_in ran out: through S1, tangent to e_out
  T1P2  e_out ran out: tangent to e_in, through E2   (the shorter face is tried first)
  PP    both ran out: through S1 and E2
A candidate is taken when the tangent foot of every non-pivot face lies on that face. Standard library plus numpy.
"""
import math
import numpy as np

TOL = 1e-9


def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1]
def cross(a, b): return a[0] * b[1] - a[1] * b[0]
def norm(a): return math.hypot(a[0], a[1])
def unit(a):
    n = norm(a)
    return (a[0] / n, a[1] / n)
def rot90(a): return (-a[1], a[0])
def ang(p, c): return math.atan2(p[1] - c[1], p[0] - c[0])


class Edge:
    """A line (kind L) or a circular arc (kind A) from p0 to p1. Arcs carry centre c, radius R, ccw and the signed sweep."""

    def __init__(self, kind, p0, p1, c=None, R=None, ccw=True, sweep=None):
        self.kind, self.p0, self.p1, self.c, self.R, self.ccw, self.sweep = kind, p0, p1, c, R, ccw, sweep

    @staticmethod
    def line(p0, p1): return Edge("L", p0, p1)

    @staticmethod
    def arc_c(p0, p1, c, ccw):
        R = norm(sub(p0, c))
        a0, a1 = ang(p0, c), ang(p1, c)
        d = (a1 - a0) % (2 * math.pi) if ccw else -((a0 - a1) % (2 * math.pi))
        return Edge("A", p0, p1, c, R, ccw, d)

    @staticmethod
    def arc3(p0, m, p1):
        ax, ay = p0; bx, by = m; cx, cy = p1
        d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
        uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
        c = (ux, uy)
        ccw = cross(sub(m, p0), sub(p1, m)) > 0
        return Edge.arc_c(p0, p1, c, ccw)

    def reversed(self):
        if self.kind == "L":
            return Edge.line(self.p1, self.p0)
        return Edge("A", self.p1, self.p0, self.c, self.R, not self.ccw, -self.sweep)

    def length(self):
        return norm(sub(self.p1, self.p0)) if self.kind == "L" else abs(self.sweep) * self.R

    def point(self, t):
        """t in [0, 1] along the edge."""
        if self.kind == "L":
            return add(self.p0, mul(sub(self.p1, self.p0), t))
        a = ang(self.p0, self.c) + self.sweep * t
        return (self.c[0] + self.R * math.cos(a), self.c[1] + self.R * math.sin(a))

    def mid(self): return self.point(0.5)

    def tan_start(self):
        if self.kind == "L":
            return unit(sub(self.p1, self.p0))
        u = unit(sub(self.p0, self.c))
        return rot90(u) if self.ccw else mul(rot90(u), -1)

    def tan_end(self):
        if self.kind == "L":
            return unit(sub(self.p1, self.p0))
        u = unit(sub(self.p1, self.c))
        return rot90(u) if self.ccw else mul(rot90(u), -1)

    def sample(self, n=400):
        if self.kind == "L":
            return [self.p0, self.p1]
        return [self.point(k / n) for k in range(n + 1)]

    def carrier(self, side, r):
        """The curve the fillet centre lies on: ('line', point, dir) or ('circle', c, R), or None."""
        if self.kind == "L":
            d = unit(sub(self.p1, self.p0))
            return ("line", add(self.p0, mul(rot90(d), side * r)), d)
        Ro = self.R - side * r if self.ccw else self.R + side * r
        return ("circle", self.c, Ro) if Ro > TOL else None

    def sdist(self, C):
        """Signed distance of C from this edge's carrier, positive on the left (the material side of a CCW profile)."""
        if self.kind == "L":
            return cross(unit(sub(self.p1, self.p0)), sub(C, self.p0))
        d = norm(sub(C, self.c))
        return self.R - d if self.ccw else d - self.R

    def foot(self, C):
        """(point on this edge's carrier nearest C, whether it lies within the edge)."""
        if self.kind == "L":
            d = unit(sub(self.p1, self.p0))
            t = dot(sub(C, self.p0), d)
            return add(self.p0, mul(d, t)), -TOL <= t <= self.length() + TOL
        u = sub(C, self.c)
        if norm(u) < TOL:
            return None, False
        f = add(self.c, mul(unit(u), self.R))
        a0 = ang(self.p0, self.c)
        dlt = (ang(f, self.c) - a0) % (2 * math.pi) if self.sweep > 0 else -((a0 - ang(f, self.c)) % (2 * math.pi))
        if abs(dlt) > 2 * math.pi - 1e-9:
            dlt = 0.0
        return f, (dlt * (1 if self.sweep > 0 else -1)) <= abs(self.sweep) + 1e-9


def inter(A, B):
    """Intersections of two carriers."""
    if A is None or B is None:
        return []
    if A[0] == "line" and B[0] == "line":
        den = cross(A[2], B[2])
        if abs(den) < 1e-12:
            return []
        t = cross(sub(B[1], A[1]), B[2]) / den
        return [add(A[1], mul(A[2], t))]
    if A[0] == "circle" and B[0] == "line":
        A, B = B, A
    if A[0] == "line":                      # line / circle
        p, d = A[1], A[2]
        c, R = B[1], B[2]
        f = sub(p, c)
        b = dot(f, d)
        disc = b * b - (dot(f, f) - R * R)
        if disc < -1e-12:
            return []
        s = math.sqrt(max(disc, 0.0))
        return [add(p, mul(d, -b - s)), add(p, mul(d, -b + s))]
    c1, R1, c2, R2 = A[1], A[2], B[1], B[2]    # circle / circle
    dd = norm(sub(c2, c1))
    if dd < 1e-12 or dd > R1 + R2 + 1e-12 or dd < abs(R1 - R2) - 1e-12:
        return []
    a = (R1 * R1 - R2 * R2 + dd * dd) / (2 * dd)
    h = math.sqrt(max(R1 * R1 - a * a, 0.0))
    u = unit(sub(c2, c1))
    m = add(c1, mul(u, a))
    return [add(m, mul(rot90(u), h)), add(m, mul(rot90(u), -h))]


def point_circle(P, r): return ("circle", P, r)


def solve_corner(e_in, e_out, r):
    """The rule for one corner. Returns dict(case, C, Q1, Q2, side) or None if no arc exists."""
    V = e_in.p1
    convex = cross(e_in.tan_end(), e_out.tan_start()) > 0
    side = 1 if convex else -1
    S1, E2 = e_in.p0, e_out.p1
    off_in, off_out = e_in.carrier(side, r), e_out.carrier(side, r)

    def side_ok(C):
        """The centre is on the fillet side of both faces' carriers, and no further from either than r."""
        return all(-TOL <= side * e.sdist(C) <= r + 1e-7 for e in (e_in, e_out))

    def ok_in(C):
        f, inside = e_in.foot(C)
        return f if inside and side_ok(C) else None

    def ok_out(C):
        f, inside = e_out.foot(C)
        return f if inside and side_ok(C) else None

    def best(cands, key):
        return min(cands, key=key) if cands else None

    # TT
    tt = []
    for C in inter(off_in, off_out):
        a, b = ok_in(C), ok_out(C)
        if a is not None and b is not None:
            tt.append((C, a, b))
    t = best(tt, lambda x: norm(sub(x[0], V)))
    if t:
        return dict(case="TT", C=t[0], Q1=t[1], Q2=t[2], side=side, r=r)
    # one pivot: the shorter face first
    p1 = []
    for C in inter(off_out, point_circle(S1, r)):
        b = ok_out(C)
        if b is not None:
            p1.append((C, S1, b))
    p2 = []
    for C in inter(off_in, point_circle(E2, r)):
        a = ok_in(C)
        if a is not None:
            p2.append((C, a, E2))
    order = [("P1T2", p1), ("T1P2", p2)] if e_in.length() <= e_out.length() else [("T1P2", p2), ("P1T2", p1)]
    found = []
    for name, lst in order:
        c = best(lst, lambda x: norm(sub(x[0], V)))
        if c:
            found.append(dict(case=name, C=c[0], Q1=c[1], Q2=c[2], side=side, r=r))
    if found:
        # a second one-pivot arc that also satisfies the rule is an ambiguity of the rule, kept for the report
        return dict(found[0], alts=found[1:])
    # both pivots: the centre on the far side of the chord from V
    pp = [(C, S1, E2) for C in inter(point_circle(S1, r), point_circle(E2, r)) if side_ok(C)]
    c = best(pp, lambda x: -norm(sub(x[0], V)))
    if c:
        return dict(case="PP", C=c[0], Q1=c[1], Q2=c[2], side=side, r=r)
    return None


def arc_edge(sol):
    """The fillet arc as an Edge: convex corner counter-clockwise (centre on the material side), concave clockwise."""
    return Edge.arc_c(sol["Q1"], sol["Q2"], sol["C"], sol["side"] > 0)


def trimmed(e, new_p0=None, new_p1=None):
    """e with its start and/or end moved along itself (None leaves it)."""
    p0 = new_p0 if new_p0 is not None else e.p0
    p1 = new_p1 if new_p1 is not None else e.p1
    if e.kind == "L":
        return Edge.line(p0, p1)
    return Edge.arc_c(p0, p1, e.c, e.ccw)


def fillet_corner(edges, k, r):
    """edges: closed CCW list. Fillet the corner between edges[k] (incoming) and edges[(k+1) % n] (outgoing).
    Returns (new edges, solution dict + crease info) or (None, None)."""
    n = len(edges)
    ei, eo = edges[k], edges[(k + 1) % n]
    sol = solve_corner(ei, eo, r)
    if not sol:
        return None, None
    out, sol = apply_solution(edges, k, sol)
    # an alternative that leaves the part (a convex fillet may only remove, a concave one only add) is not an answer
    sol["alts"] = [a for a in sol.get("alts", []) if contained(edges, apply_solution(edges, k, a)[0], a["side"] > 0)]
    sol["escapes"] = not contained(edges, out, sol["side"] > 0)
    return out, sol


def contained(old, new, convex, tol=2e-3):
    """The new profile lies inside the old one (convex: material only removed) or contains it (concave: only added)."""
    from shapely.geometry import Polygon
    A, B = Polygon(outline(old, 800)), Polygon(outline(new, 800))
    if not B.is_valid:
        return False
    return (B.difference(A).area if convex else A.difference(B).area) < tol


def apply_solution(edges, k, sol):
    """The profile with the corner replaced by the arc of sol (one of solve_corner's answers)."""
    n = len(edges)
    ei, eo = edges[k], edges[(k + 1) % n]
    arc = arc_edge(sol)
    new_in = None if norm(sub(sol["Q1"], ei.p0)) < 1e-9 else trimmed(ei, new_p1=sol["Q1"])
    new_out = None if norm(sub(sol["Q2"], eo.p1)) < 1e-9 else trimmed(eo, new_p0=sol["Q2"])
    prev, nxt = edges[(k - 1) % n], edges[(k + 2) % n]
    out = []
    for j in range(n):
        if j == k:
            if new_in is not None:
                out.append(new_in)
            out.append(arc)
            if new_out is not None:
                out.append(new_out)
        elif j == (k + 1) % n:
            continue
        else:
            out.append(edges[j])
    # crease: turn between the arc and the face beyond a pivot (0 where it is tangent)
    def turn(t0, t1):
        return math.degrees(math.atan2(cross(t0, t1), dot(t0, t1)))
    c1 = turn(prev.tan_end(), arc.tan_start()) if new_in is None else 0.0
    c2 = turn(arc.tan_end(), nxt.tan_start()) if new_out is None else 0.0
    sol = dict(sol, crease1=c1, crease2=c2, arc=arc)
    return out, sol


def fillet_pair(edges, k1, r1, k2, r2):
    """Two corners joined by one face (edges[k1 + 1] is that face; corner k2 = k1 + 1 is the one at its far end): the
    INTERSECTION of the two rounded profiles (convex corners). Returns (new edges, info)."""
    n = len(edges)
    assert (k2 - k1) % n == 1
    e0, em, e2 = edges[k1], edges[(k1 + 1) % n], edges[(k1 + 2) % n]
    s1 = solve_corner(e0, em, r1)
    s2 = solve_corner(em, e2, r2)
    if not s1 or not s2:
        return None, None
    a1, a2 = arc_edge(s1), arc_edge(s2)
    # where along the middle face the two tangent points sit
    t1 = dot(sub(s1["Q2"], em.p0), em.tan_start()) if em.kind == "L" else None
    t2 = dot(sub(s2["Q1"], em.p0), em.tan_start()) if em.kind == "L" else None
    out = []
    info = dict(s1=s1, s2=s2, cross=None)
    order = [edges[(k1 + 3 + j) % n] for j in range(n - 3)]      # the rest of the loop, after e2 and up to e0
    new_e0 = None if norm(sub(s1["Q1"], e0.p0)) < 1e-9 else trimmed(e0, new_p1=s1["Q1"])
    new_e2 = None if norm(sub(s2["Q2"], e2.p1)) < 1e-9 else trimmed(e2, new_p0=s2["Q2"])
    out += order
    if new_e0 is not None:
        out.append(new_e0)
    overlap = t1 is not None and t1 > t2 + 1e-9
    if overlap:
        # the arcs cross: take the intersection of the two circles that lies on both arcs
        best = None
        for X in inter(("circle", s1["C"], s1["r"]), ("circle", s2["C"], s2["r"])):
            _, in1 = Edge.arc_c(s1["Q1"], s1["Q2"], s1["C"], s1["side"] > 0).foot(X)
            _, in2 = Edge.arc_c(s2["Q1"], s2["Q2"], s2["C"], s2["side"] > 0).foot(X)
            if in1 and in2:
                best = X if best is None or X[1] < best[1] else best
        if best is None:
            return None, None
        info["cross"] = best
        out.append(Edge.arc_c(s1["Q1"], best, s1["C"], s1["side"] > 0))
        out.append(Edge.arc_c(best, s2["Q2"], s2["C"], s2["side"] > 0))
        u1 = Edge.arc_c(s1["Q1"], best, s1["C"], s1["side"] > 0).tan_end()
        u2 = Edge.arc_c(best, s2["Q2"], s2["C"], s2["side"] > 0).tan_start()
        info["included"] = 180.0 - math.degrees(math.atan2(abs(cross(u1, u2)), dot(u1, u2)))
    else:
        out.append(a1)
        if t1 is not None and abs(t1 - t2) > 1e-9:
            out.append(Edge.line(s1["Q2"], s2["Q1"]))
        out.append(a2)
        info["included"] = 180.0
    if new_e2 is not None:
        out.append(new_e2)
    return out, info


# ------------------------------------------------------------------ areas
def area(edges):
    """Exact (Green) area of the closed profile."""
    s = 0.0
    for e in edges:
        if e.kind == "L":
            s += cross(e.p0, e.p1)
        else:
            a0, a1 = ang(e.p0, e.c), ang(e.p0, e.c) + e.sweep
            s += e.R * e.R * e.sweep + e.c[0] * e.R * (math.sin(a1) - math.sin(a0)) - e.c[1] * e.R * (math.cos(a1) - math.cos(a0))
    return s / 2


def moment_x(edges):
    """The integral of x dA over the profile (for the volume of a solid of revolution about the x = 0 axis: 2 pi times this)."""
    s = 0.0
    for e in edges:
        if e.kind == "L":
            s += (e.p0[0] ** 2 + e.p0[0] * e.p1[0] + e.p1[0] ** 2) / 3 * (e.p1[1] - e.p0[1])
        else:
            a0 = ang(e.p0, e.c); a1 = a0 + e.sweep
            cx, R = e.c[0], e.R
            i1 = math.sin(a1) - math.sin(a0)
            i2 = e.sweep / 2 + (math.sin(2 * a1) - math.sin(2 * a0)) / 4
            i3 = (math.sin(a1) - math.sin(a1) ** 3 / 3) - (math.sin(a0) - math.sin(a0) ** 3 / 3)
            s += R * (cx * cx * i1 + 2 * cx * R * i2 + R * R * i3)
    return s / 2


def outline(edges, n=200):
    pts = []
    for e in edges:
        pts += e.sample(n)[:-1] if e.kind == "A" else [e.p0]
    return pts


def to_path(edges):
    """Tokens for gprobe / the recipe: S x z, then L x z or A mx mz x z for every edge, the closing edge left implicit."""
    t = [("S", edges[0].p0)]
    for e in edges[:-1]:
        t.append(("L", e.p1) if e.kind == "L" else ("A", e.mid(), e.p1))
    last = edges[-1]
    if last.kind == "A":
        t.append(("A", last.mid(), last.p1))
    return t


def parse_path(tokens):
    """tokens like ['S', x, z, 'L', x, z, 'A', mx, mz, x, z] -> CCW edge list."""
    edges, i, cur, first = [], 0, None, None
    while i < len(tokens):
        t = tokens[i]
        if t == "S":
            cur = first = (float(tokens[i + 1]), float(tokens[i + 2])); i += 3
        elif t == "L":
            n = (float(tokens[i + 1]), float(tokens[i + 2])); edges.append(Edge.line(cur, n)); cur = n; i += 3
        else:
            m = (float(tokens[i + 1]), float(tokens[i + 2])); n = (float(tokens[i + 3]), float(tokens[i + 4]))
            edges.append(Edge.arc3(cur, m, n)); cur = n; i += 5
    if norm(sub(cur, first)) > 1e-9:
        edges.append(Edge.line(cur, first))
    if area(edges) < 0:
        edges = [e.reversed() for e in reversed(edges)]
    return edges


def corner_index(edges, P, tol=1e-6):
    """k such that edges[k] ends at P."""
    for k, e in enumerate(edges):
        if norm(sub(e.p1, P)) < tol:
            return k
    raise ValueError(P)


if __name__ == "__main__":
    # self-test against the closed forms of oracle.py (right angle) and a circle
    import oracle
    box = parse_path(["S", 0, 0, "L", 4, 0, "L", 4, 6, "L", 0, 6])
    for r in (1.0, 3.9, 4.0, 4.5, 6.0, 7.0):
        k = corner_index(box, (0, 6))
        ne, s = fillet_corner(box, k, r)
        want = 24 - oracle.corner(4, 6, r)["area"]
        got = area(ne)
        assert abs(got - want) < 1e-9, (r, got, want)
    ne = parse_path(["S", 0, 0, "A", 1, -1, 2, 0, "A", 1, 1, 0, 0])      # a disc radius 1 centred (1, 0)
    assert abs(area(ne) - math.pi) < 1e-9
    assert abs(moment_x(ne) - math.pi) < 1e-9                            # centroid x = 1
    print("section.py self-test ok")
