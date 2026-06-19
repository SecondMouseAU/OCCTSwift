---
title: Surface — Analytic Types
parent: API Reference
---

# Surface — Analytic Types

These members expose the type-specific properties of the six analytic surface kinds: plane, sphere, torus, cylinder, cone, and swept surface. They are accessed via typed nested structs (e.g. `surface.planeProperties`) and are meaningful only when the underlying `Surface` wraps an OCCT object of that kind — calling them on a mismatched type returns zero/nil silently. See the main `Surface` page for construction methods, evaluation, and operations.

## Topics

- [Geom_Plane Properties](#geom_plane-properties-v01080) · [Geom_SphericalSurface Properties](#geom_sphericalsurface-properties-v01080) · [Geom_ToroidalSurface Properties](#geom_toroidalsurface-properties-v01080) · [Geom_CylindricalSurface Properties](#geom_cylindricalsurface-properties-v01080) · [Geom_ConicalSurface Properties](#geom_conicalsurface-properties-v01080) · [Geom_SweptSurface Properties](#geom_sweptsurface-properties-v01080)

---

## Geom_Plane Properties (v0.108.0)

### `planeProperties`

Returns the plane-specific property accessor for this surface.

```swift
public var planeProperties: PlaneProperties { get }
```

Meaningful only when the surface wraps a `Geom_Plane`. Accessing members on a non-plane surface returns zeroed values or `nil`.

- **Returns:** A `PlaneProperties` value backed by the same internal handle.
- **OCCT:** `Geom_Plane` — accessed via `Handle(Geom_Plane)::DownCast`.
- **Example:**
  ```swift
  if let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
      let pp = surf.planeProperties
  }
  ```

---

### `PlaneProperties.coefficients`

The plane equation coefficients in the form `Ax + By + Cz + D = 0`.

```swift
public var coefficients: (a: Double, b: Double, c: Double, d: Double) { get }
```

The normal vector `(A, B, C)` is unit-length. `D` is the signed distance from the origin to the plane (negative when the origin is on the positive normal side).

- **Returns:** Tuple `(a, b, c, d)` satisfying `Ax + By + Cz + D = 0`. Returns all-zero if the surface is not a `Geom_Plane`.
- **OCCT:** `Geom_Plane::Coefficients`.
- **Example:**
  ```swift
  if let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)) {
      let c = surf.planeProperties.coefficients
      // c.c ≈ 1.0, c.d ≈ -5.0
  }
  ```

---

### `PlaneProperties.uIso(_:)`

A U iso-curve on the plane at the given U parameter.

```swift
public func uIso(_ u: Double) -> Curve3D?
```

On a `Geom_Plane`, a U iso-curve is a line running in the V direction at the specified U coordinate.

- **Parameters:** `u` — U parameter value.
- **Returns:** The iso-curve as a `Curve3D`, or `nil` if the surface is not a plane or the call fails.
- **OCCT:** `Geom_Plane::UIso`.
- **Example:**
  ```swift
  if let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
      if let iso = surf.planeProperties.uIso(2.0) {
          let pt = iso.point(at: 0.0)
      }
  }
  ```

---

### `PlaneProperties.vIso(_:)`

A V iso-curve on the plane at the given V parameter.

```swift
public func vIso(_ v: Double) -> Curve3D?
```

On a `Geom_Plane`, a V iso-curve is a line running in the U direction at the specified V coordinate.

- **Parameters:** `v` — V parameter value.
- **Returns:** The iso-curve as a `Curve3D`, or `nil` if the surface is not a plane or the call fails.
- **OCCT:** `Geom_Plane::VIso`.
- **Example:**
  ```swift
  if let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
      if let iso = surf.planeProperties.vIso(3.0) {
          let pt = iso.point(at: 0.0)
      }
  }
  ```

---

### `PlaneProperties.pln`

The plane's geometric data: origin point and outward normal.

```swift
public var pln: (origin: SIMD3<Double>, normal: SIMD3<Double>) { get }
```

The origin is the plane's location point (`gp_Pln::Location`). The normal is the unit direction of the plane's Z axis (`gp_Pln::Axis::Direction`).

- **Returns:** Tuple `(origin, normal)`. Returns `(.zero, .zero)` if the surface is not a `Geom_Plane`.
- **OCCT:** `Geom_Plane::Pln` → `gp_Pln::Location` + `gp_Pln::Axis::Direction`.
- **Example:**
  ```swift
  if let surf = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 1, 0)) {
      let p = surf.planeProperties.pln
      // p.origin ≈ SIMD3(1, 2, 3), p.normal ≈ SIMD3(0, 1, 0)
  }
  ```

---

## Geom_SphericalSurface Properties (v0.108.0)

### `sphereProperties`

Returns the sphere-specific property accessor for this surface.

```swift
public var sphereProperties: SphereProperties { get }
```

Meaningful only when the surface wraps a `Geom_SphericalSurface`. Members return zero/nil for other surface kinds.

- **Returns:** A `SphereProperties` value backed by the same internal handle.
- **OCCT:** `Geom_SphericalSurface` — accessed via `Handle(Geom_SphericalSurface)::DownCast`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 10) {
      let sp = surf.sphereProperties
  }
  ```

---

### `SphereProperties.radius`

The radius of the sphere.

```swift
public var radius: Double { get }
```

- **Returns:** Radius in model units, or `0` if the surface is not a sphere.
- **OCCT:** `Geom_SphericalSurface::Radius`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 10) {
      let r = surf.sphereProperties.radius  // 10.0
  }
  ```

