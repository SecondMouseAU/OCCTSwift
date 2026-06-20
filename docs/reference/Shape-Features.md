---
title: Shape — Features, Sweeps & Surface Building
parent: API Reference
---

# Shape — Features, Sweeps & Surface Building

This page documents the Shape API from **Geometry Construction** through **Plate Surfaces** (source lines 1258–3344 of `Shape.swift`). It covers face and solid assembly, feature-based modeling (bosses, pockets, holes, patterns), shape inspection, slicing, measurement, advanced pipe sweeps, surface building, and healing. For the primitive factories, boolean operations, and transforms that precede this range, see the main **Shape** index page (not yet written; use `Surface.md` as an exemplar for style).

## Topics

- [Geometry Construction](#geometry-construction-v0110) · [Feature-Based Modeling](#feature-based-modeling-v0120) · [Shape Type](#shape-type) · [Sub-Shape Extraction](#sub-shape-extraction) · [Bounds](#bounds) · [Slicing](#slicing) · [Operators](#operators) · [Measurement & Analysis](#measurement--analysis-v070) · [Convenience Overloads](#wireenface-convenience-overloads) · [Selective Fillet / Draft / Defeaturing](#selective-fillet-draft--defeaturing) · [Advanced / Variable-Section Pipe Sweep](#advanced--variable-section-pipe-sweep) · [Surface Creation](#surface-creation-v090) · [Shape Healing / Analysis / Fixing / Unification](#shape-healing--analysis-v0130) · [Advanced Blends & Surface Filling](#advanced-blends--surface-filling-v0140) · [Variable Radius Fillet](#variable-radius-fillet-v0140) · [Multi-Edge Blend](#multi-edge-blend-v0140) · [Surface Filling](#surface-filling-v0140) · [Plate Surfaces](#plate-surfaces-v0140--v0230)

---

## Geometry Construction (v0.11.0)

### `Shape.face(from:planar:)`

Creates a planar face from a closed wire.

```swift
public static func face(from wire: Wire, planar: Bool = true) -> Shape?
```

- **Parameters:** `wire` — a closed wire defining the face boundary; `planar` — if `true` (default), requires the wire to be planar.
- **Returns:** A face shape, or `nil` if the wire is not closed, not planar (when `planar: true`), or construction fails.
- **OCCT:** `BRepBuilderAPI_MakeFace(wire, planar)`.
- **Example:**
  ```swift
  let rect = Wire.rectangle(width: 10, height: 5)!
  let face = Shape.face(from: rect)!
  let box = face.extruded(direction: [0, 0, 1], length: 3)
  ```

---

### `Shape.face(outer:holes:)`

Creates a face with one or more through-holes.

```swift
public static func face(outer: Wire, holes: [Wire]) -> Shape?
```

- **Parameters:** `outer` — the outer boundary wire (closed); `holes` — array of inner boundary wires, each defining a hole.
- **Returns:** A face with holes, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace(outer, planar)` + `BRepBuilderAPI_MakeFace::Add` for each inner wire.
- **Example:**
  ```swift
  let outer = Wire.rectangle(width: 20, height: 20)!
  let hole1 = Wire.circle(radius: 3)!.translated(x: -5, y: 0, z: 0)
  let hole2 = Wire.circle(radius: 3)!.translated(x: 5, y: 0, z: 0)
  if let face = Shape.face(outer: outer, holes: [hole1, hole2]) {
      let extruded = face.extruded(direction: [0, 0, 1], length: 5)
  }
  ```

---

### `Shape.solid(from:)`

Creates a solid from a closed shell.

```swift
public static func solid(from shell: Shape) -> Shape?
```

The shell must be closed (no gaps). A shell produced by `sew(shapes:)` is typically already closed when all boundary faces are included.

- **Parameters:** `shell` — a shell shape (from sewing or face assembly).
- **Returns:** A solid shape, or `nil` if the shell is not closed.
- **OCCT:** `BRepBuilderAPI_MakeSolid(shell)`.
- **Example:**
  ```swift
  let sewn = Shape.sew(shapes: faces, tolerance: 1e-6)!
  let solid = Shape.solid(from: sewn)!
  ```

---

### `Shape.sew(shapes:tolerance:)`

Sews multiple shapes into a connected shell or solid.

```swift
public static func sew(shapes: [Shape], tolerance: Double = 1e-6) -> Shape?
```

Connects faces that share edges within `tolerance`. Useful for repairing imported geometry or joining separately created faces. If the result is closed, OCCT promotes it to a solid.

- **Parameters:** `shapes` — array of shapes (faces, shells) to sew; `tolerance` — maximum gap size to close (default 1e-6).
- **Returns:** Sewn shape (shell or solid if closed), or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Sewing`.
- **Example:**
  ```swift
  let solid = Shape.sew(shapes: [top, bottom, front, back, left, right], tolerance: 0.01)
  ```

---

### `Shape.sew(_:with:tolerance:)`

Sews exactly two shapes together.

```swift
public static func sew(_ shape: Shape, with other: Shape, tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `shape` — first shape; `other` — second shape; `tolerance` — gap tolerance.
- **Returns:** Sewn shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Sewing` (two-argument convenience).

---

### `sewn(with:tolerance:)`

Sews this shape with another (instance method).

```swift
public func sewn(with other: Shape, tolerance: Double = 1e-6) -> Shape?
```

Calls `Shape.sew(self, with: other, tolerance:)`.

- **Parameters:** `other` — shape to sew with; `tolerance` — gap tolerance.
- **Returns:** Sewn shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Sewing`.

---

## Feature-Based Modeling (v0.12.0)

### `withPrism(profile:direction:height:fuse:)`

Adds or removes material via a prismatic extrusion feature.

```swift
public func withPrism(profile: Wire, direction: SIMD3<Double>, height: Double, fuse: Bool) -> Shape?
```

When `fuse` is `true`, material is added (boss); when `false`, material is removed (pocket). The profile should already be positioned on a face of the receiver.

- **Parameters:** `profile` — wire profile to extrude; `direction` — extrusion direction; `height` — feature height; `fuse` — `true` = add material, `false` = remove material.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePrism` + `BRepAlgoAPI_Fuse` or `BRepAlgoAPI_Cut`.
- **Example:**
  ```swift
  let box = Shape.box(width: 50, height: 50, depth: 10)
  let profile = Wire.circle(radius: 5)!.translated(x: 25, y: 25, z: 10)
  let withBoss = box.withPrism(profile: profile, direction: SIMD3(0, 0, 1), height: 5, fuse: true)
  ```

---

### `withBoss(profile:direction:height:)`

Adds a raised feature (boss) to the shape. Convenience wrapper for `withPrism(..., fuse: true)`.

```swift
public func withBoss(profile: Wire, direction: SIMD3<Double>, height: Double) -> Shape?
```

- **Parameters:** `profile` — profile wire; `direction` — extrusion direction; `height` — boss height.
- **Returns:** Shape with added boss, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePrism` (fuse mode).

---

### `withPocket(profile:direction:depth:)`

Creates a depression (pocket) in the shape. Convenience wrapper for `withPrism(..., fuse: false)`.

```swift
public func withPocket(profile: Wire, direction: SIMD3<Double>, depth: Double) -> Shape?
```

- **Parameters:** `profile` — profile wire defining the pocket boundary; `direction` — pocket direction (into the shape); `depth` — pocket depth.
- **Returns:** Shape with pocket, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePrism` (cut mode).

---

### `drilled(at:direction:radius:depth:)`

Drills a cylindrical hole into the shape.

```swift
public func drilled(at position: SIMD3<Double>, direction: SIMD3<Double>,
                    radius: Double, depth: Double = 0) -> Shape?
```

`depth: 0` creates a through-hole (the cylinder is made large enough to penetrate the shape entirely).

- **Parameters:** `position` — hole-centre point on the entry face; `direction` — drill direction (into the shape); `radius` — hole radius; `depth` — hole depth, or `0` for through-hole.
- **Returns:** Shape with drilled hole, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace` + `BRepAlgoAPI_Cut` (internal cylinder cutter).
- **Example:**
  ```swift
  let plate = Shape.box(width: 50, height: 50, depth: 10)
  if let drilled = plate.drilled(at: SIMD3(25, 25, 10), direction: SIMD3(0, 0, -1),
                                   radius: 5, depth: 0) {
      // through-hole centred at (25, 25)
  }
  ```

---

### `split(by:)`

Splits the shape using a cutting tool shape.

```swift
public func split(by tool: Shape) -> [Shape]?
```

- **Parameters:** `tool` — shape to use as cutting tool (typically a face or solid).
- **Returns:** Array of result shapes after the split, or `nil` on failure. The array will have at least two elements when the cut produces distinct pieces.
- **OCCT:** `BRepAlgoAPI_BuilderAlgo` (multi-split general cutter).
- **Example:**
  ```swift
  let box = Shape.box(width: 20, height: 20, depth: 20)
  let plane = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
                   .translated(by: SIMD3(0, 0, 10))
  if let halves = box.split(by: plane) {
      // halves.count == 2
  }
  ```

---

### `split(atPlane:normal:)`

Splits the shape by an infinite plane.

```swift
public func split(atPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> [Shape]?
```

- **Parameters:** `point` — a point on the cutting plane; `normal` — plane normal direction.
- **Returns:** Array of result shapes, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeFace` (build cutting plane) + `BRepAlgoAPI_BuilderAlgo`.
- **Example:**
  ```swift
  let cube = Shape.box(width: 20, height: 20, depth: 20)
  let halves = cube.split(atPlane: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))
  ```

---

### `Shape.glue(_:_:tolerance:)`

Glues two shapes together at coincident faces.

```swift
public static func glue(_ shape1: Shape, _ shape2: Shape, tolerance: Double = 1e-6) -> Shape?
```

More efficient than boolean union when the shapes have perfectly coincident faces. Uses OCCT's glue option (`BRepAlgoAPI_Fuse` with `GlueFull`) to avoid full topology re-computation.

- **Parameters:** `shape1` — first shape; `shape2` — second shape with coincident faces; `tolerance` — face-matching tolerance.
- **Returns:** Glued shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` with glue option.

---

### `Shape.evolved(spine:profile:)`

Creates an evolved shape (profile swept along spine with orientation tracking).

```swift
public static func evolved(spine: Wire, profile: Wire) -> Shape?
```

The profile is swept along the spine and its orientation evolves to remain perpendicular to the spine tangent.

- **Parameters:** `spine` — path wire; `profile` — profile wire to sweep.
- **Returns:** Evolved shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeEvolved`.

---

### `Shape.evolvedAdvanced(spine:profile:joinType:axeProf:solid:volume:tolerance:)`

Creates an evolved shape with full parameter control.

```swift
public static func evolvedAdvanced(spine: Shape, profile: Wire,
                                   joinType: OffsetJoinType = .arc,
                                   axeProf: Bool = true,
                                   solid: Bool = true,
                                   volume: Bool = false,
                                   tolerance: Double = 1e-4) -> Shape?
```

- **Parameters:**
  - `spine` — spine shape (any topology accepted).
  - `profile` — profile wire.
  - `joinType` — how to join offset edges at corners (default `.arc`).
  - `axeProf` — if `true`, profile is in global coordinates; if `false`, local to the spine.
  - `solid` — produce a solid result when `true`.
  - `volume` — use volume mode (removes self-intersections) when `true`.
  - `tolerance` — construction tolerance.
- **Returns:** Evolved shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeEvolved`.

---

### `linearPattern(direction:spacing:count:)`

Creates a linear array of this shape.

```swift
public func linearPattern(direction: SIMD3<Double>, spacing: Double, count: Int) -> Shape?
```

Returns a compound containing `count` copies of the shape, spaced `spacing` apart along `direction`.

- **Parameters:** `direction` — pattern direction vector; `spacing` — distance between copies; `count` — number of copies (including the original).
- **Returns:** Compound of all copies, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Transform` applied iteratively, collected into a `TopoDS_Compound`.
- **Example:**
  ```swift
  let hole = Shape.cylinder(radius: 3, height: 10)
  let row = hole.linearPattern(direction: SIMD3(20, 0, 0), spacing: 20, count: 5)
  ```

---

### `circularPattern(axisPoint:axisDirection:count:angle:)`

Creates a circular array of this shape around an axis.

```swift
public func circularPattern(axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>,
                             count: Int, angle: Double = 0) -> Shape?
```

Duplicates the **entire body** `count` times around `axisPoint`/`axisDirection` and returns a compound. It does **not** pattern features — to replicate a cut feature, see `circularPatternCut(tool:...)`.

- **Parameters:** `axisPoint` — point on the rotation axis; `axisDirection` — axis direction; `count` — number of copies (including original); `angle` — total arc to span in radians (`0` = full circle).
- **Returns:** Compound of all copies, or `nil` on failure.
- **OCCT:** `gp_Trsf::SetRotation` applied iteratively.
- **Example:**
  ```swift
  let holeTool = Shape.cylinder(radius: 3, height: 20).translated(by: SIMD3(40, 0, 0))
  let tools = holeTool.circularPattern(axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 6)
  let drilled = flange.subtracting(tools!)
  ```

---

### `circularPatternCut(tool:axisPoint:axisDirection:count:angle:)`

Replicates a cut feature around an axis and subtracts all copies from this body.

```swift
public func circularPatternCut(tool: Shape, axisPoint: SIMD3<Double>,
                                axisDirection: SIMD3<Double>, count: Int,
                                angle: Double = 0) -> Shape?
```

Combines `circularPattern` of `tool` with `subtracting` in a single call. The natural primitive for bolt circles.

- **Parameters:** `tool` — the cutting feature (e.g. a cylinder at the first hole position); `axisPoint` — rotation axis point; `axisDirection` — axis direction; `count` — number of tool copies (including original); `angle` — arc span in radians (`0` = full circle).
- **Returns:** This body with all `count` features cut out, or `nil` on failure.
- **OCCT:** `circularPattern` + `BRepAlgoAPI_Cut`.
- **Example:**
  ```swift
  let hole = Shape.cylinder(radius: 3, height: 20).translated(by: SIMD3(40, 0, 0))
  let flangeWithHoles = blank.circularPatternCut(
      tool: hole, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 8
  )
  ```

---

## Shape Type

### `ShapeType`

Topological type of a shape, matching `TopAbs_ShapeEnum`.

```swift
public enum ShapeType: Int, CustomStringConvertible, Sendable {
    case compound = 0
    case compSolid = 1
    case solid = 2
    case shell = 3
    case face = 4
    case wire = 5
    case edge = 6
    case vertex = 7
    case unknown = -1
}
```

Used by `shapeType`, `subShapeCount(ofType:)`, `subShape(type:index:)`, and `subShapes(ofType:)`.

---

### `shapeType`

The topological type of this shape.

```swift
public var shapeType: ShapeType { get }
```

- **Returns:** The `ShapeType` case for this shape's root topology.
- **OCCT:** `TopoDS_Shape::ShapeType` (via `OCCTShapeGetType`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)
  print(box.shapeType)  // .solid
  ```

---

### `isValidSolid`

Whether the shape is a topologically valid closed solid.

```swift
public var isValidSolid: Bool { get }
```

Runs `BRepCheck_Analyzer` — a **topology** check only. It does not detect global self-intersection (overlapping faces). A self-intersecting B-spline solid can pass this check yet cause booleans to hang or return garbage. Use `isSelfIntersecting(timeout:)` for the complementary geometric check.

- **Returns:** `true` if `BRepCheck_Analyzer` reports no errors.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTShapeIsValidSolid`).

---

### `isSelfIntersecting(timeout:)`

Checks whether the shape has overlapping or interfering sub-faces.

```swift
public func isSelfIntersecting(timeout: Double = 30) -> Bool?
```

Backed by `BOPAlgo_ArgumentAnalyzer`'s self-interference test. Expensive (seconds on B-spline solids), so wall-clock bounded by `timeout`.

- **Parameters:** `timeout` — seconds before the check gives up (default 30). `0` or negative = unbounded.
- **Returns:** `true` = self-interference found; `false` = shape is clean; `nil` = indeterminate (timed out / errored — treat as "unknown", not "clean").
- **OCCT:** `BOPAlgo_ArgumentAnalyzer` (via `OCCTShapeSelfIntersectsBounded`).
- **Example:**
  ```swift
  guard let solid = Shape.loft(profiles: ps, ruled: false)?.orientedForward(),
        solid.isSelfIntersecting() == false else { /* reject */ return }
  ```

---

### `ImportError`

Error type for failed STEP/IGES/BREP imports.

```swift
public enum ImportError: Error, LocalizedError {
    case importFailed(String)
    case cancelled
}
```

- `importFailed` — carries a human-readable message describing why the import failed.
- `cancelled` — the import was cancelled via `ImportProgress.shouldCancel()`.

---

### `ShapeType` (companion enum to `Shape.shapeType`)

*(See `ShapeType` entry above in this section.)*

---

### `ImportResult`

Result of a robust STEP import that includes diagnostic information.

```swift
public struct ImportResult: Sendable {
    public let shape: Shape
    public let originalType: ShapeType
    public let resultType: ShapeType
    public let sewingApplied: Bool
    public let solidCreated: Bool
    public let healingApplied: Bool
    public var summary: String { get }
}
```

`summary` returns a human-readable description such as `"Shell → Solid (processing: sewing, solid creation)"`.

---

## Sub-Shape Extraction

### `subShapeCount(ofType:)`

Returns the number of sub-shapes of a given topological type.

```swift
public func subShapeCount(ofType type: ShapeType) -> Int
```

- **Parameters:** `type` — the topological type to count (e.g. `.face`, `.edge`, `.vertex`).
- **Returns:** Count of sub-shapes of that type.
- **OCCT:** `TopExp::MapShapes` (via `OCCTShapeGetSubShapeCount`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)
  print(box.subShapeCount(ofType: .face))  // 6
  ```

---

### `subShape(type:index:)`

Returns a sub-shape by topological type and zero-based index.

```swift
public func subShape(type: ShapeType, index: Int) -> Shape?
```

Uses `TopExp::MapShapes` to enumerate sub-shapes of the given type.

- **Parameters:** `type` — topological type; `index` — zero-based index.
- **Returns:** The sub-shape as a `Shape`, or `nil` if `index` is out of range.
- **OCCT:** `TopExp::MapShapes` + index lookup (via `OCCTShapeGetSubShapeByTypeIndex`).
- **Note:** Edge indices are not guaranteed to be stable across calls or OCCT versions. Iterate to find a working index for edge-specific operations.

---

### `subShapes(ofType:)`

Returns all sub-shapes of a given topological type as an array.

```swift
public func subShapes(ofType type: ShapeType) -> [Shape]
```

- **Parameters:** `type` — topological type.
- **Returns:** Array of all sub-shapes of that type (may be empty).
- **OCCT:** Calls `subShapeCount` + `subShape(type:index:)` iteratively.

---

## Bounds

### `bounds`

Axis-aligned bounding box of the shape.

```swift
public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) { get }
```

Uses OCCT's default `Bnd_Box`, which for B-spline and faceted surfaces is the **control-point hull** and can over-report the true extent. For a tight AABB use `boundingBoxOptimal()` (`Bnd_Box::AddOptimal`), or the ground-truth min/max of `mesh(...)` vertices.

- **Returns:** Tuple of min and max AABB corners.
- **OCCT:** `BRepBndLib::Add` (via `OCCTShapeGetBounds`).
- **Example:**
  ```swift
  let b = Shape.box(width: 10, height: 5, depth: 3).bounds
  // b.min ≈ SIMD3(0, 0, 0), b.max ≈ SIMD3(10, 5, 3)
  ```

---

### `size`

Size of the bounding box (max − min).

```swift
public var size: SIMD3<Double> { get }
```

- **Returns:** `bounds.max − bounds.min`.

---

### `center`

Centre of the bounding box.

```swift
public var center: SIMD3<Double> { get }
```

- **Returns:** `(bounds.min + bounds.max) / 2`.

---

## Slicing

### `sliceAtZ(_:)`

Slices the shape at a given Z height, returning the cross-section as loose edges.

```swift
public func sliceAtZ(_ z: Double) -> Shape?
```

- **Parameters:** `z` — the Z-plane height at which to section.
- **Returns:** A shape containing the cross-section edges, or `nil` if no intersection exists at that Z.
- **OCCT:** `BRepAlgoAPI_Section`.

---

### `sectionWiresAtZ(_:tolerance:)`

Returns closed wires from a section at a Z level.

```swift
public func sectionWiresAtZ(_ z: Double, tolerance: Double = 1e-6) -> [Wire]
```

Unlike `sliceAtZ`, this chains the section edges into closed wires suitable for offset or CAM operations. Use a larger `tolerance` (e.g. `1e-4`) for imprecise geometry.

- **Parameters:** `z` — Z level to section at; `tolerance` — tolerance for connecting edges into wires.
- **Returns:** Array of closed `Wire` objects; empty if no contours exist at that level.
- **OCCT:** `BRepAlgoAPI_Section` + `BRepBuilderAPI_MakeWire` (via `OCCTShapeSectionWiresAtZ`).
- **Example:**
  ```swift
  let model = try Shape.load(from: stepFile)
  let contours = model.sectionWiresAtZ(5.0)
  for contour in contours {
      if let offset = contour.offset(by: toolRadius) { /* CAM boundary */ }
  }
  ```

---

### `edgePoints(at:maxPoints:)`

Returns sampled points along the edge at the given index.

```swift
public func edgePoints(at index: Int, maxPoints: Int = 20) -> [SIMD3<Double>]
```

Points are uniformly sampled from start to end of the edge curve.

- **Parameters:** `index` — edge index (0 to `subShapeCount(ofType: .edge) − 1`); `maxPoints` — maximum points to return (capped at 20 internally).
- **Returns:** Array of 3D points along the edge curve.
- **OCCT:** `BRep_Tool::Curve` + `GCPnts_UniformParameter` (via `OCCTShapeGetEdgePoints`).

---

### `contourPoints(maxPoints:)`

Returns the start vertices of all edges in the shape.

```swift
public func contourPoints(maxPoints: Int = 1000) -> [SIMD3<Double>]
```

Returns edge **start** vertices only, not intermediate curve samples. For curved edges use `edgePoints(at:maxPoints:)` instead. Suitable for simple polygon contours from Z-plane slices.

- **Parameters:** `maxPoints` — maximum number of points to return.
- **Returns:** Array of 3D points (one per edge start vertex).
- **OCCT:** `TopExp_Explorer` over `TopAbs_EDGE` (via `OCCTShapeGetContourPoints`).

---

## Operators

Boolean operator overloads on `Shape`. All return `Shape?`.

### `+(lhs:rhs:)`

```swift
public static func + (lhs: Shape, rhs: Shape) -> Shape?
```

Union of two shapes. Calls `lhs.union(rhs)`.

- **OCCT:** `BRepAlgoAPI_Fuse`.

---

### `-(lhs:rhs:)`

```swift
public static func - (lhs: Shape, rhs: Shape) -> Shape?
```

Subtraction. Calls `lhs.subtracting(rhs)`.

- **OCCT:** `BRepAlgoAPI_Cut`.

---

### `&(lhs:rhs:)`

```swift
public static func & (lhs: Shape, rhs: Shape) -> Shape?
```

Intersection. Calls `lhs.intersection(rhs)`.

- **OCCT:** `BRepAlgoAPI_Common`.

---

## Measurement & Analysis (v0.7.0)

### `ShapeProperties`

Mass and geometric properties of a shape.

```swift
public struct ShapeProperties: Sendable, Equatable {
    public var volume: Double
    public var surfaceArea: Double
    public var mass: Double
    public var centerOfMass: SIMD3<Double>
    public var momentOfInertia: simd_double3x3
}
```

Returned by `properties(density:)`.

---

### `DistanceResult`

Result of a minimum-distance measurement between two shapes.

```swift
public struct DistanceResult: Sendable, Equatable {
    public var distance: Double
    public var pointOnShape1: SIMD3<Double>
    public var pointOnShape2: SIMD3<Double>
    public var solutionCount: Int
}
```

Returned by `distance(to:deflection:)`.

---

### `properties(density:)`

Returns full mass properties of the shape.

```swift
public func properties(density: Double = 1.0) -> ShapeProperties?
```

- **Parameters:** `density` — material density for mass calculation (default 1.0).
- **Returns:** `ShapeProperties` including volume, surface area, centre of mass, and inertia tensor; or `nil` if calculation fails.
- **OCCT:** `BRepGProp::VolumeProperties` + `BRepGProp::SurfaceProperties` (via `OCCTShapeGetProperties`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)
  if let p = box.properties(density: 7.8) {
      print("mass: \(p.mass), CoM: \(p.centerOfMass)")
  }
  ```

