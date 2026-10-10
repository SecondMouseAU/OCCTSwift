#!/usr/bin/env python3
"""Analytic oracle for two equal fillets on opposite edges of a face of width w (cross-section area).

Cross-section, looking along the edges: a rectangle w wide and h tall. The left edge is rounded by
the circle of radius r centred (r, h - r), the right edge by the one centred (w - r, h - r). The
kept region is the INTERSECTION of the two rounded profiles.

  r <= w/2   the arcs do not reach each other; removed area = 2 (1 - pi/4) r^2
  w/2 <= r < w   the arcs cross on the mid line x = w/2 at height y* = h - r + sqrt(w r - w^2/4);
                 the included angle between the arcs there is 180 - 2 asin((r - w/2)/r) degrees
                 (180 at r = w/2: the semicircle, tangent-continuous), and

      removed area A(r) = w r - pi r^2/2 + (r - w/2) sqrt(w r - w^2/4) + r^2 asin(1 - w/(2r))

                 (derivation: A = 2 * integral over x in [0, w/2] of (r - sqrt(r^2 - (x - r)^2)) dx,
                 antiderivative of sqrt(r^2 - u^2) is (u/2) sqrt(r^2 - u^2) + (r^2/2) asin(u/r)).
  Both agree at r = w/2 (A = 2 (1 - pi/4) r^2). Range: w/2 <= r < min(w, h). At r = w the left arc
  reaches the right edge (OCCT#1177 part 1); r <= h keeps the arcs on the side faces.
"""
import math
import numpy as np

def removed_area(w, r):
    if r <= w / 2:
        return 2 * (1 - math.pi / 4) * r * r
    return w * r - math.pi * r * r / 2 + (r - w / 2) * math.sqrt(w * r - w * w / 4) + r * r * math.asin(1 - w / (2 * r))

def volume(w, h, L, r):
    return w * h * L - L * removed_area(w, r)

def numeric_removed(w, h, r, n=200000):
    xs = (np.arange(n) + .5) / n * w
    left = np.where(xs < r, np.sqrt(np.maximum(r * r - (xs - r) ** 2, 0)), r)
    right = np.where(xs > w - r, np.sqrt(np.maximum(r * r - (xs - (w - r)) ** 2, 0)), r)
    top = h - r + np.minimum(left, right)
    return float(np.sum(h - np.minimum(top, h)) * (w / n))

if __name__ == "__main__":
    w, h, L = 4.0, 6.0, 10.0
    print("r        analytic_area   numeric_area   volume      crossing_height  included_angle_deg")
    for r in (1.0, 1.9999, 2.0, 2.0001, 2.2, 2.5, 3.0, 3.5, 3.9):
        a, nmr = removed_area(w, r), numeric_removed(w, h, r)
        ystar = h - r + math.sqrt(w * r - w * w / 4) if r >= w / 2 else float("nan")
        ang = 180 - 2 * math.degrees(math.asin(max(r - w / 2, 0) / r)) if r >= w / 2 else float("nan")
        print(f"{r:<8} {a:<15.9f} {nmr:<14.9f} {volume(w, h, L, r):<11.6f} {ystar:<16.6f} {ang:.3f}")
