#!/usr/bin/env python3
"""Analytic oracles for fillets whose arcs meet each other or run out of face (cross-section area, volume).

Looking along the edges, a box is a rectangle w wide and h tall. Coordinates here are (x, d): x across the
top face, d the depth below the top face.

A and B. Two fillets on the opposite top edges, radii r1 (left, x = 0) and r2 (right, x = w).
  The left arc is the upper half of the circle centre (r1, r1), the right arc the one centre (w - r2, r2).
  Removed depth at x:  g1(x) = r1 - sqrt(r1^2 - (x - r1)^2) on [0, r1], else 0   (g2 mirrored).
  Kept profile = INTERSECTION of the two rounded profiles, so the removed depth is max(g1, g2) and
      A = integral over [0, w] of max(g1, g2) dx.
  s = r1 + r2 - w.
    s <= 0  the arcs do not reach each other:           A = (1 - pi/4)(r1^2 + r2^2); at s = 0 they are tangent
            to each other at (r1, 0) (both tangent to the top plane there) and each tangent to its wall (case A).
    s > 0   the arcs cross (case B). The radical line of the two circles is
                2 s x = 2 (r2 - r1) d + s (r1 + w - r2),
            the crossing (xc, dc) is its intersection with circle 1 (the root with the smaller d), and
                A = [r1 xc - (F1(xc - r1) - F1(-r1))] + [r2 (w - xc) - (F2(r2) - F2(xc - (w - r2)))]
            with F_r(u) = (u/2) sqrt(r^2 - u^2) + (r^2/2) asin(u/r), the antiderivative of sqrt(r^2 - u^2).
            Equal radii give the closed form of patch 0059's README:
                A(r) = w r - pi r^2/2 + (r - w/2) sqrt(w r - w^2/4) + r^2 asin(1 - w/(2 r)).
  Included angle at the crossing, between the two arcs' tangent rays leaving the crossing towards their own walls,
  measured through the material: 180 - 2 asin((r - w/2)/r) degrees for equal radii.
  Valid range: both radii < w (each fillet alone is a legal fillet) and <= h (the arc stays on its wall).

C and D. A single fillet of radius r on a right-angle convex edge between two planar faces whose widths (the
  distance from the edge to the far edge of each face) are a (face 1, along u) and b (face 2, along v).
  Cross-section corner at O = (0, 0), face 1 on the u axis, face 2 on the v axis, material in u, v >= 0.
    r <= min(a, b)   tangent to both:    centre (r, r), arc ends Q1 = (r, 0), Q2 = (0, r).
    a < r            face 1 runs out. Tangent to face 2 and through the far edge of face 1, P1 = (a, 0):
                     centre (r, sqrt(2 a r - a^2)), Q1 = P1, Q2 = (0, sqrt(2 a r - a^2)), valid while
                     sqrt(2 a r - a^2) <= b, i.e. r <= (a^2 + b^2)/(2 a).
    b < r            face 2 runs out: the mirror image.
    both run out     through P1 = (a, 0) and P2 = (0, b), centre on the perpendicular bisector of P1 P2 on the
                     side away from O, valid for r >= sqrt(a^2 + b^2)/2.
  Removed area = q1 q2/2 - (r^2/2)(theta - sin theta), theta = 2 asin(sqrt(q1^2 + q2^2)/(2 r)): the triangle
  O Q1 Q2 less the circular segment between its hypotenuse and the arc. At r = a the pivot is tangent to face 1
  too (the arc ends on the far edge, tangent), and the formulas agree there.
"""
import math
import numpy as np


def F(r, u):
    return u / 2 * math.sqrt(max(r * r - u * u, 0.0)) + r * r / 2 * math.asin(max(-1.0, min(1.0, u / r)))


