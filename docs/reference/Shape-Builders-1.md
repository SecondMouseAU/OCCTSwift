---
title: Shape — Builders & Boolean Internals I
parent: API Reference
---

# Shape — Builders & Boolean Internals I

These members are low-level OCCT builder and algorithm wrappers — polyhedral geometry, history tracking, 2D fillet engines, shell/solid builders, Boolean splitters, ray/contour intersection, mesh utilities, and surface-fill algorithms — exposed directly on `Shape`. See the main [Shape](#) page for the core topology, transform, and measurement API (free-boundary analysis is on the **Shape — Measurement** page).

## Topics

- [v0.50 Polyhedral Distance / History / Wire-Vertex / Nearest Plane](#v050-polyhedral-distance--history--wire-vertex--nearest-plane) · [v0.51 BRepLib\_MakeSolid / GC Transforms / ChFi2d\_AnaFilletAlgo](#v051-breplib_makesolid--gc-transforms--chfi2d_anafilletalgo) · [BRepFill\_Generator / AdvancedEvolved / OffsetWire / Draft / Pipe / CompatibleWires](#brepfill_generator--advancedevolved--offsetwire--draft--pipe--compatiblewires) · [ChFi2d\_FilletAlgo](#chfi2d_filletalgo) · [BRepTools\_Substitution](#breptools_substitution) · [ShapeUpgrade\_ShellSewing](#shapeupgrade_shellsewing) · [LocOpe\_BuildShape](#locope_buildshape) · [BOPAlgo Splitter / ArgumentAnalyzer](#bopalgo-splitter--argumentanalyzer) · [IntCurvesFace Intersection](#intcurvesface-intersection) · [Contap Contour Analysis](#contap-contour-analysis) · [BRepMesh\_Deflection](#brepmesh_deflection) · [BRepBuilderAPI\_MakeShapeOnMesh](#brepbuilderapi_makeshapeonmesh) · [GeomPlate\_Surface](#geomplate_surface) · [CellsBuilder](#cellsbuilder) · [BRepLib\_MakeEdge / MakeFace / MakeShell / ToolTriangulatedShape / PointCloudShape](#breplib_makeedge--makeface--makeshell--tooltriangulatedshape--pointcloudshape) · [BRepBuilderAPI\_MakeEdge2d](#brepbuilderapi_makeedge2d) · [BRepTools\_Modifier + NurbsConvert](#breptools_modifier--nurbsconvert) · [ShapeCustom\_Direct / TrsfModification](#shapecustom_direct--trsfmodification) · [LocOpe Builders](#locope-builders) · [CPnts\_UniformDeflection](#cpnts_uniformdeflection) · [IntCurvesFace\_ShapeIntersector](#intcurvesface_shapeintersector) · [GeomLProp\_CLProps / SLProps](#geomlprop_clprops--slprops) · [BRepOffset\_SimpleOffset](#brepoffset_simpleoffset) · [Approx\_CurvilinearParameter](#approx_curvilinearparameter) · [GeomInt\_IntSS](#geomint_intss) · [Contap\_Contour](#contap_contour) · [BRepFeat\_Builder](#brepfeat_builder) · [GeomFill Trihedron Laws / Coons / Curved / CoonsAlgPatch](#geomfill-trihedron-laws--coons--curved--coonsalgpatch)

---

## v0.50 Polyhedral Distance / History / Wire-Vertex / Nearest Plane

### `PolyhedralDistance`

Result of an approximate (mesh-based) distance query.

```swift
public struct PolyhedralDistance {
    public let distance: Double
    public let point1: SIMD3<Double>
    public let point2: SIMD3<Double>
}
```

- **Fields:** `distance` — approximate distance; `point1` — closest point on the first shape; `point2` — closest point on the second shape.

---

### `polyhedralDistance(to:)`

Compute fast polyhedral (approximate) distance to another shape.

```swift
public func polyhedralDistance(to other: Shape) -> PolyhedralDistance?
```

Both shapes must be meshed (have triangulation). Faster than exact distance but less precise.

- **Parameters:** `other` — the shape to measure against.
- **Returns:** `PolyhedralDistance`, or `nil` if either shape has no triangulation or computation fails.
- **OCCT:** `BRepExtrema_Poly` via `OCCTShapePolyhedralDistance`.
- **Example:**
  ```swift
  if let d = box.polyhedralDistance(to: sphere) {
      print(d.distance)
  }
  ```

---

### `History`

Shape modification history for tracking what happened during operations.

```swift
public class History {
    public init?()
    public func addModified(initial: Shape, modified: Shape)
    public func addGenerated(initial: Shape, generated: Shape)
    public func remove(_ shape: Shape)
    public func isRemoved(_ shape: Shape) -> Bool
    public var hasModified: Bool { get }
    public var hasGenerated: Bool { get }
    public var hasRemoved: Bool { get }
    public func modifiedCount(of shape: Shape) -> Int
    public func generatedCount(of shape: Shape) -> Int
}
```

A reference-counted history store wrapping `OCCTHistoryRef`. Freed in `deinit`.

- **OCCT:** `BRepTools_History` / `OCCTHistory*` bridge family.

#### `History.init?()`

Create an empty history object.

```swift
public init?()
```

- **Returns:** New `History`, or `nil` if the underlying handle cannot be allocated.
- **OCCT:** `OCCTHistoryCreate`.

#### `addModified(initial:modified:)`

Record that an initial shape was modified into a new shape.

```swift
public func addModified(initial: Shape, modified: Shape)
```

- **OCCT:** `OCCTHistoryAddModified`.

#### `addGenerated(initial:generated:)`

Record that an initial shape produced a new generated shape.

```swift
public func addGenerated(initial: Shape, generated: Shape)
```

- **OCCT:** `OCCTHistoryAddGenerated`.

#### `remove(_:)`

Record that a shape was removed during the operation.

```swift
public func remove(_ shape: Shape)
```

- **OCCT:** `OCCTHistoryRemove`.

#### `isRemoved(_:)`

Check whether a shape was recorded as removed.

```swift
public func isRemoved(_ shape: Shape) -> Bool
```

- **OCCT:** `OCCTHistoryIsRemoved`.

#### `hasModified`, `hasGenerated`, `hasRemoved`

Whether any modifications / generations / removals were recorded.

```swift
public var hasModified: Bool { get }
public var hasGenerated: Bool { get }
public var hasRemoved: Bool { get }
```

- **OCCT:** `OCCTHistoryHasModified`, `OCCTHistoryHasGenerated`, `OCCTHistoryHasRemoved`.

#### `modifiedCount(of:)`

Number of shapes the given initial shape was modified to.

```swift
public func modifiedCount(of shape: Shape) -> Int
```

- **OCCT:** `OCCTHistoryModifiedCount`.

#### `generatedCount(of:)`

Number of shapes generated from the given initial shape.

```swift
public func generatedCount(of shape: Shape) -> Int
```

- **OCCT:** `OCCTHistoryGeneratedCount`.

---

### `WireVertexAnalysis`

Result of wire vertex connectivity analysis.

```swift
public struct WireVertexAnalysis {
    public let edgeCount: Int
    public let isDone: Bool
}
```

---

### `WireVertexStatus`

Vertex connection status codes.

```swift
public enum WireVertexStatus: Int32 {
    case sameVertex = 0
    case sameCoords = 1
    case close = 2
    case end = 3
    case start = 4
    case intersection = 5
    case disjoined = -1
    case unknown = -2
}
```

---

### `wireVertexAnalysis(precision:)`

Analyze wire vertex connections for gaps, overlaps, and intersections.

```swift
public func wireVertexAnalysis(precision: Double = 0.01) -> WireVertexAnalysis
```

- **Parameters:** `precision` — tolerance for vertex comparison.
- **Returns:** `WireVertexAnalysis` with edge count and a completion flag.
- **OCCT:** `ShapeAnalysis_WireVertex` via `OCCTShapeWireVertexAnalysis`.
- **Example:**
  ```swift
  let a = wire.wireVertexAnalysis(precision: 1e-4)
  print(a.edgeCount, a.isDone)
  ```

---

### `wireVertexStatus(precision:index:)`

Get the status of a specific vertex in a wire.

```swift
public func wireVertexStatus(precision: Double = 0.01, index: Int) -> WireVertexStatus
```

- **Parameters:** `precision` — analysis tolerance; `index` — 0-based vertex index.
- **Returns:** `WireVertexStatus` case, or `.unknown` for unrecognised codes.
- **OCCT:** `OCCTShapeWireVertexStatus`.

---

### `NearestPlane`

Result of least-squares plane fitting.

```swift
public struct NearestPlane {
    public let normal: SIMD3<Double>
    public let origin: SIMD3<Double>
    public let maxDeviation: Double
}
```

- **Fields:** `normal` — fitted plane normal; `origin` — a point on the plane; `maxDeviation` — maximum distance from any input point to the fitted plane.

---

### `Shape.nearestPlane(to:)`

Fit the nearest plane to a set of 3D points using least-squares.

```swift
public static func nearestPlane(to points: [SIMD3<Double>]) -> NearestPlane?
```

- **Parameters:** `points` — array of at least 3 points.
- **Returns:** `NearestPlane`, or `nil` if fewer than 3 points are provided or fitting fails.
- **OCCT:** `gp_Pln` / `OCCTShapeNearestPlane`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0)]
  if let plane = Shape.nearestPlane(to: pts) {
      print(plane.normal)  // ≈ (0, 0, 1)
  }
  ```

---

## v0.51 BRepLib\_MakeSolid / GC Transforms / ChFi2d\_AnaFilletAlgo

### `Shape.solidFromShell(_:)`

Create a solid from a shell shape using `BRepLib_MakeSolid`.

```swift
public static func solidFromShell(_ shell: Shape) -> Shape?
```

- **Parameters:** `shell` — a shape containing a closed shell (e.g. from `shellFromSurface`).
- **Returns:** Solid shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeSolid` via `OCCTShapeMakeSolidFromShell`.
- **Example:**
  ```swift
  if let solid = Shape.solidFromShell(myShell) {
      print(solid.isValid)
  }
  ```