---

### `volume`

Volume of the shape in cubic units. Returns `nil` if the shape has no volume (e.g. a face).

```swift
public var volume: Double? { get }
```

- **Returns:** Non-negative volume, or `nil` if OCCT returns a negative sentinel.
- **OCCT:** `BRepGProp::VolumeProperties` (via `OCCTShapeGetVolume`).

---

### `signedVolume`

Signed volume of the shape. Negative for reversed-orientation solids.

```swift
public var signedVolume: Double { get }
```

Unlike `volume`, preserves the sign. A solid whose faces point inward (e.g. produced by `sweep(profile:along:)`) has a negative `signedVolume`. Use `orientedForward()` to fix the orientation.

- **OCCT:** `BRepGProp::VolumeProperties`.

---

### `orientedForward()`

Returns a copy of this solid whose faces are oriented outward (positive volume).

```swift
public func orientedForward() -> Shape?
```

Reverses orientation only when `signedVolume < 0`. Already-correct solids, shells, and faces are returned unchanged.

- **Returns:** Outward-oriented copy, `self` if no fix needed, or `nil` if reversal fails.
- **OCCT:** `TopoDS_Shape::Reverse` applied via `reversed` when `signedVolume < 0`.
- **Example:**
  ```swift
  if let solid = Shape.sweep(profile: profile, along: path)?.orientedForward() {
      // solid.signedVolume > 0 guaranteed
  }
  ```

