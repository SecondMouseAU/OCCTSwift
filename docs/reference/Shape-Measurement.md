---
title: Shape — Measurement, Sub-Shapes & Local Operations
parent: API Reference
---

# Shape — Measurement, Sub-Shapes & Local Operations

This page covers the measurement, decomposition, healing, and local-operation APIs on `Shape` (source lines 4955–6935). For the core primitives, Boolean operations, and transforms, see the main **[Shape](Shape.md)** page.

## Topics

- [Sub-Shape Extraction](#sub-shape-extraction-v0380) · [Fuse and Blend](#fuse-and-blend-v0380) · [Multi-Edge Evolving Fillet](#multi-edge-evolving-fillet-v0380) · [Per-Face Variable Offset](#per-face-variable-offset-v0380) · [Free Boundary Analysis](#free-boundary-analysis-v0390) · [Pipe Feature](#pipe-feature-v0390) · [Semi-Infinite Extrusion](#semi-infinite-extrusion-v0390) · [Prism Until Face](#prism-until-face-v0390) · [Inertia Properties](#inertia-properties-v0400) · [Extended Distance](#extended-distance-v0400) · [Find Surface](#find-surface-v0400) · [Shape Surgery](#shape-surgery-v0410) · [Plane Detection](#plane-detection-v0410) · [Closed Edge Splitting](#closed-edge-splitting-v0410) · [Geometry Conversion](#geometry-conversion-v0410) · [Face Restriction](#face-restriction-v0410) · [Solid Construction / 2D Fillet / Point Cloud](#solid-construction-2d-fillet-and-point-cloud-v0420) · [Face Subdivision](#face-subdivision-v0430) · [Curve-on-Surface Check](#curve-on-surface-check) · [Edge Connection](#edge-connection) · [Self-Intersection Detection](#self-intersection-detection-v0450) · [Bezier Conversion](#bezier-conversion) · [Edge Concavity Analysis](#edge-concavity-analysis-v0460) · [Geometric Edge Selection](#geometric-edge-selection-v121) · [Local Prism / Volume Inertia](#local-prism-and-volume-inertia-v0460) · [Local Revolution](#local-revolution-v0470) · [Draft Prism](#draft-prism-v0470) · [Constrained Filling](#constrained-filling-v0470) · [Shape Validity Checking](#shape-validity-checking-v0470) · [Local Operations / Validation / Fixing / Extrema](#local-operations-validation-fixing-and-extrema-v0480) · [ShapeAnalysis FreeBoundsProperties](#shapeanalysis-freeboundsproperties)

---

## Sub-Shape Extraction (v0.38.0)

### `solidCount`

Number of solid sub-shapes in this shape.

```swift
public var solidCount: Int { get }
```

- **OCCT:** `BRep_Builder` / `TopExp_Explorer` (via `OCCTShapeGetSolidCount`).
- **Example:**
  ```swift
  let box = Shape.box(dx: 10, dy: 10, dz: 10)!
  print(box.solidCount)  // 1
  ```

---

### `solids`

Extract all solid sub-shapes.

```swift
public var solids: [Shape] { get }
```

- **Returns:** Array of solid sub-shapes; empty if none.
- **OCCT:** `TopExp_Explorer` with `TopAbs_SOLID`.
- **Example:**
  ```swift
  let compound = Shape.compound([box1, box2])
  let all = compound.solids  // [box1, box2]
  ```

---

### `shellCount`

Number of shell sub-shapes.

```swift
public var shellCount: Int { get }
```

- **OCCT:** `OCCTShapeGetShellCount`.

---

### `outerShell`

The outer shell of this solid.

```swift
public var outerShell: Shape? { get }
```

For a solid with internal voids (multiple shells), returns the shell bounding the outer body, distinguishing it from inner void shells. Returns `nil` if the shape is not a solid or has no shell.

- **Returns:** The outer shell, or `nil` if the shape is not a solid or has no shell.
- **OCCT:** `BRepClass3d::OuterShell`.
- **Example:**
  ```swift
  if let outer = hollowSolid.outerShell {
      print(outer.faceCount)
  }
  ```

---

### `innerShells`

Inner (void / cavity) shells of this solid — every shell except `outerShell`.

```swift
public var innerShells: [Shape] { get }
```

- **Returns:** Empty for a solid with no internal voids, or for a non-solid.
- **OCCT:** `OCCTShapeInnerShells`.
- **Example:**
  ```swift
  let cavities = part.innerShells
  print("cavity count: \(cavities.count)")
  ```

---

### `shells`

Extract all shell sub-shapes.

```swift
public var shells: [Shape] { get }
```

- **Returns:** Array of all shell sub-shapes (inner and outer).
- **OCCT:** `TopExp_Explorer` with `TopAbs_SHELL` (via `OCCTShapeGetShells`).

---

### `wireCount`

Number of wire sub-shapes.

```swift
public var wireCount: Int { get }
```

- **OCCT:** `OCCTShapeGetWireCount`.

---

### `wires`

Extract all wire sub-shapes.

```swift
public var wires: [Shape] { get }
```

- **Returns:** Array of wire sub-shapes; empty if none.
- **OCCT:** `TopExp_Explorer` with `TopAbs_WIRE` (via `OCCTShapeGetWires`).

---

## Fuse and Blend (v0.38.0)

### `fusedAndBlended(with:radius:)`

Fuse with another shape and fillet the intersection edges.

```swift
public func fusedAndBlended(with other: Shape, radius: Double) -> Shape?
```

- **Parameters:**
  - `other` — Shape to fuse with.
  - `radius` — Fillet radius applied to intersection edges after fusion.
- **Returns:** Fused and filleted shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Fuse` + `BRepFilletAPI_MakeFillet`.
- **Example:**
  ```swift
  if let result = boxA.fusedAndBlended(with: boxB, radius: 2.0) {
      print(result.isValid)
  }
  ```

---

### `cutAndBlended(with:radius:)`

Cut another shape from this shape and fillet the intersection edges.

```swift
public func cutAndBlended(with other: Shape, radius: Double) -> Shape?
```

- **Parameters:**
  - `other` — Shape to cut from this shape.
  - `radius` — Fillet radius applied to intersection edges after cutting.
- **Returns:** Cut and filleted shape, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Cut` + `BRepFilletAPI_MakeFillet`.

---

## Multi-Edge Evolving Fillet (v0.38.0)

### `EvolvingFilletEdge`

Describes an evolving radius along an edge for filleting.

```swift
public struct EvolvingFilletEdge: Sendable {
    public var edgeIndex: Int
    public var radiusPoints: [(parameter: Double, radius: Double)]
    public init(edgeIndex: Int, radiusPoints: [(parameter: Double, radius: Double)])
}
```

- `edgeIndex` — 1-based edge index.
- `radiusPoints` — Array of `(parameter, radius)` pairs defining the radius evolution along the edge.

---

### `filletEvolving(_:)`

Apply evolving-radius fillets to multiple edges simultaneously.

```swift
public func filletEvolving(_ edges: [EvolvingFilletEdge]) -> Shape?
```

- **Parameters:** `edges` — Array of edge specifications with radius evolution; must not be empty.
- **Returns:** Filleted shape, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet` with evolving law (via `OCCTShapeFilletEvolving`).
- **Example:**
  ```swift
  let spec = EvolvingFilletEdge(edgeIndex: 1, radiusPoints: [(0.0, 1.0), (1.0, 3.0)])
  if let filled = box.filletEvolving([spec]) {
      print(filled.isValid)
  }
  ```

---

## Per-Face Variable Offset (v0.38.0)

### `offsetPerFace(defaultOffset:faceOffsets:tolerance:joinType:)`

Offset a shape with different distances per face.

```swift
public func offsetPerFace(defaultOffset: Double,
                           faceOffsets: [Int: Double],
                           tolerance: Double = 1e-3,
                           joinType: OffsetJoinType = .arc) -> Shape?
```

- **Parameters:**
  - `defaultOffset` — Default offset distance applied to all faces not listed in `faceOffsets`.
  - `faceOffsets` — Dictionary mapping 1-based face indices to custom offset distances.
  - `tolerance` — Offset tolerance.
  - `joinType` — Join strategy for offset gaps (`.arc` or `.intersection`).
- **Returns:** Offset shape, or `nil` on failure.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid` (via `OCCTShapeOffsetPerFace`).
- **Example:**
  ```swift
  if let result = solid.offsetPerFace(defaultOffset: 1.0,
                                       faceOffsets: [1: 2.0, 3: 0.5]) {
      print(result.isValid)
  }
  ```

---

## Free Boundary Analysis (v0.39.0)

### `FreeBoundsResult`

Result of free boundary analysis.

```swift
public struct FreeBoundsResult: Sendable {
    public let wires: Shape
    public let closedCount: Int
    public let openCount: Int
}
```

- `wires` — Compound shape containing all free boundary wires.
- `closedCount` — Number of closed free boundary wires.
- `openCount` — Number of open free boundary wires.

---

### `freeBounds(sewingTolerance:)`

Analyze free boundary wires (open edges not shared by two faces).

```swift
public func freeBounds(sewingTolerance: Double = 1e-6) -> FreeBoundsResult?
```

Free boundaries indicate gaps in a shell. A watertight shell has no free boundaries.

- **Parameters:** `sewingTolerance` — Tolerance for grouping free edges into wires.
- **Returns:** Free bounds result, or `nil` if no free boundaries are found.
- **OCCT:** `ShapeAnalysis_FreeBounds`.
- **Example:**
  ```swift
  if let fb = shell.freeBounds() {
      print("open gaps: \(fb.openCount)")
  }
  ```

---

### `fixedFreeBounds(sewingTolerance:closingTolerance:)`

Fix free boundary wires by closing gaps.

```swift
public func fixedFreeBounds(sewingTolerance: Double = 1e-6,
                             closingTolerance: Double = 1e-4) -> (shape: Shape, fixedCount: Int)?
```

- **Parameters:**
  - `sewingTolerance` — Tolerance for sewing free edges.
  - `closingTolerance` — Maximum distance to close a gap.
- **Returns:** Tuple of `(fixed shape, number of wires fixed)`, or `nil` on failure.
- **OCCT:** `ShapeFix_Shape` / `ShapeAnalysis_FreeBounds` (via `OCCTShapeFixFreeBounds`).

---

## Pipe Feature (v0.39.0)

### `pipeFeature(profile:sketchFaceIndex:spine:fuse:)`

Create a pipe feature by sweeping a profile along a spine, fused with or cut from this shape.

```swift
public func pipeFeature(profile: Shape, sketchFaceIndex: Int,
                        spine: Wire, fuse: Bool = true) -> Shape?
```

- **Parameters:**
  - `profile` — Profile shape (face) to sweep along the spine.
  - `sketchFaceIndex` — 0-based index of the face on this shape where the profile sits.
  - `spine` — Wire defining the sweep path.
  - `fuse` — If `true`, adds material; if `false`, removes material.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePipe` (via `OCCTShapePipeFeatureFromProfile`).

---

## Semi-Infinite Extrusion (v0.39.0)

### `extrudedSemiInfinite(direction:infinite:)`

Extrude a shape semi-infinitely in a direction.

```swift
public func extrudedSemiInfinite(direction: SIMD3<Double>, infinite: Bool = false) -> Shape?
```

Creates a solid that extends infinitely in one direction from the profile. Useful for half-spaces and trimming operations.

- **Parameters:**
  - `direction` — Direction of extrusion.
  - `infinite` — If `true`, extrude in both directions (fully infinite); if `false`, extrude in one direction (semi-infinite).
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `BRepPrimAPI_MakeHalfSpace` / `BRepBuilderAPI_MakeSolid` (via `OCCTShapeExtrudeSemiInfinite`).

---

## Prism Until Face (v0.39.0)

### `prismUntilFace(profile:sketchFaceIndex:direction:fuse:untilFaceIndex:)`

Extrude a profile until it reaches a target face, with automatic fuse/cut.

```swift
public func prismUntilFace(profile: Shape, sketchFaceIndex: Int,
                           direction: SIMD3<Double>, fuse: Bool = true,
                           untilFaceIndex: Int? = nil) -> Shape?
```

Uses `BRepFeat_MakePrism` which handles the until-face computation more robustly than a simple extrusion + Boolean.

- **Parameters:**
  - `profile` — Profile face to extrude.
  - `sketchFaceIndex` — 0-based face index on this shape where the profile sits.
  - `direction` — Extrusion direction.
  - `fuse` — If `true`, adds material; if `false`, removes material.
  - `untilFaceIndex` — 0-based face index on this shape where extrusion stops. Pass `nil` for thru-all.
- **Returns:** Modified shape, or `nil` on failure.
- **OCCT:** `BRepFeat_MakePrism` (via `OCCTShapePrismUntilFace`).

---

## Inertia Properties (v0.40.0)

### `InertiaProperties`

Volume-based (or surface-area-based) inertia properties.

```swift
public struct InertiaProperties {
    public let mass: Double
    public let centerOfMass: SIMD3<Double>
    public let inertiaMatrix: [Double]
    public let principalMoments: SIMD3<Double>
    public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
    public let hasSymmetryAxis: Bool
    public let hasSymmetryPoint: Bool
}
```

- `mass` — Volume (for `inertiaProperties()`) or surface area (for `surfaceInertiaProperties()`).
- `inertiaMatrix` — 9-element row-major 3×3 inertia tensor `[Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz]`.
- `principalAxes` — Three unit vectors for the principal axes of inertia.

---

### `inertiaProperties()`

Compute volume-based inertia properties.

```swift
public func inertiaProperties() -> InertiaProperties?
```

- **Returns:** Inertia properties, or `nil` if computation fails.
- **OCCT:** `BRepGProp::VolumeProperties` (via `OCCTShapeInertiaProperties`).
- **Example:**
  ```swift
  if let props = solid.inertiaProperties() {
      print("volume: \(props.mass)")
      print("center of mass: \(props.centerOfMass)")
  }
  ```

---

### `surfaceInertiaProperties()`

Compute surface-area-based inertia properties.

```swift
public func surfaceInertiaProperties() -> InertiaProperties?
```

The `mass` field contains total surface area rather than volume.

- **Returns:** Inertia properties, or `nil` if computation fails.
- **OCCT:** `BRepGProp::SurfaceProperties` (via `OCCTShapeSurfaceInertiaProperties`).

---

## Extended Distance (v0.40.0)

### `DistanceSolution`

A closest-point solution between two shapes.

```swift
public struct DistanceSolution {
    public let point1: SIMD3<Double>
    public let point2: SIMD3<Double>
    public let distance: Double
}
```

---

### `allDistanceSolutions(to:maxSolutions:)`

Compute all distance extrema solutions between this shape and another.

```swift
public func allDistanceSolutions(to other: Shape, maxSolutions: Int = 32) -> [DistanceSolution]?
```

Returns all extremal point pairs (not just the minimum). Useful for finding multiple closest/farthest point pairs.

- **Parameters:**
  - `other` — The other shape.
  - `maxSolutions` — Maximum number of solutions to return.
- **Returns:** Array of distance solutions, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` (via `OCCTShapeAllDistanceSolutions`).
- **Example:**
  ```swift
  if let solutions = shapeA.allDistanceSolutions(to: shapeB) {
      let min = solutions.min(by: { $0.distance < $1.distance })
      print("minimum distance: \(min?.distance ?? 0)")
  }
  ```

---

### `isInside(_:)`

Check if this shape is fully contained inside another shape.

```swift
public func isInside(_ container: Shape) -> Bool?
```

- **Parameters:** `container` — The potential container shape.
- **Returns:** `true` if this shape is inside the container; `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` inner solution detection (via `OCCTShapeIsInnerDistance`).

---

### `DistanceSupportType`

Support type for a distance solution point.

```swift
public enum DistanceSupportType: Int32, Sendable {
    case vertex = 0
    case onEdge = 1
    case inFace = 2
}
```

---

### `DistanceSolutionDetail`

Detailed parametric info for a distance solution.

```swift
public struct DistanceSolutionDetail: Sendable {
    public let supportType1: DistanceSupportType
    public let supportType2: DistanceSupportType
    public let paramEdge1: Double
    public let paramEdge2: Double
    public let paramFaceUV1: (u: Double, v: Double)
    public let paramFaceUV2: (u: Double, v: Double)
}
```

---

### `distanceSolutionDetail(to:solutionIndex:)`

Get detailed parametric info for a specific distance solution.

```swift
public func distanceSolutionDetail(to other: Shape, solutionIndex: Int) -> DistanceSolutionDetail?
```

Returns the support type (vertex/edge/face) and parametric location for each closest point. Use in conjunction with `allDistanceSolutions(to:)` to obtain the solution index.

- **Parameters:**
  - `other` — The other shape.
  - `solutionIndex` — 0-based index into the solutions returned by `allDistanceSolutions(to:)`.
- **Returns:** Detail struct, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` (via `OCCTShapeDistanceSolutionDetail`).

---

## Find Surface (v0.40.0)

### `findSurfaceEx(tolerance:onlyPlane:)`

Find the underlying geometric surface shared by a shape's edges.

```swift
public func findSurfaceEx(tolerance: Double = 1e-6, onlyPlane: Bool = false) -> Surface?
```

Analyzes the edges of a shape to determine if they lie on a common geometric surface.

- **Parameters:**
  - `tolerance` — Tolerance for surface detection.
  - `onlyPlane` — If `true`, only look for planar surfaces.
- **Returns:** The underlying surface, or `nil` if none found.
- **OCCT:** `BRepLib_FindSurface` (via `OCCTShapeFindSurfaceEx`).
- **Example:**
  ```swift
  if let surf = wire.findSurfaceEx(onlyPlane: true) {
      print(surf.surfaceKind)  // .plane
  }
  ```

---

## Shape Surgery (v0.41.0)

### `removingSubShapes(_:)`

Remove sub-shapes from this shape surgically.

```swift
public func removingSubShapes(_ subShapes: [Shape]) -> Shape?
```

Uses `BRepTools_ReShape` to remove faces, edges, or vertices while preserving the remaining topology.

- **Parameters:** `subShapes` — Sub-shapes to remove.
- **Returns:** Shape with sub-shapes removed, or `nil` on failure.
- **OCCT:** `BRepTools_ReShape` (via `OCCTShapeRemoveSubShapes`).

---

### `replacingSubShapes(_:)`

Replace sub-shapes within this shape.

```swift
public func replacingSubShapes(_ replacements: [(old: Shape, new: Shape)]) -> Shape?
```

- **Parameters:** `replacements` — Array of `(old, new)` shape pairs.
- **Returns:** Shape with replacements applied, or `nil` on failure.
- **OCCT:** `BRepTools_ReShape` (via `OCCTShapeReplaceSubShapes`).

---

## Plane Detection (v0.41.0)

### `DetectedPlane`

Result of plane detection.

```swift
public struct DetectedPlane {
    public let normal: SIMD3<Double>
    public let origin: SIMD3<Double>
}
```

---

### `findPlane(tolerance:)`

Find if this shape's edges lie in a plane.

```swift
public func findPlane(tolerance: Double = 1e-6) -> DetectedPlane?
```

- **Parameters:** `tolerance` — Tolerance for planarity check.
- **Returns:** Detected plane, or `nil` if the shape is not planar.
- **OCCT:** `BRepBuilderAPI_FindPlane` (via `OCCTShapeFindPlane`).
- **Example:**
  ```swift
  if let plane = wire.findPlane() {
      print("normal: \(plane.normal)")
  }
  ```

---

## Closed Edge Splitting (v0.41.0)

### `dividedClosedEdges(splitPoints:)`

Split closed (periodic) edges in the shape.

```swift
public func dividedClosedEdges(splitPoints: Int = 1) -> Shape?
```

Periodic edges (like circles) can cause issues in some algorithms. This splits each closed edge into segments.

- **Parameters:** `splitPoints` — Number of split points per closed edge (default `1`, which doubles the edge count).
- **Returns:** Shape with closed edges split, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideAngle` / `BRep_Builder` (via `OCCTShapeDivideClosedEdges`).

---

## Geometry Conversion (v0.41.0)

### `withSurfacesAsBSpline(extrusion:revolution:offset:plane:)`

Convert all surfaces to BSpline form.

```swift
public func withSurfacesAsBSpline(extrusion: Bool = true, revolution: Bool = true,
                                   offset: Bool = true, plane: Bool = false) -> Shape?
```

- **Parameters:**
  - `extrusion` — Convert extrusion surfaces (default `true`).
  - `revolution` — Convert revolution surfaces (default `true`).
  - `offset` — Convert offset surfaces (default `true`).
  - `plane` — Convert planar surfaces (default `false`).
- **Returns:** Shape with converted surfaces, or `nil` on failure.
- **OCCT:** `ShapeCustom::ConvertToBSpline` (via `OCCTShapeCustomConvertToBSpline`).

---

### `withSurfacesAsRevolution()`

Convert surfaces to revolution form where possible.

```swift
public func withSurfacesAsRevolution() -> Shape?
```

- **Returns:** Shape with surfaces converted to surfaces of revolution, or `nil` on failure.
- **OCCT:** `ShapeCustom::ConvertToRevolution` (via `OCCTShapeCustomConvertToRevolution`).

---

## Face Restriction (v0.41.0)

### `faceRestricted(by:)`

Create restricted faces from a face and wire boundaries.

```swift
public func faceRestricted(by boundaries: [Wire]) -> [Shape]?
```

Uses `BRepAlgo_FaceRestrictor` to build faces on the underlying surface of this shape's first face, bounded by the given wires.

- **Parameters:** `boundaries` — Wire boundaries that define the restricted regions.
- **Returns:** Array of restricted face shapes (up to 64), or `nil` on failure.
- **OCCT:** `BRepAlgo_FaceRestrictor` (via `OCCTShapeFaceRestrict`).

---

## Solid Construction, 2D Fillet and Point Cloud (v0.42.0)

### `solidFromShells(_:)`

Create a solid from one or more shell shapes.

```swift
public static func solidFromShells(_ shells: [Shape]) -> Shape?
```

The first shape provides the outer shell; additional shapes provide cavity (inner) shells.

- **Parameters:** `shells` — Array of shapes containing shells; must not be empty.
- **Returns:** Solid shape, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeSolid` (via `OCCTSolidFromShells`).
- **Example:**
  ```swift
  if let solid = Shape.solidFromShells([outerShell, innerShell]) {
      print(solid.isValid)
  }
  ```

---

### `fillet2D(vertexIndices:radii:)`

Apply 2D fillets (rounded corners) to a planar face at specified vertices.

```swift
public func fillet2D(vertexIndices: [Int], radii: [Double]) -> Shape?
```

- **Parameters:**
  - `vertexIndices` — 0-based indices of vertices to fillet.
  - `radii` — Fillet radius for each vertex; must match `vertexIndices` count.
- **Returns:** Modified shape with fillets, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet2d` (via `OCCTFace2DFillet`).
- **Note:** `vertexIndices` and `radii` must have equal length; mismatch returns `nil`.

---

### `chamfer2D(edgePairs:distances:)`

Apply 2D chamfers (angled cuts) to a planar face between adjacent edge pairs.

```swift
public func chamfer2D(edgePairs: [(Int, Int)], distances: [Double]) -> Shape?
```

- **Parameters:**
  - `edgePairs` — Array of `(edge1Index, edge2Index)` pairs (0-based) identifying adjacent edges.
  - `distances` — Chamfer distance for each edge pair.
- **Returns:** Modified shape with chamfers, or `nil` on failure.
- **OCCT:** `BRepFilletAPI_MakeFillet2d` (via `OCCTFace2DChamfer`).

---

### `PointCloudGeometry`

Classification of a point cloud's geometric arrangement.

```swift
public enum PointCloudGeometry {
    case point(SIMD3<Double>)
    case linear(origin: SIMD3<Double>, direction: SIMD3<Double>)
    case planar(origin: SIMD3<Double>, normal: SIMD3<Double>)
    case space
}
```

- `.point` — All points are coincident.
- `.linear` — Points are collinear.
- `.planar` — Points are coplanar.
- `.space` — Points are dispersed in 3D space.

---

### `analyzePointCloud(_:tolerance:)`

Analyze a set of 3D points to determine their geometric arrangement.

```swift
public static func analyzePointCloud(_ points: [SIMD3<Double>], tolerance: Double = 1e-6) -> PointCloudGeometry?
```

- **Parameters:**
  - `points` — Array of 3D points (minimum 1).
  - `tolerance` — Tolerance for classification.
- **Returns:** Classification result, or `nil` on failure.
- **OCCT:** `GProp_PEquation` (via `OCCTAnalyzePointCloud`).
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [.init(0,0,0), .init(1,0,0), .init(2,0,0)]
  if case .linear(let o, let d) = Shape.analyzePointCloud(pts) {
      print("line direction: \(d)")
  }
  ```

---

## Face Subdivision (v0.43.0)

### `dividedByArea(maxArea:)`

Subdivide faces whose area exceeds a maximum threshold.

```swift
public func dividedByArea(maxArea: Double) -> Shape?
```

- **Parameters:** `maxArea` — Maximum face area; faces larger than this are split.
- **Returns:** Shape with subdivided faces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideArea` (via `OCCTShapeDivideByArea`).

---

### `dividedByParts(_:)`

Subdivide faces into a target number of parts.

```swift
public func dividedByParts(_ parts: Int) -> Shape?
```

- **Parameters:** `parts` — Target number of parts per face.
- **Returns:** Shape with subdivided faces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideArea` in splitting-by-number mode (via `OCCTShapeDivideByParts`).

---

### `SmallFaceInfo`

Result of small/degenerate face analysis.

```swift
public struct SmallFaceInfo: Sendable {
    public let isSpotFace: Bool
    public let isStripFace: Bool
    public let isTwisted: Bool
    public let spotLocation: SIMD3<Double>?
}
```

- `isSpotFace` — Face collapsed to a point.
- `isStripFace` — Face with negligible width.
- `isTwisted` — Face with twisted geometry.
- `spotLocation` — Location of a spot face (only set when `isSpotFace` is `true`).

---

### `checkSmallFaces(tolerance:)`

Check faces for degenerate conditions (spot, strip, twisted).

```swift
public func checkSmallFaces(tolerance: Double = 1e-6) -> [SmallFaceInfo]
```

Returns only faces that have at least one degenerate condition.

- **Parameters:** `tolerance` — Analysis tolerance.
- **Returns:** Array of degenerate face descriptions; empty if none found.
- **OCCT:** `ShapeAnalysis_CheckSmallFace` (via `OCCTShapeCheckSmallFaces`).

---

### `purgedLocations`

Purge problematic location datums from the shape.

```swift
public var purgedLocations: Shape? { get }
```

Removes negative-scale and non-unit-scale transforms from the shape and all sub-shapes. Useful for cleaning imported geometry from STEP/IGES files.

- **Returns:** Cleaned shape, or `nil` if purge was unnecessary or failed.
- **OCCT:** `BRepLib::SameParameter` / transform purge (via `OCCTShapePurgeLocations`).

---

## Curve-on-Surface Check

### `CurveOnSurfaceCheck`

Result of a curve-on-surface consistency check.

```swift
public struct CurveOnSurfaceCheck {
    public let maxDistance: Double
    public let maxParameter: Double
}
```

- `maxDistance` — Maximum deviation between 3D edge curves and their pcurves on faces.
- `maxParameter` — Curve parameter where the maximum deviation occurs.

---

### `curveOnSurfaceCheck`

Check edge-on-surface consistency.

```swift
public var curveOnSurfaceCheck: CurveOnSurfaceCheck? { get }
```

Examines all edge-face pairs in the shape and reports the maximum deviation between each edge's 3D curve and its parametric curve (pcurve) on the face surface.

- **Returns:** Check result, or `nil` if the check fails.
- **OCCT:** `BRep_Tool::CurveOnSurface` / `ShapeAnalysis_Edge` (via `OCCTShapeCheckCurveOnSurface`).

---

## Edge Connection

### `connectedEdges`

Connect edges by merging shared vertices in the shape.

```swift
public var connectedEdges: Shape? { get }
```

Identifies edges that share geometric positions and merges their vertices. Useful for healing imported geometry where topologically disconnected edges actually meet at the same point.

- **Returns:** Shape with connected edges, or `nil` on failure.
- **OCCT:** `ShapeFix_EdgeConnect` (via `OCCTShapeConnectEdges`).

---

## Self-Intersection Detection (v0.45.0)

### `SelfIntersectionResult`

Result of a self-intersection check.

```swift
public struct SelfIntersectionResult: Sendable {
    public let overlapCount: Int
    public let isDone: Bool
}
```

---

### `selfIntersection(tolerance:meshDeflection:)`

Check the shape for self-intersection using BVH-accelerated triangle mesh overlap.

```swift
public func selfIntersection(tolerance: Double = 0.001,
                              meshDeflection: Double = 0.5) -> SelfIntersectionResult?
```

Meshes the shape and detects overlapping triangle pairs.

- **Parameters:**
  - `tolerance` — Tolerance for detecting intersections.
  - `meshDeflection` — Mesh deflection for triangulation.
- **Returns:** Self-intersection result, or `nil` if the check failed.
- **OCCT:** `BRepExtrema_SelfIntersection` (via `OCCTShapeSelfIntersection`).
- **Example:**
  ```swift
  if let si = shape.selfIntersection() {
      print("overlapping pairs: \(si.overlapCount)")
  }
  ```

---

## Bezier Conversion

### `convertedToBezier`

Convert all curves and surfaces in the shape to Bezier representations.

```swift
public var convertedToBezier: Shape? { get }
```

Replaces BSpline curves and surfaces with their Bezier equivalents. Converts 2D/3D curves, surfaces, lines, circles, conics, planes, revolutions, extrusions, and BSpline entities.

- **Returns:** Shape with Bezier geometry, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeConvertToBezier` (via `OCCTShapeConvertToBezier`).

---

## Edge Concavity Analysis (v0.46.0)

### `EdgeConcavity`

Edge concavity type from `BRepOffset_Analyse`.

```swift
public enum EdgeConcavity: Sendable {
    case convex
    case concave
    case tangent
}
```

- `.convex` — Edge connects two faces at a convex angle (e.g., outer corner of a box).
- `.concave` — Edge connects two faces at a concave angle (e.g., inner corner of a groove).
- `.tangent` — Edge connects two faces with a smooth (tangent) transition.

---

### `edgeConcavities(angle:)`

Classify all edges by their concavity type.

```swift
public func edgeConcavities(angle: Double = 0.01) -> [(Edge, EdgeConcavity)]?
```

Analyzes the angles between adjacent faces at each edge.

- **Parameters:** `angle` — Threshold angle (radians) for tangent classification.
- **Returns:** Array of `(edge, concavity)` pairs in edge order, or `nil` on error.
- **OCCT:** `BRepOffset_Analyse` (via `OCCTShapeAnalyzeEdgeConcavity`).

---

### `edgeConcavityCount(_:angle:)`

Count edges of a specific concavity type.

```swift
public func edgeConcavityCount(_ type: EdgeConcavity, angle: Double = 0.01) -> Int?
```

- **Parameters:**
  - `type` — Concavity type to count.
  - `angle` — Threshold angle (radians) for tangent classification.
- **Returns:** Count of matching edges, or `nil` on error.
- **OCCT:** `BRepOffset_Analyse` (via `OCCTShapeCountEdgeConcavity`).

---

## Geometric Edge Selection (v1.2.1)

### `edges(where:)`

Select edges of this shape that satisfy a geometric predicate.

```swift
public func edges(where predicate: (Edge) -> Bool) -> [Edge]
```

A robust alternative to picking edges by raw index from `edges()` — the index shifts when model parameters change, whereas a geometric predicate keeps selecting the right edge.

- **Parameters:** `predicate` — Returns `true` for edges to keep.
- **Returns:** The matching edges (possibly empty), each with a valid index.
- **Example:**
  ```swift
  // Round only long edges (> 50 mm)
  let targets = bracket.edges { $0.length > 50 }
  let rounded = bracket.filleted(edges: targets, radius: 2)
  ```

---

### `concaveEdges(angle:)`

The concave edges of this solid (interior angle > 180°).

```swift
public func concaveEdges(angle: Double = 0.01) -> [Edge]
```

Concave edges are typically the ones you want to fillet to add material to an inside corner.

- **Parameters:** `angle` — Threshold (radians) below which an edge counts as tangent rather than concave.
- **Returns:** The concave edges, or an empty array if none or on error.
- **Example:**
  ```swift
  let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
  ```

---

### `convexEdges(angle:)`

The convex edges of this solid (interior angle < 180°).

```swift
public func convexEdges(angle: Double = 0.01) -> [Edge]
```

Convex edges are the outer corners of a part, typically the ones you want to chamfer or round.

- **Parameters:** `angle` — Threshold (radians) below which an edge counts as tangent rather than convex.
- **Returns:** The convex edges, or an empty array if none or on error.

---

### `edges(parallelTo:tolerance:)`

Select straight edges whose direction is parallel to a given axis.

```swift
public func edges(parallelTo axis: SIMD3<Double>, tolerance: Double = 1e-4) -> [Edge]
```

Only line edges are considered (curved edges have no single direction). The test is sign-agnostic: edges pointing along `+axis` or `-axis` both match.

- **Parameters:**
  - `axis` — The reference direction (need not be unit length).
  - `tolerance` — Maximum sine of the angle between edge and axis.
- **Returns:** The matching straight edges, each with a valid index.
- **Example:**
  ```swift
  // Round every vertical edge of an extruded prism
  let verticals = part.edges(parallelTo: SIMD3(0, 0, 1))
  let rounded = part.filleted(edges: verticals, radius: 2)
  ```

---

### `edges(inBounds:_:)`

Select edges fully contained within an axis-aligned bounding region.

```swift
public func edges(inBounds min: SIMD3<Double>, _ max: SIMD3<Double>) -> [Edge]
```

An edge matches when its entire bounding box lies inside the box spanned by `min...max` (inclusive).

- **Parameters:**
  - `min` — Lower corner of the region.
  - `max` — Upper corner of the region.
- **Returns:** The contained edges, each with a valid index.

---

## Local Prism and Volume Inertia (v0.46.0)

### `localPrism(direction:)`

Create a local prism (extrusion) from this shape along a direction.

```swift
public func localPrism(direction: SIMD3<Double>) -> Shape?
```

Uses `LocOpe_Prism` which tracks generated shapes for each input sub-shape.

- **Parameters:** `direction` — Direction and distance of extrusion.
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `LocOpe_Prism` (via `OCCTLocOpePrism`).

---

### `localPrism(direction:translation:)`

Create a local prism with an additional translation.

```swift
public func localPrism(direction: SIMD3<Double>, translation: SIMD3<Double>) -> Shape?
```

- **Parameters:**
  - `direction` — Primary direction and distance of extrusion.
  - `translation` — Secondary translation vector.
- **Returns:** Extruded shape, or `nil` on failure.
- **OCCT:** `LocOpe_Prism` (via `OCCTLocOpePrismWithTranslation`).

---

### `VolumeInertia`

Volume inertia properties of a solid shape.

```swift
public struct VolumeInertia: Sendable {
    public let volume: Double
    public let centerOfMass: SIMD3<Double>
    public let inertiaTensor: [Double]
    public let principalMoments: SIMD3<Double>
    public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
    public let gyrationRadii: SIMD3<Double>
}
```

- `inertiaTensor` — 9-element row-major 3×3 inertia tensor.
- `gyrationRadii` — Radii of gyration about the three principal axes.

---

### `volumeInertia`

Compute volume inertia properties of this shape.

```swift
public var volumeInertia: VolumeInertia? { get }
```

- **Returns:** Volume inertia result, or `nil` on error.
- **OCCT:** `BRepGProp::VolumeProperties` (via `OCCTShapeVolumeInertia`).
- **Example:**
  ```swift
  if let vi = solid.volumeInertia {
      print("volume: \(vi.volume)")
      print("gyration radii: \(vi.gyrationRadii)")
  }
  ```

---

### `SurfaceInertia`

Surface inertia properties of a shape.

```swift
public struct SurfaceInertia: Sendable {
    public let area: Double
    public let centerOfMass: SIMD3<Double>
    public let inertiaTensor: [Double]
    public let principalMoments: SIMD3<Double>
}
```

---

### `surfaceInertia`

Compute surface (area) inertia properties of this shape.

```swift
public var surfaceInertia: SurfaceInertia? { get }
```

- **Returns:** Surface inertia result, or `nil` on error.
- **OCCT:** `BRepGProp::SurfaceProperties` (via `OCCTShapeSurfaceInertia`).

---

## Local Revolution (v0.47.0)

### `localRevolution(axisOrigin:axisDirection:angle:)`

Create a revolved shape by rotating a profile around an axis.

```swift
public func localRevolution(axisOrigin: SIMD3<Double>,
                             axisDirection: SIMD3<Double>,
                             angle: Double) -> Shape?
```

Uses `LocOpe_Revol` for local revolution operations with shape tracking.

- **Parameters:**
  - `axisOrigin` — Origin point of the rotation axis.
  - `axisDirection` — Direction of the rotation axis.
  - `angle` — Rotation angle in radians.
- **Returns:** Revolved shape, or `nil` on failure.
- **OCCT:** `LocOpe_Revol` (via `OCCTLocOpeRevol`).

---

### `localRevolution(axisOrigin:axisDirection:angle:angularOffset:)`

Create a revolved shape with an angular offset.

```swift
public func localRevolution(axisOrigin: SIMD3<Double>,
                             axisDirection: SIMD3<Double>,
                             angle: Double,
                             angularOffset: Double) -> Shape?
```

- **Parameters:**
  - `axisOrigin` — Origin point of the rotation axis.
  - `axisDirection` — Direction of the rotation axis.
  - `angle` — Rotation angle in radians.
  - `angularOffset` — Angular offset for positioning in radians.
- **Returns:** Revolved shape, or `nil` on failure.
- **OCCT:** `LocOpe_Revol` (via `OCCTLocOpeRevolWithOffset`).

---

## Draft Prism (v0.47.0)

These methods are on `Face`, not `Shape`.

### `Face.draftPrism(height1:height2:angle:)`

Create a draft prism (tapered extrusion) from this face.

```swift
public func draftPrism(height1: Double, height2: Double, angle: Double) -> Shape?
```

- **Parameters:**
  - `height1` — First height.
  - `height2` — Second height.
  - `angle` — Draft angle in radians.
- **Returns:** Draft prism shape, or `nil` on failure.
- **OCCT:** `LocOpe_DPrism` (via `OCCTLocOpeDPrism`).

---

### `Face.draftPrism(height:angle:)`

Create a draft prism with a single height.

```swift
public func draftPrism(height: Double, angle: Double) -> Shape?
```

- **Parameters:**
  - `height` — Extrusion height.
  - `angle` — Draft angle in radians.
- **Returns:** Draft prism shape, or `nil` on failure.
- **OCCT:** `LocOpe_DPrism` (via `OCCTLocOpeDPrismSingleHeight`).

---

## Constrained Filling (v0.47.0)

### `ConstrainedFillInfo`

Information about a constrained-fill BSpline surface.

```swift
public struct ConstrainedFillInfo: Sendable {
    public let uDegree: Int
    public let vDegree: Int
    public let uPoles: Int
    public let vPoles: Int
}
```

---

### `constrainedFill(edge1:edge2:edge3:edge4:maxDegree:maxSegments:)`

Create a surface by filling a region bounded by 3 or 4 edge curves.

```swift
public static func constrainedFill(edge1: Edge, edge2: Edge, edge3: Edge,
                                    edge4: Edge? = nil,
                                    maxDegree: Int = 8,
                                    maxSegments: Int = 15) -> Shape?
```

- **Parameters:**
  - `edge1`, `edge2`, `edge3` — Required boundary edges.
  - `edge4` — Optional fourth boundary edge; pass `nil` for a 3-sided fill.
  - `maxDegree` — Maximum BSpline degree.
  - `maxSegments` — Maximum number of segments.
- **Returns:** Face shape built on the filled BSpline surface, or `nil` on failure.
- **OCCT:** `GeomFill_ConstrainedFilling` (via `OCCTGeomFillConstrained`).

---

### `constrainedFillInfo`

Get BSpline surface info from a constrained fill result.

```swift
public var constrainedFillInfo: ConstrainedFillInfo? { get }
```

- **Returns:** Surface info (degrees and pole counts), or `nil` if not a BSpline surface.
- **OCCT:** `Geom_BSplineSurface` (via `OCCTGeomFillConstrainedInfo`).

---

## Shape Validity Checking (v0.47.0)

### `CheckStatus`

Shape check error status codes from `BRepCheck`.

```swift
public enum CheckStatus: Int32, Sendable, CaseIterable {
    case noError = 0
    case invalidPointOnCurve = 1
    case invalidPointOnCurveOnSurface = 2
    case invalidPointOnSurface = 3
    case no3DCurve = 4
    case multiple3DCurve = 5
    case invalid3DCurve = 6
    case noCurveOnSurface = 7
    case invalidCurveOnSurface = 8
    case invalidCurveOnClosedSurface = 9
    case invalidSameRangeFlag = 10
    case invalidSameParameterFlag = 11
    case invalidDegeneratedFlag = 12
    case freeEdge = 13
    case invalidMultiConnexity = 14
    case invalidRange = 15
    case emptyWire = 16
    case redundantEdge = 17
    case selfIntersectingWire = 18
    case noSurface = 19
    case invalidWire = 20
    case redundantWire = 21
    case intersectingWires = 22
    case invalidImbricationOfWires = 23
    case emptyShell = 24
    case redundantFace = 25
    case invalidImbricationOfShells = 26
    case unorientableShape = 27
    case notClosed = 28
    case notConnected = 29
    case subshapeNotInShape = 30
    case badOrientation = 31
    case badOrientationOfSubshape = 32
    case invalidPolygonOnTriangulation = 33
    case invalidToleranceValue = 34
    case enclosedRegion = 35
    case checkFail = 36
}
```

---

### `CheckResult`

Result of a shape validity check.

```swift
public struct CheckResult: Sendable {
    public let isValid: Bool
    public let errorCount: Int
    public let firstError: CheckStatus?
}
```

---

### `checkResult`

Check the overall validity of this shape.

```swift
public var checkResult: CheckResult { get }
```

- **Returns:** Check result with validity flag, error count, and first error code.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTCheckShape`).
- **Example:**
  ```swift
  let cr = shape.checkResult
  if !cr.isValid, let err = cr.firstError {
      print("invalid: \(err)")
  }
  ```

---

### `detailedCheckStatuses`

Get detailed error status codes for this shape.

```swift
public var detailedCheckStatuses: [CheckStatus] { get }
```

Returns all individual error codes found during validation. Useful for diagnosing exactly what's wrong with an invalid shape.

- **Returns:** Array of check status codes; empty if valid.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTCheckShapeDetailed`).

