# OCCTSwift#572: what the sweep / offset / unify / convert consumers of `GeomConvert_ApproxSurface` did when #522 made truncation errors real

Follow-up spike to [#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522), whose patch
`Scripts/patches/0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch` fixed
`AdvApp2Var_ApproxF2var::mma2ce1_` filling both Jacobi-maxima buffers from the V slot, so every
interior truncation error the approximator computed was exactly zero.

The question was whether the five kernel classes that construct a `GeomConvert_ApproxSurface`
without re-checking `MaxError()` moved, and the issue's own expectation was that they could not have
taken a *wrong* shape, only a *differently parameterised* one, because "they are driven at C1/C2,
where the `NDMINU` floor is already high".

**They took a wrong shape.** At C1, on the paths OCCTSwift reaches. The fit that
`PipeShellBuilder.setForceApproxC1(true)` accepts sat 0.876 from the surface it was approximating
against a requested tolerance of 1e-4, and `IsDone()` was true. With `0019` the same request lands
0.176 away, 5x closer, and reports `IsDone() == false`, which is the truthful answer.

Continuity turned out not to be the axis that predicts this. See "Why C1 was not safe" below.

## Files

| file | what it is |
|---|---|
| `occt_572_consumers.mm` | the harness: one case per wrapper path, plus a per-site direction measurement |
| `sweep-stock.txt` | its output with `0019` reverted |
| `sweep-fixed.txt` | its output with `0019` applied |
| `probe-census.txt` | the same harness run against a backtrace probe in `GeomConvert_ApproxSurface::Approximate`, which is how the reachability column below was measured rather than read off the source |

## Building it

Plain run, against whatever `Libraries/OCCT.xcframework` currently holds:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/572-approx-consumer-sweep/occt_572_consumers.mm -o /tmp/occt_572
/tmp/occt_572
```

For the A/B, build **both** sides as `-O0` single-TU override links, one from the current source and
one with `0019` reverted:

```bash
SRC=Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var/AdvApp2Var_ApproxF2var.cxx
cp "$SRC" /tmp/f2var_fixed.cxx
sed 's/mma2jmx_(ndjacu, iordru, &wrkar_off\[ipt4\])/mma2jmx_(ndjacu, iordru, \&wrkar_off[ipt5])/' \
  "$SRC" > /tmp/f2var_stock.cxx

for v in fixed stock; do
  clang++ -c -std=gnu++17 -O0 -g -w -DNDEBUG -DNo_Exception -DOCC_CONVERT_SIGNALS \
    -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
    -I"Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var" \
    /tmp/f2var_$v.cxx -o /tmp/f2var_$v.o
  clang++ -std=c++17 -ObjC++ -w \
    -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
    -L"Libraries/OCCT.xcframework/macos-arm64" \
    Scripts/repro/572-approx-consumer-sweep/occt_572_consumers.mm /tmp/f2var_$v.o \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o /tmp/occt_572_$v
  /tmp/occt_572_$v > /tmp/sweep-$v.txt
done
diff /tmp/sweep-stock.txt /tmp/sweep-fixed.txt
```

**Both sides have to be `-O0` overrides.** Comparing an `-O0` override against the shipped `-O2`
archive moves the sampled-geometry hash on rows that `0019` does not touch at all (the four
`geomLib/*` rows, and the swept volume in its eighth significant digit), which buries the signal.
`-DNo_Exception` matters for the same reason it did in #555: the shipped kernel is built with it.

The reachability probe is a copy of `GeomConvert_ApproxSurface.cxx` with a `backtrace()` dump at the
top of `Approximate`, compiled and linked the same way; run its output through `c++filt`.

## Which sites are reachable, measured

The probe counted 22 constructions across the harness. Grouped by caller:

| site | continuity it asks for | reachable from | fires? |
|---|---|---|---|
| `GeomFill_Sweep.cxx:296` | C1/C1, tol 1e-4, nmax 16 | `PipeShellBuilder.setForceApproxC1(true)` **only** | yes |
| `BRepOffset_Offset.cxx:1626` | caller's `Conti`, caller's `TolApp` | nothing | **no, dead code** |
| `ShapeUpgrade_UnifySameDomain.cxx:3629` | C1/C1, tol 1e-4, nmax 16 | `UnifySameDomainBuilder.build()` | yes, on one surface family |
| `GeomLib.cxx:1517` | C1/C1, tol `Precision::Confusion()`, nmax 16 | no OCCTSwift entry point in this set | not indirectly |
| `GeomConvert_1.cxx:786` | C1 or C2, tol 1e-4, nmax `4(nu+1)(nv+1)` | `Surface.toBSpline()` on a trimmed surface | yes |
| `GeomConvert_1.cxx:960` | **C0, C1 or C2 per the surface**, tol 1e-4 | `Surface.toBSpline()` on an untrimmed one | yes |

Three of those rows differ from the issue's table:

**`Shape.sweep` cannot reach row 1.** It is `BRepOffsetAPI_MakePipe(path, profile)`, the two-argument
constructor, and `ForceApproxC1` is only on the five-argument one. Row 1 also needs the swept surface
to fail `IsCNv(1)`, which needs the spine's tangent discontinuity *inside* one edge: `BRepFill_Sweep`
splits the sweep at spine vertices, so a polyline spine never gets there. A three-point polygon spine
and a circular-arc spine both return the identical shape with the flag on and off.

**Row 2 is dead.** The construction sits inside `if (Polynomial)` in
`BRepOffset_Offset::Init(const TopoDS_Vertex&, ...)`, `Polynomial` defaults to `false` on all three
`Init` overloads, and the only in-tree caller is `BRepOffset_MakeOffset.cxx:2047`,
`BRepOffset_Offset OF(V, LOE, CurOffset)`, which takes that default. Measured as well as read: an
arc-join `Shape.offset` on a box builds a spherical face on every convex vertex, which is precisely
this function, and the probe records no construction for it, nor for the tangent and intersection
joins, nor for either `thickSolid` case.

**Row 4 has no OCCTSwift entry point.** `GeomLib::ExtendSurfByLength` is reached from
`BRepFill_Sweep.cxx:2334`, `BRepOffset_Offset.cxx:661` and three siblings, `BRepOffset_Tool.cxx`,
`BRepLib.cxx:3245` and `ChFi3d` (so fillets, not just "GeomLib conversions", which is worth
recording because it is a wider reachable-from than the issue listed). But none of the pipe shell,
offset, thick solid or fillet cases in this harness reaches its approximator branch: the surfaces
those paths hand it are already B-splines, which is the branch above the construction. The four
`geomLib/*` rows in the transcripts call `GeomLib::ExtendSurfByLength` directly, which no bridge
function does. They are in the harness because the site is live in the kernel and does move; they are
not evidence of an OCCTSwift-visible change.

**Row 3 needs a surface nothing in `BRepPrimAPI` produces.** `Uperiod` comes from
`aBaseSurface->IsUPeriodic()` at `:3244`, so the branch holding the construction only runs when the
merged face closes a direction the base surface is *not* periodic in, and only when that base surface
is not already a B-spline. Every cylinder, sphere, torus and surface of revolution is periodic and
takes the other branch: the harness unifies halved cylinders, a sphere, a torus, two fused boxes and
a box fused to a cylinder, and none of them fires it. An extrusion of a closed but clamped (not
periodic) B-spline curve does fire it, and that is what `unify/closedExtrusion` builds.

## What moved

`diff sweep-stock.txt sweep-fixed.txt`, six rows out of 79:

| case | stock | fixed |
|---|---|---|
| `pipeShell/c0Spine/force=1` | vol 42.677, area 128.36, deg 13x4, poles 14x8 | vol 40.707, area 139.65, deg 14x14, poles 41x67 |
| `pipeShell/multiSection/force=1` | vol 163.60, area 212.46, deg 8x4, poles 9x8 | vol 190.54, area 407.19, deg 14x14, poles 41x67 |
| `geomLib/revolutionC0/inU=0` | deg 12x3, poles 13x8 | deg 14x14, poles 41x80 |
| `geomLib/revolutionC0/inU=1` | deg 12x3, poles 24x6 | deg 14x14, poles 54x67 |
| `toBSpline/trimOffsetC1InU` | deg 12x9, poles 35x18 | deg 14x14, poles 80x54 |
| `unify/closedExtrusion/concat=1` | unchanged | unchanged |

Everything else is identical, including every offset, thick solid, fillet, boolean-fused unify, and
every analytic conversion.

## Which direction it moved

The `dir/` section reruns each reached site's own request on its own input and reports OCCT's
`MaxError()` next to two measured deviations: `paramDev` compares the two surfaces at the same
normalised parameters (the quantity the approximator's error model is about), and `projDev` is the
nearest point on the fit to each sampled source point, which is independent of parameterisation and
so measures the shape and nothing else.

| request | stock `MaxError` | stock `projDev` | fixed `MaxError` | fixed `projDev` |
|---|---|---|---|---|
| swept surface, C1, tol 1e-4 | 1.28e-5, `isDone=1` | **0.876** | 2.547, `isDone=0` | **0.176** |
| revolution over a C0 curve, C1, tol 1e-7 | 9.04e-9, `isDone=1` | **0.626** | 1.887, `isDone=0` | **0.391** |
| trimmed offset surface, C1, tol 1e-4 | 2.09e-5, `isDone=1` | **0.104** | 0.341, `isDone=0` | **0.038** |
| revolution over a C2 curve, C1, tol 1e-7 | 6.78e-9, `isDone=1` | 4.40e-9 | 6.78e-9, `isDone=1` | 4.40e-9 |
| untrimmed offset surface, C0/C2, tol 1e-4 | 2.70e-5, `isDone=1` | 8.07e-6 | 4.14e-5, `isDone=1` | 8.07e-6 |
| closed extrusion, C1, tol 1e-4 | 1.07e-14, `isDone=1` | 1.78e-15 | 1.93e-14, `isDone=1` | 1.78e-15 |

Every row that moved moved toward the tolerance, by 1.6x to 5x, and every row that did not move was
already meeting it. On the three that moved the pre-`0019` kernel reported `IsDone()` on a fit that
missed its own tolerance by four to eight orders of magnitude; after the fix it says so.

**None of the three reaches its tolerance even after the fix.** They cap out at degree 14 and 16 or
24 segments. What changed is that the degree search now climbs to that cap instead of stopping at the
`NDMINU` floor with every candidate scoring zero, and that the caller is now told.

## Why C1 was not safe

The issue expected these sites to be untouched because C1 puts `NDMINU` at 8, above the collapse.
Two things make that the wrong prediction.

**The floor is not the only thing the zeroed error controls.** It also disables the subdivision
decision. With every interior truncation error evaluating to 0, `mma2ce2_`'s tolerance test
(`errmax[nd] > epsapr[nd]`) can never fire on a patch interior, so the fit neither raises its degree
nor cuts the patch, whatever continuity was requested. Every site above allows 16 or 24 segments, and
that is where the movement came from: degree 13x4 to 14x14, 14x8 poles to 41x67.

**C0 is reachable at `GeomConvert_1.cxx:960`, and it did not collapse there.** That site does not
hardcode a continuity, it derives one from the surface, starting at `GeomAbs_C0` and raising it only
if `IsCNu`/`IsCNv` say so. A `Geom_OffsetSurface` reports `IsCNu(N)` as its basis surface's
`IsCNu(N + 1)`, so offsetting a B-spline that is C1 but not C2 in U produces a surface whose U
request is C0. Measured (`dir/offsetC1InU`): degree 13x14, 66x15 poles, bit-identical either side of
`0019`, and only the reported error rises. The collapse needs a low `NDMINU`, and that floor is low
only where the boundary iso-curves carry no information, which is what a sphere's degenerate V poles
do and an ordinary offset patch's boundaries do not.

So the axis that predicted which consumers move was not continuity. It was whether the site allows
subdivision and whether the input needs any.

## The defect this measurement found next to it

`GeomFill_Sweep` accepts the conversion on `HasResult()` and never reads `MaxError()`:

```cpp
GeomConvert_ApproxSurface ConvertApprox(mySurface, theTol, theUCont, theVCont, degU, degV, nmax, thePrec);
if (ConvertApprox.HasResult())
{
  mySurface = ConvertApprox.Surface();
```

`HasResult()` is documented as true even for a result "not NECESSARILY within the required
tolerance", which is exactly what this is: a 1e-4 request satisfied to 0.176. `0019` makes that
visible (`IsDone()` is now false and `MaxError()` is now 2.55) but nothing reads either, so a caller
still gets a surface missing its stated tolerance by four orders of magnitude. Same shape as the
healing sites in #570 and the filling refusal in #482, and it is a separate defect from #522. Filed
as its own issue.

`ShapeUpgrade_UnifySameDomain.cxx:3629` is worse in kind: it does not even check `HasResult()`, it
calls `Approximator.Surface()` straight away and can bind a null handle. Not reachable in this
harness's fixtures because the fit there is exact, and filed with the above.

## Method notes

- **`BRepTools::Write` is not usable as a fingerprint here.** The offset and boolean paths order
  their output differently between runs of the same binary, and the length of the written text
  changes with it. The harness fingerprints geometry instead: per face, the surface type, its
  layout, and a 5x5 sampled point grid, sorted across faces so face order cannot matter. It also
  sets `BOPAlgo_Options::SetParallelMode(false)`. With both, three consecutive runs of the same
  binary are byte-identical.
- The `paramDev` column exists to catch the case the issue was expecting (a re-parameterisation),
  and `projDev` to separate that from a shape change. On the swept surface they disagree by 5x, so
  reporting only one of them would have given the wrong answer about what happened.

## Swift-level regression tests

`Tests/OCCTSurfaceTests/Issue572ApproxConsumerTests.swift` and
`Tests/OCCTModelingTests/Issue572SweepApproxTests.swift` pin the two paths that moved, and both were
checked against the released pre-`0019` kernel with `OCCTSWIFT_REMOTE=1`, where exactly the two
pinning tests fail with the numbers above (0.876114 and 0.103785) and the three deliberate
non-regression controls pass.

## #597: the wider family, beyond `GeomConvert_ApproxSurface`

Cluster E's own one-line definition (`docs/v2.0.0-plan.md`) is "accept an approximation without
reading its error", not "constructs `GeomConvert_ApproxSurface`" specifically. The sites above are
the ones that follow #522's blast radius through that one class. #597 swept the rest of the
cluster's territory: every OCCT class in `OCCTBridge_Modeling.mm`/`OCCTBridge_Healing.mm` capable of
reporting a fitting/approximation error, regardless of which approximator it wraps. This is that
enumeration, extending this artifact per the census-once rule rather than duplicating it in #597's
own directory:

| site | file | error API | reads it? | verdict |
|---|---|---|---|---|
| `occtPlateApproxSurface` (backs `OCCTShapePlatePoints`, `OCCTShapePlateCurves`, +4 more in `OCCTBridge_ProjLib_NLPlate.mm`) | Healing.mm (shared helper in ProjLib_NLPlate.mm) | `GeomPlate_MakeApprox::ApproxError()`/`CriterionError()` | no | investigated, not a fixable defect (measures fidelity to an intermediate object the caller never sees, not the caller's own input) |
| `OCCTShapeFillBuildResult` (backs `OCCTShapeFill`, `OCCTShapeFillWithSupport`, `OCCTShapeFillConstraints`) | Healing.mm | `BRepOffsetAPI_MakeFilling::G0Error()`/`G1Error()`/`G2Error()` | no | investigated, not a fixable defect (the right metric, but the bridge's `Tol3d` default is routinely and legitimately exceeded by correct fills) |
| `occtUnifySameDomain` / `OCCTUnifySameDomain` builder | Healing.mm / Modeling.mm | none (`ShapeUpgrade_UnifySameDomain` exposes no error getter at all) | n/a | confirms this artifact's own finding above; nothing to read |
| `PipeShellBuilder` (`OCCTPipeShell*`) | Modeling.mm | `BRepFill_PipeShell::ErrorOnSurface()` | **yes** | not a defect: deliberate manual-builder design, error is an opt-in accessor |
| `FillingSurface` (`OCCTFilling*`) | Modeling.mm | `BRepOffsetAPI_MakeFilling::G0Error()`/`G1Error()`/`G2Error()` | **yes** | same as above |
| `ShapeCustom_BSplineRestriction` (`OCCTShapeBSplineRestrictionAdvanced`) | Healing.mm | `SurfaceError()`/`Curve3dError()`/`Curve2dError()`/`MaxErrors()` | no | self-polices in the kernel: declines a face's conversion rather than ever accepting one out of tolerance |
| `ShapeCustom_ConvertToBSpline`, `ShapeCustom_ConvertToRevolution` | Healing.mm | none | n/a | not an approximation with a reported error |
| `BRepFill_NSections`, `BRepOffsetAPI_ThruSections`, `BRepOffsetAPI_MakeOffset(Shape)`, `BRepFill_Evolved` | both | none | n/a | no error-reporting API in OCCT for these |
| `GeomAPI_PointsToBSpline(Surface)`, `GeomAPI_Interpolate` | Modeling.mm | none | n/a | `#include`d only; no construction site in either file |

Full measurement detail (the actual probes, the reverted-fix confirmation against
`Issue571PlateApproxTests`/`FillingSupportFaceTests`, and why each verdict above holds) lives at
[`Scripts/repro/597-bridge-modeling-healing-approx-error/`](../597-bridge-modeling-healing-approx-error/README.md),
which this table indexes rather than duplicates.
