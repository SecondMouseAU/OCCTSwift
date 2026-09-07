# #1399, reading family `geometry`: 44 classes

The reading list is derived, not typed:

```bash
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family geometry
```

It grew from 32 to 44 mid-pass when the twelve `GeomEval_*`/`Geom2dEval_*` analytic evaluators
moved out of the "this project invented them" bucket. They are genuine OCCT 8.0.1 classes in
`TKG3d` and `TKG2d`, present in the pinned headers, and that misclassification is itself the
subject of the largest finding below: the docs made the same mistake in prose.

**Run on this branch, that command now prints 23, not 44, and this is the pass working rather
than a stale number.** `derive_lane.py` puts a class in `machine-covered` when a claim the
attribution census parses names it, and the fixes below gave twenty-one of the forty-four an
`- **OCCT:**` bullet naming their real class for the first time. So they are now re-checked by
`census-doc-occt-attribution.py` on every run, whole-tree, instead of sitting in the algorithm
bucket waiting to be read by hand. The twenty-one, all of them `over` rows in the table:

    CPnts_UniformDeflection       Geom2dGcc_QualifiedCurve   LProp_CurAndInf
    LProp_CIType                  ProjLib_Plane              ProjLib_Cylinder
    HelixGeom_HelixCurve          HelixGeom_BuilderHelix     HelixGeom_BuilderHelixCoil
    GeomEval_EllipsoidSurface     GeomEval_HyperboloidSurface
    GeomEval_ParaboloidSurface    GeomEval_HypParaboloidSurface
    GeomEval_CircularHelicoidSurface  GeomEval_TBezierSurface  GeomEval_AHTBezierSurface
    Geom2dEval_ArchimedeanSpiralCurve  Geom2dEval_LogarithmicSpiralCurve
    Geom2dEval_SineWaveCurve      Geom2dEval_TBezierCurve    Geom2dEval_AHTBezierCurve

23 + 21 = 44. To reproduce the reading list this pass worked from, run `--family geometry` at
`2b714c83..0a2872e6` (the lane branch before this commit). The twenty-three that remain are the
`ok` and `deliberate, recorded` rows plus `GeomConvert`, `GeomAbs_IsoType`, `GccEnt_Position`,
`GccInt_IType` and `Law_BSpFunc`, whose corrections were prose rather than a new class name on an
attribution bullet.

`derive_lane.py --self-test` is **14/14** on this branch; it was 13/13 when this pass began, and
12/12 when the pass was briefed. The count is the coordinator's to move, and it has moved twice.

## Result

| verdict | count |
|---|---|
| `ok` | 8 |
| `deliberate, recorded` | 10 |
| `under` | 1 |
| `over` | 25 |

Four `over` rows carry an `under` alongside (marked `+under`); the verdict column names the more
severe of the two, which in each case is the false statement rather than the missing one. One
further `under` was found on a class just outside the 44 and is recorded under "Adjacent findings".

**Every `ok` row was checked against `census-doc-occt-attribution.py` before being called `ok`**,
after the coordinator's correction that the census's 431 findings are reported-but-unadjudicated
rather than clean. The cross-reference is mechanical:

```bash
python3 Scripts/census-doc-occt-attribution.py > /tmp/attr.txt
# then grep /tmp/attr.txt for each class, and for each of its bridge functions' names in via=
```

None of the 44 class names appears in the census's own finding list, because the census names the
class *the doc names*, not the class the bridge reaches. Grepping the `via=` column for this
family's bridge entry points is what surfaced its share, and that is the query recorded here for
the next reader.

## Table

`census` = the finding was already in `census-doc-occt-attribution.py`'s output and had simply
never been adjudicated. `read` = the census cannot see it; the two blind spots are item 1 of "For the integrator".

