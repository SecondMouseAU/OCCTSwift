# OCCTSwift#556 probe: what a null geometry `Handle` actually does at each OCCT entry point

Ground truth for the defect class behind #556, against the pinned OCCT 8.0.0p1 kernel. It exists
because #556's stated mechanism needed checking before 60 functions were edited on the strength of
it, and the check changed the story in both directions: the issue's headline example is the mildest
case in the whole set, and the class is far more dangerous than "latent" elsewhere.

No fixture files needed: every case is a default-constructed (null) `Handle`.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/556-null-handle-guard-sweep/repro_556.mm -o /tmp/occt_556
/tmp/occt_556
```

Each probe runs in a forked child, so a crash is reported rather than ending the run. A child that
exits normally, or via `Standard_Failure`, is a case the bridge's own `catch (...)` already coped
with before the fix. A child killed by a signal is a case it could not.

## What it measures

57 distinct OCCT entry points: every API that the bridge passes an `OCCTCurve3DRef` /
`OCCTCurve2DRef` / `OCCTSurfaceRef`'s handle into. 35 of them come from #556; #618 added the
other 22 (see below).

**36 of 57 crash with an uncatchable signal. 10 raise a catchable `Standard_Failure`. 11 return.**

### The issue's headline example is one of the mild ones

#556 leads with `Geom2dAdaptor_Curve`, and argues from
`ModelingData/TKG2d/Geom2dAdaptor/Geom2dAdaptor_Curve.cxx:272`:

> `Geom2dAdaptor_Curve::load` [...] has **no** null precondition at all: it goes straight to
> `C->DynamicType()`. So this is not a `Standard_NullObject` raise that `No_Exception` compiled
> out, it is an unconditional dereference in every build configuration.

The premise is right and the conclusion is wrong, because lowercase `load` is private. Every caller
(including both handle-taking constructors) reaches it through the public `Load`, which is
header-inline at `Geom2dAdaptor_Curve.hxx:108-131` and opens with an unconditional,
never-`No_Exception`-guarded check:

```cpp
void Load(const occ::handle<Geom2d_Curve>& theCurve)
{
  if (theCurve.IsNull())
  {
    throw Standard_NullObject();
  }
  load(theCurve, theCurve->FirstParameter(), theCurve->LastParameter());
}
```

Measured: `Geom2dAdaptor_Curve(null)` and `Geom2dAdaptor_Curve(null, 0, 1)` both raise a catchable
`Standard_Failure`, which every bridge caller's existing `catch (...)` already absorbed. Same for
`GeomAdaptor_Curve`, `GCPnts_AbscissaPoint` and `GeomAPI_ExtremaSurfaceSurface`.

### The cases that do crash

| OCCT call | reached from | null handle |
|---|---|---|
| `new Geom_TrimmedCurve` | `OCCTCurve3DTrimmed` | SIGSEGV |
| `new Geom_OffsetCurve` | `OCCTCurve3DCreateOffset` | SIGSEGV |
| `new Geom_RectangularTrimmedSurface` | `OCCTSurfaceCreate{RectangularTrimmed,TrimmedInU,TrimmedInV}` | SIGSEGV |
| `ShapeAnalysis_Curve::{Project,ValidateRange,GetSamplePoints,IsClosed,IsPeriodic}` | 5 `OCCTCurve3D*` fns | SIGSEGV |
| `ShapeConstruct_Curve::{ConvertToBSpline,AdjustCurve,AdjustCurve2d}` | 4 `OCCTShapeConstruct*` fns | SIGSEGV |
| `ShapeCustom_Curve2d::ConvertToLine2d` | `OCCTCurve2DConvertToLine` | SIGSEGV |
| `Bisector_BisecAna::Perform` | both `OCCTBisectorBisecAna*` fns | SIGSEGV |
| `BRepLib_MakeEdge2d` | `OCCTMakeEdge2dCurve{,Range}` | SIGSEGV |
| `GeomConvert::CurveToBSplineCurve` | `OCCTSurfaceFillBSpline{2,4}Curves` | SIGSEGV |
| `ShapeAnalysis_Surface::ValueOfUV` | 11 `OCCTSurface*` fns | SIGSEGV |
| `GeomFill_Gordon::Init` | `OCCTGeomFillGordon{,Report}` | SIGSEGV |
| `BRepAlgoAPI_Section` ctor / `Init1` | `OCCTShapeSectionWithSurface`, `OCCTSectionBuilderInit{1,2}Surface` | SIGSEGV |
| `Geom2d_Curve->D0`, `Handle->FirstParameter` | `OCCTCurve2DPointAt`, `OCCTCurve3DSplitAt`, both `OCCTConcatenateCurves*` | SIGSEGV |

`ShapeAnalysis_Surface` is worth singling out: **constructing** it from a null handle returns
normally, and the crash lands at the first `ValueOfUV`/`HasSingularities` call. A probe that only
constructed the object would have reported this whole 11-function family as safe.

Per CLAUDE.md, `OCC_CATCH_SIGNALS` is inert in this build, so none of the 24 is recoverable
in-process. The enclosing `catch (...)` is not a fallback for any of them.

## The 22 entry points #618 added

The walk that produced #556's census matched `param->field` and nothing else, so it never saw the
bridge sites that reach the handle through a cast or a local alias, and so these entry points,
the ones those sites call, were never probed at all. #618 taught the checker every indirection in
the tree and then measured what it turned up. Each probe below runs the bridge function's real
sequence (`Init` *and* `Perform`, not just the first call), because the crash need not land on the
first one.

**13 crash, 5 raise a catchable `Standard_Failure`, 5 return.** Which means the "suspected
unguarded" list #618 was filed with was partly wrong, in the direction that matters: measuring
first avoided three guards that would have been noise.

| OCCT call | reached from | null handle |
|---|---|---|
| `LocalAnalysis_CurveContinuity` ctor | `OCCTLocalAnalysisCurveContinuity{,Flags}` | SIGSEGV |
| `LocalAnalysis_SurfaceContinuity` ctor | `OCCTLocalAnalysisSurfaceContinuity{,Flags}` | SIGSEGV |
| `ShapeUpgrade_SplitCurve3dContinuity` `Init`+`Perform` | `OCCTSplitCurve3dContinuity` | SIGSEGV |
| `ShapeUpgrade_SplitCurve2dContinuity` `Init`+`Perform` | `OCCTSplitCurve2dContinuity` | SIGSEGV |
| `ShapeUpgrade_ConvertCurve2dToBezier` `Init`+`Perform` | `OCCTConvertCurve2dToBezier` | SIGSEGV |
| `ShapeUpgrade_SplitSurface{Continuity,Angle,Area}` `Init`+`Perform` | the three `OCCTSplitSurface*` fns | SIGSEGV |
| `GeomTools_Curve2dSet::Add` + `Write` | `OCCTGeomToolsCurve2dSetWrite` | SIGSEGV |
| `GeomTools_SurfaceSet::Add` + `Write` | `OCCTGeomToolsSurfaceSetWrite` | SIGSEGV |
| `GeomFill_NSections` + `ComputeSurface` / `SectionShape` | `OCCTGeomFillNSections{,Info}` | SIGSEGV |
| `new Geom_TrimmedCurve` | `OCCTProjLibProjectOnSurface` | SIGSEGV |
| `Approx_SameParameter` ctor | `OCCTApproxSameParameter` | `Standard_Failure` |
| `GeomAdaptor_Surface` ctor | 9 `OCCTExtrema*` / `OCCTProjLib*` fns | `Standard_Failure` |
| `GeomAdaptor_Curve(c, first, last)` | 5 `OCCTExtrema*` fns | `Standard_Failure` |
| `GeomLib_IsPlanarSurface` ctor | `OCCTGeomLibIsPlanarSurface`, `OCCTGeomLibPlanarSurfacePlane` | `Standard_Failure` |
| `Geom2dConvert_ApproxArcsSegments` | `OCCTGeom2dConvertApproxArcsSegments` | `Standard_Failure` |
| `GeomLib_Tool::Parameter` (3D and 2D) | `OCCTGeomLibToolParameter{3D,2D}` | returns false |
| `GeomLib_Tool::Parameters` (surface) | `OCCTGeomLibToolParametersSurface` | returns false |
| `GeomConvert_SurfToAnaSurf::IsCanonical` | `OCCTGeomConvertIsCanonical` | returns |
| `GeomTools_CurveSet::Add` + `Write` | `OCCTGeomToolsCurveSetWrite` | returns |

### One asymmetry worth naming: `GeomTools`

The three `GeomTools_*Set` writers are the same code three times over, and they do not behave the
same way. `GeomTools_CurveSet::Add` opens

```cpp
return (C.IsNull()) ? 0 : myMap.Add(C);
```

so a null 3D curve is dropped rather than written. `GeomTools_Curve2dSet.cxx` and
`GeomTools_SurfaceSet.cxx` contain no `IsNull` at all, and both crash. Upstream inconsistency, not
ours; the two that crash are guarded bridge-side, the one that copes is left alone and recorded in
the checker's `ALLOWED` with that reason.

## What this does not show

It does not show that any of these is reachable from Swift today. #478 classified all 228 sites
that bind a handle into one of the three wrapper types and found none that can produce a wrapper
carrying a null handle, so the class stays latent. What the measurement changes is the cost of
weakening that invariant later: for 24 of these 35 entry points the first symptom is a SIGSEGV
with no diagnostic trail, not a caught exception and a nil return.

`Scripts/check-null-handle-guards.py` is what keeps the guard uniform from here.