---

### `SphereProperties.setRadius(_:)`

Mutates the sphere's radius in place.

```swift
@discardableResult
public func setRadius(_ r: Double) -> Bool
```

Modifies the underlying `Geom_SphericalSurface` handle. The change is reflected in all `Surface` values that share this handle.

- **Parameters:** `r` — new radius (must be > 0 per OCCT conventions).
- **Returns:** `true` on success, `false` if the surface is not a sphere or `r` is invalid.
- **OCCT:** `Geom_SphericalSurface::SetRadius`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 5) {
      surf.sphereProperties.setRadius(8)
  }
  ```

---

### `SphereProperties.area`

The total surface area of the sphere (4πr²).

```swift
public var area: Double { get }
```

- **Returns:** Surface area in model units², or `0` if the surface is not a sphere.
- **OCCT:** `Geom_SphericalSurface::Area`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 1) {
      let a = surf.sphereProperties.area  // ≈ 12.566 (4π)
  }
  ```

---

### `SphereProperties.volume`

The volume enclosed by the sphere (4/3 πr³).

```swift
public var volume: Double { get }
```

- **Returns:** Volume in model units³, or `0` if the surface is not a sphere.
- **OCCT:** `Geom_SphericalSurface::Volume`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 1) {
      let v = surf.sphereProperties.volume  // ≈ 4.189 (4π/3)
  }
  ```

---

### `SphereProperties.center`

The centre point of the sphere.

```swift
public var center: SIMD3<Double> { get }
```

- **Returns:** Centre position in model space, or `.zero` if the surface is not a sphere.
- **OCCT:** `Geom_SphericalSurface::Sphere().Location()`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: SIMD3(1, 2, 3), radius: 5) {
      let c = surf.sphereProperties.center  // SIMD3(1, 2, 3)
  }
  ```

---

### `SphereProperties.uIso(_:)`

A U iso-curve on the sphere at the given U parameter.

```swift
public func uIso(_ u: Double) -> Curve3D?
```

On `Geom_SphericalSurface`, U is the longitude angle; a U iso-curve is a meridian circle.

- **Parameters:** `u` — U parameter (longitude angle in radians, range [0, 2π]).
- **Returns:** The iso-curve as a `Curve3D`, or `nil` if the surface is not a sphere or the call fails.
- **OCCT:** `Geom_SphericalSurface::UIso`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 5) {
      if let meridian = surf.sphereProperties.uIso(0) {
          let len = meridian.length
      }
  }
  ```

---

### `SphereProperties.vIso(_:)`

A V iso-curve on the sphere at the given V parameter.

```swift
public func vIso(_ v: Double) -> Curve3D?
```

On `Geom_SphericalSurface`, V is the latitude angle; a V iso-curve is a parallel circle.

- **Parameters:** `v` — V parameter (latitude angle in radians, range [-π/2, π/2]).
- **Returns:** The iso-curve as a `Curve3D`, or `nil` if the surface is not a sphere or the call fails.
- **OCCT:** `Geom_SphericalSurface::VIso`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: .zero, radius: 5) {
      if let equator = surf.sphereProperties.vIso(0) {
          let len = equator.length  // ≈ 31.416 (2π*5)
      }
  }
  ```