| class | verdict | found by | one-line evidence |
|---|---|---|---|
| `GeomConvert` | `over` | read | `docs/API_REFERENCE.md:600` gave `Curve3D.join(_:)` as `GeomConvert::ConcatG1`; `OCCTCurve3DJoinToBSpline` uses `CurveToBSplineCurve` + `GeomConvert_CompCurveToBSplineCurve::Add`, and `ConcatG1` is called nowhere in the bridge |
| `Adaptor3d_Curve` | `deliberate, recorded` | — | the parameter type of the six shared `adaptor*` helpers in the `Curve3D_*.mm` set and the base whose `Value`/`D1`/`D2` the helix evaluators call; never a Swift type |
| `Convert_ElementarySurfaceToBSplineSurface` | `deliberate, recorded` | — | base class taken by reference by one shared helper (`OCCTBridge_Surface_Adaptor.mm:488`); its four concrete subclasses each have their own `docs/reference/Document-Math-Bounds.md` entry |
| `CPnts_UniformDeflection` | `over` | census | `docs/reference/Shape-Builders-1.md:1492,1512` attributed `uniformDeflection` to `GCPnts_UniformDeflection`; the bridge uses `CPnts_UniformDeflection` and the repo wraps `GCPnts_` separately, behind `drawDeflection` |
| `Geom2dGcc_QualifiedCurve` | `over` | census | `docs/reference/Curve2D.md` named five OCCT classes that do not exist in the pinned kernel (see finding 3) |
| `GeomAbs_JoinType` | `ok` | — | the three join kinds are documented as `OffsetJoinType` (`docs/reference/Shape.md:1078`, `Document-Mesh-Fixing.md:3114`) and as `Wire.JoinType`'s two-case subset, and every mapping site agrees with the enum's ordinals |
| `GccEnt_Position` | `over` `+under` | read | "Pass these alongside curves in **every** `Curve2DGcc` solver call" is false, and the orientation-dependent definition of "inside" was missing |
| `Geom2dConvert` | `ok` | — | `Geom2dConvert::CurveToBSplineCurve(curve, parameterisation)` and `::C0BSplineToArrayOfC1BSplineCurve` are both named and both reached (`OCCTBridge_Geom2d_Conversion.mm:1777`, `_Curves.mm:2577`) |
| `Convert_ConicToBSplineCurve` | `deliberate, recorded` | — | base class taken by `buildCurve2DFromConic`; the four conic subclasses each have their own doc entry, with measured degenerate-input behaviour |
| `Law_BSpFunc` | `over` `+under` | read | "Only works on BSpline-based law functions created via `bspline(...)`" names one factory where four qualify; measured, and now a test |
| `ElCLib` | `ok` | — | `LineValue`/`CircleValue`/`EllipseValue`/`LineD1`/`CircleD1` are reached: `ElCLib::Value(U, gp_Lin)` inlines to `LineValue(U, L.Position())` (`ElCLib.lxx:28`) |
| `gp` | `deliberate, recorded` | — | two call sites, both `gp::DZ()` as a default axis; a named constant, not a caller-visible type |
| `LProp_CurAndInf` | `over` | census + read | `docs/reference/Shape-Builders-2.md:875` named `LProp_AnalyticCurInf`, which exists nowhere in the pinned kernel or its source, for what is a bridge-side computation over `LProp_CurAndInf` |
| `GccEnt_QualifiedLin` | `deliberate, recorded` | — | built inside four `GccAna_*` bridge functions from the caller's point-and-direction pair, always `GccEnt_unqualified` except in the two `Circ2d2TanOn`/`Circ2dTanOnRad` entries whose qualifier is documented as `Curve2DQualifier` |
| `Geom2d_Point` | `deliberate, recorded` | — | the abstract handle type three `Geom2d_CartesianPoint` locals are held by; the concrete class is what is constructed and what the docs name |
| `ElSLib` | `ok` | — | same inline-forwarding shape as `ElCLib`: `ElSLib::D1(U, V, gp_Sphere, ...)` inlines to `SphereD1` (`ElSLib.lxx:174`) |
| `GccEnt_QualifiedCirc` | `deliberate, recorded` | — | as `GccEnt_QualifiedLin`; a wrapper the Swift caller never sees, built from centre and radius |
| `Geom2dGridEval` | `ok` | — | `docs/API_REFERENCE.md:772` gives `Geom2dGridEval_Curve::EvaluateGridD1`, which is what `OCCTCurve2DEvaluateGridD1` constructs and calls; the bare namespace only supplies the `CurveD1` alias |
| `TColGeom_Array2OfBezierSurface` | `deliberate, recorded` | — | a container: the patch grid passed to `occtAnyBezierPatchIsRational` and `OCCTSurfaceJoinBezierPatches`, whose Swift surface is `[Surface]` |
| `Adaptor3d_CurveOnSurface` | `deliberate, recorded` | — | built inside `OCCTValidateEdge`, `OCCTGeomFillDarbouxTrihedron` and `OCCTGeomFillBoundWithSurfEvaluate` to pair a pcurve with its surface; never returned |
| `GccInt_IType` | `over` | read | the enum selects which conic payload `extractBisecSolution` writes, and both the doc and the bridge header described that payload wrongly (see finding 5) |
| `GeomEval_HyperboloidSurface` | `over` `+under` | read | `- **OCCT:**` named a bridge C symbol, and nothing said `twoSheets: true` returns one sheet |
| `Adaptor2d_Curve2d` | `deliberate, recorded` | — | one site: the `Handle(Adaptor2d_Curve2d)` that `Approx_Curve2d` takes in `OCCTApproxCurve2d`; `Curve2D.approximatedInRange` is what the caller sees |
| `GeomGridEval` | `ok` | — | as `Geom2dGridEval`: `GeomGridEval_Curve`/`_Surface` are named and reached; the bare name is a namespace of aliases and template helpers |
| `LProp_CIType` | `over` | read | the same entry claimed "inflections"; `OCCTLPropAnalyticCurInf` only ever calls `AddExtCur`, so `CurvaturePointType.inflection` is unreachable |
| `ProjLib_Plane` | `over` | census | `docs/reference/Document-Transforms.md:1270,1301` said `→ ProjLib::Project`; the bridge constructs `ProjLib_Plane` and reads `IsDone()`/`Line()`/`Circle()` |
| `FairCurve_AnalysisCode` | `ok` | — | `FairCurveCode`'s four cases match the enum's ordinals, and `docs/reference/Curve2D-Analysis.md` documents each with the header's own explanation |
| `Geom2dEval_ArchimedeanSpiralCurve` | `over` | read | `- **OCCT:**` named a bridge C symbol, and the entries said nothing about the unguarded throw (#1646) |
| `Geom2dEval_LogarithmicSpiralCurve` | `over` | read | as above |
| `Geom2dEval_SineWaveCurve` | `over` | read | as above |
| `GeomEval_CircularHelicoidSurface` | `over` | read | `- **OCCT:**` named a bridge C symbol; the section preamble called these "`Geom_CartesianPoint`-derived" |
| `GeomEval_EllipsoidSurface` | `over` | read | as above, plus "custom `Geom_Surface` evaluator" on its own bullet |
| `GeomEval_HypParaboloidSurface` | `over` | read | as above |
| `GeomEval_ParaboloidSurface` | `over` | read | as above |
| `HelixGeom_HelixCurve` | `over` | census | three bullets attributed `Helix.evaluate`/`evaluateD1`/`evaluateD2` to `HelixGeom_Helix::Value`/`D1`/`D2`; no `HelixGeom_Helix` exists |
| `ProjLib_Cylinder` | `over` | census | `docs/reference/Document-Transforms.md:1285` said `→ ProjLib::Project`; the bridge constructs `ProjLib_Cylinder` |
| `Geom2dEval_AHTBezierCurve` | `over` | read | `- **OCCT:**` named `OCCTGeom2dEvalAHTBezierCurveCreate` |
| `Geom2dEval_TBezierCurve` | `over` | read | `- **OCCT:**` named `OCCTGeom2dEvalTBezierCurveCreate` |
| `GeomEval_AHTBezierSurface` | `over` | read | `- **OCCT:**` named `OCCTGeomEvalAHTBezierSurfaceCreate` |
| `GeomEval_TBezierSurface` | `over` | read | `- **OCCT:**` named `OCCTGeomEvalTBezierSurfaceCreate` |
| `GeomProjLib` | `ok` | — | all three documented statics (`Curve2d`, `Project`, `ProjectOnPlane`) are called, at `OCCTBridge_ProjLib_NLPlate.mm:103,161,193` |
| `HelixGeom_BuilderHelix` | `over` | census | `Helix.build` was attributed to `HelixGeom_Helix` + `GeomAPI_PointsToBSpline`; neither is reached |
| `HelixGeom_BuilderHelixCoil` | `over` | census | `Helix.buildCoil` was attributed to a "`HelixGeom_Helix` coil variant"; it is a separate builder class |
| `GeomAbs_IsoType` | `under` | read | the U/V selection is documented, but the `-1e6...1e6` clamp on an infinite iso, and the `count` origin points a non-face shape yields, were not |

## The findings

### 1. Twelve classes documented as if this project had written them (`over`, read)

The largest finding, and the one no detector can reach. Every `GeomEval_*` and `Geom2dEval_*`
entry's `- **OCCT:**` bullet named a **bridge C function** where every sibling entry in the same
file names an OCCT class:

```
- **OCCT:** `OCCTGeomEvalEllipsoidCreate`, custom `Geom_Surface` evaluator.
- **OCCT:** `OCCTGeom2dEvalTBezierCurveCreate`.
```

Two claims in that shape are false rather than merely thin. "custom … evaluator" says this project
wrote the evaluator; it did not. And `docs/reference/Surface.md:1304` described the whole family as
"backed by `Geom_CartesianPoint`-derived evaluator surfaces". `Geom_CartesianPoint` is a
`Geom_Point` (`Geom_CartesianPoint.hxx:...`), so it is not a surface at all, and the real bases are
`Geom_ElementarySurface` for the five analytic surfaces and `Geom_BoundedSurface` for the two
Bezier ones, measured from the pinned headers:

```
GeomEval_EllipsoidSurface              class GeomEval_EllipsoidSurface : public Geom_ElementarySurface
GeomEval_TBezierSurface                class GeomEval_TBezierSurface : public Geom_BoundedSurface
Geom2dEval_ArchimedeanSpiralCurve      class Geom2dEval_ArchimedeanSpiralCurve : public Geom2d_Curve
Geom2dEval_TBezierCurve                class Geom2dEval_TBezierCurve : public Geom2d_BoundedCurve
```

Consequence for a reader: a page that says a surface is a project-local evaluator does not tell you
it composes with the rest of the kernel. It does. Fixed: every bullet now names its OCCT class, and
the two preambles say what these are and what they derive from, without naming the base class *on
the attribution bullet* (see "Not making the census worse").

The parametrisation formulas already in those pages were checked line by line against the header
comments and are all correct.

### 2. Four `Geom2dEval_*` evaluators crash on an ordinary argument (filed as #1646)

Found while reading the same twelve. Ten bridge entry points construct a `Geom2dEval_*` curve with
**no `try`/`catch`**, and their constructors throw `Standard_ConstructionError` on plain caller
values. Every 3D `GeomEval*` sibling and every `*Create` in the same files has a `try`/`catch`; the
ten are the only ones without.

Measured, not inferred: `probe_geom2deval_throws.mm` in `Scripts/repro/1399-geometry/`, transcript
beside it.

```
  SineWaveCurve(amplitude=0, omega=1, phase=0)               THREW Standard_Failure: Geom2dEval_SineWaveCurve: amplitude must be > 0
  CircleInvoluteCurve(radius=0)                              THREW Standard_Failure: Geom2dEval_CircleInvoluteCurve: radius must be > 0
  ArchimedeanSpiralCurve(initialRadius=1, growthRate=0)      THREW Standard_Failure: Geom2dEval_ArchimedeanSpiralCurve: growth rate must be > 0
  LogarithmicSpiralCurve(scale=0, growthExponent=0.2)        THREW Standard_Failure: Geom2dEval_LogarithmicSpiralCurve: scale must be > 0
```

Per CLAUDE.md's Known OCCT Bugs a C++ exception reaching the Swift boundary is uncatchable in this
build (#345), so `Geom2dEval.sineWaveD0(amplitude: 0, ...)` aborts the process.

Filed as **#1646** rather than fixed here: it needs a signature or contract decision across all ten
(silent zero, an added `bool` return, or optional-returning Swift), a bridge edit, `format-bridge`,
and a test per class. The docs now state the current contract and point at #1646.

The `GeomEval*` 3D evaluators have the milder version of the same problem: they catch, leave the
out parameters untouched, and the Swift wrappers pre-zero them, so a rejected argument reads back
as `SIMD3(0, 0, 0)`. That is #726's subject and `census-unmeasured-values.py` does not see it. The
contract is now documented rather than left to be discovered.

### 3. Five OCCT classes that do not exist, in the `Gcc` family (`over`, census)

`docs/reference/Curve2D.md` attributed five `Curve2DGcc` members to `Geom2dGcc_Circ2d2TanPt`,
`Geom2dGcc_Circ2dTanPtRad`, `Geom2dGcc_Circ2d2PtRad`, `Geom2dGcc_Circ2d3Pt` and
`Geom2dGcc_Lin2dTanPt`. None is a header in the pinned kernel; each is the **bridge function's own
name** with the OCCT package prefix stuck on, which is `measure-dont-assume.md`'s "the adjacent
identifier reads as the one you need" exactly, and the same mistake #811 found five of.

What they actually build, read from `OCCTBridge_Geom2d_GccSolver.mm` and `_Curves.mm`:

| Swift member | real OCCT construction |
|---|---|
| `circlesTangentToTwoCurvesAndPoint` | `Geom2dGcc_Circ2d3Tan`, two-qualified-curve + point ctor |
| `circlesTangentToPointWithRadius` | `Geom2dGcc_Circ2d2TanRad`, qualified-curve + point ctor |
| `circlesThroughTwoPoints` | `Geom2dGcc_Circ2d2TanRad`, two-`Geom2d_CartesianPoint` ctor |
| `circleThroughThreePoints` | `Geom2dGcc_Circ2d3Tan`, three-`Geom2d_CartesianPoint` ctor |
| `linesTangentToPoint` | `Geom2dGcc_Lin2d2Tan`, qualified-curve + point ctor |

`docs/reference/Curve2D-Constraint-Solvers.md` had all five right already, which is worth recording
for its own sake: **a first reading of this pass called two of that page's rows wrong** on the
assumption that the point-only members went to `GccAna_*` like their neighbours. They do not; they
take the `Geom2dGcc_*` point constructors. The rejection came from reading the bodies, and the
brief's warning that this repo has mis-documented the `Gcc` family before applies to the auditor
too.

### 4. `GccEnt_Position`: "every solver call", and the missing orientation rule (`over` `+under`)

`docs/reference/Curve2D-Constraint-Solvers.md:174` said "Pass these alongside curves in every
`Curve2DGcc` solver call". Four members take no qualifier at all
(`circlesThroughTwoPoints`, `circleThroughThreePoints`, `hatch`, and every `GccAnaBisector`
member), because a point has no inside.

The `under` in the same entry is the semantics the whole family turns on, from
`GccEnt_Position.hxx`:

> Note: the interior of a line or any open curve is defined as the left-hand side of the line or
> curve in relation to its orientation.

So `enclosing` and `enclosed` swap meaning when a curve is reversed. Nothing in `docs/` or in the
`///` said so. Both are now stated, along with why OCCT's fifth value `GccEnt_noqualifier` is
deliberately not mirrored: it is a read-back result from `Geom2dGcc_QualifiedCurve::Qualifier()`,
never an input, and nothing in this API reads a qualifier back.

### 5. `GccInt_IType`: the bisector payload, wrong in the docs and in the bridge header (`over`)

`BisecSolution` carries three loosely typed fields whose meaning depends on `type`.
`docs/reference/Curve2D-Constraint-Solvers.md` said `position` is the "focus for conics" and
`secondary` the "semi-axes for conics"; `Sources/OCCTBridge/include/OCCTBridge_Geom2d.h` said
"(px, py) is focus/center, radius is semi-axis". Read against `extractBisecSolution` and the `gp`
headers, none of that holds:

| `GccInt_IType` branch | `position` is | `secondary` is | `radius` |
|---|---|---|---|
| `GccInt_Ell` | `gp_Elips2d::Location`, "the **center** of the ellipse" | `(MajorRadius, MinorRadius)` | `0` |
| `GccInt_Hpr` | `gp_Hypr2d::Location`, the XAxis/YAxis intersection | `(MajorRadius, MinorRadius)` | `0` |
| `GccInt_Par` | `gp_Parab2d::Location`, "the **vertex** of the parabola" | `(Focal(), 0)` | `0` |

No conic reports a focus, `radius` is `0` for every conic, and the parabola's `secondary` is a
focal distance rather than a pair of semi-axes. Corrected in the reference page, in the `///`, and
in the bridge header (clang-format re-run).

Not a code defect: the switch is on the named enumerator, so `GccInt_IType`'s ordinals
(`Lin, Cir, Ell, Par, Hpr, Pnt`) differing from `BisecType`'s (`line, circle, ellipse, hyperbola,
parabola, point`) at positions 3 and 4 costs nothing. That was checked because it looks exactly
like an off-by-order bug.

### 6. `LProp_CurAndInf` / `LProp_CIType`: a class that does not exist, over a bridge-side computation (`over`)

`docs/reference/Shape-Builders-2.md:875` gave `Shape.analyticCurvaturePoints` as
`- **OCCT:** LProp_AnalyticCurInf`. That name is in no pinned header and in no file of
`Libraries/occt-src`. The bridge comment calls itself an "inline implementation matching OCCT
`LProp_AnalyticCurInf::Perform`", so the wrong name has a source.

Reading the body changes the entry more than the name does. `OCCTLPropAnalyticCurInf` uses
`LProp_CurAndInf` purely as a result container and `LProp_CIType` as the kind enum, and computes
the four ellipse vertices itself. So:

- Only `curveType: 2` ever returns a point. The docs said "for an analytic curve type" without
  saying that four of the five types always return empty.
- The docs promised "inflections, min/max curvature". No inflection is ever produced: only
  `AddExtCur` is called, so `CurvaturePointType.inflection` is unreachable.
- `LProp_CurAndInf` classifies by *radius* of curvature, so an ellipse's major-axis vertices, where
  it bends hardest, come back as `.minimumCurvature`. That inversion was undocumented and is the
  kind of thing a caller reads backwards.

### 7. `Law_BSpFunc`: which factories the knot-splitting pair can read (`over` `+under`, measured, with a test)

`docs/reference/GeometrySolvers.md` and the `///` both said "Only works on BSpline-based law
functions created via `bspline(poles:knots:multiplicities:degree:)`". Four of the seven factories
qualify, not one: `Law_Interpol : Law_BSpFunc` (`Law_Interpol.hxx:29`) and `Law_S : Law_BSpFunc`
(`Law_S.hxx:26`), so `interpolate(points:periodic:)` and `sCurve(from:to:parameterRange:)` are
readable as well.

Measured rather than deduced from the inheritance graph, at `.c0`/`.c1`/`.c2`/`.c3`, as
`knotSplitting.count`/`knotSplitParameters.count`:

```
constant:             0/0 0/0 0/0 0/0
linear:               0/0 0/0 0/0 0/0
sCurve:               2/2 2/2 2/2 2/2
interpolate(points:): 2/2 2/2 2/2 2/2
interpolated(values:) 2/2 2/2 2/2 4/4
bspline:              2/2 2/2 2/2 4/4
composite:            0/0 0/0 0/0 0/0
```

A readable law always reports at least its two end knots, so an empty array means "not a
`Law_BSpFunc`-derived law", never "no discontinuities". That is now the documented contract and is
held by `Tests/OCCTCurveTests/Issue1399LawKnotSplitFactoryReachTests.swift`.

**Prove-the-test-fails** (`okf/policies/prove-the-test-fails.md`), both halves, injected at the
bridge rather than in Swift, with `OCCTSWIFT_BRIDGE_PREBUILT` unset so the edits took effect:

| injection | result |
|---|---|
| baseline | both tests pass |
| `Handle(Law_BSpFunc)::DownCast` → `Handle(Law_Interpol)::DownCast` in both `OCCTLawBSplineKnotSplitting`/`KnotSplitParams` | readable-half **fails, 12 issues** (3 factories × 4 orders; `interpolate(points:)` still passes, since `Law_Interpol` is what the injected downcast asks for). Unreadable-half still passes. |
| null-downcast escape `return -1` → `return 2` | unreadable-half **fails** (`[0, 0]` where empty was expected). Readable-half still passes. |
| restored | both tests pass; `git diff` on `Sources/OCCTBridge` empty |

### 8. `GeomConvert`: `Curve3D.join(_:)` attributed to a static it never calls (`over`, read)

`docs/API_REFERENCE.md:600` gave `GeomConvert::ConcatG1`. `ConcatG1` exists
(`GeomConvert.hxx:297`) and is called nowhere in the bridge; `OCCTCurve3DJoinToBSpline`
(`OCCTBridge_Curve3D_Conversion.mm:822`) runs `GeomConvert::CurveToBSplineCurve` and accumulates
with `GeomConvert_CompCurveToBSplineCurve::Add`. `docs/reference/Curve3D.md:865` had it right, so
the two pages disagreed.

The attribution census cannot see this one: `GeomConvert` *is* named in the bridge file, so the
class-level check passes and the method half is invisible to it.

### 9. `HelixGeom_*` and `ProjLib_*` and `CPnts_UniformDeflection` (`over`, census)

These three were sitting in the census's output unread, and all are real:

- `HelixGeom_Helix` does not exist. The kernel has `HelixGeom_BuilderHelix`,
  `HelixGeom_BuilderHelixCoil`, `HelixGeom_HelixCurve`, `HelixGeom_BuilderApproxCurve`,
  `HelixGeom_BuilderHelixGen` and `HelixGeom_Tools`. Six bullets named the non-existent one, one of
  them also claiming `GeomAPI_PointsToBSpline` fits the result, which nothing does:
  `HelixGeom_BuilderHelix::Perform()` produces the BSpline itself. A seventh named
  `HelixGeom_ApproxCurve` "or equivalent BSpline fitting" for `Helix.approximateToBSpline`, which
  runs `HelixGeom_Tools::ApprHelix`.
- `ProjLib::Project` exists and would give the same answer, but the three `ProjLib` bridge
  functions construct `ProjLib_Plane`/`ProjLib_Cylinder` and read `IsDone()`/`Line()`/`Circle()`.
- `GCPnts_UniformDeflection` exists and this repo wraps it, behind `Curve3D.drawDeflection` and
  `Curve2D.drawDeflection`. `uniformDeflection` uses `CPnts_UniformDeflection`, a different class
  with a different sampling contract. Both entries said `GCPnts_`.

### 10. `GeomAbs_IsoType`: the only `under` inside the 44

`uIsoCurvePoints`/`vIsoCurvePoints` document the U/V selection and the `count` clamp, and both are
true. Two behaviours were not documented, both visible in `OCCTAdaptor3dIsoCurveEval`:

- The iso curve's parameter range is clamped to `-1e6...1e6` when the surface is infinite in that
  direction, so on a plane or a cylinder's V the samples span the clamp rather than anything
  derived from the face.
- The `catch (...)` writes nothing, and the Swift wrapper's buffer is pre-zeroed, so a non-face
  shape returns `count` points at the origin rather than an empty array.

## Adjacent findings (outside the 44, recorded rather than owned)

- **`Geom2dEval_CircleInvoluteCurve` (`under`).** `Geom2dEval.circleInvoluteD0(origin:direction:radius:u:)`
  and its `D1` sibling, the explicit-placement overloads at `Sources/OCCTSwift/GeomEval.swift:213`
  and `:227`, are public and were documented nowhere; only the `(radius:u:)` overloads had entries.
  Both are also among #1646's ten unguarded functions. Documented here because the fix is two doc
  entries and the class is one line outside the family list.
- **`Convert_CompPolynomialToPoles`** (`docs/reference/Document-Math-Bounds.md:2642`, subject
  `toBSpline2d`) is in the census's UNREACHED bucket and belongs to whoever owns that class; not
  adjudicated here.

## For the integrator (`gaps.md` material)

Marked as the brief asks, since `docs/occtswift-wrapping-gaps.md` is the integrator's file:

1. **The attribution census's two measured blind spots, from this lane.** (a) It resolves a class
   name against the bridge function's whole *file*, so a claim naming a class the file merely
   `#include`s resolves as reached: `GCPnts_UniformDeflection` was flagged only because the doc
   named it explicitly, and `GeomConvert::ConcatG1` was not flagged at all. (b) It sees no
   attribution when the `- **OCCT:**` bullet names a **bridge C function** instead of an OCCT class,
   which is how twenty entries across three pages had no OCCT attribution at all and the census
   reported `GeomEval` and `Geom2dEval` clean. A detector for "an `- **OCCT:**` bullet whose only
   code span is an `OCCT*` bridge symbol" would be cheap and would have found finding 1.
2. **`census-unmeasured-values.py` does not see the `GeomEval*D0`/`D1` shape**: a `void` bridge
   function with out-parameters that returns without writing them on a caught throw, against a
   Swift wrapper that pre-zeroes and returns unconditionally. Ten such functions in this family.
3. **#1646** is filed and should be linked from whatever list the integrator keeps.
4. `derive_lane.py --family geometry` prints 44 while `--self-test` counts `geometry=22` in the
   algorithm bucket. Both are internally consistent and the self-test is 13/13; noting it only so
   the next reader does not treat the two numbers as a contradiction.

## Not making the census worse

The first version of these fixes named base classes and exception types **on the `- **OCCT:**`
bullet** (`Geom_BoundedSurface`, `Adaptor3d_Curve`, `Standard_ConstructionError`), which the
census resolves as attributions: total findings went 431 → 430, eighteen fixed and seventeen
introduced. Those names were moved into the surrounding prose, where the information survives and
the census does not read them as claims.

Measured before and after, whole-tree:

```
before: findings : 431
after : findings : 413
```

and a line-by-line diff of the two finding lists shows exactly the eighteen removals and no
additions.

## Reproducing this pass

```bash
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family geometry  # 23 now, see above
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --self-test   # 14/14
python3 Scripts/census-doc-occt-attribution.py                                  # 413 findings
python3 Scripts/census-doc-occt-attribution.py --lane HelixGeom                 # 0
python3 Scripts/census-doc-occt-attribution.py --lane Geom2dGcc                 # 0
python3 Scripts/census-doc-occt-attribution.py --lane ProjLib                   # 0
python3 Scripts/census-doc-occt-attribution.py --lane GCPnts                    # 3, all unrelated
swift test --filter Issue1399LawKnotSplitFactoryReach                           # 2 tests

clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1399-geometry/probe_geom2deval_throws.mm -o /tmp/occt_probe_1399
/tmp/occt_probe_1399
```
