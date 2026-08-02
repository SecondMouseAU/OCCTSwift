# OCCTSwift#549 probe: the 2D pre-bounded arc-length adaptor, measured

Ground truth for the two spellings of ranged 2D arc length the bridge carried, against the pinned
OCCT 8.0.0p1 kernel.

`Curve2D.arcLength(from:to:)` reached `OCCTCurve2DLength`, which measured through a **pre-bounded**
`Geom2dAdaptor_Curve(curve, u1, u2)`; `Curve2D.length(from:to:)` reaches `OCCTCurve2DGetLengthBetween`,
which passes the range to `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`. #549 was filed as a
consistency question: the 2D spelling rejected a reversed range where the 3D one measured it, and both
behaviours were documented, so which one is correct is a decision rather than a bug report. The issue
left one question open, and it is the one that decides the answer:

> Worth checking whether the 2D pre-bounded form extrapolates the same way before deciding, since that
> would make it a correctness question rather than a consistency one.

#506 answered that for 3D (it does). This probe asks it of 2D, and asks the range-taking form the
follow-up question #506's figures invite: is its clamping a property of the form, or of the curve?

No fixture files needed: every case builds its geometry from a primitive or an interpolation.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/549-curve2d-arclength-range-order/occt_549_curve2d_arclength.mm -o /tmp/occt_549
/tmp/occt_549
```

Parts 1 to 6 measure both forms on the same input across in-domain, reversed, equal-parameter,
out-of-domain, periodic-seam and NaN ranges, on a 5-point 2D interpolation (domain `[0, 318.433]`,
length 353.508), a circle, an unbounded line, a trimmed line and a 3-pole Bezier. Part 7 applies the
bridge's own `catch` and `>= 0` test to show what Swift reports per entry point. Part 8 repeats the
out-of-domain rows in 3D, on the same four curve types.

## Result

**It extrapolates, so #549 is a correctness question too.**

| range | pre-bounded (`arcLength`) | ranged (`length`) |
|---|---|---|
| in domain, forward | 169.457 | 169.457 |
| in domain, reversed | raises `Standard_Failure`, reported as `-1.0` | 169.457 |
| equal parameters | 0 | 0 |
| overshooting both ends by a domain width | **8082.404** | 353.508 |
| overshooting the upper end only | **2549.691** | 353.508 |
| wholly outside the domain | **1.259** | 0 |
| periodic seam, full period, two periods, unbounded sub-range | agree | agree |

So `Curve2D.arcLength(from:to:)` measured a 353-unit curve as 8082 and reported it as an ordinary
success. That is the same defect #477 removed from the 3D path and #506 removed from the 3D orphan,
still live in 2D only because the two dimensions were fixed one at a time.

**The reversed-range raise is real in this build**, on all four curve types, so `No_Exception` does
not void this particular precondition (contrast #487).

### The range-taking form does not clamp on every curve, and the 3D docs said it did

Measured in both dimensions, on the same four curve types:

| curve | range wholly outside the domain | ranged form measures |
|---|---|---|
| 5-point interpolation (multi-span BSpline) | `[l+1, l+2]` | **0** |
| 3-pole Bezier | `[2, 3]` (domain `[0, 1]`) | 41.256 |
| line trimmed to `[0, 10]` | `[20, 30]` | 10 |

`GCPnts_AbscissaPoint::length` picks one of three strategies by curve type
(`GCPnts_AbscissaPoint.cxx`): a curve with more than one `GeomAbs_CN` interval intersects each
interval with `[min(u1,u2), max(u1,u2)]`, which is where both the order tolerance and the clamping
come from; a line, a circle or a 2-pole non-rational spline returns `|u2 - u1| * ratio`, order
tolerant and unclamped; anything else, a single-span Bezier included, integrates the range as given.

`Curve3D.length(from:to:)` documented the clamping unconditionally ("Parameters outside the curve's
domain are clamped to it, so a range wholly outside measures `0`"), which holds only for the first
of those three. Corrected in the same PR, since #549 aligns the 2D wording onto it.

### NaN moves with the form, the same way #548 describes

| curve | pre-bounded | ranged |
|---|---|---|
| interpolation, NaN upper | `nan`, Swift reports failure | **0** |
| interpolation, NaN lower | `nan`, Swift reports failure | **353.508** |
| segment, circle, Bezier, NaN upper | `nan`, Swift reports failure | `nan`, Swift reports failure |

That is #548's finding, in 2D: the clamping branch compares the NaN bound against a domain bound,
the comparison is false, and the bound silently lands on an endpoint instead of poisoning the
integral. Routing `arcLength(from:to:)` onto the ranged form therefore gives the 2D path the same
hole the 3D path has. Noted on #548 rather than patched here, so both dimensions get one fix.

## What was done with it

`OCCTCurve2DLength` deleted, with tombstone comments in `OCCTBridge.h` and `OCCTBridge_Geom2d.mm`
naming the surviving function, matching the idiom #500 established and #506 used. That removes the
last pre-bounded arc-length call site in the bridge. `Curve2D.arcLength(from:to:)` now delegates to
`length(from:to:)`, the shape `Curve3D.arcLength(from:to:)` has had since #408.

`Tests/OCCTGeom2dTests/Issue549Curve2DArcLengthRangeTests.swift` pins the divergent ranges, checks
the clamping against a chord-sum reference rather than against the implementation's own answer for
the whole domain, and compares the 2D answers against the 3D ones on the same points in the z = 0
plane. Verified by injection: restoring the pre-bounded call reproduces this probe's figures
through the public Swift API (`-1.0` against 169.457, 8082.404 against 353.508, 1.259 against 0)
and fails 7 of the 11 tests across the two suites.

Not an upstream defect: both `Geom2dAdaptor_Curve` constructors behave as documented, and choosing
between them is the caller's job. Nothing to file or patch in the kernel.
