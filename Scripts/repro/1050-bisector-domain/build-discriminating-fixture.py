#!/usr/bin/env python3
"""Derive the fixture that separates an input-derived bound from a curve-derived one (#1050).

The three fixtures in the issue all have their meeting point inside `2 * span + 1`, so they cannot
tell the two candidate bounds apart. This script solves for one that does, and prints the numbers
the probe hard-codes so the reader can see where they came from rather than taking them on trust.

Construction. Bisector 1 is that of A(0,0) B(0,10): a half-line starting at the midpoint (0,5) and
running along -x. Pick a target meeting point on it, at parameter `u`. Pick where bisector 2 should
start, `m2`. Bisector 2 must then run from `m2` towards the target, and since a point-point bisector
runs along `perp(D - C)` normalised, that fixes `D - C` up to a scale, which is chosen so the pair
is 10 apart. C and D follow.

The whole point is that `u` has to exceed `2 * span + 1` while the two bisectors still cross at a
healthy angle, so the miss is attributable to the bound and not to two nearly-parallel lines.

    python3 build-discriminating-fixture.py
"""

import math


def build(u: float, m2: tuple[float, float], pair_length: float = 10.0):
    a = (0.0, 0.0)
    b = (0.0, 10.0)

    # Bisector 1: starts at the midpoint of AB, runs along perp(B - A) normalised.
    m1 = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    d1 = (-(b[1] - a[1]), b[0] - a[0])
    n1 = math.hypot(*d1)
    d1 = (d1[0] / n1, d1[1] / n1)

    target = (m1[0] + u * d1[0], m1[1] + u * d1[1])

    # Bisector 2 must run from m2 to the target, and its direction is perp(D - C) normalised.
    # perp(v) == (-v.y, v.x), so v == (w.y, -w.x) for a wanted direction w.
    w = (target[0] - m2[0], target[1] - m2[1])
    nw = math.hypot(*w)
    v = (w[1] / nw * pair_length, -w[0] / nw * pair_length)
    c = (m2[0] - v[0] / 2, m2[1] - v[1] / 2)
    d = (m2[0] + v[0] / 2, m2[1] + v[1] / 2)

    pts = [a, b, c, d]
    span = max(
        math.hypot(p[0] - q[0], p[1] - q[1]) for i, p in enumerate(pts) for q in pts[i + 1 :]
    )
    d2 = (w[0] / nw, w[1] / nw)
    crossing = math.degrees(math.acos(max(-1.0, min(1.0, d1[0] * d2[0] + d1[1] * d2[1]))))
    return {
        "a": a,
        "b": b,
        "c": c,
        "d": d,
        "target": target,
        "u": u,
        "span": span,
        "input_bound": 2 * span + 1,
        "crossing_deg": crossing,
    }


if __name__ == "__main__":
    r = build(u=150.0, m2=(-20.0, 30.0))
    print(f"A {r['a']}  B {r['b']}")
    print(f"C ({r['c'][0]:.4f}, {r['c'][1]:.4f})  D ({r['d'][0]:.4f}, {r['d'][1]:.4f})")
    print(f"meeting point {r['target']} at parameter u = {r['u']}")
    print(f"largest pairwise separation of the four points: {r['span']:.4f}")
    print(f"2 * span + 1 = {r['input_bound']:.4f}   (must be well below u)")
    print(f"crossing angle of the two bisectors: {r['crossing_deg']:.2f} degrees")
    assert r["input_bound"] < r["u"], "fixture does not discriminate: the input bound reaches u"
    assert r["crossing_deg"] > 5, "fixture is near-parallel, the miss would not be the bound's"
    print("\nboth conditions hold, so a miss here is attributable to the bound")