---

### `mirroredAboutPoint(_:)`

Mirror this shape about a point (point symmetry / inversion).

```swift
public func mirroredAboutPoint(_ point: SIMD3<Double>) -> Shape?
```

- **Parameters:** `point` — centre of the point mirror.
- **Returns:** Mirrored shape, or `nil` on failure.
- **OCCT:** `gp_Trsf` point mirror via `OCCTShapeMirrorAboutPoint`.
- **Example:**
  ```swift
  let inverted = box.mirroredAboutPoint(SIMD3(5, 0, 0))
  ```

---

### `mirroredAboutAxis(origin:direction:)`

Mirror this shape about an axis line.

```swift
public func mirroredAboutAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Shape?
```

- **Parameters:** `origin` — a point on the axis; `direction` — axis direction.
- **Returns:** Mirrored shape, or `nil` on failure.
- **OCCT:** `gp_Trsf` axis mirror via `OCCTShapeMirrorAboutAxis`.

---

### `scaledAboutPoint(_:factor:)`

Scale this shape about a specific centre point.

```swift
public func scaledAboutPoint(_ center: SIMD3<Double>, factor: Double) -> Shape?
```

Unlike `scaled(by:)` which scales about the origin, this scales about the given point.

- **Parameters:** `center` — centre of scaling; `factor` — scale factor.
- **Returns:** Scaled shape, or `nil` on failure.
- **OCCT:** `gp_Trsf` scale via `OCCTShapeScaleAboutPoint`.

---

### `translated(from:to:)`

Translate this shape by the vector from one point to another.

```swift
public func translated(from: SIMD3<Double>, to: SIMD3<Double>) -> Shape?
```

- **Parameters:** `from` — start of the translation vector; `to` — end of the translation vector.
- **Returns:** Translated shape, or `nil` on failure.
- **OCCT:** `gp_Vec` translation via `OCCTShapeTranslateByPoints`.

---

### `AnaFilletResult`

Result of a 2D analytical fillet operation.

```swift
public struct AnaFilletResult {
    public let fillet: Shape
    public let edge1: Shape
    public let edge2: Shape
}
```

- **Fields:** `fillet` — the arc edge; `edge1`, `edge2` — trimmed input edges.

---

### `Shape.anaFillet(edge1:edge2:planeOrigin:planeNormal:radius:)` (Shape overload)

Compute a 2D analytical fillet between two edge shapes.

```swift
public static func anaFillet(
    edge1: Shape,
    edge2: Shape,
    planeOrigin: SIMD3<Double> = .zero,
    planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> AnaFilletResult?
```

Uses `ChFi2d_AnaFilletAlgo` for fast exact fillet computation in a plane. Supports only line and arc-of-circle edges.

- **Parameters:** `edge1`, `edge2` — edge shapes; `planeOrigin` — a point on the working plane; `planeNormal` — plane normal; `radius` — fillet radius.
- **Returns:** `AnaFilletResult`, or `nil` if computation fails.
- **OCCT:** `ChFi2d_AnaFilletAlgo` via `OCCTChFi2dAnaFillet`.
- **Example:**
  ```swift
  if let r = Shape.anaFillet(edge1: e1, edge2: e2, radius: 2) {
      // r.fillet, r.edge1, r.edge2
  }
  ```

---

### `Shape.anaFillet(edge1:edge2:planeOrigin:planeNormal:radius:)` (Edge overload)

Convenience overload accepting `Edge` objects directly.

```swift
public static func anaFillet(
    edge1: Edge, edge2: Edge,
    planeOrigin: SIMD3<Double> = .zero,
    planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> AnaFilletResult?
```

- **OCCT:** `ChFi2d_AnaFilletAlgo` (via `Shape.fromEdge` conversion then `OCCTChFi2dAnaFillet`).

---

### `Shape.anaFillet(wire:edgeIndex:planeOrigin:planeNormal:radius:)`

Compute a 2D analytical fillet between two adjacent edges of a wire.

