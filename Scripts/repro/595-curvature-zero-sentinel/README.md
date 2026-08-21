# OCCTSwift#595 probe: `0` as the curvature "undefined" sentinel, on four more public types

[#583](../583-lprop-zero-sentinel) established that `0` is not a spare encoding for
`BRepLProp_SLProps`: a cylinder's Gaussian curvature is exactly `0` at every point of the surface
with `IsCurvatureDefined()` true. It fixed the `Shape.faceLProp*` block and deferred six more entry
points, on `Curve3D`, `Curve2D`, `Surface` and `Shape`, each reading through a different OCCT class.

This probe asks the same question of those six, and of every neighbour that decides "undefined" with
a hand-rolled gate rather than an OCCT predicate.

## Building

```bash
L=Libraries/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/595-curvature-zero-sentinel/occt_595_curvature_zero.cpp -o /tmp/occt_595_curv
/tmp/occt_595_curv
```

In a git worktree `Libraries/` does not exist. Point `L` at the main checkout's copy, or symlink it
(see `docs/guides/building-occt.md`).

## Measured on 8.0.0p1

```
=== Curve3D.curvature(at:) / localCurvature(at:) -- GeomLProp_CLProps ===
curve                              tangent   Curvature()     local (same)    what a caller sees
line (straight)                    yes       0               0               REAL 0  <-- collides
circle radius 4                    yes       0.25            0.25            real value
Bezier, first two poles equal      yes       1.79769e+308    1.79769e+308    real value
Bezier, all four poles equal       NO        0               0               SENTINEL 0
rows where the two spellings disagree: 0 -- the duplication is total, so one can go.

=== Curve2D.curvature(at:) -- GeomLProp_CLProps2d ===
line (straight)                    yes       0               REAL 0  <-- collides
circle radius 4                    yes       0.25            real value
Bezier, first two poles equal      yes       1.79769e+308    real value
Bezier, all four poles equal       NO        0               SENTINEL 0

=== Shape.edgeCurvatureLP(at:) -- BRepAdaptor_Curve + BRepLProp_CLProps ===
straight edge                      yes       0               REAL 0  <-- collides
circular edge radius 4             yes       0.25            real value
edge on the cusp Bezier            yes       1.79769e+308    real value
edge on the dead Bezier            NO        0               SENTINEL 0
(sphere radius 5: its degenerate pole edge has NO 3D curve)
sphere degenerate pole edge        NO        0               SENTINEL 0

=== Surface.gaussianCurvature / meanCurvature -- GeomLProp_SLProps ===
surface point                      defined   K (gauss)       H (mean)        what a caller sees (K / H)
plane, u=3 v=4                     yes       0               0               REAL 0 / REAL 0
cylinder r=3, u=1.1 v=6            yes       -0              -0.166667       REAL 0 / real value
cone, v=1.0 (ordinary)             yes       -0              -0.866025       REAL 0 / real value
cone, v=1e-8 (past the gate)       NO        0               0               SENTINEL 0 / SENTINEL 0
cone apex, v=0                     NO        0               0               SENTINEL 0 / SENTINEL 0
sphere r=5, v=0 (equator)          yes       0.04            -0.2            real value / real value
sphere r=5, v=pi/2 (pole)          NO        0               0               SENTINEL 0 / SENTINEL 0

=== Curve3D.torsion(at:) -- hand-rolled gate, |d1 x d2|^2 < Precision::Confusion() ===
curve                              osc.plane   torsion         what a caller sees
line (straight)                    NO          0               SENTINEL 0
circle radius 4 (planar)           yes         0               REAL 0  <-- collides
Bezier helix approximation         yes         0.229729        real value
Bezier, all four poles equal       NO          0               SENTINEL 0

=== Wire.curvature(at:) -- BRepAdaptor_CompCurve, |d1| < 1e-10 ===
wire                               |d1|        curvature       what a caller sees
straight wire                      10          0               REAL 0  <-- collides
circular wire radius 4             25.13       0.25            real value
wire on the cusp Bezier            0           0               SENTINEL 0

=== summary ===
rows returning 0 as a REAL answer, gate open   : 9
rows returning 0 as the UNDEFINED sentinel     : 13
```

### The six the issue listed

Every one collides, and the collision is the most ordinary geometry there is:

| entry point | the real `0` | the sentinel `0` |
|---|---|---|
| `Curve3D.curvature(at:)` | any straight curve | a Bezier with all poles coincident |
| `Curve3D.localCurvature(at:)` | same | same |
| `Curve2D.curvature(at:)` | any straight 2D curve | same, in 2D |
| `Shape.edgeCurvatureLP(at:)` | any straight edge | **a sphere's degenerate pole edge** |
| `Surface.gaussianCurvature(atU:v:)` | **every point of every plane, cylinder and cone** | a cone apex, a sphere pole |
| `Surface.meanCurvature(atU:v:)` | every point of every plane | same |

The edge row is the one worth reading twice. The degeneracy is not a constructed pathology: a sphere
carries a degenerate edge at each pole, it has no 3D curve at all, and every `Shape.edge*` entry
point walks edges without asking whether they are degenerate. `Surface.gaussianCurvature` is the
other: it returns the "undefined" sentinel for whole surfaces at a time, exactly as
`Shape.faceLPropGaussianCurvature` did before #583.

The cusp row is why the curve half looks better covered than it is. OCCT gives a cusp its own
sentinel, `RealLast()`, so a bare double *does* distinguish that one case. It is a real answer
("infinite here"), not an absence, and it survives the change unaltered, `Double?` has no room for
it, and `nil` would be the wrong thing to say.

### `curvature(at:)` and `localCurvature(at:)` are now the same call

Since #494 converged their resolutions the two build the same `GeomLProp_CLProps` at the same
`occtLocalPropsResolution()` and gate on the same `IsTangentDefined()`. The probe runs both columns
over the same four curves: **0 rows disagree**, including the two sentinel rows, where a divergence
would be easiest to hide. The only axis on which they were ever different is a null `OCCTCurve3DRef`
,  `OCCTCurve3DGetCurvature` tests it, `OCCTCurve3DLocalCurvature` is declared `_Nonnull` and does
not, which no Swift caller can reach, since both wrappers pass a live `handle`.

Per [#562](https://github.com/SecondMouseAU/OCCTSwift/pull/589)'s rule, the axis to check before
collapsing A onto B is the one the issue did not list. Here that is buffer sizing and tolerance, and
both are already shared. So `localCurvature(at:)` is deprecated onto `curvature(at:)` and
`OCCTCurve3DLocalCurvature` is deleted.

### Two the census did not list

`Curve3D.torsion(at:)` and `Wire.curvature(at:)` decide "undefined" with a hand-rolled magnitude
gate instead of an OCCT predicate, which is why a grep for `Is*Defined()` misses them. Both have the
same defect:

- **`Curve3D.torsion(at:)`** returns `0` when `|d1 x d2|²` falls under the gate, meaning the curve
  has no osculating plane there. A **planar** curve's torsion is genuinely `0`, and every circle,
  ellipse and 2D-planar BSpline in the suite is one. So the collision runs the other way from the
  curvature rows and is just as common: a circle's real `0` against a straight line's absence of an
  answer. It sits four lines below `curvature(at:)` on the same type, so leaving it would break
  `Curve3D`'s source compatibility twice for one defect.
- **`Wire.curvature(at:)`** already returns `Double?`, but only the `-1.0` error path becomes
  `nil`. The degenerate-tangent branch returns `0.0`, which reaches the caller as a straight wire's
  genuine answer. Measured: a wire on the cusp Bezier has `|d1|` exactly `0` at its start, and today
  reports curvature `0` there. No signature changes; the branch just stops lying.

Note the wire and the curve disagree about that same cusp: `BRepAdaptor_CompCurve` computes the
formula by hand and divides by a zero derivative, where `GeomLProp_CLProps` reports the `RealLast()`
infinity sentinel. Reporting nothing is the honest answer for the hand-rolled path, which has no way
to reach the sentinel.

### Deliberately excluded

- **`Edge.dihedralAngle(between:and:at:)`** (`OCCTEdgeGetDihedralAngle`) has the same shape, a
  hand-rolled `< 1e-10` gate on the two face normals, but returns `-1`, which is outside the
  documented `0...2π` range and which the Swift wrapper already maps to `nil`. The sentinel is
  distinguishable and it already reaches the caller as an absence, so there is nothing to fix.
- **`OCCTCurve3DLocalTangent`, `OCCTCurve3DLocalNormal`, `OCCTCurve3DLocalCentreOfCurvature`,
  `OCCTSurfaceLocalCurvatures`, `OCCTSurfaceLocalCurvatureDirections`, `OCCTGeomLPropCLProps`,
  `OCCTGeomLPropSLProps`** already carry an `isDefined` out-parameter, and their Swift spellings
  already return an optional or a struct with a `curvatureDefined` flag (#494).

### Banked, not changed here

Two thresholds are left exactly as they are, because this pass changes how an absence is *spelled*,
not where the boundary between presence and absence falls:

- `OCCTCurve3DGetTorsion` compares a **squared** magnitude against the linear
  `Precision::Confusion()`, so its effective gate on `|d1 x d2|` is `3.16e-4`, not `1e-7`.
- `OCCTWireGetCurvatureAt` uses a literal `1e-10` on `|d1|`, the last hand-rolled resolution in the
  local-properties family after #494 and #529 converged the rest onto `occtLocalPropsResolution()`.

Moving either changes values, not encodings, and wants its own before/after on real geometry.