---

### `surfaceArea`

Surface area of the shape in square units.

```swift
public var surfaceArea: Double? { get }
```

- **Returns:** Non-negative area, or `nil` on failure.
- **OCCT:** `BRepGProp::SurfaceProperties` (via `OCCTShapeGetSurfaceArea`).

---

### `centerOfMass`

Centre of mass (centroid) of the shape.

```swift
public var centerOfMass: SIMD3<Double>? { get }
```

- **Returns:** Centroid position, or `nil` on failure.
- **OCCT:** `BRepGProp::VolumeProperties` (via `OCCTShapeGetCenterOfMass`).

---

### `distance(to:deflection:)`

Computes the minimum distance between this shape and another.

```swift
public func distance(to other: Shape, deflection: Double = 1e-6) -> DistanceResult?
```

- **Parameters:** `other` — the target shape; `deflection` — tolerance for curved geometry.
- **Returns:** `DistanceResult` with the distance and closest points, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape`.
- **Example:**
  ```swift
  let box1 = Shape.box(width: 5, height: 5, depth: 5)
  let box2 = Shape.box(width: 5, height: 5, depth: 5).translated(by: SIMD3(10, 0, 0))
  if let d = box1.distance(to: box2) { print(d.distance) }  // 5.0
  ```

---

### `minDistance(to:)`

Returns just the minimum distance scalar.

```swift
public func minDistance(to other: Shape) -> Double?
```

- **Returns:** Minimum distance, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` (via `distance(to:deflection:)`).