```swift
public static func anaFillet(
    wire: Wire, edgeIndex: Int = 0,
    planeOrigin: SIMD3<Double> = .zero,
    planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> AnaFilletResult?
```

Edge indices are 0-based; the fillet is computed between `edges[edgeIndex]` and `edges[edgeIndex + 1]`.

- **Parameters:** `wire` — source wire; `edgeIndex` — index of the first edge; remaining parameters as above.
- **Returns:** `AnaFilletResult`, or `nil` if indices are out of range or fillet fails.
- **OCCT:** `ChFi2d_AnaFilletAlgo`.

---

## BRepFill\_Generator / AdvancedEvolved / OffsetWire / Draft / Pipe / CompatibleWires

### `Shape.ruledShell(from:)`

Create a ruled shell by lofting between multiple wire sections.

```swift
public static func ruledShell(from wires: [Wire]) -> Shape?
```

Each pair of adjacent wires generates a ruled surface between them. Wires should have the same number of edges for best results.

- **Parameters:** `wires` — at least 2 wires.
- **Returns:** Shell shape, or `nil` on failure.
- **OCCT:** `BRepFill_Generator` via `OCCTBRepFillGenerator`.
- **Example:**
  ```swift
  let bottom = Wire.rectangle(width: 10, height: 10)!
  let top = Wire.circle(center: SIMD3(0, 0, 5), radius: 5)!
  if let shell = Shape.ruledShell(from: [bottom, top]) { }
  ```

---

### `Shape.advancedEvolved(spine:profile:tolerance:solid:)`

Create an evolved solid from a spine wire and profile wire.

```swift
public static func advancedEvolved(
    spine: Wire, profile: Wire,
    tolerance: Double = 1e-3, solid: Bool = true
) -> Shape?
```

The profile is oriented perpendicular to the spine at each point and swept along it.

- **Parameters:** `spine` — sweep path; `profile` — cross-section; `tolerance` — geometric tolerance; `solid` — produce a solid when `true`.
- **Returns:** Evolved shape, or `nil` on failure.
- **OCCT:** `BRepFill_AdvancedEvolved` via `OCCTBRepFillAdvancedEvolved`.

---

### `Shape.offsetWire(face:offset:)`

Offset a planar wire on its face.

```swift
public static func offsetWire(face: Face, offset: Double) -> Shape?
```

Positive offset expands outward; negative shrinks inward.

- **Parameters:** `face` — face containing the wire to offset; `offset` — signed offset distance.
- **Returns:** Offset wire shape, or `nil` on failure.
- **OCCT:** `BRepFill_OffsetWire` via `OCCTBRepFillOffsetWire`.

---

### `Shape.draft(wire:direction:angle:length:)`

Create a draft surface from a wire along a direction with a taper angle.

```swift
public static func draft(
    wire: Wire, direction: SIMD3<Double>,
    angle: Double, length: Double
) -> Shape?
```

The wire is projected along `direction` for `length`, with faces tapered at `angle` from the direction.

- **Parameters:** `wire` — base profile; `direction` — draft direction; `angle` — taper angle in radians; `length` — draft length.
- **Returns:** Draft shape, or `nil` on failure.
- **OCCT:** `BRepFill_Draft` via `OCCTBRepFillDraft`.

---

### `PipeSweepResult`

Result of a pipe sweep operation.

```swift
public struct PipeSweepResult {
    public let shape: Shape
    public let errorOnSurface: Double
}
```

- **Fields:** `shape` — the swept pipe; `errorOnSurface` — surface approximation error.

---

### `Shape.pipeSweep(spine:profile:)`

Create a pipe sweep of a profile along a spine with error reporting.

```swift
public static func pipeSweep(spine: Wire, profile: Wire) -> PipeSweepResult?
```

Sweeps the profile wire along the spine wire using a corrected Frenet trihedron.

- **Parameters:** `spine` — sweep path; `profile` — cross-section wire.
- **Returns:** `PipeSweepResult`, or `nil` on failure.
- **OCCT:** `BRepFill_Pipe` via `OCCTBRepFillPipe`.
- **Example:**
  ```swift
  if let result = Shape.pipeSweep(spine: path, profile: circle) {
      print(result.errorOnSurface)
  }
  ```

---

### `Shape.compatibleWires(_:)`

Make wires compatible for lofting (same number of edges, consistently oriented).

```swift
public static func compatibleWires(_ wires: [Wire]) -> [Wire]?
```

Resamples wires so they have the same edge count and orientation, which improves lofting quality.

- **Parameters:** `wires` — at least 2 wires to normalize.
- **Returns:** Array of compatible `Wire` objects, or `nil` on failure.
- **OCCT:** `BRepFill_CompatibleWires` via `OCCTBRepFillCompatibleWires`.

---

## ChFi2d\_FilletAlgo

### `FilletAlgoResult`

Result of a 2D iterative fillet operation.

```swift
public struct FilletAlgoResult {
    public let fillet: Shape
    public let edge1: Shape
    public let edge2: Shape
    public let resultCount: Int
}
```

- **Fields:** `fillet` — the arc edge; `edge1`, `edge2` — trimmed edges; `resultCount` — number of fillet solutions found.

---

### `Shape.filletAlgo(edge1:edge2:planeOrigin:planeNormal:radius:)` (Shape overload)

Compute a 2D iterative fillet between two edge shapes in a plane.

```swift
public static func filletAlgo(
    edge1: Shape, edge2: Shape,
    planeOrigin: SIMD3<Double> = .zero,
    planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> FilletAlgoResult?
```

Uses `ChFi2d_FilletAlgo` which supports general edge types, unlike `anaFillet` which is limited to lines and arcs.

- **Parameters:** `edge1`, `edge2` — edge shapes; `planeOrigin`, `planeNormal` — working plane; `radius` — fillet radius.
- **Returns:** `FilletAlgoResult`, or `nil` on failure.
- **OCCT:** `ChFi2d_FilletAlgo` via `OCCTChFi2dFilletAlgo`.

---

### `Shape.filletAlgo(edge1:edge2:planeOrigin:planeNormal:radius:)` (Edge overload)

Convenience overload accepting `Edge` objects directly.

```swift
public static func filletAlgo(
    edge1: Edge, edge2: Edge,
    planeOrigin: SIMD3<Double> = .zero,
    planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> FilletAlgoResult?
```

- **OCCT:** `ChFi2d_FilletAlgo`.

---

### `Shape.filletAlgo(wire:edgeIndex:planeOrigin:planeNormal:radius:)`

Compute a 2D iterative fillet between two adjacent edges of a wire.

```swift
public static func filletAlgo(
    wire: Wire, edgeIndex: Int = 0,
    planeOrigin: SIMD3<Double> = .zero,
    planeNormal: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double
) -> FilletAlgoResult?
```

- **Parameters:** `wire` — source wire; `edgeIndex` — 0-based index of the first edge.
- **Returns:** `FilletAlgoResult`, or `nil` if indices are out of range or fillet fails.
- **OCCT:** `ChFi2d_FilletAlgo`.

---

## BRepTools\_Substitution