---

### `SphereProperties.sphere`

The sphere's geometric data: centre point and radius in a single call.

```swift
public var sphere: (center: SIMD3<Double>, radius: Double) { get }
```

More efficient than reading `center` and `radius` separately when both are needed.

- **Returns:** Tuple `(center, radius)`. Returns `(.zero, 0)` if the surface is not a sphere.
- **OCCT:** `Geom_SphericalSurface::Sphere` → `gp_Sphere::Location` + `gp_Sphere::Radius`.
- **Example:**
  ```swift
  if let surf = Surface.sphere(center: SIMD3(1, 0, 0), radius: 3) {
      let s = surf.sphereProperties.sphere
      // s.center ≈ SIMD3(1, 0, 0), s.radius ≈ 3.0
  }
  ```

---

## Geom_ToroidalSurface Properties (v0.108.0)

### `torusProperties`

Returns the torus-specific property accessor for this surface.

```swift
public var torusProperties: TorusProperties { get }
```

Meaningful only when the surface wraps a `Geom_ToroidalSurface`. Members return zero or `false` for other surface kinds.

- **Returns:** A `TorusProperties` value backed by the same internal handle.
- **OCCT:** `Geom_ToroidalSurface` — accessed via `Handle(Geom_ToroidalSurface)::DownCast`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      let tp = surf.torusProperties
  }
  ```

---

### `TorusProperties.majorRadius`

The major radius of the torus (distance from the torus centre to the tube centre).

```swift
public var majorRadius: Double { get }
```

- **Returns:** Major radius in model units, or `0` if the surface is not a torus.
- **OCCT:** `Geom_ToroidalSurface::MajorRadius`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      let R = surf.torusProperties.majorRadius  // 10.0
  }
  ```

---

### `TorusProperties.minorRadius`

The minor radius of the torus (tube cross-section radius).

```swift
public var minorRadius: Double { get }
```

- **Returns:** Minor radius in model units, or `0` if the surface is not a torus.
- **OCCT:** `Geom_ToroidalSurface::MinorRadius`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      let r = surf.torusProperties.minorRadius  // 2.0
  }
  ```

---

### `TorusProperties.setMajorRadius(_:)`

Mutates the torus major radius in place.

```swift
@discardableResult
public func setMajorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new major radius (must be > 0 and > minor radius per OCCT).
- **Returns:** `true` on success, `false` if the surface is not a torus or the value is invalid.
- **OCCT:** `Geom_ToroidalSurface::SetMajorRadius`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      surf.torusProperties.setMajorRadius(12)
  }
  ```

---

### `TorusProperties.setMinorRadius(_:)`

Mutates the torus minor radius in place.

```swift
@discardableResult
public func setMinorRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new minor radius (must be > 0 and < major radius per OCCT).
- **Returns:** `true` on success, `false` if the surface is not a torus or the value is invalid.
- **OCCT:** `Geom_ToroidalSurface::SetMinorRadius`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      surf.torusProperties.setMinorRadius(3)
  }
  ```

---

### `TorusProperties.area`

The total surface area of the torus (4π²Rr).

```swift
public var area: Double { get }
```

- **Returns:** Surface area in model units², or `0` if the surface is not a torus.
- **OCCT:** `Geom_ToroidalSurface::Area`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      let a = surf.torusProperties.area  // ≈ 789.6 (4π²×10×2)
  }
  ```

---

### `TorusProperties.volume`

The volume enclosed by the torus (2π²Rr²).

```swift
public var volume: Double { get }
```

- **Returns:** Volume in model units³, or `0` if the surface is not a torus.
- **OCCT:** `Geom_ToroidalSurface::Volume`.
- **Example:**
  ```swift
  if let surf = Surface.torus(majorRadius: 10, minorRadius: 2) {
      let v = surf.torusProperties.volume  // ≈ 789.6 (2π²×10×4)
  }
  ```

---

## Geom_CylindricalSurface Properties (v0.108.0)

### `cylinderProperties`

Returns the cylinder-specific property accessor for this surface.

```swift
public var cylinderProperties: CylinderProperties { get }
```

