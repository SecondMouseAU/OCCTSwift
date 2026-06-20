---
title: Shape
parent: API Reference
---

# Shape

`Shape` is OCCTSwift's central B-Rep type, wrapping OCCT's `TopoDS_Shape` hierarchy. It represents any B-Rep entity — solid, shell, face, wire, edge, vertex, or compound — and provides construction, boolean, modification, transformation, meshing, and format-import operations. Obtain a `Shape` via a static factory (e.g. `Shape.box()`, `Shape.loft()`), a sweep or boolean operation on an existing `Shape`, or by importing a STEP/IGES/BREP/STL/OBJ file.

> **Note:** `Shape` is large — documented across several pages. This is the core (construction, booleans, modifications, meshing, import); see also the other **Shape — …** pages for features, healing, measurement, local operations, and the low-level OCCT builder wrappers.

## Topics

- [Lifecycle](#lifecycle) · [Primitive Creation](#primitive-creation) · [Sweep Operations](#sweep-operations) · [Boolean Operations](#boolean-operations) · [Modifications](#modifications) · [Transformations](#transformations) · [Compound Operations](#compound-operations) · [Conversion](#conversion) · [Validation](#validation) · [Meshing](#meshing) · [Edge Discretization](#edge-discretization) · [Import](#import) · [STEP Reader Control](#step-reader-control) · [Robust STEP Import](#robust-step-import) · [IGES Import](#iges-import) · [IGES Reader Control](#iges-reader-control) · [BREP Import](#brep-import) · [STL Import](#stl-import) · [OBJ Import](#obj-import)

---

## Lifecycle

### `init(handle:)`

Internal designated initialiser; takes ownership of a bridge handle.

```swift
internal init(handle: OCCTShapeRef)
```

Not part of the public API — all public entry points return `Shape?` optionals and manage memory internally.

---

### `deinit`

Releases the underlying OCCT shape handle.

```swift
deinit
```

- **OCCT:** `OCCTShapeRelease` → `TopoDS_Shape` reference count decremented.

---

## Primitive Creation

### `Shape.box(width:height:depth:)`

Create a box centered at the origin.

```swift
public static func box(width: Double, height: Double, depth: Double) -> Shape?
```

- **Parameters:** `width`, `height`, `depth` — extents along X, Y, Z respectively.
- **Returns:** A solid box, or `nil` if any dimension is non-positive.
- **OCCT:** `BRepPrimAPI_MakeBox`.
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 5, depth: 3) {
      // box.isValid == true
  }
  ```

---

### `Shape.box(origin:width:height:depth:)`

Create a box at a specific position.

```swift
public static func box(
    origin: SIMD3<Double>,
    width: Double,
    height: Double,
    depth: Double
) -> Shape?
```

- **Parameters:** `origin` — corner point of the box; `width`, `height`, `depth` — extents along X, Y, Z.
- **Returns:** A solid box at the given position, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeBox`.
- **Example:**
  ```swift
  if let box = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10) {
      // volume == 1000
  }
  ```

---

### `Shape.box(at:direction:width:height:depth:)`

Create a box at an arbitrary origin along an arbitrary direction.

```swift
public static func box(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    width: Double,
    height: Double,
    depth: Double
) -> Shape?
```

- **Parameters:**
  - `origin` — corner point of the box.
  - `direction` — axis direction for the box height (will be normalised).
  - `width` — X extent in local frame.
  - `height` — Y extent in local frame.
  - `depth` — extent along `direction`.
- **Returns:** Oriented solid box, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeBox` (via `OCCTShapeCreateBoxOriented`).
- **Example:**
  ```swift
  if let box = Shape.box(at: .zero, direction: SIMD3(0, 0, 1), width: 4, height: 4, depth: 10) {
      // box tilted along Z
  }
  ```

---

### `Shape.cylinder(radius:height:)`

Create a cylinder along the Z axis with base at the origin.

```swift
public static func cylinder(radius: Double, height: Double) -> Shape?
```

- **Parameters:** `radius` — base circle radius; `height` — height along Z.
- **Returns:** A solid cylinder, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCylinder`.
- **Example:**
  ```swift
  if let cyl = Shape.cylinder(radius: 2, height: 10) {
      // volume ≈ 125.66
  }
  ```

---

### `Shape.cylinder(at:bottomZ:radius:height:)`

Create a cylinder at a specific XY position with a specified Z base.

```swift
public static func cylinder(
    at position: SIMD2<Double>,
    bottomZ: Double,
    radius: Double,
    height: Double
) -> Shape?
```

- **Parameters:** `position` — XY centre of base circle; `bottomZ` — Z coordinate of base; `radius`, `height`.
- **Returns:** Positioned cylinder, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCylinder` (via `OCCTShapeCreateCylinderAt`).
- **Example:**
  ```swift
  if let cyl = Shape.cylinder(at: SIMD2(3, 4), bottomZ: 0, radius: 1.5, height: 8) { }
  ```

---

### `Shape.cylinder(at:direction:radius:height:)`

Create a cylinder at an arbitrary origin along an arbitrary direction.

```swift
public static func cylinder(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    radius: Double,
    height: Double
) -> Shape?
```

- **Parameters:**
  - `origin` — centre of the base circle.
  - `direction` — axis direction (will be normalised).
  - `radius` — cylinder radius.
  - `height` — height along `direction`.
- **Returns:** Oriented cylinder, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCylinder` (via `OCCTShapeCreateCylinderOriented`).
- **Example:**
  ```swift
  guard let cyl = Shape.cylinder(at: SIMD3(0, 0, -8),
                                 direction: SIMD3(0, 0, 1),
                                 radius: 3, height: 16) else { return }
  ```

---

### `Shape.cylinder(radius:height:angle:)`

Create a partial cylinder (angular segment) along the Z axis.

```swift
public static func cylinder(radius: Double, height: Double, angle: Double) -> Shape?
```

- **Parameters:** `radius`, `height`; `angle` — angular extent in radians (`0 < angle <= 2*pi`).
- **Returns:** Partial cylinder sector, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCylinder` (via `OCCTShapeCreateCylinderPartial`).
- **Example:**
  ```swift
  if let half = Shape.cylinder(radius: 5, height: 10, angle: .pi) { }
  ```

---

### `Shape.cylinder(at:direction:radius:height:angle:)`

Create a partial cylinder (angular segment) at an arbitrary origin along an arbitrary direction.

```swift
public static func cylinder(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    radius: Double,
    height: Double,
    angle: Double
) -> Shape?
```

- **Parameters:** `origin`, `direction`, `radius`, `height`, `angle` — angular extent in radians (`0 < angle <= 2*pi`).
- **Returns:** Oriented partial cylinder, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCylinder` (via `OCCTShapeCreateCylinderOrientedPartial`).

---

### `Shape.toolSweep(radius:height:from:to:)`

Create a tool-sweep solid — the volume swept by a cylindrical tool moving between two points.