---

### `Face.faceCheckResult`

Check the validity of this face using `BRepCheck_Face`.

```swift
public var faceCheckResult: Shape.CheckResult { get }
```

More targeted than `Shape.checkResult` — includes wire intersection checks and face-specific validation.

- **Returns:** Check result.
- **OCCT:** `BRepCheck_Face` (via `OCCTCheckFace`).

---

## Local Operations, Validation, Fixing and Extrema (v0.48.0)

### `localPipe(along:)`

Perform a pipe sweep of this shape along a wire spine with shape tracking.

```swift
public func localPipe(along spine: Wire) -> Shape?
```

- **Parameters:** `spine` — Wire spine to sweep along.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `LocOpe_Pipe` (via `OCCTLocOpePipe`).

---

### `localLinearForm(direction:from:to:)`

Perform a linear form (translation sweep) of this shape with shape tracking.

```swift
public func localLinearForm(direction: SIMD3<Double>,
                            from start: SIMD3<Double>,
                            to end: SIMD3<Double>) -> Shape?
```

- **Parameters:**
  - `direction` — Direction vector of the sweep.
  - `start` — Start point of the sweep.
  - `end` — End point of the sweep.
- **Returns:** Swept shape, or `nil` on failure.
- **OCCT:** `LocOpe_LinearForm` (via `OCCTLocOpeLinearForm`).

