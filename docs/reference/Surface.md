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

### `Continuity`

Continuity class enum derived from `GeomAbs_Shape`.

```swift
public enum Continuity: Int32, Sendable, CaseIterable {
    case c0 = 0, g1 = 1, c1 = 2, g2 = 3, c2 = 4, c3 = 5, cN = 6
}
```

---

### `continuityClass`

The overall continuity of the surface.

```swift
public var continuityClass: Continuity { get }
```

- **Returns:** A `Continuity` value describing positional through CN continuity.
- **OCCT:** `Geom_Surface::Continuity`.
- **Example:**
  ```swift
  let bsp = Surface.bspline(poles: ..., ...)!
  print(bsp.continuityClass)  // typically .c2
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
- **OCCT:** `GeomLProp_SLProps::Normal`.
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

- **Parameters:** `origin` — a point on the plane; `normal` — outward normal direction.
- **Returns:** `Geom_Plane` surface, or `nil` if `normal` is zero-length.
- **OCCT:** `Geom_Plane(gp_Pnt, gp_Dir)`.
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

## Conversion

### `toBSpline()`

Converts this surface to a BSpline representation.

```swift
public func toBSpline() -> Surface?
```

Uses OCCT's exact conversion for analytic surfaces. Infinite surfaces must be trimmed first. The result is a `Geom_BSplineSurface`.

- **Returns:** BSpline surface, or `nil` if conversion fails (e.g. surface is already a non-convertible type).
- **OCCT:** `GeomConvert::SurfaceToBSplineSurface`.
- **Note:** Infinite surfaces (planes, full cylinders) will cause conversion to fail — trim the domain first with `trimmed(u1:u2:v1:v2:)`.
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
public func approximated(tolerance: Double = 0.01, continuity: Int = 2,
                          maxSegments: Int = 100, maxDegree: Int = 10) -> Surface?
```

Useful when exact `toBSpline()` conversion is unavailable (e.g. offset or composite surfaces).

- **Parameters:**
  - `tolerance` — maximum approximation deviation.
  - `continuity` — desired continuity order (0=C0, 1=C1, 2=C2).
  - `maxSegments` — maximum number of BSpline segments.
  - `maxDegree` — maximum polynomial degree.
- **Returns:** Approximated BSpline surface, or `nil` on failure.
- **OCCT:** `GeomConvert_ApproxSurface`.
- **Example:**
  ```swift
  let offset = sphere.offset(distance: 1)!
  let bsp = offset.approximated(tolerance: 0.001)
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

- **Parameters:** `uLineCount` — number of U iso-lines; `vLineCount` — number of V iso-lines; `pointsPerLine` — points per iso-line.
- **Returns:** Array of polylines (one per iso-line), empty if the surface is null.
- **OCCT:** `Geom_Surface::Bounds` + `Geom_Surface::D0` via `OCCTSurfaceDrawGrid`.
- **Example:**
  ```swift
  let gridLines = surface.drawGrid(uLineCount: 10, vLineCount: 10, pointsPerLine: 50)
  // Pass to Metal vertex buffer for wireframe preview
  ```

---

### `drawMesh(uCount:vCount:)`

Samples a uniform mesh grid of points for Metal visualisation.

```swift
public func drawMesh(uCount: Int = 20, vCount: Int = 20) -> [[SIMD3<Double>]]
```

Returns a 2D array indexed `[uIndex][vIndex]` of evaluated surface points on a uniform UV grid.

- **Parameters:** `uCount` — number of U sample points; `vCount` — number of V sample points.
- **Returns:** 2D array of 3D points, or `[]` if sampling fails.
- **OCCT:** `Geom_Surface::D0` sampled on a uniform UV grid.
- **Example:**
  ```swift
  let mesh = surface.drawMesh(uCount: 30, vCount: 30)
  // mesh[i][j] is the surface point at the ith U and jth V sample
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

---

### `Surface.networkSurface(profiles:guides:tolerance:)`

Builds a surface with the low-level `GeomFill_NetworkSurface` builder.

```swift
public static func networkSurface(profiles: [Curve3D], guides: [Curve3D],
                                   tolerance: Double = 1e-3)
    -> (surface: Surface?, status: NetworkSurfaceStatus)
```

Curves are converted to non-periodic BSplines and an intersection grid is sampled. This is a lower-level alternative to `gordon(...)` for cases requiring manual control over the network construction.

- **Parameters:** `profiles` — profile curves in U, at least 2; `guides` — guide curves in V, at least 2; `tolerance` — geometric tolerance for closed-seam checks.
- **Returns:** Tuple of the surface (or `nil`) and a status code.
- **OCCT:** `OCCTGeomFillNetworkSurface` / `GeomFill_NetworkSurface`.

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
  - `continuity` — desired continuity (0=C0, 1=C1, 2=C2; default 2).
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

Always returns a vector; at singular points the result may be the zero vector. Prefer the optional-returning `normal(atU:v:)` (from the Evaluation section) when singularity detection matters.

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Surface normal vector at (u, v).
- **OCCT:** `GeomLProp_SLProps::Normal`.

---

### `curvatures(u:v:)`

Computes Gaussian and mean curvature at (u, v).

```swift
public func curvatures(u: Double, v: Double) -> (gaussian: Double, mean: Double)
```

- **Parameters:** `u` — U parameter; `v` — V parameter.
- **Returns:** Tuple of Gaussian curvature (K = k_min × k_max) and mean curvature (H = (k_min + k_max) / 2).
- **OCCT:** `GeomLProp_SLProps::GaussianCurvature` and `MeanCurvature`.
- **Example:**
  ```swift
  let sphere = Surface.sphere(center: .zero, radius: 5)!
  let (K, H) = sphere.curvatures(u: 0, v: 0)
  // K ≈ 0.04 (= 1/25), H ≈ 0.2 (= 1/5)
  ```