```swift
public static func toolSweep(
    radius: Double,
    height: Double,
    from start: SIMD3<Double>,
    to end: SIMD3<Double>
) -> Shape?
```

Used for CAM simulation to compute material removal volumes.

- **Parameters:** `radius`, `height` — tool dimensions; `start`, `end` — tool centre path.
- **Returns:** Swept solid volume, or `nil` on failure.
- **OCCT:** `OCCTShapeCreateToolSweep`.
- **Example:**
  ```swift
  if let sweep = Shape.toolSweep(radius: 2, height: 5,
                                 from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) { }
  ```

---

### `Shape.sphere(radius:)`

Create a sphere centred at the origin.

```swift
public static func sphere(radius: Double) -> Shape?
```

- **Parameters:** `radius` — sphere radius.
- **Returns:** Solid sphere, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeSphere`.
- **Example:**
  ```swift
  if let ball = Shape.sphere(radius: 5) {
      // volume ≈ 523.6
  }
  ```

---

### `Shape.sphere(center:radius:)`

Create a sphere at a specific centre point.

```swift
public static func sphere(center: SIMD3<Double>, radius: Double) -> Shape?
```

- **Parameters:** `center` — centre of the sphere; `radius`.
- **Returns:** Positioned sphere, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeSphere` (via `OCCTShapeCreateSphereAtCenter`).
- **Example:**
  ```swift
  if let ball = Shape.sphere(center: SIMD3(0, 0, 10), radius: 3) { }
  ```

---

### `Shape.sphere(at:direction:radius:)`

Create an oriented sphere at an arbitrary origin along an arbitrary direction.

```swift
public static func sphere(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    radius: Double
) -> Shape?
```

- **Parameters:** `origin` — centre; `direction` — axis direction (affects parameterisation); `radius`.
- **Returns:** Oriented sphere, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeSphere` (via `OCCTShapeCreateSphereOriented`).

---

### `Shape.sphere(radius:angle:)`

Create a partial sphere (angular segment).

```swift
public static func sphere(radius: Double, angle: Double) -> Shape?
```

- **Parameters:** `radius`; `angle` — angular extent in radians (`0 < angle <= 2*pi`).
- **Returns:** Sphere sector, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeSphere` (via `OCCTShapeCreateSpherePartial`).

---

### `Shape.sphere(at:direction:radius:angle:)`

Create a partial sphere (angular segment) at an arbitrary origin along an arbitrary direction.

```swift
public static func sphere(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    radius: Double,
    angle: Double
) -> Shape?
```

- **Parameters:** `origin`, `direction`, `radius`, `angle` — angular extent in radians.
- **Returns:** Oriented sphere sector, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeSphere` (via `OCCTShapeCreateSphereOrientedPartial`).

---

### `Shape.sphere(at:direction:radius:angle1:angle2:)`

Create a sphere latitude segment at an arbitrary origin along an arbitrary direction.

```swift
public static func sphere(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    radius: Double,
    angle1: Double,
    angle2: Double
) -> Shape?
```

- **Parameters:**
  - `origin` — centre of the sphere.
  - `direction` — axis direction (affects parameterisation).
  - `radius` — sphere radius.
  - `angle1` — lower latitude bound in radians (−π/2 to π/2).
  - `angle2` — upper latitude bound in radians (−π/2 to π/2).
- **Returns:** Latitude-band sphere segment, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeSphere` (via `OCCTShapeCreateSphereOrientedSegment`).

---

### `Shape.cone(bottomRadius:topRadius:height:)`

Create a cone along the Z axis.

```swift
public static func cone(bottomRadius: Double, topRadius: Double, height: Double) -> Shape?
```

- **Parameters:** `bottomRadius` — radius at the base; `topRadius` — radius at the top (0 = true cone); `height`.
- **Returns:** Solid cone or frustum, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCone`.
- **Example:**
  ```swift
  if let cone = Shape.cone(bottomRadius: 5, topRadius: 0, height: 10) { }
  if let frustum = Shape.cone(bottomRadius: 5, topRadius: 3, height: 8) { }
  ```

---

### `Shape.cone(at:direction:bottomRadius:topRadius:height:)`

Create a cone at an arbitrary origin along an arbitrary direction.

```swift
public static func cone(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    bottomRadius: Double,
    topRadius: Double,
    height: Double
) -> Shape?
```

- **Parameters:** `origin` — centre of the base circle; `direction` — axis (will be normalised); `bottomRadius`, `topRadius`, `height`.
- **Returns:** Oriented cone/frustum, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCone` (via `OCCTShapeCreateConeOriented`).

---

### `Shape.cone(at:direction:bottomRadius:topRadius:height:angle:)`

Create a partial cone (angular segment) at an arbitrary origin along an arbitrary direction.

```swift
public static func cone(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    bottomRadius: Double,
    topRadius: Double,
    height: Double,
    angle: Double
) -> Shape?
```

- **Parameters:** `origin`, `direction`, `bottomRadius`, `topRadius`, `height`; `angle` — angular extent in radians (`0 < angle <= 2*pi`).
- **Returns:** Oriented cone sector, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeCone` (via `OCCTShapeCreateConeOrientedPartial`).

---

### `Shape.torus(majorRadius:minorRadius:)`

Create a torus in the XY plane.

```swift
public static func torus(majorRadius: Double, minorRadius: Double) -> Shape?
```

- **Parameters:** `majorRadius` — distance from torus centre to tube centre; `minorRadius` — tube radius.
- **Returns:** Solid torus, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeTorus`.
- **Example:**
  ```swift
  if let ring = Shape.torus(majorRadius: 10, minorRadius: 2) { }
  ```

---

### `Shape.torus(at:direction:majorRadius:minorRadius:)`

Create a torus at an arbitrary origin along an arbitrary direction.

```swift
public static func torus(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double
) -> Shape?
```

- **Parameters:** `origin` — centre of the torus; `direction` — normal to the torus plane; `majorRadius`, `minorRadius`.
- **Returns:** Oriented torus, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeTorus` (via `OCCTShapeCreateTorusOriented`).

---

### `Shape.torus(at:direction:majorRadius:minorRadius:angle:)`

Create a partial torus (angular segment) at an arbitrary origin along an arbitrary direction.

```swift
public static func torus(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double,
    angle: Double
) -> Shape?
```

- **Parameters:** `origin`, `direction`, `majorRadius`, `minorRadius`; `angle` — angular extent in radians (`0 < angle <= 2*pi`).
- **Returns:** Oriented torus sector, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeTorus` (via `OCCTShapeCreateTorusOrientedPartial`).

---

### `Shape.torus(at:direction:majorRadius:minorRadius:angle1:angle2:)`

Create a torus tube segment at an arbitrary origin along an arbitrary direction.

```swift
public static func torus(
    at origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double,
    angle1: Double,
    angle2: Double
) -> Shape?
```

