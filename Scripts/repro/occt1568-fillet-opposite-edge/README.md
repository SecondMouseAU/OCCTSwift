# OCCT#1568: `BRepFilletAPI_MakeFillet::Build` SIGSEGVs when the blend exactly meets the opposite edge

Upstream: [Open-Cascade-SAS/OCCT#1568](https://github.com/Open-Cascade-SAS/OCCT/issues/1568),
filed 2026-09-29 by an external reporter against occt-main, from
[FreeCAD#25289](https://github.com/FreeCAD/FreeCAD/issues/25289). Related upstream issue: #1177,
which is the non-crashing version of the same operation.

`model.brep` and `test.tcl` are the reporter's own attachment, kept here so the measurement below
can be re-run without depending on a GitHub attachment URL.

## What this reproduces

A SIGSEGV inside `BRepFilletAPI_MakeFillet::Build()`, on our own pinned kernel, not only on
upstream's master. The bridge names `BRepFilletAPI_MakeFillet` in 96 places, and `OCC_CATCH_SIGNALS`
is inert in this build, so this kills a consumer's process and no bridge-side guard in front of
`Build()` can convert it into a nil return.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -g -O0 -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/occt1568-fillet-opposite-edge/probe.mm -o /tmp/occt1568_probe

cd Scripts/repro/occt1568-fillet-opposite-edge
/tmp/occt1568_probe model.brep            # the reporter's twelve edges at 1.5: SIGSEGV, exit 139
/tmp/occt1568_probe model.brep 1.5 13     # one edge at 1.5: SIGSEGV, exit 139
/tmp/occt1568_probe model.brep 1.49 13    # one edge at 1.49: IsDone() == true, exit 0
```

`probe.mm` replays `test.tcl` through the C++ API. It follows DRAW rather than approximating it:
edge numbering is `DBRep.cxx`'s `explode()`, a `TopExp_Explorer` over `TopAbs_EDGE` deduplicated by
`NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher>` (`IsSame`, not `IsEqual`) seeded with the
parent shape, and the fillet parameters are `BRepTest_FilletCommands.cxx`'s `BLEND`:
`ChFi3d_Rational`, `SetParams(ta, tesp, t2d, t3d, t2d, fl)` and `SetContinuity(GeomAbs_C1, tapp_angle)`
with that file's static defaults (`ta = 1e-2`, `tesp = 1e-4`, `t2d = 1e-5`, `t3d = 1e-4`,
`fl = 1e-3`, `tapp_angle = 1e-2`).

`minimal.mm` is the corroboration of the mechanism and needs no model file.

## Measured, 2026-09-30

Against the local `Libraries/OCCT.xcframework`, OCCT 8.0.1 plus the carried patches as of the
`v4.0.0-kernel.1` build. None of the carried patches touches `Geom2dAdaptor_Curve`,
`Adaptor3d_CurveOnSurface`, `BRepBlend_*` or `ChFi3d_*`, and `0042`/`0043`, added since that build,
do not either, so the crash path is the same under the current `v4.0.0-kernel.3` pin.

The model has 42 distinct edges under DRAW numbering.

### Eight of the script's twelve edges crash alone, at radius 1.5

| edges added, radius 1.5 | result |
| --- | --- |
| all twelve (`3, 9, 11, 6, 13, 14, 15, 16, 17, 18, 19, 12`) | SIGSEGV |
| `13`, `14`, `15`, `16`, `17`, `18`, `19`, `12`, each alone | SIGSEGV |
| `3`, `9`, `11`, `6`, each alone | completes |

### The radius is one point, not a threshold

Edge 13 alone:

| radius | result |
| --- | --- |
| 1.0, 1.4, 1.49 | `IsDone() == true` |
| 1.4999999 | `IsDone() == false`, no crash |
| **1.5** | **SIGSEGV**, 3 runs of 3 |
| 1.5000001 | `IsDone() == true` |
| 1.6 | `IsDone() == true` |
| 3.0 | `IsDone() == false`, no crash |

One ULP either side of 1.5 is safe and the larger side succeeds outright, so the trigger is the
exactly-tangent configuration where the blend meets the opposite edge, not blend size.

### The stack, ours against the reporter's

```
2  Geom2dAdaptor_Curve::D1(double, gp_Pnt2d&, gp_Vec2d&) const + 24
4  Adaptor3d_CurveOnSurface::EvalD1(double) const + 364
5  BRepBlend_SurfRstConstRad::Values(...)
6  BRepBlend_SurfRstConstRad::IsSolution(...)
7  BRepBlend_SurfRstLineBuilder::TestArret(...)
8  BRepBlend_SurfRstLineBuilder::Perform(...)
9  ChFi3d_Builder::ComputeData(...)
10 ChFi3d_FilBuilder::PerformSurf(...)
11 ChFi3d_Builder::PerformSetOfSurfOnElSpine(...)
12 ChFi3d_Builder::PerformSetOfKGen(...)
13 ChFi3d_Builder::PerformSetOfSurf(...)
14 ChFi3d_Builder::Compute()
15 BRepFilletAPI_MakeFillet::Build(Message_ProgressRange const&)
```

Frame for frame with the trace in the upstream issue. Ours is a release kernel, so `EvalD1` is
inlined into `D1`; the reporter's debug build names `EvalD1` separately. Two of their three innermost
frames land on byte-identical lines in `Libraries/occt-src`
(`BRepBlend_SurfRstConstRad.cxx:184` is `cons.D1(X(3), ptrst, d1);`,
`Adaptor3d_CurveOnSurface.cxx:1234` is `myCurve->D1(theU, Puv, Duv);`), and their
`Geom2dAdaptor_Curve.cxx:862` maps to our `:887` under a uniform +25 line offset, because master
hoisted the non-virtual `D0`/`D1`/`D2` wrappers out of the `.cxx` and into the header. That is also
why their frame 1 reads `Adaptor2d_Curve2d.hxx:99`.

### The mechanism, measured rather than read off the trace

`minimal.mm` default-constructs a `Geom2dAdaptor_Curve` and evaluates it:

```
GetType()      = 8 (GeomAbs_OtherCurve = 8)
Curve().IsNull = true
calling D1(0.5) on it
*** SIGNAL 11 in the minimal case ***
2  Geom2dAdaptor_Curve::D1(double, gp_Pnt2d&, gp_Vec2d&) const + 24
```

Same symbol, same byte offset as the innermost frame of the fillet crash. The default constructor
(`Geom2dAdaptor_Curve.cxx:231`) leaves `myTypeCurve = GeomAbs_OtherCurve` and `myCurve` null, so
every evaluator falls to the switch's `default:` arm, which is `return myCurve->EvalD1(U);` with no
`IsNull()` check of any kind. So `ChFi3d` is driving a 2D curve adaptor that holds no curve.

## What is not established

Why the adaptor is unloaded. Adding the missing `IsNull()` to that arm converts the segfault into a
`Standard_NullObject` and does not answer it. The shape resembles the `CurveOnSurface` results
dereferenced without `IsNull()` recorded against #348, which upstream fixed for 8.0.1 as
[OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392), but this is a different site and
proving the cause needs an instrumented kernel rather than a probe.