### `substituted(replacing:with:)`

Substitute a topological sub-shape within this shape and rebuild the parent.

```swift
public func substituted(replacing oldSubShape: Shape, with newSubShape: Shape) -> Shape?
```

Replaces a vertex, edge, or face with another sub-shape and rebuilds the containing topology.

- **Parameters:** `oldSubShape` — the sub-shape to replace; `newSubShape` — the replacement.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepTools_Substitution` via `OCCTBRepToolsSubstitute`.

---

## ShapeUpgrade\_ShellSewing

### `shellSewing(tolerance:)`

Sew disconnected shells in this shape.

```swift
public func shellSewing(tolerance: Double = 1e-6) -> Shape?
```

Connects shells that share edges within the given tolerance.

- **Parameters:** `tolerance` — sewing tolerance (default `1e-6`).
- **Returns:** Sewn shape, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShellSewing` via `OCCTShapeUpgradeShellSewing`.

---

## LocOpe\_BuildShape

### `builtFromFaces()`

Build a shape from the faces of this shape.

```swift
public func builtFromFaces() -> Shape?
```

Extracts all faces and reconstructs them into a shell or solid.

- **Returns:** Rebuilt shape, or `nil` on failure.
- **OCCT:** `LocOpe_BuildShape` via `OCCTLocOpeBuildShape`.

---

## BOPAlgo Splitter / ArgumentAnalyzer

### `Shape.split(objects:by:)`

Split shapes by tool shapes using `BOPAlgo_Splitter`.

```swift
public static func split(objects: [Shape], by tools: [Shape]) -> Shape?
```

Partitions the object shapes using the tool shapes as cutting geometry. All fragments are returned in a single compound.

- **Parameters:** `objects` — shapes to be split; `tools` — cutting tools.
- **Returns:** Compound of all split fragments, or `nil` on failure.
- **OCCT:** `BOPAlgo_Splitter` via `OCCTBOPAlgoSplit`.
- **Example:**
  ```swift
  let fragments = Shape.split(objects: [block], by: [cuttingPlane])
  ```

---

### `BooleanOperation`

Boolean operation type for argument analysis.

```swift
public enum BooleanOperation: Int32 {
    case fuse = 0
    case common = 1
    case cut = 2
    case cut21 = 3
    case section = 4
}
```

---

### `Shape.analyzeBoolean(_:_:operation:)`

Analyze whether two shapes are valid for a Boolean operation.

```swift
public static func analyzeBoolean(_ shape1: Shape, _ shape2: Shape,
                                   operation: BooleanOperation = .fuse) -> Bool
```

Checks for self-intersection, small edges, and argument type compatibility.

- **Parameters:** `shape1` — object shape; `shape2` — tool shape; `operation` — the operation to validate.
- **Returns:** `true` if the shapes pass validation for the given operation.
- **OCCT:** `BOPAlgo_ArgumentAnalyzer` via `OCCTBOPAlgoAnalyzeArguments`.

---

## IntCurvesFace Intersection

### `LineFaceIntersection`

Result of a line-face intersection.

```swift
public struct LineFaceIntersection {
    public let point: SIMD3<Double>
    public let parameter: Double
}
```

- **Fields:** `point` — 3D intersection point; `parameter` — line parameter at intersection.

---

### `intersectLine(origin:direction:paramRange:)`

Intersect a line with this shape (must be a face).

```swift
public func intersectLine(origin: SIMD3<Double>, direction: SIMD3<Double>,
                          paramRange: ClosedRange<Double> = -1000...1000) -> [LineFaceIntersection]
```

- **Parameters:** `origin` — line origin; `direction` — line direction; `paramRange` — parameter bounds on the line.
- **Returns:** Array of intersection results (may be empty).
- **OCCT:** `IntCurvesFace_Intersector` via `OCCTIntersectLineFace`.
- **Example:**
  ```swift
  let hits = face.intersectLine(origin: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1))
  ```

---

## Contap Contour Analysis

### `ContourType`

Contour type from analytical contour computation.

```swift
public enum ContourType: Int32 {
    case line = 0
    case circle = 1
    case other = 2
}
```

---

### `ContourResult`

Result of an analytical contour computation.

```swift
public struct ContourResult {
    public let type: ContourType
    public let count: Int
    public let data: [Double]
}
```

- **Fields:** `type` — contour geometry kind; `count` — number of contours; `data` — raw parameters (for circles: centre and radius; for lines: location and direction).

---

### `Shape.contourSphereDir(center:radius:direction:)`

Compute the silhouette contour of a sphere for an orthographic view direction.

```swift
public static func contourSphereDir(center: SIMD3<Double>, radius: Double,
                                     direction: SIMD3<Double>) -> ContourResult?
```

- **Parameters:** `center` — sphere centre; `radius` — sphere radius; `direction` — orthographic view direction.
- **Returns:** `ContourResult`, or `nil` on failure.
- **OCCT:** `Contap_ContAna` via `OCCTContapSphereDir`.

---

### `Shape.contourCylinderDir(origin:axis:radius:direction:)`

Compute the silhouette contour of a cylinder for an orthographic view direction.

```swift
public static func contourCylinderDir(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                       radius: Double, direction: SIMD3<Double>) -> ContourResult?
```

- **Parameters:** `origin` — cylinder axis origin; `axis` — axis direction; `radius` — radius; `direction` — view direction.
- **Returns:** `ContourResult`, or `nil` on failure.
- **OCCT:** `Contap_ContAna` via `OCCTContapCylinderDir`.

---

### `Shape.contourSphereEye(center:radius:eye:)`

Compute the silhouette contour of a sphere for a perspective eye point.

```swift
public static func contourSphereEye(center: SIMD3<Double>, radius: Double,
                                     eye: SIMD3<Double>) -> ContourResult?
```

- **Parameters:** `center` — sphere centre; `radius` — sphere radius; `eye` — perspective eye point.
- **Returns:** `ContourResult`, or `nil` on failure.
- **OCCT:** `Contap_ContAna` via `OCCTContapSphereEye`.

---

## BRepMesh\_Deflection

### `computeAbsoluteDeflection(relativeDeflection:maxShapeSize:)`

Convert a relative deflection value to an absolute deflection for meshing.

```swift
public func computeAbsoluteDeflection(relativeDeflection: Double, maxShapeSize: Double) -> Double?
```

- **Parameters:** `relativeDeflection` — relative deflection; `maxShapeSize` — maximum dimension of the shape.
- **Returns:** Absolute deflection, or `nil` if computation fails (negative result from bridge).
- **OCCT:** `BRepMesh_Deflection` via `OCCTComputeAbsoluteDeflection`.

---

### `Shape.deflectionIsConsistent(current:required:allowDecrease:ratio:)`

Check whether a mesh deflection is consistent with requirements.

```swift
public static func deflectionIsConsistent(current: Double, required: Double,
                                           allowDecrease: Bool = false,
                                           ratio: Double = 0.1) -> Bool
```