- **Parameters:**
  - `origin` — centre of the torus.
  - `direction` — axis direction (normal to torus plane).
  - `majorRadius`, `minorRadius`.
  - `angle1` — start angle of the tube section in radians.
  - `angle2` — end angle of the tube section in radians.
- **Returns:** Tube-segment torus, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeTorus` (via `OCCTShapeCreateTorusOrientedSegment`).

---

## Sweep Operations

### `Shape.sweep(profile:along:)`

Sweep a 2D profile wire along a path wire to create a solid.

```swift
public static func sweep(profile: Wire, along path: Wire) -> Shape?
```

The result is orientation-normalised so its faces always point outward (positive volume), regardless of how the profile's normal relates to the path tangent. You do not need to manually orient the section against the tangent.

- **Parameters:** `profile` — closed cross-section wire placed at the path's start; `path` — spine wire.
- **Returns:** Swept solid, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipe`.
- **Example:**
  ```swift
  guard let section = Wire.circle(origin: SIMD3(16, 0, 0),
                                  normal: SIMD3(0, 1, 0), radius: 5),
        let path = Wire.arc(center: .zero, radius: 16,
                            startAngle: 0, endAngle: .pi / 2),
        let elbow = Shape.sweep(profile: section, along: path) else { return }
  // elbow.isValid == true
  ```

---

### `Shape.extrude(profile:direction:length:)`

Extrude a 2D profile wire in a direction to create a prism.

```swift
public static func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> Shape?
```

- **Parameters:** `profile` — closed profile wire; `direction` — extrusion direction (need not be unit length); `length` — extrusion distance.
- **Returns:** Solid prism, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakePrism`.
- **Example:**
  ```swift
  guard let profile = Wire.rectangle(width: 20, height: 12),
        let prism = Shape.extrude(profile: profile,
                                  direction: SIMD3(0, 0, 1), length: 8) else { return }
  // prism.volume == 20 * 12 * 8 == 1920
  ```

---

### `Shape.revolve(profile:axisOrigin:axisDirection:angle:)`

Revolve a 2D profile wire around an axis.

```swift
public static func revolve(
    profile: Wire,
    axisOrigin: SIMD3<Double>,
    axisDirection: SIMD3<Double>,
    angle: Double = .pi * 2
) -> Shape?
```

- **Parameters:**
  - `profile` — meridian wire in a plane containing the axis.
  - `axisOrigin` — a point on the revolution axis.
  - `axisDirection` — axis direction vector.
  - `angle` — sweep angle in radians (default full 2π).
- **Returns:** Revolution solid, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeRevol`.
- **Example:**
  ```swift
  guard let meridian = Wire.polygon([
      SIMD2(5, 0), SIMD2(7, 0), SIMD2(7, 10), SIMD2(5, 10)
  ], closed: true),
        let drum = Shape.revolve(profile: meridian,
                                 axisOrigin: .zero,
                                 axisDirection: SIMD3(0, 1, 0),
                                 angle: 2 * .pi) else { return }
  ```

---

### `extruded(by:)`

Extrude an existing shape (any topology) along a vector.

```swift
public func extruded(by vector: SIMD3<Double>) -> Shape?
```

- **Parameters:** `vector` — translation vector; its magnitude determines the extrusion distance.
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakePrism` (via `OCCTShapeCreateExtrusionShape`).
- **Example:**
  ```swift
  if let solid = face.extruded(by: SIMD3(0, 0, 5)) { }
  ```

---

### `extrudedInfinite(direction:infinite:)`

Extrude an existing shape to infinity (or semi-infinity) along a direction.

```swift
public func extrudedInfinite(direction: SIMD3<Double>, infinite: Bool = true) -> Shape?
```

Useful for half-space cutters in booleans (e.g. slice a solid).

- **Parameters:** `direction` — extrusion direction; `infinite` — if `true`, both directions; if `false`, semi-infinite.
- **Returns:** Infinite-extent shape (shell), or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakePrism` (via `OCCTShapeCreateExtrusionInfinite`).
- **Example:**
  ```swift
  // Cut anything above z = 0 from a solid
  guard let plane = Shape.face(from: Wire.rectangle(width: 200, height: 200)!),
        let halfSpace = plane.extrudedInfinite(direction: SIMD3(0, 0, 1)),
        let trimmed = solid.subtracting(halfSpace) else { return }
  ```

---

### `revolved(axisOrigin:axisDirection:)`

Revolve an existing shape around an axis by a full 360 degrees.

```swift
public func revolved(
    axisOrigin: SIMD3<Double>,
    axisDirection: SIMD3<Double>
) -> Shape?
```

- **Parameters:** `axisOrigin` — point on revolution axis; `axisDirection` — axis direction.
- **Returns:** Revolution solid, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeRevol` (via `OCCTShapeCreateRevolutionFull`).

---

### `revolved(axisOrigin:axisDirection:angle:)`

Revolve an existing shape around an axis by a partial angle.

```swift
public func revolved(
    axisOrigin: SIMD3<Double>,
    axisDirection: SIMD3<Double>,
    angle: Double
) -> Shape?
```

- **Parameters:** `axisOrigin`, `axisDirection`; `angle` — sweep angle in radians.
- **Returns:** Partial revolution solid, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeRevol` (via `OCCTShapeCreateRevolutionPartial`).

---

### `Shape.loft(profiles:solid:)`

Loft through multiple profile wires.

```swift
public static func loft(profiles: [Wire], solid: Bool = true) -> Shape?
```

- **Parameters:** `profiles` — ordered array of profile wires; `solid` — `true` (default) creates a closed solid, `false` creates an open shell.
- **Returns:** Lofted shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_ThruSections`.
- **Note:** Mismatched closed/open profiles can trigger a SIGSEGV in `BRepFill_CompatibleWires` when using smooth (non-ruled) lofts — see the CLAUDE.md note on this known upstream bug and the patch in `Scripts/patches/`.
- **Example:**
  ```swift
  guard let base = Wire.circle(radius: 5),
        let top = Wire.circle(origin: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1), radius: 2),
        let transition = Shape.loft(profiles: [base, top], solid: true) else { return }
  ```

---

### `Shape.loft(profiles:solid:ruled:firstVertex:lastVertex:)`

Loft through profile wires with advanced options.

```swift
public static func loft(profiles: [Wire], solid: Bool = true, ruled: Bool,
                        firstVertex: SIMD3<Double>? = nil,
                        lastVertex: SIMD3<Double>? = nil) -> Shape?
```

- **Parameters:**
  - `profiles` — ordered profile wires.
  - `solid` — solid vs shell.
  - `ruled` — `true` = ruled (flat/faceted) surfaces between profiles; `false` = smooth B-spline blend.
  - `firstVertex` — optional starting tip point for cone/taper shapes.
  - `lastVertex` — optional ending tip point for cone/taper shapes.
- **Returns:** Lofted shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_ThruSections` (via `OCCTShapeCreateLoftAdvanced`).
- **Example:**
  ```swift
  // Ruled loft (flat sides)
  let ruled = Shape.loft(profiles: [bottom, upper], solid: true, ruled: true)
  // Smooth loft
  let smooth = Shape.loft(profiles: [bottom, upper], solid: true, ruled: false)

  // Taper to a point (cone tip)
  guard let circle = Wire.circle(radius: 5) else { return }
  let cone = Shape.loft(profiles: [circle], solid: true, ruled: true,
                        lastVertex: SIMD3(0, 0, 10))
  ```

