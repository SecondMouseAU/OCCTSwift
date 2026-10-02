# #2976: which axis `IsURational()` / `IsVRational()` report on

`Surface.BSpline.isURational` and `Surface.Bezier.isURational` document nothing, and OCCT's
definition is the opposite of the one a reader supplies. This directory is the measurement the
documentation is written from, rather than a reading of the headers, because for the Bezier pair
the header contradicts itself.

## What the headers say

`Geom_BSplineSurface.hxx`, the pinned copy:

> `IsURational()`: Returns False if **for each row** of weights all the weights are identical.
>
> |1.0, 1.0, 1.0|
> if Weights = |0.5, 0.5, 0.5| returns False
> |2.0, 2.0, 2.0|

A row is one U index across every V: the same header's bounds paragraph puts rows at
`1...NbUPoles` and columns at `1...NbVPoles`. So "each row is constant" means the weights do not
change as **V** advances, and `IsURational()` reports on V.

`Geom_BezierSurface.hxx` says something different and prints the same matrix:

> `IsURational()`: Returns False if the weights are identical **in the U direction**.

"Identical in the U direction" would make the constant *columns* the False case, but the matrix
beside it has constant *rows*. The prose and the example say opposite things, so the Bezier pair
had to be measured rather than copied from the BSpline wording.

## What was measured

`run.sh` compiles and runs `probe.mm` against the pinned kernel. Measured 2026-10-02 against the
`v4.0.0-kernel.3` xcframework:

```
== Geom_BezierSurface, explicit weight matrices ==
   (row index = U index, column index = V index, per the header's bounds)
  rows constant, varies along U                  isURational=0 isVRational=1
  columns constant, varies along V               isURational=1 isVRational=0
  all weights equal (not rational at all)        isURational=0 isVRational=0
  varies along both                              isURational=1 isVRational=1

== Geom_BSplineSurface, the cylinder #2976 names ==
  radius 5, height 10, converted                 isURational=0 isVRational=1
  ...after ExchangeUV()                          isURational=1 isVRational=0

== Geom_BSplineSurface, the same explicit matrices ==
  rows constant, varies along U                  isURational=0 isVRational=1
  columns constant, varies along V               isURational=1 isVRational=0
```

**The Bezier pair behaves exactly as the BSpline pair, so the Bezier header's example is right and
its prose is wrong.** Both classes: `IsURational()` is true exactly when the weights change as V
advances, and `IsVRational()` is true exactly when they change as U advances. Each flag names the
axis opposite the one a reader supplies.

The source agrees and says why.
`Libraries/occt-src/src/ModelingData/TKG3d/Geom/Geom_BezierSurface.cxx`'s static `Rational()`
sets `Urational` from `Weights(I, J) != Weights(I, J + 1)`, which walks **J**, the column index,
which is V. `Geom_BSplineSurface.cxx` computes it the same way. The probe is still the artifact of
record, because reading an implementation tells you what the value is and not what a caller may
rely on, and because the pinned binary is what ships.

## The cylinder, and why it reads as a defect

A cylinder converted with `GeomConvert::SurfaceToBSplineSurface` carries the circle's weights
around U and constant weights along the axis V, so it reports `isURational == false` and
`isVRational == true`. The same holds for every cone, sphere and surface of revolution in BSpline
form. This was already pinned in `Tests/OCCTSurfaceTests/BSplineSurfaceManipulationTests.swift`
with a paragraph in the test explaining why the pair is not inverted; #2976 moved that explanation
to the `///` comments where a caller reads it, and
`Tests/OCCTAnalysisTests/BezierSurfaceTests.swift` gained
`rationalFlagsReportTheOppositeAxis` so the Bezier half has a test under its sentence too.

## Running it

```bash
# from the repo root, with Libraries/OCCT.xcframework present
Scripts/repro/2976-surface-rational-axes/run.sh

# a linked worktree has no xcframework of its own
OCCT_XCFRAMEWORK=/path/to/main/checkout/Libraries/OCCT.xcframework \
  Scripts/repro/2976-surface-rational-axes/run.sh
```