- **Parameters:** `current` — current deflection; `required` — required deflection; `allowDecrease` — permit finer mesh than required; `ratio` — comparison ratio (0–1).
- **Returns:** `true` if the current deflection is acceptable.
- **OCCT:** `BRepMesh_Deflection::IsConsistent` via `OCCTDeflectionIsConsistent`.

---

## BRepBuilderAPI\_MakeShapeOnMesh

### `Shape.fromMesh(points:triangles:)`

Build a topological shape from a triangulated mesh.

```swift
public static func fromMesh(points: [SIMD3<Double>], triangles: [(Int32, Int32, Int32)]) -> Shape?
```

- **Parameters:** `points` — mesh vertices; `triangles` — index triples using 1-based indices into `points`.
- **Returns:** Shape from the mesh, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeShapeOnMesh` via `OCCTShapeFromMesh`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0)]
  let tris: [(Int32, Int32, Int32)] = [(1, 2, 3)]
  let shape = Shape.fromMesh(points: pts, triangles: tris)
  ```

---

## GeomPlate\_Surface

### `Shape.plateSurface(points:tolerance:maxDegree:maxSegments:)`

Build a smooth plate surface through point constraints.

```swift
public static func plateSurface(points: [SIMD3<Double>], tolerance: Double = 1e-3,
                                 maxDegree: Int = 8, maxSegments: Int = 20) -> Shape?
```

Creates a smooth BSpline surface that passes through or near the given points. Useful for surfaces from scattered point data.

- **Parameters:** `points` — 3D points to fit; `tolerance` — approximation tolerance; `maxDegree` — max BSpline degree; `maxSegments` — max BSpline segments.
- **Returns:** Face with plate surface, or `nil` on failure.
- **OCCT:** `GeomPlate_BuildPlateSurface` + `GeomPlate_MakeApprox` via `OCCTGeomPlateSurface`.

---

## CellsBuilder

Builder for Boolean cell operations. Partitions input shapes into cells (volumetric fragments), assigns material IDs, and lets you select which cells to include in the result. The class is a standalone `final class`, not a member of `Shape`.

### `CellsBuilder.init?(shapes:)`

Create a `CellsBuilder` by partitioning a set of input shapes into cells.

```swift
public init?(shapes: [Shape])
```

- **Parameters:** `shapes` — input shapes to partition.
- **Returns:** `CellsBuilder`, or `nil` if partitioning fails.
- **OCCT:** `BOPAlgo_CellsBuilder` via `OCCTCellsBuilderCreate`.

---

### `addAllToResult(material:)`

Add all split cells to the result with a given material ID.

```swift
public func addAllToResult(material: Int32 = 0)
```

- **Parameters:** `material` — material ID to assign (default `0`).
- **OCCT:** `OCCTCellsBuilderAddAllToResult`.

---

### `removeAllFromResult()`

Remove all cells from the current result.

```swift
public func removeAllFromResult()
```

- **OCCT:** `OCCTCellsBuilderRemoveAllFromResult`.

---

### `removeInternalBoundaries()`

Merge adjacent cells that share the same material ID, removing internal faces.

```swift
public func removeInternalBoundaries()
```

- **OCCT:** `BOPAlgo_CellsBuilder::RemoveInternalBoundaries` via `OCCTCellsBuilderRemoveInternalBoundaries`.

---

### `result()`

Get the current result shape.

```swift
public func result() -> Shape?
```

- **Returns:** Result compound shape, or `nil` if no cells have been added.
- **OCCT:** `OCCTCellsBuilderGetResult`.
- **Example:**
  ```swift
  if let cb = CellsBuilder(shapes: [box, sphere]) {
      cb.addAllToResult(material: 1)
      cb.removeInternalBoundaries()
      let merged = cb.result()
  }
  ```

---

## BRepLib\_MakeEdge / MakeFace / MakeShell / ToolTriangulatedShape / PointCloudShape

### `Shape.edgeFromLine(origin:direction:p1:p2:)`

Create an edge from a line with parameter bounds.

```swift
public static func edgeFromLine(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    p1: Double,
    p2: Double
) -> Shape?
```

- **Parameters:** `origin` — line origin point; `direction` — line direction; `p1`, `p2` — parameter bounds.
- **Returns:** Edge shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge(gp_Lin, p1, p2)` via `OCCTBRepLibMakeEdgeFromLine`.

---

### `Shape.edgeFromPoints(_:_:)`

Create an edge from two 3D points.

```swift
public static func edgeFromPoints(_ p1: SIMD3<Double>, _ p2: SIMD3<Double>) -> Shape?
```

- **Parameters:** `p1`, `p2` — start and end points.
- **Returns:** Edge shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge(gp_Pnt, gp_Pnt)` via `OCCTBRepLibMakeEdgeFromPoints`.

---

### `Shape.edgeFromCircle(center:axis:radius:p1:p2:)`

Create an edge from a circle arc with parameter bounds.

```swift
public static func edgeFromCircle(
    center: SIMD3<Double>,
    axis: SIMD3<Double>,
    radius: Double,
    p1: Double,
    p2: Double
) -> Shape?
```

- **Parameters:** `center` — circle centre; `axis` — normal axis; `radius` — radius; `p1`, `p2` — angular bounds in radians.
- **Returns:** Edge shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeEdge(gp_Circ, p1, p2)` via `OCCTBRepLibMakeEdgeFromCircle`.

---

### `Shape.faceFromPlane(origin:normal:uRange:vRange:tolerance:)`

Create a face from a plane surface with UV bounds.

```swift
public static func faceFromPlane(
    origin: SIMD3<Double>,
    normal: SIMD3<Double>,
    uRange: ClosedRange<Double>,
    vRange: ClosedRange<Double>,
    tolerance: Double = 1e-6
) -> Shape?
```

- **Parameters:** `origin` — point on the plane; `normal` — plane normal; `uRange`, `vRange` — parameter bounds; `tolerance` — vertex tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeFace(gp_Pln, ...)` via `OCCTBRepLibMakeFaceFromPlane`.

---

### `Shape.faceFromCylinder(origin:axis:radius:uRange:vRange:tolerance:)`

Create a face from a cylindrical surface with UV bounds.

```swift
public static func faceFromCylinder(
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    radius: Double,
    uRange: ClosedRange<Double>,
    vRange: ClosedRange<Double>,
    tolerance: Double = 1e-6
) -> Shape?
```