---

### `localRevolutionForm(axisOrigin:axisDirection:angle:)`

Perform a revolution form of this shape with shape tracking.

```swift
public func localRevolutionForm(axisOrigin: SIMD3<Double>,
                                 axisDirection: SIMD3<Double>,
                                 angle: Double) -> Shape?
```

- **Parameters:**
  - `axisOrigin` — Origin point of the rotation axis.
  - `axisDirection` — Direction of the rotation axis.
  - `angle` — Rotation angle in radians.
- **Returns:** Revolved shape, or `nil` on failure.
- **OCCT:** `LocOpe_RevolutionForm` (via `OCCTLocOpeRevolutionForm`).

---

### `splitFace(at:with:)`

Split a face of this shape by adding a wire on it.

```swift
public func splitFace(at faceIndex: Int, with wire: Wire) -> Shape?
```

- **Parameters:**
  - `faceIndex` — 0-based index of the face to split.
  - `wire` — Wire lying on the face that defines the split.
- **Returns:** Modified shape with the face split, or `nil` on failure.
- **OCCT:** `LocOpe_SplitShape` (via `OCCTLocOpeSplitShapeByWire`).

---

### `splitEdge(at:parameter:)`

Split an edge of this shape at a parameter.

```swift
public func splitEdge(at edgeIndex: Int, parameter: Double) -> Shape?
```

