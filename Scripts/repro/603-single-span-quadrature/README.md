# #603 — one Gauss quadrature is not enough to measure an arc

`Curve3D.length` on a full ellipse was up to 1.7% wrong, and a parabola over a wide range 3.1%
wrong in the other direction. Same mechanism as [#477](https://github.com/SecondMouseAU/OCCTSwift/issues/477),
on curves that fix could not reach.

```bash
clang++ -std=c++17 -ObjC++ -w -O2 \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/603-single-span-quadrature/occt_603_probe.mm -o /tmp/occt_603_probe
/tmp/occt_603_probe
```

## The mechanism

`CPnts_AbscissaPoint::Length` integrates `|C'(u)|` with **one** fixed-order Gauss rule over the
whole range it is handed — `CPnts_AbscissaPoint.cxx`'s `order()` picks 10 for a conic, 5 for a
parabola, `2 * Degree` for a Bezier, `2 * NbPoles - 1` for a BSpline. `GCPnts_AbscissaPoint::Length`
splits at the `GeomAbs_CN` interval boundaries and applies that rule per interval, which is the
whole of what #477 bought. A conic has exactly **one** interval, so the rule still has to cover the
entire domain in one go.

It is therefore not a conic defect and not a "single span" defect: the error is set by how much
`|C'|` varies across one integration interval. The 8 × 3 ellipse is 0.337% out over `[0, 2π]`,
0.0001% over `[0, π]` and exact over `[0, π/2]` — same curve, same rule, three interval widths. A
5-point interpolated BSpline (four intervals) is 6.0e-5 out; a 200-point one 3.1e-8.

A circle and a line are exempt for a different reason: `computeType` classifies them
`GCPnts_LengthParametrized` and the answer is `|u2 − u1| × ratio`, no quadrature at all.

## Measured, whole curve

`today` is what the bridge called before this fix; `fixed` is the subdivided measurement; the
reference is a 16-point composite Gauss-Legendre quadrature of `|C'(u)|` over 40,000 panels, taken
through the adaptor's own `D1`.

| curve | intervals | today | fixed | today's error | fixed error |
|---|---|---|---|---|---|
| ellipse 8 × 3 | 1 | 36.489426687 | 36.366862783 | **+0.337%** | 1.7e-14 |
| ellipse 10 × 1 | 1 | 41.243157870 | 40.639741801 | **+1.485%** | 1.8e-13 |
| ellipse 100 × 30 | 1 | 441.001217874 | 438.591006957 | **+0.550%** | 9.2e-15 |
| ellipse 1 × 0.05 | 1 | 4.089251430 | 4.019425619 | **+1.737%** | 2.9e-14 |
| ellipse 1 × 0.001 | 1 | 4.076274504 | 4.000015588 | **+1.907%** | 1.2e-11 |
| parabola f=3 over [-100, 100] | 1 | 1638.523403092 | 1690.708711624 | **−3.087%** | 9.6e-14 |
| parabola f=3 over [-20, 20] | 1 | 80.869096808 | 81.115422225 | −0.304% | 7.0e-14 |
| hyperbola 5/2 over [-4, 4] | 1 | 285.669841141 | 285.479768689 | +0.067% | 2.1e-14 |
| Bezier degree 3, whipping poles | 1 | 48.124450786 | 48.215369891 | −0.189% | 2.0e-14 |
| Bezier degree 3, near-cusp | 1 | 16.964857992 | 16.942042960 | +0.135% | 1.4e-14 |
| interpolated BSpline, 5 points | 4 | 110.963893077 | 110.970568312 | −0.0060% | 2.5e-14 |
| interpolated BSpline, 40 points | 39 | 1010.874896366 | 1010.876436705 | −0.0002% | 3.4e-13 |
| circle r=5 | 1 | 31.415926536 | 31.415926536 | exact | exact |
| line, trimmed [0, 25] | 1 | 25.000000000 | 25.000000000 | exact | exact |

The **parabola is the worst case anywhere in the family**, and the only one whose error has the
opposite sign — it gets an order-5 rule, the lowest `order()` hands out to anything curved. The
issue named it as worth measuring and did not measure it.

The 2D spelling, an elliptical edge and a wire containing one all reproduce their 3D curve's number
exactly, before and after: `GCPnts_AbscissaPoint::length` is one template shared by
`Adaptor3d_Curve` and `Adaptor2d_Curve2d`, and `BRepAdaptor_Curve` / `BRepAdaptor_CompCurve` are
just more `Adaptor3d_Curve`s.

## Trap 1 — deciding which number is wrong

On the 5-point interpolation, GCPnts and the Gauss-Legendre reference disagreed by 6.0e-5 relative,
which is far too small to eyeball and far too large to be rounding. A single reference cannot settle
that. A structurally different second one can:

```
GCPnts                     110.963893077389
Gauss-Legendre, 40k panels 110.970568311821
chord sum, Richardson      110.970568311825   <- agrees with the first to 12 digits
subdivided (the fix)       110.970568311824
```

## Trap 2 — where the subdivision has to happen

The obvious design is to halve the whole requested range and stop when two levels agree. It does not
work, and it fails silently. On the same 5-point interpolation:

```
whole range in  1: 110.963893077389  rel err 6.015e-05
whole range in  2: 110.963893077389  rel err 6.015e-05   <- bit-identical to n=1
whole range in  4: 110.963880486096  rel err 6.027e-05
whole range in  8: 110.970627372779  rel err 5.322e-07
whole range in 16: 110.970568370265  rel err 5.267e-10
```

The domain midpoint of a uniformly-knotted curve **is** a knot, and GCPnts already splits there — so
the level-2 sum repeats the level-1 sum exactly and any "have two levels agreed?" test reports
convergence on an answer that never moved.

Subdividing **inside** each `GeomAbs_CN` interval removes the coincidence by construction: there is
no boundary of GCPnts' own left inside one for the split points to land on. That is what
`occtAdaptorArcLength` (`Sources/OCCTBridge/src/OCCTBridge_Internal.h`) does.

## The inverse had to move with it

OCCT's root finder inverts the very quadrature this replaces — `CPnts_MyRootFunction::Value(X)` is
one Gauss rule over `[u0, X]` minus the target. So before this fix, the length and its inverse were
wrong by the *same* amount and `parameterAtLength(length)` still landed on the curve's last
parameter. Fixing only the length breaks that:

| ellipse | fraction | kernel solver, fed the accurate total | walked |
|---|---|---|---|
| 8 × 3 | 0.25 | arc err 2.0e-09 | 6.8e-15 |
| 8 × 3 | 0.50 | arc err 7.3e-07 | 1.1e-14 |
| 8 × 3 | **1.00** | u = 6.2438 for a domain ending at 6.2832, **arc err 3.3e-03** | 1.7e-14 |
| 10 × 1 | **1.00** | u = 6.0358, **arc err 1.0e-02** | 1.8e-13 |
| 1 × 0.05 | **1.00** | u = 6.0000, **arc err 1.1e-02** | 2.9e-14 |

`occtArcWalkToLength` accumulates the same sub-piece quadratures the length is summed from and hands
the final, narrow piece to the kernel's own solver, which is accurate at that width.

A target longer than the curve keeps its old answer: the kernel reports `IsDone` with a parameter
outside the curve's own domain (12.566 on an ellipse bounded by 2π), and the walk falls back to it
rather than turning a reported answer into a failure.

## Downstream, measured rather than assumed

The issue lists three things as inheriting the defect. Measured:

* **`parameterAtLength` / `edgeParameterAtFraction` — yes**, and both are fixed here.
* **`GCPnts_UniformAbscissa` (uniform sampling by arc length) — no.** On the worst ellipse
  (1 × 0.05), at 7 and at 9 points, the *true* arc between consecutive samples is uniform to
  1.6e-10 and 1.9e-10. The sampler was already accurate and is untouched.
* **`BRepGProp::LinearProperties` — yes, and it is NOT fixed here.** It runs its own integrator
  and returns 41.243157870 for the 10 × 1 elliptical edge against a truth of 40.639741801
  (+1.485%, the identical figure). It is reached from `Shape.linearProperties()`, whose `length`
  therefore now **disagrees** with `Shape.edgeArcLength` on the same edge, where before both were
  wrong together. Reimplementing mass properties is a different piece of work; filed separately.

## Cost

| curve | before | after |
|---|---|---|
| circle / line (closed form) | 0.00 µs | 0.02 µs |
| ellipse 8 × 3 | 0.11 µs | 3.5 µs |
| interpolated BSpline, 40 spans | 17 µs | 95 µs |
| interpolated BSpline, 200 spans | 89 µs | 452 µs |

Roughly 5×, with a floor of three quadratures per `GeomAbs_CN` interval where there used to be one.
Curves whose closed form is exact (`GeomAbs_Line`, `GeomAbs_Circle`, a 2-pole Bezier or BSpline)
converge on the first split with nothing to remove and stay at the closed form's value.

## Not done here

The kernel fix. Both defects live in two files in
`src/ModelingData/TKGeomBase/CPnts/`: `CPnts_AbscissaPoint::Length`'s
`math_GaussSingleIntegration` and `CPnts_MyRootFunction::Value`'s, which are the same call over the
same kind of range. One shared adaptive helper would fix them together and every other OCCT
consumer with them (including `GCPnts_UniformAbscissa`'s internals and, separately, whatever
`BRepGProp` should do about its own). That is the issue's option 2; this branch is option 1, the
bridge fix that ships against any `OCCT.xcframework`, and it composes with a later kernel fix rather
than conflicting with it — a converged kernel answer simply makes the first subdivision level agree
immediately.