---

## Boolean Operations

### `BooleanGlue`

Glue mode enum for boolean operations (`BOPAlgo_GlueEnum`).

```swift
public enum BooleanGlue: Int32, Sendable {
    case off   = 0  // No gluing — full intersection (default)
    case shift = 1  // BOPAlgo_GlueShift — coincident but otherwise disjoint faces
    case full  = 2  // BOPAlgo_GlueFull  — all faces coincident (fastest, strictest)
}
```

Gluing speeds up booleans when arguments share coincident faces. Only use when faces truly coincide — gluing genuinely interpenetrating solids produces a wrong result.

---

### `defaultBooleanTimeout`

Default wall-clock timeout for boolean operations, in seconds.

```swift
public static let defaultBooleanTimeout: Double = 120
```

A self-intersecting or inside-out operand (e.g. from `loft(ruled: false)`) can make `BRepAlgoAPI_Cut` spin indefinitely; boolean operations abort and return `nil` once this elapses. Pass `0` or negative to disable. Override per call via the `timeout:` parameter.

---

### `union(_:fuzzyValue:glue:timeout:)`

Union (fuse) two shapes together.

```swift
public func union(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
                  timeout: Double = Shape.defaultBooleanTimeout) -> Shape?
```

Also available as the `+` operator.

- **Parameters:**
  - `other` — the shape to fuse with `self`.
  - `fuzzyValue` — tolerance (`SetFuzzyValue`). `0` = OCCT default; a small positive value (e.g. `1e-4`) helps near-tangent/coincident faces fuse cleanly. Negative = ignored.
  - `glue` — glue mode for coincident-face arguments.
  - `timeout` — wall-clock bound in seconds; `nil` result if elapsed.
- **Returns:** Fused solid, or `nil` on failure or timeout.
- **OCCT:** `BRepAlgoAPI_Fuse` (via `OCCTShapeUnionEx`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 10, height: 10, depth: 10),
        let cyl = Shape.cylinder(at: SIMD3(0, 0, -8), direction: SIMD3(0, 0, 1),
                                 radius: 3, height: 16) else { return }
  let fused = box.union(cyl)           // or: box + cyl
  // Fuzzy: near-tangent walls fuse cleanly
  let clean = outer.union(inner, fuzzyValue: 2.1e-5)
  // Glue: stacked blocks sharing a face
  let stacked = lower.union(upper, glue: .shift)
  ```
- **Note:** The deprecated `union(with:)` overload is available for compatibility; prefer `union(_:)`.

---

### `union(with:)` *(deprecated)*

```swift
@available(*, deprecated, renamed: "union(_:)", ...)
public func union(with other: Shape) -> Shape? { union(other) }
```

Renamed to `union(_:)`. Use `union(_:fuzzyValue:glue:timeout:)` instead.

---

### `subtracting(_:fuzzyValue:glue:timeout:)`

Subtract another shape from this one.

```swift
public func subtracting(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
                        timeout: Double = Shape.defaultBooleanTimeout) -> Shape?
```

Also available as the `-` operator.

- **Parameters:**
  - `other` — the tool shape to remove from `self`.
  - `fuzzyValue` — tolerance. Raise slightly when a thin-wall cut under-subtracts.
  - `glue` — glue mode.
  - `timeout` — wall-clock bound in seconds.
- **Returns:** Result of `self − other`, or `nil` on failure or timeout.
- **OCCT:** `BRepAlgoAPI_Cut` (via `OCCTShapeSubtractEx`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 10, height: 10, depth: 10),
        let cyl = Shape.cylinder(at: SIMD3(0, 0, -8), direction: SIMD3(0, 0, 1),
                                 radius: 3, height: 16) else { return }
  let drilled = box.subtracting(cyl)   // or: box - cyl
  ```

---

### `intersection(_:fuzzyValue:glue:timeout:)`

Intersection of two shapes.

```swift
public func intersection(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
                         timeout: Double = Shape.defaultBooleanTimeout) -> Shape?
```

Also available as the `&` operator.

- **Parameters:**
  - `other` — the shape to intersect with `self`.
  - `fuzzyValue` — tolerance.
  - `glue` — glue mode.
  - `timeout` — wall-clock bound in seconds.
- **Returns:** The volume common to both shapes, or `nil` on failure or timeout.
- **OCCT:** `BRepAlgoAPI_Common` (via `OCCTShapeIntersectEx`).
- **Example:**
  ```swift
  let common = box.intersection(cyl)  // or: box & cyl
  ```
- **Note:** The deprecated `intersection(with:)` overload is available for compatibility; prefer `intersection(_:)`.

---

### `intersection(with:)` *(deprecated)*

```swift
@available(*, deprecated, renamed: "intersection(_:)", ...)
public func intersection(with other: Shape) -> Shape? { intersection(other) }
```

Renamed to `intersection(_:)`. Use `intersection(_:fuzzyValue:glue:timeout:)` instead.

---

## Modifications

### `filleted(radius:)`

Fillet (round) all edges with a given radius.

```swift
public func filleted(radius: Double) -> Shape?
```

- **Parameters:** `radius` — fillet radius.
- **Returns:** Shape with all edges rounded, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet`.
- **Example:**
  ```swift
  if let rounded = Shape.box(width: 10, height: 10, depth: 10)?.filleted(radius: 1) { }
  ```

---

### `chamfered(distance:)`

Chamfer all edges with a given distance.

```swift
public func chamfered(distance: Double) -> Shape?
```

- **Parameters:** `distance` — chamfer distance (equal on both sides).
- **Returns:** Shape with all edges chamfered, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeChamfer`.
- **Example:**
  ```swift
  if let bevelled = Shape.box(width: 10, height: 10, depth: 10)?.chamfered(distance: 0.5) { }
  ```

---

### `chamferedTwoDistances(_:)`

Chamfer specific edges with two different distances (asymmetric).

```swift
public func chamferedTwoDistances(_ edges: [(edgeIndex: Int, faceIndex: Int, dist1: Double, dist2: Double)]) -> Shape?
```

Each entry specifies an edge, a reference face adjacent to that edge, and two distances. `dist1` is measured on the reference face side, `dist2` on the opposite side.