- **Parameters:**
  - `edgeIndex` — 0-based index of the edge to split.
  - `parameter` — Parameter along the edge (0.0–1.0) where the split occurs.
- **Returns:** The split edge parts as a compound, or `nil` on failure.
- **OCCT:** `LocOpe_SplitShape` (via `OCCTLocOpeSplitShapeByVertex`).

---

### `splitDrafts(faceIndex:wire:direction:planeOrigin:planeNormal:angle:)`

Split a face with draft angles on both sides of a wire.

```swift
public func splitDrafts(faceIndex: Int, wire: Wire,
                        direction: SIMD3<Double>,
                        planeOrigin: SIMD3<Double>,
                        planeNormal: SIMD3<Double>,
                        angle: Double) -> Shape?
```

- **Parameters:**
  - `faceIndex` — 0-based index of the face to split.
  - `wire` — Wire defining the split line.
  - `direction` — Extraction direction.
  - `planeOrigin` — Origin of the neutral plane.
  - `planeNormal` — Normal of the neutral plane.
  - `angle` — Draft angle in radians.
- **Returns:** Modified shape with draft, or `nil` on failure.
- **OCCT:** `LocOpe_SplitDrafts` (via `OCCTLocOpeSplitDrafts`).
- **Note:** `LocOpe_SplitDrafts::Perform()` can throw on incompatible geometry; the bridge wraps it in a try-catch.

