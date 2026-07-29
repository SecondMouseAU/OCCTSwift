---
title: Changelog
nav_order: 13
---

# Changelog

All notable changes to OCCTSwift.

## Current: v1.17.0

**macOS / iOS (device + simulator) | OCCT 8.0.0p1 (+ #263, #280, #298, #310, #317, #318, #319, #323, #341, #344, #348, #349, #353, #374 kernel patches)**

---

## Release History

### v1.17.0 (July 2026): pass 1a of the #377 duplication audit, and two source-breaking changes in a minor release

**Read this before upgrading. Two changes in this release break source compatibility, which
[`SEMVER.md`](SEMVER.md) reserves for a major bump.** The exception is deliberate and recorded
there; the major version stays reserved for OCCT 9.0. Nothing else in this release requires a
source change, and there is no binary or behavioural change to any API not named below.

#### Breaking: `Surface.drawMesh` and `Surface.evaluateGrid` return `SurfaceGrid` (#404)

Both previously returned `[[SIMD3<Double>]]`, and they nested in **opposite** orders:
`drawMesh` was `[uIndex][vIndex]`, `evaluateGrid` was `[vIndex][uIndex]`. Nothing at the type
level caught a caller mixing them up. They now share one `SurfaceGrid` type indexed by
`at(u:v:)`, so the ambiguity is gone rather than documented.

```swift
// Before
let mesh = surface.drawMesh(uCount: 30, vCount: 30)
for row in mesh { for p in row { emit(p) } }
let rows = mesh.count, cols = mesh[0].count

// After
let mesh = surface.drawMesh(uCount: 30, vCount: 30)
for u in 0..<mesh.uCount {
    for v in 0..<mesh.vCount {
        if let p = mesh.at(u: u, v: v) { emit(p) }
    }
}
let rows = mesh.uCount, cols = mesh.vCount
```

`SurfaceGrid` exposes `at(u:v:)`, `uCount`, `vCount` and `isEmpty`. It is not a `Collection` and
is not subscriptable, so the break is a compile error at every call site rather than anything
silent. **If you are migrating `evaluateGrid` specifically, check your index order**: its old
shape was `[v][u]`, so a mechanical rewrite that assumes `[u][v]` transposes the data.

No shim is possible here. Swift does not overload on return type alone, so a deprecated overload
with the old return type would be ambiguous at every call site that binds the result to a variable.

#### Breaking: `Curve3D.interpolate(points:startTangent:endTangent:)` removed (#400)

The no-`tolerance` overload shadowed its tolerance-aware sibling: Swift always prefers the exact
arity match, so the ordinary three-argument call could never reach the `tolerance:` parameter,
which was pinned at `1e-6` regardless of what a caller asked for.

```swift
// Before and after — identical source, and it now compiles against the tolerance-aware overload
let c = Curve3D.interpolate(points: pts, startTangent: t0, endTangent: t1)

// Now reachable for the first time
let c = Curve3D.interpolate(points: pts, startTangent: t0, endTangent: t1, tolerance: 1e-4)
```

In practice most call sites need no edit: the three-argument spelling still compiles and still
defaults to `1e-6`. It breaks only where the removed overload was referenced as a value
(`let f = Curve3D.interpolate(points:startTangent:endTangent:)`) or passed as a function argument.

#### Everything else

Pass 1a of the [#377](https://github.com/SecondMouseAU/OCCTSwift/issues/377) duplication audit:
27 issues, each a pair of API spellings that turned out not to mean the same thing. Eleven of
them change what an existing call returns without any compiler diagnostic, so the per-entry
sections below carry a **behaviour-change table** listing each one as was/now. If you upgrade
without reading anything else, read that table.

The individual entries follow: #477 (arc-length integrator), #433/#434 (`FillingSurface`
continuity), #398 (continuity enums), #399-#422 (the audit batch), #443 (first-of-N explorer
sites).

Consumers on the opt-in prebuilt bridge (`OCCTSWIFT_BRIDGE_PREBUILT=1`) **must** take this
release's `OCCTBridge.xcframework.zip`: the bridge's C ABI changed (`OCCTSurfaceKnotSplitting`
gained four parameters, five functions were removed), so a v1.16.1 bridge binary no longer
matches this Swift layer. `Package.swift`'s URL and checksum are bumped accordingly.
`OCCT.xcframework` is unchanged and stays pinned at its v1.15.18 asset: this release carries no
kernel patch changes.

### v1.17.0 (July 2026) — fix: Curve3D arc length was integrated as one quadrature across the whole domain (#477)

`Curve3D.length` and `Curve3D.length(from:to:)` measured arc length with
`CPnts_AbscissaPoint::Length`, a single Gauss quadrature of order ≤ 24 spanning the entire
parameter domain. That is exact for a line or a circle and wrong for anything with many spans, and
nothing signalled the difference: the call returned a plausible number. Every other arc-length call
site in the bridge (`Curve2D`, `Edge`, `WireCurve`, the property queries) already used
`GCPnts_AbscissaPoint::Length`, which splits the curve at its `GeomAbs_CN` interval boundaries and
integrates each span separately. These two were the only `CPnts_AbscissaPoint` call sites left in
the bridge, and the reference docs had already described them as `GCPnts` for some time.

Measured against a densely sampled polyline reference over the same domain, on the pinned kernel:

| curve | spans | GCPnts (now) | CPnts (before) |
|---|---|---|---|
| 40-pt interpolated BSpline, varying speed | 39 | `2.9e-7` rel. | **`5.1e-2` rel. (5% of 356 units)** |
| 60-pt interpolated helix | 59 | `4.3e-15` rel. | `3.9e-6` rel. |
| 5-pt interpolated BSpline | 4 | `6.9e-12` rel. | `2.5e-3` rel. |
| line, circle, arc | 1 | exact | exact |

(On the helix and 5-point rows the `GCPnts` figure sits at or below the reference's own residual
error, so it bounds the remaining error rather than measuring it. The first row's `2.9e-7` is
`GCPnts`'s genuine per-span quadrature residual on a sharply wiggling curve.)

The error is worst where `|C'(u)|` varies sharply along the curve, which is the ordinary case for
an interpolated toolpath or an imported spline, so a CAM step-over or a sweep spacing derived from
a curve's length was percent-level wrong. The ranged overload had the identical gap, and
`totalArcLength` / `arcLength(from:to:)` / `arcLengthBetween(_:_:)` inherit the fix as soon as they
route through `length` (#408).

**One behavioural change beyond accuracy**, on out-of-domain parameters: `GCPnts` clamps to the
curve's domain where `CPnts` extrapolated the polynomial past its knots. On the 356-unit test
curve, overshooting both ends by a full domain width used to measure 441,972; it now measures the
curve's own length. A range wholly outside the domain used to measure 865,392; it now measures `0`.
Nothing else in the failure contract moves:
probed against the pinned kernel, both integrators agree on reversed ranges, equal parameters,
zero-length curves, periodic curves, and unbounded lines, and neither throws where the other does
not.

The three bridge functions that already used the composite integrator
(`OCCTCurve3DArcLength` / `OCCTCurve3DLength` / `OCCTCurve3DArcLengthBetween`) stay exported for
direct C consumers, but they are no longer reached from Swift: #408 routed `totalArcLength`,
`arcLength(from:to:)` and `arcLengthBetween(_:_:)` through `length`/`length(from:to:)`, so every
Swift spelling now lands on `OCCTCurve3DGetLength`/`OCCTCurve3DGetLengthBetween`. Nothing in
`Sources/OCCTSwift` references the older three.

New suite `Issue477ArcLengthAccuracyTests` (`OCCTCurveTests`) pins all five Swift spellings against
an independently computed reference (a Richardson-extrapolated polyline, not the implementation's
own answer), so it fails on the old integrator rather than ratifying it. 5 of its 8 tests fail
against the previous code.

### v1.17.0 (July 2026) — fix: `FillingSurface`'s continuity mapping was wrong for both non-default orders, and it converged onto `Shape.fill`'s implementation (#433, #434)


`FillingSurface.add(edge:continuity:)`/`add(freeEdge:continuity:)` hand-mapped the plate
constraint order onto `GeomAbs_Shape` locally instead of using `occtFillingContinuityToGeomAbs`,
the helper #430 introduced for `Shape.fill`: order 1 requested `GeomAbs_C1` (curvature) instead
of `GeomAbs_G1` (tangency), and order 2 requested `GeomAbs_C2` (ordinal 4), which every
constraint class rejects — failing the whole `build()` rather than just that one constraint
(#433). `add` returned `true` regardless, since `BRepOffsetAPI_MakeFilling::Add` only appends and
never validates the order.

`FillingSurface` also held its own, separate `BRepFill_Filling` — the private implementation
class `BRepOffsetAPI_MakeFilling` (what `Shape.fill` already used) forwards to internally, and
never exposes. #434 converges the two onto one implementation: `FillingSurface` now holds the
same `BRepOffsetAPI_MakeFilling`, built through the same shared `occtFillingMakeBuilder`, and
every `add` call shares `occtFillingAddConstraint` outright rather than each having its own copy
of the same defensive logic — fixing #433 as a consequence of the convergence rather than as a
separate patch. `occtFillingAddConstraint` is no longer a template now that both callers hold the
same concrete filler type.

New: `FillingSurface.add(edge:support:continuity:)`, mirroring `FillConstraint`'s support-face
semantics — a face named here is used or the constraint fails, never silently substituted. Its
`continuity` defaults to `.g1`, not `.g0`, matching `FillConstraint`: at `.g0` there is nothing
to be tangent or curvature-continuous with, so `support` is never even read, and a `.g0` default
would make the "used or fails" guarantee false for the common zero-argument call. Covers the
boundary-edge case; `FillConstraint.isBoundary` also covers free edges with a named support
face, which this PR does not add an equivalent for.

```swift
// Tangent to the wall the rim came from
let filling = FillingSurface()
filling.add(edge: rim, support: wall, continuity: .g1)
```

Verified on the same truncated-sphere fixture #430's own tests use: `.g2` on a curved boundary,
which previously failed the whole `build()`, now succeeds and measurably bulges further than
`.g1` — matching `Shape.fill`'s own curvature-vs-tangency regression test on the other entry
point.

### v1.17.0 (July 2026) — refactor: nine continuity enums collapsed to two shared vocabularies (#398)


OCCTSwift had grown **nine** separate "continuity level" enums, each written against one bridge
call and each re-deriving its own raw-int meaning. Verified against the pinned kernel, they turn
out to express exactly **three** contracts, not one:

| contract | what OCCT receives | enums that expressed it |
|---|---|---|
| geometric constraint order, `0/1/2 = G0/G1/G2` | a plate constraint order; `GeomPlate_CurveConstraint` rejects outside `[-1, 2]` with "The continuity is not G0 G1 or G2" | `SurfaceContinuity`, `PlateConstraintOrder`, `FillingContinuity` |
| required parametric continuity, `0…3 = C0…C3` | a `GeomAbs_Shape` continuity class, or a literal derivative-order integer | `GeometricContinuity`, `ApproxContinuity`, `Shape.BSplineContinuity`, `Curve3D.ContinuityOrder` |
| a `GeomAbs_Shape` ordinal reported back | nothing; it is a *result* | `Surface.Continuity` |

Collapsed to `SurfaceContinuity` (`.g0` / `.g1` / `.g2`) and a new `ParametricContinuity`
(`.c0` … `.c3`). `Surface.Continuity` is retained as a result type, and `Shape.ContinuityLevel`
is retained as a strict superset (it adds `cn`, `g1`, `g2` cases that only
`dividedByContinuity(criterion:tolerance:)` accepts).

**No raw value moved, and no bridge code changed, so no existing call's behaviour changed.** Two
deliberate widenings, both in `Curve3D.continuityBreaks(minContinuity:)`: `.c3` becomes reachable
(below), and results past the 256th are no longer silently dropped. The latter is the only new
executable code in this PR, and the more consequential of the two for imported geometry, which is
where split counts get large. Every retired name and spelling remains as a deprecated alias, so
existing source still compiles:

```swift
@available(*, deprecated, renamed: "SurfaceContinuity")
public typealias FillingContinuity = SurfaceContinuity      // and PlateConstraintOrder
@available(*, deprecated, renamed: "ParametricContinuity")
public typealias GeometricContinuity = ParametricContinuity // and ApproxContinuity,
                                                            // Shape.BSplineContinuity,
                                                            // Curve3D.ContinuityOrder
```

`SurfaceContinuity.c0` / `.c1` / `.c2` also survive as deprecated aliases of `.g0` / `.g1` /
`.g2`. Two source-compatibility caveats, both fixed by adding a `default`:

- An *exhaustive* `switch` over any of these enums now needs one, because the old spellings are
  static properties rather than cases.
- `Curve3D.ContinuityOrder` also *widens* from three cases to four, so even a switch written with
  the correct `.c0` / `.c1` / `.c2` spellings stops being exhaustive.

Two live defects surfaced while verifying the mappings the issue had assumed correct. Both are
pre-existing, both are now pinned by tests, and neither is fixed here:

- **`Shape.plateSurface(through:orders:)` can never accept `.g2`.** A bare point carries no
  curvature to match, so `GeomPlate_PointConstraint` throws above order 1 (the header's "Order is
  not 0 or -1" doc is itself wrong; 1 is accepted). The throw fails the whole call, so a single
  `.g2` in an otherwise valid order list returns `nil`.
- **`Curve3D.ContinuityOrder`'s cap at `.c2` made every order it offered a no-op.**
  `GeomConvert_BSplineCurveKnotSplitting` splits where `degree - multiplicity < ContinuityRange`,
  and a cubic interpolation is already C2 at its interior knots. Measured: ranges 0, 1 and 2 all
  return just the two end knots; range 3 returns five parameters. Sharing `ParametricContinuity`
  makes `.c3` reachable, which fixes this as a side effect.

Also re-enabled `AdvancedPlateSurfaceTests`, disabled since v0.23.0 under the claim "Plate surface
operations cause segfault in OCCT". A C++ replica of that exact bridge path shows no segfault at
orders 0 or 1, and the suite is 8/8 clean over repeated runs. Same pattern as the #341
re-enablement: the claim was never characterised and does not hold up.

Docs: `naming-conventions.md` carried `GeometricContinuity.c0, .c1, .g1` as its worked example,
an enum/case combination that never existed.

### v1.17.0 (July 2026) - refactor + fix: the #377 duplication audit, 24 near-duplicate API pairs collapsed onto one implementation each (#399-#422)


One entry for the whole batch, since the 24 issues are one piece of work with one recurring
finding: **wherever two spellings of "the same" operation existed, they were not actually the
same.** Each pair was run against the pinned kernel before being unified rather than assumed
equivalent, and the divergences that turned up were real: a factory that accepted what its twin
rejected, a tolerance an order of magnitude apart, a parameter one spelling could not reach.
Collapsing a pair onto one implementation therefore changes behaviour on one side of it, listed
in full below.

Sibling entry: #398 (continuity enums), directly above. #433/#434 (`FillingSurface`) is the same
audit and has its own entry.

#### Behaviour changes

Each of these changes what an existing, unmodified call returns. None produces a compiler
diagnostic.

| Call | Was | Now | Issue |
|---|---|---|---|
| `Curve3D.circleFromCenterNormal(radius: 0)`, `ellipseFromCenterNormal(minorRadius: 0)`, `hyperbolaFromCenterNormal` with either radius 0, `parabolaFromCenterNormal(focal: 0)` | a live, degenerate curve (`gce_Make*` rejects only strictly-negative dimensions) | `nil`, matching the direct `circle`/`ellipse`/`parabola`/`hyperbola` factories | #399 |
| `Curve2D.circleFromCenterRadius(center:radius:)` at radius exactly 0 | a live, zero-radius curve | `nil`, matching `circle(center:radius:)` and the contract `Curve2D-Analysis.md` already documented | #411 |
| `Surface.curvatures(u:v:)` | its own `GeomLProp_SLProps` at resolution `1e-6` | the shared construction at `Precision::Confusion()` (`1e-7`), matching `gaussianCurvature(atU:v:)`/`meanCurvature(atU:v:)` | #405 |
| `Surface.normal(u:v:)` | accepted any `\|D1U × D1V\| > 1e-15` (absolute) | the same `GeomLProp_SLProps` degeneracy test `normal(atU:v:)` uses, a *relative* sine tolerance of `Precision::Confusion()`. A near-parallel-derivative point that used to yield a normal now yields `SIMD3(0, 0, 0)` | #401 |
| `Surface.approximated()` with no arguments | `tolerance: 0.01`, `maxDegree: 10` | `tolerance: 1e-3`, `maxDegree: 8`, matching `Curve3D.approximated`/`Curve2D.approximated` | #406 |
| `Curve3D.totalArcLength`, `arcLength(from:to:)`, `arcLengthBetween(_:_:)` on failure | `0.0`, indistinguishable from a genuine zero-length result | `-1.0` | #408 |
| `Curve2D.arcLength(from:to:)` on failure (e.g. reversed `u1 > u2`, which its range-checked adaptor rejects) | `0.0` | `-1.0` | #409 |
| `Point2D.distance(to: Curve2D)` with no projection (point past a bounded curve's ends, or a circle's centre) | `-1`, passed through as if it were a distance, so `distance < tolerance` read it as "touching" | `.infinity`, which such a test rejects correctly | #413 |
| `Curve2D.interpolatePeriodic(points:)` with exactly 2 points | `nil` (bridge floor `count < 3`) | a valid out-and-back periodic loop, matching `interpolate(through:closed:)`'s floor of `count < 2`, which has always allowed it | #412 |
| `Curve2D.interpolate(points:startTangent:endTangent:)` | tolerance pinned at `1e-6` with no parameter path to reach it | honours the new `tolerance:` parameter (default `1e-6`, so the bare call is unchanged) | #410 |
| `BRepGraph.sampleFaceUVGrid` | unpacked `uSamples * vSamples` points regardless of how many the bridge wrote | unpacks the written count, with `gaussianCurvatures`/`meanCurvatures` truncated to match | #419 |

Two lower-level changes with the same character:

- `Curve3D.interpolate(points:startTangent:endTangent:)` (the overload without `tolerance:`) is
  **removed**. Swift always prefers the exact-arity match, so the ordinary 3-argument call could
  never reach the tolerance-aware overload it shadowed. The 3-argument call now resolves to that
  overload with its default (#400).
- `BRepGraph`'s 12 adjacency accessors guard `count <= 0` rather than `count == 0`. The bridge
  `...Count` functions narrow through an unchecked `int32_t` cast, so a negative count now
  degrades to `[]` instead of trapping `Array(repeating:count:)` (#418).

Routing the three `arcLength` entry points through `length`/`length(from:to:)` also moved them onto
that pair's integrator, which was the less accurate of the two the bridge carried. That is fixed in
#477 (entry at the top of this file), so the accuracy the `arcLength` spellings had before #408 is
restored and `length`/`length(from:to:)` gain it as well. Note the consequence for the C bridge:
`OCCTCurve3DArcLength`, `OCCTCurve3DLength` and `OCCTCurve3DArcLengthBetween` are no longer reached
from Swift at all (nothing in `Sources/OCCTSwift` references them), though they remain exported for
direct C consumers.

#### Public Swift API

Source-breaking, both MAJOR-triggering under [`SEMVER.md`](SEMVER.md) and tracked on #377 so the
obligation survives the squash-merge:

- `Surface.drawMesh(uCount:vCount:)` and `Surface.evaluateGrid(uParameters:vParameters:)` return a
  new `SurfaceGrid` instead of `[[SIMD3<Double>]]`. They previously nested in *opposite* orders
  (`[u][v]` vs `[v][u]`) with nothing at the type level to catch a caller mixing them up;
  `SurfaceGrid` is indexed by `.at(u:v:)`, so the ambiguity is gone rather than documented (#404).
- `Curve3D.interpolate(points:startTangent:endTangent:)` removed, as above (#400).

Renamed, with a deprecated shim, so existing source still compiles:

- `Curve2D.approximated(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)` is now
  `approximatedInRange(...)`. It wraps `Approx_Curve2d` (explicit sub-range, separate U/V
  tolerances, continuity fixed at C2), a genuinely different algorithm from
  `approximated(tolerance:continuity:maxSegments:maxDegree:)`'s `Geom2dConvert_ApproxCurve`, and
  nothing steered a caller between them (#407).

Additive:

- `Surface.mirrored(acrossPoint:)` and `Surface.mirrored(acrossAxis:direction:)`, closing the gap
  between `Surface`'s copy-returning transform family and `Curve3D`/`Curve2D`'s (#414).
- `BRepGraph.contains(uid: GraphItemUID)`, the counterpart to the existing `GraphUID`/`GraphRefUID`
  overloads (#417).
- `Surface.KnotSplitResult.uSplitParams`/`vSplitParams`, and `LawFunction.knotSplitParameters(continuityOrder:)`.
  Both back onto values their OCCT class already computed and discarded (#403).
- `ArcLengthCurveAdaptor`, a public protocol carrying the composition logic
  (`point`/`tangent(atAbscissa:)`, `points(spacing:)`) that `EdgeCurve` and `WireCurve` previously
  duplicated line for line. Both stay distinct public classes (#422).
- `tolerance:` parameters on `Curve2D.interpolatePeriodic` and
  `Curve2D.interpolate(points:startTangent:endTangent:)`, defaulted to the value each used to
  hardcode (#410, #412).

#### Bridge C API

The C surface is not covered by the Swift SemVer promise, but direct `OCCTBridge.h` consumers
are affected:

- **Signature changed:** `OCCTSurfaceKnotSplitting` takes four more arguments (`outUParams`,
  `maxUParams`, `outVParams`, `maxVParams`) and reports true counts even when writing was
  truncated, so a caller can retry with a bigger buffer (#403).
- **Removed:** `OCCTCurve3DCreateArc3Points` (#415), `OCCTGceMakeCone` and
  `OCCTGceMakeCylinderFrom3Points` (#420), `OCCTGeom2dLPropCurExt` and `OCCTGeom2dLPropCurInf`
  along with the `OCCTCurInfPoint` struct (#402). Each duplicated a sibling that survives.
- **Added:** `OCCTSurfaceMirrorPoint`, `OCCTSurfaceMirrorAxis` (#414), `OCCTBRepGraphHasItemUID`
  (#417), `OCCTLawBSplineKnotSplitParams` (#403).
- **Behaviour:** `OCCTCurve2DProjectPoint2D` returns `NaN` for the parameter on failure and
  documents `outDistance < 0` as the signal. It used to return `0.0`, which is a legitimate
  parameter: projecting a segment's own start point onto it returns exactly `0` at distance `0`
  (#413). `OCCTInterpolate2DPeriodic`, `OCCTInterpolate2DWithTangents` and
  `OCCTInterpolateWithTangents` now forward to their canonical siblings rather than holding a
  second copy, so direct C consumers get the same behaviour as Swift callers (#412, #410, #400).

#### Unified with no behaviour change

`Curve2D.curvatureExtremaDetailed()`/`inflectionPointsDetailed()` now delegate to their plain
siblings instead of re-running the same `GeomLProp_CurAndInf2d` (#402). `Curve3D.arc(through:_:_:)`
became the true alias of `arcOfCircle(start:interior:end:)` it was already documented as (#415).
`Curve3D`'s six immutable transform functions fold onto the same `buildTrsf3D` the mutating family
used, and the mutating dispatcher gained the `IsNull()` guard the immutable six already had (#416).
`BRepGraph`'s 12 count-buffer-fetch-map accessors share one helper (#418). Ten flat-buffer unpack
sites share `unpackSIMD3` (#419). `Surface.coneFrom2PointsRadii`/`cylinderFrom3Points` delegate to
their `GC_Make*`-backed counterparts (#420), as do the four overlapping plane factories (#421). The
`EdgeCurve`/`WireCurve` bridge primitives share one `Adaptor3d_Curve&` helper set; public C symbol
names are unchanged (#422).

Test coverage went up where the audit found none: `Curve3D.arc(through:_:_:)`,
`Surface.rotated(axisOrigin:axisDirection:angle:)`, `BRepGraph.rootProductIndices`,
`EdgeCurve`/`WireCurve`'s `points(spacing:)`/`parameterRange`/`point(atParameter:)`, and
degenerate-input cases across every unified factory pair had no dedicated tests before.

### v1.16.1 (July 2026): fix — unify consumed the shape it was given, so a declined merge still damaged the caller's solid (#446)

`ShapeUpgrade_UnifySameDomain` rewrites sub-shapes of the shape it is handed, and those rewrites
reach the `TShape`s the caller's `Shape` still shares. The result: the idiom every consumer writes —
take the merge if it is valid, otherwise keep what you had — silently damaged what you had. A solid
that was a clean, non-self-intersecting manifold before the call came out of it self-intersecting,
with no result ever accepted. OCCT documents the class as producing a new shape and says nothing
about the input being consumed.

**Root cause, traced in the kernel:** `TransformPCurves` (`ShapeUpgrade_UnifySameDomain.cxx:1228`
and two sibling sites) writes temporary pcurves onto the **input's** edges, against a scratch
reference face the algorithm builds for itself, and only ever removes them again if that reference
face is later replaced. `SetSafeInputMode` does not cover this path — it is unguarded, and safe mode
is OCCT's default anyway, so the reporter was already running it. Minimal reproducer: two stacked
coaxial cylinders (same-domain cylindrical faces, differently parameterised, which is what drives
that path). The input's serialized BREP grows from **1676 to 1778 bytes** across a single
`unified()` call that the caller never even used the result of.

Every unify entry point now works on a private copy (`BRepBuilderAPI_Copy`), so the caller's shape is
untouched whatever the algorithm does to its own input: `Shape.unified()`, `Shape.simplified()`, and
`UnifySameDomainBuilder`. No API change and no new parameter — the copy is unconditional, because
"the input survives" is what every call site already assumed.

**What the copy costs.** A real fraction of the call, not a rounding error: measured here at 0.6 ms
against 2.3 ms for the merge itself on an 84-face compound (28%), and review measurement on a
600-face compound put it at 18% where there is real merging to do but 64% on a nothing-to-merge input
— which matters because `unified()` is the standard post-boolean cleanup and often finds nothing.
Peak memory doubles for the duration. Unconditional anyway: a `copyInput:` flag would put the
silent-corruption path back within reach of anyone optimising a hot loop, and it can be added later
if a caller measures this as a real problem.

**And what it costs in identity.** The result now shares **no** sub-shapes with the input, even where
nothing was merged — before this change an untouched face came back `IsSame` with the one it came
from. `Shape.isSame(as:)`, `isPartner(with:)` and `isEqual(to:)` are public and consumers do map
selections and attributes across by sub-shape identity, so that code has to key off geometry instead.
This is the unavoidable price of the fix rather than a choice, but it is a behaviour change and is
pinned by a test. `UnifySameDomainBuilder.keepShape(_:)` is unaffected: it still takes the input's own
sub-shapes and maps them across for you.

**Deduplication.** Three bridge call sites constructed `ShapeUpgrade_UnifySameDomain` independently
(`OCCTShapeUnifySameDomain` and `OCCTShapeSimplify` in `OCCTBridge_Healing.mm`, the builder in
`OCCTBridge_Modeling.mm`), each with its own copy of the construct/`Build()`/null-check sequence —
which is exactly why one fix had to be written three times. They now share
`occtUnifySameDomain`/`occtUnifySameDomainInput`/`occtUnifySameDomainMapped`
(`OCCTBridge_Internal.h`). The two public Swift entry points are **not** redundant and both stay:
`Shape.unified()` is the one-shot, `UnifySameDomainBuilder` adds tolerances, `keepShape` and
internal-edge control. Their `concatBSplines` defaults disagree (`true` vs `false`) — left as-is
rather than silently changed under existing callers, but now cross-documented on both.

`UnifySameDomainBuilder.keepShape(_:)` names a sub-shape of the **caller's** shape, so working on a
copy means mapping it onto its counterpart there; without that, every `keepShape` would have quietly
kept nothing. `setSafeInputMode(_:)`'s doc comment, which claimed it "copies input shape to preserve
original", was wrong on both counts and is corrected.

**Sibling audit (so nobody files a speculative sweep):** the same input-consumption class was checked
on the same fixture for `ShapeFix_Shape` (`healed()`, `fixed(tolerance:)`), `BRepAlgoAPI_Defeaturing`
(`withoutSmallFaces(minArea:)`) and `ShapeUpgrade_ShapeDivideClosed` (`dividedClosedFaces()`). All
four leave the input byte-identical. `ShapeUpgrade_UnifySameDomain` is the outlier, not the first of
a family.

Bridge-only fix: no OCCT kernel change, no xcframework rebuild, no new operations (count unchanged at
4,258). New regression suite `Issue446UnifyInputMutationTests` (`OCCTShapeHealingTests`) asserts the
input's serialized BREP is byte-identical across all three entry points, that a declined merge leaves
the shape's validity/self-intersection/volume unchanged, that the merged result's geometry is
unmoved, that the result no longer shares sub-shapes with the input, and that `keepShape` still
blocks a merge through the copy (per-edge: the junction seam blocks it, a cap circle does not). Full
`swift test` (combined with #397 below): 4480 tests in 1292 suites, all passing.

Also fixed in passing: `docs/reference/Shape-Features.md` credited `withoutSmallFaces(minArea:)` to
`ShapeAnalysis_CheckSmallFace` + `ShapeUpgrade_UnifySameDomain`; `OCCTShapeRemoveSmallFaces` uses
neither, it collects small faces by area and removes them with `BRepAlgoAPI_Defeaturing`.

### v1.16.1 (July 2026): fix — `Shape.faceAddHole()` rejected every circular hole wire, and never oriented the ones it kept (#397)

`Shape.faceAddHole(face:wire:)` returned `nil` for **every** hole wire built from circular geometry —
`Wire.circle(origin:normal:radius:)` and a hand-joined two-arc circle alike, at any radius, in either
winding — while a polygonal hole on the same face worked. The cause was this wrapper's own
degenerate-wire guard (added for #234, which declines a zero-area hole because the invalid face it
produces goes on to SIGSEGV `ShapeFix` downstream): the guard counted the wire's **vertices**, and a
circle has one (`Wire.circle`) or two (two joined arcs), so it tripped the "fewer than 3 distinct
vertices" rejection meant for out-and-back line segments. Nothing in OCCT was rejecting these wires;
they never reached `BRepBuilderAPI_MakeFace::Add` at all.

The guard now samples points **along the wire's curves** rather than at its vertices, which is what
lets a circular hole describe the area it encloses. Sampling alone would weaken #234's protection —
an arc traversed out and back spreads its samples over a curve and so clears the collinearity test
that catches a straight out-and-back — so the loop's own vector area is checked as well, and a wire
whose mean width (area ÷ longest chord) falls below `Precision::Confusion()` is still declined.

**Fixing the `nil` exposed a second half to the same defect**, pre-existing and equally silent: the
wrapper never oriented the wire it added. `MakeFace::Add` does no reorienting of its own, so a hole
wound the same way as the face's outer boundary was added as a second **outer** loop — a 20×20 face
given a 2×2 hole came back with area 404 rather than 396, and its prism was not a valid solid. Only
callers who happened to hand in an opposite-wound wire ever got a hole. `faceAddHole` now compares the
hole's winding against the face's outer boundary in the face's plane and reverses the wire when they
match, the same rule `OCCTShapeCreateFaceWithHoles` has used since #274, with a validity-checked
retry of the other orientation for non-planar hosts where no plane can be fitted. Either winding now
cuts, and the sampler both tests share is now one helper (`occtSampleWirePoints`) rather than two
copies of the same traversal.

**One behaviour change beyond the two bugs:** when *neither* winding yields a `BRepCheck`-valid face,
`faceAddHole` now returns nil instead of the invalid face. That case is not a winding question — the
wire does not lie inside the face's boundary, and no orientation makes it a hole — and returning a
non-nil invalid face is exactly what #234 established breaks callers later. Pre-existing behaviour
(the old code never validated its result at all), tightened here because the winding retry introduced
the validity check anyway.

Bridge-only fix: no OCCT kernel change, no xcframework rebuild, no new operations (count unchanged at
4,258). New regression suite `Issue397CircularHoleTests` (`OCCTModelingTests`) covers `Wire.circle`
and two-arc holes in both windings, the extruded-solid volume, same-winding polygon holes, the
zero-area curved wire that must still be declined, and the boundary-crossing wire that no winding can
turn into a hole; `Issue234DegenerateHoleTests` passes unchanged. Full `swift test` (combined with
#446 above): 4480 tests in 1292 suites, all passing.

### v1.17.0 (July 2026) - fix: three more first-of-N `TopExp_Explorer` sites dropped most of their input (#443)

#442's audit note asked for the first-of-N `TopExp_Explorer` idiom to be grepped for across the whole
bridge before closing it, on the grounds that #439 had two instances and #442 two more, and every one
was found by someone reading the neighbouring lines rather than from a report. That sweep found **23
candidate sites**: 8 false positives, 5 where "first" is the documented contract, and 10 undocumented
silent picks. Three of those were confirmed **by measurement** to lose most of their input, and are
fixed here. The other seven are documented rather than changed: each is singular by contract, and
widening it would change what its arguments mean.

Measured against a compound of two disjoint 10 mm boxes (2 solids, 12 faces, 2000 mm³):

| call | before | after |
| --- | --- | --- |
| `Shape.solid(from:)` | 1 solid, 1000 mm³ | 2 solids, 2000 mm³ |
| `Shape.upgraded()` | 1 solid, 1000 mm³ | 2 solids, 2000 mm³ |
| `AssemblyNode.setTriangulationFromShape` | 4 nodes, 2 triangles | 48 nodes, 24 triangles |

**`Shape.solid(from:)`** (and `Shape.solidWithFullHistory(from:)`) is the sharpest of the three: its
own doc names sewing output as the expected input, and sewing two bodies yields exactly the two-shell
input it mishandled. After #442 the two sibling entry points disagreed on that same shape:
`sewn.solidFromShellFixed()` gave 2 solids / 2000 mm³ and `Shape.solid(from: sewn)` gave 1 / 1000.
Both now go through #442's `occtBodyBoundingShells`, so they agree by construction; the helper moved
to `OCCTBridge_Internal.h` for that. The history variant shares **one** `ShapeBuild_ReShape` across
the per-body `ShapeFix_Solid` runs, so the single history still covers every body:
`BRepTools_ReShape::History()` builds a fresh `BRepTools_History` from the context's whole replacement
map on each call, so earlier bodies' replacements are still in it (confirmed against `occt-src`).

**`Shape.upgraded()`** is documented as a "sew + make solid + heal pipeline" and is the call most
likely to be pointed at a raw imported mesh, where multi-body input is the norm. Its solid step now
builds one solid per body-bounding shell. Two limits inherent to sewing first are now documented
rather than silent: sewing dissolves the input's solids, so a **hollow body's cavity is filled**
(8000 mm³ for a 7000 mm³ hollow cube, unchanged from before but never stated); and the solid step
replaces the sewn shape rather than merging into it, so content sewing could not attach to a shell is
not carried through. `fixed(tolerance:)` is the call for either case, since it does not sew.

**`AssemblyNode.setTriangulationFromShape`** meshed the whole shape and then stored only the **first
face's** triangulation on the label. A 6-face box and a 12-face two-box compound both stored 4 nodes
and 2 triangles, for a doc comment reading "by meshing a shape". Arguably the worst of the three,
since the attribute is what later readers trust as the label's geometry. It now merges every meshed
face into one `Poly_Triangulation` in the shape's own coordinate system: per-face locations applied to
the nodes, reversed faces' winding and node normals flipped so the result is consistently outward
(the same rules `Shape.mesh()` applies), the worst contributing face's deflection carried over, node
normals kept only if every face has them, and per-face UV nodes dropped since they index parameter
spaces that stop meaning anything once the faces are pooled.

**A latent case in #442's own helper was found and fixed with them.** `occtBodyBoundingShells` ran its
enclosure-parity pass within each solid but added every shell belonging to *no* solid unconditionally,
on the reasoning that a free shell has no declared cavity relationship. But **sewing dissolves the
solid that carried that declaration**, and sewing is the ordinary way all of these calls are reached.
Measured on a sewn hollow box: the same two shells answered 1 body while inside a solid and 2 once
sewn, the second being the cavity as a positive solid; on `{hollow body, body inside its cavity}` it
gave 3 bodies for a 2-body part. Free shells are now one further group through the same parity pass,
so both readings agree. Containment among free shells is geometric rather than declared, so a closed
shell alone inside another is read as that one's cavity: the same reading OCCT's own solid convention
gives it, and the only one available without a declaration. A body nested inside a cavity is enclosed
twice, so it is still a body. None of #442's shipped cases change (two disjoint free shells → 2 solids;
the same free shell twice → 1).

The parity pass is O(N²) classifications in the size of one group, which was fine when a group was one
solid's 1-3 shells but is not when it is every free shell of a sewn mesh. A conservative bounding-box
pre-filter now prunes pairs before any ray cast, and skips building a classifier for a reference that
overlaps nothing: enclosure implies box containment, so no verdict changes. Measured at 200 disjoint
shells: 160 ms without it, 0.7 ms with, identical results. This is not the `Bnd_Box` rule #442
rejected; that failed as the *decision* rule, which is exactly why it is sound as a pre-filter.

> **Behaviour change for consumers:** `Shape.solid(from:)`, `Shape.solidWithFullHistory(from:)` and
> `Shape.upgraded()` now return a **compound** where they previously returned one arbitrary body's
> solid, for multi-body input only. Single-body input is untouched, down to the returned shape type.
> A caller that assumed `.solid` unconditionally should read `.solids` instead.
> `Shape.solidFromShellFixed()` returns **one** body where it returned two for a sewn hollow part,
> the second having been the cavity. `AssemblyNode.setTriangulationFromShape` stores nodes in the
> **shape's** frame rather than the first face's local frame, so a located shape's stored coordinates
> move as well as its node count.

The seven remaining undocumented picks are documented in place, in both the Swift doc comment and the
bridge, with why each stays singular: `MedialAxis.init(of:)` (a medial axis is a property of one face,
and the result type holds one graph), `Shape.halfSpace(face:referencePoint:)` (a half-space is bounded
by one face by definition), `Shape.fillet2D(vertexIndices:radii:)` and `chamfer2D(edgePairs:distances:)`
(the indices are numbered within the chosen face, so covering every face would need per-face index
lists and a different signature), `Shape.splitByWireOnFace(_:faceIndex:)` and
`locOpeSplit(wiresOnFaces:)` (the pair list is already where several wires are named), and
`Shape.solidFromShells(_:)` (the argument order *is* the outer-versus-cavity contract, so widening
each argument would make it stop meaning anything). `OCCTShapeBuildThreadCutter` is internal and
single-body by construction. `Shape.faceRestricted(by:)` and `Wire.offset(by:joinType:)` already
stated what they do and are untouched.

**Review round 3: the one item left open, `Shape.solid(from:)`/`solidWithFullHistory(from:)`'s own
`BRepBuilderAPI_MakeSolid` failure path.** Flagged unresolved in review round 2: before this PR, a
`MakeSolid` failure on the (only) shell was a hard failure for the whole call; per-body, it silently
dropped just that one body from the result compound — the exact defect class this PR exists to fix,
reopened one layer down. Checked against `occt-src` rather than assumed: `BRepLib_MakeSolid`'s
single-shell constructor (`BRepLib_MakeSolid.cxx`) unconditionally calls `Done()` after adding the
shell, with no closure or coherence check anywhere in the path — matching its own header's "a solid
under construction is always valid." Confirmed with a probe: `BRepBuilderAPI_MakeSolid` on a
5-of-6-face open shell, and on a bare empty shell, both come back `IsDone() == true` with a non-null
`Solid()` — just a geometrically invalid one (`BRepCheck_Analyzer.IsValid() == false`), not a failure.
**So the failure this review item worried about cannot occur for this call**, confirmed by re-running
the two new regression tests below against the pre-fix code: both still pass, because the code path
they exercise never reaches the branch in question either way.

Fixed anyway, for defense in depth: the dead `continue` (drop) is now `push_back` (keep the shell
as-is), matching `OCCTShapeSolidFromShell`'s identical "keeps a body rather than dropping it if that
changes" comment — same belt-and-braces contract as its #442 sibling, zero observable behaviour
change today. Two new tests (`solid(from:) keeps an open body rather than dropping it`,
`solidWithFullHistory(from:) keeps an open body rather than dropping it`) pin the guarantee that
actually matters regardless of mechanism: a closed shell alongside a disjoint 5-of-6-face open shell
still comes back as 2 bodies / 11 faces, not 1.

**Review round 4: `OCCTShapeUpgrade` had the same dead-but-inconsistent `MakeSolid` drop round 3
fixed on its siblings, and two doc passages didn't hold up.** Round 3 fixed the silent per-body drop
on `Shape.solid(from:)`/`solidWithFullHistory(from:)`, but `OCCTShapeUpgrade`'s own per-shell loop —
touched by this same PR — still had the plain `continue`-style drop, missed because it wasn't one of
the two functions round 3's own finding was about. Fixed the same way: `push_back` the unfixed shell
on `IsDone() == false` instead of dropping it, same belt-and-braces reasoning, same "dead code today"
status (verified: `BRepBuilderAPI_MakeSolid`'s single-shell constructor never fails). A new test,
`upgraded() keeps an unclosable shell's faces rather than dropping them`, pins it — on face count
rather than solid count, since `upgraded()`'s later `ShapeFix_Shape` pass reclassifies the kept body
so it no longer counts as a `TopAbs_SOLID`, unlike the round-3 siblings that don't run that pass.

Also: three existing `docs/reference/` pages covering methods documented (not changed) by this PR —
`Shape-Measurement.md` (`fillet2D`/`chamfer2D`/`solidFromShells`), `Shape-Builders-1.md`
(`splitByWireOnFace`), `Shape-Builders-2.md` (`locOpeSplit(wiresOnFaces:)`) — had the caveat added to
the Swift doc comment but not mirrored into the page; now they match. And `upgraded()`'s own doc
comment claimed "free shells each become a body," which is what this very PR's free-shell parity fix
made untrue — the next line already stated the correct, narrower rule (an even-enclosed free shell is
skipped), so the topic sentence was reworded to match rather than contradict it, reusing
`solid(from:)`'s more precise phrasing.

Bridge-only fix: no OCCT kernel change and no `OCCT.xcframework` rebuild.

### v1.16.0 (July 2026): fix — `Shape.fixSolid()`/`solidFromShellFixed()` healed only the first body (#442)

`Shape.fixSolid()` and `Shape.solidFromShellFixed()` healed the **first** solid (respectively the
first shell) a `TopExp_Explorer` yielded and discarded every other body without a signal. The return
was a well-formed `Shape` that looked like a healed version of the input, so nothing downstream could
tell that most of the part was gone: a 2000 mm³ two-box compound came back as a 1000 mm³ single solid.

Both now cover every body. `ShapeFix_Solid` cannot be handed a compound — its constructor and `Init`
take a `TopoDS_Solid`, and `TopoDS::Solid` throws on anything else — so multi-body input has to be
driven one solid at a time. **A compound result is not a new return category:** `ShapeFix_Solid::Shape()`
already hands one back when a single solid's shells resolve into several bodies, so callers that
handled `fixSolid()` correctly for a multiconnex solid already handle this.

`solidFromShellFixed()` builds one solid per **body-bounding** shell, decided by **enclosure parity**:
within each solid, a shell bounds a body iff an *even* number of the other shells enclose it, plus
every shell belonging to no solid at all (the usual shape of sewing output). A solid's *cavity* shells
are skipped: a hole is not a body, and building one as a positive solid would return a compound whose
volume double-counts the part (8000 + 1000 for a 7000 mm³ hollow box). Enclosure is decided with
`BRepClass3d_SolidClassifier`, not by shell orientation — measured, both a hollow solid's outer and
cavity shells are `FORWARD`, so orientation carries no signal here; each reference is read once with
`PerformInfinitePoint` so an inside-out shell flips the sense rather than the answer.

An **open** shell is skipped in the reference role (`BRep_Tool::IsClosed`, which for a shell is a real
edge-pairing check rather than the `Closed()` flag, so a genuine cavity shell still qualifies). Open
shells reach this code by contract — the same call accepts them and returns them as unclosed solids —
and under parity every shell is a reference, so one that cannot enclose anything would still add a
spurious ±1 to the others. Measured on `{A_outer, A_cavity, openShell wrapping both}`: without the
guard the outer shell is **dropped outright** (enclosed count 1, odd) and the cavity emitted as a
positive body.

Parity is used because **every rule that picks one reference shell and calls everything outside it a
body is wrong on some real input**, and the two obvious choices fail on different ones. Measured, on
one solid holding `{A_outer 8000, A_cavity 1000, B_outer 27000}`: picking the widest shell emits
`A_cavity` as a positive body (36000 mm³ against a correct 35000), because it is outside *B*; picking
`BRepClass3d::OuterShell` gets that case right but names the *cavity* on an inside-out hollow solid,
emitting the true outer shell as a second overlapping body (9000 mm³ for a 7000 mm³ part). Parity
assumes no single enclosing shell and needs no orientation, and it also reads a body nested inside
another body's cavity correctly — enclosed twice, so even, so a body (8064 mm³, measured). It is
O(N²) classifications in the shells of one solid, where N is 1-3 on any real input and 1 is free.

Neither call can drop a body by any path: a solid `ShapeFix_Solid` fails to heal comes back unhealed
rather than vanishing, `Shape()`'s compound is flattened by direct children so a shell it could not
close is kept rather than skipped by a `TopAbs_SOLID` explorer, and a compound holding the same free
shell twice yields one solid, not two.

> **Reading the result of `fixSolid()`:** because no body is dropped, a result body is not always a
> solid. `ShapeFix_Solid` hands back a shell it could not close, and a solid it fails to heal comes
> back unhealed. `result.solids.count` can therefore be lower than the number of input bodies with
> nothing lost. Spot an unclosed body by walking the result's **direct children**
> (`child(at:)` over `nbChildren`) — **not** `subShapes(ofType: .shell)`, which maps at every depth
> and so reports one shell per *healthy* solid as well, making it useless as a failure signal. A body
> that came back unhealed is still a solid; use `isValid` for that.

> **Behaviour change for consumers:** these two calls now return a **compound** where they previously
> returned one arbitrary body's solid, for multi-body input only. Single-body input is untouched, down
> to the returned shape type. A caller that assumed `.solid` unconditionally should read `.solids`
> instead; a caller that wants one specific body should pick it before healing.

Unlike #439, no doc comment was being violated here — the Swift docs were one-liners that said nothing
about multi-body input either way — so this is a design decision rather than a contract fix. Returning
`nil` for multi-body input (what #439 did for `outerShell`) was rejected: `outerShell` answers a
question about *one* body and has no meaningful answer for several, whereas refusing to heal a
two-body part is a capability loss with no upside. `ShapeFix_Shape` was checked as the "call the other
class" alternative the issue suggested — it does handle a multi-solid compound correctly (2 solids,
2000 mm³) and is already wrapped as `Shape.fixed(tolerance:…)`, now cross-referenced from `fixSolid()`
for callers with mixed content to preserve.

`OCCTShapeFixSolid` also gains the `if (!shape) return nullptr;` guard its siblings in the file use.
Not reachable through the Swift API, but a null deref is an uncatchable SIGSEGV rather than something
the enclosing `try` would catch.

**Documentation correction:** `solidFromShellFixed()` was previously described, before and after this
change, as returning `nil` when a shell does not close. Reading `ShapeFix_Solid.cxx`, `SolidFromShell`
does `B.MakeSolid(solid); B.Add(solid, sh);` unconditionally before any classification and returns
that even on its exception path — it never returns a null solid and never rejects an open shell. The
only `nil` is "no shells at all"; an open shell comes back as a solid that is not closed.

Bridge-only (no OCCT kernel change, no `OCCT.xcframework` rebuild). Operation count is unchanged at
4,258 — behaviour and documentation only. Source comments, `OCCTBridge.h` and the generated reference
(`docs/reference/Document-OCAF-Attributes.md`) all state the same rule.

### v1.16.0 (July 2026): fix — `Shape.outerShell` answered for the wrong body on a multi-solid compound (#439)

`Shape.outerShell` returned the **first solid's shell** on a compound holding more than one solid,
where its own doc comment specified `nil`. The result was a plausible-looking `Shape` that silently
answered for one arbitrary body, so callers guarding on `nil` never fired and every measurement
taken against it was wrong with no signal. On the reporter's 2-solid part a per-vertex sweep went
from mean 0.0131 mm / max 0.2511 mm to mean 2.3129 mm / max 18.2483 mm — output that reads as a
poorly fitted part, not as an error.

`OCCTShapeOuterShell` took the first solid a `TopExp_Explorer` yielded without ever checking whether
a second followed. `OCCTShapeInnerShells` (#212) had the identical defect and is fixed with it: a
2-solid compound reported the first solid's cavities as though they were the compound's.

Both now resolve through one `occtSoleSolid` helper that accepts a solid, or a compound/compsolid
wrapping exactly **one** solid, and returns nothing for a container of two or more. This is the
contract the doc comment already stated; it is a behaviour change only for inputs that were being
answered incorrectly.

> **Behaviour change for consumers:** a caller that passed a multi-solid compound or compsolid to
> `outerShell` and got a shell back now gets `nil`; the same input to `innerShells` now gives `[]`.
> That shell was one arbitrary body's, so any measurement against it was already wrong. Migrate to
> `outerShells` (per body), `solids.flatMap(\.innerShells)` (per body), or
> `Shape.compound(shape.subShapes(ofType: .face))` (whole boundary, cavities included).

**Added** `Shape.outerShells: [Shape]` (`OCCTShapeOuterShells`) — the outer shell of every solid, in
exploration order, so the fix is not purely subtractive. Equivalent to `solids.compactMap(\.outerShell)`
in a single traversal. Note these shells drop internal void walls by design; to measure against the
complete boundary of a multi-body part, cavities included, use
`Shape.compound(shape.subShapes(ofType: .face))`.

Bridge-only (no OCCT kernel change, no `OCCT.xcframework` rebuild). Source comment, generated
reference (`docs/reference/Shape-Measurement.md`) and `OCCTBridge.h` now state the same rule —
the generated page had been paraphrasing the contract with the parenthetical dropped.

### v1.16.0 (July 2026): fix — `Shape.fill` SIGSEGV'd on its own default parameters (#430)

`FillingParameters` defaults `continuity` to `.g1`, so the ordinary
`Shape.fill(boundaries: [wire])` call requested tangent continuity. For any boundary edge
borrowed from an existing face — the normal way to get one — that took the whole host process
down with an uncatchable SIGSEGV rather than returning `nil`.

The bridge always used `BRepFill_Filling`'s face-less `Add(edge, order)` overload. That overload
fetches the edge's pcurve *and its `[first, last]` range*, then builds its constraint from the
**untrimmed** pcurve, discarding the range it just read. For the usual `Geom2d_Line` pcurve that
means a ±2e100 parameter span instead of, say, `[0, 2π]`. The resulting constraint cannot be
projected, and `GeomPlate_BuildPlateSurface::Perform`'s projection-failure recovery branch then
dereferences its own `myGeomPlateSurface` — which `Perform` unconditionally nullifies on entry and
never assigns on that path. Both defects are upstream and present in OCCT master; neither is
reachable through the face-carrying `Add(edge, face, order)` overload, which trims correctly.

Fixed bridge-side by keeping the face-less overload out of the call path whenever continuity is
above positional: a support face is used if one is available, derived from the edge's own pcurve
surface if not, and only a boundary edge with no pcurve at all falls through to the old overload —
where OCCT's documented `Standard_Failure` makes it a clean `nil`. Verified equivalent to a
kernel-patched build: identical G0/G1 errors and identical geometry.

Two new overloads make the continuity reference explicit rather than implied:

- `Shape.fill(boundaries:supportedBy:parameters:)` — each boundary edge takes its tangency
  reference from that edge's own ancestor face in a given shape. The "cap this opening so it flows
  into the walls around it" case.
- `Shape.fill(constraints:parameters:)` with the new `FillConstraint` — per-edge support face,
  continuity order, and whether the edge bounds the face or is an internal constraint.

A face named through `FillConstraint.support` is now used or the fill fails. It previously fell
back to a face derived from the edge when the named one carried no pcurve, which answered with a
continuity reference the caller never asked for and gave no signal that their choice had been
discarded. Auto-picked faces (`supportedBy`) still degrade per edge, since nothing was chosen
there to begin with. Note a planar face is legitimately usable even with no pcurve stored, because
`BRep_Tool::CurveOnSurface` projects onto a plane on the fly.

Also corrected (#431), at both sites that had it:

- `OCCTShapeFill`'s `BRepOffsetAPI_MakeFilling` constructor call bound
  `maxDegree`/`maxSegments`/`continuity` to `Degree`/`NbPtsOnCur`/`TolAng`, leaving `MaxDeg` and
  `MaxSegments` at their defaults and making the angular tolerance the continuity ordinal. Measured
  effect on a cylinder-rim fill: G0Error 0.615 before, 0.00040 after.
- `OCCTFillingCreate` (backing `FillingSurface`) passed `maxDegree`/`maxSegments` as
  `SetResolParam`'s 3rd and 4th arguments, which are `NbIter` and `Anisotropie` — so `maxDegree`
  silently became the solver's iteration count (8 instead of 2, roughly 3x the work at the
  documented defaults) and `maxSegments` became a bool. `SetApproxParam`, the only place `MaxDeg`
  and `MaxSegments` can actually be set, was never called at all, leaving both documented
  parameters inert. `FillingSurface(maxDegree:maxSegments:)` now controls what its names say.

Continuity mapping is now explicit and documented: `BRepFill_Filling` forwards the `GeomAbs_Shape`
value to `GeomPlate_CurveConstraint` as an integer plate order and rejects anything outside
`[-1, 2]`, so `.g2` is `GeomAbs_C1` (ordinal 2). `GeomAbs_G2` (ordinal 3) always throws, despite
OCCT's header docs naming it as the curvature value.

`FillingSurface` reached the same OCCT defect through its own bridge implementation and crashed
identically (#432). The constraint helpers moved to `OCCTBridge_Internal.h` and both entry points
now share them, so that crash is fixed too.

**Note on the planar/curved split** — worth knowing before probing this family. The same face-less
call is a *catchable* `Standard_Failure` on a **planar** support surface, which rejects the ±2e100
parameters, and an uncatchable SIGSEGV on an **unbounded or periodic** one (cylinder, sphere,
cone), which accepts them. The pre-existing filling tests only ever used rectangles and polygons at
`.c0`, so neither half of the defect ever showed.

**Was open, now fixed above:** `FillingSurface`'s continuity mapping was wrong in its own way —
`.c1` requested curvature rather than tangency, and `.c2` landed on an order OCCT rejects, which
failed the entire `build()` (`add` returned `true` regardless; it only appends). Fixed as #433,
folded into #434's convergence of the two wrappers onto one implementation — see the entry above.
The kernel patch for the two upstream defects, and the upstream filing, remain deferred.

### v1.15.20 (July 2026): fix — `Edge.circleProperties` returned `nil` for every full-circle edge (#378)

`Edge.circleProperties` (`MeasurementHelpers.swift`) fits a circle through three points sampled
at `[parameterBounds.first, mid, parameterBounds.last]`. For a full circle the underlying curve
is periodic and `parameterBounds` is `(0, 2π)`, so `point(at: parameterBounds.last)` evaluates to
the same point as `point(at: parameterBounds.first)` (identical to ~1e-16) — the three-point fit
then received two coincident points and returned `nil` for every full-circle edge: a drilled
hole, a bore, a plain cylinder's cap boundary. Partial arcs (`first != last`) were unaffected.

**Fixed:** when `parameterBounds` spans a full `2π` (periodic curve), sample the third point at
2/3 of the range instead of at `bounds.last`, and the second point at 1/3 instead of the
midpoint — all three samples land at distinct, non-wrapping parameters. Partial-arc sampling
(midpoint + `bounds.last`) is unchanged. No public API surface change — same signature, same
`nil`-for-non-circular-edges contract — so this is a patch per `docs/SEMVER.md`.

**Tests:** `edgeCirclePropertiesFullCircle` (`v0.143 Circle property extraction` suite,
`OCCTCurveTests`) — a cylinder's two full-circle cap edges now yield non-nil `circleProperties`
with the correct radius and `isFullCircle == true`; confirmed it fails against the pre-fix code.

### v1.15.19 (July 2026): docs + tests — `Shape.mesh()`/`Shape.loadSTL()` winding guarantees, retract the #375 "loses winding" concern (#375)

**Not a bug — investigated and retracted, both parts.** #375 asked whether `Shape.mesh()`
(always outward for a valid solid, even after a mirror) and `Shape.loadSTL()` (reportedly
"locally inconsistent" after round-tripping a globally-reversed STL) were losing orientation
information. Both were root-caused with a ground-truth C++ test against the pinned xcframework,
independent of any Swift-side code.

1. **`Shape.mesh()` outward-normalization is genuine, intentional OCCT behavior.** A
   `BRepPrimAPI_MakeBox` box already has a mixed FORWARD/REVERSED face-orientation split (3/3)
   baked into its topology; mirroring it (`gp_Trsf::SetMirror`, a negative-determinant
   transform) through `BRepBuilderAPI_Transform` produces the **identical** 3/3 split, and both
   the original and mirrored mesh read 12/12 triangles outward. OCCT compensates a mirror
   transform by flipping face orientation flags, preserving the invariant that a valid solid's
   faces always classify consistently outward — the bridge's existing
   `face.Orientation() == TopAbs_REVERSED` check (already correct) has nothing left to get
   "wrong". There is no way, via a valid `Shape`, to get caller-controlled/"wrong-way" winding —
   that's what `Mesh(vertices:normals:indices:)` is for.

2. **`Shape.loadSTL()` preserves facet winding exactly, including a full global reversal.** A
   from-scratch, independently-verified box STL — both normally wound and uniformly, globally
   reversed — round-trips through `StlAPI_Reader` (`BRepBuilderAPI_MakeShapeOnMesh`) +
   `BRepMesh_IncrementalMesh` + the bridge's extraction as **fully consistent** in both cases (12/12
   outward, then 12/12 inward; zero shared-edge orientation conflicts either way). **The "locally
   inconsistent" result that prompted the issue traced to a bug in the reporting test's own STL
   fixture generator** (a `quad()` helper that copy-pasted the bottom face's relative vertex
   layout onto the top face without mirroring it, so the top face's own "non-reversed" baseline
   was already backwards) — confirmed by reproducing that exact fixture's geometry and finding
   the same defect independent of any `reversed` flag. Not an OCCTSwift bug; not filed upstream.

**Docs:** `Shape.mesh(linearDeflection:angularDeflection:)`, `mesh(parameters:)`, and
`loadSTL(from:)`/`loadSTL(fromPath:)` (`Sources/OCCTSwift/Shape.swift`) each gain a `- Note:`
explaining the orientation guarantee, pointing at `Mesh(vertices:normals:indices:)` for
caller-controlled winding.

**Tests:** `Issue375MeshWindingTests` (`OCCTMeshTests`) — a mirrored box still meshes 100%
outward, both `mesh()` overloads. `Issue375STLWindingTests` (`OCCTIOTests`) — a normally-wound
box STL round-trips 100% outward; a globally-reversed box STL round-trips as a clean 100% inward
(not a fraction strictly between 0 and 1, which would mean local inconsistency).

Docs + tests only, no code behavior change, no binary change — reuses the v1.15.18 xcframework
(the binaryTarget URL is unchanged).

### v1.15.18 (July 2026) — fix (kernel): Resource_Manager::Debug / Storage_Schema::ICurrentData() races (#374)

The two upstream OCCT foundation-layer races [#371](https://github.com/SecondMouseAU/OCCTSwift/issues/371)'s
confirmation harness turned up, filed as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398).
Moving every document to a private `TDocStd_Application` (#371) made application/schema
*construction* itself concurrent for the first time — something the old shared singleton never
allowed — and that surfaced two previously-uncaught races.

1. `Resource_Manager::Resource_Manager(const char*, bool)` writes a file-scope `static bool Debug`
   on every construction with zero synchronization; every fresh app's first `DefineFormat()` call
   lazily constructs its own `Resource_Manager`, racing another thread's concurrent first
   construction.
2. `Storage_Schema::ICurrentData()` is a function-local static `Handle` mutated with no lock:
   `Write()` sets it for one store's duration, and *any* `Storage_Schema` construction — including
   the throwaway one `PCDM_ReadWriter_1` builds on **every** `Open()` — nulls it out from under a
   concurrent in-flight save or load.

**Fix:** `Resource_Manager::Debug` → `std::atomic<bool>`. `Storage_Schema` gets a new
`ICurrentDataMutex()` (recursive, since `Write()` re-enters `BindType()`/`AddPersistent()`/
`PersistentToAdd()` on the same thread via driver callbacks) guarding every touch point:
constructor, `Write()`'s whole body, `BindType()`, `TypeBinding()`, `AddPersistent()`,
`PersistentToAdd()`, `HasTypeBinding()`, `ISetCurrentData()`. No public API changes; bridge
untouched — only the pinned `OCCT.xcframework` kernel binary changed (`Scripts/patches/0016`).

Confirmed via a dedicated TSan reproducer (the "unguarded" variant of #371's own confirmation
harness): 13 races + SIGABRT before the fix, 0/4 clean runs after (8×30, 8×50, 10×60, 8×40). Full
`Scripts/tsan-stress.sh run` gate (10 scenarios) clean, 0 regressions on any prior scenario. Full
`swift test` clean. Filed upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398)
(repro, filed during #371); this fix is proposed as the corresponding kernel PR. See
`Scripts/repro/374-resource-manager-storage-schema-race/` for the full writeup.

### v1.15.17 (July 2026) — fix (bridge): stop using the XCAFApp_Application::GetApplication() singleton (#371)

Prompted by upstream maintainer feedback on [OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396)
(our #353 repro issue): `XCAFApp_Application::GetApplication()` "exists solely for compatibility
reasons"; OCCT's own guidance since 7.1 is a private `TDocStd_Application` per caller, not a
shared singleton. Our whole #341/#344/#349/#353 race cluster traced back to every document
sharing that one singleton.

**Fix:** `OCCTDocument`'s constructor (`OCCTBridge_Internal.h`) and every other bridge call site
that grabbed the singleton (9 total, across `OCCTBridge_Document.mm`/`OCCTBridge_IO.mm`) now
build a private `new TDocStd_Application()` instead — confirmed behaviorally equivalent via a
ground-truth C++ test before touching bridge code. `CDF_Application::myDirectory`/`myReaders`/
`myWriters` and `CDM_Application::myMetaDataLookUpTable` (the state #344/#349/#353 fixed) are all
per-instance fields, so a private app per document makes that state exclusive to one document by
construction. Two latent bugs fixed along the way: `OCCTDocumentLoadOCAF`/`OCCTDocumentLoadGLTF`
each opened a document through a *different* app instance than the one stored on the returned
`OCCTDocument` — harmless only because both were the same shared singleton before this change.

**Not a clean win — a dedicated confirmation harness found two new upstream races.** Testing the
new pattern in isolation (private app per thread, zero shared state, zero serialization, run
against the real TSan-instrumented kernel) surfaced `Resource_Manager::Resource_Manager()`
(unsynchronized global `Debug`) and `Storage_Schema::ICurrentData()` (unsynchronized global
`Handle`) — both previously uncaught because every prior TSan investigation shared one
application instance, which accidentally serialized them down to "runs once, ever." Filed
upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398), not yet fixed in
the kernel. `ocafStoreMutex()` (the #349 bridge mitigation) is **not** redundant after this
refactor — its coverage was expanded (not removed) to also wrap `OCCTDocumentDefineFormatBin/
BinL/Xml/XmlL/BinXCAF/XmlXCAF` and `OCCTDocumentCreateWithFormat`, previously outside the lock.

**Upstream kernel PRs for #344/#349/#353 were NOT withdrawn** — they fix real bugs in the
singleton pattern OCCT's own header still calls "the only valid method"; every other OCCT
consumer following that guidance remains exposed. This change only reduces our own bridge's
exposure to those specific mechanisms.

Full `swift test` (4428 tests) clean. `Scripts/tsan-stress.sh swift` (bridge-level, 445 tests)
clean. `Scripts/tsan-stress.sh run` (kernel-level gate, 9 scenarios including the new
`371-getapplication-singleton-elimination`) clean. See `docs/thread-safety.md` and
`Scripts/repro/371-getapplication-singleton-elimination/` for the full writeup.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged (still
v1.15.15) — this is a bridge-only change, no kernel patch.

### v1.15.16 (July 2026) — fix (bridge): Shape.fuseAll(_:) internal parallelism caused data corruption under concurrent calls (#367)

Found continuing #342's classification pass. `OCCTShapeFuseMulti` (backs `Shape.fuseAll(_:)`) was
the only bridge call site that set `builder.SetRunParallel(true)` — internal OCCT parallelism for
a single call. Under concurrent load this was actively unsafe, not just an oversubscription
concern as #342 originally framed it: two threads' top-level `Build()` calls, each requesting
internal parallelism, submit work to the same process-wide `OSD_ThreadPool::DefaultPool()`, and
worker threads from one caller's dispatch can end up processing another caller's data.

**Evidence** (`Scripts/repro/342-boolean-ops/occt_342_boolean_stress.cpp`,
`fuse_multi_parallel` scenario): 8 threads × 50 iterations, **400/400 concurrent operations
produced wrong results** — 27 faces instead of the correct 13 (volume matched almost exactly,
consistent with duplicated/torn geometry rather than floating-point imprecision) — plus 237
ThreadSanitizer race reports across foundational topology code (`TopoDS_Builder::Add`,
`TopExp_Explorer`, `BRep_Tool::Range`, `BOPTools_AlgoTools::MakeSplitEdge`). By contrast, the
plain (non-parallel) boolean ops — `Shape.union(with:)`/`.subtracting(_:)`/`.intersecting(_:)`,
none of which ever set `SetRunParallel` — are clean: 2000 concurrent mixed operations, 0 errors,
0 wrong results, 0 races.

**Fix:** dropped `SetRunParallel(true)` entirely — `Shape.fuseAll(_:)` now runs on OCCT's safe
serial default. Removes the trigger rather than locking around a known-corrupting path. New
regression suite `Issue367FuseMultiThreadSafetyTests`. Full `swift test` (4428 tests) clean.

**Not fixed here:** the underlying mechanism looks like a genuine `OSD_ThreadPool`/
`BOPTools_Parallel` concurrency bug in OCCT's own shared-pool dispatch — more foundational than
anything else found in this project's TSan series (#298/#341/#344/#349/#353/#361 were all
specific static/global variables in narrower classes). Root-causing it properly is tracked as a
follow-up investigation in #367, out of scope for this release.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged (still
v1.15.15) — this is a bridge-only fix, no kernel patch.

### v1.15.15 (July 2026) — fix (kernel): #341's AutoNamingScope revised to a per-instance override after upstream review (#363)

Follow-up to #341 (v1.15.5) and its Swift-side analogue #363/#365 (v1.15.14, `TNaming_Scope` moved
to a per-`Document` field). Upstream reviewer [gkv311](https://github.com/Open-Cascade-SAS/OCCT/pull/1388)
caught something our own v1.15.5 writeup got wrong: `XCAFDoc_ShapeTool::AutoNamingScope`'s
`recursive_mutex` serialized the three known override call sites (`RWMesh_CafReader::fillDocument()`,
`RWGltf_CafReader::fillDocument()`, `XCAFDoc_Editor::Expand()`) against each other, but every *other*
read of `theAutoNaming` in `XCAFDoc_ShapeTool.cxx` (`AddShape`, `MakeReference`, `SetSHUO`) stayed
outside any scope — an unrelated, unscoped caller on another thread could still observe another
thread's temporary override. Making the flag `std::atomic<bool>` closed the memory-safety gap, not
the logical one; our own "the flag is deliberately global" framing at the time was the mistake.

**Fix:** `theAutoNaming` was never meant to express per-document intent — the three overriding call
sites each want to suppress naming for their own document's build, and `XCAFDoc_ShapeTool` is
already one instance per document, so the override belongs there. `XCAFDoc_ShapeTool::OwnAutoNamingScope`
replaces `AutoNamingScope`: a per-instance `myOwnAutonaming` field (-1 inherits the process-wide
default, 0/1 is a local override), with `OwnAutoNaming()`/`SetOwnAutoNaming()`/`UnsetOwnAutoNaming()`
accessors. No locking needed at all — independent documents never touch each other's state.
`XCAFDoc_Editor::Expand()`'s self-recursion (the reason the old fix needed a *recursive* mutex) still
composes correctly: `OwnAutoNamingScope` saves and restores whatever override state the instance had
on entry, not an unconditional reset, so nesting on the same instance works the same way the old
recursive lock did — just without a lock. `theAutoNaming` itself stays `std::atomic<bool>`;
`SetAutoNaming()`/`AutoNaming()` remain callable concurrently from any thread at any time.

**Verified:** same TSan stress as the original fix (10 threads × 200 iterations,
`obj_roundtrip_unique`) — zero races, matching the prior result. New `isolation` scenario
(`Scripts/repro/363-own-autonaming/occt_363_isolation.cpp`) directly checks the property the mutex
fix couldn't guarantee: half the threads locally override via `OwnAutoNamingScope` on their own
document while the other half do plain unscoped `AddShape()` on independent documents relying on the
process-wide default, concurrently — 3000 operations, zero leaks. Patch `0011` updated in place
(same fix, corrected design, not a new patch number). Full production `OCCT.xcframework` rebuild
(macOS, iOS device, iOS simulator); full `swift test` clean.

Upstream: [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) updated to the new design
and re-reviewed — CI green across all 3 platforms, every build/GTest/regression/test job.

### v1.15.14 (July 2026) — fix (bridge): naming scope moved to a per-Document field instead of a shared instance + mutex (#363)

Follow-up to #361, prompted by upstream reviewer feedback on #341's analogous fix
([OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) review comment: "a mutex is not
the right tool here... usage remains unprotected"). v1.15.13's `docNamingScopeMutex()` made
concurrent access to the shared `TNaming_Scope` instance memory-safe, but left the underlying
design bug in place: every `Document` still shared the *same* `TNaming_Scope`, so one document's
valid-label set could leak into another's regardless of locking — a correctness bug, not just a
race, that predates #361's fix.

**Fix:** `TNaming_Scope` moved from a shared process-wide static to a field on `OCCTDocument`
itself (`doc->namingScope`, `OCCTBridge_Internal.h`). No lock needed at all — two threads working
on two different `Document` instances no longer touch anything shared. `docNamingScopeMutex()` was
removed entirely; the six `OCCTDocumentNamingScope*` bridge functions now read/write
`doc->namingScope` directly (two of the six, `OCCTDocumentNamingScopeClear`/`ValidCount`, gained a
null-check on `doc` they'd never had — a symptom of the same bug, since the old implementation
ignored the `doc` parameter entirely and touched the shared global instead).

New test `namingScopesAreIsolatedAcrossDocuments` in `Issue361SharedSingletonThreadSafetyTests`
directly verifies the correctness property (two documents' valid-label sets and counts stay
independent) — a deterministic, single-threaded assertion, not a race-dependent exerciser. Full
`swift test` (4427 tests) clean, both source and `OCCTSWIFT_BRIDGE_PREBUILT=1` build paths.

`Font_FontMgr`'s font-list cache (`fontListMutex()`, also from #361) is unaffected — that mutex
stays, since the system font registry is genuinely one process-wide resource by OCCT's own design,
unlike `TNaming_Scope`. See `docs/thread-safety.md`'s updated section for the general lesson this
draws: a mutex is the right tool only when state is *meant* to be shared; when it was wrongly made
global in the first place, the fix is relocating ownership, not locking access to the wrong owner.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed again,
so `Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged
(still v1.15.11).

Filed as a companion to [#363](https://github.com/SecondMouseAU/OCCTSwift/issues/363), which also
tracks applying the same per-instance-override redesign to #341's upstream `AutoNamingScope` PR —
that part is deliberately deferred: prototype + test locally first, then respond to the OCCT#1388
review and update that PR, not the other way around.

### v1.15.13 (July 2026) — fix (bridge): two more unsynchronized process-global singletons — TNaming_Scope shared instance, Font_FontMgr font-list cache (#361)

Found continuing the #342 (bridge-level thread-handling contract) scoping pass that produced #359 —
an earlier survey flagged two `needs-investigation` spots as high-confidence pattern matches for the
#341/#344/#353 shape; verified both directly this release before fixing.

- **`getDocNamingScope()`** (`OCCTBridge_Document.mm`) returns one process-wide `TNaming_Scope`
  instance shared across every `OCCTDocument`. Construction is safe (C++11 magic statics), but
  `TNaming_Scope`'s own `NCollection_Map<TDF_Label> myValid` has no internal synchronization —
  two threads calling `namingScopeValid`/`IsValid`/`ValidChildren`/`Unvalid`/`ClearValid`/
  `ValidCount` on two *unrelated* documents race on that shared map.
- **`Font_FontMgr`'s font-list cache** (`OCCTBridge_Visualization.mm`): `g_fontList`/
  `g_fontListPopulated` is a classic unsynchronized check-then-act lazy-init, and the public
  `OCCTFontMgrInitDatabase()` can reassign both at any time from any thread, racing an
  in-progress iteration in any of the read-side functions.

**Fix:** bridge-only, matching the established #341/#344/#353 pattern — a dedicated
`std::mutex` per shared resource (`docNamingScopeMutex()`, `fontListMutex()`), held for the
duration of every access. No OCCT kernel change needed since both races are in bridge-owned
static state, not inside OCCT's own classes. New regression suite
`Issue361SharedSingletonThreadSafetyTests` (`Tests/OCCTThreadTests/`) — a basic exerciser, not the
authoritative verification, same honesty caveat as #341/#359's equivalent suites. Full `swift test`
(4426 tests) clean, both source and `OCCTSWIFT_BRIDGE_PREBUILT=1` build paths.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed again,
so `Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged
(still v1.15.11, no kernel patch this release).

### v1.15.12 (July 2026) — fix (bridge): STEP import + 3 later-added STEP writers missing the DE mutex — #181-B's fix didn't fully hold (#359)

Found while scoping #342 (bridge-level thread-handling contract). #181-B (fixed by PR #184) found
that `STEPControl`/`STEPCAFControl`/`IGESControl` readers and writers share OCCT's process-global
`Interface_Static` parameter table, and serialized every STEP/IGES *writer* entry point on a shared
`igesMutex()` — the closing comment claimed this "serializes *all* of them." Auditing every function
in `OCCTBridge_IO.mm`/`OCCTBridge_Document.mm` that constructs a `STEPControl_Reader`/`Writer` or
`STEPCAFControl_Reader`/`Writer`, or calls `Interface_Static::Set*` directly, found that claim didn't
hold: **18 functions were missing `igesMutex()`** — every STEP import function (all added after PR
#184, across the "v0.58.0 STEP Full Coverage" and "v0.168.0 Progress" batches; the original #181-B
report was specifically about concurrent writes, so import was never in scope), plus 3 STEP export
functions added after PR #184 shipped (`OCCTExportSTEPWithName`, `OCCTExportSTEPWithModeProgress`,
`OCCTDocumentWriteSTEPWithModes`).

**Fix:** added `igesMutex()` to all 18 sites, matching the existing `#181-B` convention. Bridge-only,
no kernel change, no `OCCT.xcframework` rebuild. New regression suite
`Issue359STEPThreadSafetyTests` (`Tests/OCCTThreadTests/`) exercises concurrent STEP import/export
through the Swift API — like #341's equivalent suite, this is a basic exerciser (confirms no deadlock
and no round-trip regression), not the authoritative verification; a missing-lock bug on a
non-recursive `std::mutex` doesn't reliably manifest as an observable Swift-level failure at modest
concurrency. Full `swift test` (4424 tests) clean, both source and `OCCTSWIFT_BRIDGE_PREBUILT=1`
build paths.

Not the same issue as #280 (constructing a `STEPCAFControl_Reader` poisons subsequent STEP writes) —
confirmed during triage that #280 is a different, already-fixed mechanism (not `Interface_Static`-
related, resolved via a kernel patch in v1.10.1).

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift`'s URL/checksum are bumped to this release; consumers building with
`OCCTSWIFT_BRIDGE_PREBUILT=1` need the new release asset. `OCCT.xcframework` is unchanged (still
v1.15.11, no kernel patch this release).

### v1.15.11 (July 2026) — fix (kernel): CDM_Application::myMetaDataLookUpTable + CDM_MetaData field races under concurrent document save/close (#353)

Surfaced while validating the #349 fix: post-#349 TSan runs consistently produced one different,
previously-masked race — the "fixing one race exposes the next" pattern from #341→#344→#349
continuing. `CDM_Application::myMetaDataLookUpTable` is shared process-wide (one `CDM_Application`
singleton, since #344) with zero synchronization: `CDM_MetaData::LookUp()`'s map mutation,
`CDM_Document::SetMetaData()`'s whole-table iteration on every save, and each `CDM_MetaData`'s own
`myIsRetrieved`/`myDocument` fields all race independently. TSan confirmed the exact trace from the
issue: `SetMetaData()` reading `IsRetrieved()` racing a *different* document's destructor tearing
down its own metadata entry on another thread — 1 confirmed race + SIGABRT (exit 134) on stock
#349-fixed kernel.

**Fix:** `CDM_Application` gets a `mutable std::mutex` guarding the lookup table, threaded through
`CDM_MetaData::LookUp()` and `CDM_Document::SetMetaData()`'s iteration; `CDM_MetaData` gets its own
private mutex guarding `myIsRetrieved`/`myDocument`, independent of the table lock. TSan: 1 race +
SIGABRT → 0 races, clean exit, across 5 runs. `swift test --filter OCAFSaveLoadBinaryTests`/
`OCCTXCAFTests` and 3× full `swift test` (4423 tests) all clean. `CDM_MetaData::myDocumentVersion`
has the identical unguarded-field shape but on the reference-resolution path, not TSan-observed —
flagged as a plausible sibling, not fixed here. See
[`Scripts/repro/353-cdm-metadata-lookup-table/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/353-cdm-metadata-lookup-table)
for the reproducer and full writeup. Filed upstream as
[Open-Cascade-SAS/OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) /
[OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) (fix, CI green on all platforms).

### v1.15.10 (July 2026): ThreadSanitizer gate for concurrency-touching changes (docs/tooling)

Docs-and-tooling release; no API, bridge, or kernel changes, and no new binary assets (the
`OCCT.xcframework.zip` binary target continued to resolve from the v1.15.9 release until v1.15.11
above).

Formalizes the TSan protocol that found and validated #298/#341/#344/#349 as a routine gate
(#355, plus the #356 sysroot fix):

- `Scripts/tsan-stress.sh`: `build` produces a minimal-module ThreadSanitizer OCCT (all carried
  patches applied) into `Libraries/occt-install-tsan`; `run` compiles the `Scripts/repro/` stress
  harnesses and executes a 7-scenario gate matrix that must be race-clean; `swift` runs
  `swift test --sanitize=thread` on the concurrency-focused suites (wrapper-only coverage).
- `Scripts/tsan.supp`: curated suppressions; only confirmed-benign races or filed-and-open kernel
  findings, each with an issue link and a removal condition. The #353 entry was removed in
  v1.15.11 once that kernel patch landed.
- `docs/thread-safety.md`: new "ThreadSanitizer gate" section defining when the gate is required
  (new concurrent bridge paths, newly parallel-wrapped subsystems, mutex removals, new
  thread-safety kernel patches) and the rule that new concurrent usage patterns add a scenario.
- Verified end-to-end: gate green (7/7 scenarios, zero unsuppressed races) against the patched
  `V8_0_0_p1` kernel.

Context: upstream OCCT CI runs no sanitizers, so races this gate does not catch are caught by
nobody. See the ecosystem report `docs/occt-kernel-bug-deep-dive-2026-07.md` (SecondMouseAU/ecosystem#23).

### v1.15.9 (July 2026) — fix (kernel): PCDM_StorageDriver/PCDM_Reader driver-instance reentrancy SIGSEGV under concurrent Save/SaveAs of the same format (#349)

`CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache one storage/retrieval driver instance
per document format and hand the same cached instance back to every subsequent `Store()`/
`Retrieve()` call for that format — including from different threads, different documents,
concurrently. Found while validating the #344 fix. `PCDM_StorageDriver`/`PCDM_Reader` subclasses
(`BinLDrivers_DocumentStorageDriver` et al.) are not reentrant: `Write()`/`Read()` mutate
instance-level scratch state (`myRelocTable`, `myTypesMap`, and others) with no synchronization,
so two threads calling `Write()` on the same cached instance corrupt it — a reliably reproducible
SIGSEGV (`BinMDF_ADriverTable::AssignIds` on a torn `myTypesMap`), confirmed by TSan (136 race
warnings + crash on stock kernel). Structural, not BinLDrivers-specific — `XmlLDrivers`,
`BinXCAFDrivers`/`XmlXCAFDrivers`, and `TObj` drivers all share the same base classes and pattern.

**Fix:** `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` guarding their own
`Write()`/`Read()`, held at the three call sites (`CDF_StoreList::Store`,
`CDF_Application::Retrieve`, `CDF_Application::Read`) that invoke a cached, possibly-shared driver
— every format driver subclass inherits the guard for free. TSan: 136 races + SIGSEGV → 0 races,
clean exit. The interim bridge-side mitigation (`ocafStoreMutex()`, shipped v1.15.6) stays in
place, same PR1→PR2 pattern as #298/#341/#344. See
[`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy)
for the reproducer and full writeup. Filed upstream as
[Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) /
[OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms).

A separate, previously-masked race surfaced during validation of this fix
(`CDM_Application::myMetaDataLookUpTable`, unsynchronized) — out of scope for #349, filed as
[#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353).

### v1.15.8 (July 2026) — fix (kernel): ShapeUpgrade_UnifySameDomain unguarded null-pcurve dereference SIGSEGV on mesh-sewn solids (#348)

`UnifySameDomainBuilder.build()` SIGSEGV'd (Address 0, uncatchable in-process) on a real
mesh-sewn solid — found via OCCTReconstruct#194, minimized to a standalone, deterministic
OCCTSwift-only reproducer (just load a BREP, run the builder). Root cause:
`ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (and its file-local `SplitWire` helper)
disambiguate between multiple candidate next-edges at a branching vertex by comparing each
candidate's pcurve tangent direction on the current reference face; three call sites in
`IntUnifyFaces` and a structurally identical pair in `SplitWire` fetch that pcurve via
`BRep_Tool::CurveOnSurface(...)` and dereference it immediately (`->D1(...)`/`->Value(...)`)
with no `IsNull()` check — unlike every other `CurveOnSurface` call site in the same file, which
do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the
given face, routine for a raw mesh-sewn solid (`BRepBuilderAPI_Sewing` from an STL/mesh import)
at a vertex shared by more than two edges. Confirmed via a debug (`-g -O0`) single-TU
override-link + `lldb bt`: resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003`
(`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`. **Fixed** (kernel
patch `Scripts/patches/0013-*`, xcframework rebuilt): all five sites guard with `IsNull()`,
following the file's own established pattern — a missing pcurve on a candidate edge means "skip
it, not a rankable direction"; a missing pcurve on the current edge falls back to treating all
candidates as equally likely, same as the existing single-candidate shortcut. New regression test
`Tests/OCCTStressTests/StressNullInvalidTests.swift`'s
`unifySameDomainOnMeshSewnSolidWithMissingPCurve`. Reproducer at
[`Scripts/repro/348-unify-null-pcurve`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve);
filed upstream as [OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) /
[OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix). #348.

### v1.15.7 (July 2026) — fix (bridge): 49 unguarded gp_Dir/Geom_Direction constructions — the likely #345 SIGABRT (#345)

**#345's companion crash to #344**, root-caused via an audit rather than direct reproduction:
#345 was filed with essentially no evidence (`exited with unexpected signal code 6`, no test
name, no backtrace). OCCT's `gp_Dir` and `Geom_Direction` constructors throw
`Standard_ConstructionError` for a zero-length (or near-zero) direction/normal vector. **49 public
bridge functions** across 7 files constructed these directly from caller-supplied doubles (or
called a `D0`/`D1`/`D2` derivative evaluator, or a `GeomEval_*Surface` constructor — same
degenerate-input throw risk) with no try/catch anywhere in the call chain — e.g. `OCCTSurfaceD1`/
`OCCTSurfaceD2` had none, immediately next to `OCCTSurfaceGetNormal`, which already did. An
uncaught C++ exception crossing the bridge boundary into Swift-generated call frames is a
guaranteed `std::terminate()` → `abort()` (SIGABRT), leaving almost no diagnostic trail — matching
#345's profile exactly.

**Fix**: wrapped all 49 functions in `try { ... } catch (...) { <safe fallback> }`, matching each
file's existing idiom. The 3 functions returning a `_Nonnull` pointer
(`OCCTAxis1PlacementCreate`/`OCCTAxis2PlacementCreate`/`OCCTOBBCreate`) fall back to a valid default
axis rather than `nullptr`, since returning null from a `_Nonnull` contract would just relocate the
crash. Two confirmed false positives left untouched: `computePlaneForPoints` and `buildTrsf3D`
(two separately-defined `static` helpers) are both already protected by a `try` in their sole
caller.

**Validation**: 70 additional full-suite `swift test` runs (4419-4422 tests each, ~309,540
individual test executions) — zero crashes of any kind. New regression tests
(`Tests/OCCTStressTests/StressNullInvalidTests.swift`): `mirrorAxisZeroDirection`,
`mirrorPlaneZeroNormal`, `geomDirectionZeroVector`.

Bridge-only fix — no OCCT kernel change, no `OCCT.xcframework` rebuild (the prebuilt
`OCCTBridge.xcframework` opt-in artifact is rebuilt). Not an OCCT bug, so nothing filed upstream.
#345's own bar for confident closure was "100+ runs with no recurrence" — 70 clean runs plus a fix
matching the exact crash mechanism is short of that literal bar but the strongest evidence gathered
to date. #345.

### v1.15.6 (July 2026) — fix (kernel): XCAFApp_Application::GetApplication/CDF_Directory races — the SIGSEGV #341 didn't explain (#344)

**The uncatchable SIGSEGV that survived the #341 fix.** #341 (v1.15.5) fixed a real
`XCAFDoc_ShapeTool::theAutoNaming` race, but flagged a separate empirical SIGSEGV (garbage fault
address, right after two concurrent OBJ imports) as unconfirmed — filed as #344. Re-running the
parallel `swift test` stress loop 12× against v1.15.5 hit it again once: confirmed genuinely
independent of #341's fix.

**Root cause: two races in code the #341 TSan stress never reached.** That harness builds
`TDocStd_Document` directly (`new TDocStd_Document("BinXCAF")`), bypassing
`XCAFApp_Application`/`CDF_Application` entirely — but every real bridge call
(`OCCTDocumentLoadOBJ` and every other document-producing function) goes through
`XCAFApp_Application::GetApplication()->NewDocument(...)`.

1. `XCAFApp_Application::GetApplication()`'s lazy singleton init is a textbook
   double-checked-locking-without-locking bug — two threads' first concurrent call can both
   construct a new instance and race to assign the shared handle. TSan shows this is the dominant
   defect: it produces multiple concurrently-constructed `XCAFApp_Application` instances, cascading
   into races across dozens of unrelated destructors as the "losing" instances are torn down
   mid-flight.
2. `CDF_Directory::Add`/`Remove`/`Contains` mutate/read `myDocuments` (a plain `NCollection_List`)
   with zero synchronization — every `CDF_Application` is normally one process-wide instance shared
   by every caller, so its one `CDF_Directory` races on `NCollection_BaseList::PAppend` from every
   document-creating call on every thread.

**Fix**, `Scripts/patches/0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch`:
`GetApplication()` folds construction into the static local's initializer (C++11 magic statics,
thread-safe exactly once, replacing the separate `IsNull()`-guarded assignment); `CDF_Directory`
gets a private `std::mutex` guarding `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`.

**Validation:** a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` signal handler
(`backtrace_symbols_fd`) crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds on
stock p1, both captured backtraces resolving to `TDocStd_Application::NewDocument ->
CDF_Application::Open`. TSan (same minimal-module protocol as #298/#319/#341) goes from 234 race
reports to 9 — all directly in `CDF_Directory::Add`/`PAppend` and all showing the *same* mutex held
on both sides of the reported conflict, consistent with a TSan/allocator-recycling artifact rather
than a genuine unaddressed race (a control program with a trivially-correct mutex pattern shows no
such warning under identical flags). The entire `GetApplication()`-driven destructor cascade —
dozens of unique signatures pre-fix — is gone entirely. New regression test
`parallelDocumentCreate` (`OCCTStressTests`, `StressConcurrentDocumentCreationTests`) exercises
`Document.create()` from 40 concurrent tasks.

**Found during validation of the fix above**: correctly making `GetApplication()` a true singleton
means every caller now genuinely shares ONE `TDocStd_Application` instance — surfacing more races
on that instance's *other* unsynchronized state, previously masked by threads sometimes getting
different (uncontended) instances. Repeated `swift test` runs hit a SIGTRAP in
`Resource_Manager::SetResource` (via `TDocStd_Application::DefineFormat`, called by the common
`Document.defineAllFormats()` test-setup path) and a SIGSEGV in `TDocStd_Application::
ReadingFormats` iterating `CDF_Application::myReaders` concurrently with a writer.
`TDocStd_Application::Resources()` has the identical lazy-init bug as `GetApplication()`;
`Resource_Manager`'s maps and `CDF_Application::myReaders`/`myWriters` have zero synchronization.
Also fixed in the same patch: a mutex for `Resources()`'s lazy-init, a `std::recursive_mutex` for
`Resource_Manager`'s accessors (with an explicit copy constructor — the new mutex broke
`ShapeProcess_Context.cxx`'s existing `new Resource_Manager(*sRC)` thread-safety workaround, whose
own comment already acknowledged this exact defect), and a mutex for `myReaders`/`myWriters`. 0/12
further `swift test` runs of `OCCTXCAFTests` reproduce either crash after the fix.

A third, architecturally different crash surfaced in the same validation
(`BinLDrivers_DocumentStorageDriver::Write` corrupting a shared, cached, non-reentrant
storage-driver instance under concurrent `Save`/`SaveAs` of the same format) — a shared worker
object, not a container needing a lock, so the kernel fix needs its own dedicated investigation;
filed separately as #349. It was severe enough alone (~60% crash rate in `OCCTXCAFTests` once the
two races above stopped masking it) that this release also ships an **interim bridge-side
mitigation**: `ocafStoreMutex()` (`OCCTBridge_Document.mm`) serializes
`OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF` — the same #298/#341
bridge-mutex-now/kernel-fix-later pattern. 0/12 further `swift test` runs of `OCCTXCAFTests` crash
after this mitigation.

Reproducer at [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory); filed upstream as
[Open-Cascade-SAS/OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) /
[OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits). #344.

### v1.15.5 (July 2026) — fix (kernel): XCAFDoc_ShapeTool::theAutoNaming race, replacing v1.15.4's bridge mitigation (#341)

**Follow-up to v1.15.4.** That release shipped an immediate bridge-side mitigation (`meshCafMutex()`)
for the `XCAFDoc_ShapeTool::theAutoNaming` race characterized in #341. This release carries the real
kernel fix and removes the bridge lock as redundant — the #298 PR1→PR2 pattern.

**The full hazard, on closer inspection, was bigger than v1.15.4's writeup captured.** Auditing every
internal caller of `theAutoNaming` turned up two more independent save/modify/restore sites beyond
`RWMesh_CafReader::fillDocument()`: a *separate*, near-duplicate override in
`RWGltf_CafReader::fillDocument()` (not a call into the base class's version — glTF import has its
own copy of the same unsynchronized dance), and `XCAFDoc_Editor::Expand()`, which additionally
recurses into itself while the dance is in flight. Verifying the bridge mutex fix under TSan (with
the mutex removed, to test the kernel in isolation) also surfaced a second, narrower problem the
v1.15.4 characterization missed: even with the three save/restore sites serialized against each
other, an *unscoped* `XCAFDoc_ShapeTool::AddShape` call (e.g. any export building a document from an
existing shape, outside all three sites) still reads the raw `bool` with no synchronization at all —
a genuine data race independent of the "logical" interleaving bug.

**Fix, both layers**, in `Scripts/patches/0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch`:

1. `XCAFDoc_ShapeTool::AutoNamingScope` — a new RAII helper backed by a `std::recursive_mutex` held
   for its entire lifetime (not just around the individual get/set calls), so overlapping
   save/modify/restore sequences from any of the three sites serialize correctly instead of
   interleaving (recursive because `Expand()` reenters it on the same thread). All three sites now
   use it; `Expand()`'s two duplicate manual-restore-before-return call sites collapse into one
   destructor-driven restore that fires on every exit path.
2. `theAutoNaming` itself is now `std::atomic<bool>` instead of a plain `bool`, so every access
   anywhere in the file — including `AddShape`'s internal read — is well-defined, closing the
   residual gap the mutex alone doesn't reach. Not a semantic change: `SetAutoNaming`/`AutoNaming`
   remain a single global setting, exactly as documented; an unscoped reader still sees "whatever
   mode is currently active," it just now gets a real, non-torn value instead of undefined behavior.

**Verification.** The same TSan stress (10 threads × 200 concurrent OBJ round-trips, each its own
file) reports **zero** `theAutoNaming` races across 4 separate runs, down from 9-17/run before the
fix — verified with the bridge-side `meshCafMutex()` mitigation removed, testing the kernel fix in
isolation. Zero regression on the `create_fillet_boolean` (#298) and independent-meshing scenarios.
`RWGltf_CafReader`'s copy of the fix compiles cleanly and is mechanically identical to the
`RWMesh_CafReader` path that was exercised, but wasn't run under TSan directly — this repo's
minimal-module TSan build excludes `TKDEGLTF` (needs RapidJSON, disabled for build speed).

**Binary release** — both `OCCT.xcframework` (kernel patch, all 3 core slices rebuilt) and
`OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339; `meshCafMutex()` removed) changed, so
`Package.swift` picks up new URLs + checksums for both.

Filed upstream as [Open-Cascade-SAS/OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387)
(repro, filed alongside v1.15.4) / [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388)
(fix, draft PR, CLA-covered fork).

### v1.15.4 (July 2026) — fix: concurrent OBJ/glTF/PLY import races on an unsynchronized OCCT global; the long-claimed "NCollection race" doesn't hold up (#341)

**Background.** `CLAUDE.md`'s Known OCCT Bugs and this changelog have carried a "pre-existing
non-deterministic NCollection arm64 race under parallel execution" claim since ~v0.51.0, backing a
`swift test --no-parallel` recommendation and three permanently-`.disabled()` suites in
`Tests/OCCTStressTests/StressConcurrencyTests.swift`. The claim was never reproduced, root-caused, or
filed anywhere — it had been riding purely on observed flakes. Filed and investigated as #341
(companion #342), from an OCCTReconstruct test-contention audit that found the same doctrine costing
real CI time downstream (OCCTReconstruct#175/#309).

**Investigation.** Applied the #298 TSan protocol: a minimal-module ThreadSanitizer build of
V8_0_0_p1 (+ all 10 carried patches) covering `FoundationClasses`+`ModelingData`+
`ModelingAlgorithms`+`DataExchange`. Concurrent create/fuse/fillet and independent meshing scenarios
are clean except the already-known, benign `BOPAlgo_InitMessages` lazy-init race (see the #298 entry
below). **No NCollection race reproduced at any tested scale.** Re-enabled the three long-disabled
stress suites — 25/25 clean runs across repeated iterations — and removed their unevidenced
`.disabled()` claims permanently.

**What was actually found.** A concurrent OBJ round-trip scenario (each thread its own uniquely-named
file, so not a file-path collision) reported 9-17 ThreadSanitizer races per run, all resolving to one
root cause: `RWMesh_CafReader::fillDocument()` (the shared base of `RWObj_CafReader` and
`RWGltf_CafReader` — reachable via OBJ **and** glTF import, and PLY export via `AddShape`)
saves/mutates/restores `XCAFDoc_ShapeTool::theAutoNaming` — a process-global `static bool` — with
zero synchronization; `XCAFDoc_ShapeTool::AddShape` reads the same flag. Same failure class as #298
(an unsynchronized save/modify/restore dance on shared global state), but cosmetic (wrong
auto-naming) rather than geometric. Minimal C++ reproducer, methodology, and full writeup:
[`Scripts/repro/341-meshcaf/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/341-meshcaf).

**Fix.** Bridge-only mitigation (matches the #298 PR1 pattern — no kernel patch or `OCCT.xcframework`
rebuild needed for this release): every OBJ/glTF/PLY CAF-reader/writer bridge function now serializes
on a dedicated `meshCafMutex()` (`OCCTBridge_IO.mm`). Not yet filed upstream. New regression suite
`Issue341MeshCafThreadSafetyTests` (`OCCTThreadTests`) exercises concurrent OBJ round-trips through
the Swift API — documented honestly as a basic exerciser, not a reliable reproducer at this scale (the
race needs sanitizer instrumentation or a much larger operation count to surface without one).

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift` picks up the new URL + checksum; `OCCT.xcframework` is unchanged. Consumers building
`OCCTBridge` from source (the default) get the fix by pulling this tag; consumers on
`OCCTSWIFT_BRIDGE_PREBUILT=1` need the new release asset.

**Still open, filed separately.** Two hard crashes (SIGSEGV/SIGABRT, garbage-looking fault addresses)
were observed empirically in ~2 of 20 full-suite parallel `swift test` runs during this
investigation. Filed as #344 (SIGSEGV, right after two concurrent OBJ imports — possibly the same
`theAutoNaming` race in a rarer timing window that produces heap corruption instead of just wrong
naming, unconfirmed) and #345 (SIGABRT, essentially no localizing evidence). **Correction**: this
entry originally attributed the SIGABRT to a `BinTools`/`TopTools` "File was not written with this
version of the topology" message seen nearby in the log, and floated fixed-temp-file-path collisions
as a working theory. Both were wrong — that message is routine, expected output from two intentional
negative tests (`Tests/OCCTIOTests/OCCTIOTests.swift`'s `BREPStringSerializationTests`, exercising
`Shape.fromBREPString` on malformed input) and appears in every run including clean ones; it has no
connection to either crash, and the fixed-temp-file-path theory was speculation based on that false
premise. #342 (bridge-level thread-handling contract: per-call safety classification,
scoped/controllable internal parallelism) remains open and gets a concrete first classified entry
from this investigation — OBJ/glTF/PLY CAF operations are `exclusive` (need `meshCafMutex()`).

### v1.15.3 (July 2026) — chore: opt-in prebuilt `OCCTBridge.xcframework`, skip compiling the 62K-line Obj-C++ bridge per consumer rebuild (#339)

**Problem, from an OCCTReconstruct build-time audit (OCCTReconstruct#309):** `OCCTBridge` is 16
Objective-C++ files / ~62K lines, each including a large slice of OCCT's ~1,700 headers. SwiftPM
recompiles all 16 from source on every consumer of OCCTSwift — measured at 51.6s wall / 186.5s CPU
per rebuild in one path-dependency consumer worktree, on top of the ecosystem's [shared-xcframework
setup](../docs/guides/sharing-the-xcframework.md). A cold artifact re-extraction compounds this by
re-stamping header mtimes and invalidating every consumer's clang module cache.

**Fix.** `Scripts/build-occtbridge.sh` compiles the bridge once per platform slice (same core slices
as `OCCT.xcframework`: macOS, iOS device, iOS simulator) and packages it as `OCCTBridge.xcframework`
— compiled objects + public header, no OCCT source involved. Set **`OCCTSWIFT_BRIDGE_PREBUILT=1`**
to have `Package.swift` link this prebuilt binary (local copy if present, else the matching release
asset) instead of compiling `Sources/OCCTBridge/src/*.mm` from source.

**Default is unchanged (source build).** Every release edits the bridge source directly and tests
against those edits (see `CLAUDE.md`'s Release Process); a prebuilt binary that silently doesn't
reflect fresh edits would be a correctness trap. The prebuilt path is strictly opt-in — full details,
including the local escape hatch for bridge iteration and visionOS/tvOS (not covered by the core
prebuilt slices), in [docs/guides/prebuilt-bridge.md](../docs/guides/prebuilt-bridge.md).

**Verification.** Both paths built clean and the full test suite passed against each: the default
source build (regression check, unchanged behavior) and `OCCTSWIFT_BRIDGE_PREBUILT=1` (55/55 tests
in `OCCTThreadTests` exercising real boolean/fillet/mesh operations through the prebuilt binary,
confirming it's not just a link-success check).

**Binary release** — `OCCTBridge.xcframework.zip` ships as a new release asset alongside the
existing `OCCT.xcframework.zip`; `Package.swift`'s `occtBridgeTarget` URL + checksum point at it.

### v1.15.2 (July 2026): docs + tests — chaining `*WithFullHistory` ops across a `BRepGraph`, retract the #336 "absorbs zero records" report (#336)

**Not a bug — investigated and retracted.** #336 reported that a second `*WithFullHistory` boolean op
chained onto a prior op's live output absorbed zero history records into `add(_:absorbing:inputRoots:
operationName:)`. Verified two independent ways: probing the raw `ShapeHistoryRef` directly against the
first op's output faces (bypassing the graph and `CollectHistoryInputs`/`Absorb` entirely) showed the
same zero records, and `out1.volume == out2.volume` confirmed the second cut changed nothing
geometrically. **Root cause: the reporter's tool placement, not the absorb path.**
`Shape.box(width:height:depth:)` is centered at the origin (documented on the API itself), not
corner-anchored like raw OCCT's `BRepPrimAPI_MakeBox(w,h,d)`. The repro's first "corner" tool landed
fully *inside* the box (an interior-cavity cut) and its second "opposite corner" tool landed entirely
*outside* the box's actual bounds — the two shapes' bounding boxes don't even overlap — so the second
cut was a genuine geometric no-op. Zero absorbed records was the correct answer.

**Real gap found and closed: test coverage.** No existing test chained two `*WithFullHistory` ops
end-to-end (second op fed from the first op's live, `Compound`-wrapped output) or passed a non-root
`NodeRef` as `inputRoots` — every `GraphHistoryAbsorbTests` case only did a single hop rooted at the
graph's own top-level node. New `Issue336ChainedHistoryTests` (`OCCTBRepGraphTests`) covers both: a
genuine two-hop chain (opposite real corners) absorbing records at each hop, and a permanent regression
guard for the reporter's exact non-intersecting geometry asserting the zero-record result stays correct.

- **Docs:** `docs/reference/BRepGraph-Detail-History.md` gains a "Chaining multiple operations" section
  with a runnable multi-hop snippet and the box-centering gotcha, right where `add(_:absorbing:...)` is
  documented.
- Docs only, no code or binary change — reuses the v1.15.1 xcframework (the binaryTarget URL is
  unchanged).

### v1.15.1 (July 2026) — fix: `isSelfIntersecting(hardTimeout:)` can now actually interrupt a stuck self-interference search (#319)

**Root cause — two compounding defects** in `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (`BOPAlgo_CheckerSI::CheckFaceSelfIntersection` → `IntTools_FaceFace::Perform` → `Intf_Interference::Insert`), found while independently verifying a reproducer contributed against [OCCTReconstruct#295](https://github.com/SecondMouseAU/OCCTReconstruct/issues/295): a pathological artifact ran 619s+ of CPU against a 30s `hardTimeout:` deadline and never returned.

1. `Intf_Interference::Insert` compares points between the new tangent zone and every existing zone via `Intf_TangentZone::GetPoint(Index)`, called inside a doubly-nested loop. `GetPoint` indexes the zone's backing `NCollection_Sequence` — a linked list with no O(1) random access — so each call walks from the nearest end. Profiling (independently reproduced) attributed ~80% of leaf samples to `NCollection_BaseSequence::Find`. The artifact produces an unboundedly growing *number* of distinct tangent zones, not one giant merging zone, so this alone doesn't bound wall-clock time — it just makes the per-comparison cost O(1) instead of O(n).
2. The self-interference phase never polled its cooperative progress indicator anywhere *inside* a single face's check — only between whole-face checks, which is not where the artifact gets stuck.

**Fix — both layers.** `Intf_TangentZone::Points()` builds and caches a true `NCollection_Array1` per zone in one linear pass on first use (invalidated by any mutation); `Insert()` indexes through it instead of calling `GetPoint` in the nested loop. `Intf_Interference::SetBreaker` (thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll a `Message_ProgressScope` every 256 calls and abort by throwing `Standard_Failure`, unwinding the `IntTools_FaceFace`/`Intf_Interference` call stack safely; `BOPAlgo_CheckerSI`'s self-intersect functor wires this up around `IntTools_FaceFace::Perform`, gated on `!myRunParallel` — an exception from an `OSD_Parallel::For` worker thread would risk `std::terminate()`, so the checkpoint is only active single-threaded. Kernel patch carried as `Scripts/patches/0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319.patch`, xcframework rebuilt.

**Verification.** On the linked artifact, a 0.5s deadline now returns in 0.547s and a 30s deadline in 30.1s (vs. 619s+ CPU / never returning on stock p1), correct `HasFaulty()` results at every deadline tested (0.5s/1s/2s/3s/5s/30s), clean across a 10x repeated-run stress test. Zero regression on clean, overlapping, and grid self-intersection sanity cases (byte-identical output). An empty-zone edge case in `Points()` is guarded explicitly (`NCollection_Array1::Resize(1, 0, false)` throws `Standard_RangeError` for an empty range) — caught by a dedicated GTest before it could reach a real caller. New upstream GTests `Intf_TangentZone_Test.cxx`/`Intf_Interference_Test.cxx` pass on Linux/Windows/macOS in OCCT's own CI. Reproducer committed at [`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection). Upstreamed as [Open-Cascade-SAS/OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (repro) / [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (fix — full CI green on the first submission across clang-format, ASCII check, all 3 platform builds, and GTest); the carried patch retires once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for #319; `Scripts/patches/README.md` and `okf/references/carried-occt-patches.md` document patch `0010`.

### v1.15.0 (July 2026) — `TopologyGraph` renamed to `BRepGraph` (closes #333)

**MINOR — additive; old name still works.** `TopologyGraph` read as too close to OCCT's own `TopoDS_*`
family (`TopoDS_Shape`, `TopoDS_Face`, ...) on a skim, without signaling that it specifically wraps the
BRepGraph durable-identity engine. Renamed to `BRepGraph`, matching both the C++ package it wraps and
this file's own name (`BRepGraph.swift`).

```swift
@available(*, deprecated, renamed: "BRepGraph")
public typealias TopologyGraph = BRepGraph
```

Existing code compiles unchanged (with a deprecation warning) under the old name. New code should use
`BRepGraph`. The typealias stays until a later release drops it per the usual deprecation policy — no
removal date set yet.

Docs move alongside the rename: `docs/reference/TopologyGraph*.md` → `BRepGraph*.md`,
`docs/guides/cookbook/topology-graph*.md` → `brep-graph*.md`. The `Tests/OCCTTopologyGraphTests` target
is renamed to `Tests/OCCTBRepGraphTests` (internal only, no consumer-visible effect).

### v1.14.0 (July 2026) — feat: `*WithFullHistory` parity for translate/rotate/scale/mirror/patterns (#331)

Extends the #290 `ShapeHistoryRef`/`add(_:absorbing:)` pattern — already shipped for booleans, fillet/
chamfer/shell/defeature (#165), and sew/quilt/heal (#327, v1.13.0) — to the last gap: transforms and
patterns. Consumers doing incremental persistent-identity tracking (OCCTMCP #91/#93) previously had to
fall back to a generation reset after any of these ops, losing continuity for `GraphUID`s minted before
the transform.

**New, all returning `(result: Shape, history: ShapeHistoryRef)`:**

- `Shape.translatedWithFullHistory(by:)`
- `Shape.rotatedWithFullHistory(axis:angle:)`
- `Shape.scaledWithFullHistory(by:)`
- `Shape.mirroredWithFullHistory(planeNormal:planeOrigin:)`
- `Shape.linearPatternWithFullHistory(direction:spacing:count:)`
- `Shape.circularPatternWithFullHistory(axisPoint:axisDirection:count:angle:)`

```swift
let hole = Shape.cylinder(radius: 3, height: 10)!
let (row, history) = hole.linearPatternWithFullHistory(direction: SIMD3(20, 0, 0), spacing: 20, count: 5)!
let copies = history.record(of: someHoleFace).modified   // 5 corresponding instance faces
graph.add(row, absorbing: history, inputRoots: [root], operationName: "linearPattern")
```

**Implementation — two different shapes, unlike the #327 batch:**

- **translate/rotate/scale/mirror** all bottom out in `BRepBuilderAPI_Transform`, which (unlike
  sewing/healing) genuinely derives from `BRepBuilderAPI_MakeShape` — so these reuse the existing
  `OCCTBooleanHistoryAsBRepToolsHistory` retained-builder/args synthesis path unchanged, the same one
  fillet/chamfer/defeature use. The plain (non-history) transform functions already construct
  `BRepBuilderAPI_Transform` with `theCopyGeom = true`, which forces
  `BRepBuilderAPI_Transform::Perform` down its `myUseModif = true` branch unconditionally (confirmed in
  `BRepBuilderAPI_Transform.cxx`) — so `Modified()`/`Generated()` always come from the real
  `BRepTools_Modifier`, never the "same TShape, just relocated" short-circuit that would otherwise
  report nothing.
- **Patterns are N:1**, not 1:1, so the single-builder synthesis path doesn't apply: each pattern
  instance is an independent `BRepBuilderAPI_Transform` run against the same source shape. History is
  built manually — one shared `BRepTools_History`, with every instance's `Modified`/`Generated` results
  for each *original* source sub-shape folded in via `AddModified`/`AddGenerated` (confirmed these
  append rather than replace, in `BRepTools_History.hxx`) — so a source sub-shape's history record
  reports all `count` corresponding instance sub-shapes, one per copy including the identity-transformed
  original at index 0.

New suite `TransformPatternFullHistoryTests` (`OCCTModelingTests`), 10 tests, including two graph-absorb
integration tests (one 1:1 transform, one N:1 pattern) proving both history shapes flow through
`OCCTBRepGraphAddWithHistory` correctly, and two zero-length-direction regression tests for the
exception-safety fix caught in review (`gp_Vec::Normalize`/`gp_Dir`'s constructor throw on a zero
vector; the pattern wrappers now guard that inside their own try/catch instead of leaving it to the
caller). No kernel change, no xcframework rebuild — reuses the v1.12.9 binary.

### v1.13.1 (July 2026) — feat: hard-bounded `isSelfIntersecting`, TSan-verified (#319)

Follow-up to #293 (closed, doc-only fix): `isSelfIntersecting(timeout:)` is cooperative — it can only
return once OCCT polls, and `BOPAlgo_ArgumentAnalyzer`'s self-interference phase has at least one long
checkpoint-free stretch (`Intf_Interference::Insert`). #319 tracked two tracks; only Track 1 ships here.

**New: `Shape.isSelfIntersecting(hardTimeout:)`** — a genuinely hard wall-clock bound. Runs the check
on a detached background thread against a `deepCopy()` (independent geometry, the standard pattern for
concurrent OCCT work), and waits on the calling thread with a real `DispatchSemaphore` deadline. If the
deadline passes first, returns `nil` immediately and the background computation is **abandoned, not
cancelled** — it keeps running orphaned until it eventually completes (burned CPU traded for a
caller-side guarantee, the same trade the #286 mesher-hang caller made). Additive: `timeout:` is
unchanged, and the two overload labels (`timeout:` / `hardTimeout:`) disambiguate cleanly.

**Prerequisite work, not skipped:** the reason this wasn't done alongside the v1.12.5 doc fix was an
open question — is `BOPAlgo_ArgumentAnalyzer` safe to run on a worker thread concurrently with
unrelated OCCT calls on other threads? That shape of concurrency (not OCCT's own internal
`SetRunParallel`, and not this project's usual "independent shapes on independent threads" pattern
either, since the *caller* keeps running) had no precedent in this codebase. Investigated with the same
method that found #298's fillet race: a minimal OCCT build (`FoundationClasses` + `ModelingData` +
`ModelingAlgorithms` only) with `-fsanitize=thread`, then a stress harness — 60 bursts × 8 threads, half
running self-intersection checks on independent self-intersecting compounds (36 overlapping boxes,
genuine interference so `Intf_Interference::Insert` does real work), half running unrelated
fuse+mesh work concurrently on independent shapes. 480 operations, zero TSan race reports, zero
wrong-but-plausible results. That's a positive signal on one stress shape and one access pattern, not
an exhaustive audit — the doc comment says so explicitly, and `isSelfIntersecting(timeout:)` stays the
default recommendation unless a caller genuinely needs the hard guarantee.

**Track 2 (upstream OCCT report: missing checkpoints + the `Intf_Interference::Insert` quadratic)
remains blocked** — still needs the minimal, un-thrashed reproducer this issue originally hoped would
fall out of a quiet-host OCCTReconstruct #208 re-run. That hasn't happened: #208 itself is closed
(2026-07-18, no linked commit — superseded by a re-scoped successor line, not resolved), and neither
it nor its successors (#252, #254, the currently-open #292) touch self-intersection or timeouts at
all. No reproducer exists anywhere in that repo as of this release. No action taken on Track 2.

New suite `Issue319HardBoundedSelfIntersection` (`OCCTModelingTests`), 3 tests. No kernel change, no
xcframework rebuild — reuses the v1.12.9 binary.

### v1.13.0 (July 2026) — feat: `*WithFullHistory` for sewing, quilting, and healing (#327)

`add(_:absorbing:inputRoots:operationName:)` (#290) solved "an operation rebuilt the shape, keep my
selection" for booleans and Tier 2 modification ops — but only when the operation hands back a
`ShapeHistoryRef`, and the operations at the heart of a mesh-to-B-Rep pipeline (sew → heal → solid)
returned a bare `Shape?` with nothing to absorb.

**New, all returning `(result: Shape, history: ShapeHistoryRef)`:**

- `Shape.sewWithFullHistory(shapes:tolerance:)`, `.sewnWithFullHistory(with:tolerance:)`,
  `.sewnWithFullHistory(tolerance:)` (self-sew)
- `Shape.quiltWithFullHistory(_:)`
- `Shape.healedWithFullHistory()`
- `Shape.solidWithFullHistory(from:)`

```swift
let (shell, history) = Shape.sewWithFullHistory(shapes: faces, tolerance: 1e-6)!
let record = history.record(of: someInputFace)   // .modified / .generated / .isDeleted
graph.add(shell, absorbing: history, inputRoots: [root], operationName: "sew")
```

**Implementation:** none of these algorithms derive from `BRepBuilderAPI_MakeShape`, so the existing
`OCCTBooleanHistoryAsBRepToolsHistory` template-synthesis path (built for booleans/fillet/chamfer/
thick-solid) doesn't apply directly. `OCCTBooleanHistory` (the opaque handle behind `ShapeHistoryRef`)
now optionally carries an already-built `Handle(BRepTools_History)` instead of a retained builder:

- **Sewing** (`sew`/`sewn` both directions) — `BRepBuilderAPI_Sewing` always allocates its own
  `BRepTools_ReShape` context (confirmed in `occt-src`) and records every vertex/edge merge and
  small-face removal into it via `Replace()`/`Remove()` during `Perform()`, so
  `GetContext()->History()` is complete and native — no manual walk needed.
- **Healing** (`healed`) — `ShapeFix_Shape::Init` auto-creates its `ShapeBuild_ReShape` context, so
  `Context()->History()` is likewise safe and complete without an explicit `SetContext()` call.
- **Solid from shell** (`solid(from:)`) — the one case that's the mirror image: `BRepBuilderAPI_MakeSolid`
  genuinely fits the template-synthesis path, but wrapping an already-closed shell into a solid doesn't
  modify any sub-shape, so that path would report nothing. The real history source is the
  `ShapeFix_Solid` orientation-fix pass — and unlike `ShapeFix_Shape`, `ShapeFix_Solid::Init` does
  **not** auto-create a context (verified in `occt-src`), so the bridge now calls
  `SetContext(new ShapeBuild_ReShape)` explicitly before `Perform()`.
- **Quilting** — `BRepTools_Quilt` has no `ReShape` context and no `Modified`/`Generated`/`IsDeleted`,
  only single-shape `IsCopied()`/`Copy()`, so this is the one manual per-subshape walk in the group.

**Faithfulness question answered:** the issue asked whether sewing's many-to-one merges (two coincident
input edges becoming one output edge — the *normal* case for sewing, not an edge case) are represented
cleanly. Confirmed by reading `BRepBuilderAPI_Sewing`'s vertex-merge code directly, and by a regression
test: **both merged inputs are recorded as Modified into the same output edge** — neither side is
silently dropped or marked Removed. `Shape.isSame(as:)` verifies the two records' outputs are the
identical edge.

**Not implemented: `Mesh.toShapeWithFullHistory`.** The issue's own open question floated this as a
possible answer, and it's the right one: `Mesh.toShape` builds every face from scratch out of raw
vertex/index arrays — there is no input `TopoDS_Shape` for `ShapeHistoryRef.record(of:)` to be called
with in the first place, so a `*WithFullHistory` variant would be a hollow stub that always returns
empty records. Identity for a mesh-to-B-Rep pipeline has to be established *after* the mesh-to-shape
step, not carried through it.

New suite `SewQuiltHealFullHistoryTests` (`OCCTModelingTests`), 9 tests. No kernel change, no
xcframework rebuild — reuses the v1.12.9 binary.

### v1.12.10 (July 2026): docs, BREP graph durable identity and UIDs cookbook

Docs only, no code change. Reuses the v1.12.9 binary (the binaryTarget URL is unchanged). Adds a new
cookbook, `docs/guides/cookbook/topology-graph-uids.md`, covering how UIDs are managed in the BREP
graph: the three durable-ID flavours (`GraphUID` / `GraphRefUID` / `GraphItemUID`), minting and
resolving, the one-graph-instance scope rule and `instanceID` / `graphID` provenance (#295), what
preserves identity (`copy` / `translated` / `compact`) versus mints a new one (`copyFace` / rebuild),
the deprecated always-1 `generation` counter, persistence, and how UIDs relate to history absorb
(#290). Cross-linked with the existing Topology Graph cookbook.

### v1.12.9 (July 2026) — carry three more upstream OCCT crash/hang fixes (#323)

**Not a bug we hit — a proactive audit.** Unlike #310/#317/#318, these three weren't discovered via
an OCCTSwift crash: #323 audited every OCCT PR merged or opened since our `V8_0_0_p1` baseline and
identified crash/hang fixes in code paths OCCTSwift exercises, per the `upstream-fixes-first` policy.
A fourth candidate from the same audit, OCCT#1380 (`ShapeFix_Face::FixPeriodicDegenerated`), turned
out to already be covered — it's our own patch `0005`, shipped for #317.

**`Scripts/patches/0007`** backports open (third-party) [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331), fixing [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330): `ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` (the same helper `0004` patches for #310) left a stale `lwire` index when a skipped-loop candidate wire turned out to have zero edges — e.g. a wire wrapping a single internal-orientation edge — so the outer loop's `lwire == -1` termination check never fired and it read invalid memory. Validated by translating the upstream TCL test to C++: a closed triangle wire plus one internal-orientation edge SIGSEGVs 100% of the time on stock p1 + patches `0001`–`0006`, returns a valid wire after the patch.

**`Scripts/patches/0008`** backports merged [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329), fixing [OCCT#1288](https://github.com/Open-Cascade-SAS/OCCT/issues/1288) ("Boolean operation 'section' hangs-up for a pair of cylindrical shapes"): `Geom_BSplineCurve::PeriodicNormalization` used an O(N) `while`-loop to bring an out-of-range parameter into a periodic curve's range — a genuine infinite loop once the parameter's magnitude vastly exceeds the period (`Parameter -= Period` becomes a floating-point no-op). Rewritten to O(1). Validated: `PeriodicNormalization(1e17)` on a normal periodic curve (period ≈ 6.12) hangs indefinitely on stock p1 (wall-clock timeout) and returns instantly after the patch; a 9-case sanity sweep of in-range/near-boundary/several-periods-off values is byte-identical before and after.

**`Scripts/patches/0009`** backports open (maintainer) [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318): `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-character line buffer — no amount of flushing ever made room for text that can't fit in a full, empty line either. Fixed by splitting the token across as many lines as needed. Validated: a 200-character unbroken name via the public `StartEntity`/`SendString` path hangs indefinitely on stock p1 and returns instantly after the patch, correctly split across continuation lines with the text intact; normal-length fields are byte-identical before and after. New regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`), reachable directly from `Shape.writeSTEP(to:name:)` with a >72-char name.

All three (and the existing `0001`–`0006`) verified via the fast override-link technique (patched `.o` linked ahead of `libOCCT-macos.a`, no full rebuild needed for validation) before committing to the xcframework rebuild. Two of the three are open, third-party or maintainer PRs — pinned to a specific commit SHA in each patch's header; re-verify if the PR changes in review before the next repin. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for `0007`–`0009`; `Scripts/patches/README.md` and `okf/references/carried-occt-patches.md` document all three.

### v1.12.8 (July 2026) — fix: `Shape.analyze(tolerance:)` no longer crashes on a degenerate curve-on-surface edge (#318)

**Root cause.** `BRepGProp_EdgeTool::IntegrationOrder` — invoked from `BRepGProp::LinearProperties`, which backs `Shape.analyze(tolerance:)`'s small-edge scan — reads an edge's pole count to pick a numeric-integration order. For a Bezier/BSpline-type curve, it correctly identifies the type via `BAC.GetType()` (a `BRepAdaptor_Curve`, whose `GeomAdaptor_TransformedCurve::GetType()` override correctly handles the curve-on-surface case), but then re-derives the pole count by hand via a completely different, non-virtual path: `BAC.Curve().Curve()`, down-cast to `Geom_BezierCurve`/`Geom_BSplineCurve`. `BAC.Curve()` returns the base `GeomAdaptor_Curve` sub-object, which holds the 3D-curve representation only — never `Load()`ed when the edge has no 3D curve (only a curve-on-surface pcurve), so the handle is null, the down-cast returns null, and `->NbPoles()` dereferences it. This is exactly the shape of a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright — surfaced sewing two real mesh-derived planar candidate faces (`kof_ii_engine_cover.stl`, regions 10 + 64) via a diagnostic dump added to OCCTReconstruct's plane-select spike, then isolated with a custom `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox) that pinned the crash to `IntegrationOrder`. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace — the mechanism doesn't depend on the specific fixture.

**Fix — both layers.** Bridge (`OCCTShapeAnalyze`'s small-edge scan) now skips degenerate edges outright — closes the crash immediately, on any xcframework, and is also a correctness fix: a degenerate edge's zero 3D extent isn't a "small edge" defect to flag. Kernel patch also carried (`Scripts/patches/0006-BRepGProp_EdgeTool-use-adaptor-NbPoles-curve-on-surface-318.patch`, xcframework rebuilt): `IntegrationOrder` now calls the adaptor's own, correctly-dispatching `BAC.NbPoles()` (`GeomAdaptor_TransformedCurve` already has this override right next to `GetType()`) instead of manually re-deriving the pole count — no behaviour change for edges that do have a 3D curve.

**Verification.** The real sewn fixture and the synthetic degenerate edge both SIGSEGV 100% of the time on stock p1 and complete cleanly after the patch. New regression test `Issue318DegenerateCurveOnSurfaceEdgeTests` (`OCCTShapeHealingTests`), embedding the real sewn shape as a BREP fixture. Upstreamed as [Open-Cascade-SAS/OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381) (repro) / [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382) (fix, with a GTest); the carried patch retires once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for #318; `Scripts/patches/README.md` documents patch `0006`.

### v1.12.7 (July 2026) — fix: `Shape.face(from:boundary:)` no longer crashes on a single closed wire belting a cone (#317)

**Root cause.** `ShapeFix_Face::FixPeriodicDegenerated()` — invoked whenever a face's sole boundary wire is a single closed edge belting a `Geom_ConicalSurface`'s full 2π period, apex outside the wire's V range (a rivet/boss-rim seam fit as one periodic curve is the common source) — builds a degenerate apex edge and finalizes with an unconditional `Context()->Replace(myFace, myResult)`. Every *other* `Context()->Replace` call site in that OCCT source file — eleven of them — guards a null `Context()` first; this one didn't. `Context()` is left null by `ShapeFix_Root`'s base constructor and set only by an explicit `SetContext()` call, which the ordinary `ShapeFix_Face fixer(face); fixer.Perform();` (including ours, before this release) never makes — so any caller healing this exact wire shape null-derefs. Diagnosed with a custom `backtrace_symbols_fd` `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox) pinpointing the crash to `FixPeriodicDegenerated`; `-O0` single-TU override-link tracing confirmed every prior statement in the function completes and the fault is specifically that call. A standalone `wireFromEdges`-only repro is negative — the crash needs the wire trimmed to a periodic surface via `face(from:boundary:)`, which the original title's suspicion of `Wire.wireFromEdges` itself never exercised.

**Fix — both layers.** Bridge (`OCCTShapeCreateFaceFromSurfaceWire[WithHoles]`, `OCCTFaceFixerCreate`) now calls `fixer.SetContext(new ShapeBuild_ReShape)` before `Perform()` — closes the crash immediately, on any xcframework. Kernel patch also carried (`Scripts/patches/0005-ShapeFix_Face-guard-null-context-FixPeriodicDegenerated-317.patch`, xcframework rebuilt): restores the same `if (!Context().IsNull())` guard used at every other call site in the file.

**Verification.** A synthetic 8-point closed periodic curve edge trimmed to a cone, healed with a bare `ShapeFix_Face`, SIGSEGVs 100% of the time on stock p1 and survives (valid healed face) after the patch; a 10-point curve fit through real mesh-derived rivet-rim points (the fixture this was originally surfaced from, `railsim_581_lead.stl`) behaves identically. New regression test `Issue317PeriodicConicalSingleWireTests` (`OCCTSurfaceTests`). Upstreamed as [Open-Cascade-SAS/OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378) (repro) / [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380) (fix, with a GTest); the carried patch retires once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for #317; `Scripts/patches/README.md` documents patch `0005`.

### v1.12.6 (July 2026) — fix: `ShapeAnalysis_FreeBounds` no longer crashes on disjoint free-boundary components (#310)

**The real fix lands in the kernel.** v1.12.5 documented the crash risk in `freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires` (and, it turns out, `freeBounds` too — same underlying constructor) because no reliable guard existed at the wrapper level. This release removes the risk entirely.

**Root cause (found with AddressSanitizer).** `ShapeAnalysis_FreeBounds::SplitWire` finds each wire's closed sub-loops, then hands whatever edges weren't consumed to `ConnectEdgesToWires` to chain into the "open" result. When a wire's edges are **entirely** consumed by closed-loop detection, that hand-off is an empty (but non-null) sequence. The call chain `ConnectEdgesToWires` → `ConnectWiresToWires` → `connectWiresToWiresImpl` starts with `if (iwires.IsNull() || !iwires->Length()) { return; }` — for empty input this returns **without ever assigning its `owires` out-parameter**. Every caller in the file starts from a freshly-defaulted (null) handle, so the null propagates back through `SplitWire`'s `open` parameter into `ShapeAnalysis_FreeBounds::SplitWires`'s `open->Append(tmpopen)`, dereferencing a null handle — an uncatchable SIGSEGV. Not a data-volume threshold: it depends only on whether *any* single free-boundary component happens to close with nothing left over, so a shape with 150+ loops can be fine while a 2-loop shape crashes (and vice versa) — which is exactly why the #310 report's own minimization (150-face fixture, sew ladder) came up empty while the real trigger, one call later in the pipeline, was easy to hit.

**Fix.** `Scripts/patches/0004-ShapeAnalysis_FreeBounds-init-owires-empty-input-310.patch`: the one-line contract restoration `connectWiresToWiresImpl`'s own non-empty path already follows a few lines down (`owires = new NCollection_HSequence<TopoDS_Shape>;` before populating it) — "nothing to connect" now produces a valid **empty** result instead of an untouched out-parameter. The xcframework was rebuilt with the patch.

**Verification.** AddressSanitizer (macOS arm64, `ModelingAlgorithms`+`ModelingData`+`FoundationClasses`, `RelWithDebInfo`, `MMGT_OPT=0`): two disjoint planar faces in one compound crashed 100% of the time on stock p1 — same function, same `NCollection_Sequence::Append` call, same `0xfffffffffffffff8` fault address at both `-O2` and `-O0` — and now returns the correct `2 closed, 0 open`. On the real #310 fixture (150-face analytic compound): `tol=0.05` gives `152 closed/0 open` byte-identical before and after (no behavior change on the working path); `tol=0.10` crashed on stock p1 and now returns `144 closed/0 open`. New regression test `issue310DisjointFacesFreeBounds` (`OCCTShapeHealingTests`). Upstreamed as [Open-Cascade-SAS/OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377) (with a GTest), superseding the repro-only [OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376); the carried patch is retired once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** removed the now-obsolete "can crash" warnings from `freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires` (doc comments + `docs/reference/Document-Analysis-Builders.md`); `CLAUDE.md`'s Known OCCT Bugs entry updated to record the fix.

### v1.12.5 (July 2026) — docs: correct #310's crash diagnosis + `isSelfIntersecting(timeout:)` cooperative-bound wording (#310, #293)

**PATCH — docs only, no code change.** #310 reported `Shape.sew`/`.healed()`/`.fixed(tolerance:)`
SIGSEGV-ing on a loose analytic-face compound, reproducing in a full pipeline but not via a standalone
BREP replay. Investigation found the original diagnosis was off on two points, and root-caused the
real defect:

- **Not `Shape.sew`/`.healed()`/`.fixed()`.** The crash is one call later: `Shape.freeBoundsClosedWires`/
  `freeBoundsClosedCount` (`ShapeAnalysis_FreeBounds`), called by the reporting pipeline immediately
  after a successful `sew` to print the free-boundary loop count. It only *looked* like the next `sew`
  call because that's the next thing that runs.
- **Not process-state-dependent.** The standalone probe that failed to reproduce it never called
  `freeBoundsClosedWires`/`freeBoundsClosedCount` — it only replayed `sew`/`healed`/`fixed`, so it never
  exercised the crashing function. Confirmed in pure C++ (no OCCTSwift) against the exact committed
  fixture, and reduced further to two disjoint planar faces in one compound with no shared geometry at
  all — not data-volume-dependent either (a shape with 150+ free-boundary loops can be fine while a
  2-loop shape crashes).
- **Root cause** (via a `-O0` single-TU override-link of `ShapeAnalysis_FreeBounds.cxx`, same technique
  as #263): the uncatchable SIGSEGV is inside `NCollection_HSequence<TopoDS_Shape>::Append`, called
  from `SplitWires`'s per-wire result accumulation, with a valid (non-null) target handle — consistent
  with heap corruption originating earlier in the same function rather than a null-handle deref at the
  `Append` site. Not covered by the #298 fillet patch (checked: neither the sew/heal/fix path nor
  `ShapeAnalysis_FreeBounds` reference `TopOpeBRepBuild`/`BlendFunc`), and not a concurrency bug (the
  reporting ladder is single-threaded).

**Fix.** No wrapper-side guard is possible yet — there's no reliable predicate distinguishing safe
input from crashing input, so a defensive check would either miss the real trigger or reject valid
shapes. Documented the crash risk on `freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`
(doc comments + `docs/reference/Document-Analysis-Builders.md` + `CLAUDE.md`'s Known OCCT Bugs list).
Filed upstream as [Open-Cascade-SAS/OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376)
with both a minimal 2-face repro and the real-fixture repro; possibly related to the still-open
[OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330) (a different function in the same
file, same "re-chaining free-boundary components" symptom family).

**Also in this release (#293) — `isSelfIntersecting(timeout:)`'s bound is cooperative, not a hard
deadline.** `Shape.isSelfIntersecting(timeout:)` documented its `timeout` as a wall-clock bound, but
the mechanism (`OCCTBoolTimeoutBreaker`, a `Message_ProgressIndicator` whose `UserBreak()` trips past
the deadline) can only fire when the running OCCT algorithm *polls* — `BOPAlgo_ArgumentAnalyzer`'s
self-interference phase has at least one long checkpoint-free stretch (observed 20+ minutes past a
30s bound on a pathological B-spline solid), during which the calling thread is blocked inside the
call with no way to return early. The boolean ops' own timeout (#206) is unaffected — their polled
path is verified to interrupt correctly; this is specific to the self-interference check. Corrected
the doc comment (`Shape.swift`), `docs/reference/Shape-Features.md`, and
`docs/guides/cookbook/healing-and-validity.md` to state the bound is cooperative and can overrun
arbitrarily in an un-polled phase, with process-level isolation as the only true hard bound. No API
or behavior change.

### v1.12.4 (July 2026) — fix: `drilled` honours its direction; `face(outer:holes:)` respects hole winding; docs audit made type-aware

Two behaviour bugfixes and a documentation-coverage pass. No public API change (derived operation count unchanged at 4,241).

**`drilled(at:direction:radius:depth:)` now bores along `direction` (#272).** The bridge built the drill cutter via a +Z-hardcoded cylinder (`OCCTShapeCreateCylinderAt`), so drilling along any non-Z axis silently bored straight up Z — often removing nothing when the repositioned base fell outside the shape. It now uses `OCCTShapeCreateCylinderOriented`, whose `gp_Ax2(entryPoint, direction)` orients the bore along the requested (normalized) axis; a zero-length direction returns `nil`.

**`face(outer:holes:)` no longer double-flips an already-opposite hole (#274).** Every hole wire was reversed unconditionally before `BRepBuilderAPI_MakeFace.Add` — but `Add` does not normalise hole orientation, so a hole passed already wound opposite the outer (the correct winding) was flipped back to *wrong*, yielding an invalid face or an added-instead-of-subtracted hole. Reversal is now conditional: the outer's plane is found, an arc-aware signed area decides each wire's winding, and a hole is reversed only when it winds the *same* way as the outer. Per-hole, so mixed-winding hole sets work too; falls back to the legacy reverse when no plane can be determined.

**`Scripts/count-operations.py --audit` is now type-aware (#294).** The old matcher compared a counted entry point's bare name against doc headings with no notion of the owning type, so it over-reported generic names (`get`, `cols`, `z`, …) that *were* documented, and missed multi-symbol headings (`` ### `isCylinder`, `isCone`, `isSphere` ``) entirely — capturing only the first name. Of the 37 it flagged, **26 were false positives**; the matcher now carries a `Type.name` identity on both sides and parses multi-span headings. The **11 genuine gaps** (oriented bounding box, `OSD_Environment` accessors, and `LocalizedError.errorDescription` on seven error enums) are now documented — `--audit` reports **0**.

### v1.12.3 (July 2026) — fix: concurrent fillet/chamfer fixed in the kernel; serialization lock removed (#298)

**The real fix for #298 lands in the pinned OCCT, and the interim bridge lock is gone — concurrent fillet/chamfer run in parallel again.** v1.12.1 stopped the corruption by serialising every 3D fillet/chamfer build behind a bridge mutex (`occtFilletMutex`); that was correct but cost the parallelism. This release fixes the root cause in the kernel and drops the lock.

**Root cause (found with ThreadSanitizer).** `BRepFilletAPI_MakeFillet` reconstructs its result solid through OCCT's legacy `TopOpeBRepBuild` boolean engine (`ChFi3d_Builder::Compute` → `TopOpeBRepBuild_HBuilder::MergeSolid` → `TopOpeBRepBuild_Builder::SplitSolid`), which passed state between methods through a file-scope `static`, `STATIC_SOLIDINDEX`: `SplitSolid` sets it to 1/2 to tell `FillSolid` which operand it is splitting, and `FillSolid` reads it back to pick the operand shape. Two fillet builds on independent shapes on separate threads clobbered each other's flag, so `FillSolid` mis-classified faces and returned a wrong-but-plausible solid (one solid, positive volume, fails `BRepCheck`). This is *not* the `BlendFunc` scratch the v1.12.1 notes first suspected — those statics do race, but benignly; `STATIC_SOLIDINDEX` alone accounts for the corruption.

**Fix.** `Scripts/patches/0003-TopOpeBRep-non-reentrant-globals-fillet-298.patch` converts the fillet-path statics to `thread_local` (each thread keeps its own copy; single-thread behaviour is unchanged): `STATIC_SOLIDINDEX` and `STATIC_lastVPind` (functional), plus the `BlendFunc_ConstRad`/`EvolRad` and `ChFi3d_Builder` `checkcurve` scratch (benign, converted so the path is TSan-clean). The xcframework was rebuilt with the patch, so the kernel is reentrant and the `occtFilletMutex` guard (16 bridge call sites) was removed. Upstreamed as [Open-Cascade-SAS/OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374); the carried patch is retired once it ships in the pinned kernel.

**Verification.** Pure-C++ 8-thread stress: 0/1600 concurrent fillet builds invalid with a single correct volume (was ~15–20% corrupt), and ThreadSanitizer reports the fillet path clean. `Issue298FilletThreadSafetyTests` now passes with the lock removed. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

### v1.12.2 (July 2026) — fix: graph construction now runs OCCT's `Clear()` rebuild boundary (#303)

**Every graph OCCTSwift built reported `generation == 0` and an all-zero `GraphGUID`.** The bridge
built a graph with the constructor plus `Shapes().Add(shape)`, and never called `BRepGraph::Clear()`
— which upstream treats as *the* rebuild boundary (PR #1237) and is the only call that stamps a
graph's identity (`IncrementGeneration()` + `SetGraphGUID(random)`). Skipping it left the kernel's
own version-stamp machinery unarmed on our path: `GraphGUID` stayed the default all-zeros, so
`BRepGraph_VersionStamp::ToGUID` — documented as making per-node GUIDs *"globally unique across
different graph instances"* — would have hashed in the zero GUID and returned identical GUIDs for
different graphs. Nothing user-visible broke (none of `GraphGUID` / `StampOf` / `IsStale` / `ToGUID`
is wrapped), but it was a live trap for whoever wraps that surface next.

Surfaced while fixing #295, and verified independent of it: giving graphs real GUIDs does **not** stop
a foreign UID resolving, because `BRepGraph_UID` is `(Kind, Counter)` and carries no GUID for
`NodeIdFrom` to compare. #295's `instanceID` provenance check is still needed and unchanged.

**Fix.** `OCCTBRepGraphCreate` and `OCCTBRepGraphCopyFace` now call `graph.Clear()` before ingesting
the shape, matching upstream's declared lifecycle. `copy()` / `translated()` deliberately do not:
`BRepGraph_Copy`/`_Transform::Perform` transplant the source's whole identity (generation + GUID)
into the target, so a pre-`Clear()` would just be overwritten — the inheritance is what we want.
`copyFace()` does get a `Clear()`: it is a fresh build with counters restarting at 1, and
ground truth on the pinned 8.0.0p1 kernel confirms `CopyNode` does **not** transplant the source
GUID, so the fresh stamp survives and matches the graph's fresh `instanceID`.

**Verified safe first** (the issue's load-bearing unknown): `Clear()` calls
`LayerRegistry::ClearAll()`, which the header documents as clearing layer data *"without
unregistering services"* — so the `BRepGraph_LayerHistory` layer the constructor registers, which
#290's `add(_:absorbing:…)` depends on, survives. Ground-truth-confirmed against the pinned kernel:
after `Clear()`-then-`Add()`, the history layer is still registered and recording works; the #290
history-absorb suite and the #295 provenance suite both stay green.

- **Changed:** `TopologyGraph.generation` is now a constant **1** (was 0). Still deprecated and still
  useless as identity — it is the same 1 for every graph. Use `instanceID` to compare graph identity.

### v1.12.1 (July 2026) — fix: concurrent 3D fillet/chamfer builds no longer corrupt each other (#298)

**Filleting a shape on two threads at once returned wrong-but-plausible geometry.** Reported as
`SheetMetal.Builder.build` returning an invalid solid under parallel test execution (~8 of 10 runs),
but the root cause is upstream and independent of the wrapper. `BRepFilletAPI_MakeFillet`'s
constant- and evolutive-radius blend solvers (`BlendFunc_ConstRad`, `BlendFunc_EvolRad`) and the
shared `ChFi3d_Builder` curve checker keep their geometric work variables in function-local
`static`s — process-global state, "to avoid systematic reallocation". Two threads filleting at once
interleave writes to those statics, the solver converges on a corrupted surface, and the result is a
solid with one shell and a positive volume that nonetheless fails `BRepCheck` — silent bad geometry,
not a crash and not a thrown error.

Reproduced in **pure OCCT with no OCCTSwift code involved**: a fuse-then-fillet on eight threads
produced BRepCheck-invalid solids with volumes scattered across several wrong values, while the same
build on one thread was bit-for-bit deterministic and correct. A plain box fillet (which takes OCCT's
analytic `ChFiKPart` fast path, not the numerical blend) is unaffected; only filleting a boolean
result, which needs the general path, trips it.

The issue's own diagnosis was corrected on three points: the result is *not* an empty shape (so the
suggested "reject empty results" guard would not have caught it), the boolean is *not* implicated
(the fuse is thread-safe and returns the correct shape every time), and it is unrelated to the
NCollection arm64 SEGV.

**Fix.** The bridge now serialises every 3D fillet and chamfer build under a dedicated recursive
mutex (`occtFilletMutex`), distinct from `OCCTSerial`. Fillet/chamfer are now always safe to call
concurrently with no caller-side lock; booleans, meshing, sweeps, and everything else stay fully
parallel — only fillet/chamfer builds serialise against each other. 2D fillets
(`BRepFilletAPI_MakeFillet2d`, the analytic `ChFi2d` toolkit) have no such statics and are not
guarded. Verified: the originally-failing `OCCTMiscTests` target passes 8/8 parallel runs, and a new
`Issue298FilletThreadSafetyTests` regression fails reliably without the lock and passes with it.

This is a mitigation. The permanent fix de-statics the work variables in OCCT itself so the lock can
be dropped and fillet/chamfer become genuinely parallel — tracked as a follow-up `occt-src` patch
and an upstream report. See `docs/thread-safety.md` for the full write-up.

### v1.12.0 (July 2026) — fix: a `GraphUID` no longer resolves against a graph that didn't mint it (#295)

**`node(forUID:)` returned a wrong node instead of `nil` for a UID from an unrelated graph.**
`GraphUID` carried no graph identity: it is a `(kind, counter)` pair, and every `TopologyGraph`
allocates counters from 1 independently. A UID minted from a box therefore landed inside a cylinder
graph's valid counter range and resolved cleanly — to an unrelated face. `contains(uid:)` returned
`true`. No error, no `nil`, just a plausible wrong answer:

```swift
let boxUID = boxGraph.uid(ofNodeKind: 2, index: 2)!   // a face of the BOX
cylGraph.node(forUID: boxUID)     // was: Optional((kind: 2, index: 2))  — now: nil
cylGraph.contains(uid: boxUID)    // was: true                           — now: false
```

The documented safeguard could never have caught it. `generation` is a **constant 0**, and the
staleness recipe the docs gave compared it against `storedOwnGen`, a per-entity mesh field that was
never the same counter.

**Fix.** Every graph carries an `instanceID`, and every UID it mints records it as `graphID`.
`node(forUID:)` / `contains(uid:)` / `ref(forUID:)` / `item(forUID:)` reject a UID from any other
graph. The id follows the same lifecycle rules as OCCT's own graph identity (`GraphGUID`), which
OCCTSwift cannot read because the kernel only populates it in `BRepGraph::Clear()` — a call our build
path skips (see #303).

**Identity follows the kernel's rule** — whether an operation transplants the UID counter space:

| Operation | Identity | UIDs |
|---|---|---|
| `compact()`, node removal, `add(_:absorbing:…)` | same instance | keep resolving |
| `copy()`, `translated()` | inherited | keep resolving, naming the same nodes |
| `copyFace()` | fresh | source UIDs now return `nil` (they returned a **wrong face** before) |
| a new graph over any shape, incl. a rebuild | fresh | source UIDs now return `nil` |

`copy()` and `translated()` are **unaffected**: `BRepGraph_Copy`/`_Transform::Perform` transplant the
counter space, Generation and GraphGUID into the target, so a copy genuinely is the same identity and
every source UID resolves to the same node. Only `copyFace()` — which lifts one face into an empty
graph, restarting counters at 1 — aliased, and it is now rejected.

- **New:** `TopologyGraph.instanceID`; `graphID` on `GraphUID`, `GraphRefUID`, `GraphItemUID`.
- **Deprecated:** `TopologyGraph.generation` — always 0, guards nothing. Also the hand-built
  `GraphUID(kind:counter:)` initializers: a UID with no provenance resolves in no graph, so mint them
  with `uid(ofNodeKind:index:)`.
- **Immutable fields:** `kind` / `counter` / `domain` are now `let`. A mutable counter beside an
  immutable `graphID` let a caller forge provenance — mutate a minted UID's counter and it would
  resolve to an arbitrary node, the exact bug this release closes. Mutating a UID was never coherent
  and no code in the ecosystem did it, but this is technically source-breaking for anyone who did.
- **Persistence:** a UID does not survive a rebuild, and never legitimately did — it only appeared to,
  because rebuilding the same shape re-allocates counters identically, with nothing checking it was
  the same shape. Store `(kind, index)` with the shape and re-mint after rebuilding. This matches
  OCCT's model, where a UID is an anchor into a *persisted graph model*; OCCT does not yet expose a
  graph serializer, and its `GraphGUID` is regenerated on every rebuild by design.
- **Codable:** payloads written before this release have no `graphID` and decode as unstamped
  (`graphID == 0`), which resolves nowhere rather than failing the load.
- **Equality:** `graphID` participates in `Hashable`/`Equatable`, so UIDs from unrelated graphs no
  longer compare equal or collapse together in a `Set`. Within one graph (and across a copy),
  equality is unchanged.

Unchanged: a UID still survives compaction and node removal within its own graph — that is what it is
for, and it is now the property the tests actually check. The previous `foreignUIDDoesNotResolve` test
only fabricated an *out-of-range* counter, which the reverse-index rejected anyway; a genuinely
foreign UID is in-range. Surfaced while investigating #290.
### v1.11.3 (July 2026) — fix: robust importers silently dropped all but the first body (#302)

**A multibody file lost every body after the first.** Ten boxes in, one box out — no error, no
diagnostic, and a perfectly valid solid returned. Found while sweeping the robust import paths for
#300; it is a data-loss defect rather than a progress one, so it was filed and fixed separately.

Every robust importer sewed and then took **the first shell only**:

```cpp
TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
if (shellExp.More()) {                                    // <-- first shell, no loop
    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
    if (makeSolid.IsDone()) resultShape = makeSolid.Solid();
}
```

Measured on a 10-box compound (10 solids, 60 faces), through the public API:

| API | before | after |
|---|---|---|
| `Shape.loadRobust` (STEP) | 1 solid, 6 faces | **10 solids, 60 faces** |
| `Shape.loadSTLRobust` | 1 solid, 12 faces | **10 solids** |
| `Shape.loadWithDiagnostics` | 1 solid, 6 faces | **10 solids**, `solidsCreated == 10` |

The sewing was never at fault — `BRepBuilderAPI_Sewing` returns one shell per body, and the bridge
discarded nine of them. `Shape.load` / `loadSTL` (the plain loaders) were never affected, and
`loadIGESRobust` is not either: the IGES path only transfers and heals, so it has no `MakeSolid`
step to truncate.

**Behaviour change — the return type now follows the file.** A multibody import returns a
**compound of solids**; a single-body import still returns a plain **solid**, exactly as before, so
existing single-body callers are untouched. Callers that handle both must not assume `.solid`.

**`ImportResult.solidsCreated: Int`** (new) reports how many shells became solids, alongside the
existing `solidCreated: Bool`. The count is precisely the fact that was silently wrong.

Shells that `MakeSolid` rejects are now carried through as shells rather than dropped — losing them
quietly is the defect being fixed.

The fix walks a compound's **immediate children** rather than exploring for shells, because an
explorer descends *into* solids: a hollow body owns an outer shell plus one per void, and
solidifying those separately would split one body into two — trading data loss for corruption. A
regression test covers it (a box with an internal spherical void survives with both shells and its
exact volume).

Regression tests assert on **body count**, not validity. That distinction is the point: a truncated
import returned a well-formed solid and `isValid` was true throughout, which is why this shipped
unnoticed. Same lesson as #286/#300 — assert the property that was actually broken.

### v1.11.2 (July 2026) — fix: robust-import healing ran outside the caller's progress range (#300)

**`Shape.loadIGESRobust` now honours a deadline during healing.** The sweep of the remaining
`*Progress` entry points that #299 called for found the #286 *constructor* pattern does not recur —
the other entry points all hand the range to a range-taking method. But it found the same *family* of
defect: `OCCTImportIGESRobustProgress` gave `TransferRoots` the entire `Message_ProgressRange` and
then ran `ShapeFix_Shape::Perform()` with **no range at all**. Healing is not a coda to a robust
import — measured at **38–50%** of transfer+heal across box/sphere/cylinder/torus compounds — so a
caller's deadline could not bound roughly half the call. `shouldCancel()` returning `true` during
healing was ignored entirely: the heal ran to completion and the import returned a **shape** rather
than reporting cancellation.

Fixed with a `Message_ProgressScope` subdividing the range: transfer takes `fraction` 0…0.5, healing
0.5…1.0. **This changes the reported `fraction` curve** — transfer previously spanned 0…1.0 and then
the import paused silently and uncancellably. The even split is what the measurements support, not a
guess; and because the scope closes out on destruction, `fraction` still reaches 1.0. Wiring a live
range into healing costs nothing measurable (−4.7%, i.e. noise, over 3 reps).

`ShapeFix_Shape::Perform(range)` and `BRepBuilderAPI_Sewing::Perform(range)` were both verified to
*honour* the break, not merely poll it — 1.85 s full heal vs 0.005 s cancelled, and a mid-flight
deadline interrupted at 0.478 s against a 0.463 s budget. Since the abort leaves a partially-healed
shape behind, the bridge now reports cancellation rather than handing that back.

The regression test asserts on **elapsed time** with the deadline set *past* the transfer, so it
lands inside healing — the part that was unreachable. Confirmed to fail against the old bridge:
*"loadIGESRobust returned a shape instead of cancelling"*. A cancel triggered on reported `fraction`
would have been a false negative: under the old bridge the transfer alone spanned 0…1.0, so any
fraction-based trigger fired while the transfer was still running and cancelled correctly even with
the bug present.

**`Shape.loadRobust` gains a `progress:` channel** (new API). `OCCTImportSTEPRobustProgress` had the
identical defect, and was fixed identically (transfer/sew/heal, with sewing taking a thin slice of the
repair half since it costs ~1% of what healing does) — but no Swift API reached it: `loadRobust` called
the non-progress bridge variant, so a robust STEP import could not be observed or cancelled **at all**.
It now routes through the progress-capable variant, mirroring its `loadIGESRobust` sibling:

```swift
let shape = try Shape.loadRobust(from: stepURL, progress: Deadline())
```

Source-compatible — `progress` defaults to `nil`, so existing `loadRobust(from:)` call sites are
unaffected. The one visible change is the failure message for the URL overload, which now carries the
full path rather than the last component (it delegates to the path overload, as `loadIGESRobust` does).

Exposing it is also what makes the STEP path **testable**: the new regression test drives it through a
convex N-gon prism, which imports as a single many-faced *solid* and so takes the SOLID branch, where
repair is ~50% of the work. That share is load-bearing — on a *compound* the same import spends only
~6% in repair, so a deadline would land in the transfer, which was already cancellable, and the test
would pass with the bug present. Confirmed to fail against an unfixed repair phase: *"loadRobust
returned a shape instead of cancelling"*.

Also in this release:
- **Docs corrected:** `loadIGESRobust` was documented as "sewing and healing". It has never called
  `BRepBuilderAPI_Sewing` — it only transfers and heals.
- **Documented OCCT limitation:** `IGESControl_Reader::ReadFile` takes no `Message_ProgressRange`
  (verified against the pinned `V8_0_0_p1` headers), so parsing happens *before* the indicator
  exists and can be neither reported nor cancelled. The same is true of `STEPControl_Reader::ReadFile`
  and the STEP/IGES writers. Stated rather than papered over, per the #286 lesson.
- **Redundant `Perform()` dropped** from `OCCTExportSTL`/`OCCTExportSTLWithMode`, whose constructor
  already meshes. Measured as redundant, *not* a 2× cost: 0.0003 s against a 1.29 s mesh.

### v1.11.1 (July 2026) — fix: `meshWithProgress` could never cancel; retract the #286 kernel story (#286)

**`Shape.meshWithProgress` now actually cancels.** The bridge used the
`BRepMesh_IncrementalMesh(shape, linDefl, isRelative, angDefl)` constructor, which calls `Perform()`
*internally* with a null `Message_ProgressRange`. The entire mesh was therefore built uninterruptibly
inside the constructor, before the range we passed to the following `Perform(range)` was ever polled —
and that second call meshed the shape a **second time**. Cancellation still *threw*, because
`UserBreak()` was checked afterwards, so the pre-existing test passed and the defect shipped. Fixed by
using the `IMeshTools_Parameters` + `Message_ProgressRange` constructor, the only one that consumes a
range. Meshing behaviour is otherwise unchanged: both constructors leave
`AngleInterior`/`MinSize`/`DeflectionInterior` at defaults, which `Perform()` resolves identically.

Measured on the #286 face (249 s to mesh in full): a 10 s deadline now throws `ImportError.cancelled`
after 10.1 s, having polled 154,898 times. Previously it ran past 400 s without cancelling.

**v1.10.2's account of #286 was wrong in every substantive claim, and is retracted.** Each was checked
by measuring or building it rather than by reading:

| Claim (v1.10.2) | Measured |
|---|---|
| `Shape.mesh` hangs unboundedly on offset surfaces | **Terminates in 249 s**, `status=0`, 1.4 M triangles. Earlier "hangs" were 120 s / 300 s timeouts set below that. |
| No in-process timeout can bound it — "measured, not inferred" | **A 10 s deadline returns in 10.1 s.** The "10 s cancel never fired" measurement was our own `meshWithProgress` bug, above — not an OCCT limitation. |
| Root cause is `BRepMesh_MeshAlgoFactory::GetAlgo` handing offsets a `BRepMesh_UndefinedRangeSplitter` | **Disproven by building it.** Routing `GeomAbs_OffsetSurface` to `BRepMesh_NURBSRangeSplitter` leaves the runtime identical. `getUndefinedIntervalNb()` is dead code here: `NbUIntervals(CN)` forwards to the basis adaptor and returns **11, not 1**, so the `if (aIntervalsNb == 1)` branch never runs and the two splitters behave identically. (`NbUPoles()` also *throws* `Standard_NoSuchObject` on an offset adaptor, so the proposed one-liner was unsafe regardless.) |
| The hang is in `BRepMesh_Delaun::createTrianglesOnNewVertices` | Stack samples put 100 % of time in `BRepMesh_DelaunayDeflectionControlMeshAlgo::optimizeMesh`. |

**Actual cause — invalid input, not an OCCT defect.** The offset surface is *self-intersecting*.
Offsetting by more than the local radius of curvature produces cusps: the #286 basis fit's minimum
principal curvature radius is `2.6e-05` against an offset of `1.27`, so **23.8 %** of its domain is
cusped and the surface normal swings by up to `π` across one. `BRepMesh` splits any triangle link whose
end normals differ by more than `AngleInterior` (= `2 × angularDeflection`), but at a normal
*discontinuity* splitting never converges — halving a link that straddles a cusp just moves the cusp
into one half. So `optimizeMesh` runs all 11 passes demanding ~80 k splits each, long after linear
deflection is satisfied (1.82 against a 2.48 target by pass 6, with linear splits at **zero** from pass
4); `MinSize` (= `linearDeflection / 10`) is the only backstop, rejecting ~200 k splits per pass.

**No upstream OCCT issue or patch is warranted** — retracting v1.10.2's "an upstream OCCT fix is being
attempted". No xcframework rebuild either: the binary is unchanged. A well-formed offset surface meshes
normally.

`Shape.mesh` and `Shape.meshWithProgress` docs and `docs/reference/Shape.md` rewritten against the
measurements, and the mitigation list now leads with the deadline that actually works. The `bounds`
pre-check remains the best first line of defence, and `isValid` still will not catch this (a
self-intersecting offset surface is a topologically valid face).

### v1.11.0 (July 2026) — feat: absorb a boolean's history into the graph, so a picked face survives it (#290)

Holding a reference to a picked face across an operation that rebuilds the shape had no supported
path. `ShapeHistoryRef` (TopoDS-level, from the `*WithFullHistory` helpers) and the `TopologyGraph`
history log were two disconnected systems: the boolean never wrote a record into the graph's log, so
`resolve(.splitOf(…))` / `.createdBy(…)` / `currentForms(of:)` had nothing to walk and callers were
left correlating `ShapeHistoryRecord.modified` back to graph nodes by hand — in practice by geometry.

OCCT 8.0.0p1 already ships the bridge; it was simply unwrapped.
`BRepGraph::ShapesView::AddWithHistory` collects the input map via `CollectHistoryInputs`, the output
map via `Options::TrackAddedNodes`, and hands both to `BRepGraph_LayerHistory::Absorb`.

**New**

- **`TopologyGraph.add(_:absorbing:inputRoots:operationName:)`** — add an operation's result to the
  graph and absorb its history. Afterwards the entities you already held resolve to their successors.
- **`TopologyGraph.historyIsDeleted(_:)`** / **`.historyDeletedNodes`** — distinguish "consumed by the
  operation" from "never touched". Absence of a record is not deletion.

```swift
let graph = TopologyGraph(shape: base)!
let root = graph.findNode(for: base)!               // topology root — NOT rootNodes (see below)
let topNode = graph.findNode(for: topFace)!         // pin the face BEFORE the cut
let pinned = TopologyGraph.NodeRef(kind: topNode.kind, index: topNode.index)

let (result, history) = base.subtractedWithFullHistory(tool)!
graph.add(result, absorbing: history,
          inputRoots: [TopologyGraph.NodeRef(kind: root.kind, index: root.index)],
          operationName: "channel-cut")

let strips = graph.currentForms(of: pinned).filter { $0.kind == .face }   // the two successors
graph.resolve(.splitOf(original: .literal(pinned), occurrence: 0))        // .success(face)
```

**One graph, not two.** `AddWithHistory` resolves its input roots against the *receiving* graph, so
the input and the result share one graph and history is NodeId-keyed. The `NodeRef`s and `GraphUID`s
a caller already holds stay valid: there is no generation boundary to cross and no cross-graph UID
resolution — which sidesteps the aliasing hazard in
[#295](https://github.com/SecondMouseAU/OCCTSwift/issues/295) entirely. Build the graph from the
operation's **input**, then hand it the result. The two-graph `Absorb` overload and the UID-keyed
record path (`RecordUid` / `HasKnownInput`) are deliberately left unwrapped: strictly more dangerous,
and no consumer.

**Works for all nine `*WithFullHistory` ops.** `OCCTBooleanHistoryAsBRepToolsHistory` synthesizes a
real `BRepTools_History` from the retained builder via the `(arguments, algo)` template constructor,
which needs only `Modified` / `Generated` / `IsDeleted` — all virtual on `BRepBuilderAPI_MakeShape`.
That matters because only the `BRepAlgoAPI_*` builders expose a native `History()`; fillet, chamfer
and thick-solid do not. `OCCTBooleanHistory` now retains its arguments, since a type-erased builder
cannot report its own inputs.

**Known edges, documented rather than papered over:**

- `currentForms(of:)` returns the cut's new section **edges** alongside the split faces, because
  `BRepGraph_LayerHistory::FindDerived` unions Modified and Generated descendants transitively.
  Filter by `.kind` when you want only faces. Existing behaviour, unchanged.
- Only **vertices, edges, faces and solids** are carried — `BRepTools_History::IsSupportedType`
  tracks nothing else, so absorbing records nothing for wires, shells or compounds.
- `TopologyGraph.rootNodes` is **Products**, and shape-built graphs set `CreateAutoProduct = false`,
  so it is always empty for them. The topology root is `findNode(for: inputShape)`. This trips people
  up; the reference page now says so.

### v1.10.3 (July 2026) — docs: canonical operation count, derived not hand-maintained (#289)

The headline operation count was stated in two places with **three numbers in play**: README said
4,313, `docs/API_REFERENCE.md`'s `Total` said 3,431, and that table's own 470 category rows summed to
3,320. Both headline figures were last written in the *same* commit, so at most one was ever right,
and both predated v1.10.0.

**Canonical rule, now written down** (`docs/API_REFERENCE.md` § How operations are counted):

> One row per distinct public Swift entry point; overloads counted separately.

An operation is any `public func`/`static func`, `public init`, `public var` **with an accessor
block**, or `public subscript` in the `OCCTSwift` module. Stored properties, types and enum cases are
data, not entry points, and are not counted. The derived count is **4,234**.

**Derived, not hand-maintained.** `Scripts/count-operations.py` computes it from source and rewrites
both figures (`--fix`), exiting 1 if they disagree — the drift class is now mechanically impossible.
`--audit` lists counted entry points with no reference page.

The 882 gap turned out to be exactly what #289 suspected: **two divergent methodologies.** README's
4,313 was ~the full entry-point surface (80 off today's derived 4,234 — stale, not wrong-in-kind),
while API_REFERENCE's rows are a curated *categorisation* covering 3,320 (~78%) of the surface. The
`Total` and the row sum were never measuring the same thing; the table now says so explicitly rather
than implying the rows should add up.

**Docs coverage audit** (the same pass): 39 counted entry points had no reference documentation. Two
were counted in API_REFERENCE's own example lists while being undocumented — `Shape.commonAll(_:)`
(Booleans) and `hollowed(removingFaces:thickness:tolerance:joinType:)` (Modifications) — both now
documented beside their siblings. The remaining 37 are tracked in #294.

### v1.10.2 (July 2026) — docs: `Shape.mesh` can hang unboundedly on offset surfaces (#286)

> **Retracted by v1.11.1.** Every substantive claim below is false: the mesh is not unbounded (249 s),
> cancellation *does* work (the failed 10 s deadline was our own bridge bug), and the splitter root
> cause was disproven by building the proposed fix. Kept for history; see v1.11.1.

Documentation only; no code change — because there is no correct in-process code change to make, and
saying so precisely is the useful output.

`Shape.mesh(linearDeflection:angularDeflection:)` can put OCCT's mesher into an effectively
non-terminating state on the `Geom_OffsetSurface` geometry that `shelled(thickness:)` / `offset(by:)`
produce. Reproduced standalone from a real fitted-then-offset B-spline panel: a **single face meshed
for >300 s without returning**, at a *coarse* deflection (2.48 against a 1583 bbox diagonal — 1/638).
A kernel pathology, not a workload cost.

**Root cause** (OCCT `V8_0_0_p1`): `BRepMesh_MeshAlgoFactory::GetAlgo` lumps `GeomAbs_OffsetSurface`
in with `GeomAbs_OtherSurface`, handing it a `BRepMesh_UndefinedRangeSplitter` whose
`getUndefinedIntervalNb()` returns a constant `1`. An offset surface therefore gets **no parametric
subdivision at all**, however wiggly its basis B-spline is, while that same B-spline meshed directly
gets `BRepMesh_NURBSRangeSplitter` (`NbUPoles()-1` intervals). The Delaunay insertion starts from a
near-empty grid and `BRepMesh_Delaun::createTrianglesOnNewVertices` blows up.

Two things this is **not**, both worth recording because both were the obvious first guesses:

- **Not fixable with a timeout — measured, not inferred.** `createTrianglesOnNewVertices` *does* poll
  (`aPS.More()`) in its outer per-vertex loop, but the hang is inside a single iteration, so the poll
  is never reached. A 10 s cancel deadline via `meshWithProgress` was measured **not to fire at all**
  (killed at 120 s). `meshWithProgress`'s docs previously implied a cancellation guarantee it cannot
  honour; they now state the checkpoint granularity explicitly.
- **Not catchable by a validity pre-check.** The offending solid reports `isValid == true`.

Mitigations documented on `mesh`, best first: sanity-check with `bounds` (a cheap `Bnd_Box` query, no
tessellation) before meshing untrusted offsets; `withSurfacesAsBSpline(offset: true)`, which converts
the offset surface to a plain B-spline and turns the hang into a bounded 125 s / 526 k verts — this
also explains *why* that mitigation works, since it routes the surface to the correct splitter (a
rescue path, not a default); or mesh out-of-process.

An upstream OCCT fix is being attempted against the root cause; see #286.

Well-formed offset solids are unaffected.

### v1.10.1 (July 2026) — OCCT rebuild carrying the #280 kernel fix; consumer builds are warning-free (#281)

**Rebuilt `OCCT.xcframework`** (all three slices) carrying a new carried patch,
`0002-STEPControl_Writer-initialize-missing-shape-processing-1334.patch` — a backport of upstream
[OCCT#1334](https://github.com/Open-Cascade-SAS/OCCT/pull/1334) (merged 2026-07-10), which lands after
our `V8_0_0_p1` pin (2026-06-16). This fixes [#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280)
**in the kernel**, so the v1.9.2 bridge workaround (`repairSTEPWriterActor`, which installed a plain
controller on each of the 8 shape-level write paths) is **removed** — verified by deleting it and
confirming the regression test still passes against the rebuilt binary.

**Build warnings: 797 → 0** ([#281](https://github.com/SecondMouseAU/OCCTSwift/issues/281)).

- **684 `-Wdeprecated-declarations` → 0.** OCCT 8.0 deprecates its own legacy spellings
  (`Standard_True`, `Standard_Real`, `TopTools_*`, `TColStd_Array1Of*`, …) which this bridge still
  uses. Defining OCCT's own `OCCT_NO_DEPRECATED` opt-out on the `OCCTBridge` target silences exactly
  those attributes and nothing else. Deliberately a `.define` and not `.unsafeFlags` — SwiftPM rejects
  `unsafeFlags` in any package consumed as a dependency, which would break every downstream consumer.
  This buys quiet, not absolution: migrating the call sites off the legacy spellings is still tracked
  in #281.
- **23 `-Wshorten-64-to-32` → 0.** All 23 were the same shape — an `NCollection` container's
  `.Size()` (`size_t`) assigned to `int32_t`/`int`. Now explicit `static_cast`. To be clear, these were
  **not** latent bugs: unlike the `quantize()` Int32 overflow (OCCTSwiftViewport#30), a container with
  >2^31 elements is not reachable here. The casts document intent and stop the noise.
- **Swift hygiene.** Removed four dead bindings in `SheetMetal.swift` (`aOuter1`/`bOuter1`,
  `arcNormalCandidate`, `seamLength`) — each was leftover from a superseded approach that the
  surrounding comments already described, so the stale comments went too; none was an unfinished
  calculation. `Mesh.swift` `var`→`let`. Also fixed two warnings not listed in #281 that a cached build
  had been hiding: a deprecated `String(cString:)` in `BRepGraph.swift` (decoding now stops at the
  bridge's NUL terminator — `String(decoding:as:)` over the whole fixed 128-byte buffer would have
  carried the NUL padding into the string) and a deprecated `union(with:)` in `OCCTTest`.

Full suite: **4,359 tests, 0 failures.** Consumer builds inherit no warnings from this package.

Bumped **PATCH**: no public API change — a kernel rebuild, a workaround removal, and build hygiene.

### v1.10.0 (July 2026) — feat: `allEdgePolylinesIndexed` — bulk wireframe with pick identity (#275 follow-up)

`allEdgePolylines` is dense: when a degenerate/failed edge is skipped (a sphere's pole seams, a
scan's broken edge), every later polyline shifts down, so a polyline's position no longer equals its
edge index — consumers that round-trip wireframe back to topology (per-segment edge pick indices,
polyline → `TopoDS_Edge`) silently mis-map from the first skip onward.

**New:** `Shape.allEdgePolylinesIndexed(deflection:maxPointsPerEdge:) -> [(edgeIndex: Int, points:
[SIMD3<Double>])]` — the same single O(edges) bulk pass (#275), with each polyline carrying its
original `edgePolyline(at:)` / `edge(at:)` index. `allEdgePolylines` now delegates to it (`.map(\.points)`)
— dense output unchanged, byte-identical.

The first consumer is OCCTSwiftTools' `extractEdgePolylines` (the `shapeToBodyAndMetadata` wireframe
pass), whose per-index loop was the O(edges²) hot path that hung OCCTMCP's `render_preview` on
mesh-scale STL imports (OCCTMCP#75).

New test: sphere fixture proves indices survive a real skip (returned pairs match the per-index
accessor exactly; skipped indices are exactly those the per-index accessor rejects).

### v1.9.2 (July 2026) — fix: an XDE STEP read silently corrupted every later STEP write (#280)

Reading a STEP through `Document.loadSTEP` permanently corrupted every subsequent
`Exporter.writeSTEP` in the process. A cone frustum wrote as a **2-face solid missing its lateral
`CONICAL_SURFACE` and 63% of its volume** (408.407 → 151.844), still reporting `isValid == true`.
Read a STEP, write a STEP, geometry silently gone — an ordinary app sequence.

Upstream OCCT bug. `STEPCAFControl_Controller`'s constructor overwrites the actor its base class
just configured, without re-applying `SetShapeProcessFlags`, then `AutoRecord()`s itself under the
same `"STEP"` name the plain writer resolves by — and `STEPControl_Writer::SetWS()` unconditionally
re-runs `SelectNorm("STEP")`. So after any XDE read (a `STEPCAFControl_Reader` merely being
*constructed* is enough) every shape-level write ran with **empty** `OperationsFlags`:
`DirectFaces` never ran, and faces on indirect (left-handed) surfaces — a frustum's cone — were
dropped. That is why only the cone was affected; box/cylinder/sphere/torus have no indirect
surfaces.

Fixed upstream in OCCT PR #1334 (merged 2026-07-10), which added an `InitializeMissingParameters()`
call to `STEPControl_Writer::Transfer`. Our pinned **V8_0_0_p1** (tagged 2026-06-16) predates it —
it *defines* that method but never calls it, and it is `private`. The bridge therefore installs a
freshly-constructed plain controller on each shape-level write, restoring the flags the writer
should have had. Retire the workaround when the bundled OCCT moves past that commit.

This was also the cause of the long-standing `cone()` failure in `StressFormatRoundTripTests`, which
passed in isolation and failed in every full run purely because `OCCTIOTests` reads a STEP first. It
was never flaky — it was correctly reporting this bug. **The full suite is now green: 4,359 tests,
0 failures.**

Bumped **PATCH**: bug fix, no public API change.

### v1.9.1 (July 2026) — fix: a new Document could inherit a dead Document's construction context (#277)

`Document.constructionContext` is resolved through a side table keyed on `ObjectIdentifier(document)`
— the raw instance pointer, which is unique only among **live** objects. The entry was never removed
(a `clear(for:)` existed but was never wired to `Document.deinit`), so a context outlived its
document; the allocator then readily handed the same address to the next `Document`, which resolved
to the dead one's context and silently inherited its entities.

This was not a rare race. In a tight create/destroy loop **every** new `Document` reused the address
and accumulated its predecessors' entities monotonically (1 → 2 → 3 → …). It surfaced as an
intermittent failure in the `materializeAll()` test — 4 entities materialized where 3 were added — but
the same fault hits any app that creates and releases documents over its lifetime: fresh documents
silently carrying dead ones' construction geometry, plus an unbounded leak of every
`ConstructionContext` ever created.

`Document.deinit` now clears the association before the instance's memory can be recycled. No API
change — the documented guarantee (one context per `Document` instance, released with it) is simply
true now. `DocumentAssociatedStorage` carries a warning that owners must clear on `deinit`, since the
pattern silently reintroduces this if they don't.

Bumped **PATCH** per the cohort SemVer policy: bug fix, no public API change.

### v1.9.0 (July 2026) — perf: `allEdgePolylines` is O(edges), not O(edges²) (#275)

`Shape.allEdgePolylines` looped `edgePolyline(at:)`, and every one of those calls rebuilt the shape's
full `TopTools_IndexedMapOfShape` — so extracting a wireframe was quadratic in edge count. Measured on
a box compound: **12,288 edges went from 15.5 s to 0.017 s (~900x)**; 3,072 edges from 0.93 s to
0.004 s. The old cost curve made mesh-scale shapes effectively unusable (an STL lands one face per
facet, so a 442k-triangle scan is ~1.3M edges), which is what forced OCCTMCP to route around the
bridge in v1.13.0 (OCCTMCP#75/#77).

The bridge now discretises every edge in one pass, building the edge map once:

- **New C API** — `OCCTShapeComputeAllEdgePolylines(shape, deflection, maxPointsPerEdge)` returns an
  `OCCTEdgePolylinesRef` handle, read via `OCCTEdgePolylinesGetEdgeCount` / `…GetPointCount` /
  `…CopyPoints` and freed with `OCCTEdgePolylinesRelease`. Edge ordering matches
  `OCCTShapeGetTotalEdgeCount` / `OCCTShapeGetEdgePolyline`; failed/degenerate edges are retained as
  0-point entries so indices stay aligned with the shape's edge indices.
- The pcurve fallback's edge→face ancestor map is now also built at most once per call, instead of
  once per edge that needs it.

**No Swift API change.** `allEdgePolylines`' signature, ordering and skip-on-failure behaviour are
unchanged — output is byte-identical to the old per-index path (covered by a parity test over box and
cylinder), just dramatically faster. `edgePolyline(at:)` is unchanged and still rebuilds the map per
call; it is now documented as one-off-lookup only. Bumped **MINOR** per the cohort SemVer policy: new
C surface, additive.

This fixes the `allEdgePolylines` hot path only — the ~24 other per-index accessors (`edge(at:)`,
face/vertex variants) still rebuild their maps per call. Caching the map on `OCCTShape` with
mutation-invalidation is the structural fix, left open on #275.

### v1.8.8 (July 2026) — feat: close the face-analysis tail (#266 follow-up, 6 ops)

Wraps the five low-value leftovers from the post-v1.8.7 face-gap re-audit — the face surface is now
complete:

- **`BRepLProp_SLProps` V tangent** (`Shape.faceLPropTangentV`) — the tangent plane is now two-sided
  (was `TangentU`-only).
- **`BRepGProp_Face` integration internals** (`Shape`): `faceIntegrationKnotsV`, `faceSurfaceIntegration`
  (precision-driven Gauss order + U/V subinterval counts), `faceBoundaryIntegration(edgeIndex:)`
  (edge-loaded boundary order/subs/knots).
- **`ShapeFix_Face` tolerance clamps** (`FaceFixer`): `setMaxTolerance`, `setMinTolerance`.

Swift-only; no xcframework change. `BRepGProp_Face::GetTKnots` remains deliberately unwrapped
(needs a loaded boundary arc and is subsumed by `faceBoundaryIntegration`).

### v1.8.7 (June 2026) — feat: face healing & validation surface (#266 follow-up)

**New APIs (~16 ops).** Rounds out the face-analysis surface flagged by the coverage audit:

- **`ShapeFix_Face` per-pass control** (`FaceFixer`): `setMode(_:_:)` toggles any of the 11 healing
  passes (wire, orientation, **addNaturalBound**, missingSeam, smallAreaWire, removeSmallAreaFace,
  intersectingWires, loopWires, splitFace, autoCorrectPrecision, periodicDegenerated) before
  `perform()`; plus `fixIntersectingWires()`, `fixPeriodicDegenerated()`, `fixWiresTwoCoincEdges()`,
  `fixLoopWire()`, `result` (Face **or** Shell), and `status(_:)`. Previously `perform()` ran with
  hardcoded defaults — e.g. no way to turn off the natural-bound pass that can balloon a trimmed face.
- **`BRepCheck_Face` per-wire diagnostics** (`Shape`): `checkFaceIntersectingWires`,
  `checkFaceWireImbrication`, `checkFaceWireOrientation` — the specific `BRepCheck_Status` per check.
- **`ShapeAnalysis_Surface` extras** (`Surface`): `uvFromIso`, `singularity(_:)` (full pole/iso
  detail), `projectDegenerated`, and domain-restricted `projectPoint(_:uDomain:vDomain:)`.
- **`BRepGProp_Face`** (`Shape`): `faceIntegrationOrders`, `faceIntegrationKnotsU()`.

Swift-only; no xcframework change. The audit's "rebound a face on its own surface" and "3D point
classifier" candidates were verified **already wrapped** (`faceAddHole` and `OCCTClassifyPointOnFace`)
and not duplicated.

### v1.8.6 (June 2026) — feat: face-from-surface with interior holes (#266)

**New API.** `Shape.face(from: surface, outer: Wire, innerWires: [Wire])` builds a single trimmed
face that has **interior openings** (windows / cutouts) — a parametric surface trimmed by an outer
boundary with N inner-wire holes. Wraps `BRepBuilderAPI_MakeFace(surface, outer)` + `.Add(hole)` per
hole + `ShapeFix_Face` to project pcurves; hole winding is normalized automatically (tries holes
reversed, falls back to as-given, returns the valid build). Until now every face-from-surface builder
took a single outer loop, so a panel with holes couldn't be one trimmed face.

Motivating case: OCCTReconstruct carbody side-panel surfacing — a fitted B-spline panel with
window/door cutouts now surfaces cleanly instead of the surface ballooning over the windows
(SecondMouseAU/OCCTReconstruct #133). Swift-only; no xcframework change.

### v1.8.5 (June 2026) — chore: slim xcframework to the core slices (≈57% smaller download)

**Packaging only — identical kernel/source to v1.8.4.** The shipped `OCCT.xcframework` now contains
just the slices the ecosystem actually builds against — **macOS arm64, iOS arm64, iOS-arm64-simulator**
— dropping the visionOS and tvOS device/simulator slices. Result: download **344 MB → ~149 MB**,
extracted **~1.3 GB → ~594 MB**. Each shipped slice keeps its own `Headers/` (SwiftPM auto-exposes
per-slice headers to the C++ bridge — they cannot be de-duplicated to a single copy without breaking
remote/URL consumers), so the header reduction comes from shipping 3 slices instead of 7.

**Need visionOS / tvOS?** Rebuild the full set with `BUILD_ALL_PLATFORMS=1 Scripts/build-occt.sh`
(the package still declares those platforms). The build script defaults to the 3 core slices.

No API or behaviour change; the #263 ShapeFix kernel patch from v1.8.4 is retained.

### v1.8.4 (June 2026) — fix: OCCT kernel patch for ShapeFix_Face heap corruption (#263)

**Binary release.** Rebuilds `OCCT.xcframework` carrying a one-function OCCT source patch
(`Scripts/patches/0001-ShapeFix_Face-guard-non-face-context-replacement-263.patch`) that fixes the
upstream crash behind #263 at the kernel level.

`ShapeFix_Face::Perform` cast `Context()->Apply(myFace)` to `TopoDS_Face` without a type check; when
an earlier fix in the shared `ShapeBuild_ReShape` context had replaced the face with a compound (a
self-intersecting face split into several faces), the cast built an invalid face handle over a
compound `TShape` and corrupted the heap (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve` →
`BRep_TEdge::EmptyCopy`, SIGSEGV/SIGBUS). The patch guards the entry of `Perform`: if the applied
shape is not a face, return — the replacement is already recorded in the context. Submitted upstream
as [Open-Cascade-SAS/OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323) (CI green) and
will be dropped from `Scripts/patches/` once it ships in an OCCT release.

With this binary, a self-intersecting prism now *heals to a valid solid* instead of crashing; the
v1.8.3 in-wrapper `occtHasSelfIntersectingWire` guard remains as defence-in-depth. **xcframework
rebuilt** — remote SPM consumers get the new binary via the bumped `Package.swift` URL + checksum.

### v1.8.3 (June 2026) — fix: guard prism/heal against self-intersecting profiles (#263)

**Bug fix.** A self-intersecting mesh-derived outline (`BRepCheck` `SelfIntersectingWire`) extruded
into a prism and then healed by OCCT's `ShapeFix_Shape` corrupts the heap and aborts the process with
an uncatchable OS signal — the exact #263 fault (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve`
→ `BRep_TEdge::EmptyCopy`). Isolated to a **pure-OCCT** reproducer (a 4-point "bowtie" face: extrude
succeeds, healing the prism crashes 3/3) and reported upstream as
[Open-Cascade-SAS/OCCT#1322](https://github.com/Open-Cascade-SAS/OCCT/issues/1322).

`OCC_CATCH_SIGNALS` is inert in this build, so the signal cannot be caught once raised. The fix
**prevents** it: a cheap, no-meshing `BRepCheck_Analyzer` guard (`occtHasSelfIntersectingWire`) makes
`Shape.extrude` / `Shape.extruded(by:)` / `Shape.healed()` return `nil` for a self-intersecting
profile instead of building/healing the crashing solid (such a profile can never form a valid
extruded solid). Consumers (e.g. OCCTReconstruct `reify`) now degrade gracefully instead of aborting.

**Swift-only — no xcframework rebuild.** New `SelfIntersectingProfileGuard263` suite + full Modeling
(409) and ShapeHealing (208) domains green. Closes #263.

### v1.8.2 (June 2026) — feat: smooth multi-start `threadedShaft` direct build (#257)

**Feature.** Multi-start threads (`threadedShaft(starts: N)`, N > 1) now build via the smooth,
boolean-free **direct** path instead of falling to the faceted boolean cut (which produced
disconnected notches, #254). The single-start cam-slice loft is generalised to **N teeth tiling the
turn at lead = N·pitch**, giving a continuous interleaved multi-helix — a low-face-count,
BRepCheck-valid solid with the crest exactly at the nominal major radius. Partial-length multi-start
(thread + plain shank) closes via per-start shoulder faces; full-length is the lofted solid directly.

Covers the piecewise-linear forms the direct build already supports (ISO/Unified, trapezoidal/ACME,
square, buttress). Rounded (knuckle / rounded Whitworth), tapered (NPT/BSPT), and non-cylinder
targets still use the cut path.

Key detail: the loft samples **per pitch** (not per lead) — sampling per turn under-samples each
tooth at N > 1 and the `ruled:false` loft balloons the crest radially past nominal. Swift-only — no
xcframework rebuild. Verified: 2-/3-start crest = nominal by mesh vertices; start count = N.

### v1.8.1 (June 2026) — fix: single-start `threadedShaft` is always a smooth helix; deprecate `.boolean` (#254)

**Fix.** `threadedShaft(build: .boolean)` produced a *faceted, disconnected* thread — a helical
scatter of rectangular notches rather than a continuous groove — because it forced the screw-loft
boolean cut path, whose tightly-wound helical cutter is the classic OCCT BOP failure (cf. #213/#225).
The solid was `isValid` with roughly the right volume, so only rendering exposed it.

`.boolean` only ever existed to clamp a supposed crest "overshoot" from #222 — but #232 established
that overshoot is a `Bnd_Box` control-hull **artifact** (verified here: the direct build's crest
measures **exactly nominal** by both `boundingBoxOptimal()` and mesh vertices, while `.bounds`
over-reads +14–21%). With no remaining reason to prefer it, **single-start coaxial-cylinder threads
now take the smooth, boolean-free direct build (#213) for every build mode**, and `ThreadBuild.boolean`
is **deprecated** (now treated as `.auto`). Use `.auto` or `.direct`.

`.auto` / `.direct` single-start behaviour is unchanged (they already built direct). Swift-only change —
no xcframework rebuild.

**Known limitation:** multi-start threads (`starts > 1`) and non-cylinder targets still use the
faceted cut path, which can come out as disconnected notches — a smooth multi-start/internal direct
build is a tracked gap.

### v1.8.0 (June 2026) — feat: `Exporter.writeBREP(allowInvalid:)`

**Feature (additive).** `Exporter.writeBREP` (and the `Shape.writeBREP` instance wrapper) gain an
`allowInvalid: Bool = false` parameter. When `true`, the `shape.isValid` pre-check is skipped and the
shape is serialized as-is. BREP is OCCT's lossless native format and `BRepTools::Write` does not
require a topologically valid shape, so an in-progress reconstruction — a compound of loose analytic
faces, possibly with a few invalid faces — can be persisted and later reloaded for measurement /
diagnostics (`Shape.loadBREP` already does not gate on validity). Default `false` preserves the
existing validity gate, matching the other exporters. Enables OCCTMCP #41 (measure an imperfect
reconstruction without forcing it through the validity gate). No xcframework change.

### v1.7.11 (June 2026) — fix: `fromPointGrid` degree clamp prevents a BRepMesh hang (#244)

**Bug fix.** `Surface.fromPointGrid` now clamps the B-spline fit degree to `min(uCount, vCount) − 1`.
Passing a `degMax` higher than the grid supports (e.g. the default `degMax: 8` on a 7×7 grid)
over-parameterised the fit — a degree-8 surface from only 7 samples/direction oscillates (Runge
phenomenon) and can self-overlap in 3D. The face was *topologically* valid (`BRepCheck` passes) but
geometrically rippling, so `BRepMesh`'s adaptive refinement never converged — an in-process,
uninterruptible hang (the OCCTReconstruct blocker). Clamping the degree keeps the fit well-posed; the
7×7 case now meshes in ~40 ms.

Prevention is the fix: a watchdog-based bounded mesh was prototyped and **rejected** — BRepMesh does
not poll `UserBreak` during heavy meshing (verified: a fine sphere ran ~13 min / 5 GB ignoring a
0.01s deadline), so an in-process time bound can't be made both reliable and safe. No xcframework change.

### v1.7.10 (June 2026) — crash fix: degenerate hole wires (#234); housekeeping (#178, #210)

**Bug fix + docs.**

- **#234 — `faceAddHole` rejects degenerate hole wires.** A 2-vertex / zero-area / collinear hole
  wire was accepted, producing an invalid face whose extruded prism **SIGSEGV'd** OCCT's `ShapeFix`
  (`healed()`) — an uncatchable OS signal. `OCCTMakeFaceAddHole` now returns `nil` for a hole wire
  with < 3 distinct vertices or all-collinear points, breaking the crash chain at the source. (The
  general "`healed()` never crashes on any invalid input" can't be defended in-process — the fault
  is inside OCCT's uncatchable `ShapeFix`.)
- **#178 — loft polar-iterator fix is upstream.** The `BRepFill_CompatibleWires` guard (#176) shipped
  in OCCT 8.0.0p1; the carried `Scripts/patches/0001-*` was dropped. Corrected the stale CLAUDE.md
  note + #176 regression test comment (the test passes against the unpatched p1 xcframework).
- **#210 — context7.** Runnable-snippet doc comments on the core ops (primitives + booleans) and a
  CLAUDE.md doc-standards rule ("document with a runnable Swift snippet so context7 indexes it"). The
  Swift API is now indexed and queryable on context7 (`/gsdali/occtswift`).

No new operations; no xcframework change.

### v1.7.9 (June 2026) — face from surface bounded by a wire / UV polygon (#233)

**Additive, source-compatible.** Trim a curved analytic surface (cylinder / cone / sphere /
B-spline) to a **non-rectangular** region, instead of only a rectangular UV patch.

- **`Surface.toFace(uvBoundary: [SIMD2<Double>])`** — a closed UV-space boundary polygon becomes 2D
  edges with pcurves on the surface → `BRepBuilderAPI_MakeFace(surface, wire)` + `BuildCurves3d`.
- **`Shape.face(from: Surface, boundary: Wire)`** — a 3D boundary wire: exact `MakeFace` +
  `ShapeFix_Face` when the wire lies on the surface, else a fallback that projects the wire's ordered
  points to UV and trims by that polygon (handles sampled boundary polylines; a seam-crossing
  boundary isn't handled by the fallback).

Bridge: `OCCTShapeCreateFaceFromSurfaceUVPolygon`, `OCCTShapeCreateFaceFromSurfaceWire`. Surfaces
86→88, total **4,290** operations. No xcframework change.

Also lands the #232 investigation (doc + tests, no behavior change): `Shape.bounds` over-reports for
B-spline/faceted geometry (control-hull artifact) — threaded solids are bounded *exactly* to
`length`/`depth`; `Issue232BoundsTests` asserts the true (mesh-vertex) extent.

### v1.7.8 (June 2026) — cookbook: surfaces from points + working with meshes (#230, #231)

**Documentation only — no code, API, or xcframework change.** Two new cookbook pages; snippets
compile-checked against the shipped API.

- **Surfaces from Points** (#230) — fit a B-spline `Surface` through 3D points: a regular grid via
  `Surface.fromPointGrid` (`GeomAPI_PointsToBSplineSurface`), a scattered cloud via
  `Surface.plateThrough` (`GeomPlate`), and deform-an-existing-surface-to-targets via
  `nlPlateDeformed` (NLPlate). With a which-to-use table (vs. `Surface.gordon` for curve networks).
- **Working with Meshes** (#231) — operating on the `Mesh` value type (distinct from Meshing &
  Export): build from vertex/index arrays, inspect, triangle ↔ B-Rep face picking
  (`trianglesWithFaces`), mesh-level booleans, `toShape`, and SceneKit / RealityKit / Metal interop.

### v1.7.7 (June 2026) — cookbook: Gordon surfaces (#229)

**Documentation only — no code, API, or xcframework change.** New cookbook page on **Gordon
surfaces** — skinning a surface through a network of crossing profile + guide curves via
`Surface.gordon` / `Surface.gordonReport` (`GeomFill_Gordon`). Covers the grid-closure requirement,
build diagnostics (`GordonResultStatus`, `allowApproximateFallback`), the lower-level `networkSurface`
(`GeomFill_NetworkSurface`) and its knot-alignment caveat, and a Gordon-vs-loft-vs-fill decision table.
Snippets compile-checked against the shipped API; figure rendered from the same network the page shows.

### v1.7.6 (June 2026) — cookbook complete: healing, meshing, XCAF, topology (#210, #228)

**Documentation only — no code, API, or xcframework change.** Adds the final four cookbook areas,
completing the issue #210 area list (the Swift-API counterpart to OCCT's own user guides). Every
snippet was compile- and run-checked against the shipped API.

- **Healing & Validity** — `isValid` / `isValidSolid` / `isSelfIntersecting`, `analyze`,
  `signedVolume` + `orientedForward`, the repair ops (`healed` / `fixed` / `unified` / `upgraded`),
  sewing, and free-boundary gap finding/closing.
- **Meshing & Export** — `mesh(linearDeflection:)` + `MeshParameters`, the `Mesh` type, `mesh.toShape`,
  a deflection table, and STL / OBJ / PLY / STEP / IGES / BREP / glTF export + import with a round-trip.
- **XCAF Assemblies** — `Document` trees, components & instancing, names / colors / materials, and
  structured STEP / GLB round-trip (with a two-colour assembly figure).
- **Topology Graph** — `TopologyGraph` node counts, adjacency / shared edges / `sameDomainFaces`,
  durable `GraphUID`s (vs ephemeral `NodeRef`), and history tracking through operations.

### v1.7.5 (June 2026) — `threadedRod` from a custom profile + helical-sweeps cookbook (#225)

**Additive, source-compatible.** New `Shape.threadedRod(customProfile:nominalDiameter:pitch:cutDepth:length:…)`
builds a smooth worm/screw from a **custom radial tooth profile** directly — composing the helicoid
with the core by sewing, with **no boolean** — yielding a BRepCheck-valid, analytic solid (a handful
of B-spline faces → a sub-MB STEP).

This addresses #225: `helicalSweep` + `union`/`subtract` against a coaxial cylinder produces an
invalid (union) or collapsed-to-zero (subtract) result that no fuzzy value or heal pass recovers —
OCCT's BOP can't resolve the coincident/tangent helicoid faces (consistent with #213, #181). The
boolean compose path was never the way; the direct build is. The custom-profile direct build already
existed under `threadedShaft(spec:)` with a `ThreadSpec(customProfile:)` — `threadedRod` makes it a
discoverable one-liner and never silently falls back to an invalid boolean (returns `nil` instead).

- `ThreadProfile.supportsSmoothRodBuild` — public predicate (real crest flat, ≤ 2 flanks) for whether
  a custom profile can take the direct build.
- `Shape.helicalSweep(…)` doc now warns against the boolean-compose anti-pattern and points to `threadedRod`.
- **Cookbook: Helical Sweeps** — new page (`helicalSweep` helicoids vs. `threadedRod` worms, and why
  the boolean compose fails), with rendered figures.

### v1.7.4 (June 2026) — docs: cookbook lofting & sweeps, context7 onboarding

**Documentation only — no code, API, or xcframework change.**

- **Cookbook: Lofting & Sweeps** (#226) — new example-rich page covering extrude, revolve,
  sweep-along-path, loft (square→round, ruled vs smooth, point-capped cones), and multi-section
  pipe shells, with a "loft vs multi-section sweep — which?" decision section. Every snippet is
  compile- and run-checked against the shipped API; four figures (pipe elbow, frustum, cone, vase)
  rendered headlessly as PNG posters + interactive `<model-viewer>` GLB models.
- **context7 onboarding** (#224) — added `context7.json` scoping context7's crawl to the Swift API
  (`docs/`, `Sources/OCCTSwift`) with usage rules, so the Swift surface becomes queryable on
  context7 (issue #210).
- **WebAssembly feasibility plan** (#223) — `docs/wasm-feasibility.md`: analysis + phased plan for
  reusing the OCCTSwift API in a SwiftWasm app (deferred; the wasi-sdk-vs-Emscripten ABI split is
  the central obstacle).

### v1.7.3 (June 2026) — smooth fine-pitch internal threads (#219)

**Bug fix.** `threadedHole` on a fine-pitch internal thread (e.g. 3/8-16 UNC, M10×1.5) came out
**faceted**. The `ruled:false` smooth helical cutter self-intersects in a degenerate band around the
default ~14 sections/turn — the axial step per section is far smaller than the groove's axial
half-width, so consecutive sections overlap many-deep and the lofted B-spline pinches, making the
boolean a no-op that silently fell back to the faceted cutter. The cut path now builds the smooth
*internal* cutter at a denser, escalating section count (24→36/turn) and takes the first sound cut;
the faceted cutter remains the fallback for genuinely awkward composite bodies. Fine-pitch internal
threads now cut smooth (the wing-nut cookbook bore drops from ~247 faces to ~15). No API change.

### v1.7.2 (June 2026) — thread envelope fix (#222)

**Additive, source-compatible.** `Shape.threadedShaft(…)` gains a `build: ThreadBuild = .auto`
parameter. At coarse pitch / wide crest flats the smooth direct rod build (#213) bows the crest
**past** the nominal major radius (+14–21% measured: M12×1.75 → r 6.85 vs 6.0; Tr12×3 → 7.28),
which oversizes headless single-start parts (lead screws, studs, worms). `build: .boolean` forces
the boolean cut path — cutter subtracted from a cylinder of radius exactly `nominalDiameter / 2`,
so the crest is clamped in-envelope (≤ nominal, ~1% tessellation margin). `.auto` (default) and
`.direct` keep the original smooth build. No existing call sites change.

### v1.7.1 (June 2026) — p1 follow-ups + xcframework header hygiene

**Additive + a packaging fix.** New p1 operations and a corrected xcframework (no stale headers).

#### New operations
- **BRepGraph durable identity** — `TopologyGraph` UID/RefUID/ItemUID accessors (`uid(ofNodeKind:index:)`,
  `node(forUID:)`, `contains(uid:)`, ref/item variants, `generation`) over `BRepGraph::UIDsView`, giving
  persist-safe identifiers (the migration note's `UID`/`RefUID`/`ItemUID`, vs the non-durable NodeId/RefId).
- **`Surface.networkSurface(profiles:guides:tolerance:)`** — wraps the new `GeomFill_NetworkSurface`
  low-level Gordon builder, with a `NetworkSurfaceStatus`.
- **`Surface.gordonReport(…)`** — exposes `GeomFill_Gordon`'s new `Status()`/`IsApproximate()` and the
  `ExactOnly`/approximate-fallback `ApproximationMode` (`GordonResult` + `GordonResultStatus`).
- **`Polygon2D.copy()`, `PolygonOnTriangulation.copy()/setNodes()/setParameters()`** — the new
  `Poly_*` copy/mutator APIs.
- **BRepGraph reads, now real:** `faceSameDomain(of:)` (derived from edge-incidence + surface equality),
  face/edge adjacency & shared-edges (derived from first-class reverse relations), `faceIsNaturalRestriction`
  (`Tool::Face::NbWires == 0`).
- **BRepGraph vertex-supplement:** `faceAddVertex`/`edgeAddInternalVertex`/`faceRemoveVertex`/`faceNbVertexRefs`
  now back onto the `BRepGraph_LayerTopoSupplement` layer (uid/shape-based; the v1.7.0 stubs were no-ops).

#### Packaging fix — stale headers removed from the xcframework
`build-occt.sh` reused the CMake install prefix across builds; `cmake --install` adds headers but never
deletes removed ones, so **18 OCCT 8.0.0-GA headers** that p1 removed/renamed (e.g.
`Approx_BSplineApproxInterp.hxx`, `BRepGraph_Builder/History/RepId/MeshCache/LayerRegularity.hxx`,
`GeomFill_GordonBuilder.hxx`) **leaked into the v1.7.0 framework**, where they masqueraded as current
API (their symbols were never in the library). The build script now wipes the install prefixes each run,
and the v1.7.1 xcframework contains **only real p1 headers**. (Functionally harmless in v1.7.0 — the
phantom headers had no symbols — but misleading.)

> Note on edge regularity/continuity: one of those phantom headers (`BRepGraph_LayerRegularity`) made it
> look like a graph-level regularity API existed in p1. It does not (p1 ships `BRepGraph_LayerParametric`
> instead); `TopologyGraph.edgeMaxContinuity`/`setEdgeRegularity` remain no-ops. Use `Shape.maxContinuity`
> (`BRep_Tool::MaxContinuity`) for edge continuity.

### v1.7.0 (June 2026) — OCCT 8.0.0p1 upgrade; BRepGraph realigned to its redesigned model

**MINOR — dependency upgrade with API-behaviour changes confined to the BRepGraph domain.** OCCT
shipped **8.0.0p1** as a hot patch on top of 8.0.0. OCCTSwift now pins it (`V8_0_0_p1`). Everything
outside BRepGraph is a transparent upgrade; BRepGraph itself was comprehensively redesigned upstream
and our wrapper has been realigned to the new model rather than shimmed back to the old one.

#### Upstream fix landed
Our `BRepFill_CompatibleWires::SameNumberByPolarMethod()` polar-iterator guard (OCCTSwift #176 — the
loft/ThruSections SIGSEGV on mismatched closed profiles) **shipped in 8.0.0p1**. The source patch we
carried (`Scripts/patches/0001-…`) is therefore removed; `build-occt.sh` pins `OCCT_RC="p1"`.

#### Removed/changed OCCT classes migrated (non-BRepGraph)
- **`Approx_BSplineApproxInterp` (removed)** → `BSplineApproxInterp` is reimplemented on
  `GeomAPI_PointsToBSpline` (the documented replacement). The C/Swift ABI is unchanged, but
  `nbControlPoints` is now **advisory** (the approximator chooses the pole count to meet tolerance)
  and `interpolatePoint(_:withKink:)` is a **no-op** (no per-point exact-interpolation/kink control
  in the replacement). `maxError` is computed by projecting the inputs onto the fitted curve.
- **`GeomFill_Gordon` (reworked)** — API remained source-compatible; no wrapper change.
- **`BRepGraph_RepId`** moved to the `BRepGraphInc` subpackage (header `BRepGraphInc_RepId.hxx`).

#### p1 crash fixes (OS-signal null-derefs that `catch(...)` cannot trap)
- **`Extrema_ExtElCS` (line ∥ cylinder axis)** — infinite/degenerate extrema crash. `ExtremaElCS.lineToCylinder`
  now returns 0 when the line is parallel to the cylinder axis.
- **`ShapeUpgrade_WireDivide` / `ShapeFix_ComposeShell`** — p1 made the `ShapeBuild_ReShape` context
  mandatory; `Perform()` null-derefs without one. Both bridges now set a context (plus WireDivide
  guards a wire whose edges have no pcurve on the target face).
- **`Wire.rectangle`** with sub-`Precision::Confusion()` dimensions made degenerate edges that crashed
  downstream; such dimensions are now rejected (returns nil).

#### BRepGraph realigned to the 8.0.x model
BRepGraph is OCCT's explicit graph-oriented topology model (see
[Open-Cascade-SAS/OCCT discussion #1291](https://github.com/Open-Cascade-SAS/OCCT/discussions/1291)).
8.0.0p1 reworked it around nine separated concerns — topology **definitions** vs **references/usages**,
**geometry reps**, **mesh reps**, **products/occurrences**, persistent **UIDs**, metadata **layers**,
modification **stamps** (version counters, *not* booleans), and self-invalidating **caches**. The
wrapper was rewritten to that model. Upstream notes the interface "will change slightly in 8.1 and in
development versions after 8.0," so expect further churn here.

Concretely:
- **Shape ingestion**: `BRepGraph_Builder` removed → `BRepGraph::ShapesView::Add()`.
- **History**: `BRepGraph::History()` removed → the registered `BRepGraph_LayerHistory` layer
  (`LayerRegistry().FindLayer<>()` / `.Ensure<>()`); records are `Event`s.
- **Topology queries** moved across views: counts to `Topo().Geometry().NbFaceSurfaces()` etc.;
  `IsBoundary`/`IsManifold`/`FindCoEdgeId` to `BRepGraph_Tool::Edge`; `SameParameter`/`SameRange` to
  `BRepGraph_Tool::CoEdge` (per-coedge, derived). Edge→faces / vertex→edges are first-class reverse
  relations (`FacesOf`, `VertexOps::Edges`); **face/edge adjacency and shared-edges are derived from
  them** (no direct adjacency call survived, but the data does).
- **Mesh + geometry representations are handle-based**: integer "rep ids" are gone. The wrapper keeps
  its rep-id Swift API working via a per-graph handle registry that backs the new
  `Mesh().Editor().Faces().SetCachedTriangulation(face, handle)` / persistent-rep setters. Mesh cache
  inspection reads `Mesh().Cache().*.Entry()` (each holds a single handle + a `MeshGeneration` stamp).
- **Edge start/end vertex** now resolves a `VertexRefId` (a per-edge use) to its vertex definition.
- **Root products** require explicit `AppendDocumentRoot()` after creation.

##### Deliberately-removed concepts (now no-ops or derived-getter-only — by design, not breakage)
These reflect BRepGraph's intent; the *capability* lives elsewhere in the new model:
- **Flags are derived from geometry, not stored** → `SameParameter`/`SameRange`/`Degenerated`/`IsClosed`
  setters are no-ops; the **getters return the live derived value**.
- **Regularity/ownership are controlled layers**, not inline flags → the old `SetEdgeRegularity` /
  `EdgeMaxContinuity` inline path is gone.
- **Natural-bound faces are normalized away** (explicit topology is required below a bounded face) →
  `…NaturalRestriction` get/set no longer apply.
- **Locations live on assembly references** (occurrence/child), not per-subshape → the per-vertex/edge/
  wire/face/shell/solid/coedge `…RefLocalLocation` setters are gone; occurrence/child placement setters
  remain.
- **Coedges are first-class** (a coedge *is* the edge-on-face use, carrying orientation/pcurve/seam) →
  the coedge-as-separate-reference setters are gone; `NbCoEdgeRefs` reports the coedge count.
- **Vertices are references with reverse relations** → face/edge vertex add/remove mutators are gone
  (population builds them); query via the reverse relations instead.

#### Test/behaviour notes
- `GC_MakeHyperbola` (3-point) is stricter in p1: a collinear `S2` (zero minor radius) is rejected;
  the test now uses a valid off-axis `S2`.
- Run the suite with `swift test --no-parallel` — the pre-existing non-deterministic NCollection
  arm64 race makes the parallel run flaky (unrelated to p1).

### v1.6.3 (June 2026) — buttress trued to DIN 513; Whitworth & knuckle finished

**PATCH — geometry corrections, non-breaking.** The last two medium-confidence thread forms are
trued to their standards:

- **`.buttress` → DIN 513** (German *Sägengewinde*): asymmetric **3° load / 30° clearance** flanks
  (33° total) at depth **0.86777·P** (so the bolt core `d3 = d − 2·0.86777·P`, verified against the
  DIN 513 table — e.g. S 10 × 2 → d3 = 6.528). Previously it used a reconstructed ANSI 7°/45° profile
  at 0.66271·P, which matched no German standard.
- **`.whitworth` / `.bspParallel`** confirmed at the correct 55° / **0.640327·P** and kept as the
  standard BS 84 **flat-truncation** (crest = root flat = P/6). A fully *rounded* crest makes the deep
  tooth's `ruled:false` loft spike past the nominal radius (a thin outward flap, OCCTSwift #213), so
  the truncation is the form that builds smooth and dimensionally exact.
- **`.knuckle`** now routes through the **faceted cut path** for the external build. The previous
  rounded-crest direct loft was both slow (~28 s) and bulged ~6% past the nominal crest; the cut path
  keeps the crest exactly at the nominal radius and builds in ~1 s. (Rounded profiles — those with
  more than two straight flanks — are now detected and sent to the cut path generally.)

Buttress cookbook figure re-rendered with the DIN 513 profile.

### v1.6.2 (June 2026) — knuckle thread trued to DIN 405

**PATCH — geometry correction, non-breaking.** The `.knuckle` form now matches DIN 405: depth
**0.55·P** (so the bolt minor `d3 = d − 1.1·P`, verified against the standard dimension table — e.g.
Rd 8 × 1/10″ → d3 = 5.460) and a proper **30°-included (15° per side)** flank with circular-arc
rounded crest and root (the rounding radius is solved for flank tangency). Previously it used a
cosine profile at 0.5·P (≈60°-included flanks). A small crest/root land is retained so the smooth
direct build still applies.

### v1.6.1 (June 2026) — smooth internal threads

**PATCH — quality improvement, non-breaking.** `threadedHole` now produces **smooth** internal
threads instead of faceted ones. An interior helix is cut into a *thick wall* (not a thin shaft), so
OCCT's boolean subtracts a smooth (`ruled=false`) helical cutter robustly — verified valid across all
orientations. (The external fallback is unchanged: subtracting a smooth cutter from a thin external
cylinder is the unreliable case from #213, so non-cylinder/tapered external cuts stay faceted.)
Cookbook nut / wing-nut / lead-screw figures re-rendered with the smooth bore threads.

### v1.6.0 (June 2026) — thread forms + custom profiles

**MINOR — additive, non-breaking** (existing `ThreadSpec`/`threadedShaft` calls are unchanged).

The thread feature now covers the common standard forms beyond the 60° V, and can thread a cylinder
with **any** cross-section:

- **New `ThreadForm` cases**: `.whitworth` / `.bspParallel` (55°), `.acme` (29°) / `.trapezoidal`
  (metric Tr, 30°), `.square`, `.buttress` (7°/45°), `.knuckle` (rounded), `.nptTapered` /
  `.bsptTapered` (60°/55° on a 1:16 taper), and `.custom`. (UNF/UNC, metric-fine, and SAE remain
  pitch/standards variants of the existing 60° forms — no new cases needed.)
- **`ThreadProfile`** — a public, `Codable` normalized tooth cross-section (vertices of
  `axial` 0…1 × `depth` 0 = crest … 1 = root). `ThreadSpec(customProfile:nominalDiameter:pitch:cutDepth:)`
  threads a cylinder with an arbitrary shape. Built-in form profiles are exposed too
  (`.iso60V()`, `.acme29`, `.square`, …).
- **Geometry is now form-dependent**: `ThreadSpec.cutDepth` / `profile` / `taperRatio` switch on the
  form. ISO/Unified compute identically to before (5H/8, P/8 crest, P/4 root, 30° flanks).
- **All forms work external and internal**: external cylinders use the smooth, BRepCheck-valid direct
  build (#213) — a handful of faces; internal threads (`threadedHole`), non-cylinder targets, and the
  tapered pipe forms use the robust faceted cut path. The OCCT bridge is unchanged (a thin wrapper);
  all new geometry is composed in Swift.
- **Parser** recognises `Tr40x7[LH]`, `1.5-4 ACME`, `G1/2` (BSP), `R…`/`Rc…` (BSPT), `W1/2` / `1/2 BSW`
  (Whitworth), and `1/2-14 NPT`, alongside the existing metric/Unified designations.

Cookbook: the [Threads](https://gsdali.github.io/OCCTSwift/guides/cookbook/threads.html) page gains a
forms gallery and a custom-profile example.

### v1.5.3 (June 2026) — smooth, valid ISO V-threads built without booleans (closes #213)

**PATCH — additive, non-breaking** (same `threadedShaft` API; smoother/valid result).

`Shape.threadedShaft(form: .iso68)` produced a near-square groove (~6.6° flanks) instead of a true
60° V (30° flanks): the cutter's flank offsets used the crest/root *truncation* flats and omitted
the `cutDepth·tan(30°)` flank term. Fixing the profile, however, exposed a deeper limit — OCCT's
boolean engine **cannot reliably subtract a smooth helical V-thread cutter** from a cylinder (it
under-cuts / no-ops on ~half of all orientations, unfixable by bleed / fuzzy / cone / extend; only
the faceted screw-loft is robust, because its planar facets cross the shaft transversally).

So `threadedShaft` now **builds the threaded rod directly, with no boolean**, when the target is a
plain cylinder coaxial with the axis (the common case):

- The thread region is a `ruled=false` ThruSections loft of the thread's true cross-section
  ("cam": root arc → flank spiral → crest arc → flank spiral) at z-slices rotated by the helix —
  one BSpline face per cam edge (**~9 faces, not hundreds of facets**), flat caps, solid-to-axis.
- Any unthreaded margin is closed by **pure sewing** — a single-loop shoulder face + plain
  cylinder + end disk — not a fuse (a fuse is robust here but **6–71 s**; sewing is ~0.3 s).

Because the kernel's BOP is never invoked, the result is **orientation-robust AND BRepCheck-valid**
where the old cut path was faceted or failed. The boolean cut path remains the fallback for
non-cylinder targets, internal threads (`threadedHole`), and multi-start. The whole construction is
composed in Swift from already-wrapped primitives (`Shape.loft(ruled:)`, `Wire.arc`/`.interpolate`,
`Shape.face(from:)`, `Shape.sew`, `Shape.solidFromShell`), so the OCCT bridge stays a thin wrapper —
no thread-specific bridge code.

> Note: the smooth thread is a BSpline solid, so its default `Bnd_Box` is the control-pole hull and
> overshoots the true surface by ~13% (a pole artifact, not a bulge); use `boundingBoxOptimal()` for
> the real extent (the crest sits exactly at the nominal radius).

### v1.5.2 (June 2026) — reconstruction wrapping gaps: outer shell, mesh quality flag, wire arc-length adaptor (closes #211)

**PATCH — additive, non-breaking.** Closes the confirmed gaps from the mesh→CAD reconstruction
coverage audit (#211):

- **`Shape.outerShell` → `Shape?`** (`BRepClass3d::OuterShell`) — the outer body shell of a solid,
  distinguishing it from internal void shells. `nil` for non-solids. Decomposes a part into
  outer-body + cavities.
- **`MeshParameters.allowQualityDecrease`** (`IMeshTools_Parameters::AllowQualityDecrease`, default
  `false`) — the one missing mesh knob. Lets a re-mesh at a different deflection actually replace an
  existing finer triangulation (e.g. a deviation re-measure), instead of OCCT silently keeping the
  coarser/finer mesh.
- **`WireCurve`** (`BRepAdaptor_CompCurve`) — treats a multi-edge wire as one **arc-length**
  curve: `length`, `point(atAbscissa:)` / `tangent(atAbscissa:)` (walk across edge boundaries),
  `points(count:)` / `points(spacing:)` for **even arc-length sampling** (`GCPnts_UniformAbscissa`),
  plus native `parameterRange` / `point(atParameter:)` / `tangent(atParameter:)`. Replaces ad-hoc
  per-edge sampling when placing sections along a measured wire.
- **`EdgeCurve`** (`BRepAdaptor_Curve`) — the single-edge sibling of `WireCurve`: adds the
  arc-length side (`length`, `point(atAbscissa:)`, `points(count:/spacing:)`) that `Edge`'s native
  `point(at parameter:)` lacked.
- **`Shape.innerShells`** — the void/cavity shells of a solid (every shell except `outerShell`);
  pairs with `outerShell` to fully decompose a part into outer body + cavities.

Also from #211, verified and **not** needing changes: `Shape.minDistance(to:) -> Double?` already
exists; and a "scattered point-cloud" `GeomAPI_PointsToBSplineSurface` fit is **not** an OCCT
capability — every constructor is grid-based (`Array2`); a cloud fit means resampling to a grid
(already wrapped via `Surface.fromPointGrid`) or `GeomPlate` / `BRepOffsetAPI_MakeFilling` (already
wrapped). Source-only (no xcframework change).

### v1.5.1 (June 2026) — `Shape.isSelfIntersecting(timeout:)` — bounded self-intersection check (closes #208)

**PATCH — additive, non-breaking.** Follow-up to #206. `isValidSolid` is a topology-level check
(`BRepCheck_Analyzer`) that **misses global self-intersection** — a self-intersecting B-spline solid
from `loft(ruled: false)` can report `isValidSolid == true` yet poison downstream booleans. New:

```swift
func isSelfIntersecting(timeout: Double = 30) -> Bool?   // true / false / nil(=indeterminate)
```

Backed by `BOPAlgo_ArgumentAnalyzer`'s self-interference test (stop-on-first-faulty), wrapped in the
same wall-clock watchdog as the #206 booleans so it can't hang: returns `true` (self-intersects),
`false` (clean), or `nil` if it couldn't finish within `timeout` (**indeterminate** — treat as
"unknown", not "clean"). The test is **expensive** (seconds on B-spline solids), so it's opt-in.
Verified on the #206 operands: `nurbs_env` → `true` (the actual culprit), and the docs give the
validate-at-source recipe (`orientedForward()` + `isSelfIntersecting() == false`).

**Why not a cheap volume/`isValidSolid` guard (the issue's other options):** investigation showed
the reported `env` operand passes `BRepCheck`, sits within its bounding box, and has positive volume
— nothing cheap flags it. And a `volume <= 0` reject would false-positive on legitimately
*reversed-orientation* solids (a known, `orientedForward()`-fixable case), so it isn't sound.
`isValidSolid`'s doc now spells out the topology-vs-self-intersection distinction. Source-only.

### v1.5.0 (June 2026) — boolean ops are time-bounded; never hang indefinitely (closes #206)

**MINOR — additive param + a default-behavior change.** `Shape.union` / `subtracting` /
`intersection` could **hang indefinitely** on a self-intersecting / inside-out operand — e.g. a
B-spline solid from `loft(ruled: false)` that reports `isValidSolid == true` yet poisons the
boolean. `BRepAlgoAPI_Cut` on the reported operands spun for >5 min on a 66-face input.

The boolean ops now run under a **wall-clock watchdog** (OCCT's `Message_ProgressRange` +
`UserBreak`) and return `nil` at a deadline instead of spinning forever:

```swift
func union(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
           timeout: Double = Shape.defaultBooleanTimeout) -> Shape?   // and subtracting / intersection
```

- **`timeout`** — seconds; default `Shape.defaultBooleanTimeout` (**120s**). `0`/negative = unbounded
  (the prior behavior). Verified to interrupt the real #206 operands (was an infinite hang → now `nil`).
- **Default-behavior change:** a boolean that genuinely runs longer than 120s now returns `nil`
  instead of completing/blocking. Pathological hangs are bounded; raise `timeout` (or pass `0`) for
  legitimately heavy booleans.

**Why a timeout and not an operand pre-check:** the cheap detectors don't catch the reported
`env` operand — `BRepCheck_Analyzer` reports it *valid* and its volume sits within its bounding box;
only `BOPAlgo_ArgumentAnalyzer` flags it, and that itself ran >50s on the input. The watchdog is the
only general, bounded guard. (The separate `cav` operand has negative volume, so a downstream
`volume > 0 && analyzeValidity(geometryChecks:)` gate remains a useful cheap fast-fail and is still
recommended.) Source-only (no xcframework change).

### v1.4.7 (June 2026) — boolean fuzzy value + glue options (closes #202)

**PATCH — additive, non-breaking.** `Shape.union` / `subtracting` / `intersection` now expose the two
`BRepAlgoAPI_BooleanOperation` robustness levers OCCT provides for **coincident / near-tangent faces**,
where the default boolean can silently under-subtract or inflate volume:

```swift
func union(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off) -> Shape?
// same trailing parameters on subtracting(_:) and intersection(_:)
```

- `fuzzyValue` → `SetFuzzyValue` (tolerance-based fuzzy boolean; `0` keeps OCCT's default, negatives ignored).
- `glue` → `SetGlue` — new `Shape.BooleanGlue` enum: `.off` (default), `.shift` (`BOPAlgo_GlueShift`),
  `.full` (`BOPAlgo_GlueFull`). Gluing hardens & speeds up unions/cuts of solids known to share
  coincident faces (e.g. consecutive analytic loft chunks, thin-wall shells).

Defaults reproduce prior behavior exactly. Implemented via a shared templated bridge driver
(`OCCTShapeUnionEx`/`SubtractEx`/`IntersectEx`) over the common `BRepAlgoAPI_BooleanOperation` base.
Source-only (no xcframework change).

### v1.4.6 (June 2026) — instanced-assembly STEP writer (closes #173)

**PATCH — additive, non-breaking.** New `Exporter.writeSTEPAssembly(_ document: Document, to url:)`
writes an XCAF `Document` as a **product-structured STEP assembly**: each unique part label
becomes one STEP product, referenced by its located component occurrences
(`NEXT_ASSEMBLY_USAGE_OCCURRENCE` + each component's `TopLoc_Location`). A part placed N times
stores **one** `MANIFOLD_SOLID_BREP`, not N copies — file size scales with unique parts, and the
result opens as an editable assembly in standard CAD viewers (AP214). Names/colors set on the
document are preserved.

The underlying capability already existed (`Document.writeSTEP` transfers the XCAF doc via
`STEPCAFControl_Writer`, and full rotation+translation placement landed in #174); this adds the
named, documented, throwing convenience entry point #173 asked for, plus instancing + round-trip
tests.

### v1.4.5 (June 2026) — mesh→shape weld tolerance is caller-tunable (#197)

**PATCH — additive, non-breaking.** `Mesh.toShape()` sewed its triangles into a shell at a
**hardcoded `1e-6`** weld tolerance. That tolerance must scale with the mesh's coordinate
magnitude — too small for a large-coordinate (or imprecise, imported) mesh leaves shared edges
unmerged and silently yields an open shell. It now takes `weldTolerance: Double = 1e-6` (the
default reproduces prior output); non-positive values return `nil`. From the #197 hardcoded-constant
sweep — the audit (see issue) found this the one remaining genuine knob; the rest of the `1e-X`
literals are internal correctness epsilons left as-is.

### v1.4.4 (June 2026) — mesh deflection is caller-tunable on auto-meshing utilities (#197)

**PATCH — additive, non-breaking.** Several utility functions auto-triangulated their input at a
**hardcoded `0.1` mm** deflection, leaving callers no control over fidelity/speed. Each now takes a
`deflection: Double = 0.1` parameter (the default reproduces prior output). First slice of the #197
hardcoded-constant sweep — the *mesh deflection* area:

- `Shape.writeSTLBinary(to:deflection:)` / `writeSTLAscii(to:deflection:)` — STL export resolution.
- `Shape.proximityFaces(with:tolerance:deflection:)` — proximity triangulation.
- `Shape.selfIntersectionPairs(tolerance:maxPairs:deflection:)` — self-intersection triangulation.
- `CoherentTriangulation.createFromMesh(_:deflection:)`.

(The primary STL path `Exporter.writeSTL(shape:to:deflection:)` already exposed this.) Source-only;
remaining #197 areas — tolerances, sampling counts — tracked in the issue.

### v1.4.3 (June 2026) — fast 2D drawings of threaded solids via polyhedral HLR (closes #196)

**PATCH — additive + guidance.** The v1.4.1 smooth analytic thread helicoid is HLR-hostile under
OCCT's **exact** HLR (`hlrEdges` / `HLRBRep_Algo`): projecting its BSpline faces computes analytic
helical silhouettes and blows up — a downstream 2D-drawing pipeline measured **~19× slower** vs the
v1.4.0 faceted thread.

**The fix is not to change the solid.** OCCT's **polyhedral** HLR (`hlrPolyEdges` / `HLRBRep_PolyAlgo`,
already wrapped) projects the shape's *triangulation*, so it is fast on any surface — **measured ~48×
faster** than exact HLR on an analytic M10 thread (337 ms vs 16.4 s, side view) — while the one
analytic solid stays smooth for STEP. **Prefer `hlrPolyEdges` for 2D drawings of threaded / curved
solids; reserve exact `hlrEdges` for analytically simple shapes.**

`hlrPolyEdges(direction:category:deflection:)` now exposes the internal mesh **`deflection`** (mm,
default `0.1`) so drawing pipelines can trade fidelity (more, shorter edges) for speed. Non-breaking —
the default reproduces prior output. (No GPU offload needed; the polyhedral CPU path already recovers
the speed. The broader hardcoded-constant sweep this surfaced is tracked in #197.)

### v1.4.2 (June 2026) — long full-length threads return a usable solid, not nil (closes #193)

**PATCH — regression fix.** A long full-length thread (`threadedShaft` over tens of turns, e.g. an
ISO 4017 M10×50 full-thread shank ≈ 49 turns) came back **`nil`**. No API change.

**Cause.** v1.4.1's soundness gate required `Shape.isValid`. For a long thread, the two cutter paths
both fail that gate: the smooth analytic cutter is BRepCheck-valid but, when wound over ~40+ turns,
OCCT's boolean degenerates to a near-no-op (the result keeps ~the full blank volume — *no groove cut*);
the faceted screw-loft fallback *does* cut the groove correctly but trips `BRepCheck` on a benign facet
self-intersection (`isValid == false`) — exactly the #193 symptom. With both rejected, the method
returned `nil`.

**Fix.** Soundness is now judged on **geometry, not `BRepCheck`**: the cut must stay inside the blank
(tight/optimal envelope) and remove a sane fraction of the volume. `isValid` is no longer a gate. The
analytic no-op is still rejected (it removes ~0 material → fails the volume check), so a long thread
falls through to the faceted screw-loft and is returned — dimensionally correct and STEP-exportable,
as the downstream reporter confirmed. Short/medium threads still get the smooth analytic helicoid and
remain `isValid == true`; only the long faceted fallback is allowed to be invalid-but-usable.

### v1.4.1 (June 2026) — smooth analytic thread helicoid, with screw-loft fallback (#187)

**PATCH — geometry quality, no API change.** `threadedShaft` / `threadedHole` now emit a **smooth
analytic helicoid** instead of v1.4.0's faceted ruled loft. Same signatures, same in-envelope
result; the difference is surface quality and face count.

**What changed.** v1.4.0 swept the V-profile through ~14 screw-transformed sections per turn and
ruled-lofted them — correct and in-envelope, but **faceted** (hundreds of flank facets) and ~1 s per
thread. The cutter is now built analytically (new bridge op `OCCTShapeBuildThreadCutter`): the four
ISO-68 V-corners each trace a single BSpline helix (`GeomAPI_Interpolate`), and the solid is bounded
by four ruled faces between consecutive corner-helices plus two V end caps — sewn, made solid, and
`BRepLib::OrientClosedSolid`-corrected. That's **~6 faces, no faceting**, regardless of turn count.

**Automatic fallback.** OCCT's boolean chokes on the *tightly-wound* cutter of small, fine-pitch
threads (e.g. M5×0.8 — 22.5 turns at radius 2.5): the subtraction comes back BRepCheck-"valid" but
with *more* volume than the blank. The cut is validated (optimal/tight bounding box stays inside the
blank **and** volume strictly decreases by a sane amount); if the analytic result fails, it silently
falls back to v1.4.0's robust screw-loft. So M6/M8/M10/M12 and coarse worm pitches get the smooth
helicoid, while pathological small-fine-pitch threads still build via the faceted-but-robust path.

**Why the envelope is measured on the optimal box.** The smooth helicoid's *default* `Bnd_Box`
(`BRepBndLib::Add`) is the BSpline **convex hull**, which overshoots the real surface by ~0.1–0.35 mm
— a control-pole artifact, not escaped material (`AddOptimal` returns the blank's exact extent).
Both the fallback check and the #181-C regression test now use the tight optimal box; a strict
tolerance there still catches the real >1 mm balloon the guard exists for.

**Migration.** None required. Thread mesh/STEP geometry differs again (smoother) — byte-exact
snapshot consumers must rebaseline; everything else is unchanged.

### v1.4.0 (June 2026) — correct, in-envelope thread geometry (closes #187)

**MINOR — BEHAVIOUR CHANGE to `threadedShaft` / `threadedHole`.** The thread output geometry changes:
both now produce a **correct, in-envelope helicoid** for every pitch, including coarse worm pitches
that previously returned `nil` or garbage.

**Why it changed.** The cutter was a `BRepOffsetAPI_MakePipeShell` sweep of a V-profile along the
helix. That sweep re-frames the section with the helix lead, so it **bulged the thread outward**
(~1.25× cut depth for fasteners, ~3.1× for worm pitches → a self-intersecting ≈2×-radius balloon that
crashed STEP export — #181-C/#185). The cutter is now built by a **screw-motion sweep**: the axial
V-profile is transported by a pure rotate-about-axis + translate-along-axis motion (every section
stays in its own axial plane), ruled-lofted, and subtracted. The result's crest sits at the nominal
radius (within ~0.1 mm tessellation), deterministically.

**Migration.** No API change (same signatures, still `Shape?`). But:
- the produced thread **mesh / STEP geometry differs** — snapshot/byte-exact consumers must rebaseline;
- threads that returned `nil` at coarse/worm pitch now return a valid solid;
- the V-form is faceted (ruled loft, ~14 sections/turn) rather than a smooth pipe surface;
- **performance:** ~1 s per thread (loft + boolean over the section facets). For many threads, expect
  it to dominate; a true analytic helical surface (future work) would remove the faceting/cost trade.

The #181-C envelope guard is retained as a thin safety net (now 1× cut depth) but effectively never
trips on the in-envelope result.

### v1.3.6 (June 2026) — fix: thread envelope guard rejected valid fastener threads (closes #189)

**PATCH — regression fix.** The #181-C envelope guard added in v1.3.4 used a tolerance
(`1e-3 · extent`) far tighter than the bounding-box overrun of a *valid* `threadedShaft` /
`threadedHole` result, so it returned **`nil` for ordinary bolts/screws** (M5–M10, ISO 4762/4014/…)
that built in v1.3.3 — breaking 37 downstream fastener generators.

The guard's tolerance is now `2 · cutDepth`. Measured overruns (relative to the thread cut depth,
which scales the corrected-Frenet sweep's directional bulge) are ~1.25× for valid fastener threads
and ~3.1× for the coarse-worm-pitch garbage the guard is meant to catch (#181-C, which balloons to
~2× radius and crashes STEP export). `2 · cutDepth` sits cleanly between them — valid threads build
again, the catastrophic balloon is still rejected. (The proper fix — a cutter that doesn't bulge at
all — is tracked in #187.)

### v1.3.5 (June 2026) — `Shape.helicalSweep` worm/screw-thread helicoid (closes #185)

**PATCH — additive convenience API.** Adds `Shape.helicalSweep(profile:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)`
(and a multi-profile overload), the turnkey form of the #180 auxiliary-spine sweep for the helical
case. It builds the helix spine **and** a correctly-spanning central-axis auxiliary spine internally,
with the orientation flags (`CurvilinearEquivalence = false`, no contact) that keep the swept section
radial — producing a worm/screw-thread helicoid in one call:

```swift
Shape.helicalSweep(profile: rib, axisOrigin: .zero, axisDirection: SIMD3(0,0,1),
                   radius: 5, pitch: .pi, turns: 4.77)   // crest stays radial (~Ø12), not nil
```

Hand-rolling this with `pipeShell(mode: .auxiliary(...))` reliably returned nil because (a) `Wire.helix`
runs toward +Z or −Z depending on handedness and (b) the auxiliary spine must span the helix's full
axial extent or the section planes never intersect it. The helper handles both. (Investigation: the
correct OCCT recipe was confirmed empirically — `SetMode(axisLine, CurvilinearEquivalence=false,
NoContact)`; `CurvilinearEquivalence=true` and the contact modes fail to build for a helix spine.)

### v1.3.4 (June 2026) — assembly/export robustness (#181 B & C)

**PATCH — robustness fixes, no API change.**

- **STEP writer serialization (#181-B).** Concurrent `writeSTEP` calls could SIGSEGV because
  OCCT's `STEPCAFControl`/`STEPControl` writers share non-thread-safe `Interface_Static` globals
  with IGES. All STEP/IGES write entry points now serialize on the shared data-exchange mutex, so
  parallel exports queue instead of crashing. (The crash is an uncatchable signal, so internal
  serialization — not documentation — is the fix.)
- **`threadedShaft` envelope guard (#181-C).** At coarse pitch / steep lead (and, observed here,
  even at bolt pitch) the helical V-cutter self-intersects and the boolean subtract returns a
  non-deterministic solid that BRepCheck reports "valid" yet extends well outside the blank
  (≈Ø22 on a Ø12 blank) — which then crashed downstream STEP export. A thread cut can only remove
  material, so `threadedShaft` now returns `nil` when the result escapes the blank envelope rather
  than handing back garbage. Callers should fall back (e.g. a smooth-cylinder worm body).

Note on #181-A (XCAF `setColor`/`setName` on auto-created component labels): could not reproduce as
an OCCT or bridge fault — `XCAFDoc_ColorTool::SetColor` on auto-created/reference component labels is
robust in isolation, and the bridge already fails safe on unregistered labels. Left open pending a
minimal reproducer.

### v1.3.3 (June 2026) — multi-section pipe shell (closes #180)

**PATCH — additive API.** Adds `Shape.pipeShellMultiSection(spine:profiles:mode:withContact:withCorrection:solid:)`,
the multi-section form of `pipeShell`. Several profiles positioned along the spine are swept into a
single variable cross-section solid/shell via repeated `BRepOffsetAPI_MakePipeShell::Add`. Supports
all orientation modes including `.auxiliary(spine:)`, so a thread rib can ramp from a runout to full
crest along a helix while staying radial — the worm-thread case that single-profile `pipeShellWithLaw`
(Frenet-only, degenerates on near-zero scaling) could not express.

```swift
Shape.pipeShellMultiSection(spine: helix, profiles: [fullRib, runoutRib], mode: .auxiliary(spine: axis))
```

### v1.3.2 (June 2026) — fix loft (ThruSections) SIGSEGV on mismatched profiles (closes #176)

**PATCH — robustness fix, no API change.** `Shape.loft` (and any `BRepOffsetAPI_ThruSections`
path) could SIGSEGV and abort the host process on mismatched closed profiles — e.g. machine-generated
profile sets with differing vertex counts. The crash is an upstream OCCT null dereference in
`BRepFill_CompatibleWires::SameNumberByPolarMethod` (unguarded correspondence-list iterator
over-advance); because it surfaces as an OS signal, the bridge's `catch(...)` could not intercept it.

Fixed by carrying a minimal source patch
(`Scripts/patches/0001-BRepFill_CompatibleWires-guard-polar-iterator.patch`, applied by
`build-occt.sh`) and rebuilding the xcframework. Loft now fails gracefully (`nil`) on such inputs.
Reported and fixed upstream: OpenCASCADE/OCCT issue #1297, PR #1298.

Note: the `OCC_CATCH_SIGNALS` guards added in v1.2.1/v1.2.2 are inert in this build (OCCT is not
compiled with `OCC_CONVERT_SIGNALS`) and do not provide signal safety; this patch addresses the
crash at its source instead.

### v1.3.1 (June 2026) — feature-aware patterning, sweep orientation, geometric edge selection (closes #169, #170, #171)

**PATCH — additive helpers + one orientation fix.** Three ergonomics gaps surfaced building the
OCCTSwiftScripts cookbook recipes (pipe-flange, helical-spring, mounting-bracket). No C++ bridge
change — everything composes existing tested primitives.

- **#169 — feature-level circular pattern.** `circularPattern` duplicates the *body*, so the
  bolt-circle intent ("drill one hole, repeat it around the axis") produced overlapping flange
  copies with the holes filled in. New `Shape.circularPatternCut(tool:axisPoint:axisDirection:count:angle:)`
  patterns the *tool* and subtracts the compound in one call; `circularPattern`'s doc now warns it
  patterns the body, not features.

  ```swift
  let flange = blank.circularPatternCut(tool: hole, axisPoint: .zero,
                                        axisDirection: SIMD3(0,0,1), count: 8)
  ```

- **#170 — sweep orientation.** `Shape.sweep` (`BRepOffsetAPI_MakePipe`) could yield an
  inward-oriented (negative-volume) solid depending on the section wire's sense vs. the path
  tangent — a hazard for booleans and `volume > 0` checks. `sweep` now orientation-normalises its
  result. New `Shape.orientedForward()` applies the same fix explicitly, and `Shape.signedVolume`
  exposes the signed `BRepGProp` mass for orientation diagnostics (unlike `volume`, which masks
  negatives as `nil`).

- **#171 — geometric edge selection.** Picking fillet edges by raw `edges()` index is fragile —
  the index shifts with parameters. New selectors return edges that feed straight into
  `filleted(edges:radius:)`: `concaveEdges()` / `convexEdges()` (classified via `BRepOffset_Analyse`),
  `edges(where:)`, `edges(parallelTo:tolerance:)`, and `edges(inBounds:_:)`.

  ```swift
  let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
  ```


### v1.3.0 (June 2026) — full 4×4 XCAF component locations (closes #174)

**MINOR — additive new public API.** XCAF assembly components could previously only be placed by a
translation, so true instanced assemblies (shared geometry under arbitrary rigid transforms) lost
their rotations. `Document.addComponent(matrix:)` now accepts a full 4×4 placement (row-major 12),
and shape-driven instancing via `Shape.located(matrix:)` + `addShape(makeAssembly: true)` dedupes by
shared `TShape` so each unique solid is written once with N located occurrences.

### v1.2.2 (June 2026) — broaden OCC signal guards (#175)

**PATCH — robustness.** Extended `OSD::SetSignal` + `OCC_CATCH_SIGNALS` coverage to the validity,
volume, boolean, extrude, and revolve bridge paths (on top of v1.2.1's loft/mesh/transform guards),
so more degenerate-input failures surface as caught errors rather than aborting the process. Note:
`OCC_CATCH_SIGNALS` is a no-op unless `OCC_CONVERT_SIGNALS` is defined, and converting via
setjmp/longjmp bypasses C++ unwinding — so this hardens, but does not fully tame, deterministic
SIGSEGVs on degenerate machine-generated geometry (see #176).

### v1.2.1 (June 2026) — OCC signal handling on loft/mesh/transform (#175)

**PATCH — robustness.** Installed `OSD::SetSignal` and wrapped the loft (ThruSections), mesh, and
transform bridge entry points in `OCC_CATCH_SIGNALS` so OCCT hardware-signal faults on those paths
convert to catchable failures instead of crashing the caller.

### v1.2.0 (June 2026) — TopologyGraph attribute store + Codable snapshot (closes #168)

**MINOR — additive new public API.** `TopologyGraph` nodes were bare `(kind, index)` pairs with
no payload, and the type had no serialization (it wraps an opaque C++ handle). This adds a pure
Swift-side sidecar so callers can attach arbitrary typed metadata to any `NodeRef` and round-trip
it. No C++ bridge change — the store never touches the C++ graph.

```swift
extension TopologyGraph {
    public var attributes: NodeAttributeStore            // per-node typed metadata
    public func attribute(_ key: String, for: NodeRef) -> AttrValue?
    public func setAttribute(_ key: String, _ value: AttrValue, for: NodeRef)
    public func snapshot() throws -> GraphSnapshot        // export attributes + source shape
    public convenience init(snapshot: GraphSnapshot) throws  // rebuild + reattach
}
```

- `AttrValue` — closed Codable enum: `bool` / `int` / `double` / `string` / `ints` / `doubles`
  (`ints` for mesh-region index sets, `doubles` for fitted-surface params).
- `NodeAttributeStore` — Codable, keyed by `NodeRef`, encodes as sorted arrays so element order
  is deterministic; pair with `GraphSnapshot.canonicalEncoder()` (`.sortedKeys`) for byte-stable,
  diffable output.
- `GraphSnapshot` — Codable round-trip. The graph *structure* is not serialized; it is re-derived
  by rebuilding from the source shape's BREP (captured at construction). Rebuild pins
  `parallel: false`; a determinism test verifies `NodeRef` indexing is stable across rebuilds.
- `NodeKind` and `NodeRef` gained `Codable`.

Foundation for the [OCCTReconstruct](https://github.com/gsdali/OCCTReconstruct) mesh-to-solid
pipeline (per-node fit residual / confidence / provenance + session persistence) and for OCCTMCP's
planned `reconstruct_*` read/write graph tools ([OCCTMCP #33](https://github.com/gsdali/OCCTMCP/issues/33)).

### v1.1.0 (May 2026) — TopologyGraph history disambiguation (closes #167)

**First MINOR bump under the [cohort SemVer policy](SEMVER.md).** Two new methods on `TopologyGraph` resolve the ambiguity in `findDerived`'s empty-result case:

```swift
extension TopologyGraph {
    /// True iff any history record names `original` as a key.
    public func hasHistoryRecord(for original: NodeRef) -> Bool

    /// findDerived if non-empty; else [] for explicitly-deleted nodes;
    /// else [original] for untouched nodes (still at the same index).
    public func findDerivedOrSelf(of original: NodeRef) -> [NodeRef]
}
```

`findDerived` returned `[]` for both "untouched" and "explicitly deleted" — selection-remap consumers couldn't tell which. `findDerivedOrSelf` is the typical "where did this node end up?" lookup: a single deterministic call that returns derivatives, `[]` for deleted, or `[original]` for untouched. `hasHistoryRecord` is the lower-level disambiguator for callers that want to handle the cases differently at the call site.

Implementation is a Swift-side scan over `historyRecords` — O(records × originals-per-record), which is fine for typical scenes. A bridge-side accelerator can land later if profiling ever justifies it.

**Downstream impact:** [OCCTMCP v1.3.0](https://github.com/gsdali/OCCTMCP/releases/tag/v1.3.0) currently works around this with an `isIdentityPreserving` flag on its `HistoryRegistry` for `transform_body` / `heal_shape`. Once OCCTMCP picks up this OCCTSwift bump, it can drop the flag for ops that record explicit modify/delete records and use per-node resolution.

**Op count: 4,284 → 4,286** (+2). xcframework binary unchanged from v1.0.0.

### v1.0.4 (May 2026) — wire applyFillet / applyChamfer through *WithFullHistory (closes #166)

Closes the explicit follow-up to v1.0.3: `FeatureReconstructor.BuildResult.histories[id]` now also covers `FeatureSpec.Fillet` and `FeatureSpec.Chamfer` with non-nil ids — every spec kind now resolves through OCCT's recorded history instead of the centroid-distance heuristic on the consumer side.

**Behavior changes:**

- `applyFillet` for all three `EdgeSelector` cases (`.all`, `.nearPoint`, `.onFeature`) now uses `Shape.filletedWithFullHistory(radius:edges:)` and records the returned `ShapeHistoryRef` in `ctx.histories[id]`.
- `applyChamfer` does the same via `Shape.chamferedWithFullHistory(distance:edges:)`. **Chamfer's `.nearPoint` and `.onFeature` selectors are now wired up** — they were stubbed to `recordSkip(.unsupported)` in v1.0.3 and earlier.
- Each path falls back to the index-less primitive (`filleted(radius:)` / `chamfered(distance:)`) on builder-nil to preserve existing back-compat semantics. Specs without ids continue to land directly on the non-history path.

**Internals:** the per-selector helpers now return `[Int]?` matching-edge-index lists instead of pre-cooked `Shape?` results. This consolidates the resolution machinery between fillet and chamfer (chamfer used to duplicate fillet's `.all`-only path because it had no shared resolver). The OCCTSwiftIO and OCCTMCP-side consumers that read `BuildResult.histories[id]` get fillet / chamfer coverage without any code change.

**Out of scope:** variable-radius fillet via `FeatureSpec` (the `filletedWithFullHistory(edge:startRadius:endRadius:)` Tier 2 variant) — `FeatureSpec.Fillet` only carries one `radius`. Variable-radius would be a new spec variant.

### v1.0.3 (May 2026) — full per-input history Tier 2 & Tier 3 (issue #165)

Completes [#165](https://github.com/gsdali/OCCTSwift/issues/165). Builds on the boolean-history surface in v1.0.2 by extending it to modification ops and threading history capture through `FeatureReconstructor`.

**Tier 2 — modification ops with full history (+5 ops):**

```swift
extension Shape {
    func filletedWithFullHistory(radius: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    func filletedWithFullHistory(edge: Int, startRadius: Double, endRadius: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    func chamferedWithFullHistory(distance: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    func shelledWithFullHistory(facesToRemove: [Int], thickness: Double, tolerance: Double = 1e-3)
        -> (result: Shape, history: ShapeHistoryRef)?
    func defeaturedWithFullHistory(faces: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
}
```

All five reuse the existing `OCCTBooleanHistory` opaque handle (the underlying type stores a `unique_ptr<BRepBuilderAPI_MakeShape>`, which is the common base of every OCCT modification builder). For consumers, the API matches Tier 1 — `history.record(of: inputSubShape)` returns the `ShapeHistoryRecord` of `Modified` / `Generated` / `IsDeleted` lookups.

**Tier 3 — `FeatureReconstructor.BuildResult.histories`:**

```swift
public struct BuildResult: Sendable {
    // … existing fields …
    public let histories: [String: ShapeHistoryRef]
}
```

Per-feature `ShapeHistoryRef` keyed by the feature id. Populated when:
- A boolean spec (`FeatureSpec.Boolean`) with non-nil id resolves successfully — captured from `unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory`
- A hole spec (`FeatureSpec.Hole`) with non-nil id — captured from the underlying subtract
- An additive feature (revolve/extrude/sheet-metal) with non-nil id whose `absorbAdditive` step fuses into a non-empty `current` — captured from the union

Features without an id aren't keyed, and the existing `applyFillet` / `applyChamfer` paths still go through the non-history primitives (those cases need edge/face index computation that's tracked as a separate refinement).

This unblocks [OCCTMCP](https://github.com/gsdali/OCCTMCP)'s `remap_selection` for the `apply_feature` tool: instead of falling back to centroid-distance heuristics on splits / merges / deletions, the consumer can now walk `BuildResult.histories[feature_id].record(of: subshape)` for the exact OCCT-recorded mapping.

**Op count: 4,279 → 4,284** (+5 Tier 2 entry points). xcframework binary unchanged from v1.0.0; SPM consumers continue to resolve against the v1.0.0 asset.

### v1.0.2 (May 2026) — per-input boolean history (issue #165 Tier 1)

**Additive feature for selection-remapping consumers** ([#165](https://github.com/gsdali/OCCTSwift/issues/165)). Adds a per-input-subshape history lookup surface to the four `BRepAlgoAPI` boolean ops, addressing OCCTMCP's `remap_selection` need to walk selection IDs across boolean / split mutations exactly (instead of the centroid-distance heuristic that loses on splits / merges / deletions):

```swift
extension Shape {
    func unionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func subtractedWithFullHistory(_ tool: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func intersectionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func splitWithFullHistory(by tool: Shape) -> (pieces: [Shape], history: ShapeHistoryRef)?
}

public final class ShapeHistoryRef: @unchecked Sendable {
    func record(of inputSubShape: Shape) -> ShapeHistoryRecord  // .modified / .generated / .isDeleted
}
```

The `ShapeHistoryRef` retains the OCCT builder so `Modified` / `Generated` / `IsDeleted` stay queryable after the operation completes. Existing `BooleanResult` / `BooleanHistoryResult` callers are unchanged — pure additive surface.

**Bug fix on the way.** While building the history-handle plumbing I found that the new probe-then-fill helpers returned `0` when called with `maxCount=0` (or `outRefs=null`), breaking the Swift-side count-then-allocate idiom. Fixed: the new bridge functions now always return the full count and only stop *writing* when `count >= maxCount`. Existing callers were unaffected (none used the probe path).

xcframework binary unchanged from v1.0.0 (no OCCT version change). SPM consumers continue to resolve against the v1.0.0 asset.

**Out of scope for this release** (will land in follow-ups under #165 Tiers 2 / 3): `filletedWithFullHistory` / `chamferedWithFullHistory` / `shelledWithFullHistory` / `defeaturedWithFullHistory`, and `FeatureReconstructor.BuildResult.history`.

### v1.0.1 (May 2026) — TopologyGraph.rootNodes fix + test repair

**Bug fix.** `TopologyGraph.NodeKind` was missing `product = 10` and `occurrence = 11` cases, so `rootNodes` silently returned `[]` even when products were present (`compactMap { NodeKind(rawValue: 10) }` filtered every entry out as `nil`). After OCCT 8.0.0 beta1 reshaped root iteration to "Products only", every `rootNodes` consumer hit this. Fixed by extending the enum to cover the full `BRepGraph_NodeId::Kind` range (topology 0–8, assembly 10–11; slot 9 reserved upstream).

**Tests.** The four pre-existing failures shipped with v1.0.0 are repaired:

- `hasRoots` and `childExplorer` now wrap the box's solid in a Product via `linkProductToTopology` before querying `rootNodes` (matches OCCT 8.0 GA assembly semantics).
- `edgeVertexDistance` switched from low-level `BRepExtrema_DistanceSS` (which deliberately skips edge-vertex pairs whose closest point is at an endpoint, expecting the caller to also pair vertices-with-vertices) to high-level `Shape.distance(to:)` backed by `BRepExtrema_DistShapeShape`, which orchestrates all subshape combinations including endpoint cases.
- `edgeSelectorFeatureUnsupported` deleted — it asserted `Fillet.onFeature` was unsupported, contradicting the newer `filletOnFeature` test that asserts the opposite. `.onFeature` is wired up in `FeatureReconstructor`.

xcframework binary is unchanged from v1.0.0; SPM consumers continue resolving against the v1.0.0 asset.

### v1.0.0 (May 2026) — OCCT 8.0.0 GA — SemVer-stable

**OCCTSwift reaches SemVer-stable v1.0.0**, pinned to **OpenCASCADE Technology 8.0.0 GA** (released 2026-05-07, commit `d3056ef8` on `Open-Cascade-SAS/OCCT`). After eight months of pre-1.0 development across 170+ point releases — wrapping ~4,275 OCCT operations across 1,160+ test suites — the public Swift API is stable from this point on. Pin to `from: "1.0.0"` in `Package.swift`.

**OCCT 8.0.0 GA highlights since rc5** (per [OCCT discussion #1275](https://github.com/Open-Cascade-SAS/OCCT/discussions/1275)):

- BRepGraph (graph-based topology) and Gordon Surfaces shipped in their final shape
- TKHelix toolkit (geometric helix with B-spline approximation)
- ExtremaPC specialized point-to-curve extrema with variant dispatching
- STEP read/write thread safety: "safe under the contract of one reader or writer per thread"
- Multiple SEGV fixes in chamfer, fillet, and pipe-shell operations
- BSpline evaluation bugs corrected; geometry hashing implementations completed
- C++17 minimum (already required by Swift 6); `Standard_Failure` inherits `std::exception`

**Beta2 → GA breaking changes absorbed in this release:**

- **`PointSetLib` removed.** OCCT introduced `PointSetLib_Props` / `PointSetLib_Equation` in 8.0.0 beta1 (rc5/PCA point-cloud analysis) and removed them before GA. The Swift `PointSetLib` enum and bridge wrappers were deleted to follow upstream. If you depended on `PointSetLib.properties / barycentre / inertiaMatrix / equation`, port to your own NumPy/Accelerate implementation; the OCCT primitives are no longer available at any layer.
- **CoEdge continuity setters consolidated into `setEdgeRegularity`.** OCCT 8.0.0 GA moved continuity from per-coedge to per-`(edge, face1, face2)` (in `BRepGraph_LayerRegularity`). The pre-GA `setCoEdgeContinuity` / `setCoEdgeSeamContinuity` / `setCoEdgeSeamPairId` are replaced by a single `TopologyGraph.setEdgeRegularity(_:face1:face2:continuity:) -> Bool`. For seam continuity, pass the same face index as `face1` and `face2`. Explicit seam-pair-id is gone — seam-pair-id is structural in GA (two coedges on the same edge/face with opposite orientations); query via the existing `coedgeSeamPair` accessor.

**Removed deprecated:**

- **`TopologyGraph.occurrenceParentOccurrence(_:)`** — deprecated in v0.157.0 when OCCT 8.0.0 beta1 reshaped assembly topology to `Product → Occurrence → Product`. Use `occurrenceParentProduct(_:)`.

**Looking ahead:** OCCTSwift now moves to a **work-on-branch strategy** for upstream OCCT changes; `main` stays release-quality. Future OCCT releases land in feature branches and graduate to a tagged OCCTSwift release only when the upstream is GA.

### v0.171.0 (May 2026) — ML-export hoist to OCCTSwiftIO

**Breaking change.** The consumption-side ML repacking layer added in v0.136.0 (`TopologyGraph.GraphExport`, `exportForML()`, `exportJSON()`) has been removed and lifted to [OCCTSwiftIO](https://github.com/gsdali/OCCTSwiftIO) v0.2.0 per [OCCTSwiftIO#1](https://github.com/gsdali/OCCTSwiftIO/issues/1) (supersedes [OCCTSwift#71](https://github.com/gsdali/OCCTSwift/issues/71)). It's pure batch / headless workflow with no Viewport dependency — fits the OCCTSwiftIO charter, doesn't need to live in the kernel.

**What stays in the kernel** (and why): `FaceGridSample`, `sampleFaceUVGrid(faceIndex:uSamples:vSamples:)`, and `sampleEdgeCurve(edgeIndex:count:)`. Their implementations call C bridge functions on `TopologyGraph.handle`, which is `internal` to this module. Lifting them would require widening visibility — explicitly out of scope per the partial-lift decision recorded on the issue.

**Consumer migration:** direct callers of `exportForML` / `exportJSON` must add `import OCCTSwiftIO` alongside `import OCCTSwift`. Symbol resolution otherwise unchanged. Known external callers swept: `OCCTSwiftScripts/Sources/occtkit/Commands/GraphML.swift`, `OCCTSwiftScripts/Sources/GraphML/main.swift`.

**Net deltas:** −124 LOC in `BRepGraph.swift`, −76 LOC in `ShapeTests.swift`. xcframework binary unchanged (no bridge changes).

### v0.170.1 (May 2026) — ShapeMeasurements kernel hoist + OCCTBridge.mm split complete

**ShapeMeasurements moved to kernel** ([#100](https://github.com/gsdali/OCCTSwift/issues/100), [PR #163](https://github.com/gsdali/OCCTSwift/pull/163)). `ShapeMeasurements` (per-face areas / centroids / perimeters + per-edge lengths) and `Shape.measure(linearTolerance:)` are now part of `OCCTSwift` itself, no longer requiring a dependency on `OCCTSwiftTools`. Pure Swift relocation — no bridge changes. Existing `OCCTSwiftTools.ShapeMeasurements` callers should re-target to `import OCCTSwift` once `OCCTSwiftTools` ships its dep bump (tracked in [OCCTSwiftTools#13](https://github.com/gsdali/OCCTSwiftTools/issues/13)).

**OCCTBridge.mm split — DONE** ([#99](https://github.com/gsdali/OCCTSwift/issues/99), PRs #160-#162). The monolithic `OCCTBridge.mm` is now **393 lines** of pure foundation (header includes, global mutex, `OCCTSewing` struct, `Internal.h` import) — down from 58,168 lines pre-split (−99.3%). All 4,281 operations live in 15 per-OCCT-module translation units (`OCCTBridge_Modeling.mm`, `OCCTBridge_Topology.mm`, `OCCTBridge_Healing.mm`, `OCCTBridge_Properties.mm`, `OCCTBridge_Geom2d.mm`, `OCCTBridge_Surface.mm`, `OCCTBridge_Curve3D.mm`, `OCCTBridge_Document.mm`, `OCCTBridge_IO.mm`, `OCCTBridge_Mesh.mm`, `OCCTBridge_Spatial.mm`, `OCCTBridge_BRepGraph.mm`, `OCCTBridge_AIS.mm`, `OCCTBridge_Visualization.mm`, `OCCTBridge_ProjLib_NLPlate.mm`). Net-zero behavior change throughout; public C surface unchanged. The xcframework binary is identical to v0.170.0 (no OCCT changes), so SPM consumers can continue using the v0.170.0 binary URL.

### v0.170.0 (May 2026) — OCCT 8.0.0-beta2 ingest

xcframework rebuilt against `V8_0_0_beta2`. No public API changes — beta2 is a small follow-up to beta1 with no API breakage. Final 8.0.0 release remains targeted for May 7, 2026.

Upstream changes that landed in beta2:

- **Thread-safe STEP write + STEP/IGES read** ([OCCT #1259](https://github.com/Open-Cascade-SAS/OCCT/pull/1259)) — fixes `libmalloc` double-free under concurrent `STEPControl_Writer::Transfer` and intermittent crashes in concurrent STEP/IGES readers. Contract: one reader/writer per thread; STEP read + write safe under that contract; IGES read still requires explicit serialization. OCCTSwift already serializes IGES via `igesMutex()` and STEP via `occtGlobalMutex()`, so the upstream fix is a net safety improvement without requiring bridge changes.
- **CPU grid path restored** ([OCCT #1252](https://github.com/Open-Cascade-SAS/OCCT/pull/1252)) — the classical `Graphic3d_Structure`-based grid removed in beta1 is back as a coexisting backend. Doesn't surface in OCCTSwift (no grid API exposed).
- **Documentation refresh + samples directory + CI warning cleanup** — internal to upstream; no impact on consumers.

OCCTSwift surface unchanged: 4,281 wrapped operations, 3,393 tests, 1,178 suites, identical Swift `OCCTSwift.*` API.

### v0.169.0 (May 2026) — Mesh + export progress (issue #98 follow-up)

Extends the `ImportProgress` channel from v0.168 to two more long-running OCCT operations called out as out-of-scope in the original issue: `BRepMesh_IncrementalMesh::Perform` and the STEP / IGES writers. Same protocol, same cancellation contract.

**New Swift API**:

```swift
extension Shape {
    /// Run BRepMesh_IncrementalMesh with progress + cooperative cancellation.
    /// Throws ImportError.cancelled if cancelled.
    @discardableResult
    public func meshWithProgress(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5,
        progress: ImportProgress? = nil
    ) throws -> Shape
}

extension Exporter {
    /// Export a shape to STEP with progress + cancellation.
    /// Throws ExportError.cancelled if cancelled.
    public static func writeSTEP(shape: Shape, to url: URL, progress: ImportProgress?) throws

    /// Export a shape to IGES with progress + cancellation.
    public static func writeIGES(shape: Shape, to url: URL, progress: ImportProgress?) throws
}

extension Document {
    /// Write the document to a STEP file with progress + cancellation.
    /// Throws ImportError.cancelled if cancelled.
    public func writeSTEP(to url: URL, progress: ImportProgress?) throws
}

extension ExportError {
    case cancelled
}
```

**Bridge plumbing**: 5 new entry points (`OCCTShapeIncrementalMeshProgress`, `OCCTExportSTEPProgress`, `OCCTExportSTEPWithModeProgress`, `OCCTExportIGESProgress`, `OCCTDocumentWriteSTEPProgress`) reusing the existing `BridgeProgressIndicator` from v0.168. `BRepMesh_IncrementalMesh::Perform(Message_ProgressRange&)`, `STEPControl_Writer::Transfer(...range)`, `IGESControl_Writer::AddShape(...range)`, and `STEPCAFControl_Writer::Transfer(...range)` all accept the indicator's progress range.

**Why `ImportProgress` is the type for export too**: it's the same channel — progress + cancel. Adding parallel `ExportProgress`/`MeshProgress` protocols would multiply types without functional benefit. The protocol name reads slightly oddly in export contexts; pre-1.0 we accept that, and v1.0 will likely rename to `OperationProgress`.

6 new tests cover meshing progress + cancellation, STEP/IGES export with `progress: nil` (back-compat), STEP export progress fires, and `Document.writeSTEP(to:progress:)` round-trip.

### v0.168.0 (May 2026) — STEP/IGES import progress + cancellation (issue #98)

Wraps OCCT's `Message_ProgressIndicator` so callers of `Shape.loadSTEP / loadIGES / loadIGESRobust` and `Document.load / loadSTEP` can observe progress and cooperatively cancel long-running imports.

**New Swift API**:

```swift
public protocol ImportProgress: AnyObject, Sendable {
    func progress(fraction: Double, step: String)
    func shouldCancel() -> Bool   // default: false
}

extension ImportError {
    case cancelled
}

extension Shape {
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Shape
    public static func loadSTEP(from url: URL, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape
    public static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> Shape
    public static func loadIGESRobust(from url: URL, progress: ImportProgress? = nil) throws -> Shape
}

extension Document {
    public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Document
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Document
    public static func loadSTEP(from url: URL, modes: STEPReaderModes, progress: ImportProgress?) throws -> Document
}
```

`progress: nil` (the default) keeps existing call sites source-compatible — no behavioural change for callers that haven't opted in.

**Bridge plumbing**: 7 new `*Progress` C entry points in `OCCTBridge` plus an internal `BridgeProgressIndicator` subclass of `Message_ProgressIndicator` that forwards `Show()` to a Swift callback (via opaque `userData` + `@convention(c)` trampoline) and reports `UserBreak() == true` when the Swift `shouldCancel()` returns true. `STEPControl_Reader::TransferRoots`, `IGESControl_Reader::TransferRoots`, and `STEPCAFControl_Reader::Transfer` all accept the indicator's progress range.

**Cancellation contract**: `shouldCancel()` is polled at OCCT's progress checkpoints (typically once per transferred entity). Returning `true` causes the loader to throw `ImportError.cancelled` at the next boundary. The shape / document is not partially constructed.

4 new tests cover (1) progress callback fires for a round-tripped STEP file, (2) `progress: nil` back-compat path still works, (3) cancellation flag honored, (4) `Document.load` progress.

**Driver**: unblocks [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) v0.4.0 — its `CADFileLoader.load(from:format:)` async API can now pass `progress` straight through, giving OCCTSwiftAIS' file-open dialog a real progress bar and cancel button "for free".

### v0.167.0 (May 2026) — visionOS + tvOS support

OCCT.xcframework now ships **seven slices**:

| Platform | Slice |
|---|---|
| macOS 12+ arm64 | `macos-arm64` |
| iOS 15+ device arm64 | `ios-arm64` |
| iOS 15+ Simulator arm64 | `ios-arm64-simulator` |
| visionOS 1+ device arm64 | `xros-arm64` (new) |
| visionOS 1+ Simulator arm64 | `xros-arm64-simulator` (new) |
| tvOS 15+ device arm64 | `tvos-arm64` (new) |
| tvOS 15+ Simulator arm64 | `tvos-arm64-simulator` (new) |

`Package.swift` declares `.visionOS(.v1)` and `.tvOS(.v15)` alongside the existing `.iOS(.v15)` / `.macOS(.v12)`. The xcframework asset attached to this release is ~341 MB (up from 148 MB at v0.165.0; quadruples the slice count).

**Build script changes** (`Scripts/build-occt.sh`) — required to make OCCT 8 cross-compile cleanly to visionOS and tvOS SDKs:

- Added four new build blocks (`visionOS device`, `visionOS Simulator`, `tvOS device`, `tvOS Simulator`).
- Each new block sets `-DCMAKE_SIZEOF_VOID_P=8` to bypass OCCT's `OCCT_MAKE_COMPILER_BITNESS` cmake macro, which couldn't autodetect pointer size on the visionOS SDK (`32 + 32*(/8)` syntax error from an empty `CMAKE_C_SIZEOF_DATA_PTR`).
- Removed explicit `-mtargetos=` / `-m*-version-min=` flags from the C/CXX flags — clang rejects them when CMake already sets `--target=arm64-apple-xros1.0` from the SDK + deployment target. Letting CMake derive the target is the correct path.
- xcframework creation step now conditionally includes each platform slice: if a slice fails to build (empty `.a`), the xcframework is built without it instead of aborting the whole script.

`OCCT.xcframework.zip` checksum: `5147b7d65cd9af5a6c3af1b38a1492365e645ed5c76a663bf9311c2f54043d87`.

### v0.166.1 (May 2026) — Platform plan refinement

Metadata-only patch revising the v1.0.0 platform expansion plan:

- **Dropped Intel Mac (`macOS x86_64`).** Apple is winding down Intel macOS support; not worth the build slot.
- **visionOS confirmed for v1.0.0.** Device + simulator slices.
- **tvOS reduced to "if cheap".** Will only add if it falls out of the visionOS work without extra effort.
- **Linux / Windows / Android — moved to "under review"** with a full analysis in [docs/platform-expansion.md](../docs/platform-expansion.md). Headline: Linux is the strongest non-Apple candidate (~2 weeks of focused work), Windows is medium-risk, Android should wait for Swift-on-Android packaging to stabilize. The prerequisite for any non-Apple port is the OCCTBridge `.mm` → `.cpp` audit, which is independently useful.

### v0.166.0 (May 2026) — Swift Package Index readiness

Preparation for a public listing on [Swift Package Index](https://swiftpackageindex.com) alongside v1.0.0. No code changes; metadata only.

**Added:**

- `.spi.yml` — SPI build matrix declaration:
  - macOS via SPM on Swift 6.0, 6.1, 6.2, 6.3
  - iOS on Swift 6.3
  - DocC documentation target: `OCCTSwift`
- `CODE_OF_CONDUCT.md` — short pointer to Contributor Covenant 2.1 with reports email.
- README:
  - SPI shields.io badges (Swift versions, platforms) — activate once the package is added to SPI.
  - Updated install snippet from stale `from: "0.128.0"` to current `from: "0.165.0"`.
  - "Supported Platforms" table covering current support and v1.0.0 expansion plan (Intel Mac, visionOS).
  - Documented Swift 6.1+ verified clean against 6.1 / 6.2 / 6.3 toolchains.

**Submission gating:** waiting until v1.0.0 ships (May 7, 2026, alongside OCCT 8.0.0 GA) before submitting to SPI. v0.166 makes the repo submission-ready.

### v0.165.0 (May 2026) — Fix SPM xcframework URL (issue #97)

`Package.swift` had its remote `binaryTarget(url:)` hardcoded to the **v0.131.0** xcframework — predating OCCT 8 by months. SPM consumers pinning `from: "0.157.0"` resolved the version correctly but the build failed at compile-time with `'BRepGraph_MeshView.hxx' file not found` because the v0.131.0 binary was built against rc-era OCCT and didn't ship the beta1 headers that the v0.157+ wrappers reference. Local-path consumers were unaffected (the auto-detect picks up `Libraries/OCCT.xcframework`).

This release:

1. Attaches the current beta1 xcframework as a release asset (`OCCT.xcframework.zip`, ~148 MB).
2. Updates `Package.swift`'s remote URL to point at the v0.165.0 release and bumps the SPM checksum to `99bba63c0e686195512cfaa4f3f46f9f11c8b6cd89e8fe5b8aed872a48978003`.

After this release, `from: "0.165.0"` resolves cleanly for remote-pin consumers and the v0.157.0 → v0.164.0 wrapper surface (MeshView, MeshCache, EditorView mutation, ProductOps, RepOps + cache inspection) becomes usable downstream. Downstream Package.swift consumers should bump their pin to `from: "0.165.0"`.

No new ops; this is purely a packaging fix.

### v0.164.0 (May 2026) — RepOps non-guard setters & cache entry inspection (21 ops)

Final wrapping pass for OCCT 8.0.0 beta1 BRepGraph surface. After this release, the public surface of `BRepGraph::EditorView` and `BRepGraph::MeshView` is exhaustively wrapped on `TopologyGraph`.

**RepOps non-guard setters** — swap geometry / mesh content bound to an existing rep id without recreating the rep:

```swift
graph.repSetSurface(repId, surface: newSurface)
graph.repSetCurve3D(repId, curve: newCurve3D)
graph.repSetCurve2D(repId, curve: newCurve2D)
graph.repSetTriangulation(repId, triangulation: newTri)
graph.repSetPolygon3D(repId, polygon: newPoly3D)
graph.repSetPolygon2D(repId, polygon: newPoly2D)
graph.repSetPolygonOnTri(repId, polygon: newPolyOnTri)
graph.repSetPolygonOnTriTriangulationId(polyOnTriRepId, triRepId: newTriRepId)
```

**Cache entry inspection** — detailed access to the algorithm-derived cache tier for diagnostics and non-destructive mesh tooling:

```swift
graph.cachedFaceMeshIsPresent(0)              // Bool
graph.cachedFaceMeshTriRepCount(0)            // Int
graph.cachedFaceMeshActiveIndex(0)            // Int (-1 if absent)
graph.cachedFaceMeshStoredOwnGen(0)           // UInt32 (cache freshness gen)
graph.cachedFaceMeshTriRepId(0, repIndex: 0)  // Int? (active or specific entry)

graph.cachedEdgeMeshIsPresent(0)
graph.cachedEdgeMeshPolygon3DRepId(0)
graph.cachedEdgeMeshStoredOwnGen(0)

graph.cachedCoEdgeMeshIsPresent(0)
graph.cachedCoEdgeMeshPolygon2DRepId(0)
graph.cachedCoEdgeMeshPolygonOnTriRepCount(0)
graph.cachedCoEdgeMeshPolygonOnTriRepId(0, repIndex: 0)
graph.cachedCoEdgeMeshStoredOwnGen(0)
```

The `StoredOwnGen` accessors expose the cache freshness generation — pair with the entity's current OwnGen (via existing readers) to detect stale cache entries.

3 new tests cover fresh-graph absence, post-`appendCachedTriangulation` state readback, and edge/coedge cache absence.

### v0.163.0 (May 2026) — EditorView ProductOps assembly building (5 ops)

Closes the **EditorView mutation surface**. With v0.163.0 the public mutation API of `BRepGraph::EditorView` is fully wrapped on `TopologyGraph`.

```swift
let parent = graph.createEmptyProduct()!
let child = graph.linkProductToTopology(
    shapeRootKind: 0, shapeRootIndex: 0,
    placement: TopologyGraph.identityLocationMatrix)!
let linked = graph.linkProducts(
    parentProductIndex: parent,
    referencedProductIndex: child,
    placement: TopologyGraph.identityLocationMatrix)!
// linked.occurrenceIndex, linked.occurrenceRefIndex

graph.productRemoveOccurrence(parent, occurrenceRefIndex: linked.occurrenceRefIndex)
graph.productRemoveShapeRoot(child)
```

`linkProductToTopology` accepts `placement: nil` for an identity placement. `linkProducts` takes a `parentOccurrenceIndex: Int?` (nil for unparented).

2 new tests cover the create/link path and remove-with-bogus-ids no-crash safety.

### v0.162.0 (May 2026) — EditorView geometric setters, location setters, PCurve API (16 ops)

Closes the EditorView wrapping started in v0.159.0. With v0.162.0 the public mutation surface of `BRepGraph::EditorView` is fully wrapped on `TopologyGraph`.

**CoEdge geometric setters:**
- `setCoEdgeUVBox(_:u1:v1:u2:v2:)`
- `setCoEdgeContinuity` / `setCoEdgeSeamContinuity` (GeomAbs_Shape: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN)
- `setCoEdgeSeamPairId`

**Face geometric setter:**
- `setFaceTriangulationRep(_:triRepId:)` — bind the active triangulation to a face's persistent tier (vs `appendCachedTriangulation` for the cache tier)

**CoEdge PCurve API** (uses existing `Curve2D` Swift type):
- `coEdgeCreateCurve2DRep(_ curve2D:)` → rep id
- `coEdgeSetPCurve(_ coedgeIndex:curve2D:)` (pass nil to clear)
- `coEdgeAddPCurve(edgeIndex:faceIndex:curve2D:first:last:orientation:)`

**Location setters via 12-double 3x4 matrix** (`gp_Trsf::SetValues` row-major convention):
- `setVertexRefLocalLocation`, `setCoEdgeRefLocalLocation`, `setWireRefLocalLocation`
- `setFaceRefLocalLocation`, `setShellRefLocalLocation`, `setSolidRefLocalLocation`
- `setOccurrenceRefLocalLocation`, `setChildRefLocalLocation`
- Convenience: `TopologyGraph.identityLocationMatrix` returns the 3x4 identity

3 new tests cover CoEdge geometric setters on real coedges, identity-matrix location setters on real refs, and face-triangulation binding with MeshView readback.

### v0.161.0 (May 2026) — EditorView Add / Remove / Ref setters (41 ops)

Continues the EditorView wrapping started in v0.159.0 with the structural-mutation surface:

**Add operations** (return ref id or nil):
- `edgeAddInternalVertex(_:vertexIndex:orientation:)`
- `faceAddVertex(_:vertexIndex:orientation:)`
- `shellAddChild(_:childKind:childIndex:orientation:)`
- `solidAddChild(_:childKind:childIndex:orientation:)`
- `compoundAddChild(_:childKind:childIndex:orientation:)`
- `compSolidAddSolid(_:solidIndex:orientation:)`

**Remove operations** (return Bool indicating active-usage removal):
- `edgeRemoveVertex`, `edgeReplaceVertex` (returns new ref id)
- `wireRemoveCoEdge`, `faceRemoveVertex`, `faceRemoveWire`
- `shellRemoveFace`, `shellRemoveChild`
- `solidRemoveShell`, `solidRemoveChild`
- `compoundRemoveChild`, `compSolidRemoveSolid`
- `removeRep(repKind:repIndex:)` — generic representation removal

**Ref setters** (entity-ref → entity-def rebinding, orientation, rep-id binding):
- Vertex: `setVertexRefOrientation`, `setVertexRefVertexDefId`
- Edge: `setEdgeStartVertexRefId`, `setEdgeEndVertexRefId`, `setEdgeCurve3DRepId`, `setEdgePolygon3DRepId`
- CoEdge: `setCoEdgeRefCoEdgeDefId`, `setCoEdgeEdgeDefId`, `setCoEdgeFaceDefId`, `setCoEdgeCurve2DRepId`, `setCoEdgePolygon2DRepId`, `setCoEdgePolygonOnTriRepId`, `clearCoEdgePCurveBinding`
- Wire: `setWireRefIsOuter`, `setWireRefOrientation`, `setWireRefWireDefId`
- Face: `setFaceSurfaceRepId`, `setFaceRefOrientation`, `setFaceRefFaceDefId`
- Shell: `setShellRefOrientation`, `setShellRefShellDefId`
- Solid: `setSolidRefOrientation`, `setSolidRefSolidDefId`
- Occurrence: `setOccurrenceChildDefId`, `setOccurrenceRefOccurrenceDefId`
- Generic: `setChildRefOrientation`, `setChildRefChildDefId`

Setters that need `TopLoc_Location` or `Bnd_Box2d` (e.g. `*RefLocalLocation`, `CoEdge.SetUVBox`, `CoEdge.SetContinuity`) are deferred until a 12-double / 4-double calling convention lands in the bridge.

3 new tests cover Add no-crash safety, Remove returning false on bogus ref ids, and Ref setters operating on real box ids without crashing.

### v0.160.0 (May 2026) — MeshCache write API + new `Triangulation` type

Completes the OCCT 8.0.0 beta1 two-tier mesh storage wrapping started in v0.158.0. The cache write side — `BRepGraph_Tool::Mesh` static helpers — is now exposed on `TopologyGraph`, and a new `Triangulation` Swift class wraps `Handle<Poly_Triangulation>` for input.

**New `Triangulation` class** (mirrors the existing `Polygon3D` / `PolygonOnTriangulation` pattern):

```swift
let tri = Triangulation.create(
    nodes: [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0), SIMD3(1,1,0)],
    triangles: [0,1,2, 1,3,2]
)!
tri.nodeCount        // 4
tri.triangleCount    // 2
tri.node(at: 0)      // SIMD3(0, 0, 0)
tri.triangle(at: 0)  // (0, 1, 2)
tri.deflection = 0.01
```

Vertex indices are 0-based on the Swift boundary; the bridge handles OCCT's 1-based convention internally.

**MeshCache write API** on `TopologyGraph`:

```swift
let triRepId = graph.createTriangulationRep(tri)!
graph.appendCachedTriangulation(faceIndex: 0, triRepId: triRepId)
graph.setCachedActiveIndex(faceIndex: 0, activeIndex: 0)

let polyRepId = graph.createPolygon3DRep(polygon3d)!
graph.setCachedPolygon3D(edgeIndex: 0, polyRepId: polyRepId)

let polyOnTriRepId = graph.createPolygonOnTriRep(polygonOnTri, triRepId: triRepId)!
graph.appendCachedPolygonOnTri(coedgeIndex: 0, polyRepId: polyOnTriRepId)
graph.setCachedPolygon2D(coedgeIndex: 0, poly2DRepId: ...)
```

This unblocks downstream tooling (OCCTMCP, OCCTSwiftScripts) that wants to populate algorithm-derived mesh data on a graph without touching the persistent (STEP-imported) tier — important for non-destructive meshing workflows.

4 new tests cover Triangulation construction round-trip, malformed-input rejection, and rep-creation + face/edge binding with subsequent MeshView readback.

### v0.159.0 (May 2026) — EditorView field setters

OCCT 8.0.0 beta1's `BRepGraph::EditorView` exposes per-entity `Ops` classes with `Set*` methods that mutate field-level data on existing graph entities (without requiring a full topology rebuild). v0.159.0 wraps the simple-value subset (scalars, bools, orientations) on the `TopologyGraph` Swift type:

**VertexOps** — `setVertexPoint(_:x:y:z:)`, `setVertexTolerance(_:tolerance:)`

**EdgeOps** — `setEdgeTolerance`, `setEdgeParamRange(_:first:last:)`, `setEdgeSameParameter`, `setEdgeSameRange`, `setEdgeDegenerate`, `setEdgeIsClosed`

**CoEdgeOps** — `setCoEdgeParamRange`, `setCoEdgeOrientation` (Forward/Reversed/Internal/External as Int 0–3)

**WireOps** — `setWireIsClosed`

**FaceOps** — `setFaceTolerance`, `setFaceNaturalRestriction`

**ShellOps** — `setShellIsClosed`

All 14 setters are pass-through to the corresponding `g.Editor().<Entity>().Set*(...)` on the OCCT side. Invalid ids are no-ops (try/catch in bridge). Setters that require new opaque types — `SetPCurve`, `SetSurfaceRepId`, `SetTriangulationRep`, `Mut*` RAII guards — are deferred. Same with `Add*` / `Remove*` mutation methods that aren't already wrapped via the Builder bridge functions.

Driver: lets headless tooling (OCCTMCP, OCCTSwiftScripts) tweak field-level data after constructing a graph (e.g. relax a tolerance, mark an edge degenerate) without round-tripping through `TopoDS_Shape` rebuilds.

4 new tests cover set-then-read-back where a getter exists, plus no-crash safety on the readback-less setters.

### v0.158.0 (May 2026) — MeshView two-tier mesh storage (read API)

OCCT 8.0.0 beta1 introduced a two-tier mesh storage model: an algorithm-derived **cache** (populated by `BRepGraphMesh`) and the **persistent** tier (mesh data imported from STEP, stored in topology definitions). v0.158.0 wraps the read-side of this model — `BRepGraph::MeshView` queries — exposing it on the existing `TopologyGraph` Swift type:

- Counts: `polygon2DCount`, `polygonOnTriCount`, `activeTriangulationCount`, `activePolygon3DCount`, `activePolygon2DCount`, `activePolygonOnTriCount`. Pairs with the existing `triangulationCount` / `polygon3DCount` from v0.133.0.
- Per-entity cache-first queries:
  - `meshFaceActiveTriangulationRepId(_ faceIndex:)` → optional rep id (cache-first, persistent fallback)
  - `meshEdgePolygon3DRepId(_ edgeIndex:)` → optional rep id (cache-first, persistent fallback)
  - `meshCoEdgeHasMesh(_ coedgeIndex:)` → bool (cache-only)

The Swift API is unchanged for existing call sites. Driver: prep for future BRepGraphMesh-driven workflows in OCCTMCP / OCCTSwiftScripts that want to introspect mesh state without invalidating the persistent tier.

The mesh **write** API (`BRepGraph_Tool::Mesh::CreateTriangulationRep` etc.) is intentionally not yet wrapped — it requires marshaling `Handle<Poly_Triangulation>` from Swift, which is a larger lift. Targeted for v0.159 or v1.0.

### v0.157.0 (May 2026) — OCCT 8.0.0 beta1 support (final pre-1.0 release)

xcframework rebuilt against `V8_0_0_beta1`. v1.0.0 will follow on May 7, 2026 pinned to the OCCT 8.0.0 GA tag.

Bridge migrations driven by upstream API churn since rc5:

- **`BRepGraph_BuilderView` removed** ([OCCT #1237](https://github.com/Open-Cascade-SAS/OCCT/pull/1237)) → migrated all 22 mutation entry points to `BRepGraph_EditorView`. Old: `g.Builder().AddVertex(p, t)`; new: `g.Editor().Vertices().Add(p, t)`. Swift API surface unchanged.
- **`NCollection_Vector` deprecated** ([OCCT #1230](https://github.com/Open-Cascade-SAS/OCCT/pull/1230)) → switched 4 internal sites to `NCollection_DynamicArray`, including the `BRepGraph_History::Record` mapping container.
- **`Builder().AppendFlattenedShape` / `AppendFullShape` consolidated** → both now route through the static `BRepGraph_Builder::Add(graph, shape, options)`. The `Flatten` and `CreateAutoProduct` options preserve the pre-beta1 distinction.
- **`Builder().ClearFaceMesh` / `ClearEdgePolygon3D` moved** → now `BRepGraph_Tool::Mesh::ClearFaceCache` / `ClearEdgeCache`. Semantic shift: clears only the new cached-mesh tier, not persistent (STEP-imported) mesh data.
- **`graph.Build(shape, parallel)` removed** → wrapper now calls the static `BRepGraph_Builder::Add(graph, shape, opts)` with `CreateAutoProduct = false` to preserve the historical "no auto Product wrap" behaviour.
- **`graph.RootNodeIds()` → `graph.RootProductIds()`** — root iteration is now Products only.
- **`BRepGraph_Copy::CopyFace` → `CopyNode`** — single-node deep copy now takes any NodeId kind.
- **`Topo().Occurrences().ParentOccurrence` removed** — beta1 model is `Product → Occurrence → Product`; an occurrence has no parent occurrence. Wrapper retained as `-1` sentinel for ABI; will be removed in v1.0.
- **`BRepGraph_ChildExplorer::Current()` returns `BRepGraphInc::NodeInstance`** (was `NodeUsage`); field accessor unchanged.
- **`BRepGraph_Tool::Edge::StartVertex` / `EndVertex` renamed** to `StartVertexId` / `EndVertexId`; return type simplified from a `VertexRef` struct to `BRepGraph_VertexId`.
- **`Topo().Poly().Nb*` moved to `Mesh().Poly().Nb*`** — triangulation/polygon counts live on the new MeshView, paired with the two-tier mesh storage.

New beta1 surface (`BRepGraph_MeshCache`, `BRepGraph_MeshView` read-side, `EditorView` per-entity Ops methods, `BRepGraph_Tool::Mesh` cache-write API) is **deferred to v0.158 / v1.0** — kept v0.157 minimal to preserve the soak window.

The 1300+ existing tests continue to pass under serial execution (`OCCT_SERIAL=1` with `--num-workers 1`); the pre-existing parallel-execution NCollection arm64 race remains the same as v0.156.

### v0.156.3 (Apr 2026) — `Document.node(at:)` warms up the labelId registry (issue #95)

The `Document.node(at:)` lookup added in v0.156.1 returned `nil` on a freshly-loaded STEP document if `rootNodes` hadn't been walked first. Cause: the bridge's labelId-to-`TDF_Label` registry is populated lazily via `registerLabel(...)` calls — `OCCTDocumentLabelIsNull(0)` reports null because `labels[0]` doesn't exist yet. `rootNodes` warms it up because `OCCTDocumentGetRootLabelId(handle, i)` calls `registerLabel`, but `OCCTDocumentGetRootCount` alone doesn't.

`node(at:)` now eagerly iterates root indices to register top-level labels before the IsNull check:

```swift
public func node(at labelId: Int64) -> AssemblyNode? {
    let rootCount = OCCTDocumentGetRootCount(handle)
    for i in 0..<rootCount { _ = OCCTDocumentGetRootLabelId(handle, i) }
    guard !OCCTDocumentLabelIsNull(handle, labelId) else { return nil }
    return AssemblyNode(document: self, labelId: labelId)
}
```

Deep-child labelIds aren't registered by this warmup — those are expected to have been registered earlier by an explicit traversal (e.g. via `node.children`). The contract docstring spells this out.

`mainLabel` was checked for the same lazy-init quirk and is fine as-is — `OCCTDocumentGetMainLabel` calls `registerLabel(main)` itself.

Driver: [OCCTSwiftScripts#23](https://github.com/gsdali/OCCTSwiftScripts/issues/23)'s `set-metadata` verb. The downstream workaround (`_ = document.rootNodes.count` before `node(at:)`) can be removed.

One new regression test: load a STEP doc, look up `node(at: 0)` *without* touching `rootNodes` first, expect a non-nil node with `labelId == 0`.

### v0.156.2 (Apr 2026) — Public `Mesh(vertices:normals:indices:)` constructor (issue #94)

`Mesh` had `internal init(handle:)` and no public way to construct from raw vertex/index arrays. This blocked sibling packages (notably [OCCTSwiftMesh](https://github.com/gsdali/OCCTSwiftMesh)) from returning `Mesh` instances produced by mesh-domain algorithms (decimation, smoothing, repair, remeshing) that operate purely on vertex/index buffers and have no B-Rep state.

```swift
let mesh = Mesh(
    vertices: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)],
    indices: [0, 1, 2]
)
```

Optional `normals: [SIMD3<Float>]?` parameter — when nil, per-vertex normals are computed by averaging the face normals of adjacent triangles (smooth shading default). Per-triangle normals are always computed from the geometry. `faceIndices` is set to `-1` for every triangle (no B-Rep source).

Failable initializer rejects: empty inputs, index count not divisible by 3, indices out of range, mismatched normals count.

Bridge: one new symbol `OCCTMeshCreateFromArrays(vertices, vertexCount, normals, indices, indexCount) -> OCCTMeshRef?` — caller releases via the existing `OCCTMeshRelease`. Unblocks [OCCTSwiftMesh#1](https://github.com/gsdali/OCCTSwiftMesh/issues/1) (v0.1.0 — `Mesh.simplified(_:)` via vendored meshoptimizer).

7 new tests covering round-trip, computed-normals correctness, supplied-normals preservation, and all four invalid-input rejection paths.

### v0.156.1 (Apr 2026) — Public `AssemblyNode.labelId` + `Document.node(at:)` lookup (issue #93)

`AssemblyNode.labelId` was `internal` even though every other `Document` API works in terms of `Int64` labelIds (`removeShape(labelId:)`, `componentLabelId(...)`, `expandShape(labelId:)`, etc.). Consumers walking the assembly via `Document.rootNodes → AssemblyNode.children` couldn't read each node's `labelId` to identify it across calls. Driver: [OCCTSwiftScripts#23](https://github.com/gsdali/OCCTSwiftScripts/issues/23) (`occtkit inspect-assembly` / `set-metadata`) needs stable IDs that round-trip.

Two tiny additive changes:

```swift
// 1. labelId is now public
public let labelId: Int64

// 2. New lookup on Document
public func node(at labelId: Int64) -> AssemblyNode?
```

`node(at:)` validates the labelId via `OCCTDocumentLabelIsNull` (O(1), consistent with the rest of the int64-based Document API) and returns `nil` for unknown labelIds. LabelIds are stable within a single `Document` instance — round-trips with `rootNodes` traversal in the same session.

No bridge changes. Two new tests covering the round-trip and rejection of nonexistent labelIds.

### v0.156.0 (Apr 2026) — Quality release: drop deprecated `GCE2d_*` symbols

OCCT 8.0.0 deprecated the entire `GCE2d_Make*` family of 2D geometry constructors in favour of the canonical `GC_Make*2d` names — each old class is now literally a `using GCE2d_X = GC_X2d` typedef alias. This release migrates all internal C++ uses inside `OCCTBridge.mm` to the canonical names so we're no longer building against deprecated identifiers.

```
GCE2d_MakeArcOfCircle   → GC_MakeArcOfCircle2d
GCE2d_MakeArcOfEllipse  → GC_MakeArcOfEllipse2d
GCE2d_MakeArcOfHyperbola → GC_MakeArcOfHyperbola2d
GCE2d_MakeArcOfParabola → GC_MakeArcOfParabola2d
GCE2d_MakeCircle        → GC_MakeCircle2d
GCE2d_MakeEllipse       → GC_MakeEllipse2d
GCE2d_MakeHyperbola     → GC_MakeHyperbola2d
GCE2d_MakeLine          → GC_MakeLine2d
GCE2d_MakeMirror        → GC_MakeMirror2d
GCE2d_MakeParabola      → GC_MakeParabola2d
GCE2d_MakeRotation      → GC_MakeRotation2d
GCE2d_MakeScale         → GC_MakeScale2d
GCE2d_MakeSegment       → GC_MakeSegment2d
GCE2d_MakeTranslation   → GC_MakeTranslation2d
```

14 `#include` directives + ~30 internal symbol uses migrated. Bridge ABI unchanged: the bridge's own C function names (`OCTGCE2dMake*`) are preserved so Swift wrappers continue to call them by their existing names — this is a **non-breaking** internal hygiene release.

Operation count, test count, and suite count are unchanged — same OCCT objects, just constructed via canonical names. The `@Suite("GCE2d_MakeLine")` test label was renamed to `@Suite("GC_MakeLine2d")` for consistency. Source comments and `// MARK:` headers in `Sources/OCCTSwift/Curve2D.swift` and `Sources/OCCTSwift/Document.swift` were updated similarly.

This was the cleanup-half of a rescoped v0.156.0 plan. The OCAF/Message data introspection scope originally pencilled in for v0.156.0 was abandoned after a full audit revealed the project is at the asymptote of useful OCCT public surface — most flagged "missing" classes were already wrapped via the established `OCCTDocumentRef` + `int64_t labelId` pattern, and the genuinely unwrapped classes (~25 ops total: `gp_Vec2f/3f`, `GeomConvert_FuncCone/Cylinder/SphereLSDist`) are too small to justify a 100-op release on their own.

### v0.155.1 (Apr 2026) — `Wire(_:Shape)` convenience initializer (issue #91)

Completes the v0.154.0 trio. Recovers a typed `Wire` from a generic `Shape` that wraps a `TopoDS_Wire`, returning nil on type mismatch. Mirrors `Face(_:Shape)` and `Edge(_:Shape)`.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let wireShapes = box.subShapes(ofType: .wire)
if let wire = Wire(wireShapes[0]) {
    // typed Wire recovered from a wire-typed Shape
}
```

Unblocks face-rebuild flows where existing inner wires (returned as `[Shape]` from `Shape.wires` or `subShapes(ofType: .wire)`) need to be passed back into `Shape.face(outer:holes:)` — previously those wires were stuck as `Shape` because the `Wire(handle:)` initializer was internal. Concrete motivating case: preserving both bore and chamfer outlines on the same mid-face when extracting countersink mid-surfaces in [UnfoldEngine](https://github.com/gsdali/UnfoldEngine).

Bridge: one new symbol `OCCTWireFromShape(OCCTShapeRef) -> OCCTWireRef?`.

### v0.155.0 (Apr 2026) — `SheetMetal.Builder`: convex bends (issue #89)

The v0.151–v0.153 builder only supported **concave** bends (L-bracket-style, where the two flanges' bodies overlap in volume around the seam). **Convex** bends — Z-section middle bends, offset brackets, gusseted brackets where one flange folds back on the opposite side — failed with `BuildError.filletFailed` because the seam edge is non-manifold (a kiss point with four boundary faces meeting at one line, which `BRepFilletAPI_MakeFillet` rejects).

v0.155 adds first-class convex bend support:

- **Auto-detected direction.** Each bend is classified concave or convex from the relative position of the two flanges' body centroids. No caller change needed; the existing v0.151–v0.153 fixtures (L, U, stepped Z) continue to build identically because they're all concave.

- **Convex bend material.** Convex bends build a **curved-triangle prism** that bridges the two flanges' outer-corner edges with a cylindrical fillet on the outside surface, then boolean-fuses with the flanges. The "kiss point" stays sharp on the inside (which is the natural CAD interpretation when the user's flange placements don't leave room for an inside cylinder); the outside is rounded to the bend radius.

- **`Bend` struct expanded** with optional explicit controls:
  - `angle: Double?` — bend angle in radians, signed (positive = concave, negative = convex). Nil means auto-infer from flange positions. Sign convention follows OCCT's right-hand rule: angles are CCW-positive about the bend axis derived from `cross(fromFlange.normal, toFlange.normal)`, with concave-positive matching how a CAD designer thinks about bends.
  - `insideRadius: Double` — replaces the legacy single `radius` (which still works as a convenience init).
  - `outsideRadius: Double?` — independent control of the outside fillet radius. Defaults to nil = match insideRadius for convex builds.
  - `materialThicknessAtBend: Double?` — allow thinner material in the bend region than the flange thickness, common in etched parts where a thinned bend line allows tighter folds without cracking.
  - `direction: BendDirection` — `.auto` (default), `.concave`, or `.convex` for explicit override.

- **The legacy `Bend(from:to:radius:)` initializer is unchanged.** All v0.151–v0.153 callers continue to work without modification.

The 93-face inside-corner-reinforcing-bracket from #89 (Z-section with both same-direction and convex bends) now builds cleanly. Test fixtures from the issue: symmetric Z, offset L with very short web, channel-with-flange, all pass.

Bridge: one new symbol `OCCTWireCreateArcThroughPoints(s, m, e)` for 3-point arc-wire construction (avoids the `gp_Ax2` X-direction ambiguity of the angle-based arc API). Exposed as `Wire.arc(start:midpoint:end:)`.

### v0.154.0 (Apr 2026) — `Face(_:Shape)` and `Edge(_:Shape)` convenience initializers

Two tiny additive bridge symbols and their Swift conveniences. Recovers a typed `Face` or `Edge` from a generic `Shape` that wraps a `TopoDS_Face` / `TopoDS_Edge` (returns nil on type mismatch). Useful when a method gives back a `Shape` (e.g. `subShapes(ofType: .face)`) and you want the typed wrapper to call methods like `area()`, `outerWire`, `length`, etc., directly.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let faceShapes = box.subShapes(ofType: .face)
if let face = Face(faceShapes[0]) {
    print(face.area())   // 100
}
```

Bridge: `OCCTFaceFromShape(OCCTShapeRef) -> OCCTFaceRef?` and `OCCTEdgeFromShape(OCCTShapeRef) -> OCCTEdgeRef?`. Both return NULL when the shape's `ShapeType()` doesn't match. Unblocks the upcoming `UnfoldEngine` package, which builds on these.

### v0.153.0 (Apr 2026) — `SheetMetal.Builder` step-aware bends (issue #86)

The v0.151 `SheetMetal.Builder` implementation extruded each flange at its full profile, fused them, then filleted the seam edge. That works when both flanges have matching extents along the seam direction, but fails on **stepped seams** — flanges that meet along less than their full extent (a narrow tab on a wider base, a U-channel with sides narrower than the spine). OCCT can't cleanly fillet an edge that terminates at a free-face boundary, so the v0.151 builder reported `BuildError.filletFailed` and the downstream `OCCTDesignLoop` pipeline padded the narrower flange to match — both expensive and incorrect.

v0.153 lifts that limitation:

- `SheetMetal.Builder.build(flanges:bends:)` now computes the seam intersection between each pair of flanges in a bend and **splits the wider flange** at the intersection endpoints before extruding. The matched-extent middle piece carries the bend; the outer pieces stay flat. The fillet machinery from v0.151 runs unchanged on the matched-extent piece, where it's always well-formed.
- For matched-extent inputs (where v0.151 already worked), the result is identical: the splitting step is a no-op.
- Two new error cases: `BuildError.seamsDoNotOverlap(fromID:toID:)` if the two flanges' seam edges don't actually intersect along the seam line; `BuildError.nonRectangularStepFlange(id:)` if a flange would need to be split but its profile isn't axis-aligned-rectangular (rectangular profiles cover the issue's three test fixtures and the common cases; non-rectangular stepped seams are deferred).

The three reference fixtures from issue #86 all build cleanly:

- **L-bracket** with 80×40 base + 20×30 centred mounting tab.
- **Z-bracket** with 50×30 base + full-seam mid + 20×30 stepped top tab.
- **U-channel** with 100×40 spine + 80×15 stepped side flanges (narrower than the spine in the seam direction).

OCCTDesignLoop's `eval/describer_to_features.py` can drop its seam-padding workaround and emit actual described flange dimensions; the existing typed `SheetMetal.Flange` / `SheetMetal.Bend` API and the JSON envelope are unchanged.

The unrelated v0.151 limitation about the bend axis being on the *outside* corner (sharp inner corner, filleted outer corner) still applies — that's a different construction (real inside-radius + outside-radius bend) and is filed separately.

### v0.152.1 (Apr 2026) — `FeatureReconstructor.buildJSON` decodes `boolean` (issue #88)

`FeatureSpec.boolean` (with `op` ∈ `union | subtract | intersect`, `leftID`, `rightID`) has been wired through `applyBoolean` since the typed Swift API landed, and v0.152's `inputBody` makes it useful for cuts that reference the seeded body via `@input`. But the JSON decoder never picked it up — `FeatureEntry.init(from:)` had no `case "boolean":` branch, so JSON entries with `"kind": "boolean"` fell into the `default:` clause and were silently dropped.

- **Adds the `case "boolean":` decoder branch.** Reads `op` (string), `left`, `right`, optional `id`. Coding keys for these were already declared.
- **Bad `op` rawValue surfaces as a recordable skip** with reason `unsupported("boolean(op:smush)")` rather than throwing — matches the rest of the reconstructor's "graceful degradation" policy.
- **Unknown `kind` strings now also surface as `Skipped` entries** when the JSON entry carries an `id`. Reason: `unsupported("unknown JSON kind: …")`. Stage: `additive`. Without this, typos in `kind` and version-drift schemas were silently swallowed; now they're visible. Entries without an id continue to be silently ignored, matching the rest of `FeatureReconstructor` (the kernel only records skips when there's an id to attach them to).

Together these mean the `inputBody → boolean(@input, slot)` chain that v0.152 implies should work, actually does work end-to-end from JSON.

### v0.152.0 (Apr 2026) — `FeatureReconstructor.inputBody` for chained composition (issue #87)

`FeatureReconstructor.build(from:)` previously always started from an empty `BuildContext.current`, with the in-progress shape grown purely from additive feature entries. That blocks **chaining** — composing a body via one kernel API (e.g. `SheetMetal.Builder` from v0.151) and then cutting / finishing into it via the reconstructor. v0.152 makes the kernel itself accept a starting body.

- **Optional `inputBody` parameter on both build entry points:** `FeatureReconstructor.build(from: specs, inputBody: Shape? = nil)` and `FeatureReconstructor.buildJSON(_:inputBody:)`. When non-nil, `BuildContext.current` is seeded with the input and the input is registered in `namedShapes` under the sentinel id `@input`. When nil, behaviour is byte-for-byte identical to v0.151.
- **`FeatureReconstructor.inputBodySentinel`** — the literal string `@input`, exposed as a public constant so JSON envelopes and Swift callers share one source of truth. Boolean `leftID` / `rightID`, `Fillet.edgeSelector.onFeature`, and `Chamfer.edgeSelector.onFeature` all resolve `@input` via the standard `namedShapes` lookup — no separate code path. Last-write-wins semantics: a feature with `id == "@input"` shadows the seed, which is the obvious behaviour.
- **No JSON schema change.** Downstream callers using `buildJSON` pass `inputBody:` from Swift; the JSON envelope itself is unchanged. Within the envelope, references to `@input` are just regular id strings.
- **Stage ordering preserved.** Additive features still union onto whatever `current` is at the start of stage 1 (input or empty). Subtractive / finishing / annotation stages run with the same dispatch as v0.151. The existing `Skipped` reporting (under-determined / OCCT failure / unresolved-ref / unsupported) is unchanged.

The immediate driver is the sheet-metal → reconstructor chain referenced by [OCCTSwiftScripts#13](https://github.com/gsdali/OCCTSwiftScripts/issues/13): build a bent bracket via `SheetMetal.Builder`, then drill mounting holes into it with the reconstructor's hole-placement and `Skipped` machinery. The verb-side wiring downstream is one line — `FeatureReconstructor.buildJSON(envelope, inputBody: try GraphIO.loadBREP(at: path))`.

This is also the primitive the planned `Skipped` resume-from-last-good-shape behaviour will need: "given a partially-built shape, continue applying remaining specs" reduces to an `inputBody`-aware build.

**Out of scope:** multi-body input lists (use `Shape.compound` upstream), round-tripping face / edge tags from prior history (gone after BREP serialisation), reverse decomposition (`Shape → [FeatureSpec]`).

### v0.151.0 (Apr 2026) — Sheet-metal composition API (issue #85)

OCCT has no sheet-metal bend primitive and is not expected to grow one — CATIA / SolidWorks / FreeCAD all compose bends from extrude + union + fillet. v0.151 adds the canonical Swift-level composition so downstream consumers (OCCTDesignLoop's VLM reconstructor, scripts, MCP tooling) do not each reinvent it.

- **`SheetMetal.Flange`** — a closed 2D profile positioned in world space by explicit `(origin, uAxis, vAxis, normal)`. All three axes are independent so left-handed world placements (e.g. a flange normal along +Y with the profile reading +X / +Z) are expressible without handedness surprises. `vAxis` defaults to `cross(normal, uAxis)` when omitted.
- **`SheetMetal.Bend`** — names two flanges + an inside radius. No geometric data; the builder resolves the seam edge from the flange placements.
- **`SheetMetal.Builder.build(flanges:bends:)`** — extrudes each flange along its normal by `thickness`, fuses the bodies in order, then for each bend finds the seam edge(s) and applies `Shape.filleted(edges:radius:)`. Seam finding walks the fused shape's edges, keeps only those parallel to `cross(nA, nB)`, and selects the one whose midpoint lies on each flange's face that points *toward* the other flange — which uniquely identifies the bend and rejects the coincidental convex back corner.
- **`SheetMetal.BuildError`** — named cases for invalid thickness, empty flange list, duplicate/unknown IDs, invalid profile, extrusion/union/fillet failures, parallel flanges (no seam direction), and missing seam edge. `CustomStringConvertible` for direct logging.

**Known limitation:** stepped seams (flanges meeting along less than their full seam-direction extent, e.g. a narrow upright on a wider base) surface as `BuildError.filletFailed`. OCCT cannot cleanly round an edge that terminates at a free-face boundary; downstream callers should match flange widths along the seam or split the wider flange. Reverse-direction unwrap (bent BRep → flat cutting pattern) is the planned next addition to this namespace.

### v0.150.0 (Apr 2026) — Pure-Swift PDF + SVG export + BOM + balloons

Second half of the v0.149 → v0.150 drawing-automation arc. Drawings now have three readable output formats (DXF for engineering tools, PDF for humans, SVG for the web) plus the assembly-drawing primitives that make BOM-driven output a one-call operation.

- **`PDFWriter` + `Exporter.writePDF(drawing:to:pageSize:)` / `writePDF(sheet:body:to:)`** — pure-Swift PDF 1.4 writer. No UIKit / AppKit / Core Graphics dependency; works on macOS, iOS, and Linux. Helvetica font, one page per file, content stream installs a mm→pts CTM so staged geometry stays in drawing units. Per-layer ISO 128-20 stroke weights (0.5 mm VISIBLE / OUTLINE, 0.25 mm HIDDEN / CENTER / DIMENSION / TEXT, 0.18 mm HATCH) with dashed / chain patterns on HIDDEN / CENTER. Circles rendered as four cubic Bézier segments; arcs split into ≤90° Bézier chunks.
- **`SVGWriter` + `Exporter.writeSVG(drawing:to:)` / `writeSVG(sheet:body:to:)`** — pure-Swift SVG 1.1 writer. One `<g>` group per layer with stroke / stroke-width / stroke-dasharray attributes. Arcs emitted as native SVG `<path d="M… A …"/>`. ViewBox explicit or computed from content bounds. Drawing's mathematical Y (up) mapped to SVG's screen Y (down) via a group-level `scale(1,-1)`; each `<text>` carries its own counter-transform so glyphs read right-side up.
- **`DrawingAnnotation.balloon(Balloon)`** — new case carrying `itemNumber` + `centre` + `radius` + optional `leaderTo`. Rendered in every writer (DXF / PDF / SVG) as a circle + number text + optional leader line that exits the circle at the point nearest the target. `Drawing.addBalloon(itemNumber:at:leaderTo:radius:id:)` is the convenience entry point.
- **`BillOfMaterials`** — pure-Swift `Codable` value type. Seven-column table (ITEM / PART NO / DESCRIPTION / QTY / MAT / MASS / NOTES) with per-column default widths; caller populates `[Item]` and calls `render(into: DXFWriter, at:)`. Origin is the **bottom-right** anchor so the table grows up and to the left (idiomatic placement above a title block). `Sheet.renderBOM(_:into:at:)` convenience places the BOM right-aligned to the inner frame's top edge.
- **`DrawingDispatch.swift`** — shared internal annotation + dimension dispatcher used by `PDFWriter` and `SVGWriter`. `DrawingPrimitiveOps` struct bundles the five drawing primitives (addLine / addPolyline / addCircle / addArc / addText) as closures; a single dispatch path handles every `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine, balloon) and every `DrawingDimension` case including tolerance rendering. `DXFWriter` continues to use its own inline logic — not because it couldn't be ported, but to keep its test coverage load-bearing and avoid regression risk.
- **`Exporter.pdfA3Landscape` / `pdfA4Landscape`** — named pts-space page-size constants. Also `PDFWriter.addDimension(_:)` / `SVGWriter.addDimension(_:)` mirror the DXF-side method added in v0.149 for ad-hoc dimension staging without a `Drawing`.

After v0.150, the only substantive drawing-layer gap is native DXF `DIMENSION` entities (still exploded LINE+TEXT), which remains demand-gated.

### v0.149.0 (Apr 2026) — Sheet automation + tolerance + ordinate dimensioning

First of a two-release arc closing the last substantive drawing-automation gaps: one-call multi-view layout, typed tolerance data on every dimension, and ISO 129-1 §9.3 ordinate dimensioning.

- **`Sheet.standardLayout(of:scale:margin:includeIso:)`** — composes front / top / side / optional isometric views of a `Shape` onto the sheet's inner frame as a 2x2 grid. Arrangement follows the sheet's `ProjectionAngle`: first-angle places top below front, third-angle places top above. Uniform scale is computed to fit the widest projected view; callers can pass a smaller `DrawingScale` to override. Returns a `StandardLayout` whose `PlacedView`s hold the original Drawings (attach dimensions per view before calling `render(into:)`).
- **`Drawing.addAutoDimensions(from:viewDirection:minRadius:dimensionOffset:bounds:)`** — heuristic dimensioner: adds a linear dimension for the projected X and Y extents of the shape's bounding box, plus a diameter dimension on every visible circular edge. Edge-on circles are skipped (mirrors the `addAutoCentermarks` detection); `minRadius` filters noise holes.
- **`DrawingTolerance`** — typed, `Codable` enum carried as `tolerance: DrawingTolerance` on every `DrawingDimension` payload (Linear, Radial, Diameter, Angular, Ordinate). Cases: `.none`, `.symmetric(Double)`, `.bilateral(plus:minus:)`, `.unilateral(Double)`, `.fitClass(String)`, `.limits(lower:upper:)`. Inline cases fold into the nominal label; multi-value cases render as stacked upper/lower TEXT in DXF at ~55% height, placed perpendicular to each dimension's text baseline.
- **`DrawingDimension.ordinate(Ordinate)`** — shared-origin X+Y dimensioning for CNC reference-datum workflows. Each feature carries its own position plus optional custom label; a single `tolerance` applies across all features. DXF emit draws a small origin cross, per-feature extension lines with ticks at the origin baseline, and offset labels perpendicular to each line. `Drawing.addOrdinateDimensions(origin:features:tolerance:id:)` is the convenience entry point. `DrawingDimension.Ordinate` + `Feature` are `Codable` for JSON-driven pipelines.
- **`DXFWriter.addDimension(_:)`** — public single-entity dispatch over every `DrawingDimension` case; useful for tests and for scripts that compose DXFs from dimension values without going through a `Drawing`.

### v0.148.0 (Apr 2026) — Drawing.append(_:) unified dispatcher

Small release closing #83 and #84 — both asked for the same thing: a public `Drawing.append(_:)` that dispatches every `DrawingAnnotation` case without the consumer-side switch blind spot.

- **`Drawing.append(_ annotation: DrawingAnnotation)`** — appends any `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine). When new cases land, the dispatcher updates in one place, not in every consumer.
- **`Drawing.append(contentsOf: [DrawingAnnotation])`** — for factory output like `DrawingAnnotation.surfaceFinish(...)`, `.featureControlFrame(...)`, `.datumFeature(...)`, `.breakLine(...)`, `.cosmeticThreadSideView(...)` which all return arrays.
- **`Drawing.append(_ dimension: DrawingDimension)`** / `append(contentsOf: [DrawingDimension])` — symmetric for dimensions.

Downstream `replay(...)` helpers (OCCTSwiftScripts, OCCTSwiftPartsAgent) collapse to one-line `drawing.append(contentsOf: DrawingAnnotation.surfaceFinish(...))`. The existing `addCentreLine` / `addCentermark` / `addTextLabel` / `addHatch` / `addCuttingPlaneLine` typed factories continue to work unchanged; they're now a thin convenience over `append(_:)` conceptually (though the storage path is identical either way).

### v0.147.0 (Apr 2026) — Drawing + FeatureSpec consumer polish

Closes four small follow-up issues (#79, #80, #81, #82) that downstream consumers (OCCTSwiftScripts, OCCTDesignLoop, MCP tooling) asked for to remove boilerplate and unblock JSON-driven workflows.

- **#80 `Edge.curve3D`**: Direct `Edge → Curve3D` bridge. Ensures the 3D curve is built via `BRepLib::BuildCurves3d` for pcurve-only edges. Returns the raw `Geom_Curve` so consumers can call `curve.circleProperties` / `lineProperties` / etc. without DownCast gymnastics.
- **#79 `Drawing.addAutoCentermarks(from:viewDirection:extent:minRadius:bounds:)`**: symmetric to `addAutoCentrelines`. Walks circular edges, projects each centre into the view plane, adds `.centermark` annotations. Skips edges whose circle plane is parallel to the view (edge-on). `minRadius` filters small holes; `bounds` filters centermarks outside the view.
- **#81 `DrawingAnnotation.CuttingPlaneLine` + `Drawing.addCuttingPlaneLine`**: typed ISO 128-40 cutting-plane line. Computes trace in view 2D from cutting plane normal × view direction. DXFWriter renders heavy-chain ends, thin-chain middle, perpendicular arrows, and label letters at both ends.
- **#82 `FeatureSpec` Codable conformance**: `FeatureSpec` + all nested types (`Revolve`, `Extrude`, `Hole`, `Thread`, `EdgeSelector`, `Fillet`, `Chamfer`, `Boolean`) now `Codable`. Unblocks `FeatureReconstructor.buildJSON` + Python / MCP driven reconstruction pipelines without each consumer mirroring the types in their own schema.

### v0.146.0 (Apr 2026) — ISO drawings III: cosmetic threads, surface finish, GD&T symbols, detail views

Closes the ISO drawings arc (#78). Final release ships cosmetic threads (#77), ISO 1302 surface finish, ISO 1101 GD&T symbols, and compressed-view conventions (detail + break lines).

- **#77 `DrawingAnnotation.cosmeticThreadSideView` / `cosmeticThreadEndView`**: ISO 6410 cosmetic thread representation. Side view: two parallel lines at minor diameter spanning the thread length, optional callout text. End view: 3/4 broken arc set (0–90° / 90–180° / 180–315° with a 45° gap). `Drawing.addCosmeticThreadSide(...)` and `DXFWriter.addCosmeticThreadEndView(...)` convenience wrappers.
- **ISO 1302 surface finish**: `SurfaceFinishSymbol` enum (`.any` / `.machiningRequired` / `.machiningProhibited`). `DrawingAnnotation.surfaceFinish(at:leaderTo:ra:symbol:method:)` produces the check-mark geometry with Ra value label, horizontal bar for machiningRequired, optional production-method text, and leader line to the target feature.
- **ISO 1101 GD&T symbols**: `GDTSymbol` enum covering all 15 ASME/ISO geometric characteristics (straightness, flatness, circularity, cylindricity, profile of line/surface, perpendicularity, parallelism, angularity, position, concentricity, symmetry, coaxiality, circular runout, total runout). `DrawingAnnotation.featureControlFrame(at:symbol:tolerance:datums:leaderTo:)` emits the classic `[⌖] [0.1] [A] [B] [C]` rectangular frame. `DrawingAnnotation.datumFeature(label:at:pointingTo:)` emits the boxed letter + triangle pointer.
- **Detail views**: `Drawing.detailView(at:scale:)` returns a `TransformedDrawing` suitable for placing a scaled-up region of the parent drawing at a specific sheet location.
- **Break lines**: `DrawingAnnotation.breakLine(from:to:amplitude:)` emits ISO 128-30 compressed-length zigzag marker as 5 line segments.

### v0.145.0 (Apr 2026) — ISO drawings II: sheet templates, title blocks, projection symbols

Second release in the ISO drawings arc (#78). Closes #76 — adds ISO 5457 trimmed-sheet templates, ISO 7200 title blocks, and ISO 5456-2 projection symbols as first-class OCCTSwift API.

- **`PaperSize`**: `A0` / `A1` / `A2` / `A3` / `A4` with `.size(in: .landscape)` / `.portrait` returning ISO 5457 trimmed dimensions in mm.
- **`Orientation`**: `.landscape` / `.portrait`.
- **`ProjectionAngle`**: `.first` (ISO / Europe) / `.third` (ANSI / USA).
- **`TitleBlock`**: ISO 7200 mandatory + optional fields (title, drawingNumber, owner, creator, approver, documentType, dateOfIssue, revision, sheetNumber, language, material, weight, scale).
- **`Sheet`**: ties PaperSize + Orientation + ProjectionAngle + TitleBlock together. `render(into: DXFWriter)` emits border + ISO 5457 inner frame with correct margins (20 mm binding left, 10 mm other edges on A0–A3), centring marks at edge midpoints, and the title block in the bottom-right. `innerFrame` property exposes the drawable rectangle for layout.
- **`ProjectionSymbol`**: `ProjectionSymbol.render(.first, at:, into:)` emits the ISO 5456-2 truncated-cone + circle pair at the correct relative position for first / third angle.
- DXFWriter gets two new layers: `BORDER` and `TITLE`.

### v0.144.0 (Apr 2026) — ISO drawings I: section views, hatch, multi-view, style foundations

First of a three-release ISO-drawings arc (tracked in #78). Closes #73, #74, #75 and adds the ISO 128-20 / 3098 / 5455 style primitives every downstream sheet producer needs.

- **#75 `Drawing.transformed(translate:scale:)` + `Drawing.bounds`**: new `TransformedDrawing` wrapper and `DXFWriter.collectFromDrawing(_ transformed:)` overload. `Drawing.bounds(deflection:includeAnnotations:)` returns the drawing's 2D axis-aligned bounding box. Unblocks multi-view sheet composition: `writer.collectFromDrawing(view.transformed(translate: offset, scale: 0.5))`.
- **#73 `Shape.section2D(planeOrigin:planeNormal:planeU:deflection:)`** + `Shape.section2DView(...)`: slice a shape with a plane, return a `Drawing` in the plane's own 2D frame (not world space). `section2DView` wraps the contour with automatic ISO 128-40 hatching at 45° and an optional "A-A" label.
- **#74 `Drawing.addHatch(boundary:angle:spacing:islands:)`**: ISO 128-50 sectional-view fill. DXFWriter tessellates into line segments at the specified angle and spacing with island (hole) subtraction via even-odd rule scanlines. Adds `HATCH` + `SECTION` XCAF layers.
- **G1 ISO 128-20 line widths + ISO 128-21 arrows + ISO 3098 text heights**: `DrawingLineWidth` enum (w013 → w200, ISO 1:1.4 series), `DrawingTextHeight` enum (h25 → h200) with `.recommended(forPaper:)` and `.snap(_:)`, `DrawingArrowStyle` (filledClosed / openClosed90 / openClosed30 / tick), `DrawingLineStyle.defaultWidth` / `.boldWidth` per style.
- **G2 ISO 5455 `DrawingScale`**: enum cases `.one` / `.reduction(Int)` / `.enlargement(Int)` / `.custom(Double)` with `.factor` and `.label` accessors. `DrawingScale.preferred` returns the ISO-standard scale series (50:1 down to 1:1000).

### v0.143.0 (Apr 2026) — Measurement ergonomics + clearing v0.142 deferrals

Small-but-broad release that sands the measurement papercuts surfaced by the v0.143 audit and retires every deferral the v0.142 release notes flagged. Roughly 40 ops: 4 measurement additions, 5 deferral clearings.

**Measurement ergonomics (M1–M4):**

- **`Shape.volume` / `Shape.surfaceArea`** — verified already wrapped as optional properties (audit had missed them); no new code, just confirmation.
- **`Curve3D.distance(to: SIMD3)` / `Edge.distance(to: SIMD3)`** — one-liner point-to-curve distance when you don't need the projected point / parameter.
- **Angle helpers**: `Edge.angle(to:)`, `Edge.isParallel(to:tolerance:)`, `Edge.isPerpendicular(to:tolerance:)`, `Face.angle(to:)`, `Face.isParallel(to:)`, `Face.isPerpendicular(to:)`, `Face.isCoplanar(with:tolerance:)`. Plus `ConstructionAxis.angle(to:in:)`, `ConstructionPlane.angle(to:in:)`. `unsignedAngle(between:and:)` free function for SIMD3 pairs.
- **Circle / revolution property extraction**: `Edge.circleProperties` returns `(center, radius, axis, isFullCircle, startAngle, endAngle)?` for circular edges (three-point circle fit). `Face.revolutionProperties` returns `(axis, radius)?` for cylindrical / conical / spherical / toroidal / surface-of-revolution faces.

**Deferral clearings (from v0.142 release notes):**

- **Constructionspeak persistence (D1)**: `Document.addConstructionShape(_:)` tags a shape with the `CONSTRUCTION` XCAF layer; `Document.constructionShapeLabels` enumerates on reload. `ConstructionContext.materialize(in:graph:options:)` resolves every plane/axis/point recipe and creates a finite representative shape (rectangular face for planes, bounded edge for axes, vertex for points) on the layer. STEP export preserves layer tags; import produces layer-marked shapes but not the typed recipes. Matches FreeCAD's long-standing ceiling.
- **Arc / circle tessellation in `Sketch.buildProfile` (D2)**: `SketchElement.CurveKind.tessellate2D(segmentsPerRadian:)` for all four curve kinds (line / polyline / arc / circle). `Sketch.buildProfile` now lifts tessellated samples through the host plane's frame. D-shaped and circular profiles now produce wires.
- **Named-shape registry for `FeatureSpec.Boolean` (D3)**: Each feature with a non-nil `id` registers its produced shape in an internal dict; `Boolean.leftID` / `rightID` look up by id. `.union` / `.subtract` / `.intersect` all supported. Missing-id cases report `.unresolvedRef`.
- **Multi-leaf `.createdBy` disambiguation (D4)**: new `leafOccurrence: Int? = 0` parameter on `TopologyRef.createdBy` — pick the Nth leaf when a creation has split into multiple live descendants. `TopologyGraph.currentForms(of:)` returns all leaves. `leafOccurrence: nil` disables forward-walk.
- **FeatureReconstructor ↔ TopologyGraph coupling for `EdgeSelector` (D5)**: `.nearPoint(point, tolerance)` resolves edges by midpoint-distance within the target shape. `.onFeature(featureID)` looks up the source feature's shape via the named-shape registry and heuristically matches target edges whose midpoints coincide with the source's edges. `.all` for uniform fillet/chamfer still works. (v1 heuristic; full graph-history dispatch remains available if consumers need per-op edge identity.)

Scope cuts: chamfer per-edge selector still requires a per-edge distance array the bridge doesn't yet expose — falls through to `.unsupported` for `.nearPoint` / `.onFeature` on chamfer specifically. Uniform chamfer (`.all`) works. Flagged as a v0.144 candidate.

### v0.142.0 (Apr 2026) — Construction geometry, sketches, FeatureReconstructor

Second release in the v0.141 → v0.143 arc — ships Phases 2–6 from #72 plus #62 in one go. With this release, OCCTSwift has the full construction-geometry vocabulary that agentic modelling needs: recipe-based references (v0.141) → typed construction entities → document context → sketches → declarative feature reconstruction.

- **`ConstructionPlane` / `ConstructionAxis` / `ConstructionPoint`** (#72 Phase 2): Fusion-style recipe enums carrying `TopologyRef`s. 7 plane variants (absolute, offsetFromFace, throughAxis, tangentToFace, midPlane, byThreePoints, normalToEdge), 5 axis variants (absolute, alongEdge, normalToFace, throughPoints, intersectionOfPlanes), 6 point variants (absolute, atVertex, midpointOfEdge, centroidOfFace, atEdgeParameter, intersectionOfAxisAndPlane). Resolvers compute `Placement` / `(origin, direction)` / `SIMD3<Double>` against a `TopologyGraph`. Typed `ConstructionResolutionError`.
- **`TopologyRef.containedIn` now resolves** (#72 Phase 2 unblock): new `OCCTBRepGraphChildIndices` bridge + `TopologyGraph.childIndices(rootKind:rootIndex:targetKind:)` Swift wrapper.
- **`ConstructionContext`** (#72 Phase 3): Document-level collection with typed opaque IDs (`PlaneID` / `AxisID` / `PointID`), named entities, per-entity resolution against a graph, and `allBroken(in:)` diagnostic returning every entity that fails to resolve. `Document.constructionContext` is a lazy per-document property.
- **`Sketch` + `SketchElement`** (#72 Phase 4): `Sketch` is hosted on a `ConstructionPlane` ID, carries an array of `SketchElement`s with per-element `isConstruction` flag. `buildProfile(in:graph:)` is the **single filter site** (FreeCAD-inspired) — construction elements are excluded when assembling the profile wire. Elements: `.line`, `.polyline`, `.arc`, `.circle` (arcs/circles tessellation comes later).
- **`FeatureReconstructor`** (#62): Declarative `FeatureSpec` tagged union (revolve / extrude / hole / thread / fillet / chamfer / boolean). `FeatureReconstructor.build(from:)` with staged additive → subtractive → finishing → annotation dispatch. `EdgeSelector` enum with `.all`, `.nearPoint`, `.onFeature` — `.onFeature` currently reports `.unsupported` pending full TopologyGraph-integrated dispatcher; `.all` works today for uniform fillet/chamfer. `FeatureReconstructor.buildJSON(_:)` front end parses the OCCTDesignLoop-compatible schema.
- **`Placement`** shared value type (origin + orthonormal basis) with ergonomic `init(origin:normal:)` that picks deterministic x/y axes.

Scope of what the v1 implementation deliberately does **not** do (deferred to later iterations as concrete consumers surface):
- Constraint solving in `Sketch` — explicit non-goal (see #72).
- Named-shape registry for `FeatureSpec.Boolean` with id-based left/right selection.
- `.onFeature` / `.nearPoint` edge resolution in fillet/chamfer dispatch — requires coupling `FeatureReconstructor` to a live `TopologyGraph`, which is the natural next iteration once agents drive it.
- XCAF `CONSTRUCTION` layer persistence — recipes live in-memory; STEP round-trip drops them (matches FreeCAD's 20-year limitation documented in #72).
- Multi-leaf `.createdBy` disambiguation when a single creation splits into many live descendants.

### v0.141.0 (Apr 2026) — Construction-geometry foundation: BRepGraph history readback + TopologyRef

First release in the v0.141 → v0.143 "Construction Geometry" arc (tracked in #72). Builds the substrate for recipe-based topology references that survive mutations — the prerequisite for agent-driven CAD where construction planes / axes / points stay attached to model features through edits.

- **BRepGraph history record readback (#72 Phase 0)**: Exposes the old→new node mappings that the OCCT kernel was already recording. `TopologyGraph.historyRecord(at:)`, `.historyRecords`, `.findOriginal(of:)`, `.findDerived(of:)`, `.recordHistory(operationName:original:replacements:)`. New `TopologyGraph.NodeRef` value type (kind + index) and `HistoryRecord` with full mapping.
- **`TopologyRef` recipe type (#72 Phase 1)**: Indirect enum expressing topology references as *recipes evaluated against the current graph*, not as indices (Onshape FeatureScript-inspired). Cases: `.literal(NodeRef)`, `.createdBy(operationName:kind:occurrence:)`, `.containedIn(parent:kind:occurrence:)`, `.splitOf(original:occurrence:)`. Typed `TopologyResolutionError` enum for failure modes.
- **`TopologyGraph.resolve(_:)`**: Evaluates recipes by walking history records, returns `Result<NodeRef, TopologyResolutionError>`. `.createdBy` picks up newly-introduced replacements by operation name and walks forward to the current form; `.splitOf` picks the Nth replacement of a split original; ancestor-resolution failures surface as `.ancestorMissing`.

Scope: `.containedIn` returns `.noCurrentDescendant` until Phase 2 adds child-at-index accessors. `.createdBy` current-form walk picks the first leaf in deterministic order; multi-leaf disambiguation (useful when a single creation splits into many live descendants) comes in later phases.

### v0.140.0 (Apr 2026) — GD&T write path + typed dimension/tolerance enums

Completes the read-only GD&T support shipped in v0.21.0 with a write path. Downstream callers can now author `XCAFDoc_Dimension` / `XCAFDoc_GeomTolerance` / `XCAFDoc_Datum` attributes, attach them to shape labels, and round-trip through STEP AP242. Typed Swift enums replace the raw `Int32` type codes from v0.21.0 for the full list of XCAFDimTolObjects types.

- **Typed enums**: `Document.DimensionType` (all 32 `XCAFDimTolObjects_DimensionType` cases — Location_Linear, Size_Diameter, Size_Radius, toroidal variants, etc.) and `Document.GeomToleranceType` (all 16 — flatness, perpendicularity, position, profileOfLine, etc.).
- **Typed value types**: `Document.Dimension`, `Document.GeomTolerance`, `Document.Datum`. Accessors: `typedDimension(at:)`, `typedGeomTolerance(at:)`, `typedDatum(at:)`, `typedDimensions`, `typedGeomTolerances`, `typedDatums`.
- **Write path**: `Document.createDimension(on:type:value:lowerTolerance:upperTolerance:)`, `createGeomTolerance(on:type:value:)`, `createDatum(name:)`, `setDimensionTolerance(at:lower:upper:)`. Returns the new attribute's index or nil on failure.
- **Bridge additions**: `OCCTDocumentCreateDimension`, `OCCTDocumentCreateGeomTolerance`, `OCCTDocumentCreateDatum`, `OCCTDocumentSetDimensionTolerance`.

Scope: full modifier / qualifier / grade sequences (`XCAFDimTolObjects_DimensionModif`, `GeomToleranceModif`, `DatumSingleModif` etc.) remain partial wrapping — added on demand. This release covers the 90%-case authoring path.

### v0.139.0 (Apr 2026) — Thread Form v2 + cleanup

Replaces v0.138's circular-sweep thread placeholder with a real truncated V-profile following ISO-68 / UN conventions. Also folds in two quality-of-life cleanups (#68 boolean arg labels, #69 versioned MARK headers).

**Behaviour change**: callers of v0.138's `Shape.threadedHole` / `threadedShaft` will now receive geometry that actually looks like a thread in HLR reprojection (alternating diagonal edges at pitch spacing) rather than a helical groove. API signatures unchanged; new default parameters (`starts: 1`, `runout: .none`) preserve single-start no-runout behaviour.

- **Thread Form v2 (#66 follow-up)**: `ThreadCutterProfile` builds a truncated trapezoidal cross-section with 30° flanks (60° included), H/8 crest flat, H/4 root flat. Swept along a helical spine with `BRepOffsetAPI_MakePipeShell` (correctedFrenet mode) and boolean-cut against the target. New `crestFlat` / `rootFlat` / `minorDiameter` accessors on `ThreadSpec`. New `RunoutStyle` enum (`.none` / `.filleted(radius:)` / `.tapered(turns:)`). New `starts: Int` parameter on `threadedHole` / `threadedShaft` for multi-start threads.
- **Boolean op labels (#68)**: `Shape.union(_:)`, `Shape.intersection(_:)`, `Shape.section(_:)` now match `Shape.subtracting(_:)` — all unlabelled, consistent with `Set.union(_:)` / `Set.intersection(_:)`. Deprecated `with:`-labelled shims kept for backwards compatibility.
- **MARK header refactor (#69)**: 32 versioned grab-bag MARK headers (`// MARK: - v0.X.Y: A, B, C`) renamed to feature-first format (`// MARK: - A, B, C (v0.X.Y)`). Xcode jump-to-section and grep-for-feature now work; OCCTMCP's MARK-based API-reference generator can categorise without a regex fallback.

Tapered-runout law-based pipe-shell is tracked as a follow-up — the `.tapered` case falls back to `.filleted` until `BRepOffsetAPI_MakePipeShell::SetLaw` is wrapped.

### v0.138.0 (Apr 2026) — Engineering Drawings II: DXF export + thread features

Second release in the v0.137 → v0.139 arc. Closes #63 (DXF export) and #66 (ISO thread features). ~50 ops.

- **DXF 2D writer (#63)**: Custom pure-Swift DXF R12 ASCII writer (OCCT ships no DXF support — confirmed by audit). `Exporter.writeDXF(drawing:to:deflection:)` walks a `Drawing`'s visible / hidden / outline edges through `Shape.allEdgePolylines` and emits LINE / LWPOLYLINE / CIRCLE / ARC / TEXT entities. Layers: VISIBLE / HIDDEN / OUTLINE / CENTER / DIMENSION / TEXT, with appropriate linetypes (CONTINUOUS / DASHED / CHAIN). Dimensions from v0.137's `DrawingDimension` are emitted as exploded LINE+TEXT geometry (universally readable). `Exporter.writeDXF(shape:to:viewDirection:)` convenience combines projection and write. Public `DXFWriter` for callers composing DXF manually.
- **Thread features (#66)**: `ThreadForm` enum (iso68 / unified); `ThreadSpec` struct with `parse("M5x0.8")`, `parse("1/4-20 UNC")`, metric-coarse-pitch table, theoretical and cut depth accessors, minor-diameter computation. `Shape.threadedHole(axisOrigin:axisDirection:spec:depth:)` and `Shape.threadedShaft(axisOrigin:axisDirection:spec:length:)` produce helical cut / boss geometry via `BRepOffsetAPI_MakePipeShell` sweep of a circular profile. Integrates with #62's `FeatureReconstructor` — `FeatureSpec.Thread` can now route through real geometry instead of annotation-only.

Scope decisions: v1 threads use a circular sweep cross-section rather than full 60° flank triangle — produces correct handedness, pitch, diameter, and depth for reprojection diff and visualisation; manufacturing-accurate flanks land in a follow-up release. Multi-start threads, ACME / BSP / NPT forms, and full BRepOffsetAPI_MakePipeShell option wrapping (SetForceApproxC1, multi-profile Add()) deferred. GLTF Shape-level export, PLY import, STEP/IGES option completeness dropped from v0.138 — Document-level GLTF already ships, and the remaining gaps are low priority vs. closed-loop pipeline needs.

### v0.137.0 (Apr 2026) — Engineering Drawings I: axes, dimensions, centrelines

Keystone release for the v0.137 → v0.139 "Engineering Drawings" series (tracked in #67). Adds axis extraction from shapes (#65), a pure-Swift value-type dimensioning API on `Drawing` (#64), and auto-centreline generation bridging the two. ~60 ops.

- **Axis extraction (#65)**: `Face.primaryAxis`, `Shape.revolutionAxes(tolerance:)`, `Shape.symmetryAxes(fractionalTolerance:)`, `Surface.torusAxis`, `Surface.revolutionAxis`. New `ShapeAxis` value type with `.cylinder`/`.cone`/`.sphere`/`.torus`/`.revolution`/`.extrusion`/`.symmetry` kinds. Bridge: `OCCTSurfaceTorusAxis`, `OCCTSurfaceRevolutionAxis`, `OCCTSurfaceRevolutionLocation`, `OCCTFaceGetPrimaryAxis`, `OCCTShapeRevolutionAxes`, `OCCTShapeSymmetryAxes`.
- **Surface introspection completeness**: typed `Surface.SurfaceType` + `Surface.surfaceKind`; `Surface.Continuity` + `Surface.continuityClass`; type-predicate conveniences `isPlane` / `isCylinder` / `isCone` / `isSphere` / `isTorus` / `isBezier` / `isBSpline` / `isSurfaceOfRevolution` / `isSurfaceOfExtrusion` / `isOffsetSurface`.
- **Drawing dimensioning API (#64)**: `DrawingDimension` tagged union (linear / radial / diameter / angular) + `DrawingAnnotation` tagged union (centreline / centremark / text label). `DrawingLineStyle` enum. Methods on `Drawing`: `addLinearDimension`, `addRadialDimension`, `addDiameterDimension`, `addAngularDimension`, `addCentreLine`, `addCentermark`, `addTextLabel`, `clearAnnotations`, plus `dimensions` / `annotations` accessors. Pure-Swift value types — XDE round-trip deferred to v0.139 (#67).
- **Auto-centreline generation (#64 ↔ #65)**: `Drawing.addAutoCentrelines(from:viewDirection:overshoot:tolerance:bounds:)` projects a shape's revolution axes into the drawing's view plane and emits chain-pattern centrelines; axes parallel to the view direction are returned in `.skipped`.

Scope decisions (see #67 for rationale): Full PrsDim display-dimension completeness (MaxRadius / MinRadius / Chamf2d / Chamf3d) and PrsDim geometric-relation wrapping (Concentric / Parallel / etc.) were cut from v0.137 — they are AIS display objects with low marginal value compared to the Swift value-type API that drives the closed-loop drawing workflow.

### v0.132.0 - v0.136.0 (Apr 2026) — BRepGraph Topology Graph

Wraps OCCT's new BRepGraph API — graph-based B-Rep topology with cache-friendly traversal, O(1) upward navigation, and parallel geometry extraction. 163 operations across 5 releases.

- **v0.136.0**: ML-friendly graph export (COO adjacency, node features, JSON), UV-grid face sampling (positions/normals/curvatures), edge curve sampling — for GNN/UV-Net/BRepNet pipelines
- **v0.135.0**: Builder mutations — AddVertex/Shell/Solid, AddFaceToShell/ShellToSolid, AddCompound, RemoveNode/Subgraph, AppendShape, deferred invalidation, SplitEdge, ReplaceEdgeInWire
- **v0.134.0**: Product/Occurrence assembly queries, RefsView per-kind counts and entry access, edge start/end vertices, shell closure, compound hierarchy
- **v0.133.0**: Shape reconstruction from graph nodes, BRepGraph_Tool vertex/edge/face geometry access, CoEdge half-edge queries, history tracking, graph copy/transform, poly counts
- **v0.132.0**: Core graph — build from shape, topology/geometry counts, face adjacency, shared edges, edge boundary/manifold, child/parent explorers, validate, compact, deduplicate, stats

### v0.129.0 - v0.131.0 (Apr 2026) — RC5 New APIs

- **v0.131.0**: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier curves+surfaces, GeomAdaptor_TransformedCurve
- **v0.130.0**: GeomEval analytical curves (helix, sine wave), analytical surfaces (ellipsoid, hyperboloid, paraboloid, helicoid), Geom2dEval spirals, GeomFill_Gordon, PointSetLib, ExtremaPC
- **v0.129.0**: IGES mutex serialization (thread safety fix per OCCT #1179)

### v0.120.0 - v0.128.0 (Apr 2026) — Completion & Polish

Final method-level coverage of all user-facing OCCT classes.

- **v0.128.0**: v0.128.0 release (3333 ops total)
- **v0.125.0**: BSplineSurface deep (20), Geom2d_BSpline (20), BezierCurve (8), BezierSurface (12)
- **v0.124.0**: ChamferBuilder (20), FilletBuilder (16), WireAnalyzer (18)
- **v0.123.0**: ThruSections/CellsBuilder/PipeShell/UnifySameDomain/Section extensions
- **v0.122.0**: WireFixer, ShapeFix_Edge, BRepTools/BRepLib statics, History, Sewing extensions
- **v0.121.0**: GLTF import/export (xcframework rebuilt with RapidJSON), FilletBuilder, ChamferBuilder
- **v0.120.0**: IsCN, ReversedParameter, ParametricTransformation, gp extras, surface reversed copies

### v0.110.0 - v0.119.0 (Mar-Apr 2026) — Constraint Solvers & Serialization

- **v0.119.0**: BREP serialization, gp_Pln/gp_Lin distance/contains, BezierSurface queries
- **v0.118.0**: BRepBndLib, ShapeAnalysis tolerance, BRepAlgoAPI_Check/Defeaturing
- **v0.116.0**: Helix construction, gp_Ax3/GTrsf2d/Mat2d, quaternion interpolation
- **v0.115.0**: Interpolation expansion, ThruSections builder, Triangulation queries
- **v0.114.0**: TopoDS_Builder, ShapeContents, FreeBoundsProperties, WireBuilder
- **v0.113.0**: MakeEdge completions, multi-result projections, DistShapeShape full results
- **v0.112.0**: RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte, wire/shell construction
- **v0.111.0**: PSO, GlobOptMin, FunctionRoots, GaussIntegration, BRepLProp
- **v0.110.0**: Constraint solver infrastructure — C callback adapters for OCCT math solvers

### v0.100.0 - v0.109.0 (Mar 2026) — Geometry Factories & Extrema

- **v0.109.0**: Extrema elementary distances, TrigRoots, IntAna2d, BRepAlgo_NormalProjection
- **v0.108.0**: Complete Geom_ and Geom2d_ method coverage — all conic/surface property methods
- **v0.107.0**: BSpline manipulation (3D/2D/surface), Bezier methods, BRepTools, Sewing, Hatch
- **v0.106.0**: GC surface factories, ShapeAnalysis_Wire/Edge, BRepLib_MakeEdge2d
- **v0.105.0**: GC/GCE2d geometry factories, GCPnts uniform sampling, CompCurveToBSpline (90 ops)
- **v0.104.0**: BndLib analytic bounding, OSD_Host/PerfMeter, IntAna_IntQuadQuad
- **v0.103.0**: gce transform factories, GProp element properties, Plate constraints
- **v0.102.0**: TopExp adjacency, Poly_Connect mesh adjacency, BRepOffset_Analyse
- **v0.101.0**: Geom_TrimmedCurve, BRepLib_FindSurface, ShapeAnalysis_Surface, Resource_Manager
- **v0.100.0**: RWStl I/O, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection

### v0.90.0 - v0.99.0 (Mar 2026) — OCAF Extensions & Math

- **v0.99.0**: Convert_CompBezierCurves, Geom_OffsetSurface, OSD_File, ShapeFix_Wireframe
- **v0.98.0**: IntAna analytic intersections, OSD_Chronometer/Process, Draft_Modification
- **v0.97.0**: BRepAlgo_Loop, Bnd_BoundSortBox, BRepGProp_Domain, TNaming_Naming, Precision
- **v0.96.0**: XCAFDoc_AssemblyItemRef, BRepAlgo_Image, OSD_Path, BRepClass_FClassifier
- **v0.95.0**: Convert ellipse/hyperbola/parabola/cylinder/cone/torus to BSpline
- **v0.94.0**: math_Matrix/Gauss/SVD/PolynomialRoots/Jacobi, Convert circle/sphere to BSpline
- **v0.93.0**: OSD_MemInfo, ShapeFix_EdgeProjAux, Geom2dAPI_Interpolate, BRepAlgo_FaceRestrictor
- **v0.92.0**: Bnd_OBB, Bnd_Range, BRepClass3d point-in-solid, TDataXtd_Constraint
- **v0.91.0**: ElCLib curve evaluation, ElSLib surface evaluation, gp_Quaternion, OSD_Timer
- **v0.90.0**: TDF_ChildIDIterator, TDocStd_PathParser, TFunction_DriverTable, TNaming extensions

### v0.80.0 - v0.89.0 (Mar 2026) — Extrema, Color Science & OCAF Deep

- **v0.89.0**: TDF_Transaction/Delta, TDF_ComparisonTool, TDocStd_XLinkTool
- **v0.88.0**: TNaming extensions, TDataStd_IntPackedMap, TDataStd_NoteBook
- **v0.87.0**: TDataStd_Tick/Current, ShapeAnalysis_Shell, CanonicalRecognition
- **v0.86.0**: TDataStd extended attributes (BooleanArray, ByteArray, IntegerList, etc.)
- **v0.85.0**: UnitsAPI, BinTools binary I/O, Message_Messenger/Report
- **v0.84.0**: VrmlAPI_Writer, TDataStd_Directory/Variable, TDocStd_XLink
- **v0.83.0**: XCAFDoc attributes, Notes, ClippingPlaneTool, AssemblyGraph (97 ops)
- **v0.82.0**: Quantity_Period/Date, Font_FontMgr, Image_AlienPixMap (39 ops)
- **v0.81.0**: Quantity_Color, Quantity_ColorRGBA, Graphic3d materials (24 ops)
- **v0.80.0**: Extrema 3D/2D, GeomTools persistence, ProjLib, gce factories (35 ops)

### v0.70.0 - v0.79.0 (Mar 2026) — TKBool, TKFillet, TKHlr & Geometry Deep

- **v0.79.0**: Poly_CoherentTriangulation, BRepFill_Evolved, BRepExtrema_DistanceSS, GeomFill
- **v0.78.0**: BRepTools modifications, ShapeUpgrade_SplitSurface, GeomConvert, Poly_Polygon
- **v0.77.0**: GeomLib utilities, GccAna circle/line solvers, Approx_SameParameter
- **v0.76.0**: Geom_CartesianPoint, Geom_Direction, Axis1/2Placement, ShapeConstruct_Curve (41 ops)
- **v0.75.0**: BiTgte_Blend, GeomConvert_ApproxCurve/Surface, GCPnts, BRepGProp
- **v0.74.0**: TKMesh/TKOffset/TKPrim/TKShHealing/TKTopAlgo gap closure
- **v0.73.0**: Extended HLR edges, HLRAppli_ReflectLines, Intrv_Interval (29 ops)
- **v0.72.0**: LocOpe_Gluer, ChFi2d_Builder/ChamferAPI/FilletAPI, FilletSurf_Builder
- **v0.71.0**: IntTools_BeanFaceIntersector, BOPAlgo_WireSplitter, BRepFeat_SplitShape
- **v0.70.0**: IntTools EdgeEdge/EdgeFace/FaceFace, BOPAlgo BuilderFace/BuilderSolid

### v0.60.0 - v0.69.0 (Mar 2026) — Data Exchange & TKGeomAlgo

- **v0.69.0**: NLPlate G2/G3, Plate_Plate solver, GeomPlate, GeomFill Generator (20 ops)
- **v0.68.0**: TopTrans_CurveTransition, GeomFill trihedrons, GccAna_Circ2d3Tan (18 ops)
- **v0.67.0**: FairCurve, LocalAnalysis, TopTrans SurfaceTransition (8 ops)
- **v0.66.0**: Full TkG2d — Point2D, Transform2D, AxisPlacement2D, Vector2D (44 ops)
- **v0.65.0**: BOPAlgo RemoveFeatures/Section, ShapeBuild, ShapeExtend, ShapeUpgrade (24 ops)
- **v0.64.0**: ProjLib, BRepOffset_Offset, Adaptor3d_IsoCurve (9 ops)
- **v0.63.0**: GeomLProp, BRepOffset_SimpleOffset, GeomInt_IntSS, Contap_Contour (17 ops)
- **v0.62.0**: BRepLib topology, MakeEdge2d, ShapeCustom, LocOpe, CPnts (22 ops)
- **v0.61.0**: Approx, Contap, BOPAlgo, IntCurvesFace, BRepMesh, GeomPlate (19 ops)
- **v0.60.0**: XDE/XCAF Full Coverage (42 ops)

### v0.50.0 - v0.59.0 (Feb-Mar 2026) — OCAF & Data Exchange

- **v0.59.0**: IGES/OBJ/PLY Full Coverage (23 ops)
- **v0.58.0**: STEP Full Coverage (25 ops)
- **v0.57.0**: OCAF Persistence (17 ops)
- **v0.56.0**: TDataXtd + TFunction (29 ops)
- **v0.55.0**: TDataStd Attributes (25 ops)
- **v0.54.0**: TDF Core + TDocStd (31 ops)
- v0.50.0-v0.53.0: Various additions

### v0.38.0 - v0.49.0 (Feb 2026) — Audit & Gap Closure

Systematic OCCT test suite audit rounds (7 rounds total), closing gaps in primitives, sweeps, booleans, modifications, healing, measurement, and topology.

### v0.27.0 - v0.37.0 (Feb 2026) — RC4 Upgrade & Feature Expansion

- OCCT 8.0.0-rc3 → rc4 upgrade
- Feature-based modeling, pattern operations, shape editing
- Topological naming (TNaming), OCAF framework
- TDataStd/TDataXtd attributes, TFunction framework

### v0.16.0 - v0.26.0 (Feb 2026) — Parametric Geometry

- 2D/3D parametric curves (Geom2d, Geom) with Metal draw methods
- Parametric surfaces with curvature analysis
- Law functions for variable-section sweeps
- Medial axis transform
- Camera, selection, presentation mesh
- Color science, materials

### v0.6.0 - v0.15.0 (Jan 2026) — XDE & Annotations

- XDE document support (assembly, colors, materials, GD&T)
- Annotations (dimensions, text labels, point clouds)
- KD-tree spatial queries
- Polynomial solver, hatch patterns

### v0.1.0 - v0.5.0 (Dec 2025 - Jan 2026) — Foundation

- Basic primitives, booleans, transforms
- Wire creation, sweep operations
- Mesh generation, STL/STEP import/export
- Shape validation and healing
- STEP optimization