- **Parameters:** `edges` — array of `(edgeIndex, faceIndex, dist1, dist2)` tuples.
- **Returns:** Chamfered shape, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeChamfer` (via `OCCTShapeChamferTwoDistances`).
- **Example:**
  ```swift
  if let c = box.chamferedTwoDistances([(edgeIndex: 0, faceIndex: 0, dist1: 1.0, dist2: 2.0)]) { }
  ```

---

### `chamferedDistAngle(_:)`

Chamfer specific edges with a distance and angle.

```swift
public func chamferedDistAngle(_ edges: [(edgeIndex: Int, faceIndex: Int, distance: Double, angleDegrees: Double)]) -> Shape?
```

Each entry specifies an edge, a reference face adjacent to that edge, a distance measured on the reference face, and a chamfer angle in degrees (must be between 0 and 90, exclusive).

- **Parameters:** `edges` — array of `(edgeIndex, faceIndex, distance, angleDegrees)` tuples.
- **Returns:** Chamfered shape, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeChamfer` (via `OCCTShapeChamferDistAngle`).

---

### `shelled(thickness:)`

Create a hollow shell by removing material from the inside.

```swift
public func shelled(thickness: Double) -> Shape?
```

- **Parameters:** `thickness` — wall thickness (positive = shell walls of this thickness).
- **Returns:** Hollow shell, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid`.
- **Example:**
  ```swift
  if let shell = Shape.box(width: 10, height: 10, depth: 10)?.shelled(thickness: 1) { }
  ```

---

### `offset(by:)` *(simple)*

Offset all faces by a distance.

```swift
public func offset(by distance: Double) -> Shape?
```

- **Parameters:** `distance` — offset distance (positive = outward, negative = inward).
- **Returns:** Offset shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeOffsetShape` (via `OCCTShapeOffset`).
- **Example:**
  ```swift
  if let grown = box.offset(by: 1.0) { }
  ```

---

### `offset(by:tolerance:joinType:removeInternalEdges:)`

Offset all faces using the proper join algorithm (`PerformByJoin`).

```swift
public func offset(by distance: Double, tolerance: Double = 1e-7,
                   joinType: OffsetJoinType = .arc,
                   removeInternalEdges: Bool = false) -> Shape?
```

More robust than the simple `offset(by:)` overload; handles gap-filling between parallel faces.

- **Parameters:**
  - `distance` — offset distance (positive = outward, negative = inward).
  - `tolerance` — coincidence tolerance (default `1e-7`).
  - `joinType` — how to fill gaps between offset faces: `.arc` (smooth), `.tangent`, or `.intersection` (sharp).
  - `removeInternalEdges` — whether to clean up internal edges.
- **Returns:** Offset shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeOffsetShape::PerformByJoin` (via `OCCTShapeOffsetByJoin`).
- **Example:**
  ```swift
  if let grown = box.offset(by: 1.0, joinType: .intersection) { }
  ```

---

## Transformations

### `translated(by:)`

Translate the shape.

```swift
public func translated(by offset: SIMD3<Double>) -> Shape?
```

- **Parameters:** `offset` — translation vector.
- **Returns:** Translated shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Transform` (via `OCCTShapeTranslate`).
- **Example:**
  ```swift
  if let moved = box.translated(by: SIMD3(5, 0, 0)) { }
  ```

---

### `rotated(axis:angle:)`

Rotate the shape around an axis through the origin.

```swift
public func rotated(axis: SIMD3<Double>, angle: Double) -> Shape?
```

- **Parameters:** `axis` — rotation axis vector (need not be unit length); `angle` — angle in radians.
- **Returns:** Rotated shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Transform` / `gp_Trsf` (via `OCCTShapeRotate`).
- **Example:**
  ```swift
  if let tilted = box.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4) { }
  ```

---

### `scaled(by:)`

Scale the shape uniformly from the origin.

```swift
public func scaled(by factor: Double) -> Shape?
```

- **Parameters:** `factor` — uniform scale factor.
- **Returns:** Scaled shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Transform` / `gp_Trsf` (via `OCCTShapeScale`).
- **Example:**
  ```swift
  if let big = box.scaled(by: 2.0) { }
  ```

---

### `mirrored(planeNormal:planeOrigin:)`

Mirror the shape across a plane.

```swift
public func mirrored(planeNormal: SIMD3<Double>, planeOrigin: SIMD3<Double> = .zero) -> Shape?
```

- **Parameters:** `planeNormal` — normal of the mirror plane; `planeOrigin` — point on the mirror plane (default origin).
- **Returns:** Mirrored shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Transform` / `gp_Trsf` (via `OCCTShapeMirror`).
- **Example:**
  ```swift
  // Mirror a shape across the XZ plane (normal = +Y)
  if let reflected = part.mirrored(planeNormal: SIMD3(0, 1, 0)) { }
  ```

---

## Compound Operations

### `Shape.compound(_:)`

Combine multiple shapes into a compound (grouping only — no boolean merge).

```swift
public static func compound(_ shapes: [Shape]) -> Shape?
```

- **Parameters:** `shapes` — array of shapes to group.
- **Returns:** A `TopoDS_Compound` holding all shapes, or `nil` if the array is empty or creation fails.
- **OCCT:** `BRep_Builder::MakeCompound` / `BRep_Builder::Add` (via `OCCTShapeCreateCompound`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 10, height: 5, depth: 3),
        let cyl = Shape.cylinder(radius: 2, height: 8) else { return }
  if let group = Shape.compound([box, cyl]) {
      // group.isValid == true; shapes remain separate
  }
  ```

---

## Conversion

### `Shape.fromWire(_:)`

Wrap a `Wire` as a `Shape` to access edge extraction and other Shape methods.

```swift
public static func fromWire(_ wire: Wire) -> Shape?
```

Since `TopoDS_Wire` inherits from `TopoDS_Shape` in OCCT, this is a lightweight conversion that enables using Shape methods (e.g. `allEdgePolylines()`) on wire geometry without creating solid geometry.

- **Parameters:** `wire` — the wire to wrap.
- **Returns:** A `Shape` wrapping the wire, or `nil` on failure.
- **OCCT:** `TopoDS` shape-type promotion (via `OCCTShapeFromWire`).
- **Example:**
  ```swift
  if let wireAsShape = Shape.fromWire(myWire) {
      let polylines = wireAsShape.allEdgePolylines()
  }
  ```

---

### `Shape.fromEdge(_:)`

Wrap an `Edge` as a `Shape` to use it with Shape-based APIs.

```swift
public static func fromEdge(_ edge: Edge) -> Shape?
```

Since `TopoDS_Edge` inherits from `TopoDS_Shape` in OCCT, this is a lightweight conversion.

- **Parameters:** `edge` — the edge to wrap.
- **Returns:** A `Shape` wrapping the edge, or `nil` on failure.
- **OCCT:** `TopoDS` shape-type promotion (via `OCCTShapeFromEdge`).

---

### `Shape.fromFace(_:)`

Wrap a `Face` as a `Shape` to use it with Shape-based APIs.

```swift
public static func fromFace(_ face: Face) -> Shape?
```

Since `TopoDS_Face` inherits from `TopoDS_Shape` in OCCT, this is a lightweight conversion.