def crossing(w, r1, r2):
    """(xc, dc) where the two arcs cross, for r1 + r2 > w."""
    s = r1 + r2 - w
    if abs(r2 - r1) < 1e-14:
        xc = (r1 + w - r2) / 2
        dc = r1 - math.sqrt(max(r1 * r1 - (xc - r1) ** 2, 0.0))
        return xc, dc
    # x = x0 + k d on the radical line; substitute into circle 1: x^2 + d^2 - 2 r1 x - 2 r1 d + r1^2 = 0
    x0 = (r1 + w - r2) / 2
    k = (r2 - r1) / s
    A = k * k + 1
    B = 2 * x0 * k - 2 * r1 * k - 2 * r1
    C = x0 * x0 - 2 * r1 * x0 + r1 * r1
    disc = B * B - 4 * A * C
    best = None
    for d in ((-B - math.sqrt(disc)) / (2 * A), (-B + math.sqrt(disc)) / (2 * A)):
        x = x0 + k * d
        if -1e-9 <= x <= w + 1e-9 and -1e-9 <= d <= min(r1, r2) + 1e-9 and (best is None or d < best[1]):
            best = (x, d)
    return best


def removed_area_ab(w, r1, r2):
    if r1 + r2 - w <= 0:
        return (1 - math.pi / 4) * (r1 * r1 + r2 * r2)
    xc, dc = crossing(w, r1, r2)
    a1 = r1 * xc - (F(r1, xc - r1) - F(r1, -r1))
    a2 = r2 * (w - xc) - (F(r2, r2) - F(r2, xc - (w - r2)))
    return a1 + a2


def removed_area_equal(w, r):
    if r <= w / 2:
        return 2 * (1 - math.pi / 4) * r * r
    return w * r - math.pi * r * r / 2 + (r - w / 2) * math.sqrt(w * r - w * w / 4) + r * r * math.asin(1 - w / (2 * r))


def numeric_ab(w, r1, r2, n=2000000):
    xs = (np.arange(n) + .5) / n * w
    g1 = np.where(xs < r1, r1 - np.sqrt(np.maximum(r1 * r1 - (xs - r1) ** 2, 0)), 0.0)
    g2 = np.where(xs > w - r2, r2 - np.sqrt(np.maximum(r2 * r2 - (xs - (w - r2)) ** 2, 0)), 0.0)
    return float(np.sum(np.maximum(g1, g2)) * (w / n))


def included_angle_ab(w, r1, r2):
    """Degrees, through the material, between the arcs at their crossing; 180 if they only touch."""
    if r1 + r2 <= w:
        return 180.0
    xc, dc = crossing(w, r1, r2)
    c1 = (r1, r1); c2 = (w - r2, r2)
    v1 = (xc - c1[0], dc - c1[1]); v2 = (xc - c2[0], dc - c2[1])
    t1 = (-v1[1], v1[0]); t2 = (v2[1], -v2[0])       # tangent rays towards the own wall: arc 1 to x = 0, arc 2 to x = w
    if t1[0] > 0: t1 = (-t1[0], -t1[1])
    if t2[0] < 0: t2 = (-t2[0], -t2[1])
    cosang = (t1[0] * t2[0] + t1[1] * t2[1]) / (math.hypot(*t1) * math.hypot(*t2))
    return math.degrees(math.acos(max(-1, min(1, cosang))))


def corner(a, b, r):
    """Pivot rule for one fillet on a right-angle corner. dict(case, centre, q1, q2, area), None if no arc."""
    if r <= min(a, b):
        return _fin("tangent-tangent", (r, r), r, r, r)
    cx = math.sqrt(2 * a * r - a * a) if r > a else None    # tangent to face 2, pivot at P1 = (a, 0): arc ends (a, 0), (0, cx)
    cy = math.sqrt(2 * b * r - b * b) if r > b else None    # tangent to face 1, pivot at P2 = (0, b): arc ends (cy, 0), (0, b)
    okx = cx is not None and cx <= b + 1e-12
    oky = cy is not None and cy <= a + 1e-12
    if okx:
        return _fin("pivot at the far edge of face 1", (r, cx), a, cx, r)
    if oky:
        return _fin("pivot at the far edge of face 2", (cy, r), cy, b, r)
    chord = math.hypot(a, b)
    if r < chord / 2 - 1e-12:
        return None
    hh = math.sqrt(max(r * r - chord * chord / 4, 0.0))
    c = (a / 2 + hh * b / chord, b / 2 + hh * a / chord)
    return _fin("pivot at both far edges", c, a, b, r)