---

### `intersects(_:tolerance:)`

Tests whether this shape intersects another within a tolerance.

```swift
public func intersects(_ other: Shape, tolerance: Double = 1e-6) -> Bool
```

- **Parameters:** `other` — shape to test against; `tolerance` — distance threshold.
- **Returns:** `true` if the shapes overlap or touch within `tolerance`.
- **OCCT:** `BRepExtrema_DistShapeShape` (distance ≤ tolerance).

---

## Wire / Edge / Face Convenience Overloads

The following overloads lift `Wire`, `Edge`, and `Face` into `Shape` before dispatching. They have the same semantics as their `Shape`-typed counterparts.

### `distance(to:deflection:)` — Wire, Edge, Face

```swift
public func distance(to wire: Wire, deflection: Double = 1e-6) -> DistanceResult?
public func distance(to edge: Edge, deflection: Double = 1e-6) -> DistanceResult?
public func distance(to face: Face, deflection: Double = 1e-6) -> DistanceResult?
```

---

### `intersects(_:tolerance:)` — Wire, Edge, Face

```swift
public func intersects(_ wire: Wire, tolerance: Double = 1e-6) -> Bool
public func intersects(_ edge: Edge, tolerance: Double = 1e-6) -> Bool
public func intersects(_ face: Face, tolerance: Double = 1e-6) -> Bool
```