---

### `commonEdges(with:)`

Find edges in common between this shape and another.

```swift
public func commonEdges(with other: Shape) -> [Edge]
```

- **Parameters:** `other` — Shape to compare with.
- **Returns:** Array of common edges (up to 100).
- **OCCT:** `LocOpe_FindEdges` (via `OCCTLocOpeFindEdges`).

---

### `edgesInFace(at:)`

Find edges of this shape that lie in a specific face.

```swift
public func edgesInFace(at faceIndex: Int) -> [Edge]
```

- **Parameters:** `faceIndex` — 0-based index of the face to check.
- **Returns:** Array of edges found in the face (up to 100).
- **OCCT:** `LocOpe_FindEdgesInFace` (via `OCCTLocOpeFindEdgesInFace`).

---

### `CSIntersection`

Result of a curve-shape intersection.

```swift
public struct CSIntersection: Sendable {
    public let point: SIMD3<Double>
    public let parameter: Double
    public let faceUV: SIMD2<Double>
}
```

---

### `intersectLine(origin:direction:)` *(LocOpe_CSIntersector variant)*

Intersect a line with this shape to find intersection points.

```swift
public func intersectLine(origin: SIMD3<Double>, direction: SIMD3<Double>) -> [CSIntersection]
```

- **Parameters:**
  - `origin` — Line origin.
  - `direction` — Line direction.