- **Parameters:** `face` — the face to wrap.
- **Returns:** A `Shape` wrapping the face, or `nil` on failure.
- **OCCT:** `TopoDS` shape-type promotion (via `OCCTShapeFromFace`).

---

## Validation

### `isValid`

Check if the shape is topologically and geometrically valid.

```swift
public var isValid: Bool { get }
```

- **Returns:** `true` if the shape passes OCCT's checker; `false` otherwise.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTShapeIsValid`).
- **Example:**
  ```swift
  guard let box = Shape.box(width: 10, height: 10, depth: 10),
        box.isValid else { return }
  ```

---

### `healed()`

Attempt to repair and heal the shape.

```swift
public func healed() -> Shape?
```

- **Returns:** A healed shape, or `nil` if healing fails entirely.
- **OCCT:** `ShapeFix_Shape` (via `OCCTShapeHeal`).
- **Note:** Healing fixes common issues (gaps, bad tolerances, degenerate edges) but cannot repair fundamentally broken topology. Check `isValid` after healing.
- **Example:**
  ```swift
  guard let repaired = importedShape.healed(), repaired.isValid else { return }
  ```

---

## Meshing

### `mesh(linearDeflection:angularDeflection:)`

Generate a triangulated mesh for visualisation.

```swift
public func mesh(
    linearDeflection: Double = 0.1,
    angularDeflection: Double = 0.5
) -> Mesh?
```

- **Parameters:**
  - `linearDeflection` — maximum chord deviation from curved faces (smaller = finer mesh, default `0.1`).
  - `angularDeflection` — maximum angular deviation in radians (default `0.5`).
- **Returns:** A `Mesh` containing triangles and normals, or `nil` on failure.
- **OCCT:** `BRepMesh_IncrementalMesh`.
- **Example:**
  ```swift
  if let mesh = box.mesh(linearDeflection: 0.05, angularDeflection: 0.3) {
      // use mesh.triangles, mesh.normals, etc.
  }
  ```

---

### `meshWithProgress(linearDeflection:angularDeflection:progress:)`

Generate a triangulated mesh with progress and cancellation support.

```swift
@discardableResult
public func meshWithProgress(
    linearDeflection: Double = 0.1,
    angularDeflection: Double = 0.5,
    progress: ImportProgress? = nil
) throws -> Shape
```

Wraps `BRepMesh_IncrementalMesh::Perform(Message_ProgressRange&)` so callers can observe meshing progress on large assemblies and cooperatively cancel.

- **Parameters:**
  - `linearDeflection`, `angularDeflection` — same as `mesh()`.
  - `progress` — optional `ImportProgress` object; call `shouldCancel()` to abort cooperatively.
- **Returns:** `self` (with triangulations attached) on success.
- **Throws:** `ImportError.cancelled` if the meshing was cancelled cooperatively.
- **OCCT:** `BRepMesh_IncrementalMesh` with `Message_ProgressRange` (via `OCCTShapeIncrementalMeshProgress`).
- **Example:**
  ```swift
  class MyProgress: ImportProgress {
      func shouldCancel() -> Bool { false }
      func report(fraction: Double) { print("Meshing: \(Int(fraction * 100))%") }
  }
  let prog = MyProgress()
  try shape.meshWithProgress(linearDeflection: 0.02, progress: prog)
  let mesh = shape.mesh()  // triangulations are now attached
  ```

---

### `mesh(parameters:)`

Generate a triangulated mesh with enhanced parameters.

```swift
public func mesh(parameters: MeshParameters) -> Mesh?
```

Provides fine-grained control over tessellation quality, useful for CAM toolpath generation or high-quality visualisation.

- **Parameters:** `parameters` — a `MeshParameters` struct with deflection, parallelism, and other options.
- **Returns:** A `Mesh` with the specified quality settings, or `nil` on failure.
- **OCCT:** `BRepMesh_IncrementalMesh` (via `OCCTShapeCreateMeshWithParams`).
- **Example:**
  ```swift
  var params = MeshParameters.default
  params.deflection = 0.02   // very fine mesh
  params.inParallel = true   // multi-threaded
  if let mesh = shape.mesh(parameters: params) { }
  ```

---

## Edge Discretization

### `edgePolyline(at:deflection:maxPoints:)`

Get a discretised edge as a polyline.

```swift
public func edgePolyline(
    at index: Int,
    deflection: Double = 0.1,
    maxPoints: Int = 1000
) -> [SIMD3<Double>]?
```

Adaptively samples points along a B-Rep edge using curvature-based deflection control. Useful for contour toolpath generation, edge visualisation, and G-code generation.

- **Parameters:**
  - `index` — edge index (0-based).
  - `deflection` — maximum chord deviation.
  - `maxPoints` — maximum number of points to return.
- **Returns:** Array of 3D points along the edge, or `nil` if the edge is not found.
- **OCCT:** `GCPnts_TangentialDeflection` / `BRep_Tool::Curve` (via `OCCTShapeGetEdgePolyline`).
- **Example:**
  ```swift
  if let pts = shape.edgePolyline(at: 0, deflection: 0.01) {
      // pts is [SIMD3<Double>] — contour points
  }
  ```
- **Note:** Edge indices may vary between runs for complex shapes; iterate to find a working index.

---

### `allEdgePolylines(deflection:maxPointsPerEdge:)`

Get all edges as discretised polylines.

```swift
public func allEdgePolylines(
    deflection: Double = 0.1,
    maxPointsPerEdge: Int = 1000
) -> [[SIMD3<Double>]]
```

Calls `edgePolyline` for each edge in the shape. Also calls `OCCTShapeBuildCurves3d` beforehand to ensure lofted/swept shapes (which may have only pcurves) have explicit 3D curves before discretisation.

- **Parameters:**
  - `deflection` — maximum chord deviation per edge.
  - `maxPointsPerEdge` — maximum points per edge.
- **Returns:** Array of polylines, one per edge. Edges that fail discretisation are skipped.
- **OCCT:** `BRepLib::BuildCurves3d` + `GCPnts_TangentialDeflection` (via `OCCTShapeBuildCurves3d` and `OCCTShapeGetEdgePolyline`).
- **Example:**
  ```swift
  let wireframe = shape.allEdgePolylines(deflection: 0.05)
  for polyline in wireframe {
      // draw polyline.map { CGPoint(x: $0.x, y: $0.y) }
  }
  ```

---

## Import

### `Shape.load(from:progress:)`

Load a shape from a STEP file (URL form).

```swift
public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Shape
```

Convenience alias for `loadSTEP(fromPath:progress:)`.

- **Parameters:** `url` — URL to the STEP file; `progress` — optional progress/cancellation channel.
- **Returns:** Imported shape.
- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on other failure.
- **OCCT:** `STEPControl_Reader` (via `OCCTImportSTEPProgress`).
- **Example:**
  ```swift
  guard let url = Bundle.main.url(forResource: "part", withExtension: "step") else { return }
  let shape = try Shape.load(from: url)
  ```

---

### `Shape.load(fromPath:progress:)`