Meaningful only when the surface wraps a `Geom_CylindricalSurface`. Members return zero/nil for other surface kinds.

- **Returns:** A `CylinderProperties` value backed by the same internal handle.
- **OCCT:** `Geom_CylindricalSurface` — accessed via `Handle(Geom_CylindricalSurface)::DownCast`.
- **Example:**
  ```swift
  if let surf = Surface.cylinder(radius: 5, height: 20) {
      let cp = surf.cylinderProperties
  }
  ```

---

### `CylinderProperties.radius`

The radius of the cylindrical surface.

```swift
public var radius: Double { get }
```

- **Returns:** Radius in model units, or `0` if the surface is not a cylinder.
- **OCCT:** `Geom_CylindricalSurface::Radius`.
- **Example:**
  ```swift
  if let surf = Surface.cylinder(radius: 5, height: 20) {
      let r = surf.cylinderProperties.radius  // 5.0
  }
  ```

---

### `CylinderProperties.setRadius(_:)`

Mutates the cylinder's radius in place.

```swift
@discardableResult
public func setRadius(_ r: Double) -> Bool
```

- **Parameters:** `r` — new radius (must be > 0).
- **Returns:** `true` on success, `false` if the surface is not a cylinder or the value is invalid.
- **OCCT:** `Geom_CylindricalSurface::SetRadius`.
- **Example:**
  ```swift
  if let surf = Surface.cylinder(radius: 5, height: 20) {
      surf.cylinderProperties.setRadius(8)
  }
  ```

---

### `CylinderProperties.axis`

The cylinder's axis: a position point on the axis and the axis unit direction.

```swift
public var axis: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

The axis runs through the cylinder centre along the height direction. The position is `gp_Cylinder::Axis().Location()`.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the surface is not a cylinder.
- **OCCT:** `Geom_CylindricalSurface::Cylinder().Axis()` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let surf = Surface.cylinder(radius: 5, height: 20) {
      let ax = surf.cylinderProperties.axis
      // ax.direction ≈ SIMD3(0, 0, 1) for a Z-axis cylinder
  }
  ```

---

### `CylinderProperties.uIso(_:)`

A U iso-curve on the cylindrical surface at the given U parameter.

```swift
public func uIso(_ u: Double) -> Curve3D?
```

On `Geom_CylindricalSurface`, U is the angular parameter; a U iso-curve is a line (generator) running parallel to the cylinder axis.

- **Parameters:** `u` — U parameter (angle in radians, range [0, 2π]).
- **Returns:** The iso-curve (a line) as a `Curve3D`, or `nil` if the surface is not a cylinder or the call fails.
- **OCCT:** `Geom_CylindricalSurface::UIso`.
- **Example:**
  ```swift
  if let surf = Surface.cylinder(radius: 5, height: 20) {
      if let gen = surf.cylinderProperties.uIso(0) {
          // gen is the generator line at angle 0
      }
  }
  ```

---

## Geom_ConicalSurface Properties (v0.108.0)

### `coneProperties`

Returns the cone-specific property accessor for this surface.

```swift
public var coneProperties: ConeProperties { get }
```

Meaningful only when the surface wraps a `Geom_ConicalSurface`. Members return zero for other surface kinds.

- **Returns:** A `ConeProperties` value backed by the same internal handle.
- **OCCT:** `Geom_ConicalSurface` — accessed via `Handle(Geom_ConicalSurface)::DownCast`.
- **Example:**
  ```swift
  if let surf = Surface.cone(semiAngle: .pi / 6, refRadius: 5) {
      let cp = surf.coneProperties
  }
  ```

---

### `ConeProperties.semiAngle`

The semi-angle of the cone (half the apex angle), in radians.

```swift
public var semiAngle: Double { get }
```

A semi-angle of 0 would be a cylinder; π/2 would be a flat disc. For physical cones the value is typically in (0, π/2).

- **Returns:** Semi-angle in radians, or `0` if the surface is not a cone.
- **OCCT:** `Geom_ConicalSurface::SemiAngle`.
- **Example:**
  ```swift
  if let surf = Surface.cone(semiAngle: .pi / 6, refRadius: 5) {
      let a = surf.coneProperties.semiAngle  // ≈ 0.524 (π/6)
  }
  ```

---

### `ConeProperties.refRadius`

The reference radius of the cone at its origin plane.