---

### `vertexCount`

Number of vertices (corner points) in the shape.

```swift
public var vertexCount: Int { get }
```

- **OCCT:** `TopExp::MapShapes(TopAbs_VERTEX)` (via `OCCTShapeGetVertexCount`).

---

### `vertices()`

Returns all vertex positions of the shape.

```swift
public func vertices() -> [SIMD3<Double>]
```

- **Returns:** Array of vertex coordinates. Order matches `TopExp::MapShapes` enumeration.
- **OCCT:** `TopExp::MapShapes(TopAbs_VERTEX)` + `BRep_Tool::Pnt` (via `OCCTShapeGetVertices`).
- **Note:** `vertices()` is a **method**, not a property.

---

### `vertex(at:)`

Returns the vertex at a specific zero-based index.

```swift
public func vertex(at index: Int) -> SIMD3<Double>?
```

- **Parameters:** `index` — zero-based vertex index.
- **Returns:** Vertex position, or `nil` if index is out of bounds.
- **OCCT:** `TopExp::MapShapes` + `BRep_Tool::Pnt` (via `OCCTShapeGetVertexAt`).

---

## Selective Fillet / Draft / Defeaturing

### `PipeSweepMode`

Orientation mode for advanced pipe sweep.

```swift
public enum PipeSweepMode: Sendable {
    case frenet
    case correctedFrenet
    case fixed(binormal: SIMD3<Double>)
    case auxiliary(spine: Wire)
}
```

- `.frenet` — standard Frenet trihedron; profile tracks spine curvature.
- `.correctedFrenet` — avoids twist at inflection points.
- `.fixed(binormal:)` — fixed binormal direction; profile keeps constant orientation.
- `.auxiliary(spine:)` — twist controlled by a secondary curve.

---

### `PipeTransitionMode`

Transition behaviour at spine discontinuities.

```swift
public enum PipeTransitionMode: Int32, Sendable {
    case transformed = 0
    case rightCorner = 1
    case roundCorner = 2
}
```

---

### `filleted(edges:radius:)`

Fillets specific edges with a uniform radius.

```swift
public func filleted(edges: [Edge], radius: Double) -> Shape?
```

- **Parameters:** `edges` — edges to fillet (must have valid `index` values from this shape); `radius` — fillet radius (must be > 0).
- **Returns:** Filleted shape, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTShapeFilletEdges`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)
  let edges = box.subShapes(ofType: .edge).compactMap { Edge($0) }
  if let rounded = box.filleted(edges: Array(edges.prefix(4)), radius: 1.0) { }
  ```

---

### `filleted(edges:startRadius:endRadius:)`

Fillets specific edges with a linear radius interpolation.

```swift
public func filleted(edges: [Edge], startRadius: Double, endRadius: Double) -> Shape?
```

The radius varies linearly from `startRadius` at the start of each edge to `endRadius` at its end.

- **Parameters:** `edges` — edges to fillet; `startRadius` — radius at edge start (> 0); `endRadius` — radius at edge end (> 0).
- **Returns:** Filleted shape, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet` with law-driven radius (via `OCCTShapeFilletEdgesLinear`).

---

### `drafted(faces:direction:angle:neutralPlane:)`

Adds draft angles to faces for mold release.

```swift
public func drafted(
    faces: [Face],
    direction: SIMD3<Double>,
    angle: Double,
    neutralPlane: (point: SIMD3<Double>, normal: SIMD3<Double>)
) -> Shape?
```

- **Parameters:**
  - `faces` — faces to add draft to (must have valid `index` values).
  - `direction` — pull direction (typically the mold-open direction).
  - `angle` — draft angle in radians (typically 1–5°).
  - `neutralPlane` — point and normal of the plane where draft angle is zero.
- **Returns:** Drafted shape, or `nil` on failure.
- **OCCT:** `OCCTShapeDraft` (internal `Draft_MakeDraft`-based implementation).

---

### `withoutFeatures(faces:)`

Removes faces and heals the resulting gaps by extending adjacent faces.

```swift
public func withoutFeatures(faces: [Face]) -> Shape?
```

Useful for simplifying imported geometry or removing small features before analysis.

- **Parameters:** `faces` — faces to remove (must have valid `index` values from this shape).
- **Returns:** Shape with features removed, or `nil` on failure.
- **OCCT:** `BOPAlgo_Defeaturing` (via `OCCTShapeRemoveFeatures`).

---

## Advanced / Variable-Section Pipe Sweep

### `Shape.pipeShell(spine:profile:mode:solid:)`

Creates a pipe sweep with advanced orientation mode control.

```swift
public static func pipeShell(
    spine: Wire,
    profile: Wire,
    mode: PipeSweepMode = .frenet,
    solid: Bool = true
) -> Shape?
```

- **Parameters:**
  - `spine` — path wire.
  - `profile` — profile wire to sweep.
  - `mode` — sweep orientation mode (`.frenet`, `.correctedFrenet`, `.fixed(binormal:)`, `.auxiliary(spine:)`).
  - `solid` — `true` = solid result; `false` = shell.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell`.
