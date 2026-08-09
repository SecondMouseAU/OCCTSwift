---
title: Surface
parent: API Reference
---

# Surface

A `Surface` is a parametric 2D manifold in 3D space — the Swift analog of OCCT's `Geom_Surface` class hierarchy. It wraps analytic surfaces (plane, cylinder, cone, sphere, torus), swept surfaces (extrusion, revolution), and freeform surfaces (Bezier, BSpline) polymorphically behind a single opaque handle. Obtain a surface via one of the static factory methods, by extracting it from a `Face` (`face.surface`), or by converting a `Shape` to its underlying geometry.

> **Note:** `Surface` is documented across several pages — see also **Surface — Analytic Types**, **Surface — BSpline & Bezier**, **Surface — Analysis**, and **Surface — Advanced Construction**.

## Topics

- [Properties](#properties) · [Evaluation](#evaluation) · [Analytic Surfaces](#analytic-surfaces) · [Swept Surfaces](#swept-surfaces) · [Freeform Surfaces](#freeform-surfaces) · [Operations](#operations) · [Conversion](#conversion) · [Iso Curves](#iso-curves) · [Pipe Surfaces](#pipe-surfaces) · [Draw Methods](#draw-methods) · [Bounding Box](#bounding-box) · [Surface Transform (v0.128.0)](#surface-transform-v01280) · [GeomEval Surface Factories (v0.130.0)](#geomeval-surface-factories-v01300) · [GeomEval TBezier / AHTBezier Surfaces (v0.131.0)](#geomeval-tbezier--ahtbezier-surfaces-v01310) · [v0.115.0: Surface from point grid, normal, curvatures](#v01150-surface-from-point-grid-normal-curvatures)

---

## Properties

### `SurfaceType`

Classification enum matching OCCT's `GeomAbs_SurfaceType`.

```swift
public enum SurfaceType: Int32, Sendable {
    case plane = 0, cylinder = 1, cone = 2, sphere = 3, torus = 4
    case bezierSurface = 5, bsplineSurface = 6
    case surfaceOfRevolution = 7, surfaceOfExtrusion = 8
    case offsetSurface = 9, other = 10
}
```

Use `surfaceKind` to query which case applies to a given `Surface` instance.

---

### `surfaceKind`

The specific geometric kind of this surface.

```swift
public var surfaceKind: SurfaceType { get }
```

- **Returns:** The `SurfaceType` case that classifies this surface.
- **OCCT:** `GeomAdaptor_Surface::GetType` (via `OCCTSurfaceGetType`).
- **Example:**
  ```swift
  let s = Surface.sphere(center: .zero, radius: 5)!
  print(s.surfaceKind)  // .sphere
  ```

---

### `Continuity` *(removed in v2.0.0)*

Was a deprecated alias of the top-level `ContinuityClass`, which `Curve3D` and `Curve2D` now
share (#485); the alias itself was removed at v2.0.0
([#784](https://github.com/SecondMouseAU/OCCTSwift/issues/784)). Use `ContinuityClass` directly.
The raw values are unchanged.

---

### `ContinuityClass`

The continuity OCCT *measured* on an existing curve or surface: the one continuity vocabulary that
reports rather than requests, shared by `Curve3D`, `Curve2D` and `Surface` alike (#485). Its raw
values are not a 0/1/2 order: they are `GeomAbs_Shape`'s own ordinals, which interleave the
geometric classes with the parametric ones.

```swift
public enum ContinuityClass: Int32, Sendable, CaseIterable {
    case c0 = 0
    case g1 = 1
    case c1 = 2
    case g2 = 3
    case c2 = 4
    case c3 = 5
    case cN = 6
}
```

| Case | Raw | Meaning |
|---|---|---|
| `.c0` | 0 | Positional continuity only (`GeomAbs_C0`). |
| `.g1` | 1 | Tangent continuity (`GeomAbs_G1`): tangent directions agree, magnitudes need not. |
| `.c1` | 2 | First-derivative continuity (`GeomAbs_C1`). |
| `.g2` | 3 | Curvature continuity (`GeomAbs_G2`). |
| `.c2` | 4 | Second-derivative continuity (`GeomAbs_C2`). |
| `.c3` | 5 | Third-derivative continuity (`GeomAbs_C3`). |
| `.cN` | 6 | Infinite continuity (`GeomAbs_CN`): every derivative exists. Analytic geometry. |

Do not compare a raw value against `ParametricContinuity` or `SurfaceContinuity`: those are request
orders counting 0, 1, 2; these are `GeomAbs_Shape` ordinals where C1 is 2 and C2 is 4. Use
`satisfies(_:)` for a continuity-floor check instead of comparing raw values.

#### `isParametric`

Whether this class guarantees *parametric* continuity (a C-class), not merely geometric.

```swift
public var isParametric: Bool { get }
```

`.g1`/`.g2` are `false`: they constrain tangent direction and curvature but not the derivative
vectors themselves. `false` means "not a C-class", not "meets no floor at all": a geometric class
still meets the C0 floor.

#### `derivativeOrder`

The highest continuously-differentiable derivative order this class guarantees, if it guarantees a
parametric one at all.

```swift
public var derivativeOrder: Int? { get }
```

- **Returns:** `nil` for `.g1`/`.g2`, which promise nothing about derivative vectors; `Int.max` for
  `.cN`; otherwise the C-order (`.c2` returns `2`).

#### `satisfies(_:)`

Whether the measured continuity meets a required parametric floor.

```swift
public func satisfies(_ required: ParametricContinuity) -> Bool
```

Use this instead of comparing raw values against `ParametricContinuity`; the two encodings differ
(`ContinuityClass.c1` is 2, `ParametricContinuity.c1` is 1). This asks a parametric question, which
is not what `<`/`>=` answer: those rank two measured classes by their place in `GeomAbs_Shape`'s
ladder, and outranking a class in that ladder is not the same as entailing it. The two answers
differ at exactly one pair: `.g2` sorts above `.c1` (raw 3 > 2) yet guarantees nothing about
first-derivative vectors, so `.g2.satisfies(.c1)` is `false` while `.g2 >= .c1` is `true`. They
agree everywhere else, `.c0` included: a geometric class does meet the C0 floor, since G1 entails
G0 (#623).

```swift
ContinuityClass.g1.satisfies(.c0)   // true
ContinuityClass.g1.satisfies(.c1)   // false
ContinuityClass.g2 >= .c1           // true
ContinuityClass.g2.satisfies(.c1)   // false
```

- **OCCT:** none directly; a pure-Swift comparison against the `derivativeOrder` above.

#### `<(lhs:rhs:)`

Ranks two *measured* classes by their place in `GeomAbs_Shape`'s ladder (`Comparable`
conformance). `GeomAbs_Shape` declares its cases in ascending order of how much smoothness is
being claimed (C0 < G1 < C1 < G2 < C2 < C3 < CN), so the raw values compare correctly with no
lookup table needed.

```swift
public static func < (lhs: ContinuityClass, rhs: ContinuityClass) -> Bool
```

Read it as ranking claims, not as an implication chain: `.g2` sorts above `.c1` yet does not
satisfy `.c1` (see `satisfies(_:)` above), because a geometric class is a claim about a
reparametrisable curve rather than the parametrisation actually in hand.

- **Note:** This is the real declaration behind a `check-docs-existence.py` `--coverage` artifact:
  the checker's operator-overload regex cannot capture a symbolic operator name and records a
  pseudo-member literally called `func` for `ContinuityClass` (and separately for `Shape` and
  `Material.PredefinedMaterial`, each with their own operator). That pseudo-member is not a real
  symbol and is intentionally left undocumented; this section is the actual, correct fix.

---
### `continuityClass`

The measured overall continuity of the surface.

```swift
public var continuityClass: ContinuityClass { get }
```

- **Returns:** A `ContinuityClass` describing positional through CN continuity. Raw values are
  `GeomAbs_Shape`'s own ordinals (`c0=0, g1=1, c1=2, g2=3, c2=4, c3=5, cN=6`), which are not a
  0/1/2 order — use `satisfies(_:)` rather than comparing raw values against a
  `ParametricContinuity`.
- **OCCT:** `Geom_Surface::Continuity` (via `OCCTSurfaceGetContinuity`).
- **Example:**
  ```swift
  let bsp = Surface.bspline(poles: ..., ...)!
  print(bsp.continuityClass)                  // typically .c2
  print(bsp.continuityClass.satisfies(.c2))   // true
  ```
- **Note:** `satisfies(_:)` and `>=` answer different questions and are not interchangeable.
  `satisfies(_:)` tests a measured class against a requested **parametric** floor; `<`/`>=` ranks
  two measured classes by their place in `GeomAbs_Shape`'s ladder. Because that ladder interleaves
  the geometric classes with the parametric ones, outranking a class is not the same as entailing
  it: `.g2` sorts above `.c1` but does not satisfy `.c1`, since curvature continuity says nothing
  about first-derivative vectors. They agree on every other pair, `.c0` included — a geometric
  class does meet the positional floor, because G1 entails G0 entails position, and position is
  what C0 is (#623).
  ```swift
  ContinuityClass.g1.satisfies(.c0)   // true  — tangent-continuous implies connected
  ContinuityClass.g1.satisfies(.c1)   // false — but says nothing about derivative vectors
  ContinuityClass.g2 >= .c1           // true  — the ladder ranks G2 above C1 ...
  ContinuityClass.g2.satisfies(.c1)   // false — ... without G2 entailing C1
  ```

---

### `isPlane`, `isCylinder`, `isCone`, `isSphere`, `isTorus`

Boolean type-test properties.

```swift
public var isPlane:    Bool { get }
public var isCylinder: Bool { get }
public var isCone:     Bool { get }
public var isSphere:   Bool { get }
public var isTorus:    Bool { get }
```

Convenience wrappers around `surfaceKind`. All query `surfaceKind == .<type>`.

- **Example:**
  ```swift
  if surface.isSphere { /* analytic sphere geometry available */ }
  ```

---

#### `Surface.isCylinder`

`true` when `surfaceKind == .cylinder`.

#### `Surface.isCone`

`true` when `surfaceKind == .cone`.

#### `Surface.isSphere`

`true` when `surfaceKind == .sphere`.

#### `Surface.isTorus`

`true` when `surfaceKind == .torus`.

---

### `isBezier`, `isBSpline`, `isSurfaceOfRevolution`, `isSurfaceOfExtrusion`, `isOffsetSurface`

Additional boolean type-test properties.

```swift
public var isBezier:              Bool { get }
public var isBSpline:             Bool { get }
public var isSurfaceOfRevolution: Bool { get }
public var isSurfaceOfExtrusion:  Bool { get }
public var isOffsetSurface:       Bool { get }
```

---

#### `Surface.isBSpline`

`true` when `surfaceKind == .bsplineSurface`.

#### `Surface.isSurfaceOfRevolution`

`true` when `surfaceKind == .surfaceOfRevolution`.

#### `Surface.isSurfaceOfExtrusion`

`true` when `surfaceKind == .surfaceOfExtrusion`.

#### `Surface.isOffsetSurface`

`true` when `surfaceKind == .offsetSurface`.

---

### `domain`

The parameter domain (uMin, uMax, vMin, vMax).

```swift
public var domain: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) { get }
```

For infinite analytic surfaces (planes, full cylinders) the returned bounds may be very large values. Always clamp before iterating.

- **Returns:** Tuple of four doubles describing the full UV parameter range.
- **OCCT:** `Geom_Surface::Bounds`.
- **Example:**
  ```swift
  let d = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!.domain
  // d.uMin, d.uMax will be large (±1e100)
  ```

---

### `isUClosed`

Whether the surface is closed in the U direction.

```swift
public var isUClosed: Bool { get }
```

- **OCCT:** `Geom_Surface::IsUClosed`.

---

### `isVClosed`

Whether the surface is closed in the V direction.

```swift
public var isVClosed: Bool { get }
```

- **OCCT:** `Geom_Surface::IsVClosed`.

---

### `isUPeriodic`

Whether the surface is periodic in the U direction.

```swift
public var isUPeriodic: Bool { get }
```

- **OCCT:** `Geom_Surface::IsUPeriodic`.

---

### `isVPeriodic`

Whether the surface is periodic in the V direction.

```swift
public var isVPeriodic: Bool { get }
```

- **OCCT:** `Geom_Surface::IsVPeriodic`.

---

### `uPeriod`

The period in the U direction, if periodic.

```swift
public var uPeriod: Double? { get }
```

- **Returns:** Period value, or `nil` if `isUPeriodic` is `false`.
- **OCCT:** `Geom_Surface::UPeriod`.

---

### `vPeriod`

The period in the V direction, if periodic.

```swift
public var vPeriod: Double? { get }
```

- **Returns:** Period value, or `nil` if `isVPeriodic` is `false`.
- **OCCT:** `Geom_Surface::VPeriod`.

---

## Evaluation

### `point(atU:v:)`

Evaluate the surface point at (u, v).

```swift
public func point(atU u: Double, v: Double) -> SIMD3<Double>
```

- **Parameters:** `u` — U parameter; `v` — V parameter. Both must lie within `domain`.
- **Returns:** 3D point on the surface.
- **OCCT:** `Geom_Surface::D0`.
- **Example:**
  ```swift
  let s = Surface.sphere(center: .zero, radius: 5)!
  let pt = s.point(atU: 0, v: 0)  // (5, 0, 0)
  ```

---

### `d1(atU:v:)`

First-order derivatives at (u, v).

```swift
public func d1(atU u: Double, v: Double) -> (point: SIMD3<Double>, du: SIMD3<Double>, dv: SIMD3<Double>)
```

Returns the point together with the first partial derivatives in U and V in a single call.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Tuple of position, dS/dU, and dS/dV.
- **OCCT:** `Geom_Surface::D1`.
- **Example:**
  ```swift
  let (pt, du, dv) = surface.d1(atU: 0.5, v: 0.5)
  let normal = simd_cross(du, dv)
  ```

---

### `d2(atU:v:)`

Second-order derivatives at (u, v).

```swift
public func d2(atU u: Double, v: Double) -> (
    point: SIMD3<Double>,
    d1u: SIMD3<Double>, d1v: SIMD3<Double>,
    d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>
)
```

Returns position, first partials, and second partials (including the mixed partial d²S/dUdV) in a single call.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Tuple of point, ∂S/∂U, ∂S/∂V, ∂²S/∂U², ∂²S/∂V², ∂²S/∂U∂V.
- **OCCT:** `Geom_Surface::D2`.
- **Example:**
  ```swift
  let (pt, d1u, d1v, d2u, d2v, d2uv) = surface.d2(atU: 0.3, v: 0.7)
  ```

---

### `normal(atU:v:)`

Surface normal at (u, v).

```swift
public func normal(atU u: Double, v: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Unit normal vector, or `nil` at singular points where the tangent plane is degenerate.
- **OCCT:** `GeomLProp_SLProps::Normal` (order 1, `Precision::Confusion()`), gated on `IsNormalDefined()`.
- **See also:** [`normal(u:v:)`](#normaluv) — same computation and same degeneracy test, but returns the zero vector instead of `nil` where the normal is undefined (#401).
- **Example:**
  ```swift
  if let n = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!.normal(atU: 0, v: 0) {
      // n ≈ SIMD3(0, 0, 1)
  }
  ```

---

## Analytic Surfaces

### `Surface.plane(origin:normal:)`

Creates an infinite plane from a point and normal direction.

```swift
public static func plane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Surface?
```

The surface is infinite in both U and V. Trim it with `trimmed(u1:u2:v1:v2:)` or convert to a face with `toFace(uRange:vRange:)` before use in B-Rep operations.

An unlabeled-positional spelling of [`planeFromPointNormal(point:normal:)`](Surface-Advanced.md) and delegates to it (#421) — the two cannot produce different planes for the same input.

- **Parameters:** `origin` — a point on the plane; `normal` — outward normal direction.
- **Returns:** `Geom_Plane` surface, or `nil` if `normal` has zero (or near-zero) length.
- **OCCT:** `GC_MakePlane(gp_Pnt, gp_Dir)`.
- **Example:**
  ```swift
  let floor = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
  ```

---

### `Surface.cylinder(origin:axis:radius:)`

Creates a cylindrical surface.

```swift
public static func cylinder(origin: SIMD3<Double>, axis: SIMD3<Double>,
                             radius: Double) -> Surface?
```

The cylinder is infinite along `axis`. U is the angular parameter (0 to 2π), V is the axial parameter.

- **Parameters:** `origin` — base point on the axis; `axis` — axis direction; `radius` — cylinder radius (must be > 0).
- **Returns:** `Geom_CylindricalSurface`, or `nil` on failure.
- **OCCT:** `Geom_CylindricalSurface(gp_Ax3, radius)`.
- **Example:**
  ```swift
  let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)
  ```

---

### `Surface.cone(origin:axis:radius:semiAngle:)`

Creates a conical surface.

```swift
public static func cone(origin: SIMD3<Double>, axis: SIMD3<Double>,
                         radius: Double, semiAngle: Double) -> Surface?
```

The cone apex is located along `axis` from `origin`. `semiAngle` is in radians and must be in (0, π/2).

- **Parameters:** `origin` — axis base point; `axis` — cone axis direction; `radius` — base radius; `semiAngle` — half-angle in radians.
- **Returns:** `Geom_ConicalSurface`, or `nil` on failure.
- **OCCT:** `Geom_ConicalSurface(gp_Ax3, semiAngle, radius)`.
- **Example:**
  ```swift
  let cone = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1),
                           radius: 10, semiAngle: .pi / 6)
  ```

---

### `Surface.sphere(center:radius:)`

Creates a spherical surface.

```swift
public static func sphere(center: SIMD3<Double>, radius: Double) -> Surface?
```

U is the longitude parameter (0 to 2π), V is the latitude parameter (−π/2 to π/2). The surface is closed in U and has singular poles at V = ±π/2.

- **Parameters:** `center` — sphere centre; `radius` — sphere radius (must be > 0).
- **Returns:** `Geom_SphericalSurface`, or `nil` on failure.
- **OCCT:** `Geom_SphericalSurface(gp_Ax3, radius)`.
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 10)
  ```

---

### `Surface.torus(origin:axis:majorRadius:minorRadius:)`

Creates a toroidal surface.

```swift
public static func torus(origin: SIMD3<Double>, axis: SIMD3<Double>,
                          majorRadius: Double, minorRadius: Double) -> Surface?
```

Both U and V are angular parameters (0 to 2π). The surface is closed and periodic in both directions.

- **Parameters:** `origin` — torus centre; `axis` — torus symmetry axis; `majorRadius` — distance from centre to tube centre; `minorRadius` — tube radius. Both radii must be > 0 and `minorRadius < majorRadius`.
- **Returns:** `Geom_ToroidalSurface`, or `nil` on failure.
- **OCCT:** `Geom_ToroidalSurface(gp_Ax3, majorRadius, minorRadius)`.
- **Example:**
  ```swift
  let torus = Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1),
                              majorRadius: 20, minorRadius: 5)
  ```

---

## Swept Surfaces

### `Surface.extrusion(profile:direction:)`

Creates a surface by extruding a curve along a direction.

```swift
public static func extrusion(profile: Curve3D, direction: SIMD3<Double>) -> Surface?
```

Produces a `Geom_SurfaceOfLinearExtrusion`. The U parameter follows the profile curve; the V parameter measures distance along the extrusion direction. The surface is infinite in V.

- **Parameters:** `profile` — the generator curve; `direction` — extrusion direction vector.
- **Returns:** Extrusion surface, or `nil` if `direction` is zero or construction fails.
- **OCCT:** `Geom_SurfaceOfLinearExtrusion(profile, direction)`.
- **Example:**
  ```swift
  if let line = Curve3D.line(from: .zero, to: SIMD3(10, 0, 0)),
     let surf = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)) {
      let trimmed = surf.trimmed(u1: 0, u2: 1, v1: 0, v2: 20)
  }
  ```

---

### `Surface.revolution(meridian:axisOrigin:axisDirection:)`

Creates a surface of revolution by revolving a curve around an axis.

```swift
public static func revolution(meridian: Curve3D,
                               axisOrigin: SIMD3<Double>,
                               axisDirection: SIMD3<Double>) -> Surface?
```

The U parameter is the angle of revolution (0 to 2π); V follows the meridian curve parameter. Pass a `trimmed(u1:u2:v1:v2:)` result to limit the angular sweep.

- **Parameters:** `meridian` — the profile curve to revolve; `axisOrigin` — origin of the revolution axis; `axisDirection` — direction of the revolution axis.
- **Returns:** `Geom_SurfaceOfRevolution`, or `nil` on failure.
- **OCCT:** `Geom_SurfaceOfRevolution(meridian, gp_Ax1)`.
- **Example:**
  ```swift
  if let profile = Curve3D.line(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10)),
     let surf = Surface.revolution(meridian: profile,
                                    axisOrigin: .zero,
                                    axisDirection: SIMD3(0, 0, 1)) {
      // surf is a cylinder of radius 5 and infinite height
  }
  ```

---

## Freeform Surfaces

### `Surface.bezier(poles:weights:)`

Creates a Bezier surface from a 2D grid of control points.

```swift
public static func bezier(poles: [[SIMD3<Double>]],
                           weights: [[Double]]? = nil) -> Surface?
```

`poles` is a 2D array indexed `[uRow][vCol]`, both dimensions must be ≥ 2. The surface degree in U is `poles.count − 1` and in V is `poles[0].count − 1`. When `weights` is `nil` the surface is non-rational.

- **Parameters:**
  - `poles` — 2D grid of control points (minimum 2×2).
  - `weights` — optional 2D grid of per-pole weights (same dimensions as `poles`); `nil` = uniform 1.0.
- **Returns:** `Geom_BezierSurface`, or `nil` if dimensions are invalid or construction fails.
- **OCCT:** `Geom_BezierSurface(TColgp_Array2OfPnt)` or the weighted overload.
- **Example:**
  ```swift
  let poles: [[SIMD3<Double>]] = [
      [SIMD3(0, 0, 0), SIMD3(0, 5, 1)],
      [SIMD3(5, 0, 1), SIMD3(5, 5, 0)]
  ]
  if let s = Surface.bezier(poles: poles) {
      let pt = s.point(atU: 0.5, v: 0.5)
  }
  ```

---

### `Surface.bspline(poles:weights:knotsU:multiplicitiesU:knotsV:multiplicitiesV:degreeU:degreeV:)`

Creates a BSpline surface with full explicit control.

```swift
public static func bspline(poles: [[SIMD3<Double>]],
                            weights: [[Double]]? = nil,
                            knotsU: [Double], multiplicitiesU: [Int32],
                            knotsV: [Double], multiplicitiesV: [Int32],
                            degreeU: Int, degreeV: Int) -> Surface?
```

`poles` is indexed `[uRow][vCol]`. Knot vectors and multiplicities must satisfy standard BSpline constraints (sum of multiplicities = number of poles + degree + 1 in each direction). When `weights` is `nil` the surface is non-rational.

- **Parameters:**
  - `poles` — 2D control point grid (minimum 2×2).
  - `weights` — optional 2D weight grid; `nil` = non-rational.
  - `knotsU`, `knotsV` — distinct knot values in U and V.
  - `multiplicitiesU`, `multiplicitiesV` — per-knot multiplicities.
  - `degreeU`, `degreeV` — polynomial degrees in U and V (≥ 1).
- **Returns:** `Geom_BSplineSurface`, or `nil` if parameters are invalid.
- **OCCT:** `Geom_BSplineSurface(poles, knotsU, knotsV, multsU, multsV, degU, degV)`.
- **Example:**
  ```swift
  // Bilinear (degree 1×1) BSpline — a flat quad patch
  let poles: [[SIMD3<Double>]] = [
      [SIMD3(0, 0, 0), SIMD3(0, 10, 0)],
      [SIMD3(10, 0, 0), SIMD3(10, 10, 2)]
  ]
  let s = Surface.bspline(
      poles: poles,
      knotsU: [0, 1], multiplicitiesU: [2, 2],
      knotsV: [0, 1], multiplicitiesV: [2, 2],
      degreeU: 1, degreeV: 1
  )
  ```

---

## Operations

### `trimmed(u1:u2:v1:v2:)`

Creates a rectangular trim of this surface.

```swift
public func trimmed(u1: Double, u2: Double, v1: Double, v2: Double) -> Surface?
```

The trim bounds must be within the surface `domain`. Use this to bound infinite analytic surfaces (planes, cylinders) before face creation.

- **Parameters:** `u1`, `u2` — U parameter bounds; `v1`, `v2` — V parameter bounds.
- **Returns:** `Geom_RectangularTrimmedSurface`, or `nil` on failure.
- **OCCT:** `Geom_RectangularTrimmedSurface(surface, u1, u2, v1, v2)`.
- **Example:**
  ```swift
  let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
  let patch = plane.trimmed(u1: 0, u2: 10, v1: 0, v2: 10)
  ```

---

### `offset(distance:)`

Creates an offset surface at a given distance from this surface.

```swift
public func offset(distance: Double) -> Surface?
```

Positive distance offsets in the direction of the surface normal. Complex surfaces may produce self-intersections; use `ShapeHealing` tools to fix them before B-Rep operations.

- **Parameters:** `distance` — offset distance in model units.
- **Returns:** `Geom_OffsetSurface`, or `nil` on failure.
- **OCCT:** `Geom_OffsetSurface(surface, distance)`.
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 10)!
  let outer = sphere.offset(distance: 2)  // radius-12 sphere
  ```

---

### `translated(by:)`

Returns a translated copy of this surface.

```swift
public func translated(by delta: SIMD3<Double>) -> Surface?
```

- **Parameters:** `delta` — translation vector.
- **Returns:** New surface shifted by `delta`, or `nil` on failure.
- **OCCT:** `Geom_Surface::Translated(gp_Vec)`.
- **Example:**
  ```swift
  let moved = sphere.translated(by: SIMD3(0, 0, 5))
  ```

---

### `rotated(axisOrigin:axisDirection:angle:)`

Returns a rotated copy of this surface.

```swift
public func rotated(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>,
                     angle: Double) -> Surface?
```

- **Parameters:** `axisOrigin` — a point on the rotation axis; `axisDirection` — axis direction; `angle` — angle in radians.
- **Returns:** Rotated surface copy, or `nil` on failure.
- **OCCT:** `Geom_Surface::Rotated(gp_Ax1, angle)`.
- **Example:**
  ```swift
  let tilted = cylinder.rotated(axisOrigin: .zero, axisDirection: SIMD3(0, 1, 0), angle: .pi / 4)
  ```

---

### `scaled(center:factor:)`

Returns a scaled copy of this surface.

```swift
public func scaled(center: SIMD3<Double>, factor: Double) -> Surface?
```

- **Parameters:** `center` — scaling centre point; `factor` — scale factor (negative mirrors through centre).
- **Returns:** Scaled surface copy, or `nil` on failure.
- **OCCT:** `Geom_Surface::Scaled(gp_Pnt, factor)`.
- **Example:**
  ```swift
  let doubled = sphere.scaled(center: .zero, factor: 2)
  ```

---

### `mirrored(planeOrigin:planeNormal:)`

Returns a mirrored copy of this surface across a plane.

```swift
public func mirrored(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Surface?
```

- **Parameters:** `planeOrigin` — a point on the mirror plane; `planeNormal` — plane normal direction.
- **Returns:** Mirrored surface copy, or `nil` on failure.
- **OCCT:** `Geom_Surface::Mirrored(gp_Ax2)`.
- **Example:**
  ```swift
  let reflected = cone.mirrored(planeOrigin: .zero, planeNormal: SIMD3(1, 0, 0))
  ```

---

### `mirrored(acrossPoint:)`

Returns a mirrored copy of this surface across a point.

```swift
public func mirrored(acrossPoint point: SIMD3<Double>) -> Surface?
```

- **Parameters:** `point` — the mirror point.
- **Returns:** Mirrored surface copy, or `nil` on failure.
- **OCCT:** `Geom_Surface::Mirrored(gp_Pnt)`.
- **Example:**
  ```swift
  let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
  let mirrored = plane?.mirrored(acrossPoint: SIMD3(1, 1, 1))
  ```

---

### `mirrored(acrossAxis:direction:)`

Returns a mirrored copy of this surface across an axis (line).

```swift
public func mirrored(acrossAxis point: SIMD3<Double>, direction: SIMD3<Double>) -> Surface?
```

- **Parameters:** `point` — a point on the mirror axis; `direction` — axis direction.
- **Returns:** Mirrored surface copy, or `nil` on failure.
- **OCCT:** `Geom_Surface::Mirrored(gp_Ax1)`.
- **Example:**
  ```swift
  let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
  let mirrored = plane?.mirrored(acrossAxis: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
  ```

---

## Conversion

### `toBSpline()`

Converts this surface to a BSpline representation.

```swift
public func toBSpline() -> Surface?
```

Uses OCCT's exact conversion where one exists, and approximates where it does not. Infinite surfaces must be trimmed first. The result is a `Geom_BSplineSurface`.

- **Returns:** BSpline surface, or `nil` if conversion fails (e.g. surface is already a non-convertible type).
- **OCCT:** `GeomConvert::SurfaceToBSplineSurface`.
- **Note:** Infinite surfaces (planes, full cylinders) will cause conversion to fail — trim the domain first with `trimmed(u1:u2:v1:v2:)`.
- **Note:** **This is not an exactness guarantee, and it takes no tolerance.** Analytic families
  (plane, cylinder, cone, sphere, torus, surface of revolution) plus Bezier and BSpline surfaces
  convert exactly. Everything else, including an offset surface with no analytic equivalent, is
  handed to `GeomConvert_ApproxSurface` at a tolerance OCCT hardcodes to `1e-4`
  (`GeomConvert_1.cxx:786` for a trimmed surface, `:960` otherwise), with a continuity derived from
  the surface's own `IsCNu`/`IsCNv`, and the fit is returned whether or not that tolerance was met.
  Measured on a trimmed offset of a BSpline that is C1 but not C2 in U, it caps out at degree 14 and
  sits 0.038 from its source (#572; before the `0019` kernel patch it stopped at degree 12x9 and sat
  0.104 out while reporting success internally). Use `approximated(tolerance:...)` to name the
  tolerance and `approxWithDetails(...)` to learn whether it was reached.
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 10)!
  let trimmed = sphere.trimmed(u1: 0, u2: .pi * 2, v1: -.pi / 2, v2: .pi / 2)!
  let bsp = trimmed.toBSpline()
  ```

---

### `approximated(tolerance:continuity:maxSegments:maxDegree:)`

Approximates this surface as a BSpline surface within a tolerance.

```swift
public func approximated(tolerance: Double = 1e-3, continuity: Int = 2,
                          maxSegments: Int = 100, maxDegree: Int = 8) -> Surface?
```

Useful when exact `toBSpline()` conversion is unavailable (e.g. offset or composite surfaces).

- **Parameters:**
  - `tolerance` — maximum approximation deviation.
  - `continuity` — desired continuity order, applied to **both** parametric directions, a
    `ParametricContinuity` raw value (0=C0, 1=C1, 2=C2). C2 is the ceiling: `AdvApprox` throws for
    C3 and above, which surfaces as `nil`.
  - `maxSegments` — maximum number of BSpline segments.
  - `maxDegree` — maximum polynomial degree.
- **Returns:** Approximated BSpline surface, or `nil` when OCCT produced no fit at all.
- **OCCT:** `GeomConvert_ApproxSurface`, gated on `HasResult()`, with `PrecisCode = 0`.
- **Note:** Defaults match `Curve3D.approximated`/`Curve2D.approximated` (#406) — all three wrap
  the same `GeomConvert_Approx*`/`Geom2dConvert_ApproxCurve` family applied to a different OCCT
  geometry hierarchy, not independent algorithms whose numeric defaults should diverge. (Before
  #406 this defaulted to `tolerance: 0.01, maxDegree: 10`, a 10x looser tolerance with no
  documented reason; measurement found the tighter shared values succeed on every case tried,
  with no meaningful cost difference.)
- **Note:** A non-`nil` result is **not** a promise that `tolerance` was met. This gates on OCCT's
  `HasResult()`, documented as true for a fit that is "not NECESSARILY within the required
  tolerance" — on a surface `maxDegree` cannot fit (a torus at `1e-9`) OCCT returns a usable best
  effort anyway. [`approxWithDetails`](#approxwithdetailstoleranceucontinuityvcontinuitymaxdegreemaxsegments)
  runs the identical approximation and reports the actual `maxError`.
- **Example:**
  ```swift
  let offset = sphere.offset(distance: 1)!
  let bsp = offset.approximated(tolerance: 0.001)
  ```

---

### `approxWithDetails(tolerance:uContinuity:vContinuity:maxDegree:maxSegments:)`

The same approximation as [`approximated`](#approximatedtolerancecontinuitymaxsegmentsmaxdegree),
reporting the fit's error and completion status, with the two parametric directions requested
separately.

```swift
public func approxWithDetails(tolerance: Double, uContinuity: ParametricContinuity = .c2,
                              vContinuity: ParametricContinuity = .c2,
                              maxDegree: Int = 8, maxSegments: Int = 100) -> ApproxSurfaceResult
```

One shared `GeomConvert_ApproxSurface` run backs both entry points (#491), so for identical
arguments they return the same surface — this one just also carries the diagnostics OCCT already
computed. Note `maxDegree` precedes `maxSegments` here, the reverse of `approximated`'s order.

- **Returns:** `ApproxSurfaceResult(surface:maxError:isDone:hasResult:)`. `surface` is populated
  exactly when `hasResult`; `isDone` is whether the fit reached `tolerance`; `maxError` is the
  greatest distance between the source surface and the fit.
- **OCCT:** `GeomConvert_ApproxSurface` — `Surface()`, `MaxError()`, `IsDone()`, `HasResult()`.
- **Note:** Before #491 the continuity defaults here were C1, and this entry point passed
  `PrecisCode = 1` to `GeomConvert_ApproxSurface` where `approximated` passed `0`, so the two
  returned measurably different surfaces for the same request. Both now default to C2 and pass `0`.
- **Note:** `maxError` is not trustworthy for a `.c0` request — see
  [#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522), an upstream defect where a C0 fit
  can collapse a direction to degree 1 and still report an error five orders of magnitude too small.
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 10)!
  let fit = sphere.approxWithDetails(tolerance: 1e-5)
  if let bspline = fit.surface, fit.isDone {
      print("fitted to \(fit.maxError) with \(bspline.uPoleCount)x\(bspline.vPoleCount) poles")
  }
  ```

---

## Iso Curves

### `uIso(at:)`

Extracts a U-iso curve (constant U, varying V).

```swift
public func uIso(at u: Double) -> Curve3D?
```

- **Parameters:** `u` — the fixed U parameter value.
- **Returns:** A `Curve3D` at the given U value, or `nil` on failure.
- **OCCT:** `Geom_Surface::UIso(u)`.
- **Example:**
  ```swift
  // Extract the meridian at U=0 on a sphere
  let meridian = Surface.sphere(center: .zero, radius: 10)!.uIso(at: 0)
  ```

---

### `vIso(at:)`

Extracts a V-iso curve (constant V, varying U).

```swift
public func vIso(at v: Double) -> Curve3D?
```

- **Parameters:** `v` — the fixed V parameter value.
- **Returns:** A `Curve3D` at the given V value, or `nil` on failure.
- **OCCT:** `Geom_Surface::VIso(v)`.
- **Example:**
  ```swift
  // Extract the equatorial circle of a sphere
  let equator = Surface.sphere(center: .zero, radius: 10)!.vIso(at: 0)
  ```

---

## Pipe Surfaces

### `Surface.pipe(path:radius:)`

Creates a pipe surface by sweeping a circle along a path.

```swift
public static func pipe(path: Curve3D, radius: Double) -> Surface?
```

The cross-section is a circle of the given radius. Orientation is determined by the Frenet frame of the path.

- **Parameters:** `path` — sweep path curve; `radius` — pipe radius (must be > 0).
- **Returns:** Pipe surface, or `nil` if construction fails (e.g. path is too tightly curved for the radius).
- **OCCT:** `GeomFill_Pipe(path, radius)::Perform`.
- **Example:**
  ```swift
  if let helix = Curve3D.bspline(throughPoints: [SIMD3(0,0,0), SIMD3(5,5,5)]),
     let pipe = Surface.pipe(path: helix, radius: 2) {
      let face = pipe.toFace()
  }
  ```

---

### `Surface.pipe(path:section:)`

Creates a pipe surface by sweeping a section curve along a path.

```swift
public static func pipe(path: Curve3D, section: Curve3D) -> Surface?
```

The section curve defines the cross-sectional shape at each point along `path`.

- **Parameters:** `path` — sweep path curve; `section` — cross-section curve.
- **Returns:** Pipe surface, or `nil` on failure.
- **OCCT:** `GeomFill_Pipe(path, section)::Perform`.
- **Example:**
  ```swift
  if let arc = Curve3D.arcOfCircle(center: .zero, radius: 3,
                                    startAngle: 0, endAngle: .pi),
     let line = Curve3D.line(from: .zero, to: SIMD3(0, 0, 10)),
     let pipe = Surface.pipe(path: line, section: arc) {
      let trimmed = pipe.trimmed(u1: 0, u2: 1, v1: 0, v2: 1)
  }
  ```

---

## Draw Methods

### `drawGrid(uLineCount:vLineCount:pointsPerLine:)`

Draws iso-parameter grid lines for Metal visualisation.

```swift
public func drawGrid(uLineCount: Int = 10, vLineCount: Int = 10,
                     pointsPerLine: Int = 50) -> [[SIMD3<Double>]]
```

Samples `uLineCount` U-iso lines and `vLineCount` V-iso lines, each discretised to `pointsPerLine` 3D points. Infinite surfaces are clamped to ±100 before sampling.

- **Parameters:** `uLineCount` — number of U iso-lines, at least 0; `vLineCount` — number of V iso-lines, at least 0; `pointsPerLine` — points per iso-line, at least 1.
- **Returns:** Array of polylines (one per iso-line), empty if the surface is null or the grid cannot be served. The bound is on the total: `(uLineCount + vLineCount) * pointsPerLine` must not exceed `Sampling.maximumSampleCount` (10,000,000), and each factor is checked on its own, since a negative line count used to abort the process unless the other count happened to outweigh it (#558).
- **OCCT:** `Geom_Surface::Bounds` + `Geom_Surface::D0` via `OCCTSurfaceDrawGrid`.
- **Example:**
  ```swift
  let gridLines = surface.drawGrid(uLineCount: 10, vLineCount: 10, pointsPerLine: 50)
  // Pass to Metal vertex buffer for wireframe preview
  ```

---

### `SurfaceGrid`

A 2D grid of points sampled over a surface's UV parameter space, returned by `drawMesh(uCount:vCount:)`
and `evaluateGrid(uParameters:vParameters:)` (see [Surface-Analysis.md](Surface-Analysis.md)). Both
methods share this one type specifically so indexing is unambiguous — access is always
`.at(u:v:)`, regardless of how each method lays out its own bridge buffer internally. Before
[#404](https://github.com/SecondMouseAU/OCCTSwift/issues/404), the two returned raw
`[[SIMD3<Double>]]` with opposite nesting order (`[uIndex][vIndex]` vs `[vIndex][uIndex]`) and
nothing at the type level stopped a caller from mixing them up.

```swift
public struct SurfaceGrid: Sendable {
    public let uCount: Int
    public let vCount: Int
    public var isEmpty: Bool { get }
    public func at(u: Int, v: Int) -> SIMD3<Double>
}
```

- **`uCount`/`vCount`:** number of samples in each direction.
- **`at(u:v:)`:** the point at that grid index. Traps if either index is out of range.
- **`isEmpty`:** `true` for the grid returned when sampling fails.

Storage is U-major (`u * vCount + v`). Every surface grid producer in the bridge writes that same
layout (`drawMesh`, `evaluateGrid` and `evaluateGridD1`) since
[#486](https://github.com/SecondMouseAU/OCCTSwift/issues/486); before it, two bridge functions
wrote opposite layouts, each describing its own as "row-major".

---

#### `SurfaceGrid.at`

---

### `SurfaceGridD1`

The D1 counterpart of `SurfaceGrid`, returned by `evaluateGridD1(uParameters:vParameters:)`
(see [Surface-Analysis.md](Surface-Analysis.md#evaluategridd1uparametersvparameters)). Indexed
`.at(u:v:)` for the same reason: a flat `[(point:, d1u:, d1v:)]` array leaves the caller guessing
whether u or v runs fastest, which is exactly the ambiguity the deprecated
`gridEvalD1(uParams:vParams:)` shipped with
([#486](https://github.com/SecondMouseAU/OCCTSwift/issues/486)).

```swift
public struct SurfaceGridD1: Sendable {
    public let uCount: Int
    public let vCount: Int
    public var isEmpty: Bool { get }
    public func at(u: Int, v: Int) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)
}
```

- **`at(u:v:)`:** point and both first partial derivatives at that grid index. Traps if either
  index is out of range.
- **`isEmpty`:** `true` for the grid returned when evaluation fails.
- **Example:**
  ```swift
  let grid = surface.evaluateGridD1(uParameters: [0, 0.5, 1], vParameters: [0, 1])
  let sample = grid.at(u: 2, v: 0)
  let normal = simd_normalize(simd_cross(sample.d1u, sample.d1v))
  ```

| Member | Kind | Meaning |
|---|---|---|
| `uCount` | public stored property | Number of samples in the U direction. |
| `vCount` | public stored property | Number of samples in the V direction. |

#### `SurfaceGridD1.at(u:v:)`

Point and both first partial derivatives at grid index `(u, v)`.

```swift
public func at(u: Int, v: Int) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)
```

Looks up the flat, U-major backing arrays (`points`, `d1u`, `d1v`) at
`surfaceGridIndex(u:v:vCount:)`, the same indexing function `SurfaceGrid.at(u:v:)` uses, so the two
types can never disagree about which of U or V runs fastest.

- **Parameters:** `u`, `v`: grid indices; `u` in `0..<uCount`, `v` in `0..<vCount`.
- **Returns:** A tuple of the sampled point and its first partial derivatives in U and V.
- **Precondition:** traps if either index is out of range.
- **OCCT:** Pure-Swift indexing over buffers `Surface.evaluateGridD1(uParameters:vParameters:)` fills.

---

### `drawMesh(uCount:vCount:)`

Samples a uniform grid of points over the surface's parametric bounds.

```swift
public func drawMesh(uCount: Int = 20, vCount: Int = 20) -> SurfaceGrid
```

- **Parameters:** `uCount` — number of U sample points, at least 1; `vCount` — number of V sample points, at least 1.
- **Returns:** A `SurfaceGrid` indexed `.at(u:v:)`, or an empty grid if sampling fails or the grid cannot be served. The bound is on the **product**: `uCount * vCount` must not exceed `Sampling.maximumSampleCount` (10,000,000). Each factor is also checked on its own, which is not redundant — two negative counts multiply to a plausible positive total, so `drawMesh(uCount: -1, vCount: -1)` used to look well-behaved while `drawMesh(uCount: -1, vCount: 3)` aborted the process (#558).
- **Sampled range:** the surface's parametric domain with infinite bounds clamped to ±100. For a bounded surface that is `domain`; for an unbounded one it is not, and the difference is extreme rather than marginal — a plane's `domain.uMin` is about -2e100 while its first sample sits at -100.
- **One sample in a direction is a request, not a degenerate case.** Despite the name nothing here triangulates, so `uCount: 1` is the single iso-row at the low end of the sampled U range and a 1×1 grid is one point. The bridge used to demand 2 per direction — its own interpolation divisor, not an OCCT rule — so a request this page called in-range came back as an empty grid indistinguishable from a failed sample (#620). Counts below 1 are still rejected, and rejection is still an empty grid.
- **OCCT:** `Geom_Surface::D0` sampled on a uniform UV grid.
- **Example:**
  ```swift
  let mesh = surface.drawMesh(uCount: 30, vCount: 30)
  let p = mesh.at(u: 5, v: 3)

  // A single V iso-row: 20 points along v, at the low end of the sampled U range.
  let isoRow = surface.drawMesh(uCount: 1, vCount: 20)
  let along = (0..<isoRow.vCount).map { isoRow.at(u: 0, v: $0) }

  // Bounded: that low end is domain.uMin. Unbounded: it is the clamp instead.
  let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
  plane.drawMesh(uCount: 1, vCount: 4).at(u: 0, v: 0).x   // -100, not plane.domain.uMin
  ```

---

## Bounding Box

### `boundingBox`

The axis-aligned bounding box of this surface.

```swift
public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? { get }
```

Returns `nil` for infinite surfaces (planes, full cylinders) because `BndLib_AddSurface` cannot produce a finite box. Trim the surface first.

- **Returns:** Tuple of min and max AABB corners, or `nil` for infinite or degenerate surfaces.
- **OCCT:** `GeomAdaptor_Surface` + `BndLib_AddSurface::Add`.
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 5)!
  if let bb = sphere.boundingBox {
      // bb.min ≈ SIMD3(-5, -5, -5), bb.max ≈ SIMD3(5, 5, 5)
  }
  ```

---

## Surface Transform (v0.128.0)

In-place transform variants that modify the surface geometry directly rather than returning a copy. All return `@discardableResult Bool`.

---

### `translate(dx:dy:dz:)`

Translates the surface in place.

```swift
@discardableResult
public func translate(dx: Double, dy: Double, dz: Double) -> Bool
```

- **Parameters:** `dx`, `dy`, `dz` — translation components.
- **Returns:** `true` if successful.
- **OCCT:** `Geom_Surface::Translate(gp_Vec)` applied in-place via `OCCTSurfaceTransform`.

---

### `rotate(axisOrigin:axisDirection:angle:)`

Rotates the surface in place around an axis.

```swift
@discardableResult
public func rotate(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double) -> Bool
```

- **Parameters:** `axisOrigin` — point on the rotation axis; `axisDirection` — axis direction; `angle` — angle in radians.
- **Returns:** `true` if successful.
- **OCCT:** `Geom_Surface::Rotate(gp_Ax1, angle)` in-place.

---

### `scale(center:factor:)`

Scales the surface in place from a centre point.

```swift
@discardableResult
public func scale(center: SIMD3<Double>, factor: Double) -> Bool
```

- **Parameters:** `center` — scaling origin; `factor` — scale factor.
- **Returns:** `true` if successful.
- **OCCT:** `Geom_Surface::Scale(gp_Pnt, factor)` in-place.

---

### `mirrorPoint(_:)`

Mirrors the surface in place through a point.

```swift
@discardableResult
public func mirrorPoint(_ point: SIMD3<Double>) -> Bool
```

- **Parameters:** `point` — the mirror centre.
- **Returns:** `true` if successful.
- **OCCT:** `Geom_Surface::Mirror(gp_Pnt)` in-place.

---

### `mirrorAxis(origin:direction:)`

Mirrors the surface in place through an axis.

```swift
@discardableResult
public func mirrorAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Bool
```

- **Parameters:** `origin` — a point on the mirror axis; `direction` — axis direction.
- **Returns:** `true` if successful.
- **OCCT:** `Geom_Surface::Mirror(gp_Ax1)` in-place.

---

### `mirrorPlane(origin:normal:)`

Mirrors the surface in place through a plane.

```swift
@discardableResult
public func mirrorPlane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Bool
```

- **Parameters:** `origin` — a point on the mirror plane; `normal` — plane normal direction.
- **Returns:** `true` if successful.
- **OCCT:** `Geom_Surface::Mirror(gp_Ax2)` in-place.

---

## GeomEval Surface Factories (v0.130.0)

Parametric surface factories backed by `Geom_CartesianPoint`-derived evaluator surfaces. All return `nil` on invalid parameters.

---

### `Surface.ellipsoid(a:b:c:)`

Creates a triaxial ellipsoid surface.

```swift
public static func ellipsoid(a: Double, b: Double, c: Double) -> Surface?
```

Parametrisation: `P(u,v) = a·cos(v)·cos(u)·X + b·cos(v)·sin(u)·Y + c·sin(v)·Z`.

- **Parameters:** `a` — semi-axis along X (> 0); `b` — semi-axis along Y (> 0); `c` — semi-axis along Z (> 0).
- **Returns:** Ellipsoid surface, or `nil` if any semi-axis ≤ 0.
- **OCCT:** `OCCTGeomEvalEllipsoidCreate` — custom `Geom_Surface` evaluator.
- **Example:**
  ```swift
  let ellipsoid = Surface.ellipsoid(a: 10, b: 6, c: 4)
  ```

---

### `Surface.hyperboloid(r1:r2:twoSheets:)`

Creates a hyperboloid of revolution surface.

```swift
public static func hyperboloid(r1: Double, r2: Double, twoSheets: Bool = false) -> Surface?
```

- **Parameters:** `r1` — first semi-axis radius (> 0); `r2` — second semi-axis radius (> 0); `twoSheets` — if `true`, creates a two-sheet hyperboloid.
- **Returns:** Hyperboloid surface, or `nil` on failure.
- **OCCT:** `OCCTGeomEvalHyperboloidCreate`.

---

### `Surface.paraboloid(focal:)`

Creates a circular paraboloid of revolution surface.

```swift
public static func paraboloid(focal: Double) -> Surface?
```

- **Parameters:** `focal` — focal distance (must be > 0).
- **Returns:** Paraboloid surface, or `nil` if `focal ≤ 0`.
- **OCCT:** `OCCTGeomEvalParaboloidCreate`.
- **Example:**
  ```swift
  let dish = Surface.paraboloid(focal: 5)
  ```

---

### `Surface.circularHelicoid(pitch:)`

Creates a circular helicoid (ruled surface).

```swift
public static func circularHelicoid(pitch: Double) -> Surface?
```

Parametrisation: `S(u,v) = v·cos(u)·X + v·sin(u)·Y + (P·u / 2π)·Z`.

- **Parameters:** `pitch` — axial advance per 2π turn (must be ≠ 0).
- **Returns:** Helicoid surface, or `nil` on failure.
- **OCCT:** `OCCTGeomEvalCircularHelicoidCreate`.
- **Example:**
  ```swift
  let helicoid = Surface.circularHelicoid(pitch: 3.0)
  ```

---

### `Surface.hyperbolicParaboloid(a:b:)`

Creates a hyperbolic paraboloid (saddle surface).

```swift
public static func hyperbolicParaboloid(a: Double, b: Double) -> Surface?
```

Parametrisation: `P(u,v) = u·X + v·Y + (u²/a² − v²/b²)·Z`.

- **Parameters:** `a` — first semi-axis length (> 0); `b` — second semi-axis length (> 0).
- **Returns:** Saddle surface, or `nil` on failure.
- **OCCT:** `OCCTGeomEvalHypParaboloidCreate`.

---

### `Surface.gordon(profiles:guides:tolerance:)`

Builds a Gordon surface from a network of profile and guide curves.

```swift
public static func gordon(profiles: [Curve3D], guides: [Curve3D], tolerance: Double = 1e-3) -> Surface?
```

Requires at least 2 profile curves (V-direction) and 2 guide curves (U-direction) that form a complete grid: every profile must intersect every guide within `tolerance`.

- **Parameters:** `profiles` — profile curves (V-direction, ≥ 2); `guides` — guide curves (U-direction, ≥ 2); `tolerance` — geometric tolerance for intersection detection.
- **Returns:** Gordon BSpline surface, or `nil` if construction fails.
- **OCCT:** `OCCTGeomFillGordon` / `GeomFill_Gordon`.
- **Note:** Use `gordonReport(profiles:guides:tolerance:allowApproximateFallback:)` to get detailed failure diagnostics.
- **Example:**
  ```swift
  // Requires profiles and guides to intersect at a grid of points
  if let surf = Surface.gordon(profiles: profiles, guides: guides, tolerance: 1e-3) {
      let face = surf.toFace()
  }
  ```

---

### `GordonResultStatus`

Result status enum mirroring `GeomFill_Gordon::ResultStatus`.

```swift
public enum GordonResultStatus: Int, Sendable {
    case notStarted, done, invalidInput, conversionFailed, intersectionFailed,
         orderingFailed, reparametrizationFailed, compatibilityFailed,
         curveCompatibilityFailed, rationalReparametrizationFailed,
         skinningFailed, referenceSurfaceFailed, knotAlignmentFailed,
         rationalDegreeOverflow, rationalConstructionFailed,
         periodicityFailed, approximationFailed, constructionFailed
}
```

One case per stage of `GeomFill_Gordon::Perform()`; the descriptions below are the C++
`ResultStatus` enum's own doc comments in `GeomFill_Gordon.hxx`, carried over case for case.

| Case | Meaning |
|---|---|
| `.notStarted` | `Perform()` has not been called since initialization. |
| `.done` | Surface has been constructed. |
| `.invalidInput` | Input network has too few profile or guide curves. |
| `.conversionFailed` | Curves could not be converted or reparametrized to B-splines. |
| `.intersectionFailed` | Full profile/guide intersection table could not be built. |
| `.orderingFailed` | Network curves could not be ordered consistently. |
| `.reparametrizationFailed` | Intersections could not be equalized in parameter space. |
| `.compatibilityFailed` | Prepared network failed geometric compatibility checks. |
| `.curveCompatibilityFailed` | Prepared curve families are not B-spline compatible. |
| `.rationalReparametrizationFailed` | Rational curves require unsupported exact reparametrization. |
| `.skinningFailed` | Intermediate profile/guide skinning has failed. |
| `.referenceSurfaceFailed` | Intersection-grid reference surface could not be built. |
| `.knotAlignmentFailed` | Intermediate surfaces could not be aligned. |
| `.rationalDegreeOverflow` | Exact rational product degree exceeds OCCT's B-spline limit. |
| `.rationalConstructionFailed` | Exact rational numerator/denominator construction has failed. |
| `.periodicityFailed` | Closed seam could not be converted to periodic form. |
| `.approximationFailed` | Optional approximate fallback (`allowApproximateFallback`) has failed. |
| `.constructionFailed` | Final B-spline surface construction has failed. |

Each case is indexed below too, so a reference link can land on one directly; the table above is
the authoritative description.

#### `Surface.GordonResultStatus.constructionFailed`

---

### `GordonResult`

Outcome struct returned by `gordonReport(...)`.

```swift
public struct GordonResult: Sendable {
    public let surface: Surface?
    public let status: GordonResultStatus
    public let isApproximate: Bool
}
```

`isApproximate` is `true` when the result was produced by a sampled B-spline fallback rather than exact interpolation.

---

#### `GordonResult.isApproximate`

---

### `Surface.gordonReport(profiles:guides:tolerance:allowApproximateFallback:)`

Builds a Gordon surface, returning the result status and approximate flag.

```swift
public static func gordonReport(profiles: [Curve3D], guides: [Curve3D],
                                 tolerance: Double = 1e-3,
                                 allowApproximateFallback: Bool = false) -> GordonResult
```

- **Parameters:** `profiles` — profile curves (≥ 2); `guides` — guide curves (≥ 2); `tolerance` — intersection tolerance; `allowApproximateFallback` — permit sampled B-spline fallback when exact construction fails.
- **Returns:** `GordonResult` with the surface (or `nil`), status code, and approximate flag.
- **OCCT:** `OCCTGeomFillGordonReport`.

---

### `NetworkSurfaceStatus`

Result status enum mirroring `GeomFill_NetworkSurface::ResultStatus`.

```swift
public enum NetworkSurfaceStatus: Int, Sendable {
    case notStarted, done, invalidInput, curveCompatibilityFailed,
         skinningFailed, referenceSurfaceFailed, knotAlignmentFailed,
         rationalDegreeOverflow, rationalConstructionFailed,
         constructionFailed, periodicityFailed
}
```

One case per stage of `GeomFill_NetworkSurface::Perform()`; the descriptions below are the C++
`ResultStatus` enum's own doc comments in `GeomFill_NetworkSurface.hxx`, carried over case for case.
`NetworkSurfaceStatus` is the low-level counterpart of [`GordonResultStatus`](#gordonresultstatus):
fewer cases because `networkSurface(...)` receives an already-ordered, already-compatible network
(no `orderingFailed`/`reparametrizationFailed`/`compatibilityFailed`/`conversionFailed`/
`intersectionFailed`/`approximationFailed`, which are `GeomFill_Gordon`'s own upstream-preparation
stages).

| Case | Meaning |
|---|---|
| `.notStarted` | `Perform()` has not been called since initialization. |
| `.done` | Surface has been constructed. |
| `.invalidInput` | Prepared network does not satisfy the builder's requirements. |
| `.curveCompatibilityFailed` | Curve families could not be converted to a compatible basis. |
| `.skinningFailed` | Profile or guide skin interpolation has failed. |
| `.referenceSurfaceFailed` | Intersection-grid reference surface could not be built. |
| `.knotAlignmentFailed` | Intermediate surfaces could not be aligned to one knot basis. |
| `.rationalDegreeOverflow` | Exact rational product degree exceeds OCCT's B-spline limit. |
| `.rationalConstructionFailed` | Exact rational numerator/denominator construction has failed. |
| `.constructionFailed` | Internal B-spline construction has failed. |
| `.periodicityFailed` | Closed seam could not be converted to periodic form. |

#### `Surface.NetworkSurfaceStatus.periodicityFailed`

---

### `Surface.networkSurface(profiles:guides:tolerance:)`

Builds a surface with the low-level `GeomFill_NetworkSurface` builder.

```swift
public static func networkSurface(profiles: [Curve3D], guides: [Curve3D],
                                   tolerance: Double = 1e-3)
    -> (surface: Surface?, status: NetworkSurfaceStatus)
```

Curves are converted to non-periodic BSplines; each profile/guide pair's real contact point and its
parameter in the *other* family's domain are found via `GeomAPI_ExtremaCurveCurve` and averaged
across the family, matching what `GeomFill_NetworkSurface::Perform()` requires to align its internal
profile/guide/reference skins to one knot basis (#689). This is a lower-level alternative to
`gordon(...)`: it does not reorder a scrambled network, run `gordon`'s reparametrization pass, or
derive rational contact weights (every contact point is weighted 1.0), so a network `gordon` can
complete can still decline here.

- **Parameters:** `profiles` — profile curves in U, at least 2; `guides` — guide curves in V, at least 2; `tolerance` — geometric tolerance for closed-seam checks.
- **Returns:** Tuple of the surface (or `nil`) and a status code.
- **OCCT:** `OCCTGeomFillNetworkSurface` / `GeomFill_NetworkSurface`.

---

### `Surface.KnotSplitResult`

Result of `knotSplitting(uContinuity:vContinuity:)` (documented in full on
[Surface-Advanced.md](Surface-Advanced.md#knotsplittingucontinuityvcontinuity)): the split counts,
parameter values, and knot-table indices needed to divide a BSpline surface into pieces meeting a
requested continuity in U and V.

```swift
public struct KnotSplitResult {
    public let uSplitCount: Int
    public let vSplitCount: Int
    public let uSplitParams: [Double]
    public let vSplitParams: [Double]
    public let uSplitIndices: [Int]
    public let vSplitIndices: [Int]
}
```

| Field | Meaning |
|---|---|
| `uSplitCount` | Number of U split locations needed for the requested continuity. |
| `vSplitCount` | Number of V split locations needed for the requested continuity. |
| `uSplitParams` | U parameter values (ascending, bounded by the surface's own U range) at each split. |
| `vSplitParams` | V parameter values (ascending, bounded by the surface's own V range) at each split. |
| `uSplitIndices` | 1-based indices into the surface's own U knot table, one per split: `uSplitParams[i] == bsplineUKnot(index: uSplitIndices[i])`. |
| `vSplitIndices` | 1-based indices into the surface's own V knot table, one per split. |

All six fields are empty/zero for a non-BSpline surface. `uSplitIndices`/`vSplitIndices` exist
because the underlying analyzer (`GeomConvert_BSplineSurfaceKnotSplitting`) reports both the
parameter values and the knot-table indices those values came from; before #562 only the
parameter-value form was exposed here.

#### `Surface.KnotSplitResult.vSplitIndices`

---

## GeomEval TBezier / AHTBezier Surfaces (v0.131.0)

### `Surface.tBezier(poles:uCount:vCount:alphaU:alphaV:)`

Creates a Trigonometric Bezier surface.

```swift
public static func tBezier(poles: [SIMD3<Double>], uCount: Int, vCount: Int,
                             alphaU: Double, alphaV: Double) -> Surface?
```

A tensor-product surface using trigonometric Bernstein-like bases in both U and V. Parameter domain is U ∈ `[0, π/alphaU]`, V ∈ `[0, π/alphaV]`.

- **Parameters:**
  - `poles` — control points in row-major order (must have exactly `uCount * vCount` elements).
  - `uCount` — number of poles in U (must be odd, ≥ 3).
  - `vCount` — number of poles in V (must be odd, ≥ 3).
  - `alphaU` — frequency parameter in U (> 0).
  - `alphaV` — frequency parameter in V (> 0).
- **Returns:** TBezier surface, or `nil` if counts are invalid or even.
- **OCCT:** `OCCTGeomEvalTBezierSurfaceCreate`.
- **Example:**
  ```swift
  var poles = [SIMD3<Double>](repeating: .zero, count: 9)
  // fill 3×3 grid ...
  let s = Surface.tBezier(poles: poles, uCount: 3, vCount: 3, alphaU: 1, alphaV: 1)
  ```

---

### `Surface.ahtBezier(poles:uCount:vCount:algDegreeU:algDegreeV:alphaU:alphaV:betaU:betaV:)`

Creates an Algebraic-Hyperbolic-Trigonometric (AHT) Bezier surface.

```swift
public static func ahtBezier(poles: [SIMD3<Double>], uCount: Int, vCount: Int,
                               algDegreeU: Int, algDegreeV: Int,
                               alphaU: Double, alphaV: Double,
                               betaU: Double, betaV: Double) -> Surface?
```

A tensor-product surface using mixed AHT bases in both U and V. Parameter domain is U, V ∈ `[0, 1]`. Combines algebraic (polynomial), hyperbolic, and trigonometric basis functions.

- **Parameters:**
  - `poles` — control points in row-major order (`uCount * vCount` elements).
  - `uCount`, `vCount` — grid dimensions (≥ 1).
  - `algDegreeU`, `algDegreeV` — algebraic degree in U and V (≥ 0).
  - `alphaU`, `alphaV` — hyperbolic frequency in U and V (≥ 0).
  - `betaU`, `betaV` — trigonometric frequency in U and V (≥ 0).
- **Returns:** AHT Bezier surface, or `nil` on invalid parameters.
- **OCCT:** `OCCTGeomEvalAHTBezierSurfaceCreate`.

---

## v0.115.0: Surface from point grid, normal, curvatures

### `Surface.fromPointGrid(points:uCount:vCount:degMin:degMax:continuity:tolerance:)`

Approximates a BSpline surface through a grid of 3D points.

```swift
public static func fromPointGrid(points: [SIMD3<Double>], uCount: Int, vCount: Int,
                                  degMin: Int = 3, degMax: Int = 8,
                                  continuity: Int = 2, tolerance: Double = 1e-3) -> Surface?
```

Points must be in row-major order: `point[v * uCount + u]`. Uses `GeomAPI_PointsToBSplineSurface` for the fit.

- **Parameters:**
  - `points` — flat array of 3D points in row-major order (must have exactly `uCount * vCount` elements).
  - `uCount` — number of points in U direction.
  - `vCount` — number of points in V direction.
  - `degMin` — minimum BSpline degree (default 3).
  - `degMax` — maximum BSpline degree (default 8).
  - `continuity` — desired continuity, a `ParametricContinuity` raw value (0=C0, 1=C1, 2=C2, 3=C3; default 2). Unlike `approximated(...)`, the point fitter accepts the whole range without failing.
  - `tolerance` — approximation tolerance.
- **Returns:** Fitted BSpline surface, or `nil` if `points.count ≠ uCount * vCount` or fitting fails.
- **OCCT:** `GeomAPI_PointsToBSplineSurface`.
- **Example:**
  ```swift
  // Build a 4×4 grid from a sampled cloud
  var pts = [SIMD3<Double>]()
  for v in 0..<4 { for u in 0..<4 {
      pts.append(SIMD3(Double(u), Double(v), sin(Double(u + v))))
  }}
  if let surf = Surface.fromPointGrid(points: pts, uCount: 4, vCount: 4) {
      let bb = surf.boundingBox
  }
  ```

---

### `normal(u:v:)`

Computes the surface normal at (u, v).

```swift
public func normal(u: Double, v: Double) -> SIMD3<Double>
```

Always returns a vector; where the normal is undefined the result is the zero vector. Prefer the optional-returning `normal(atU:v:)` (from the Evaluation section) when you need to tell "undefined" apart from a genuine result.

Both entry points evaluate the same `GeomLProp_SLProps` normal and gate on the same `IsNormalDefined()` test, so they always agree on *where* the normal exists — they differ only in how the absence is reported (`nil` vs. the zero vector). Before #401 this method hand-rolled `Geom_Surface::D1` plus a cross product against a literal `1e-15` magnitude epsilon, which classified degeneracy differently: arbitrarily close to a cone apex it returned a spurious zero vector for a normal OCCT resolves perfectly well.

A cone apex is a genuine singularity for this test; a sphere pole (`v = ±π/2`) is not — OCCT still resolves the tangent plane there.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Unit surface normal at (u, v), or `SIMD3(0, 0, 0)` where the normal is undefined.
- **OCCT:** `GeomLProp_SLProps::Normal` (via the shared `OCCTSurfaceGetNormal` bridge path).
- **Example:**
  ```swift
  let cone = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
  #expect(simd_length(cone.normal(u: 0, v: 0)) < 1e-12)   // apex: undefined
  #expect(cone.normal(atU: 0, v: 0) == nil)               // ... reported as nil here
  ```

---

### `curvatures(u:v:)`

Computes Gaussian and mean curvature at (u, v).

```swift
public func curvatures(u: Double, v: Double) -> (gaussian: Double, mean: Double)?
```

Equivalent to calling `gaussianCurvature(atU:v:)` and `meanCurvature(atU:v:)` at the same point, for one `GeomLProp_SLProps` evaluation instead of two. All three share that single construction — and therefore its resolution argument, `Precision::Confusion()`, which is what `IsCurvatureDefined()` tests tangent vectors against for nullity. Before #405 this method built its own `GeomLProp_SLProps` with a hardcoded `1e-6`, ten times looser, and could report `(0, 0)` at a point where its two siblings returned a real curvature.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Tuple of Gaussian curvature (K = k_min × k_max) and mean curvature (H = (k_min + k_max) / 2), or `nil` where curvature is undefined. It returned `(0, 0)` there until #595 — which is also a plane's real answer, so the agreement on definedness this method's own contract claims was not one it could express.
- **OCCT:** `GeomLProp_SLProps::GaussianCurvature` and `MeanCurvature` (order 2, `Precision::Confusion()`).
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 5)!
  if let (K, H) = sphere.curvatures(u: 0, v: 0) {
      // K ≈ 0.04 (= 1/25), H ≈ 0.2 (= 1/5)
  }
  sphere.curvatures(u: 0, v: .pi / 2)   // nil — the pole has no curvature
  ```