def _fin(case, c, q1, q2, r):
    chord = math.hypot(q1, q2)
    theta = 2 * math.asin(min(1.0, chord / (2 * r)))
    return dict(case=case, centre=c, q1=q1, q2=q2, area=q1 * q2 / 2 - (r * r / 2) * (theta - math.sin(theta)))


def pivot_angles(a, b, r):
    """Crease angles (degrees between the outward normals) where the arc meets a face at its pivot edge; none where it
    is tangent. At the far edge of face 1 the other face there has outward normal +u, at the far edge of face 2 it is +v."""
    cd = corner(a, b, r)
    if cd is None:
        return []
    cu, cv = cd["centre"]
    out = []
    if abs(cd["q1"] - a) < 1e-9 and r >= a - 1e-9:
        out.append(math.degrees(math.acos(max(-1, min(1, (a - cu) / r)))))
    if abs(cd["q2"] - b) < 1e-9 and r >= b - 1e-9:
        out.append(math.degrees(math.acos(max(-1, min(1, (b - cv) / r)))))
    return sorted(out)


def numeric_corner(a, b, r, n=4000000):
    """Independent check: integral over u in [0, q1] of the height of the removed strip, from the lower branch of the circle."""
    cd = corner(a, b, r)
    if cd is None:
        return None
    q1, q2, c = cd["q1"], cd["q2"], cd["centre"]
    us = (np.arange(n) + .5) / n * q1
    arc = c[1] - np.sqrt(np.maximum(r * r - (us - c[0]) ** 2, 0.0))
    return float(np.sum(np.clip(arc, 0.0, q2)) * (q1 / n))


def volume(w, h, L, area):
    return w * h * L - L * area


if __name__ == "__main__":
    w, h, L = 4.0, 6.0, 10.0
    print("A/B:  w=4 h=6 L=10")
    print("r1    r2    area_formula   area_numeric   diff       volume       angle_deg  crossing(x,d)")
    for r1, r2 in [(1.5, 2.5), (1, 3), (0.5, 3.5), (2, 2), (2.2, 2.2), (2.5, 2.5), (3, 3), (3.5, 3.5), (3.9, 3.9),
                   (2, 2.5), (1, 3.5), (2.5, 3), (0.5, 3.9), (3.9, 0.5)]:
        A = removed_area_ab(w, r1, r2)
        N = numeric_ab(w, r1, r2)
        cr = crossing(w, r1, r2) if r1 + r2 > w else None
        print(f"{r1:<5} {r2:<5} {A:<14.9f} {N:<14.9f} {abs(A-N):<10.2e} {volume(w,h,L,A):<12.6f} {included_angle_ab(w,r1,r2):<10.4f} {cr}")
    print("equal-radii closed form vs general:")
    for r in (2.0, 2.2, 3.0, 3.9):
        print(f"  r={r}: {removed_area_equal(w, r):.12f} {removed_area_ab(w, r, r):.12f}")
    print("C/D corner (a = width of face 1, b = width of face 2):")
    print("a   b   r     case                             centre              q1,q2              area       numeric    diff")
    for a, b, r in [(4, 6, 3.9), (4, 6, 4.0), (4, 6, 4.5), (4, 6, 5.0), (4, 6, 6.0), (4, 6, 6.5), (4, 6, 7.0), (4, 6, 9.0),
                    (8, 3, 3.5), (8, 3, 4.0), (4, 3, 4.5), (4, 3, 3.5)]:
        cd = corner(a, b, r)
        if cd is None:
            print(a, b, r, "no arc (r < chord/2)")
            continue
        nm = numeric_corner(a, b, r)
        print(f"{a:<3} {b:<3} {r:<5} {cd['case']:<32} ({cd['centre'][0]:.4f},{cd['centre'][1]:.4f})  ({cd['q1']:.4f},{cd['q2']:.4f})  {cd['area']:<10.6f} {nm:<10.6f} {abs(cd['area']-nm):.1e}")