- **Example:**
  ```swift
  let spine = Wire.helix(origin: .zero, axis: SIMD3(0,0,1), radius: 10, pitch: 5, turns: 3)!
  let profile = Wire.circle(radius: 1)!
  let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet)
  ```

---

### `Shape.pipeShellWithTransition(spine:profile:mode:transition:solid:)`

Creates a pipe sweep with both orientation mode and spine-corner transition control.

```swift
public static func pipeShellWithTransition(
    spine: Wire,
    profile: Wire,
    mode: PipeSweepMode = .frenet,
    transition: PipeTransitionMode = .transformed,
    solid: Bool = true
) -> Shape?
```

- **Parameters:**
  - `spine`, `profile` — as for `pipeShell`.
  - `mode` — orientation mode (`.frenet` or `.correctedFrenet`; other modes fall back to Frenet).
  - `transition` — corner transition style.
  - `solid` — produce a solid when `true`.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell`.

---

### `Shape.pipeShellWithLaw(spine:profile:law:solid:)`

Sweeps a profile along a spine with a law function controlling cross-section scaling.

```swift
public static func pipeShellWithLaw(
    spine: Wire,
    profile: Wire,
    law: LawFunction,
    solid: Bool = true
) -> Shape?
```

The law value defines how the profile scales along the spine: 1.0 = no scaling, 2.0 = double size.

- **Parameters:** `spine` — path wire; `profile` — profile wire; `law` — a `LawFunction` defining the scale along the spine; `solid` — produce a solid.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell` with law function (via `OCCTShapeCreatePipeShellWithLaw`).

---

### `Shape.pipeShellMultiSection(spine:profiles:mode:withContact:withCorrection:solid:)`

Sweeps multiple profiles along a spine for a variable-section result.

```swift
public static func pipeShellMultiSection(
    spine: Wire,
    profiles: [Wire],
    mode: PipeSweepMode = .frenet,
    withContact: Bool = false,
    withCorrection: Bool = false,
    solid: Bool = true
) -> Shape?
```

Each profile is positioned in 3D at its station along the spine, and OCCT interpolates a smooth solid that passes through every section. Supports all `PipeSweepMode` cases, including `.auxiliary(spine:)` for twist control.

- **Parameters:**
  - `spine` — path wire.
  - `profiles` — section wires, each pre-positioned at its station (at least one required).
  - `mode` — orientation mode.
  - `withContact` — if `true`, each profile is moved to touch the spine.
  - `withCorrection` — if `true`, each profile is rotated to stay orthogonal to the spine.
  - `solid` — produce a solid when `true`.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell` multi-profile form (via `OCCTShapeCreatePipeShellMultiSection`).

---

### `Shape.helicalSweep(profiles:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)`

Sweeps one or more profiles along a helix to build a helicoid (worm / screw-thread rib).

```swift
public static func helicalSweep(profiles: [Wire],
                                 axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 radius: Double,
                                 pitch: Double,
                                 turns: Double,
                                 clockwise: Bool = false,
                                 solid: Bool = true) -> Shape?
```

Builds the helix spine and an auxiliary spine that spans the full axial extent internally, then delegates to `pipeShellMultiSection(mode: .auxiliary(...))`. One profile gives a uniform rib; two or more give a varying section.

- **Parameters:**
  - `profiles` — rib profile wires positioned in the (radial, axis) plane (at least one).
  - `axisOrigin` — a point on the worm axis.
  - `axisDirection` — worm axis direction.
  - `radius` — helix pitch radius (must be > 0).
  - `pitch` — axial advance per turn (must be > 0).
  - `turns` — number of turns (must be > 0).
  - `clockwise` — helix handedness.
  - `solid` — produce a solid when `true`.
- **Returns:** The swept helicoid, or `nil` on failure.
- **OCCT:** `Wire.helix` + `BRepOffsetAPI_MakePipeShell` auxiliary-spine mode.
- **Note:** The auxiliary-spine framing is approximately radial, not exactly — results bulge ~10–15% beyond the nominal radius for moderate profiles, and balloon severely for fine-pitch V-forms. Use `threadedShaft` / `threadedHole` for precise fastener threads. Do **not** boolean this helicoid with a coaxial cylinder — coincident faces cause BOP to fail (see OCCTSwift #225, #213, #181). Use `threadedRod(customProfile:...)` instead.
- **Example:**
  ```swift
  let profile = Wire.rectangle(width: 3, height: 2)!  // rib cross-section
  let worm = Shape.helicalSweep(profiles: [profile],
                                 axisOrigin: .zero,
                                 axisDirection: SIMD3(0, 0, 1),
                                 radius: 15, pitch: 8, turns: 4)
  ```

---

### `Shape.helicalSweep(profile:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)`

Single-profile convenience overload for `helicalSweep(profiles:...)`.

```swift
public static func helicalSweep(profile: Wire,
                                 axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 radius: Double,
                                 pitch: Double,
                                 turns: Double,
                                 clockwise: Bool = false,
                                 solid: Bool = true) -> Shape?
```

Calls `helicalSweep(profiles: [profile], ...)`.

---

## Surface Creation (v0.9.0)

### `Shape.surface(poles:uDegree:vDegree:)`

Creates a B-spline surface face from a 2D grid of control points.

```swift
public static func surface(
    poles: [[SIMD3<Double>]],
    uDegree: Int = 3,
    vDegree: Int = 3
) -> Shape?
```

`poles` is indexed `[uIndex][vIndex]`. Requires at least `uDegree + 1` rows and `vDegree + 1` columns.

- **Parameters:**
  - `poles` — 2D array of control points.
  - `uDegree` — degree in U (default 3, cubic).
  - `vDegree` — degree in V (default 3, cubic).
- **Returns:** A face shape backed by the B-spline surface, or `nil` on failure.
- **OCCT:** `Geom_BSplineSurface` + `BRepBuilderAPI_MakeFace` (via `OCCTShapeCreateBSplineSurface`).
- **Example:**
  ```swift
  let poles: [[SIMD3<Double>]] = [
      [SIMD3(0,0,0), SIMD3(0,10,0), SIMD3(0,20,0), SIMD3(0,30,0)],
      [SIMD3(10,0,2), SIMD3(10,10,2), SIMD3(10,20,2), SIMD3(10,30,2)],
      [SIMD3(20,0,2), SIMD3(20,10,2), SIMD3(20,20,2), SIMD3(20,30,2)],
      [SIMD3(30,0,0), SIMD3(30,10,0), SIMD3(30,20,0), SIMD3(30,30,0)]
  ]
  let surf = Shape.surface(poles: poles)
  ```

---

### `Shape.ruled(profile1:profile2:)`

Creates a ruled surface between two wires.

```swift
public static func ruled(profile1: Wire, profile2: Wire) -> Shape?
```

Connects corresponding points on the two boundary wires with straight lines. Returns a shell.

- **Parameters:** `profile1` — first boundary wire; `profile2` — second boundary wire.
- **Returns:** A shell shape containing the ruled surface, or `nil` on failure.
- **OCCT:** `BRepFill::Shell(wire1, wire2)` (via `OCCTShapeCreateRuled`).
- **Example:**
  ```swift
  let bottom = Wire.circle(radius: 10)!
  let top = Wire.circle(radius: 5)!.translated(by: SIMD3(0, 0, 20))
  let cone = Shape.ruled(profile1: bottom, profile2: top)
  ```

---

### `shelled(thickness:openFaces:)`

Creates a hollow solid with specific faces left open.

```swift
public func shelled(thickness: Double, openFaces: [Face]) -> Shape?
```

- **Parameters:** `thickness` — wall thickness (positive = inward, negative = outward); `openFaces` — faces to leave open (must have valid `index` values).
- **Returns:** Shelled shape with specified faces open, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid::MakeThickSolidByJoin` (via `OCCTShapeShellWithOpenFaces`).
- **Example:**
  ```swift
  let box = Shape.box(width: 20, height: 20, depth: 20)
  let tops = box.subShapes(ofType: .face).compactMap { Face($0) }.filter { $0.normal?.z ?? 0 > 0.9 }
  let openBox = box.shelled(thickness: 2.0, openFaces: tops)
  ```