Load a shape from a STEP file path.

```swift
public static func load(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape
```

- **Parameters:** `path` — file system path to the STEP file; `progress` — optional progress/cancellation.
- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on failure.
- **OCCT:** `STEPControl_Reader` (via `OCCTImportSTEPProgress`).

---

### `Shape.loadSTEP(from:progress:)`

Load a shape from a STEP file (alias with explicit naming).

```swift
public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Shape
```

Explicit alias for `load(from:progress:)`. Identical behaviour.

- **OCCT:** `STEPControl_Reader`.

---

### `Shape.loadSTEP(fromPath:progress:)`

Load a shape from a STEP file path with optional progress.

```swift
public static func loadSTEP(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape
```

- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on failure.
- **OCCT:** `STEPControl_Reader` (via `OCCTImportSTEPProgress`).

---

## STEP Reader Control

### `Shape.stepRootCount(url:)`

Get the number of transferable roots in a STEP file.

```swift
public static func stepRootCount(url: URL) -> Int
```

Use this to inspect a STEP file before importing specific roots with `loadSTEPRoot(from:rootIndex:)`.

- **Parameters:** `url` — URL to the STEP file.
- **Returns:** Number of roots (0 if the file cannot be read).
- **OCCT:** `STEPControl_Reader::TransferRoots` (via `OCCTSTEPReaderNbRoots`).
- **Example:**
  ```swift
  let count = Shape.stepRootCount(url: stepURL)
  for i in 1...count {
      let root = try Shape.loadSTEPRoot(from: stepURL, rootIndex: i)
  }
  ```

---

### `Shape.stepRootCount(path:)`

Get the number of transferable roots in a STEP file (path form).

```swift
public static func stepRootCount(path: String) -> Int
```

- **OCCT:** `STEPControl_Reader` (via `OCCTSTEPReaderNbRoots`).

---

### `Shape.loadSTEPRoot(from:rootIndex:)`

Import a specific root from a STEP file (1-based index).

```swift
public static func loadSTEPRoot(from url: URL, rootIndex: Int) throws -> Shape
```

- **Parameters:** `url` — URL to the STEP file; `rootIndex` — 1-based root index.
- **Returns:** The imported shape for that root.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `STEPControl_Reader::Transfer` (via `OCCTImportSTEPRoot`).

---

### `Shape.loadSTEPRoot(fromPath:rootIndex:)`

Import a specific root from a STEP file by path (1-based index).

```swift
public static func loadSTEPRoot(fromPath path: String, rootIndex: Int) throws -> Shape
```

- **OCCT:** `STEPControl_Reader` (via `OCCTImportSTEPRoot`).

---

### `Shape.loadSTEP(from:unitInMeters:progress:)`

Import a STEP file with a specific system length unit.

```swift
public static func loadSTEP(from url: URL, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape
```

- **Parameters:**
  - `url` — URL to the STEP file.
  - `unitInMeters` — system length unit in metres (e.g. `0.001` for mm, `0.0254` for inch).
  - `progress` — optional progress/cancellation channel.
- **Returns:** The imported shape in the specified unit system.
- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on failure.
- **OCCT:** `STEPControl_Reader` with `Interface_Static` unit setting (via `OCCTImportSTEPWithUnitProgress`).

---

### `Shape.loadSTEP(fromPath:unitInMeters:progress:)`

Import a STEP file with a specific system length unit (path form).

```swift
public static func loadSTEP(fromPath path: String, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape
```

- **OCCT:** `STEPControl_Reader` (via `OCCTImportSTEPWithUnitProgress`).

---

### `Shape.stepShapeCount(url:)`

Get the number of shapes in a STEP file after full transfer.

```swift
public static func stepShapeCount(url: URL) -> Int
```

- **Returns:** Number of shapes (0 if the file cannot be read).
- **OCCT:** `STEPControl_Reader::NbShapes` (via `OCCTSTEPReaderNbShapes`).

---

### `Shape.stepShapeCount(path:)`

Get the number of shapes in a STEP file after full transfer (path form).

```swift
public static func stepShapeCount(path: String) -> Int
```

- **OCCT:** `STEPControl_Reader` (via `OCCTSTEPReaderNbShapes`).

---

## Robust STEP Import

### `Shape.loadRobust(from:)`

Load a STEP file with robust handling: sewing, solid creation, and shape healing.

```swift
public static func loadRobust(from url: URL) throws -> Shape
```

Recommended for STEP files that may contain disconnected faces needing sewing, shells needing conversion to solids, or geometry issues requiring healing.

- **Parameters:** `url` — URL to the STEP file.
- **Returns:** Processed shape suitable for CAM operations.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `STEPControl_Reader` + `BRepBuilderAPI_Sewing` + `BRepBuilderAPI_MakeSolid` + `ShapeFix_Shape` (via `OCCTImportSTEPRobust`).
- **Example:**
  ```swift
  let shape = try Shape.loadRobust(from: stepURL)
  print(shape.isValid)   // typically true
  ```

---

### `Shape.loadRobust(fromPath:)`

Load a STEP file with robust handling from a file path.

```swift
public static func loadRobust(fromPath path: String) throws -> Shape
```

- **OCCT:** `STEPControl_Reader` + sewing + solid creation + healing (via `OCCTImportSTEPRobust`).

---

### `Shape.loadWithDiagnostics(from:)`

Load a STEP file with diagnostic information about the processing steps applied.

```swift
public static func loadWithDiagnostics(from url: URL) throws -> ImportResult
```

Returns an `ImportResult` struct containing the shape and information about what processing (sewing, solid creation, healing) was applied.

- **Parameters:** `url` — URL to the STEP file.
- **Returns:** `ImportResult` with `shape`, `originalType`, `resultType`, `sewingApplied`, `solidCreated`, and `healingApplied`.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `STEPControl_Reader` + `OCCTImportSTEPWithDiagnostics`.
- **Example:**
  ```swift
  let result = try Shape.loadWithDiagnostics(from: stepFile)
  print(result.summary)   // e.g. "Shell → Solid (processing: sewing, solid creation, healing)"
  let shape = result.shape
  ```

---

## IGES Import

### `Shape.loadIGES(from:progress:)`

Load a shape from an IGES file.

```swift
public static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> Shape
```

IGES is a legacy CAD format still commonly used in manufacturing and older CAD systems.

- **Parameters:** `url` — URL to the `.igs` or `.iges` file; `progress` — optional progress/cancellation.
- **Returns:** Imported shape.
- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on failure.
- **OCCT:** `IGESControl_Reader` (via `OCCTImportIGESProgress`).
- **Example:**
  ```swift
  let shape = try Shape.loadIGES(from: igesURL)
  ```

---

### `Shape.loadIGES(fromPath:progress:)`

Load a shape from an IGES file path.

```swift
public static func loadIGES(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape
```

- **OCCT:** `IGESControl_Reader` (via `OCCTImportIGESProgress`).

---

### `Shape.loadIGESRobust(from:progress:)`

