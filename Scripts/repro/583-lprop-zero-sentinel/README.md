# OCCTSwift#583 probes: `0` as the local-properties "undefined" sentinel

One standalone probe for the question #583 turns on: does `BRepLProp_SLProps` ever hand back a
curvature of exactly `0` at a point where the curvature *is* defined? If it never did, spelling
"undefined" as `0` would be lossless. It does, on the two commonest solids in the test suite.

Companion to [`../529-breplprop-resolution/`](../529-breplprop-resolution), which converged these
same eighteen sites onto one `Resolution`, and to
[`../494-lprop-resolution/`](../494-lprop-resolution) on the `Geom_`-handle side.

## Building

```bash
L=Libraries/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/583-lprop-zero-sentinel/occt_583_zero_is_ordinary.cpp -o /tmp/occt_583_zero
/tmp/occt_583_zero
```

In a git worktree `Libraries/` does not exist. Point `L` at the main checkout's copy, or symlink it
(see `docs/guides/building-occt.md`).

## `occt_583_zero_is_ordinary.cpp`: measured on 8.0.0p1

The probe builds each surface directly, wraps it in a face, and reads it through
`BRepAdaptor_Surface` + `BRepLProp_SLProps` at `Precision::Confusion()`, the exact construction
`occtFaceLocalProps` performs for all fifteen `Shape.faceLProp*` / `Shape.edge*LP` entry points.

```
=== PLANE through the origin (flat everywhere, curvature defined everywhere) ===
point                      defined   K (gauss)     H (mean)      kMax          kMin          umbilic  Value()
origin (u=0, v=0)          yes       0             0             0             0             yes      (0, 0, 0)
u=3, v=4                   yes       0             0             0             0             yes      (3, 4, 0)

=== CYLINDER radius 3 (Gaussian curvature is 0 everywhere, and defined) ===
u=0, v=0                   yes       -0            -0.166667     0             -0.333333     no       (3, 0, 0)
u=1.1, v=6                 yes       -0            -0.166667     0             -0.333333     no       (1.36079, 2.67362, 6)

=== CONE apex radius 0 (curvature falls out of definition at the apex) ===
v=1e-6                     yes       -0            -866025       0             -1.73205e+06  no       (5e-07, 0, 8.66025e-07)
v=1e-8 (past the gate)     NO        0             0             0             0             -        (5e-09, 0, 8.66025e-09)
v=0 (the apex)             NO        0             0             0             0             -        (0, 0, 0)

=== SPHERE radius 5 (v = +/- pi/2 are the poles) ===
v=0 (equator)              yes       0.04          -0.2          -0.2          -0.2          yes      (5, 0, 0)
v=pi/2 (the pole)          NO        0             0             0             0             -        (3.06162e-16, 0, 5)
```

Reading the columns against the six getters #583 changes:

| Row | `IsCurvatureDefined()` | What the pre-#583 bridge returned | What it means |
|---|---|---|---|
| plane, any point | **true** | `0` from all four curvature getters | flat, and the answer *is* zero |
| plane at `(u, v) = (0, 0)` | true | `faceLPropValue` → `(0, 0, 0)` | the origin, a real point |
| cylinder, any point | **true** | `faceLPropGaussianCurvature` → `0`, `faceLPropMaxCurvature` → `0`, `faceLPropIsUmbilic` → `false` | developable, and each answer is the real one |
| cone, any point | **true** | the same three | developable |
| cone apex, sphere pole | **false** | `0` / `(0, 0, 0)` / `false` from all six | no answer exists |
| null or non-face handle | n/a | `0` / `(0, 0, 0)` / `false` from all six | the caller passed the wrong thing |

The last three rows are the whole defect: a cylinder's Gaussian curvature, a cone apex's absence of
one, and a `Shape` that is not a face at all are one indistinguishable `0`. It is not a corner
case: `faceLPropGaussianCurvature` and `faceLPropMaxCurvature` return the sentinel at **every**
point of **every** cylinder and cone, and `faceLPropIsUmbilic` returns `false` ("the principal
curvatures differ here") at points where there are no principal curvatures to differ.

`Value()` is the one that does not depend on the curvature gate at all: it is defined at the apex
(`(0, 0, 0)`, which happens to be the collision) and at the pole. Its only real failures are a null
handle and a `Shape` that is not a face, which is exactly what `TopoDS::Face` throws on.

## The curve half, which #583 does not change

```
curve                              tangent     Curvature()    reading
line (straight)                    yes         0              genuinely 0
circle radius 4                    yes         0.25           genuinely 1/4
Bezier, first two poles equal      yes         1.79769e+308   cusp: RealLast() sentinel
Bezier, all poles equal            NO          0              no answer at all
```

Same collision, one type down: a straight edge's curvature and a fully degenerate curve's absence of
one are both the double `0`. The cusp is the one case a bare double *does* distinguish, because OCCT
gives it its own sentinel.

Six entry points share this shape and keep it after #583, filed as #595 rather than folded in here,
because each is a separate public type with its own break surface:

| Swift | bridge | gate |
|---|---|---|
| `Curve3D.curvature(at:)` | `OCCTCurve3DGetCurvature` | `IsTangentDefined()` |
| `Curve3D.localCurvature(at:)` | `OCCTCurve3DLocalCurvature` | `IsTangentDefined()` |
| `Curve2D.curvature(at:)` | `OCCTCurve2DGetCurvature` | `IsTangentDefined()` |
| `Shape.edgeCurvatureLP(at:)` | `OCCTEdgeLPropCurvature` | `IsTangentDefined()` |
| `Surface.gaussianCurvature(atU:v:)` | `OCCTSurfaceGetGaussianCurvature` | `IsCurvatureDefined()` |
| `Surface.meanCurvature(atU:v:)` | `OCCTSurfaceGetMeanCurvature` | `IsCurvatureDefined()` |

The `Face` counterparts of the last two (`Face.gaussianCurvature(atU:v:)`,
`Face.meanCurvature(atU:v:)`) already return `Double?`, so `Surface` disagrees with `Face` about the
same quantity read off the same surface, and with its own neighbour
`Surface.principalCurvatures(atU:v:)`, which returns an optional struct.

Not in that list, because they already carry an `isDefined` out-parameter and their Swift spellings
already return optionals or a struct with a `curvatureDefined` flag: `OCCTCurve3DLocalTangent`,
`OCCTCurve3DLocalNormal`, `OCCTCurve3DLocalCentreOfCurvature`, `OCCTSurfaceLocalCurvatures`,
`OCCTSurfaceLocalCurvatureDirections`, `OCCTGeomLPropCLProps`, `OCCTGeomLPropSLProps`.
