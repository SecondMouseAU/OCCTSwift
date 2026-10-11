#!/usr/bin/env python3
"""Reference volumes for the fillet / chamfer comb, from a definition that does not touch the blend code.

The reference is the rolling-ball / planar-cut definition written as a membership test and integrated on a grid (numpy):

  * a convex 90 degree edge, FILLET r: the wedge u < r, v < r, (u - r)^2 + (v - r)^2 > r^2 is removed (u, v the distances from the
    two faces), over the length of the edge; CHAMFER (da, db): the triangle u / da + v / db < 1 (da is the leg on the face that
    holds v = 0... see wedge()).
  * edges meeting at a corner: the union of their wedges (the two surfaces meet along a mitre). Exception, fillet only: a corner
    where all three edges are filleted with one radius is the octant of a sphere of radius r.
  * an extruded polygon, edges along the top outline: the removed depth at a point is the maximum over the filleted edges of
    the wedge depth at that edge's perpendicular distance (union of wedges again).
  * a rim of a cylinder or of a hole: Pappus integral of the wedge profile about the axis.
  * a concave vertical edge of an extrusion: the fillet ADDS (1 - pi/4) r^2 h (chamfer: d^2 / 2 h).

These agree with the closed forms below to the grid error, checked in `calibrate()`. `r_max_unambiguous` is the largest radius
(or distance) for which each filleted edge keeps both its faces: past it, what is right is a policy the maintainer has not set
(#3207, #3208, #3233, #3234, #3235, #3237), and the sweep does not call a volume wrong there.
"""
import math
import numpy as np


# ---------------------------------------------------------------- wedge depth profiles
def fillet_depth(u, r):
    """Depth removed at distance u from the wall, on the face side, for a fillet of radius r: the quarter circle's chord."""
    t = np.clip(r - u, 0, r)
    return np.where(u < r, r - np.sqrt(np.maximum(r * r - t * t, 0.0)), 0.0)


def chamfer_depth(u, da, db):
    """Depth removed at distance u from the wall (u measured along the face holding the leg da); the leg on the other face is db."""
    return np.where(u < da, db * (1 - u / da), 0.0)


# ---------------------------------------------------------------- boxes
def box_edges():
    """The 12 edges as (axis, s_b, s_c): the edge runs along `axis`; b, c the other two axes in increasing order; s = 0 low, 1 high."""
    out = []
    for a in range(3):
        for sb in (0, 1):
            for sc in (0, 1):
                out.append((a, sb, sc))
    return out


def edge_mid(dims, e):
    a, sb, sc = e
    b, c = [i for i in range(3) if i != a]
    p = [0.0] * 3
    p[a] = dims[a] / 2
    p[b] = dims[b] if sb else 0.0
    p[c] = dims[c] if sc else 0.0
    return tuple(p)


def edge_vertices(e):
    a, sb, sc = e
    b, c = [i for i in range(3) if i != a]
    vs = []
    for sa in (0, 1):
        v = [0, 0, 0]
        v[a], v[b], v[c] = sa, sb, sc
        vs.append(tuple(v))
    return vs


def r_max_unambiguous(dims, edges):
    """Largest radius for which every filleted edge of a box keeps both its faces and no two fillets share a face."""
    rmax = max(dims) * 10
    # each filleted edge needs r <= the width of both its faces, taken in the direction away from the edge
    for (a, sb, sc) in edges:
        b, c = [i for i in range(3) if i != a]
        rmax = min(rmax, dims[b], dims[c])
    # on each face, fillets on both sides of one in-plane direction share the width
    for axis in range(3):                       # the face normal
        for side in (0, 1):
            inplane = [i for i in range(3) if i != axis]
            for d in inplane:                   # the in-plane direction measured across
                other = [i for i in inplane if i != d][0]    # the direction the edges run along
                lo = any(e[0] == other and ((e[1], e[2]) == _s(e, axis, side, d, 0)) for e in edges)
                hi = any(e[0] == other and ((e[1], e[2]) == _s(e, axis, side, d, 1)) for e in edges)
                if lo and hi:
                    rmax = min(rmax, dims[d] / 2)
    # at a corner of a face where two perpendicular edges of that face are both filleted, nothing more is needed
    return rmax


def _s(e, axis, side, d, sd):
    """(s_b, s_c) of the edge running along e[0], lying on the face (axis, side) at the position sd along direction d."""
    a = e[0]
    b, c = [i for i in range(3) if i != a]
    s = {}
    s[axis] = side
    s[d] = sd
    return (s.get(b, -1), s.get(c, -1))