- **Returns:** Array of intersection points with curve parameters and face UV coordinates.
- **OCCT:** `LocOpe_CSIntersector` (via `OCCTLocOpeCSIntersectLine`).
- **Note:** This overload returns `[CSIntersection]` with face UV. A separate `IntCurvesFace`-backed overload in v0.61.0 returns `[LineFaceIntersection]`.

---

### `analyzeValidity(geometryChecks:)`

Perform comprehensive validity analysis on this shape.

```swift
public func analyzeValidity(geometryChecks: Bool = true) -> Bool
```

- **Parameters:** `geometryChecks` — Whether to include geometry-level checks.
- **Returns:** `true` if the shape is valid.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTBRepCheckAnalyzerIsValid`).

---

### `TopAbs_ShapeEnum`

Sub-shape type specifier.

```swift
public enum TopAbs_ShapeEnum: Int32, Sendable {
    case compound = 0, compsolid = 1, solid = 2, shell = 3
    case face = 4, wire = 5, edge = 6, vertex = 7
}
```

---

### `isSubShapeValid(type:at:)`

Check if a specific sub-shape is valid within this shape's context.

```swift
public func isSubShapeValid(type: TopAbs_ShapeEnum, at index: Int) -> Bool
```

- **Parameters:**
  - `type` — Type of sub-shape to check.
  - `index` — 0-based index of the sub-shape.
- **Returns:** `true` if the sub-shape is valid.
- **OCCT:** `BRepCheck_Analyzer` (via `OCCTBRepCheckSubShapeValid`).

---

### `checkEdge(at:)`

Check validity of an edge by index.

```swift
public func checkEdge(at index: Int) -> CheckResult
```

- **Parameters:** `index` — 0-based edge index.
- **Returns:** Check result for the specified edge.
- **OCCT:** `BRepCheck_Edge` (via `OCCTCheckEdge`).

---

### `checkWire(at:)`

Check validity of a wire by index.

```swift
public func checkWire(at index: Int) -> CheckResult
```

- **OCCT:** `BRepCheck_Wire` (via `OCCTCheckWire`).

---

### `checkShell(at:)`

Check validity of a shell by index.

```swift
public func checkShell(at index: Int) -> CheckResult
```

- **OCCT:** `BRepCheck_Shell` (via `OCCTCheckShell`).

---

### `checkVertex(at:)`

Check validity of a vertex by index.

```swift
public func checkVertex(at index: Int) -> CheckResult
```

- **OCCT:** `BRepCheck_Vertex` (via `OCCTCheckVertex`).

---

### `limitTolerance(min:max:)`

Limit all tolerances in this shape to a given range.

```swift
@discardableResult
public func limitTolerance(min: Double, max: Double) -> Bool
```

- **Parameters:**
  - `min` — Minimum tolerance.
  - `max` — Maximum tolerance.
- **Returns:** `true` if any tolerance was changed.
- **OCCT:** `ShapeFix_ShapeTolerance::LimitTolerance` (via `OCCTShapeFixLimitTolerance`).

---

### `setTolerance(_:)`

Set all tolerances in this shape to a specific value.

```swift
public func setTolerance(_ tolerance: Double)
```

- **Parameters:** `tolerance` — Tolerance value to set on all sub-shapes.
- **OCCT:** `ShapeFix_ShapeTolerance::SetTolerance` (via `OCCTShapeFixSetTolerance`).

---

### `splitCommonVertices()`

Split vertices that are shared between edges in incompatible ways.

```swift
public func splitCommonVertices() -> Shape?
```

- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeFix_SplitCommonVertex` (via `OCCTShapeFixSplitCommonVertex`).