```swift
public var refRadius: Double { get }
```

This is the radius at the cone's reference position (`gp_Cone::RefRadius`), i.e. at V = 0 in the parametric domain.

- **Returns:** Reference radius in model units, or `0` if the surface is not a cone.
- **OCCT:** `Geom_ConicalSurface::RefRadius`.
- **Example:**
  ```swift
  if let surf = Surface.cone(semiAngle: .pi / 6, refRadius: 5) {
      let r0 = surf.coneProperties.refRadius  // 5.0
  }
  ```

---

### `ConeProperties.apex`

The apex (tip) of the cone.

```swift
public var apex: SIMD3<Double> { get }
```

The apex is where the cone's generator lines converge. For a cone with `refRadius > 0`, the apex is offset from the origin along the cone axis by `refRadius / tan(semiAngle)`.

- **Returns:** Apex position in model space, or `.zero` if the surface is not a cone.
- **OCCT:** `Geom_ConicalSurface::Apex`.
- **Example:**
  ```swift
  if let surf = Surface.cone(semiAngle: .pi / 4, refRadius: 5) {
      let tip = surf.coneProperties.apex
      // tip is 5.0 units along the axis from the reference plane
  }
  ```

---

### `ConeProperties.axis`

The cone's axis: a position point on the axis and the axis unit direction.

```swift
public var axis: (position: SIMD3<Double>, direction: SIMD3<Double>) { get }
```

The axis runs through the apex along the cone's height direction. The position is `gp_Cone::Axis().Location()`.

- **Returns:** Tuple `(position, direction)`. Returns `(.zero, .zero)` if the surface is not a cone.
- **OCCT:** `Geom_ConicalSurface::Cone().Axis()` → `gp_Ax1::Location` + `gp_Ax1::Direction`.
- **Example:**
  ```swift
  if let surf = Surface.cone(semiAngle: .pi / 6, refRadius: 5) {
      let ax = surf.coneProperties.axis
      // ax.direction ≈ SIMD3(0, 0, 1) for a Z-axis cone
  }
  ```

---

## Geom_SweptSurface Properties (v0.108.0)

### `sweptProperties`

Returns the swept-surface-specific property accessor for this surface.

```swift
public var sweptProperties: SweptProperties { get }
```

`Geom_SweptSurface` is the abstract base of `Geom_SurfaceOfLinearExtrusion` and `Geom_SurfaceOfRevolution`. These properties are valid for both subclasses. Members return zero/nil for non-swept surface kinds.

- **Returns:** A `SweptProperties` value backed by the same internal handle.
- **OCCT:** `Geom_SweptSurface` — accessed via `Handle(Geom_SweptSurface)::DownCast`.
- **Example:**
  ```swift
  if let surf = Surface.extrusion(profile: Wire.circle(radius: 3)!, direction: SIMD3(0, 0, 1)) {
      let sp = surf.sweptProperties
  }
  ```

---

### `SweptProperties.direction`

The sweep direction of the surface.

```swift
public var direction: SIMD3<Double> { get }
```

For a `Geom_SurfaceOfLinearExtrusion`, this is the extrusion direction. For `Geom_SurfaceOfRevolution`, this is the revolution axis direction.

- **Returns:** Unit direction vector, or `.zero` if the surface is not a swept surface.
- **OCCT:** `Geom_SweptSurface::Direction`.
- **Example:**
  ```swift
  if let surf = Surface.extrusion(profile: Wire.circle(radius: 3)!, direction: SIMD3(0, 0, 1)) {
      let d = surf.sweptProperties.direction  // ≈ SIMD3(0, 0, 1)
  }
  ```

---

### `SweptProperties.basisCurve`

The basis curve that was swept to create this surface.

```swift
public var basisCurve: Curve3D? { get }
```

For an extrusion, this is the profile curve. For a revolution surface, this is the generating curve rotated around the axis.

- **Returns:** The basis `Curve3D`, or `nil` if the surface is not a swept surface or the curve handle is null.
- **OCCT:** `Geom_SweptSurface::BasisCurve`.
- **Example:**
  ```swift
  if let surf = Surface.extrusion(profile: Wire.circle(radius: 3)!, direction: SIMD3(0, 0, 1)) {
      if let basis = surf.sweptProperties.basisCurve {
          let len = basis.length
      }
  }
  ```