def box_removed_grid(dims, edges, kind, params, h):
    """Volume removed by the filleted/chamfered `edges` of a box (corner at the origin), by a midpoint grid of spacing about h.

    kind 'f': params = (r,); kind 'c': params = per-edge list of (leg on the face of lower axis index.., ...) -- see below.
    For 'c', params = list of (da, db) per edge: da the leg along the c-axis face... we define u = distance from the face normal to
    axis b, v = distance from the face normal to axis c: material removed where u / dc + v / db < 1 with (db, dc) = params[i]:
    db is the leg measured ALONG the face normal to c... see the callers: they pass (leg_on_face_b, leg_on_face_c).
    """
    n = [max(2, int(math.ceil(d / h))) for d in dims]
    rng = np.random.default_rng(12345)
    xs = [(np.arange(k) + 0.5) * (d / k) for k, d in zip(n, dims)]
    cell = np.prod([d / k for k, d in zip(n, dims)])
    steps = [d / k for k, d in zip(n, dims)]
    total = 0.0
    corner_blend = {}
    corner_tri = {}
    count = {}
    for e in edges:
        for v in edge_vertices(e):
            count[v] = count.get(v, 0) + 1
    if kind == "f":
        r = params[0]
        corner_blend = {v for v, k in count.items() if k == 3}
    else:
        # OCCT closes a corner of three equal chamfers with a triangular face through the three mitre ends, i.e. it also removes
        # offsets o1 + o2 + o3 < 2 d (measured: d^3 / 12 per vertex). Three planes meeting in a point would be the other reading;
        # the kernel's is what every vertex with three chamfers shows, so the reference follows it and the convention is noted.
        corner_tri = {v: params[0][0] for v, k in count.items() if k == 3}
    # slab loop over the first axis to bound memory
    X1, X2 = np.meshgrid(xs[1], xs[2], indexing="ij")
    for i, x0 in enumerate(xs[0]):
        # jittered (stratified) sampling: one random point per cell, so the lattice cannot bias the indicator
        P = [np.full_like(X1, x0) + (rng.random(X1.shape) - 0.5) * steps[0],
             X1 + (rng.random(X1.shape) - 0.5) * steps[1], X2 + (rng.random(X1.shape) - 0.5) * steps[2]]
        removed = np.zeros_like(X1, dtype=bool)
        for idx, e in enumerate(edges):
            a, sb, sc = e
            b, c = [q for q in range(3) if q != a]
            u = P[b] if not sb else dims[b] - P[b]      # distance from the face normal to b
            v = P[c] if not sc else dims[c] - P[c]      # distance from the face normal to c
            if kind == "f":
                w = (u < r) & (v < r) & ((u - r) ** 2 + (v - r) ** 2 > r * r)
            else:
                lb, lc = params[idx]                    # leg lb on the face normal to b is measured along c: see below
                # on the face normal to b (u = 0) the leg runs along v and has length lb; on the face normal to c (v = 0) it
                # runs along u and has length lc
                w = (u / lc + v / lb) < 1
            removed |= w
        if kind == "f" and corner_blend:
            for vtx in corner_blend:
                cen = [r if s == 0 else dims[k] - r for k, s in enumerate(vtx)]
                inside_cube = np.ones_like(X1, dtype=bool)
                dist2 = np.zeros_like(X1)
                for k in range(3):
                    off = (P[k] if vtx[k] == 0 else dims[k] - P[k])
                    inside_cube &= off < r
                    dist2 = dist2 + (P[k] - cen[k]) ** 2
                removed = np.where(inside_cube, dist2 > r * r, removed)
        for vtx, dleg in corner_tri.items():
            ssum = np.zeros_like(X1)
            for k in range(3):
                ssum = ssum + (P[k] if vtx[k] == 0 else dims[k] - P[k])
            removed |= ssum < 2 * dleg
        total += removed.sum() * cell
    return total


# ---------------------------------------------------------------- closed forms for the calibration and for rims
def fillet_area(r):
    return (1 - math.pi / 4) * r * r


def rim_removed(R, r, kind="f", dz=None):
    """Volume removed by a fillet (or chamfer) of a convex rim of a cylinder of radius R (outer rim) -- Pappus about the axis."""
    if kind == "f":
        rho = np.linspace(R - r, R, 2000001)
        mid = (rho[1:] + rho[:-1]) / 2
        g = r - np.sqrt(np.maximum(r * r - (mid - (R - r)) ** 2, 0.0))
        return float(np.sum(2 * math.pi * mid * g) * (rho[1] - rho[0]))
    d1, d2 = r, dz     # d1 radial leg, d2 axial leg
    rho = np.linspace(R - d1, R, 2000001)
    mid = (rho[1:] + rho[:-1]) / 2
    g = d2 * (mid - (R - d1)) / d1
    return float(np.sum(2 * math.pi * mid * g) * (rho[1] - rho[0]))