---

## Shape Healing / Analysis (v0.13.0)

### `ShapeAnalysisResult`

Result of a shape analysis scan.

```swift
public struct ShapeAnalysisResult {
    public let smallEdgeCount: Int
    public let smallFaceCount: Int
    public let gapCount: Int
    public let selfIntersectionCount: Int
    public let freeEdgeCount: Int
    public let freeFaceCount: Int
    public let hasInvalidTopology: Bool
    public var totalProblems: Int { get }
    public var isHealthy: Bool { get }
}
```

`isHealthy` is `true` when `totalProblems == 0 && !hasInvalidTopology`.

---

### `analyze(tolerance:)`

Analyzes a shape for problems such as small edges, gaps, and invalid topology.

```swift
public func analyze(tolerance: Double = 1e-6) -> ShapeAnalysisResult?
```

- **Parameters:** `tolerance` — size threshold for detecting small features.
- **Returns:** `ShapeAnalysisResult` with problem counts, or `nil` if the analysis itself fails.
- **OCCT:** `ShapeAnalysis_Shell` + `ShapeAnalysis_CheckSmallFace` + `BRepCheck_Analyzer` (via `OCCTShapeAnalyze`).
- **Example:**
  ```swift
  if let a = shape.analyze(tolerance: 0.001) {
      if !a.isHealthy { print("\(a.totalProblems) problems found") }
  }
  ```

---

### `fixed(tolerance:fixSolid:fixShell:fixFace:fixWire:)`

Fixes shape problems with detailed control over what to repair.

```swift
public func fixed(tolerance: Double = 1e-6,
                  fixSolid: Bool = true,
                  fixShell: Bool = true,
                  fixFace: Bool = true,
                  fixWire: Bool = true) -> Shape?
```

- **Parameters:**
  - `tolerance` — tolerance for fixing operations.
  - `fixSolid` — whether to fix solid orientation.
  - `fixShell` — whether to fix shell closure.
  - `fixFace` — whether to fix face issues.
  - `fixWire` — whether to fix wire issues.
- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeFix_Shape` (via `OCCTShapeFixDetailed`).
- **Example:**
  ```swift
  // Fix only wire and face issues
  let fixed = shape.fixed(tolerance: 0.001, fixSolid: false, fixShell: false)
  ```

---

### `unified(unifyEdges:unifyFaces:concatBSplines:)`

Merges faces and edges that lie on the same geometry after boolean operations.

```swift
public func unified(unifyEdges: Bool = true,
                    unifyFaces: Bool = true,
                    concatBSplines: Bool = true) -> Shape?
```

- **Parameters:**
  - `unifyEdges` — merge edges on the same curve.
  - `unifyFaces` — merge faces on the same surface.
  - `concatBSplines` — concatenate adjacent B-spline edges / faces.
- **Returns:** Unified shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_UnifySameDomain` (via `OCCTShapeUnifySameDomain`).
- **Example:**
  ```swift
  let result = box - cyl1 - cyl2
  let clean = result?.unified()
  ```

---

### `withoutSmallFaces(minArea:)`

Removes faces smaller than the given area threshold.

```swift
public func withoutSmallFaces(minArea: Double) -> Shape?
```

- **Parameters:** `minArea` — minimum face area; faces below this are removed.
- **Returns:** Cleaned shape, or `nil` on failure.
- **OCCT:** `ShapeAnalysis_CheckSmallFace` + `ShapeUpgrade_UnifySameDomain` (via `OCCTShapeRemoveSmallFaces`).

---

### `simplified(tolerance:)`

Convenience method combining `unified()` and `healed()`.

```swift
public func simplified(tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `tolerance` — tolerance for simplification.
- **Returns:** Simplified shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_UnifySameDomain` + `ShapeFix_Shape` (via `OCCTShapeSimplify`).

---

### `Wire.fixed(tolerance:)`

Fixes wire problems such as gaps, degenerate edges, and incorrect ordering.

```swift
public func fixed(tolerance: Double = 1e-6) -> Wire?
```

- **Parameters:** `tolerance` — tolerance for fixing.
- **Returns:** Fixed wire, or `nil` on failure.
- **OCCT:** `ShapeFix_Wire` (via `OCCTWireFix`).
- **Example:**
  ```swift
  let fixedWire = problematicWire.fixed(tolerance: 0.001)
  ```

---

### `Face.fixed(tolerance:)`

Fixes face problems such as incorrect wire orientation, missing seams, and surface parameters.

```swift
public func fixed(tolerance: Double = 1e-6) -> Shape?
```

Returns the fixed result as a `Shape` (not `Face`) because the repair can restructure topology.

- **Parameters:** `tolerance` — tolerance for fixing.
- **Returns:** Fixed face as a `Shape`, or `nil` on failure.
- **OCCT:** `ShapeFix_Face` (via `OCCTFaceFix`).

---

## Advanced Blends & Surface Filling (v0.14.0)

### `SurfaceContinuity`

Continuity specification for surface filling operations.

```swift
public enum SurfaceContinuity: Int32 {
    case c0 = 0   // positional — surfaces touch
    case g1 = 1   // tangent — smooth transition
    case g2 = 2   // curvature — very smooth
}
```

---

### `PlateConstraintOrder`

Constraint order for plate surface construction (v0.23.0).