- **Parameters:** `origin` — axis origin; `axis` — axis direction; `radius` — cylinder radius; `uRange` — angular bounds (radians); `vRange` — axial bounds; `tolerance` — vertex tolerance.
- **Returns:** Face shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeFace(gp_Cylinder, ...)` via `OCCTBRepLibMakeFaceFromCylinder`.

---

### `Shape.shellFromPlane(origin:normal:uRange:vRange:)`

Create a shell from a plane surface with UV bounds.

```swift
public static func shellFromPlane(
    origin: SIMD3<Double>,
    normal: SIMD3<Double>,
    uRange: ClosedRange<Double>,
    vRange: ClosedRange<Double>
) -> Shape?
```

- **Parameters:** `origin` — point on the plane; `normal` — plane normal; `uRange`, `vRange` — parameter bounds.
- **Returns:** Shell shape, or `nil` on failure.
- **OCCT:** `BRepLib_MakeShell(gp_Pln, ...)` via `OCCTBRepLibMakeShellFromPlane`.

---

### `computeNormals()`

Compute normals on the triangulation of all faces in this shape.

```swift
public func computeNormals() -> Bool
```

The shape must be meshed first.

- **Returns:** `true` if normals were computed successfully.
- **OCCT:** `BRepLib_ToolTriangulatedShape::ComputeNormals` via `OCCTBRepLibComputeNormals`.

---

### `PointCloudResult`

Point cloud positions and normals.

```swift
public struct PointCloudResult: Sendable {
    public let points: [SIMD3<Double>]
    public let normals: [SIMD3<Double>]
}
```

---

### `pointCloudByTriangulation()`

Generate a point cloud from this shape's triangulation.

```swift
public func pointCloudByTriangulation() -> PointCloudResult?
```

The shape must be meshed first. One point and normal per triangulation node.

- **Returns:** `PointCloudResult`, or `nil` if the shape has no triangulation or generation fails.
- **OCCT:** `BRepLib_PointCloudShape::GetPoints` via `OCCTBRepLibPointCloudByTriangulation`.

---

### `pointCloudByDensity(_:)`

Generate a point cloud from this shape by density (points per unit area).

```swift
public func pointCloudByDensity(_ density: Double) -> PointCloudResult?
```

The shape must be meshed first.

- **Parameters:** `density` — target number of points per unit area.
- **Returns:** `PointCloudResult`, or `nil` on failure.
- **OCCT:** `BRepLib_PointCloudShape::GetPointsByDensity` via `OCCTBRepLibPointCloudByDensity`.

---

## BRepBuilderAPI\_MakeEdge2d

### `Shape.edge2d(from:to:)`

Create a 2D edge from two 2D points.

```swift
public static func edge2d(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> Shape?
```

- **Parameters:** `p1`, `p2` — start and end points in 2D.
- **Returns:** 2D edge shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeEdge2d(gp_Pnt2d, gp_Pnt2d)` via `OCCTMakeEdge2dFromPoints`.

---

### `Shape.edge2dFromCircle(center:direction:radius:p1:p2:)`

Create a 2D edge from a circle arc with parameter bounds.

```swift
public static func edge2dFromCircle(
    center: SIMD2<Double>,
    direction: SIMD2<Double>,
    radius: Double,
    p1: Double,
    p2: Double
) -> Shape?
```

- **Parameters:** `center` — 2D circle centre; `direction` — orientation; `radius` — radius; `p1`, `p2` — angular bounds.
- **Returns:** 2D edge shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeEdge2d(gp_Circ2d, p1, p2)` via `OCCTMakeEdge2dFromCircle`.

---

### `Shape.edge2dFromLine(origin:direction:p1:p2:)`

Create a 2D edge from a line with parameter bounds.

```swift
public static func edge2dFromLine(
    origin: SIMD2<Double>,
    direction: SIMD2<Double>,
    p1: Double,
    p2: Double
) -> Shape?
```

- **Parameters:** `origin` — 2D line origin; `direction` — line direction; `p1`, `p2` — parameter bounds.
- **Returns:** 2D edge shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeEdge2d(gp_Lin2d, p1, p2)` via `OCCTMakeEdge2dFromLine`.

---

## BRepTools\_Modifier + NurbsConvert

### `nurbsConvertViaModifier()`

Convert this shape to NURBS using `BRepTools_Modifier` with `BRepTools_NurbsConvertModification`.

```swift
public func nurbsConvertViaModifier() -> Shape?
```

- **Returns:** NURBS-converted shape, or `nil` on failure.
- **OCCT:** `BRepTools_Modifier` + `BRepTools_NurbsConvertModification` via `OCCTBRepToolsModifierNurbsConvert`.
- **Note:** Prefer `nurbsConvert()` for straightforward conversions; use this variant when you need the modifier-based pipeline.

---

## ShapeCustom\_Direct / TrsfModification

### `directModification()`

Orient face normals outward using `ShapeCustom_DirectModification`.

```swift
public func directModification() -> Shape?
```

- **Returns:** Shape with consistently outward-oriented face normals, or `nil` on failure.
- **OCCT:** `ShapeCustom_DirectModification` via `OCCTShapeCustomDirectModification`.

---

### `trsfModificationScale(_:)`

Apply a uniform scale with proper tolerance handling via `ShapeCustom_TrsfModification`.

```swift
public func trsfModificationScale(_ scaleFactor: Double) -> Shape?
```

Unlike the basic `scaled(by:)` transform, this propagates tolerance updates correctly through the topology.

- **Parameters:** `scaleFactor` — uniform scale factor.
- **Returns:** Scaled shape, or `nil` on failure.
- **OCCT:** `ShapeCustom_TrsfModification` via `OCCTShapeCustomTrsfModificationScale`.

---

## LocOpe Builders

### `buildWires(faceIndex:)`

Build wires from the edges of a face.

```swift
public func buildWires(faceIndex: Int32 = 0) -> [Shape]?
```

- **Parameters:** `faceIndex` — 1-based face index (`0` = all edges).
- **Returns:** Array of wire shapes, or `nil` on failure.
- **OCCT:** `LocOpe_BuildWires` via `OCCTLocOpeBuildWires`.

---

### `splitByWireOnFace(_:faceIndex:)`

Split a face of this shape by projecting a wire onto it.

```swift
public func splitByWireOnFace(_ wire: Shape, faceIndex: Int32) -> Shape?
```

- **Parameters:** `wire` — the splitting wire shape; `faceIndex` — 1-based index of the face to split.
- **Returns:** Modified shape with the face split, or `nil` on failure.
- **OCCT:** `LocOpe_WiresOnShape` + `LocOpe_Spliter` via `OCCTLocOpeSplitByWireOnFace`.

---

### `curveShapeIntersect(origin:direction:)`

Intersect a line with this shape and return parameter values on the line.

```swift
public func curveShapeIntersect(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>
) -> [Double]?
```

- **Parameters:** `origin` — line origin; `direction` — line direction.
- **Returns:** Array of parameter values where the line intersects the shape, or `nil` on failure.
- **OCCT:** `LocOpe_CurveShapeIntersector` via `OCCTLocOpeCurveShapeIntersectLine`.

---

## CPnts\_UniformDeflection

### `DeflectionResult`

Discretization result with parameters and 3D points.

```swift
public struct DeflectionResult: Sendable {
    public let parameters: [Double]
    public let points: [SIMD3<Double>]
}
```

---

### `uniformDeflection(_:)`

Discretize an edge by uniform deflection over its full parameter range.

```swift
public func uniformDeflection(_ deflection: Double) -> DeflectionResult?
```

- **Parameters:** `deflection` — maximum chord deflection.
- **Returns:** `DeflectionResult`, or `nil` on failure.
- **OCCT:** `GCPnts_UniformDeflection` via `OCCTCPntsUniformDeflection`.
- **Example:**
  ```swift
  if let d = edge.uniformDeflection(0.1) {
      // d.points — evenly deflection-spaced 3D samples
  }
  ```

---

### `uniformDeflection(_:range:)`

Discretize an edge by uniform deflection within a parameter range.

```swift
public func uniformDeflection(_ deflection: Double, range: ClosedRange<Double>) -> DeflectionResult?
```

- **Parameters:** `deflection` — maximum chord deflection; `range` — parameter range to sample.
- **Returns:** `DeflectionResult`, or `nil` on failure.
- **OCCT:** `GCPnts_UniformDeflection` with range via `OCCTCPntsUniformDeflectionRange`.

---

## IntCurvesFace\_ShapeIntersector

### `RayIntersection`

Ray-shape intersection result.

```swift
public struct RayIntersection: Sendable {
    public let point: SIMD3<Double>
    public let parameter: Double
}
```

- **Fields:** `point` — 3D hit point; `parameter` — parameter on the ray.

---

### `rayIntersect(origin:direction:)`

Intersect a ray with all faces of this shape.

```swift
public func rayIntersect(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>
) -> [RayIntersection]?
```

- **Parameters:** `origin` — ray origin; `direction` — ray direction.
- **Returns:** Array of intersections sorted by parameter, or `nil` on failure (empty shape, no triangulation, etc.).
- **OCCT:** `IntCurvesFace_ShapeIntersector` via `OCCTIntCurvesFaceShapeIntersect`.
- **Example:**
  ```swift
  if let hits = solid.rayIntersect(origin: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1)) {
      let entry = hits.first
  }
  ```

---

### `rayIntersectNearest(origin:direction:)`

Find the nearest intersection of a ray with this shape.

```swift
public func rayIntersectNearest(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>
) -> RayIntersection?
```

- **Parameters:** `origin` — ray origin; `direction` — ray direction.
- **Returns:** Nearest `RayIntersection`, or `nil` if no intersection is found.
- **OCCT:** `IntCurvesFace_ShapeIntersector` (nearest) via `OCCTIntCurvesFaceShapeIntersectNearest`.

---

## GeomLProp\_CLProps / SLProps

These types are declared at module scope (not nested in `Shape`), then used via `Shape` methods.

### `CurveLocalProperties`

Local curve properties at a parameter point.

```swift
public struct CurveLocalProperties: Sendable {
    public let point: SIMD3<Double>
    public let tangent: SIMD3<Double>?
    public let normal: SIMD3<Double>?
    public let centerOfCurvature: SIMD3<Double>?
    public let curvature: Double
}
```

- `tangent` and `normal` are `nil` at inflection or degenerate points; `centerOfCurvature` is `nil` when curvature ≈ 0.

---

### `SurfaceLocalProperties`

Local surface properties at a (U,V) parameter point.

```swift
public struct SurfaceLocalProperties: Sendable {
    public let point: SIMD3<Double>
    public let normal: SIMD3<Double>?
    public let tangentU: SIMD3<Double>?
    public let tangentV: SIMD3<Double>?
    public let maxCurvature: Double
    public let minCurvature: Double
    public let meanCurvature: Double
    public let gaussianCurvature: Double
    public let isUmbilic: Bool
}
```

---

### `curveLocalProps(at:)`

Compute curve local properties at a parameter on an edge shape.

```swift
public func curveLocalProps(at param: Double) -> CurveLocalProperties
```

- **Parameters:** `param` — curve parameter.
- **Returns:** `CurveLocalProperties` at the given parameter.
- **OCCT:** `GeomLProp_CLProps` via `OCCTGeomLPropCLProps`.
- **Example:**
  ```swift
  let props = edge.curveLocalProps(at: 0.5)
  if let t = props.tangent { print(t) }
  ```

---

### `surfaceLocalProps(u:v:)`

Compute surface local properties at (U,V) on a face shape.

```swift
public func surfaceLocalProps(u: Double, v: Double) -> SurfaceLocalProperties
```

- **Parameters:** `u`, `v` — surface parameters.
- **Returns:** `SurfaceLocalProperties` at the given parameter point.
- **OCCT:** `GeomLProp_SLProps` via `OCCTGeomLPropSLProps`.
- **Example:**
  ```swift
  let props = face.surfaceLocalProps(u: 0.0, v: 0.0)
  print(props.gaussianCurvature)
  ```

---

## BRepOffset\_SimpleOffset

### `simpleOffsetShape(distance:tolerance:)`

Create a simple surface offset of this shape.

```swift
public func simpleOffsetShape(distance: Double, tolerance: Double = 1e-3) -> Shape?
```

- **Parameters:** `distance` — offset distance; `tolerance` — geometric tolerance.
- **Returns:** Offset shape, or `nil` on failure.
- **OCCT:** `BRepOffset_SimpleOffset` via `OCCTBRepOffsetSimpleOffset`.

---

## Approx\_CurvilinearParameter

### `curvilinearParameter(tolerance:maxDegree:maxSegments:)`

Reparameterize an edge curve by arc length, returning a BSpline edge.

```swift
public func curvilinearParameter(tolerance: Double = 1e-3, maxDegree: Int = 8, maxSegments: Int = 50) -> Shape?
```

- **Parameters:** `tolerance` — approximation tolerance; `maxDegree` — max BSpline degree; `maxSegments` — max segment count.
- **Returns:** Edge with arc-length parameterization, or `nil` on failure.
- **OCCT:** `Approx_CurvilinearParameter` via `OCCTApproxCurvilinearParameter`.

---

## GeomInt\_IntSS

### `SurfaceIntersectionResult`

Surface-surface intersection result (reference-counted class).

```swift
public class SurfaceIntersectionResult {
    public var curveCount: Int { get }
    public func curve(_ index: Int) -> Shape?
    public var pointCount: Int { get }
    public func point(_ index: Int) -> SIMD3<Double>
}
```

- **Members:** `curveCount` — number of intersection curves; `curve(_:)` — 1-based curve retrieval as an edge shape; `pointCount` — number of isolated points; `point(_:)` — 1-based point retrieval.
- **OCCT:** `GeomInt_IntSS` via `OCCTGeomIntSS*`.

---

### `Shape.surfaceSurfaceIntersection(face1:face2:tolerance:)`

Compute the surface-surface intersection between two face shapes.

```swift
public static func surfaceSurfaceIntersection(face1: Shape, face2: Shape, tolerance: Double = 1e-6) -> SurfaceIntersectionResult?
```

- **Parameters:** `face1`, `face2` — face shapes; `tolerance` — intersection tolerance.
- **Returns:** `SurfaceIntersectionResult`, or `nil` if no intersection or construction fails.
- **OCCT:** `GeomInt_IntSS` via `OCCTGeomIntSSCreate`.
- **Example:**
  ```swift
  if let r = Shape.surfaceSurfaceIntersection(face1: f1, face2: f2) {
      for i in 1...r.curveCount {
          let curve = r.curve(i)
      }
  }
  ```

---

## Contap\_Contour

### `ContourLineType`

Contour line type from `Contap_Contour` analysis.

```swift
public enum ContourLineType: Int32, Sendable {
    case line = 0
    case circle = 1
    case walking = 2
    case restriction = 3
}
```

---

### `ContapContourResult`

Contour computation result (reference-counted class).

```swift
public class ContapContourResult {
    public var lineCount: Int { get }
    public func pointCount(line: Int) -> Int
    public func point(line: Int, index: Int) -> SIMD3<Double>
    public func points(line: Int) -> [SIMD3<Double>]
    public func lineType(_ line: Int) -> ContourLineType?
}
```

- All indices are 1-based.
- **OCCT:** `Contap_Contour` via `OCCTContapContour*`.

---

### `contapContourDirection(_:)`

Compute contour lines on a face with an orthographic projection direction.

```swift
public func contapContourDirection(_ direction: SIMD3<Double>) -> ContapContourResult?
```

- **Parameters:** `direction` — orthographic view direction.
- **Returns:** `ContapContourResult` if contours are found, or `nil` otherwise.
- **OCCT:** `Contap_Contour(dir)` via `OCCTContapContourDirection`.

---

### `contapContourEye(_:)`

Compute contour lines on a face with a perspective eye point.

```swift
public func contapContourEye(_ eye: SIMD3<Double>) -> ContapContourResult?
```

- **Parameters:** `eye` — perspective eye point.
- **Returns:** `ContapContourResult` if contours are found, or `nil` otherwise.
- **OCCT:** `Contap_Contour(eye)` via `OCCTContapContourEye`.

---

## BRepFeat\_Builder

### `featFuse(with:)`

Feature-based fuse (union with part selection).

```swift
public func featFuse(with tool: Shape) -> Shape?
```

- **Parameters:** `tool` — the tool shape to fuse.
- **Returns:** Fused shape, or `nil` on failure.
- **OCCT:** `BRepFeat_Builder` (fuse mode) via `OCCTBRepFeatBuilderFuse`.

---

### `featCut(with:)`

Feature-based cut (subtraction with part selection).

```swift
public func featCut(with tool: Shape) -> Shape?
```

- **Parameters:** `tool` — the tool shape to subtract.
- **Returns:** Cut shape, or `nil` on failure.
- **OCCT:** `BRepFeat_Builder` (cut mode) via `OCCTBRepFeatBuilderCut`.

---

## GeomFill Trihedron Laws / Coons / Curved / CoonsAlgPatch

### `TrihedronFrame`

Tangent, normal, binormal frame at a curve parameter.

```swift
public struct TrihedronFrame: Sendable {
    public let tangent: SIMD3<Double>
    public let normal: SIMD3<Double>
    public let binormal: SIMD3<Double>
}
```

---

### `draftTrihedron(at:biNormal:angle:)`

Evaluate a draft trihedron frame on an edge at a parameter.

```swift
public func draftTrihedron(at param: Double, biNormal: SIMD3<Double>, angle: Double) -> TrihedronFrame?
```

- **Parameters:** `param` — curve parameter; `biNormal` — fixed bi-normal direction; `angle` — draft angle in radians.
- **Returns:** `TrihedronFrame`, or `nil` if the tangent is degenerate.
- **OCCT:** `GeomFill_DraftTrihedron` via `OCCTGeomFillDraftTrihedron`.

---

### `discreteTrihedron(at:)`

Evaluate a discrete trihedron frame on an edge at a parameter.

```swift
public func discreteTrihedron(at param: Double) -> TrihedronFrame?
```

- **Parameters:** `param` — curve parameter.
- **Returns:** `TrihedronFrame`, or `nil` if the tangent is degenerate.
- **OCCT:** `GeomFill_DiscreteTrihedron` via `OCCTGeomFillDiscreteTrihedron`.

---

### `correctedFrenet(at:)`

Evaluate a corrected Frenet frame on an edge at a parameter.

```swift
public func correctedFrenet(at param: Double) -> TrihedronFrame?
```

- **Parameters:** `param` — curve parameter.
- **Returns:** `TrihedronFrame`, or `nil` if the tangent is degenerate.
- **OCCT:** `GeomFill_CorrectedFrenet` via `OCCTGeomFillCorrectedFrenet`.

---

### `FillingPoleGrid`

Pole grid result from `GeomFill_Coons` or `GeomFill_Curved`.

```swift
public struct FillingPoleGrid: Sendable {
    public let poles: [SIMD3<Double>]
    public let nbU: Int
    public let nbV: Int
}
```

- **Fields:** `poles` — control points in row-major (U-major) order; `nbU`, `nbV` — grid dimensions.

---

### `Shape.coonsFilling(boundary1:boundary2:boundary3:boundary4:)`

Compute a Coons filling pole grid from four boundary point arrays.

```swift
public static func coonsFilling(
    boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
    boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>]
) -> FillingPoleGrid?
```

All four boundary arrays must have the same length (≥ 2). The result is a BSpline control-point grid, not a `Shape` — use `Surface.bspline(...)` to construct a surface from it.

- **Parameters:** `boundary1`–`boundary4` — point arrays for the four boundaries of the patch.
- **Returns:** `FillingPoleGrid`, or `nil` if sizes are mismatched or computation fails.
- **OCCT:** `GeomFill_Coons` via `OCCTGeomFillCoonsPoles`.

---

### `Shape.curvedFilling(boundary1:boundary2:boundary3:boundary4:)`

Compute a curved filling pole grid from four boundary point arrays.

```swift
public static func curvedFilling(
    boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
    boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>]
) -> FillingPoleGrid?
```

Similar to `coonsFilling` but uses `GeomFill_Curved` which preserves surface curvature better for curved boundaries.

- **Parameters:** `boundary1`–`boundary4` — point arrays for the four boundaries.
- **Returns:** `FillingPoleGrid`, or `nil` on failure.
- **OCCT:** `GeomFill_Curved` via `OCCTGeomFillCurvedPoles`.

---

### `Shape.coonsAlgPatch(edge1:edge2:edge3:edge4:evalU:evalV:)`

Evaluate a Coons algorithmic patch from four boundary edges at a UV grid.

```swift
public static func coonsAlgPatch(
    edge1: Shape, edge2: Shape, edge3: Shape, edge4: Shape,
    evalU: Int = 10, evalV: Int = 10
) -> [SIMD3<Double>]?
```

Returns evaluated 3D points over a `evalU × evalV` parameter grid. Indices in the result are in row-major order (U-major).

- **Parameters:** `edge1`–`edge4` — boundary edge shapes; `evalU`, `evalV` — sampling count in each direction.
- **Returns:** Flat array of `evalU × evalV` 3D points, or `nil` if all points are degenerate.
- **OCCT:** `GeomFill_CoonsAlgPatch` via `OCCTGeomFillCoonsAlgPatchEval`.
- **Example:**
  ```swift
  if let pts = Shape.coonsAlgPatch(edge1: e1, edge2: e2, edge3: e3, edge4: e4,
                                    evalU: 5, evalV: 5) {
      // pts.count == 25
  }
  ```