---

### `connectedFaces(tolerance:)`

Connect adjacent faces in this shape's shell.

```swift
public func connectedFaces(tolerance: Double = 1e-4) -> Shape?
```

- **Parameters:** `tolerance` — Connection tolerance.
- **Returns:** Fixed shape with connected faces, or `nil` on failure.
- **OCCT:** `ShapeFix_FaceConnect` (via `OCCTShapeFixFaceConnect`).

---

### `fixEdgeSameParameter(tolerance:)`

Fix same-parameter inconsistencies on all edges.

```swift
@discardableResult
public func fixEdgeSameParameter(tolerance: Double = 0) -> Int
```

- **Parameters:** `tolerance` — Fixing tolerance (0 = default).
- **Returns:** Number of edges fixed.
- **OCCT:** `ShapeFix_Edge::FixSameParameter` (via `OCCTShapeFixEdgeSameParameter`).

---

### `fixEdgeVertexTolerance()`

Fix vertex tolerance issues on all edges.

```swift
@discardableResult
public func fixEdgeVertexTolerance() -> Int
```

- **Returns:** Number of edges fixed.
- **OCCT:** `ShapeFix_Edge::FixVertexTolerance` (via `OCCTShapeFixEdgeVertexTolerance`).

---

### `fixWireVertices(precision:)`

Fix vertex issues in all wires of this shape.

```swift
@discardableResult
public func fixWireVertices(precision: Double = 1e-4) -> Int
```

- **Parameters:** `precision` — Precision for fixing.
- **Returns:** Number of fixes applied.
- **OCCT:** `ShapeFix_WireVertex` (via `OCCTShapeFixWireVertex`).

---

### `EdgeEdgeExtrema`

Result of edge-edge distance extrema computation.

```swift
public struct EdgeEdgeExtrema: Sendable {
    public let distance: Double
    public let paramOnEdge1: Double
    public let paramOnEdge2: Double
    public let pointOnEdge1: SIMD3<Double>
    public let pointOnEdge2: SIMD3<Double>
    public let isParallel: Bool
    public let solutionCount: Int
}
```

---

### `edgeEdgeExtrema(edgeIndex1:other:edgeIndex2:)`

Compute distance extrema between two edges by index.

```swift
public func edgeEdgeExtrema(edgeIndex1: Int, other: Shape, edgeIndex2: Int) -> EdgeEdgeExtrema?
```

- **Parameters:**
  - `edgeIndex1` — 0-based index of the first edge in this shape.
  - `other` — Shape containing the second edge.
  - `edgeIndex2` — 0-based index of the second edge in `other`.
- **Returns:** Extrema result, or `nil` if no solutions or if edges are parallel.
- **OCCT:** `BRepExtrema_ExtCC` (via `OCCTBRepExtremaExtCC`).
- **Note:** Returns `nil` when edges are parallel (`isParallel == true`). Check `solutionCount > 0` guards this in the bridge.

---

### `PointFaceExtrema`

Result of point-face distance extrema computation.

```swift
public struct PointFaceExtrema: Sendable {
    public let distance: Double
    public let faceUV: SIMD2<Double>
    public let pointOnFace: SIMD3<Double>
    public let solutionCount: Int
}
```

---

### `pointFaceExtrema(point:faceIndex:)`

Compute distance from a point to a face.

```swift
public func pointFaceExtrema(point: SIMD3<Double>, faceIndex: Int) -> PointFaceExtrema?
```

- **Parameters:**
  - `point` — 3D point.
  - `faceIndex` — 0-based face index in this shape.
- **Returns:** Extrema result, or `nil` on failure.
- **OCCT:** `BRepExtrema_ExtPF` (via `OCCTBRepExtremaExtPF`).

---

### `FaceFaceExtrema`

Result of face-face distance extrema computation.

```swift
public struct FaceFaceExtrema: Sendable {
    public let distance: Double
    public let face1UV: SIMD2<Double>
    public let face2UV: SIMD2<Double>
    public let pointOnFace1: SIMD3<Double>
    public let pointOnFace2: SIMD3<Double>
    public let solutionCount: Int
}
```

---

### `faceFaceExtrema(faceIndex1:other:faceIndex2:)`

Compute distance extrema between two faces.

```swift
public func faceFaceExtrema(faceIndex1: Int, other: Shape, faceIndex2: Int) -> FaceFaceExtrema?
```

- **Parameters:**
  - `faceIndex1` — 0-based index of the first face in this shape.
  - `other` — Shape containing the second face.
  - `faceIndex2` — 0-based index of the second face in `other`.
- **Returns:** Extrema result, or `nil` on failure.
- **OCCT:** `BRepExtrema_ExtFF` (via `OCCTBRepExtremaExtFF`).

---

### `dividedClosedFaces(splitPoints:)`