```swift
public enum PlateConstraintOrder: Int32 {
    case g0 = 0   // position only
    case g1 = 1   // position + tangent
    case g2 = 2   // position + tangent + curvature
}
```

---

### `FillingParameters`

Parameters for N-sided surface filling.

```swift
public struct FillingParameters {
    public var continuity: SurfaceContinuity
    public var tolerance: Double
    public var maxDegree: Int
    public var maxSegments: Int

    public init(continuity: SurfaceContinuity = .g1, tolerance: Double = 1e-4,
                maxDegree: Int = 8, maxSegments: Int = 9)
}
```

---

## Variable Radius Fillet (v0.14.0)

### `filletedVariable(edgeIndex:radiusProfile:)`

Applies a variable-radius fillet to a single edge.

```swift
public func filletedVariable(
    edgeIndex: Int,
    radiusProfile: [(parameter: Double, radius: Double)]
) -> Shape?
```

Parameters are normalised from 0.0 (start) to 1.0 (end). At least two profile points are required.

- **Parameters:** `edgeIndex` — index of the edge to fillet; `radiusProfile` — array of `(parameter, radius)` pairs (minimum 2).
- **Returns:** Filleted shape, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet` with law-driven radius (via `OCCTShapeFilletVariable`).
- **Example:**
  ```swift
  // Radius varies from 1 mm at start to 3 mm at end
  let filleted = shape.filletedVariable(
      edgeIndex: 0,
      radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
  )
  ```

---

## Multi-Edge Blend (v0.14.0)

### `blendedEdges(_:)`

Applies fillets to multiple edges, each with its own radius.

```swift
public func blendedEdges(_ edgeRadii: [(edgeIndex: Int, radius: Double)]) -> Shape?
```

- **Parameters:** `edgeRadii` — array of `(edgeIndex, radius)` pairs.
- **Returns:** Filleted shape with per-edge radii applied, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTShapeBlendEdges`).
- **Example:**
  ```swift
  let blended = shape.blendedEdges([
      (0, 1.0),
      (1, 2.0),
      (2, 0.5)
  ])
  ```

---

## Surface Filling (v0.14.0)

### `Shape.fill(boundaries:parameters:)`

Fills an N-sided boundary with a smooth surface.

```swift
public static func fill(
    boundaries: [Wire],
    parameters: FillingParameters = FillingParameters()
) -> Shape?
```

Creates a face that passes through the given boundary wires with the specified continuity. Each wire's edges are added as edge constraints to the filler.

- **Parameters:** `boundaries` — wires defining the boundary (at least one); `parameters` — filling parameters (continuity, tolerance, degree, segments).
- **Returns:** Face shape covering the boundary, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeFilling` (via `OCCTShapeFill`).
- **Example:**
  ```swift
  let w1 = Wire.line(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
  let w2 = Wire.line(from: SIMD3(10,0,0), to: SIMD3(10,10,5))!
  let w3 = Wire.line(from: SIMD3(10,10,5), to: SIMD3(0,10,3))!
  let w4 = Wire.line(from: SIMD3(0,10,3), to: SIMD3(0,0,0))!
  let face = Shape.fill(boundaries: [w1, w2, w3, w4],
                         parameters: FillingParameters(continuity: .g1))
  ```

---

## Plate Surfaces (v0.14.0 / v0.23.0)

### `Shape.plateSurface(through:tolerance:)`

Creates a surface that interpolates through scattered 3D points.

```swift
public static func plateSurface(
    through points: [SIMD3<Double>],
    tolerance: Double = 0.01
) -> Shape?
```

Requires at least 3 points.

- **Parameters:** `points` — 3D points the surface must pass through (minimum 3); `tolerance` — approximation tolerance.
- **Returns:** A face backed by a `GeomPlate_Surface`, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` + `GeomPlate_MakeApprox` + `BRepBuilderAPI_MakeFace` (via `OCCTShapePlatePoints`).
- **Example:**
  ```swift
  let face = Shape.plateSurface(through: [
      SIMD3(0,0,0), SIMD3(10,0,1), SIMD3(10,10,2),
      SIMD3(0,10,1), SIMD3(5,5,3)
  ], tolerance: 0.01)
  ```

---

### `Shape.plateSurface(constrainedBy:continuity:tolerance:)`

Creates a plate surface constrained by boundary curves.

```swift
public static func plateSurface(
    constrainedBy curves: [Wire],
    continuity: SurfaceContinuity = .g1,
    tolerance: Double = 0.01
) -> Shape?
```

- **Parameters:** `curves` — wires defining the boundary constraints (at least one); `continuity` — continuity requirement at boundaries; `tolerance` — approximation tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` with curve constraints (via `OCCTShapePlateCurves`).

---

### `Shape.plateSurface(through:orders:degree:pointsOnCurves:iterations:tolerance:)` (v0.23.0)

Creates a plate surface through points with per-point constraint orders.

```swift
public static func plateSurface(
    through points: [SIMD3<Double>],
    orders: [PlateConstraintOrder],
    degree: Int = 3,
    pointsOnCurves: Int = 15,
    iterations: Int = 2,
    tolerance: Double = 0.01
) -> Shape?
```

Each point independently specifies G0 (position), G1 (position + tangent), or G2 (position + tangent + curvature) continuity.

- **Parameters:**
  - `points` — 3D points (minimum 3); must match `orders.count`.
  - `orders` — per-point constraint orders.
  - `degree` — maximum polynomial degree (default 3).
  - `pointsOnCurves` — sample points on internal curves (default 15).
  - `iterations` — solver iterations (default 2).
  - `tolerance` — approximation tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` + `NLPlate_NLPlate` + `GeomPlate_MakeApprox` (via `OCCTShapePlatePointsAdvanced`).

---

### `Shape.plateSurface(pointConstraints:curveConstraints:degree:tolerance:)` (v0.23.0)

Creates a plate surface with mixed point and curve constraints.

```swift
public static func plateSurface(
    pointConstraints points: [(point: SIMD3<Double>, order: PlateConstraintOrder)],
    curveConstraints curves: [(wire: Wire, order: PlateConstraintOrder)],
    degree: Int = 3,
    tolerance: Double = 0.01
) -> Shape?
```

At least one of `points` or `curves` must be non-empty.

- **Parameters:**
  - `points` — point constraints, each with a position and a `PlateConstraintOrder`.
  - `curves` — curve constraints, each with a `Wire` and a `PlateConstraintOrder`.
  - `degree` — maximum polynomial degree (default 3).
  - `tolerance` — approximation tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` with `GeomPlate_PointConstraint` + `GeomPlate_CurveConstraint` (via `OCCTShapePlateMixed`).
- **Example:**
  ```swift
  let boundary = Wire.rectangle(width: 20, height: 20)!
  let face = Shape.plateSurface(
      pointConstraints: [(SIMD3(10, 10, 5), .g0)],
      curveConstraints: [(boundary, .g1)]
  )
  ```
