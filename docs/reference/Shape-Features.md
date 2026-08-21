---
title: Shape. Features, Sweeps & Surface Building
parent: API Reference
---

# Shape. Features, Sweeps & Surface Building

This page documents the Shape API from **Geometry Construction** through **Plate Surfaces** in `Shape.swift`. It covers face and solid assembly, feature-based modeling (bosses, pockets, holes, patterns), shape inspection, slicing, measurement, advanced pipe sweeps, surface building, and healing. For the primitive factories, boolean operations, and transforms that precede this range, see the main **Shape** index page (not yet written; use `Surface.md` as an exemplar for style).

## Topics

- [Geometry Construction](#geometry-construction-v0110) · [Feature-Based Modeling](#feature-based-modeling-v0120) · [Shape Type](#shape-type) · [Sub-Shape Extraction](#sub-shape-extraction) · [Bounds](#bounds) · [Slicing](#slicing) · [Operators](#operators) · [Measurement & Analysis](#measurement--analysis-v070) · [Convenience Overloads](#wireenface-convenience-overloads) · [Selective Fillet / Draft / Defeaturing](#selective-fillet-draft--defeaturing) · [Advanced / Variable-Section Pipe Sweep](#advanced--variable-section-pipe-sweep) · [Surface Creation](#surface-creation-v090) · [Shape Healing / Analysis / Fixing / Unification](#shape-healing--analysis-v0130) · [Advanced Blends & Surface Filling](#advanced-blends--surface-filling-v0140) · [Variable Radius Fillet](#variable-radius-fillet-v0140) · [Multi-Edge Blend](#multi-edge-blend-v0140) · [Surface Filling](#surface-filling) · [Plate Surfaces](#plate-surfaces-v0140--v0230)

---

## Geometry Construction (v0.11.0)

### `Shape.face(from:planar:)`

Creates a planar face from a closed wire.

```swift
public static func face(from wire: Wire, planar: Bool = true) -> Shape?
```

- **Parameters:** `wire`, a closed wire defining the face boundary; `planar`, if `true` (default), requires the wire to be planar.
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

- **Parameters:** `outer`, the outer boundary wire (closed); `holes`, array of inner boundary wires, each defining a hole. **Any hole winding is accepted** (see below).
- **Returns:** A face with holes, or `nil` on failure.
- **Winding contract:** For a valid planar face, each hole must wind **opposite** to the outer boundary (measured in the face plane). You do not have to pre-orient your holes: the function measures each hole's signed area against the outer's and reverses a hole **only when its winding currently matches the outer's**. A hole passed already wound opposite (the geometrically correct sense) is kept as-is; a hole wound the same way as the outer is reversed for you. Either input yields the same valid face with the hole correctly subtracted. (Before [#274](https://github.com/SecondMouseAU/OCCTSwift/issues/274) every hole was reversed unconditionally, which broke callers that already passed the correct opposite winding.)
- **OCCT:** `BRepBuilderAPI_MakeFace(outer, planar)` + `BRepBuilderAPI_MakeFace::Add` for each inner wire, with the wire's relative winding decided by `BRepBuilderAPI_FindPlane` + a signed-area projection onto the face plane.
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

One solid is built per **body-bounding** shell, not just the first shell found: every shell that an *even* number of the other shells in its group enclose, where a group is one solid's own shells, or all the shells belonging to no solid (the usual shape of sewing output). A single body comes back as a solid, several as a compound in exploration order. This is the same selection ``Shape.solidFromShellFixed()`` makes, so the two agree on any input.

*Cavity* shells are skipped: a hole is not a body, and building one as a positive solid would return a compound whose volume double-counts the part. A body nested inside another body's cavity is enclosed twice, so it is still read as a body. To rebuild a solid that keeps its cavities, use `Shape.solidFromShells(_:)` with the outer shell first.

- **Parameters:** `shell`, a shell shape (from sewing or face assembly).
- **Returns:** A solid, a compound of solids for multi-body input, or `nil` if the shape holds no shell at all.
- **OCCT:** `BRepBuilderAPI_MakeSolid(shell)` + `ShapeFix_Solid` (orientation).
- **Example:**
  ```swift
  let sewn = Shape.sew(shapes: faces, tolerance: 1e-6)!
  let solid = Shape.solid(from: sewn)!

  // Sewing two disjoint bodies yields two shells, so this yields two solids.
  let both = Shape.solid(from: Shape.sew(shapes: [bodyA, bodyB], tolerance: 1e-6)!)!
  print(both.solids.count)   // 2
  ```

---

### `Shape.sew(shapes:tolerance:)`

Sews multiple shapes into a connected shell or solid.

```swift
public static func sew(shapes: [Shape], tolerance: Double = 1e-6) -> Shape?
```

Connects faces that share edges within `tolerance`. Useful for repairing imported geometry or joining separately created faces. If the result is closed, OCCT promotes it to a solid.

- **Parameters:** `shapes`, array of shapes (faces, shells) to sew; `tolerance`, maximum gap size to close (default 1e-6).
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

- **Parameters:** `shape`, first shape; `other`, second shape; `tolerance`, gap tolerance.
- **Returns:** Sewn shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Sewing` (two-argument convenience).

---

### `sewn(with:tolerance:)`

Sews this shape with another (instance method).

```swift
public func sewn(with other: Shape, tolerance: Double = 1e-6) -> Shape?
```

Calls `Shape.sew(self, with: other, tolerance:)`.

- **Parameters:** `other`, shape to sew with; `tolerance`, gap tolerance.
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

- **Parameters:** `profile`, wire profile to extrude; `direction`, extrusion direction; `height`, feature height; `fuse`, `true` = add material, `false` = remove material.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakePrism` + `BRepAlgoAPI_Fuse` or `BRepAlgoAPI_Cut`.
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

- **Parameters:** `profile`, profile wire; `direction`, extrusion direction; `height`, boss height.
- **Returns:** Shape with added boss, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakePrism` + `BRepAlgoAPI_Fuse`, through `withPrism(..., fuse: true)`.

---

### `withPocket(profile:direction:depth:)`

Creates a depression (pocket) in the shape. Convenience wrapper for `withPrism(..., fuse: false)`.

```swift
public func withPocket(profile: Wire, direction: SIMD3<Double>, depth: Double) -> Shape?
```

- **Parameters:** `profile`, profile wire defining the pocket boundary; `direction`, pocket direction (into the shape); `depth`, pocket depth.
- **Returns:** Shape with pocket, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakePrism` + `BRepAlgoAPI_Cut`, through `withPrism(..., fuse: false)`.

---

### `drilled(at:direction:radius:depth:)`

Drills a cylindrical hole into the shape.

```swift
public func drilled(at position: SIMD3<Double>, direction: SIMD3<Double>,
                    radius: Double, depth: Double = 0) -> Shape?
```

`depth: 0` creates a through-hole (the cylinder is made large enough to penetrate the shape entirely).

The bore is cut **along `direction`**, any axis, not just Z. `direction` is normalized internally; a zero/degenerate direction returns `nil`.

The cutting cylinder **starts at `position`** and runs `depth` along `direction`. So an entry point inside the shape drills only forward from there, a `depth` that overshoots the far face costs nothing, and the input can be a shell or a face as readily as a solid.

`radius` must exceed `Precision::Confusion` (1e-7). Below that, OCCT cuts nothing and reports success (#496), so the bridge rejects it.

#### Or the feature drill

[`cylindricalHole(axisOrigin:axisDirection:radius:extent:)`](Shape-Builders-2.md#cylindricalholeaxisoriginaxisdirectionradiusextent) wraps `BRepFeat_MakeCylindricalHole`, OCCT's dedicated feature-drilling operator. It is **not a better version of this method**, #496 measured six requests where the two disagree, and neither subsumes the other:

| reach for | when |
|---|---|
| `drilled(at:…)` | the hole starts where you say it starts; the input is not a solid; an over-long `depth` should simply drill through |
| `cylindricalHole(…extent:)` | the **solid's own faces** should bound the hole (`.untilEnd`, `.thruNext`); you need a diagnosis of *why* a drill is impossible |

- **Parameters:** `position`, hole-centre point on the entry face; `direction`, drill direction (into the shape), any non-zero axis; `radius`, hole radius, above `Precision::Confusion`; `depth`, hole depth, or `0` for through-hole.
- **Returns:** Shape with drilled hole, or `nil` on failure (including a zero-length `direction` or a degenerate `radius`).
- **OCCT:** `BRepPrimAPI_MakeCylinder` (oriented via `gp_Ax2(position, direction)`) + `BRepAlgoAPI_Cut` (internal cylinder cutter).
- **Example:**
  ```swift
  let plate = Shape.box(width: 50, height: 50, depth: 10)
  if let drilled = plate.drilled(at: SIMD3(25, 25, 10), direction: SIMD3(0, 0, -1),
                                   radius: 5, depth: 0) {
      // through-hole down the Z axis, centred at (25, 25)
  }

  // A hole bored across the width (+X), e.g. a bolt hole through a bar:
  let bar = Shape.box(width: 200, height: 60, depth: 16)
  let cross = bar?.drilled(at: SIMD3(-101, 0, 0), direction: SIMD3(1, 0, 0),
                           radius: 6.5, depth: 0)   // bore runs along +X, not Z
  ```

---

### `split(by:)`

Splits the shape using a cutting tool shape.

```swift
public func split(by tool: Shape) -> [Shape]?
```

- **Parameters:** `tool`, shape to use as cutting tool (typically a face or solid).
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

- **Parameters:** `point`, a point on the cutting plane; `normal`, plane normal direction.
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

- **Parameters:** `shape1`, first shape; `shape2`, second shape with coincident faces; `tolerance`, face-matching tolerance.
- **Returns:** Glued shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` with glue option.

---

### `Shape.evolved(spine:profile:)`

Creates an evolved shape (profile swept along spine with orientation tracking).

```swift
public static func evolved(spine: Wire, profile: Wire) -> Shape?
```

The profile is swept along the spine and its orientation evolves to remain perpendicular to the spine tangent.

- **Parameters:** `spine`, path wire; `profile`, profile wire to sweep.
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
  - `spine`: spine shape (any topology accepted).
  - `profile`: profile wire.
  - `joinType`: how to join offset edges at corners (default `.arc`).
  - `axeProf`: if `true`, profile is in global coordinates; if `false`, local to the spine.
  - `solid`: produce a solid result when `true`.
  - `volume`: use volume mode (removes self-intersections) when `true`.
  - `tolerance`: construction tolerance.
- **Returns:** Evolved shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeEvolved`.

---

### `linearPattern(direction:spacing:count:)`

Creates a linear array of this shape.

```swift
public func linearPattern(direction: SIMD3<Double>, spacing: Double, count: Int) -> Shape?
```

Returns a compound containing `count` copies of the shape, spaced `spacing` apart along `direction`.

- **Parameters:** `direction`, pattern direction vector; `spacing`, distance between copies; `count`, number of copies (including the original).
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

Duplicates the **entire body** `count` times around `axisPoint`/`axisDirection` and returns a compound. It does **not** pattern features, to replicate a cut feature, see `circularPatternCut(tool:...)`.

- **Parameters:** `axisPoint`, point on the rotation axis; `axisDirection`, axis direction; `count`, number of copies (including original); `angle`, total arc to span in radians (`0` = full circle).
- **Returns:** Compound of all copies, or `nil` on failure.
- **OCCT:** `gp_Trsf::SetRotation` applied iteratively.
- **Example:**
  ```swift
  let holeTool = Shape.cylinder(radius: 3, height: 20).translated(by: SIMD3(40, 0, 0))
  let tools = holeTool.circularPattern(axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 6)
  let drilled = flange.subtracting(tools!)
  ```

---

### `circularPatternCut(tool:axisPoint:axisDirection:count:angle:timeout:)`

Replicates a cut feature around an axis and subtracts all copies from this body.

```swift
public func circularPatternCut(tool: Shape, axisPoint: SIMD3<Double>,
                                axisDirection: SIMD3<Double>, count: Int,
                                angle: Double = 0,
                                timeout: Double = Shape.defaultBooleanTimeout) -> Shape?
```

Combines `circularPattern` of `tool` with `subtracting` in a single call. The natural primitive for bolt circles.

- **Parameters:** `tool`, the cutting feature (e.g. a cylinder at the first hole position); `axisPoint`, rotation axis point; `axisDirection`, axis direction; `count`, number of tool copies (including original); `angle`, arc span in radians (`0` = full circle); `timeout`, wall-clock bound in seconds for the closing subtraction (`0`/negative = unbounded).
- **Returns:** This body with all `count` features cut out, or `nil` on failure.
- **OCCT:** `circularPattern` + `BRepAlgoAPI_Cut`.
- **⚠️ Three indistinguishable `nil`s.** `count <= 0`, the pattern failing, and the subtraction failing or exceeding `timeout` all return the same `nil`. Before [#1067](https://github.com/SecondMouseAU/OCCTSwift/issues/1067) the 120s bound applied here but was not reachable from this signature at all, so a caller whose cut was legitimately long could not raise it. A caller who needs to tell the three apart runs the two steps directly, which is all this method does.
- **Example:**
  ```swift
  let hole = Shape.cylinder(radius: 3, height: 20).translated(by: SIMD3(40, 0, 0))
  let flangeWithHoles = blank.circularPatternCut(
      tool: hole, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 8
  )

  // A legitimately long cut: raise the bound rather than getting nil at 120s.
  let gear = blank.circularPatternCut(
      tool: toothSpace, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1),
      count: 36, timeout: 600
  )

  // Decomposed, when the three nils have to be told apart:
  guard let tools = toothSpace.circularPattern(
      axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 36) else { return }
  switch blank.subtractionOutcome(tools, timeout: 600) {
  case .success(let cut): print(cut.volume as Any)
  case .timedOut:         print("the machine, not the geometry")
  case .failed:           print("the geometry")
  }
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

#### `ShapeType.compSolid`

A composite solid (`TopAbs_COMPSOLID`): several solids sharing faces, treated as one connected block.

#### `ShapeType.unknown`

No recognised topological type; matches no `TopAbs_ShapeEnum` value.

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

Runs `BRepCheck_Analyzer`, a **topology** check only. It does not detect global self-intersection (overlapping faces). A self-intersecting B-spline solid can pass this check yet cause booleans to hang or return garbage. Use `isSelfIntersecting(timeout:)` for the complementary geometric check.

Checks `shapeType == .solid` first and returns `false` immediately otherwise, so it is the
reliable way to notice a `healed()`/`fixSolid()` demotion (#702): a shell they could not close
reads `false` here even though plain `isValid` reads `true` on it (a shell has no closure
requirement of its own).

- **Returns:** `true` if `shapeType == .solid` and `BRepCheck_Analyzer` reports no errors.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTShapeIsValidSolid`).

---

### `isSelfIntersecting(timeout:)`

Checks whether the shape has overlapping or interfering sub-faces.

```swift
public func isSelfIntersecting(timeout: Double = 30) -> Bool?
```

Backed by `BOPAlgo_ArgumentAnalyzer`'s self-interference test. Expensive (seconds on B-spline solids).

- **Important:** `timeout` is **cooperative, not a hard deadline** (#293), it's checked only when OCCT polls its progress indicator, and the self-interference phase has at least one long checkpoint-free stretch that can overrun `timeout` arbitrarily (observed 20+ minutes past a 30s bound on pathological B-spline solids). The calling thread blocks inside the call the whole time. For a true wall-clock guarantee, run it in a subprocess/worker you can kill yourself.
- **Important:** `true` means a **completed** analysis recorded a `BOPAlgo_SelfIntersect` result, and nothing else (#1054). An aborted analysis is `nil` even when it recorded results first: `BOPAlgo_CheckerSI::PostTreat` is what discards the adjacency interferences every valid solid has, and it runs last, so a clean shape interrupted between the face-face pass and `PostTreat` reports self-interferences of its own. Measured on a plain 10x10x10 box by breaking at each of its 381 progress polls in turn: 68 of them yield one to three `BOPAlgo_SelfIntersect` results and one yields `BOPAlgo_OperationAborted`, against zero faults for the uninterrupted run. A shape the analyzer rejects outright is `nil` too, for the separate reason below.
- **Important:** the analyzer runs with `ArgumentTypeMode` as well as `SelfInterMode`, so it can record `BOPAlgo_BadType` for an argument Boolean Operations cannot use (an empty compound is the reachable case: `BOPTools_AlgoTools3D::IsEmptyShape` is true for it). That is `nil`, not `true`. Reading `HasFaulty()` instead of the statuses is what used to make it `true`.
- **Parameters:** `timeout`, seconds before the check *asks* OCCT to give up (default 30); the actual return can be later. `0` or negative = unbounded.
- **Returns:** `true` = self-interference found; `false` = shape is clean; `nil` = indeterminate (timed out, rejected, or errored, treat as "unknown", not "clean").
- **OCCT:** `BOPAlgo_ArgumentAnalyzer` (via `OCCTShapeSelfIntersectsBounded`), reading `GetCheckResult()` rather than `HasFaulty()`.
- **Example:**
  ```swift
  guard let solid = Shape.loft(profiles: ps, ruled: false)?.orientedForward(),
        solid.isSelfIntersecting() == false else { /* reject */ return }
  ```

---

### `isSelfIntersecting(hardTimeout:)`

Checks whether the shape has overlapping or interfering sub-faces, with a true hard wall-clock deadline (#319): unlike `isSelfIntersecting(timeout:)`, this returns at `hardTimeout` even if OCCT never reaches a checkpoint to poll.

```swift
public func isSelfIntersecting(hardTimeout: Double) -> Bool?
```

Runs the check on a detached background thread against a `deepCopy()` of this shape (independent geometry) and waits on the calling thread with a real deadline. If the deadline passes first, this returns `nil` immediately and the background computation is abandoned, not cancelled: it keeps running orphaned on its own thread until it eventually completes. That is a deliberate trade (burned CPU for a caller-side wall-clock guarantee).

- **Parameters:** `hardTimeout`: seconds to wait before giving up and returning `nil`.
- **Returns:** `true`/`false` if the check completed in time; `nil` if the deadline passed first (indeterminate, the background check may still be running) or if the analysis could not answer the question, per `isSelfIntersecting(timeout:)`. Its inner call passes `0` (unbounded), so the aborted-analysis case above cannot arise here, but the `BOPAlgo_BadType` one can.
- **OCCT:** `BOPAlgo_ArgumentAnalyzer` (via `OCCTShapeSelfIntersectsBounded`), on a background `DispatchQueue`.
- **Example:**
  ```swift
  switch solid.isSelfIntersecting(hardTimeout: 5) {
  case .some(true):  print("self-intersects")
  case .some(false): print("clean")
  case .none:        print("deadline hit, treat as unknown, not clean")
  }
  ```

---
### `ImportError`

Error type for failed STEP/IGES/BREP imports.

```swift
public enum ImportError: Error, LocalizedError {
    case importFailed(String)
    case cancelled
    public var errorDescription: String? { get }
}
```

- `importFailed`: carries a human-readable message describing why the import failed.
- `cancelled`: the import was cancelled via `ImportProgress.shouldCancel()`.

| Case / Property | Meaning |
|---|---|
| `.importFailed(_:)` | The import failed; the associated string is a human-readable reason. |
| `.cancelled` | The import was cancelled via `ImportProgress.shouldCancel()`. |
| `errorDescription` | `LocalizedError` conformance: the associated message for `.importFailed`, or a fixed string for `.cancelled`. |

#### `ImportError.errorDescription`

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
    public let solidsCreated: Int
    public var summary: String { get }
}
```

`summary` returns a human-readable description such as `"Shell → Solid (processing: sewing, solid creation)"`.

---

#### `ImportResult.originalType`

The shape type as read from the STEP file, before any processing.

#### `ImportResult.resultType`

The shape type after processing.

#### `ImportResult.sewingApplied`

`true` if sewing was applied to connect disconnected faces.

#### `ImportResult.solidCreated`

`true` if a solid was created from a shell.

#### `ImportResult.healingApplied`

`true` if shape healing was applied.

#### `ImportResult.solidsCreated`

How many shells were turned into solids. `> 1` means the file held several bodies and `shape` is a compound of that many solids. Before v1.11.3 every body after the first was silently discarded, so this count is the fact that was quietly wrong: a truncated import still returned a perfectly valid solid (#302).

#### `ImportResult.summary`

Human-readable description such as `"Shell -> Solid (processing: sewing, solid creation)"`.

---

## Sub-Shape Extraction

This is the one sub-shape enumeration in the API. `solids`/`shells`/`wires`, `faceCount`,
`edgeCount`, `vertexCount`, `face(at:)`, `edge(at:)` and `uniqueSubShapeCount(ofType:)` all read it,
so their answers agree with these by construction (#502). Each entry is a **distinct** sub-shape,
meaning `TopoDS_Shape::IsSame`: same underlying geometry *and* same placement, orientation ignored.

### `subShapeCount(ofType:)`

Returns the number of distinct sub-shapes of a given topological type.

```swift
public func subShapeCount(ofType type: ShapeType) -> Int
```

- **Parameters:** `type`, the topological type to count (e.g. `.face`, `.edge`, `.vertex`).
- **Returns:** Count of distinct sub-shapes of that type; `0` for `.unknown`.
- **OCCT:** `TopExp::MapShapes` (via `OCCTShapeGetSubShapeCount`).
- **Note:** A sub-shape reachable from more than one parent counts once: a box has 12 edges, not
  the 24 edge-in-face occurrences a raw `TopExp_Explorer` walk yields. Two *placements* of one body
  count twice, since the location is part of the comparison.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  print(box.subShapeCount(ofType: .face))    // 6
  print(box.subShapeCount(ofType: .edge))    // 12
  print(box.subShapeCount(ofType: .vertex))  // 8
  print(box.subShapeCount(ofType: .solid))   // 1, the box itself
  ```

---

### `subShape(type:index:)`

Returns a sub-shape by topological type and zero-based index.

```swift
public func subShape(type: ShapeType, index: Int) -> Shape?
```

Uses `TopExp::MapShapes` to enumerate sub-shapes of the given type.

- **Parameters:** `type`, topological type; `index`, zero-based index.
- **Returns:** The sub-shape as a `Shape`, or `nil` if `index` is out of range.
- **OCCT:** `TopExp::MapShapes` + index lookup (via `OCCTShapeGetSubShapeByTypeIndex`).
- **Note:** Edge indices are not guaranteed to be stable across calls or OCCT versions. Iterate to find a working index for edge-specific operations.

---

### `subShapes(ofType:)`

Returns all distinct sub-shapes of a given topological type as an array, in enumeration order.

```swift
public func subShapes(ofType type: ShapeType) -> [Shape]
```

The array position **is** the ordinal, so `subShapes(ofType: t)[k]` is `subShape(type: t, index: k)`.
Unlike `Face` and `Edge`, a returned `Shape` carries no ordinal of its own, so the position is the
only thing naming which sub-shape an element is; the array is therefore returned complete or empty
and never short, since a sub-shape that could not be built would shift every later ordinal down one
with no error and no diagnostic (#979).

- **Parameters:** `type`, topological type.
- **Returns:** Every distinct sub-shape of that type in enumeration order; empty if the shape has
  none, or if any could not be built.
- **OCCT:** `TopExp::MapShapes` (via `OCCTShapeGetSubShapes`): one walk to size the buffer and one
  to fill it, rather than one per element as reading `subShape(type:index:)` in a loop would cost.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  print(box.subShapes(ofType: .face).count)  // 6
  print(box.subShapes(ofType: .edge).count)  // 12
  ```

---

## Bounds

### `bounds`

Axis-aligned bounding box of the shape.

```swift
public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)? { get }
```

Uses OCCT's default `Bnd_Box`, which for B-spline and faceted surfaces is the **control-point hull** and can over-report the true extent. For a tight AABB use `boundingBoxOptimal()` (`Bnd_Box::AddOptimal`), or the ground-truth min/max of `mesh(...)` vertices.

- **Returns:** Tuple of min and max AABB corners, or `nil` when there is no box. A shape that contributes no geometry to the box (`Bnd_Box::IsVoid()`, e.g. the empty result of a disjoint intersection) returns `nil`. A shape whose box genuinely measures zero, such as a point-vertex at the world origin, returns that all-zero box: the verdict comes from OCCT across the bridge as a `Bool`, never from comparing the returned coordinates against zero (#943).
- **OCCT:** `BRepBndLib::Add` (via `OCCTShapeGetBounds`, which returns `false` for a void box).
- **Note (#834, #943):** `bounds` and [`boundingBox`](Document-Transforms.md) compute the identical `Bnd_Box` through one shared bridge helper and answer `nil` on exactly the same inputs. They used to disagree: `boundingBox` returned `nil` for a void shape while `bounds` fabricated `(0,0,0)-(0,0,0)`.
- **Example:**
  ```swift
  let b = Shape.box(width: 10, height: 5, depth: 3)!.bounds!
  // b.min ≈ SIMD3(0, 0, 0), b.max ≈ SIMD3(10, 5, 3)
  ```

---

### `size`

Size of the bounding box (max − min).

```swift
public var size: SIMD3<Double>? { get }
```

- **Returns:** `bounds.max − bounds.min`, or `nil` when `bounds` is `nil`. `.zero` here is a measurement of a zero-size shape, not a fallback (#943).

---

### `center`

Centre of the bounding box.

```swift
public var center: SIMD3<Double>? { get }
```

- **Returns:** `(bounds.min + bounds.max) / 2`, or `nil` when `bounds` is `nil`. `.zero` here is a measurement of a point-like shape at the world origin, not a fallback (#943).

---

## Slicing

### `sliceAtZ(_:)`

Slices the shape at a given Z height, returning the cross-section as loose edges.

```swift
public func sliceAtZ(_ z: Double) -> Shape?
```

- **Parameters:** `z`, the Z-plane height at which to section.
- **Returns:** A shape containing the cross-section edges, or `nil` if no intersection exists at that Z.
- **OCCT:** `BRepAlgoAPI_Section`.

---

### `sectionWiresAtZ(_:tolerance:)`

Returns wires from a section at a Z level, chained where the section closes.

```swift
public func sectionWiresAtZ(_ z: Double, tolerance: Double = 1e-6) -> [Wire]
```

Unlike `sliceAtZ`, this chains the section edges into wires (closed where the section forms a loop, open otherwise) suitable for offset or CAM operations. Use a larger `tolerance` (e.g. `1e-4`) for imprecise geometry.

- **Note:** Edges whose orientation is `.internal` or `.external` are silently excluded from the result wires (OCCT 8.0.1, upstream OCCT#1408). This only matters if the input `Shape` was assembled with such edges via `Shape.setOrientation(_:)` and one happens to lie exactly in the cutting plane; in every case measured, an ordinary transverse section does not produce `.internal`/`.external` edges on its own. See [#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655).
- **Parameters:** `z`, Z level to section at; `tolerance`, tolerance for connecting edges into wires.
- **Returns:** Array of `Wire` objects, closed where the section forms a loop and open otherwise; empty if no contours exist at that level.
- **OCCT:** `BRepAlgoAPI_Section` + `ShapeAnalysis_FreeBounds::ConnectEdgesToWires` (via `OCCTShapeSectionWiresAtZ`).
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

- **Parameters:** `index`, edge index (0 to `subShapeCount(ofType: .edge) − 1`); `maxPoints`, output *capacity* (capped at 20 internally), clamped into `0...Sampling.maximumSampleCount` (10,000,000), so an unservable capacity returns the same points rather than a coarser sampling; 0 or less returns empty (#558).
- **Returns:** Array of 3D points along the edge curve.
- **OCCT:** `BRep_Tool::Curve` + `GCPnts_UniformParameter` (via `OCCTShapeGetEdgePoints`).

---

### `contourPoints(maxPoints:)`

Returns the start vertices of all edges in the shape.

```swift
public func contourPoints(maxPoints: Int = 1000) -> [SIMD3<Double>]
```

Returns edge **start** vertices only, not intermediate curve samples. For curved edges use `edgePoints(at:maxPoints:)` instead. Suitable for simple polygon contours from Z-plane slices.

- **Parameters:** `maxPoints`, output *capacity*, clamped into `0...Sampling.maximumSampleCount` (10,000,000), so an unservable capacity returns the same points rather than a coarser sampling; 0 or less returns empty (#558).
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

Volume mass properties of a shape. `centerOfMass` is the centre of mass of the enclosed volume, and
`momentOfInertia` is referenced to it rather than to the world origin.

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

- **Parameters:** `density`, material density for mass calculation (default 1.0).
- **Returns:** `ShapeProperties` including volume, surface area, centre of mass, and inertia tensor;
  or `nil` when the shape encloses no volume (a face, wire, edge, vertex or **open shell**) or the
  calculation fails. These are volume mass properties, so without a volume there is no mass, no
  centre of mass and no inertia tensor. Use `surfaceArea` for the area of such a shape.
- **OCCT:** `BRepGProp::VolumeProperties` with `OnlyClosed = true` + `BRepGProp::SurfaceProperties`
  (via `OCCTShapeGetProperties`). See `centerOfMass` below for what `OnlyClosed` means.
- **Note:** `momentOfInertia` is referenced to the centre of mass, not to the world origin.
- **Example:**
  ```swift
  let cone = Shape.cone(bottomRadius: 10, topRadius: 0, height: 20)!
  if let p = cone.properties(density: 2.7) {
      print(p.volume)        // 2094.395
      print(p.mass)          // 5654.867 (volume x density)
      print(p.centerOfMass)  // (0, 0, 5): a cone's centroid is at h/4
  }
  ```

---

### `volume`

Volume of the shape in cubic units, or `nil` when the shape encloses no volume.

```swift
public var volume: Double? { get }
```

- **Returns:** Non-negative volume, or `nil` for a face, wire, edge, vertex, **open shell**, or
  reversed solid (ask `signedVolume` for that last one).
- **OCCT:** `BRepGProp::VolumeProperties` with `OnlyClosed = true` (via `OCCTShapeGetVolume`),
  matching `centerOfMass`. Without that flag the divergence integral answers over a surface that
  encloses nothing: 4800 for five faces of a 10x20x30 box, and 6857 for that box in a compound with
  one loose face beside it, where the answer is 6000.
- **Closedness is topological, not geometric.** A shell counts when every non-degenerate edge is
  shared an even number of times, so faces that merely coincide are not a closed shell. Sew them
  first. This matters for mesh-derived and IGES geometry, neither of which arrives sewn.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 20, depth: 30)!
  box.volume                                    // 6000
  Shape.compound(box.faces().compactMap { Shape.fromFace($0) })?.volume   // nil, unsewn
  Shape.sew(shapes: box.faces().compactMap { Shape.fromFace($0) })?.volume // 6000
  ```

---

### `signedVolume`

The signed divergence integral over the shape's faces. **An orientation signal, not a measurement.**

```swift
public var signedVolume: Double { get }
```

The magnitude is a volume only when the surface is closed; use `volume` to measure. The *sign* is
sound for any orientable surface, closed or not, because reversing a surface negates the flux
(measured: +4800 forward and -4800 reversed for five faces of a box). That is why this deliberately
keeps the unguarded integral where `volume` refuses it: `sweep(profile:along:)` produces an **open
shell**, and normalising it (#170) depends on this sign.

- **Returns:** The signed flux. `0` on an internal error, where it used to return `-1`, which
  `orientedForward()` read as "reverse me".
- **OCCT:** `BRepGProp::VolumeProperties` with `OnlyClosed` left at its default.

---

### `orientedForward()`

Returns a copy of this shape whose faces are oriented outward (positive flux).

```swift
public func orientedForward() -> Shape?
```

Reverses orientation only when `signedVolume < 0`. Already-correct solids, shells, and faces are returned unchanged.

- **Returns:** Outward-oriented copy, `self` if no fix needed, or `nil` if reversal fails.
- **OCCT:** `TopoDS_Shape::Reverse` applied via `reversed` when `signedVolume < 0`.
- **Note:** This reads `signedVolume`, the flux integral, precisely so it still normalises an open
  shell. A strict volume test would report nothing for a pipe sweep and quietly stop normalising the
  case it exists for.
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

- **Returns:** Non-negative area, or `nil` on failure. Unlike `volume` this answers for a face or an
  open shell, since an area integral is well defined over any set of faces.
- **OCCT:** `BRepGProp::SurfaceProperties` (via `OCCTShapeGetSurfaceArea`).
- **Not the same computation as `ShapeMeasurements.totalFaceArea` (#885), canonical explanation:**
  this is one untunable `BRepGProp::SurfaceProperties(shape, props)` integration over the whole
  shape, bit-identical to `surfaceInertiaProperties().mass` and `surfaceInertia.area`.
  `ShapeMeasurements.totalFaceArea` is a different computation, a tolerance-controlled sum of
  per-face integrals, see [`Measurement.md`](Measurement.md#shapemeasurementstotalfacearea) for
  the measured gap between the two and which to reach for. `surfaceInertiaProperties()` and
  `surfaceInertia` (`Shape-Measurement.md`) point back to this entry rather than restate it.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 20, depth: 30)!
  box.surfaceArea                        // 2200, one whole-shape integral
  box.surfaceInertiaProperties()?.mass   // 2200, the identical call in disguise
  box.measure().totalFaceArea            // usually agrees closely, not guaranteed to (#885)
  ```

---

### `centerOfMass`

Centre of mass of the volume the shape encloses. This is a *volume* measure, not the centre of the
bounding box: a cone's centre of mass sits at a quarter of its height.

```swift
public var centerOfMass: SIMD3<Double>? { get }
```

- **Returns:** Centre of mass, or `nil` when the shape encloses no volume (a face, wire, edge,
  vertex or **open shell**) or the calculation fails.
- **OCCT:** `BRepGProp::VolumeProperties` with `OnlyClosed = true` (via `OCCTShapeGetCenterOfMass`),
  matching OCCT's own `XCAFDoc_Centroid` writer. An open shell contributes nothing rather than the
  number the divergence integral returns over a surface enclosing nothing; close it first if you
  need a figure, since which closure you want is your choice. Closedness is computed per shell, so a
  closed shell outside any solid still counts.
- **See also:** `surfaceInertia` for an area measure, `linearProperties()` for a length measure,
  `vertices()` for a vertex position.
- **Example:**
  ```swift
  let big = Shape.box(width: 10, height: 10, depth: 10)!
  let small = Shape.box(width: 2, height: 2, depth: 2)!.translated(by: SIMD3(20, 0, 0))!
  let part = big.union(small)!

  part.centerOfMass    // (0.1587, 0, 0): the small cube barely shifts it
                       // the bounding box centre would be 8.0
  ```

---

### `distance(to:deflection:)`

Computes the minimum distance between this shape and another.

```swift
public func distance(to other: Shape, deflection: Double = 1e-6) -> DistanceResult?
```

- **Parameters:** `other`, the target shape; `deflection`, tolerance for curved geometry.
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

- **Parameters:** `other`, shape to test against; `tolerance`, distance threshold.
- **Returns:** `true` if the shapes overlap or touch within `tolerance`.
- **OCCT:** `BRepExtrema_DistShapeShape` (distance ≤ tolerance).

---

## Wire / Edge / Face Convenience Overloads

The following overloads lift `Wire`, `Edge`, and `Face` into `Shape` before dispatching. They have the same semantics as their `Shape`-typed counterparts.

### `distance(to:deflection:)`, Wire, Edge, Face

```swift
public func distance(to wire: Wire, deflection: Double = 1e-6) -> DistanceResult?
public func distance(to edge: Edge, deflection: Double = 1e-6) -> DistanceResult?
public func distance(to face: Face, deflection: Double = 1e-6) -> DistanceResult?
```

---

### `intersects(_:tolerance:)`, Wire, Edge, Face

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
- **Former second spelling:** `Shape.nbVertices` asked this same question, backed by a bare
  `TopExp_Explorer` occurrence count (48 on an 8-vertex box) instead of this deduplicated one;
  deprecated as a forward here in #651 and removed at v2.0.0 (#784).

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

- **Parameters:** `index`, zero-based vertex index.
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

- `.frenet`: standard Frenet trihedron; profile tracks spine curvature.
- `.correctedFrenet`: avoids twist at inflection points.
- `.fixed(binormal:)`: fixed binormal direction; profile keeps constant orientation.
- `.auxiliary(spine:)`: twist controlled by a secondary curve.

---

#### `auxiliary`

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

Case meanings, from `BRepBuilderAPI_TransitionMode` (via `BRepOffsetAPI_MakePipeShell::SetTransitionMode`):

- `.transformed`: the pipe is "transformed" at each spine fracture; may self-intersect.

#### `PipeTransitionMode.rightCorner`

The two pipe segments meeting at a spine fracture are extended and intersected, forming a sharp corner. Valid only when that intersection is connected and planar; a non-linear spine near the fracture, or a profile set with a scaling law, can violate this.

#### `PipeTransitionMode.roundCorner`

The corner is filled by rotating the profile around an axis through the fracture point, derived from the cross product of the two adjacent segments' tangent directions. Reliable only when the profile is strictly orthogonal to the spine (`withCorrection: true`).

---

### `filleted(edges:radius:)`

Fillets specific edges with a uniform radius.

```swift
public func filleted(edges: [Edge], radius: Double) -> Shape?
```

- **Parameters:** `edges`, edges to fillet (must have valid `index` values from this shape); `radius`, fillet radius (must be > 0).
- **Returns:** Filleted shape, or `nil` on failure, which includes a non-positive or NaN radius and
  an edge whose `index` names no edge of this shape.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTShapeFilletEdges`).
- **Notes:** shares one bridge implementation with
  [`filleted(edges:startRadius:endRadius:)`](#filletededgesstartradiusendradius) and
  [`blendedEdges(_:)`](#blendededges_), so all three apply the same positive-radius precondition
  (#489) and the same all-or-nothing index contract (#520): an edge that does not resolve rejects
  the call rather than being skipped, so a result is never a partial fillet reported as a complete
  one.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)
  let edges = box.subShapes(ofType: .edge).compactMap { Edge($0) }
  if let rounded = box.filleted(edges: Array(edges.prefix(4)), radius: 1.0) { }
  ```

---

### `Shape.FilletResult`

Result of a fillet call that also reports which requested edges OCCT declined (#639) and, for
`blendedEdgesWithReport(_:)`, which duplicate entries were silently overwritten (#633).

```swift
public struct FilletResult: Sendable {
    public let shape: Shape
    public let declinedEdgeIndices: [Int]
    public let overwrittenDuplicateIndices: [Int]
}
```

- **Fields:** `shape`: the filleted shape, identical to what the non-reporting sibling returns for
  the same input. `declinedEdgeIndices`: 0-based indices, matching `Edge.index`, of the requested
  edges OCCT declined to fillet. Empty when every requested edge was accepted.
  `overwrittenDuplicateIndices`: 0-based edge indices whose radius a *later* entry in the same
  request overwrote. Empty for every `WithReport` sibling except `blendedEdgesWithReport(_:)`, the
  one entry point whose per-edge radius array can name the same edge twice.
- **Notes:** there is no *reason* alongside either list. `BRepFilletAPI_MakeFillet::Add` returns
  nothing, and `NbFaultyContours()`/`BadShape()`/`StripeStatus()` describe a contour that failed
  during `Build()`, which an edge OCCT never added to any contour never reaches. `Contour(edge) ==
  0`, populated by `Add()` and not `Build()`, is the only signal OCCT itself exposes, so this reports
  *which* edges were declined, not *why*. Both lists mirror the caller's request rather than
  deduplicating it: an edge requested three times, and declined, is reported three times in
  `declinedEdgeIndices`; an edge requested three times whose radius is overwritten twice is reported
  twice in `overwrittenDuplicateIndices`: the count matches how many entries of the request were
  refused or discarded, not how many distinct edges were involved. Use `Set(...)` on either field
  for distinct edges.

---

#### `Shape.FilletResult.overwrittenDuplicateIndices`
- **Notes:** there is no *reason* alongside either list. `BRepFilletAPI_MakeFillet::Add` returns
  nothing, and `NbFaultyContours()`/`BadShape()`/`StripeStatus()` describe a contour that failed
  during `Build()`, which an edge OCCT never added to any contour never reaches. `Contour(edge) ==
  0`, populated by `Add()` and not `Build()`, is the only signal OCCT itself exposes, so this reports
  *which* edges were declined, not *why*. Both lists mirror the caller's request rather than
  deduplicating it: an edge requested three times, and declined, is reported three times in
  `declinedEdgeIndices`; an edge requested three times whose radius is overwritten twice is reported
  twice in `overwrittenDuplicateIndices`: the count matches how many entries of the request were
  refused or discarded, not how many distinct edges were involved. Use `Set(...)` on either field
  for distinct edges.

---

### `filletedWithReport(edges:radius:)`

`filleted(edges:radius:)`, also reporting which requested edges OCCT declined (#639).

```swift
public func filletedWithReport(edges: [Edge], radius: Double) -> FilletResult?
```

- **Parameters:** same as `filleted(edges:radius:)`.
- **Returns:** a `FilletResult`, or `nil` on failure under the same conditions as
  `filleted(edges:radius:)`.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTShapeFilletEdges`), reading `Contour(edge)` for
  each requested edge after `Add()` and before `Build()`.
- **Notes:** an edge OCCT cannot fillet is still skipped, not rejected: this changes only what a
  caller can learn about it, not the shape returned. See `Shape.FilletResult` above.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let report = box.filletedWithReport(edges: box.edges(), radius: 1.0) {
      precondition(report.declinedEdgeIndices.isEmpty)   // every edge of a closed solid fillets
  }
  ```

---

### `filleted(edges:startRadius:endRadius:)`

Fillets specific edges with a linear radius interpolation.

```swift
public func filleted(edges: [Edge], startRadius: Double, endRadius: Double) -> Shape?
```

Each named edge is given a law running from `startRadius` to `endRadius`, placed in that edge's own
slot within its contour. A contour is not always one edge. OCCT groups tangent-continuous edges
into a single contour, and the radius over the whole contour is the interpolation of its edges'
slots, so naming two edges of one tangent chain is not the same as naming one of them. Measured on
a rounded slot's rim at 1 → 4: the straight side alone gives 10273.238348, the side plus its tangent
arc 10297.711861 (#612).

- **Parameters:** `edges`, edges to fillet; `startRadius`, radius at the start of each named edge's law (> 0); `endRadius`, radius at its end (> 0).
- **Returns:** Filleted shape, or `nil` on failure, which includes a non-positive or NaN radius at
  either end.
- **OCCT:** `BRepFilletAPI_MakeFillet::Add(R1, R2, E)` (via `OCCTShapeFilletEdgesLinear`), which
  places each law in that edge's own slot within its contour (#612).
- **Notes:** shares one bridge implementation with [`filleted(edges:radius:)`](#filletededgesradius)
  and [`blendedEdges(_:)`](#blendededges_) (#489), including their all-or-nothing index contract
  (#520). An edge OCCT declines to fillet outright, a free-boundary edge of an open shell, is
  skipped by all five edge-list fillet entry points alike; a batch in which every edge is declined
  returns `nil` (#612).

---

### `filletedWithReport(edges:startRadius:endRadius:)`

`filleted(edges:startRadius:endRadius:)`, also reporting which requested edges OCCT declined
(#639). See [`Shape.FilletResult`](#shapefilletresult) and
[`filletedWithReport(edges:radius:)`](#filletedwithreportedgesradius) for the reporting contract.

```swift
public func filletedWithReport(edges: [Edge], startRadius: Double, endRadius: Double) -> FilletResult?
```

- **Parameters:** same as `filleted(edges:startRadius:endRadius:)`.
- **Returns:** a `FilletResult`, or `nil` on failure under the same conditions as
  `filleted(edges:startRadius:endRadius:)`.
- **OCCT:** `BRepFilletAPI_MakeFillet::Add(R1, R2, E)` (via `OCCTShapeFilletEdgesLinear`).

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
  - `faces`: faces to add draft to (must have valid `index` values).
  - `direction`: pull direction (typically the mold-open direction).
  - `angle`: draft angle in radians (typically 1–5°).
  - `neutralPlane`: point and normal of the plane where draft angle is zero.
- **Returns:** Drafted shape, or `nil` on failure.
- **OCCT:** `OCCTShapeDraft` (internal `Draft_MakeDraft`-based implementation).
- **Note:** every face must be one of *this* shape's, by index. A `Face` whose `index` names no face
  here fails the whole call rather than being skipped (#568). Skipping was worse here than anywhere
  else in that sweep: `BRepOffsetAPI_DraftAngle` reports success for a request it was handed no
  faces for at all, so a list of faces taken from a different shape used to return this shape
  undrafted, presented as a successful draft.

---

### `withoutFeatures(faces:)`

Removes faces and heals the resulting gaps by extending adjacent faces.

```swift
public func withoutFeatures(faces: [Face]) -> Shape?
```

Useful for simplifying imported geometry or removing small features before analysis.

- **Parameters:** `faces`, faces to remove (must have valid `index` values from this shape).
- **Returns:** Shape with features removed, or `nil` on failure, including when a face's index does
  not belong to this shape. Such an index used to be skipped, which returned a shape that still
  carried the feature and looked no different from a successful removal (#497).
- **OCCT:** `BRepAlgoAPI_Defeaturing` (via `OCCTShapeRemoveFeatures`). Corrected here: this row
  previously named `BOPAlgo_Defeaturing`, which is not an OCCT class.
- **See also:** [`defeature(faces:)`](Document-Transforms.md#shapedefeaturefaces), the same
  operation addressing its faces as shapes, and the rest of the defeaturing family listed there. Since
  #578 it applies the same rule to a face this shape does not have: the whole call fails.

---

## Advanced / Variable-Section Pipe Sweep

### `Shape.pipeShell(spine:profile:mode:transition:withContact:withCorrection:solid:)`

Creates a pipe sweep with advanced orientation mode control.

```swift
public static func pipeShell(
    spine: Wire,
    profile: Wire,
    mode: PipeSweepMode = .frenet,
    transition: PipeTransitionMode = .transformed,
    withContact: Bool = false,
    withCorrection: Bool = false,
    solid: Bool = true
) -> Shape?
```

Since #503 this is the single-profile form of
[`pipeShellMultiSection`](#shapepipeshellmultisectionspineprofilesmodetransitionwithcontactwithcorrectionsolid)
and runs the same code, so it reaches the corner-transition and profile-placement controls that
used to be split across three other spellings.

- **Parameters:**
  - `spine`: path wire.
  - `profile`: profile wire to sweep.
  - `mode`: sweep orientation mode (`.frenet`, `.correctedFrenet`, `.fixed(binormal:)`, `.auxiliary(spine:)`).
    A mode whose own argument is unusable (a zero-length binormal, or an auxiliary spine OCCT
    rejects) returns `nil`. It is never swapped for a different mode, which is what the
    pre-#503 bridge did.
  - `transition`: corner transition style at spine discontinuities.
  - `withContact`: if `true`, the profile is moved to touch the spine before sweeping.
  - `withCorrection`: if `true`, the profile is rotated to stay orthogonal to the spine.
  - `solid`: `true` = solid result; `false` = shell.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell` (via `OCCTShapeCreatePipeShellMultiSection`).
- **Example:**
  ```swift
  let spine = Wire.helix(origin: .zero, axis: SIMD3(0,0,1), radius: 10, pitch: 5, turns: 3)!
  let profile = Wire.circle(radius: 1)!
  let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet)
  ```

---

`Shape.pipeShellWithTransition(spine:profile:mode:transition:solid:)`, deprecated since #503 and
removed at v2.0.0 (#784), accepted a full `PipeSweepMode` but reached a bridge function that could
only express `.frenet` and `.correctedFrenet`; `.fixed(binormal:)` and `.auxiliary(spine:)` were
swept as Frenet, a different solid from the one requested, returned as a success. Use
[`pipeShell(spine:profile:mode:transition:...)`](#shapepipeshellspineprofilemodetransitionwithcontactwithcorrectionsolid),
which takes the same `transition:` argument and honours every mode.

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

- **Parameters:** `spine`, path wire; `profile`, profile wire; `law`, a `LawFunction` defining the scale along the spine; `solid`, produce a solid.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell` with law function (via `OCCTShapeCreatePipeShellWithLaw`).

---

### `Shape.pipeShellMultiSection(spine:profiles:mode:transition:withContact:withCorrection:solid:)`

Sweeps one or more profiles along a spine for a variable-section result.

```swift
public static func pipeShellMultiSection(
    spine: Wire,
    profiles: [Wire],
    mode: PipeSweepMode = .frenet,
    transition: PipeTransitionMode = .transformed,
    withContact: Bool = false,
    withCorrection: Bool = false,
    solid: Bool = true
) -> Shape?
```

Each profile is positioned in 3D at its station along the spine, and OCCT interpolates a smooth solid that passes through every section. Supports all `PipeSweepMode` cases, including `.auxiliary(spine:)` for twist control. Every `MakePipeShell` sweep in OCCTSwift is this call; `pipeShell` is this function with one profile (#503).

- **Parameters:**
  - `spine`: path wire.
  - `profiles`: section wires, each pre-positioned at its station (at least one required).
  - `mode`: orientation mode. A mode whose own argument is unusable returns `nil` rather than
    being swapped for another mode.
  - `transition`: corner transition style at spine discontinuities. Reaches a multi-section
    sweep since #503; before that only the single-profile spelling could set it.
  - `withContact`: if `true`, each profile is moved to touch the spine.
  - `withCorrection`: if `true`, each profile is rotated to stay orthogonal to the spine.
  - `solid`: produce a solid when `true`.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell` (via `OCCTShapeCreatePipeShellMultiSection`).

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
  - `profiles`: rib profile wires positioned in the (radial, axis) plane (at least one).
  - `axisOrigin`: a point on the worm axis.
  - `axisDirection`: worm axis direction.
  - `radius`: helix pitch radius (must be > 0).
  - `pitch`: axial advance per turn (must be > 0).
  - `turns`: number of turns (must be > 0).
  - `clockwise`: helix handedness.
  - `solid`: produce a solid when `true`.
- **Returns:** The swept helicoid, or `nil` on failure.
- **OCCT:** `Wire.helix` + `BRepOffsetAPI_MakePipeShell` auxiliary-spine mode.
- **Note:** The auxiliary-spine framing is approximately radial, not exactly, results bulge ~10–15% beyond the nominal radius for moderate profiles, and balloon severely for fine-pitch V-forms. Use `threadedShaft` / `threadedHole` for precise fastener threads. Do **not** boolean this helicoid with a coaxial cylinder, coincident faces cause BOP to fail (see OCCTSwift #225, #213, #181). Use `threadedRod(customProfile:...)` instead.
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
  - `poles`: 2D array of control points.
  - `uDegree`: degree in U (default 3, cubic).
  - `vDegree`: degree in V (default 3, cubic).
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

- **Parameters:** `profile1`, first boundary wire; `profile2`, second boundary wire.
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

- **Parameters:** `thickness`, wall thickness (positive = inward, negative = outward); `openFaces`, faces to leave open (must have valid `index` values).
- **Returns:** Shelled shape with specified faces open, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid::MakeThickSolidByJoin` (via `OCCTShapeShellWithOpenFaces`).
- **Note:** every face must be one of *this* shape's, by index. A `Face` whose `index` names no face
  here fails the whole call rather than being skipped (#568); previously such a face was dropped and
  the solid was shelled with fewer openings than asked for.
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
    public let hasSelfIntersection: Bool?
    public let freeEdgeCount: Int
    public let freeFaceCount: Int
    public let hasInvalidTopology: Bool
    public var totalProblems: Int { get }
    public var isHealthy: Bool { get }
}
```

`isHealthy` is `true` when `totalProblems == 0 && !hasInvalidTopology`.

- **This never reports self-intersection unless asked to.** A `selfIntersectionCount` field used
  to sit here (through v1.x) but was always 0, never computed (the bridge's own comment read
  "would require more expensive computation"); it was removed in #763 rather than kept as a
  permanent zero. Use `hasSelfIntersection`, populated via
  `analyze(tolerance:selfIntersectionTimeout:)`, or `isSelfIntersecting(timeout:)` directly, for a
  real answer.
- **`hasSelfIntersection` is `nil` unless `analyze(selfIntersectionTimeout:)` was passed a
  non-`nil` value (#772).** The self-intersection check (`BOPAlgo_ArgumentAnalyzer`'s
  self-interference test, #319) is orders of magnitude more expensive than the rest of this scan,
  and on pathological input the gap is not small: measured on the #319 pathological artifact,
  roughly 3000x-4000x the cost of the rest of the scan combined (a few milliseconds vs 30+
  seconds at a 30s timeout). On ordinary shapes, including a real 662-face mesh-sewn import, the
  measured overhead was 1x-3x, cheap enough to opt into freely; see
  `Scripts/repro/772-analyze-self-intersection/` for the full measurement, including why this
  forwards to `isSelfIntersecting(timeout:)` and not `isSelfIntersecting(hardTimeout:)` (measuring
  both, not just the pathological case, found the latter is not a strict improvement here). `nil`
  covers two cases the type deliberately does not distinguish: not requested, or requested but
  indeterminate (the check did not resolve within the timeout, matching `isSelfIntersecting`'s own
  `nil` = indeterminate). `nil` is never "clean": only `hasSelfIntersection == false` means that.
  `totalProblems` adds a flat +1 when `hasSelfIntersection == true`, +0 for `false` or `nil`, so
  it never reflects self-intersection unless the analysis actually checked for it.
- **`freeEdgeCount`/`freeFaceCount` were hardcoded to 0 for every shape before #702**: the bridge
  called `ShapeAnalysis_Shell::LoadShells()`, which only registers a shell for bookkeeping,
  instead of `CheckOrientedShells()`, the call that actually populates the free-edge set. Now
  fixed: `freeEdgeCount` is the true count across every shell, and `freeFaceCount` is how many of
  those shells are not fully closed. The bridge asks `CheckOrientedShells` to also exclude an edge
  that has a matching `TopAbs_INTERNAL`-oriented occurrence elsewhere in the same shell from
  `freeEdgeCount` (it is genuinely connected through that occurrence, not a boundary gap): the
  same rule `analyzeShell()` already used, so the two agree on any shape either can see.
- **`totalProblems` counts `freeEdgeCount`, not `freeFaceCount`.** `freeFaceCount` is a derived
  summary over the same scan (this shell has at least one free edge), not an independent defect:
  it is never nonzero without `freeEdgeCount` also being nonzero, and adding both would count one
  open shell's boundary gap twice (once per edge, once more as a flat "+1 shell"). `freeFaceCount`
  stays a public field for callers who want the shell-level breakdown; it is just not folded into
  the total again.
- **A "clean" (`isHealthy == true`) result never means "this is a solid."** A well-formed open
  shell, or a shell `healed()`/`fixSolid()` demoted from a solid it could not close, has no
  closure requirement of its own and can report zero free edges accurately while still not being a
  solid. Check `shapeType` or `isValidSolid` for that.

| field | meaning |
|---|---|
| `smallEdgeCount` | Number of edges smaller than the scan's `tolerance`. |
| `smallFaceCount` | Number of faces smaller than the scan's `tolerance`. |
| `gapCount` | Number of gaps found between edges/faces. |
| `hasSelfIntersection` | `true`/`false` when `selfIntersectionTimeout` was passed and resolved; `nil` when not asked, or asked but indeterminate. `nil` is never "clean". |
| `freeEdgeCount` | Free (unconnected) edges across every shell, via `ShapeAnalysis_Shell::CheckOrientedShells`. |
| `freeFaceCount` | Shells found to have at least one free edge; a derived summary of `freeEdgeCount`, not an independent defect. |
| `hasInvalidTopology` | Whether `BRepCheck_Analyzer` found the topology invalid. |
| `totalProblems` | `smallEdgeCount + smallFaceCount + gapCount + freeEdgeCount`, plus +1 for invalid topology, plus +1 only when `hasSelfIntersection == true`. |
| `isHealthy` | `true` when `totalProblems == 0 && !hasInvalidTopology`. Says nothing about self-intersection unless it was actually checked. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `isHealthy`

---

### `analyze(tolerance:selfIntersectionTimeout:)`

Analyzes a shape for problems such as small edges, gaps, and invalid topology.

```swift
public func analyze(tolerance: Double = 1e-6, selfIntersectionTimeout: Double? = nil) -> ShapeAnalysisResult?
```

- **Important:** passing `selfIntersectionTimeout` makes this call **synchronously block the
  calling thread** for up to that many seconds (more, if OCCT never reaches a checkpoint to poll:
  see `isSelfIntersecting(timeout:)`'s own warning, inherited unchanged). Do not pass it from a
  UI/main thread without accepting that stall.
- **Parameters:**
  - `tolerance`: size threshold for detecting small features.
  - `selfIntersectionTimeout`: `nil` (the default) skips the self-intersection check entirely and
    leaves `ShapeAnalysisResult.hasSelfIntersection` `nil`. A non-`nil` value opts in, forwarded
    as the `timeout:` to `isSelfIntersecting(timeout:)` (the cooperative check, not
    `isSelfIntersecting(hardTimeout:)`: measuring both, not just on a pathological artifact, found
    the `hardTimeout:` background-thread mechanism is not a strict improvement, see below). There
    is no way to supply a timeout that does not enable the check: the two used to be separate
    parameters (`checkSelfIntersection: Bool`, `hardTimeout: Double`) until review found that
    shape let a caller's `hardTimeout` be silently discarded whenever they forgot
    `checkSelfIntersection: true`, compiling and running with no signal at all (#772). Collapsing
    them into one optional makes that mistake unrepresentable.

    Costs 1x-3x the rest of this scan on ordinary shapes, including a real 662-face mesh-sewn
    import, but roughly 3000x-4000x on the #319 pathological artifact (measured,
    `Scripts/repro/772-analyze-self-intersection/`), so it stays opt-in rather than silently
    turning a cheap call into an occasionally unbounded-shaped one.
- **Returns:** `ShapeAnalysisResult` with problem counts, or `nil` if the analysis itself fails.
- **OCCT:** `ShapeAnalysis_Shell` + `ShapeAnalysis_CheckSmallFace` + `BRepCheck_Analyzer` (via `OCCTShapeAnalyze`), plus `BOPAlgo_ArgumentAnalyzer` when `selfIntersectionTimeout` is non-`nil`.
- **Why `timeout:`, not `hardTimeout:`:** `isSelfIntersecting(hardTimeout:)` looks like the safer
  default (a true wall-clock guarantee via `deepCopy()` + a background thread + a semaphore), but
  its `deepCopy()` step, while cheap on its own (under 1ms on every fixture measured), guards an
  internal `OCCTShapeSelfIntersectsBounded` call that passes 0 (unbounded); the only bound left is
  the caller-side semaphore wait. On the #319 pathological artifact this produced a **worse**
  answer than `timeout:` at the same deadline: `timeout:` reliably returned a conclusive
  `self-intersects` around 30.1s, while `hardTimeout:` reliably returned `nil` (indeterminate) at
  exactly 30.0s, the same wall-clock budget for a strictly less useful answer, plus an abandoned
  background computation left running. `analyze()` is already fully synchronous, so a caller has
  already committed to blocking; `hardTimeout:`'s guarantee buys nothing over `timeout:` in that
  context. A caller that genuinely needs the hard guarantee should call
  `isSelfIntersecting(hardTimeout:)` directly and accept its documented trade-offs.
- **Example:**
  ```swift
  if let a = shape.analyze(tolerance: 0.001) {
      if !a.isHealthy { print("\(a.totalProblems) problems found") }   // self-intersection not included
  }

  // Opt into the expensive, thread-blocking check when it's actually needed:
  if let a = shape.analyze(tolerance: 0.001, selfIntersectionTimeout: 30) {
      switch a.hasSelfIntersection {
      case .some(true):  print("self-intersects")
      case .some(false): print("clean")
      case nil:          print("indeterminate, timeout elapsed before a checkpoint")
      }
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
  - `tolerance`: tolerance for fixing operations.
  - `fixSolid`: whether to fix solid orientation (`ShapeFix_Shape::FixSolidMode`).
  - `fixShell`: whether to fix **free** shells, shells that aren't part of a solid
    (`ShapeFix_Shape::FixFreeShellMode`).
  - `fixFace`: whether to fix **free** faces, faces that aren't part of a shell
    (`ShapeFix_Shape::FixFreeFaceMode`).
  - `fixWire`: whether to fix **free** wires, wires that aren't part of a face
    (`ShapeFix_Shape::FixFreeWireMode`).

  `fixShell`/`fixFace`/`fixWire` govern **free** (standalone) content specifically, not
  shell/face/wire fixing in general: content that *is* attached (a shell inside a solid, a face
  inside a shell, a wire inside a face) is always fixed by `Perform()` regardless of these three
  flags. Before #837 these three were accepted but never passed to `ShapeFix_Shape` at all, only
  `fixSolid` had any effect, so setting any of them to `false` silently did nothing; they are now
  live (#865).
- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeFix_Shape` (via `OCCTShapeFixDetailed`).
- **Example:**
  ```swift
  // Skip fixing free (standalone) shells/faces/wires; only fix solid orientation.
  let fixed = shape.fixed(tolerance: 0.001, fixShell: false, fixFace: false, fixWire: false)
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
  - `unifyEdges`: merge edges on the same curve.
  - `unifyFaces`: merge faces on the same surface.
  - `concatBSplines`: concatenate adjacent B-spline edges / faces.
- **Returns:** Unified shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_UnifySameDomain` (via `OCCTShapeUnifySameDomain`).
- **The receiver is not modified.** The merge runs on a private copy. `ShapeUpgrade_UnifySameDomain` rewrites sub-shapes of the shape it is given, and those rewrites reached the caller's own shape, so discarding the result was not enough to keep it (#446).
- **The result shares no sub-shapes with the receiver**, even where nothing was merged: that is the price of the copy, and it means `isSame(as:)`/`isPartner(with:)`/`isEqual(to:)` answer `false` for faces that came through untouched. Map selections and attributes by geometry, not by sub-shape identity.
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

- **Parameters:** `minArea`, minimum face area; faces below this are removed.
- **Returns:** Cleaned shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Defeaturing` (via `OCCTShapeRemoveSmallFaces`), the small faces are collected by area and removed by defeaturing. (Corrected here: this row previously credited `ShapeAnalysis_CheckSmallFace` + `ShapeUpgrade_UnifySameDomain`, neither of which the implementation uses.)

---

### `simplified(tolerance:)`

Convenience method combining `unified()` and `healed()`.

```swift
public func simplified(tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `tolerance`, tolerance for simplification.
- **Returns:** Simplified shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_UnifySameDomain` + `ShapeFix_Shape` (via `OCCTShapeSimplify`).
- **The receiver is not modified**, and the result shares no sub-shapes with it, see `unified(...)` above (#446).

---

### `Wire.fixed(tolerance:)`

Fixes wire problems such as gaps, degenerate edges, and incorrect ordering.

```swift
public func fixed(tolerance: Double = 1e-6) -> Wire?
```

- **Parameters:** `tolerance`, tolerance for fixing.
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

- **Parameters:** `tolerance`, tolerance for fixing.
- **Returns:** Fixed face as a `Shape`, or `nil` on failure.
- **OCCT:** `ShapeFix_Face` (via `OCCTFaceFix`).

---

## Advanced Blends & Surface Filling (v0.14.0)

### `SurfaceContinuity`

Geometric continuity order for a surface constraint. The single vocabulary behind every call
that constrains a generated surface against a point, edge or wire: `Shape.fill(boundaries:)`,
`Shape.fill(constraints:)`, `FillingSurface` and `Shape.plateSurface(through:orders:)`. All of
them hand the raw value to OCCT as a plate constraint order, which `GeomPlate_CurveConstraint`
validates directly and rejects outside `[-1, 2]`.

```swift
public enum SurfaceContinuity: Int32, Sendable, CaseIterable {
    case g0 = 0   // positional (G0): the surface passes through the constraint
    case g1 = 1   // tangent (G1): the surface is tangent along the constraint
    case g2 = 2   // curvature (G2): the surface matches curvature along the constraint
}
```

| Case | Meaning |
|---|---|
| `.g0` | Positional continuity: the surface passes through the constraint. |
| `.g1` | Tangent continuity: the surface is tangent along the constraint. |
| `.g2` | Curvature continuity: the surface matches curvature along the constraint. Rejected for a bare point constraint (see below). |

> **Renamed in #398.** `PlateConstraintOrder` and `FillingContinuity` were separate copies of
> this same vocabulary, deprecated as typealiases of `SurfaceContinuity`; the `.c0`, `.c1` and
> `.c2` spellings were deprecated aliases of `.g0`, `.g1` and `.g2`. No raw value moved. All were
> removed at v2.0.0 (#784). Not to be confused with `ParametricContinuity` (C0/C1/C2/C3), which is
> a different contract: see `docs/reference/Shape-Healing.md`.

---

#### `SurfaceContinuity.g2`

```swift
```
Not every API accepts every order. A bare point carries no curvature to match, so
`GeomPlate_PointConstraint` throws above order 1. `Shape.plateSurface(through:orders:)` and the
point half of `Shape.plateSurface(pointConstraints:curveConstraints:)` reject `.g2` in Swift
before building any constraint, so a point given `.g2` returns `nil` deliberately rather than by
relying on OCCT's own throw being caught (#437). Curve constraints have no such restriction:
`GeomPlate_CurveConstraint` accepts order 2 directly, so `.g2` is fine for a curve.
> **Renamed in #398.** `PlateConstraintOrder` and `FillingContinuity` were separate copies of
> this same vocabulary, deprecated as typealiases of `SurfaceContinuity`; the `.c0`, `.c1` and
> `.c2` spellings were deprecated aliases of `.g0`, `.g1` and `.g2`. No raw value moved. All were
> removed at v2.0.0 (#784). Not to be confused with `ParametricContinuity` (C0/C1/C2/C3), which is
> a different contract: see `docs/reference/Shape-Healing.md`.
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

| field | meaning |
|---|---|
| `continuity` | Surface continuity at the fill's boundaries (default `.g1`). |
| `tolerance` | Surface tolerance for the fit (default `1e-4`). |
| `maxDegree` | Maximum surface degree the filler may use (default `8`). |
| `maxSegments` | Maximum number of segments the filler may use (default `9`). |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `tolerance`

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

- **Parameters:** `edgeIndex`, 0-based index of the edge to fillet, as reported by `Edge.index`;
  `radiusProfile`: array of `(parameter, radius)` pairs (minimum 2).
- **Returns:** Filleted shape, or `nil` on failure, which includes an `edgeIndex` naming no edge of
  this shape, a non-positive or NaN radius anywhere in the profile, a parameter outside `0...1`,
  and a non-increasing parameter sequence (#520).
- **OCCT:** `BRepFilletAPI_MakeFillet` with law-driven radius (via `OCCTShapeFilletVariable`).
- **Notes:** the profile is applied through `SetRadius(UandR, contour, 1)`, the same OCCT overload
  [`filletEvolving(_:)`](Shape-Measurement#filletevolving_) uses, so the same profile gives the
  same shape through either entry point. **Until #520 the profile was never applied at all**: the
  bridge mapped each relative parameter onto the edge's own curve range and passed it where OCCT
  wanted a contour index, which truncated it to an `int`, so the result was a constant radius (and,
  for an edge whose parameter range does not start at 0, a `SIGSEGV`).
- **Example:**
  ```swift
  // Radius varies from 1 mm at start to 3 mm at end
  let filleted = shape.filletedVariable(
      edgeIndex: 0,
      radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
  )

  // Rejected: a descending parameter would silently reverse the law
  let invalid = shape.filletedVariable(
      edgeIndex: 0,
      radiusProfile: [(1.0, 1.0), (0.0, 3.0)]
  )  // nil
  ```

> OCCT stretches the profile across the whole edge, so it cannot fillet part of one and leave the
> rest alone. With exactly two points the parameters are ignored and only the endpoint radii are
> used; with three or more only the *relative* spacing of the interior points survives, because
> OCCT renormalises the first parameter to 0 and the last to 1.

---

## Multi-Edge Blend (v0.14.0)

### `blendedEdges(_:)`

Applies fillets to multiple edges, each with its own radius.

```swift
public func blendedEdges(_ edgeRadii: [(edgeIndex: Int, radius: Double)]) -> Shape?
```

- **Parameters:** `edgeRadii`, array of `(0-based edgeIndex, radius)` pairs. Every radius must be > 0.
- **Returns:** Filleted shape with per-edge radii applied, or `nil` on failure, which includes an
  empty array, a non-positive or NaN radius anywhere in it, and an index that names no edge of this
  shape.
- **OCCT:** `BRepFilletAPI_MakeFillet` (via `OCCTShapeBlendEdges`).
- **Notes:** one non-positive radius rejects the whole batch, the same contract
  [`filleted(edges:radius:)`](#filletededgesradius) applies to its single radius (#489), and one
  index that does not resolve rejects it too rather than being skipped (#520). The same edge index
  named twice is **not** rejected: `BRepFilletAPI_MakeFillet::Add(radius, edge)` writes to that
  edge's own fillet-contour slot, so the *second* call silently overwrites the first radius (#633).
  Unchanged, existing behaviour; see [`blendedEdgesWithReport(_:)`](#blendededgeswithreport_) for
  the same fillet with a report naming which entries a duplicate overwrote.
- **Example:**
  ```swift
  let blended = shape.blendedEdges([
      (0, 1.0),
      (1, 2.0),
      (2, 0.5)
  ])

  // Rejected: a radius of zero is not a fillet
  let invalid = shape.blendedEdges([(0, 1.0), (1, 0.0)])  // nil

  // Rejected: 99_999 names no edge, so the batch fails rather than filleting edge 0
  let outOfRange = shape.blendedEdges([(0, 1.0), (99_999, 2.0)])  // nil

  // Not rejected: edge 0's first radius (1.0) is silently overwritten by the second (3.0)
  let overwritten = shape.blendedEdges([(0, 1.0), (0, 3.0)])
  ```

---

### `blendedEdgesWithReport(_:)`

`blendedEdges(_:)`, also reporting which requested edges OCCT declined to fillet, and which
duplicate entries a later request overwrote (#633).

```swift
public func blendedEdgesWithReport(_ edgeRadii: [(edgeIndex: Int, radius: Double)]) -> FilletResult?
```

- **Parameters:** same as `blendedEdges(_:)`.
- **Returns:** a `FilletResult`, or `nil` on failure under the same conditions as
  `blendedEdges(_:)`.
- **OCCT:** `BRepFilletAPI_MakeFillet.Add(radius, edge)` (via `OCCTShapeBlendEdges`), reading
  `Contour(edge)` for each requested edge after `Add()` and before `Build()` for the declined-edge
  axis; the duplicate-overwrite axis is computed Swift-side from `edgeRadii` itself and needs no
  OCCT call at all, since an edge index maps to exactly one edge regardless of how many times it is
  requested.
- **Notes:** neither report changes the shape returned, which is byte-identical to what
  `blendedEdges(_:)` gives for the same input. See `Shape.FilletResult` above for the mirror-the-
  request convention both of its list fields share.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let report = box.blendedEdgesWithReport([(0, 2.0), (0, 5.0)]) {
      print(report.overwrittenDuplicateIndices)   // [0]: edge 0's first radius (2.0) was overwritten
      print(report.declinedEdgeIndices)            // []: every edge of a closed box fillets
  }
  ```

---

## Surface Filling

### Choosing a continuity reference

Tangency (`.g1`) and curvature (`.g2`) are relative, the filled surface has to be continuous
*with* something. That reference is a **support face**, and which overload you use is really the
question of where that face comes from:

| Overload | Support face | Use when |
|---|---|---|
| `fill(boundaries:parameters:)` | each edge's own underlying surface | the boundary edges were borrowed from existing faces and that surface is the right reference |
| `fill(boundaries:supportedBy:parameters:)` | the edge's ancestor face in a given shape | capping an opening so it flows into the walls around it |
| `fill(constraints:parameters:)` | named per edge | different edges need different references, orders, or internal (non-bounding) constraints |

A boundary built from free-standing wires has no reference surface at all, so any continuity above
`.c0` returns `nil` for every one of these. `.c0` always works, it constrains position only.

`FillingSurface` (`docs/reference/GeometrySolvers.md#fillingsurface`) shares this exact
`BRepOffsetAPI_MakeFilling` implementation as of #434, same continuity mapping, same support-face
rules, as the incremental, stateful alternative to these one-shot array-based overloads. Its
`add(edge:support:continuity:)` mirrors `FillConstraint`'s support-face semantics below.

### `Shape.fill(boundaries:parameters:)`

Fills an N-sided boundary with a smooth surface.

```swift
public static func fill(
    boundaries: [Wire],
    parameters: FillingParameters = FillingParameters()
) -> Shape?
```

Creates a face that passes through the given boundary wires with the specified continuity. Each
wire's edges are added as edge constraints to the filler, each taking its continuity reference from
its own underlying surface.

- **Parameters:** `boundaries`, wires defining the boundary (at least one); `parameters`, filling parameters (continuity, tolerance, degree, segments).
- **Returns:** Face shape covering the boundary, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeFilling` (via `OCCTShapeFill`).
- **Example:**
  ```swift
  let w1 = Wire.line(from: SIMD3(0,0,0), to: SIMD3(10,0,0))!
  let w2 = Wire.line(from: SIMD3(10,0,0), to: SIMD3(10,10,5))!
  let w3 = Wire.line(from: SIMD3(10,10,5), to: SIMD3(0,10,3))!
  let w4 = Wire.line(from: SIMD3(0,10,3), to: SIMD3(0,0,0))!
  // free-standing wires: nothing to be tangent to, so fill positionally
  let face = Shape.fill(boundaries: [w1, w2, w3, w4],
                         parameters: FillingParameters(continuity: .c0))
  ```

### `Shape.fill(boundaries:supportedBy:parameters:)`

Fills a boundary so the result is continuous with the shape surrounding it.

```swift
public static func fill(
    boundaries: [Wire],
    supportedBy support: Shape,
    parameters: FillingParameters = FillingParameters()
) -> Shape?
```

Each boundary edge takes its continuity reference from that edge's own ancestor face in `support`.
An edge that isn't part of `support` falls back to its own underlying surface, and failing that is
constrained positionally.

- **Parameters:** `boundaries`, wires defining the boundary; `support`, shape whose faces supply the continuity reference; `parameters`, filling parameters.
- **Returns:** Face shape covering the boundary, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeFilling::Add(edge, face, order)` (via `OCCTShapeFillWithSupport`).
- **Example:**
  ```swift
  // Cap the open top of a truncated sphere, tangent to the spherical wall
  let bowl = Shape.sphere(at: SIMD3(0,0,0), direction: SIMD3(0,0,1),
                          radius: 10, angle1: -.pi/2, angle2: 50 * .pi/180)!
  let rim = bowl.edges()
      .filter { $0.isClosed3D }
      .max(by: { $0.bounds.max.z < $1.bounds.max.z })!

  let cap = Shape.fill(boundaries: [Wire.wireFromEdges([rim])!],
                        supportedBy: bowl,
                        parameters: FillingParameters(continuity: .g1))
  // cap leaves the rim along the sphere; the .c0 fill of the same rim is a flat disc
  ```

### `Shape.fill(constraints:parameters:)`

Fills a surface from explicit per-edge constraints.

```swift
public static func fill(
    constraints: [FillConstraint],
    parameters: FillingParameters = FillingParameters()
) -> Shape?
```

Every edge names its own support face and continuity order, and may bound the resulting face or act
as an internal constraint the surface must also satisfy. `parameters.continuity` is ignored, each
constraint carries its own.

- **Parameters:** `constraints`, edge constraints; `parameters`, filling parameters (continuity field unused).
- **Returns:** Face shape satisfying the constraints, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeFilling::Add(edge, face, order, isBound)` (via `OCCTShapeFillConstraints`).
- **Example:**
  ```swift
  let wall = rim.adjacentFaces(in: bowl)!.0

  let patch = Shape.fill(constraints: [
      FillConstraint(edge: rim, support: wall, continuity: .g2),
      FillConstraint(edge: freeEdge, continuity: .c0),
      // pulled through, but does not bound the face
      FillConstraint(edge: ridgeEdge, continuity: .c0, isBoundary: false)
  ])
  ```

### `FillConstraint`

```swift
public struct FillConstraint {
    public var edge: Edge
    public var support: Face?              // nil, derive from the edge itself
    public var continuity: SurfaceContinuity   // default .g1
    public var isBoundary: Bool            // default true
}
```

- **`support`**: the face to be continuous with, used or the fill fails. If the named face carries no pcurve for `edge` it cannot serve as the reference, and the whole fill returns `nil` rather than quietly substituting a different surface. `nil` instead accepts whichever surface the edge itself resolves. (A *planar* face works even with no pcurve stored: `BRep_Tool::CurveOnSurface` projects onto a plane on the fly.)
- **`isBoundary`**: `true` bounds the resulting face; `false` makes it an internal constraint the surface passes through without being edged by it.

> **Continuity mapping.** `BRepFill_Filling` forwards the `GeomAbs_Shape` value to
> `GeomPlate_CurveConstraint` as an integer *plate order* and rejects anything outside `[-1, 2]`.
> So `.g2` maps to `GeomAbs_C1` (ordinal 2), not `GeomAbs_G2` (ordinal 3), the latter always
> throws, despite OCCT's own header docs naming it as the curvature-continuity value.

---

#### `isBoundary`

> **Continuity mapping.** `BRepFill_Filling` forwards the `GeomAbs_Shape` value to
> `GeomPlate_CurveConstraint` as an integer *plate order* and rejects anything outside `[-1, 2]`.
> So `.g2` maps to `GeomAbs_C1` (ordinal 2), not `GeomAbs_G2` (ordinal 3), the latter always
> throws, despite OCCT's own header docs naming it as the curvature-continuity value.

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

- **Parameters:** `points`, 3D points the surface must pass through (minimum 3); `tolerance`, approximation tolerance.
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

- **Parameters:** `curves`, wires defining the boundary constraints (at least one); `continuity`, continuity requirement at boundaries; `tolerance`, approximation tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` with curve constraints (via `OCCTShapePlateCurves`).

---

### `Shape.plateSurface(through:orders:degree:pointsOnCurves:iterations:tolerance:)` (v0.23.0)

Creates a plate surface through points with per-point constraint orders.

```swift
public static func plateSurface(
    through points: [SIMD3<Double>],
    orders: [SurfaceContinuity],
    degree: Int = 3,
    pointsOnCurves: Int = 15,
    iterations: Int = 2,
    tolerance: Double = 0.01
) -> Shape?
```

Each point independently specifies G0 (position) or G1 (position + tangent) continuity.
**`.g2` always returns `nil`**: `GeomPlate_PointConstraint` rejects order 2 outright for a bare
point (#437), and this is checked in Swift, via `SurfaceContinuity.isUnsupportedForPointConstraint`,
before any constraint is built, rather than relying on OCCT's own throw.

- **Parameters:**
  - `points`: 3D points (minimum 3); must match `orders.count`.
  - `orders`: per-point constraint orders (`.g0` or `.g1`; `.g2` is rejected, see above).
  - `degree`: maximum polynomial degree (default 3).
  - `pointsOnCurves`: sample points on internal curves (default 15).
  - `iterations`: solver iterations (default 2).
  - `tolerance`: approximation tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` + `GeomPlate_PointConstraint` + `GeomPlate_MakeApprox` (via `OCCTShapePlatePointsAdvanced`).

---

### `Shape.plateSurface(pointConstraints:curveConstraints:degree:tolerance:)` (v0.23.0)

Creates a plate surface with mixed point and curve constraints.

```swift
public static func plateSurface(
    pointConstraints points: [(point: SIMD3<Double>, order: SurfaceContinuity)],
    curveConstraints curves: [(wire: Wire, order: SurfaceContinuity)],
    degree: Int = 3,
    tolerance: Double = 0.01
) -> Shape?
```

At least one of `points` or `curves` must be non-empty. `.g2` is rejected up front for a **point**
constraint (`GeomPlate_PointConstraint` rejects order 2 outright, #437) but is fine for a
**curve** constraint (`GeomPlate_CurveConstraint` accepts order 2 directly); only `points`'
orders are checked.

- **Parameters:**
  - `points`: point constraints, each with a position and a `SurfaceContinuity` (`.g2` always
    rejected, see above).
  - `curves`: curve constraints, each with a `Wire` and a `SurfaceContinuity`.
  - `degree`: maximum polynomial degree (default 3).
  - `tolerance`: approximation tolerance.
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
