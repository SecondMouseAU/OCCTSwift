# #1510: `OCCTSurfaceConversionGap` reports the wrong OCCT quantity

## The defect, as filed

`OCCTSurfaceConversionGap` (`OCCTBridge_Surface_Conversion.mm`) built a brand-new
`ShapeCustom_Surface`, ran an unrelated `ConvertToAnalytical(1e-3, Standard_False)` recognition
pass at a hardcoded tolerance the caller never supplied, discarded the recognized surface, and
returned whatever `Gap()` happened to hold from that throwaway call. `ShapeCustom_Surface::Gap()`'s
own header doc says it reports the deviation "computed by **last call to ConvertToAnalytical**",
never `ConvertToPeriodic`; `myGap` is written only inside `ConvertToAnalytical`
(`ShapeCustom_Surface.cxx:401,452,454`, including on its rejection path), and `ConvertToPeriodic`
never references it at all. The issue's own compiled reproducer confirmed this: `Gap()` before any
conversion = 0.0, `Gap()` immediately after a real, successful `ConvertToPeriodic()` = still 0.0
(unchanged), and what the bridge function actually returned via the throwaway
`ConvertToAnalytical(1e-3)` call was `0.003363078` despite that recognition attempt failing
outright (`recognized == 0`).

## What this investigation adds: does `ConvertToPeriodic` have ANY gap to report?

The issue asked two questions: (a) could `OCCTSurfaceConvertToPeriodic` be changed to persist a
*real* measured quantity (e.g. sampled deviation between the original and converted surface), or
(b) is the correct fix to deprecate `OCCTSurfaceConversionGap` outright because the operation has
no gap concept at all?

Reading `ShapeCustom_Surface::ConvertToPeriodic`'s implementation
(`Libraries/occt-src/src/ModelingAlgorithms/TKShHealing/ShapeCustom/ShapeCustom_Surface.cxx:475+`)
confirms it is exactly what the issue says: a pure knot-vector rearrangement.

- It only ever calls `Geom_BSplineSurface::SetUPeriodic()`/`SetVPeriodic()` on the *original* poles
  (`BSpl->SetUPeriodic()`), which OCCT's own header documents as requiring the surface to already
  be "closed in the given parametric direction" (`Standard_ConstructionError` otherwise): the
  operation is only ever attempted on a surface OCCT itself considers already geometrically closed.
- The one branch that touches poles at all (`UMultiplicity(1) == UDegree()+1`, a fully-clamped end)
  reuses `oldPoles`/`oldWeights` unchanged and only extends/renumbers the *knot* vector
  (`newUKnots(1) = oldUKnots(1) - a`, etc.), the classic "declamping" trick that keeps a B-spline
  identical within its original parameter range while changing its representation outside it.

So there is no approximation step anywhere in `ConvertToPeriodic`, unlike `ConvertToAnalytical`
(which genuinely fits a *different* surface and needs a fit-quality metric). A "gap" computed by
sampling the original vs. the periodic-converted surface at matching parameters should, by this
reading, be at or near machine epsilon in every case: there is nothing for it to measure.

### Confirming that empirically

`occt_1510_periodic_gap.mm` builds a genuinely U-closed, non-periodic clamped BSpline surface (a
trimmed full-revolution cylinder, forced non-periodic via `SetUNotPeriodic()`), runs the real
`ShapeCustom_Surface::ConvertToPeriodic`, and samples both surfaces at a 25x25 grid over the
original's own parametric domain, plus a finer grid concentrated at the U seam:

```
IsUPeriodic before: 0
NbUPoles: 7 NbVPoles: 2
Converted OK. Gap() immediately after = 0.000000000000
IsUPeriodic after: 1
Max sampled deviation (25x25 grid over original bounds): 0.000000000000e+00
Max sampled deviation near seam: 0.000000000000e+00
```

`occt_1510_periodic_gap_perturbed.mm` repeats this with the closing pole row deliberately
perturbed by 3e-8 (well inside `Precision::Confusion()`, so `IsUClosed`/`SetUPeriodic` still accept
it as "closed enough"), to check whether a genuinely-not-quite-closed input surface produces a
measurable gap once forced periodic. It does not:

```
first pole vs last pole distance: 3.000e-08
Converted OK. sc.Gap() after (should be 0, no ConvertToAnalytical call) = 0.000e+00
Max sampled deviation over full grid: 0.000000e+00
Max deviation AT u=u2 exactly: 0.000000e+00 (perturbation was 3.000e-08)
```

Both probes' output is reproduced verbatim above; re-run with `run.sh` (needs
`Libraries/OCCT.xcframework`, see the repo root `CLAUDE.md`'s "Compile a Ground Truth C++ Test").

## Decision: (b), deprecate rather than fabricate

A "real" measured gap for `ConvertToPeriodic` would, on this evidence, always read as an
uninteresting constant (0.0, or something indistinguishable from floating-point noise) across every
scenario this investigation could construct, including the one case (a not-quite-exactly-closed
input) most likely to produce a genuine, non-trivial answer. Persisting state through
`OCCTSurfaceConvertToPeriodic`'s signature to report that constant would not be dishonest the way
the current code is, but it would not be *useful* either, and it would still imply, by existing at
all next to `OCCTSurfaceConvertToAnalytical`'s genuinely meaningful `gap` field, that
`ConvertToPeriodic` is a lossy, approximating operation the way `ConvertToAnalytical` is. It isn't.
This is the same shape as CLAUDE.md's #597/#726 precedent (`GeomPlate_MakeApprox::ApproxError()`,
`BRepOffsetAPI_MakeFilling::G0Error()`): investigated on measurement, twice, and the correct answer
is that the underlying OCCT operation has nothing here worth reporting.

The fix: `OCCTSurfaceConversionGap` is deprecated (`Surface.conversionGap` gets
`@available(*, deprecated, ...)`, kept only for source compatibility per this project's own
precedent for a non-breaking API retirement, e.g. `Shape.TopAbs_ShapeEnum` in `docs/SEMVER.md`'s
v3.0.0 entry) and its bridge implementation is simplified to a documented no-op returning `-1.0`
unconditionally, rather than running the misleading `ConvertToAnalytical(1e-3)` call. `-1.0`
reuses the function's own existing null-handle sentinel rather than inventing a second one, and is
never confusable with a real measurement (every genuine `Gap()`/deviation value in this codebase is
`>= 0`). `convertToPeriodic()`'s own doc comment is corrected to say plainly that it has no
deviation to report, so a reader lands on the right answer without following the deprecated
property's own doc chain.