Load an IGES file with automatic repair (sewing and healing).

```swift
public static func loadIGESRobust(from url: URL, progress: ImportProgress? = nil) throws -> Shape
```

- **Parameters:** `url` — URL to the IGES file; `progress` — optional progress/cancellation channel.
- **Returns:** Processed shape with healing applied.
- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on failure.
- **OCCT:** `IGESControl_Reader` + `BRepBuilderAPI_Sewing` + `ShapeFix_Shape` (via `OCCTImportIGESRobustProgress`).

---

### `Shape.loadIGESRobust(fromPath:progress:)`

Load an IGES file with automatic repair from a path.

```swift
public static func loadIGESRobust(fromPath path: String, progress: ImportProgress? = nil) throws -> Shape
```

- **OCCT:** `IGESControl_Reader` + sewing + healing (via `OCCTImportIGESRobustProgress`).

---

## IGES Reader Control

### `Shape.igesRootCount(url:)`

Get the number of transferable roots in an IGES file.

```swift
public static func igesRootCount(url: URL) -> Int
```

- **Returns:** Number of roots (0 if the file cannot be read).
- **OCCT:** `IGESControl_Reader` (via `OCCTIGESReaderNbRoots`).

---

### `Shape.igesRootCount(path:)`

Get the number of transferable roots in an IGES file (path form).

```swift
public static func igesRootCount(path: String) -> Int
```

- **OCCT:** `IGESControl_Reader` (via `OCCTIGESReaderNbRoots`).

---

### `Shape.loadIGESRoot(from:rootIndex:)`

Import a specific root from an IGES file (1-based index).

```swift
public static func loadIGESRoot(from url: URL, rootIndex: Int) throws -> Shape
```

- **Parameters:** `url` — URL to the IGES file; `rootIndex` — 1-based root index.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `IGESControl_Reader::Transfer` (via `OCCTImportIGESRoot`).

---

### `Shape.loadIGESRoot(fromPath:rootIndex:)`

Import a specific root from an IGES file by path (1-based index).

```swift
public static func loadIGESRoot(fromPath path: String, rootIndex: Int) throws -> Shape
```

- **OCCT:** `IGESControl_Reader` (via `OCCTImportIGESRoot`).

---

### `Shape.igesShapeCount(url:)`

Get the number of shapes in an IGES file after full transfer.

```swift
public static func igesShapeCount(url: URL) -> Int
```

- **OCCT:** `IGESControl_Reader::NbShapes` (via `OCCTIGESReaderNbShapes`).

---

### `Shape.igesShapeCount(path:)`

Get the number of shapes in an IGES file after full transfer (path form).

```swift
public static func igesShapeCount(path: String) -> Int
```

- **OCCT:** `IGESControl_Reader` (via `OCCTIGESReaderNbShapes`).

---

### `Shape.loadIGESVisible(from:)`

Import only visible entities from an IGES file.

```swift
public static func loadIGESVisible(from url: URL) throws -> Shape
```

- **Parameters:** `url` — URL to the IGES file.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `IGESControl_Reader` with visibility filtering (via `OCCTImportIGESVisible`).

---

### `Shape.loadIGESVisible(fromPath:)`

Import only visible entities from an IGES file (path form).

```swift
public static func loadIGESVisible(fromPath path: String) throws -> Shape
```

- **OCCT:** `IGESControl_Reader` (via `OCCTImportIGESVisible`).

---

## BREP Import

### `Shape.loadBREP(from:)`

Load a shape from OCCT's native BREP format.

```swift
public static func loadBREP(from url: URL) throws -> Shape
```

BREP is OCCT's native exact B-Rep format. It preserves full precision and is useful for fast caching of intermediate results, debugging geometry, and archiving exact geometry.

- **Parameters:** `url` — URL to the `.brep` file.
- **Returns:** Imported shape.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `BRep_Builder` / `BRepTools::Read` (via `OCCTImportBREP`).
- **Example:**
  ```swift
  let shape = try Shape.loadBREP(from: brepURL)
  ```

---

### `Shape.loadBREP(fromPath:)`

Load a shape from a BREP file path.

```swift
public static func loadBREP(fromPath path: String) throws -> Shape
```

- **OCCT:** `BRep_Builder` / `BRepTools::Read` (via `OCCTImportBREP`).

---

## STL Import

### `Shape.loadSTL(from:)`

Load a shape from an STL file.

```swift
public static func loadSTL(from url: URL) throws -> Shape
```

- **Parameters:** `url` — URL to the `.stl` file.
- **Returns:** Imported shape (a shell of triangulated faces).
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `StlAPI_Reader` (via `OCCTImportSTL`).
- **Example:**
  ```swift
  let mesh = try Shape.loadSTL(from: stlURL)
  ```

---

### `Shape.loadSTL(fromPath:)`

Load a shape from an STL file path.

```swift
public static func loadSTL(fromPath path: String) throws -> Shape
```

- **OCCT:** `StlAPI_Reader` (via `OCCTImportSTL`).

---

### `Shape.loadSTLRobust(from:sewingTolerance:)`

Load an STL file with robust healing (sew + solid creation + heal).

```swift
public static func loadSTLRobust(from url: URL, sewingTolerance: Double = 1e-6) throws -> Shape
```

- **Parameters:**
  - `url` — URL to the STL file.
  - `sewingTolerance` — tolerance for sewing disconnected faces (default `1e-6`).
- **Returns:** Processed shape suitable for solid operations.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `StlAPI_Reader` + `BRepBuilderAPI_Sewing` + `BRepBuilderAPI_MakeSolid` + `ShapeFix_Shape` (via `OCCTImportSTLRobust`).
- **Example:**
  ```swift
  let solid = try Shape.loadSTLRobust(from: stlURL, sewingTolerance: 1e-5)
  print(solid.isValid)
  ```

---

### `Shape.loadSTLRobust(fromPath:sewingTolerance:)`

Load an STL file with robust healing from a path.

```swift
public static func loadSTLRobust(fromPath path: String, sewingTolerance: Double = 1e-6) throws -> Shape
```

- **OCCT:** `StlAPI_Reader` + sewing + healing (via `OCCTImportSTLRobust`).

---

## OBJ Import

### `Shape.loadOBJ(from:)`

Load a shape from an OBJ file.

```swift
public static func loadOBJ(from url: URL) throws -> Shape
```

- **Parameters:** `url` — URL to the `.obj` file.
- **Returns:** Imported shape.
- **Throws:** `ImportError.importFailed` on failure.
- **OCCT:** `RWObj_CafReader` (via `OCCTImportOBJ`).
- **Example:**
  ```swift
  let shape = try Shape.loadOBJ(from: objURL)
  ```

---

### `Shape.loadOBJ(fromPath:)`

Load a shape from an OBJ file path.

```swift
public static func loadOBJ(fromPath path: String) throws -> Shape
```

- **OCCT:** `RWObj_CafReader` (via `OCCTImportOBJ`).