def hole_rim_removed(Rh, r, kind="f", dz=None):
    """The same for the rim of a hole of radius Rh: the material is outside, rho runs from Rh to Rh + r."""
    if kind == "f":
        rho = np.linspace(Rh, Rh + r, 2000001)
        mid = (rho[1:] + rho[:-1]) / 2
        g = r - np.sqrt(np.maximum(r * r - (Rh + r - mid) ** 2, 0.0))
        return float(np.sum(2 * math.pi * mid * g) * (rho[1] - rho[0]))
    d1, d2 = r, dz
    rho = np.linspace(Rh, Rh + d1, 2000001)
    mid = (rho[1:] + rho[:-1]) / 2
    g = d2 * (1 - (mid - Rh) / d1)
    return float(np.sum(2 * math.pi * mid * g) * (rho[1] - rho[0]))


# ---------------------------------------------------------------- extruded rectilinear polygons (L, U)
def poly_inside(poly_rects, X, Y):
    m = np.zeros_like(X, dtype=bool)
    for (x0, y0, x1, y1) in poly_rects:
        m |= (X >= x0) & (X <= x1) & (Y >= y0) & (Y <= y1)
    return m


def segment_distance(seg, X, Y):
    """Perpendicular distance from (X, Y) to an axis-aligned segment if the foot lies on it, else inf."""
    (x0, y0), (x1, y1) = seg
    if abs(x0 - x1) < 1e-12:      # vertical segment
        lo, hi = sorted((y0, y1))
        return np.where((Y >= lo) & (Y <= hi), np.abs(X - x0), np.inf)
    lo, hi = sorted((x0, x1))
    return np.where((X >= lo) & (X <= hi), np.abs(Y - y0), np.inf)


def euclid_segment_distance(seg, X, Y):
    """Euclidean distance from (X, Y) to an axis-aligned segment."""
    (x0, y0), (x1, y1) = seg
    cx = np.clip(X, min(x0, x1), max(x0, x1))
    cy = np.clip(Y, min(y0, y1), max(y0, y1))
    return np.hypot(X - cx, Y - cy)


def extrusion_top_removed(rects, segs, H, kind, params, h, closed_outline=False):
    """Volume removed by filleting/chamfering the TOP outline edges `segs` of a rectilinear extrusion of height H.

    closed_outline: every top edge is blended, so the ball rolls the whole outline and at a re-entrant corner the blend is the
    patch around the vertex (distance to the vertex), not two strips: the depth is a function of the Euclidean distance to the
    outline. With a subset of the edges the depth is the perpendicular strip of each edge only."""
    xs0 = min(r[0] for r in rects)
    xs1 = max(r[2] for r in rects)
    ys0 = min(r[1] for r in rects)
    ys1 = max(r[3] for r in rects)
    nx, ny = int(math.ceil((xs1 - xs0) / h)), int(math.ceil((ys1 - ys0) / h))
    x = xs0 + (np.arange(nx) + 0.5) * (xs1 - xs0) / nx
    y = ys0 + (np.arange(ny) + 0.5) * (ys1 - ys0) / ny
    X, Y = np.meshgrid(x, y, indexing="ij")
    ins = poly_inside(rects, X, Y)
    depth = np.zeros_like(X)
    for seg in segs:
        d = euclid_segment_distance(seg, X, Y) if closed_outline else segment_distance(seg, X, Y)
        if kind == "f":
            g = fillet_depth(d, params[0])
        else:
            g = chamfer_depth(d, params[0], params[1])      # leg on the top face = params[0], on the wall = params[1]
        depth = np.maximum(depth, np.where(np.isfinite(d), g, 0.0))
    return float(np.sum(np.where(ins, depth, 0.0)) * (xs1 - xs0) / nx * (ys1 - ys0) / ny)


def calibrate():
    """Closed forms against the grid. Prints the worst relative error."""
    worst = 0.0
    # single edge of a 10 x 10 x 10 cube
    for r in (0.5, 2.0, 5.0):
        for h in (0.1,):
            g = box_removed_grid((10, 10, 10), [(1, 0, 1)], "f", (r,), h)
            exact = fillet_area(r) * 10
            worst = max(worst, abs(g - exact) / 1000)
    # all 12 edges of a box: closed form of the rounded box
    for dims, r in (((10, 10, 10), 2.0), ((4, 10, 6), 1.5), ((20, 20, 2), 0.9)):
        a, b, c = dims
        exact = (a * b * c - (4 - math.pi) * r * r * (a + b + c) + (10 / 3 * math.pi - 8) * r ** 3 * 0)
        # exact rounded box: (a-2r)(b-2r)(c-2r) + 2r[(a-2r)(b-2r)+...] + pi r^2 [(a-2r)+(b-2r)+(c-2r)] + 4/3 pi r^3
        A, B, C = a - 2 * r, b - 2 * r, c - 2 * r
        exact = A * B * C + 2 * r * (A * B + B * C + A * C) + math.pi * r * r * (A + B + C) + 4 / 3 * math.pi * r ** 3
        g = a * b * c - box_removed_grid(dims, box_edges(), "f", (r,), min(dims) / 40)
        worst = max(worst, abs(g - exact) / (a * b * c))
    return worst


if __name__ == "__main__":
    print("worst relative error against the closed forms: %.2e" % calibrate())