Divide closed (wrapping) faces in this shape.

```swift
public func dividedClosedFaces(splitPoints: Int = 1) -> Shape?
```

Uses `ShapeUpgrade_ShapeDivideClosed` to split faces that wrap completely around (e.g., the lateral face of a cylinder).

- **Parameters:** `splitPoints` — Number of split points per closed face.
- **Returns:** Shape with divided faces, or `nil` on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideClosed` (via `OCCTShapeUpgradeDivideClosed`).

---

### `ContinuityLevel`

Continuity level for shape division.

```swift
public enum ContinuityLevel: Int32, Sendable {
    case c0 = 0, c1 = 1, c2 = 2, c3 = 3, cn = 4, g1 = 5, g2 = 6
}
```

---

### `dividedByContinuity(criterion:tolerance:)`

Divide this shape at continuity breaks.

```swift
public func dividedByContinuity(criterion: ContinuityLevel = .c1, tolerance: Double = 1e-4) -> Shape?
```

Splits faces and edges at points where the geometry drops below the required continuity level.

- **Parameters:**
  - `criterion` — Minimum required continuity level.
  - `tolerance` — Tolerance for continuity check.
- **Returns:** Divided shape, or `nil` if no divisions needed or on failure.
- **OCCT:** `ShapeUpgrade_ShapeDivideContinuity` (via `OCCTShapeUpgradeDivideContinuity`).

---

### `PointEdgeExtrema`

Result of point-edge distance extrema computation.

```swift
public struct PointEdgeExtrema: Sendable {
    public let distance: Double
    public let parameter: Double
    public let pointOnEdge: SIMD3<Double>
    public let solutionCount: Int
}
```

---

### `pointEdgeExtrema(point:edgeIndex:)`

Compute minimum distance from a point to an edge of this shape.

```swift
public func pointEdgeExtrema(point: SIMD3<Double>, edgeIndex: Int) -> PointEdgeExtrema?
```

- **Parameters:**
  - `point` — 3D point.
  - `edgeIndex` — 0-based edge index.
- **Returns:** Extrema result, or `nil` on failure.
- **OCCT:** `BRepExtrema_ExtPC` (via `OCCTBRepExtremaExtPC`).

---

### `EdgeFaceExtrema`

Result of edge-face distance extrema computation.

```swift
public struct EdgeFaceExtrema: Sendable {
    public let distance: Double
    public let paramOnEdge: Double
    public let faceUV: SIMD2<Double>
    public let pointOnEdge: SIMD3<Double>
    public let pointOnFace: SIMD3<Double>
    public let isParallel: Bool
    public let solutionCount: Int
}
```

---

### `edgeFaceExtrema(edgeIndex:other:faceIndex:)`

Compute distance extrema between an edge and a face.

```swift
public func edgeFaceExtrema(edgeIndex: Int, other: Shape, faceIndex: Int) -> EdgeFaceExtrema?
```

- **Parameters:**
  - `edgeIndex` — 0-based edge index in this shape.
  - `other` — Shape containing the face.
  - `faceIndex` — 0-based face index in `other`.
- **Returns:** Extrema result, or `nil` if parallel or computation fails.
- **OCCT:** `BRepExtrema_ExtCF` (via `OCCTBRepExtremaExtCF`).
- **Note:** When `isParallel` is `true`, the returned struct has zero distance and `solutionCount == 0`.

---

### `removeSmallSolids(volumeThreshold:)`

Remove small solids from this shape based on volume threshold.

```swift
public func removeSmallSolids(volumeThreshold: Double) -> Shape?
```

- **Parameters:** `volumeThreshold` — Solids with volume below this threshold are removed.
- **Returns:** Shape with small solids removed, or `nil` on failure.
- **OCCT:** `ShapeFix_FixSmallSolid` (via `OCCTShapeFixRemoveSmallSolids`).

---

### `mergeSmallSolids(widthFactorThreshold:)`

Merge small solids into adjacent larger solids.

```swift
public func mergeSmallSolids(widthFactorThreshold: Double) -> Shape?
```

Small solids are merged into their neighbors rather than removed.

- **Parameters:** `widthFactorThreshold` — Width factor below which solids are merged.
- **Returns:** Shape with small solids merged, or `nil` on failure.
- **OCCT:** `ShapeFix_FixSmallSolid` (via `OCCTShapeFixMergeSmallSolids`).

---

### `BSplineContinuity`

Continuity requirement for BSpline restriction.

```swift
public enum BSplineContinuity: Int32, Sendable {
    case c0 = 0, c1 = 1, c2 = 2, c3 = 3
}
```

---

### `bsplineRestriction(tol3d:tol2d:maxDegree:maxSegments:continuity3d:continuity2d:degreePriority:rational:)`

Simplify BSpline surfaces and curves by restricting degree and segment count.

```swift
public func bsplineRestriction(
    tol3d: Double = 0.01, tol2d: Double = 0.01,
    maxDegree: Int = 8, maxSegments: Int = 100,
    continuity3d: BSplineContinuity = .c1, continuity2d: BSplineContinuity = .c1,
    degreePriority: Bool = true, rational: Bool = false
) -> Shape?
```

- **Parameters:**
  - `tol3d` — 3D approximation tolerance.
  - `tol2d` — 2D approximation tolerance.
  - `maxDegree` — Maximum BSpline degree.
  - `maxSegments` — Maximum number of segments.
  - `continuity3d` — 3D continuity requirement.
  - `continuity2d` — 2D continuity requirement.
  - `degreePriority` — If `true`, prioritize degree reduction over segment reduction.
  - `rational` — Allow rational BSplines.
- **Returns:** Simplified shape, or `nil` on failure.
- **OCCT:** `ShapeCustom::BSplineRestriction` (via `OCCTShapeCustomBSplineRestriction`).

---

## ShapeAnalysis FreeBoundsProperties

### `FreeBoundInfo`

Properties of a single free bound (boundary wire).

```swift
public struct FreeBoundInfo: Sendable {
    public let area: Double
    public let perimeter: Double
    public let ratio: Double
    public let width: Double
    public let notchCount: Int
}
```

- `ratio` — `area / perimeter²` (shape factor).

---

### `FreeBoundsAnalysis`

Summary result of free bounds analysis.

```swift
public struct FreeBoundsAnalysis: Sendable {
    public let totalCount: Int
    public let closedCount: Int
    public let openCount: Int
}
```

---

### `freeBoundsAnalysis(tolerance:)`

Analyze free bounds (boundary wires) of this shape.

```swift
public func freeBoundsAnalysis(tolerance: Double) -> FreeBoundsAnalysis
```

Free bounds are edges that belong to only one face.

- **Parameters:** `tolerance` — Sewing tolerance for finding free bounds.
- **Returns:** Analysis summary with closed and open bound counts.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsAnalyze`).
- **Example:**
  ```swift
  let fb = shell.freeBoundsAnalysis(tolerance: 1e-6)
  print("open: \(fb.openCount), closed: \(fb.closedCount)")
  ```

---

### `closedFreeBoundInfo(tolerance:index:)`

Get properties of a closed free bound.

```swift
public func closedFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo?
```

- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the closed free bound.
- **Returns:** Properties, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsGetClosedBoundInfo`).

---

### `openFreeBoundInfo(tolerance:index:)`

Get properties of an open free bound.

```swift
public func openFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo?
```

- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the open free bound.
- **Returns:** Properties, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsGetOpenBoundInfo`).

---

### `closedFreeBoundWire(tolerance:index:)`

Get the wire shape of a closed free bound.

```swift
public func closedFreeBoundWire(tolerance: Double, index: Int) -> Shape?
```

- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the closed free bound.
- **Returns:** Wire as a `Shape`, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsGetClosedBoundWire`).

---

### `openFreeBoundWire(tolerance:index:)`

Get the wire shape of an open free bound.

```swift
public func openFreeBoundWire(tolerance: Double, index: Int) -> Shape?
```

- **Parameters:**
  - `tolerance` — Same tolerance used for `freeBoundsAnalysis(tolerance:)`.
  - `index` — 0-based index of the open free bound.
- **Returns:** Wire as a `Shape`, or `nil` if the index is out of range.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsGetOpenBoundWire`).
