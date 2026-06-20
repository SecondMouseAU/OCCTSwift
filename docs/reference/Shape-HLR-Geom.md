---
title: Shape — HLR, Intervals, Mesh Props & Geom Primitives
parent: API Reference
---

# Shape — HLR, Intervals, Mesh Props & Geom Primitives

This page documents the v0.73 / v0.76 batch of `Shape`-adjacent APIs covering hidden-line removal, interval arithmetic, curve/surface/ray intersection, mesh properties, geometric inertia, and the standalone `Geom_*` entity wrappers. See the main **Shape** type page for the primary `Shape` class (constructors, transforms, booleans, etc.).

## Topics

- [v0.73.0: TKHlr — Extended HLR, ReflectLines, TopCnx, Intrv](#v0730-tkhlr--extended-hlr-reflectlines-topcnx-intrv) · [Intrv_Interval (Interval with Tolerances)](#intrv_interval-interval-with-tolerances) · [Intrv_Intervals (Sorted Non-Overlapping Interval Sequence)](#intrv_intervals-sorted-non-overlapping-interval-sequence) · [ShapeRayIntersection (BRepIntCurveSurface_Inter)](#shaperayintersection-brepintcurvesurface_inter) · [ShapeConstruct (Triangulation)](#shapeconstruct-triangulation) · [Surface Extensions (ShapeCustom_Surface periodic + gap)](#surface-extensions-shapecustom_surface-periodic--gap) · [MeshCinert (Linear Mass Properties from Mesh)](#meshcinert-linear-mass-properties-from-mesh) · [MeshProps (Surface/Volume Properties from Mesh)](#meshprops-surfacevolume-properties-from-mesh) · [MeshShapeTool (Static Mesh Utilities)](#meshshapetool-static-mesh-utilities) · [ValidateEdge (BRepLib_ValidateEdge)](#validateedge-breplib_validateedge) · [BiTgte_Blend (Rolling-Ball Blend)](#bitgte_blend-rolling-ball-blend) · [GeomConvert_ApproxCurve/Surface](#geomconvert_approxcurvesurface) · [GCPnts_QuasiUniformAbscissa](#gcpnts_quasiuniformabscissa) · [GCPnts_TangentialDeflection](#gcpnts_tangentialdeflection) · [BRepGProp_Cinert (Curve Inertia per Edge)](#brepgprop_cinert-curve-inertia-per-edge) · [BRepGProp_Sinert (Surface Inertia per Face)](#brepgprop_sinert-surface-inertia-per-face) · [BRepGProp_Vinert (Volume Inertia per Face)](#brepgprop_vinert-volume-inertia-per-face) · [ShapeConstruct_ProjectCurveOnSurface](#shapeconstruct_projectcurveonsurface) · [BRepPreviewAPI_MakeBox](#breppreviewapi_makebox) · [GeomPoint3D (Geom_CartesianPoint)](#geompoint3d-geom_cartesianpoint) · [GeomDirection (Geom_Direction)](#geomdirection-geom_direction) · [GeomVector3D (Geom_VectorWithMagnitude)](#geomvector3d-geom_vectorwithmagnitude) · [Axis1Placement (Geom_Axis1Placement)](#axis1placement-geom_axis1placement)

---

## v0.73.0: TKHlr — Extended HLR, ReflectLines, TopCnx, Intrv

### `HLREdgeCategory`

Fine-grained HLR edge categories for exact and polygon-based hidden line removal.

```swift
public enum HLREdgeCategory: Int32, Sendable {
    case visibleSharp = 0
    case visibleSmooth = 1
    case visibleSewn = 2
    case visibleOutline = 3
    case visibleIso = 4
    case visibleOutline3d = 5
    case hiddenSharp = 6
    case hiddenSmooth = 7
    case hiddenSewn = 8
    case hiddenOutline = 9
    case hiddenIso = 10
}
```

Used with `hlrEdges(direction:category:)` and `hlrPolyEdges(direction:category:deflection:)` to select which edge class to extract. `.visibleIso`, `.hiddenIso`, and `.visibleOutline3d` are available for exact HLR only.

---

### `HLREdgeType`

HLR result edge type for the generic `CompoundOfEdges` and `ReflectLines` APIs.

```swift
public enum HLREdgeType: Int32, Sendable {
    case undefined = 0
    case isoLine = 1
    case outLine = 2
    case rg1Line = 3
    case rgNLine = 4
    case sharp = 5
}
```

Used with `hlrCompoundOfEdges(direction:edgeType:visible:in3d:)` and the `reflectLinesFiltered` family.

---

### `hlrEdges(direction:category:)`

Extracts edges by fine-grained category using exact HLR (hidden line removal).

```swift
public func hlrEdges(direction: SIMD3<Double>, category: HLREdgeCategory) -> Shape?
```

- **Parameters:** `direction` — view direction vector; `category` — which class of edges to extract.
- **Returns:** Compound of extracted edges, or `nil` if none exist for that category.
- **OCCT:** `HLRBRep_Algo` / `HLRBRep_HLRToShape` via `OCCTHLRGetEdgesByCategory`.
- **Example:**
  ```swift
  if let edges = shape.hlrEdges(direction: SIMD3(0, 0, -1), category: .visibleSharp) {
      // edges is a compound of visible sharp edges in the -Z view
  }
  ```

---

### `hlrPolyEdges(direction:category:deflection:)`

Extracts edges by fine-grained category using fast polygon-based (poly) HLR.

```swift
public func hlrPolyEdges(direction: SIMD3<Double>, category: HLREdgeCategory,
                         deflection: Double = 0.1) -> Shape?
```

Poly HLR projects the shape's triangulation rather than its exact geometry, making it dramatically faster on curved solids (e.g. ~48× on an analytic helicoid). Prefer this for 2D drawings of threaded or curved parts. `.visibleIso`, `.hiddenIso`, and `.visibleOutline3d` are not available for poly HLR.

- **Parameters:**
  - `direction` — view direction vector.
  - `category` — edge class to extract.
  - `deflection` — linear mesh deflection (mm) for the internal triangulation. Smaller = finer drawing; larger = coarser and faster. Default `0.1`. Meshing is incremental: existing finer triangulations are not coarsened.
- **Returns:** Compound of extracted edges, or `nil` if none exist.
- **OCCT:** `HLRBRep_PolyAlgo` / `HLRBRep_PolyHLRToShape` via `OCCTHLRPolyGetEdgesByCategory`.
- **Example:**
  ```swift
  if let vis = shape.hlrPolyEdges(direction: SIMD3(0, 0, -1),
                                   category: .visibleSharp, deflection: 0.05) {
      // vis contains visible sharp edges, finely meshed
  }
  ```

---

### `hlrCompoundOfEdges(direction:edgeType:visible:in3d:)`

Extracts a compound of edges using the generic `CompoundOfEdges` API from exact HLR.

```swift
public func hlrCompoundOfEdges(direction: SIMD3<Double>, edgeType: HLREdgeType,
                                visible: Bool, in3d: Bool) -> Shape?
```

- **Parameters:**
  - `direction` — view direction vector.
  - `edgeType` — edge type filter (`HLREdgeType`).
  - `visible` — `true` for visible edges, `false` for hidden.
  - `in3d` — `true` to return 3D edges; `false` for projected 2D edges.
- **Returns:** Compound of matching edges, or `nil` on failure.
- **OCCT:** `HLRBRep_HLRToShape::CompoundOfEdges` via `OCCTHLRCompoundOfEdges`.
- **Example:**
  ```swift
  if let outlines = shape.hlrCompoundOfEdges(direction: SIMD3(0, 0, -1),
                                              edgeType: .outLine, visible: true, in3d: true) {
      // outlines contains the visible silhouette edges in 3D
  }
  ```

---

### `reflectLines(normal:viewPoint:up:)`

Computes reflect (silhouette) lines on a shape for a given view.

```swift
public func reflectLines(normal: SIMD3<Double>, viewPoint: SIMD3<Double>,
                         up: SIMD3<Double>) -> Shape?
```

- **Parameters:**
  - `normal` — view plane normal direction.
  - `viewPoint` — eye/target position.
  - `up` — up direction for the view frame.
- **Returns:** Compound of reflect line edges in 3D, or `nil` on failure.
- **OCCT:** `HLRAppli_ReflectLines` via `OCCTHLRReflectLines`.
- **Example:**
  ```swift
  if let silhouette = shape.reflectLines(normal: SIMD3(0, 0, 1),
                                          viewPoint: SIMD3(0, 0, 100),
                                          up: SIMD3(0, 1, 0)) {
      // silhouette is a compound of outline curves
  }
  ```

---

### `reflectLinesFiltered(normal:viewPoint:up:edgeType:visible:in3d:)`

Computes reflect lines and filters the result by edge type and visibility.

```swift
public func reflectLinesFiltered(normal: SIMD3<Double>, viewPoint: SIMD3<Double>,
                                  up: SIMD3<Double>, edgeType: HLREdgeType,
                                  visible: Bool, in3d: Bool) -> Shape?
```

- **Parameters:**
  - `normal` — view plane normal direction.
  - `viewPoint` — eye/target position.
  - `up` — up direction.
  - `edgeType` — edge type to extract.
  - `visible` — `true` for visible, `false` for hidden.
  - `in3d` — `true` for 3D edges, `false` for projected.
- **Returns:** Filtered compound of reflect line edges, or `nil` on failure.
- **OCCT:** `HLRAppli_ReflectLines` / `CompoundOfEdges` via `OCCTHLRReflectLinesFiltered`.

---

### `EdgeFaceTransitionResult`

Result of an edge-face transition computation.

```swift
public struct EdgeFaceTransitionResult: Sendable {
    public let transition: Int           // TopAbs_Orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
    public let boundaryTransition: Int   // TopAbs_Orientation for boundary
}
```

---

### `FaceInterference`

Face interference description passed to `edgeFaceTransition(edgeTangent:edgeNormal:edgeCurvature:faces:)`.

```swift
public struct FaceInterference: Sendable {
    public let tangent: SIMD3<Double>
    public let normal: SIMD3<Double>
    public let curvature: Double
    public let orientation: Int32        // TopAbs_Orientation
    public let transition: Int32         // TopAbs_Orientation
    public let boundaryTransition: Int32 // TopAbs_Orientation
    public let tolerance: Double

    public init(tangent: SIMD3<Double>, normal: SIMD3<Double>, curvature: Double,
                orientation: Int32, transition: Int32, boundaryTransition: Int32,
                tolerance: Double)
}
```

---

### `Shape.edgeFaceTransition(edgeTangent:edgeNormal:edgeCurvature:faces:)`

Computes the cumulated edge-face transition orientation for multiple face interferences on an edge.

```swift
public static func edgeFaceTransition(edgeTangent: SIMD3<Double>,
                                      edgeNormal: SIMD3<Double>,
                                      edgeCurvature: Double,
                                      faces: [FaceInterference]) -> EdgeFaceTransitionResult
```

- **Parameters:**
  - `edgeTangent` — edge tangent direction.
  - `edgeNormal` — edge normal direction (use `.zero` for linear edges).
  - `edgeCurvature` — edge curvature (0 for linear edges).
  - `faces` — array of `FaceInterference` descriptors.
- **Returns:** `EdgeFaceTransitionResult` with cumulated `transition` and `boundaryTransition` orientations.
- **OCCT:** `TopCnx_EdgeFaceTransition` via `OCCTTopCnxEdgeFaceTransition`.

---

## Intrv_Interval (Interval with Tolerances)

### `Interval`

A real interval `[start, end]` with optional per-endpoint tolerances, wrapping `Intrv_Interval`.

```swift
public final class Interval: @unchecked Sendable
```

---

### `Interval.init(start:end:tolStart:tolEnd:)`

Creates an interval with bounds and optional tolerances.

```swift
public init(start: Double, end: Double, tolStart: Float = 0, tolEnd: Float = 0)
```

- **Parameters:** `start` — lower bound; `end` — upper bound; `tolStart` — tolerance at start; `tolEnd` — tolerance at end.
- **OCCT:** `Intrv_Interval(start, end, tolStart, tolEnd)` via `OCCTIntrvIntervalCreate`.
- **Example:**
  ```swift
  let iv = Interval(start: 0.0, end: 1.0, tolStart: 1e-6, tolEnd: 1e-6)
  ```

---

### `Interval.Bounds`

The bounds and tolerances of an interval.

```swift
public struct Bounds: Sendable {
    public let start: Double
    public let end: Double
    public let tolStart: Float
    public let tolEnd: Float
}
```

---

### `bounds`

Gets the interval bounds and tolerances.

```swift
public var bounds: Bounds { get }
```

- **Returns:** `Bounds` struct with `start`, `end`, `tolStart`, `tolEnd`.
- **OCCT:** `Intrv_Interval::Start`, `End`, `TolStart`, `TolEnd` via `OCCTIntrvIntervalBounds`.

---

### `isProbablyEmpty`

Whether the interval is probably empty.

```swift
public var isProbablyEmpty: Bool { get }
```

- **Returns:** `true` if `start + tolStart > end - tolEnd`.
- **OCCT:** `Intrv_Interval::IsVoid` via `OCCTIntrvIntervalIsProbablyEmpty`.

---

### `position(relativeTo:)`

Position of this interval relative to another.

```swift
public func position(relativeTo other: Interval) -> Int
```

- **Parameters:** `other` — the reference interval.
- **Returns:** `Intrv_Position` enum raw value (0 = Before … 12 = After).
- **OCCT:** `Intrv_Interval::Position` via `OCCTIntrvIntervalPosition`.

---

### `isBefore(_:)`

Whether this interval is entirely before another.

```swift
public func isBefore(_ other: Interval) -> Bool
```

- **OCCT:** `Intrv_Interval::IsBefore` via `OCCTIntrvIntervalIsBefore`.

---

### `isAfter(_:)`

Whether this interval is entirely after another.

```swift
public func isAfter(_ other: Interval) -> Bool
```

- **OCCT:** `Intrv_Interval::IsAfter` via `OCCTIntrvIntervalIsAfter`.

---

### `isInside(_:)`

Whether this interval is entirely inside another.

```swift
public func isInside(_ other: Interval) -> Bool
```

- **OCCT:** `Intrv_Interval::IsInside` via `OCCTIntrvIntervalIsInside`.

---

### `isEnclosing(_:)`

Whether this interval entirely encloses another.

```swift
public func isEnclosing(_ other: Interval) -> Bool
```

- **OCCT:** `Intrv_Interval::IsEnclosing` via `OCCTIntrvIntervalIsEnclosing`.

---

### `isSimilar(to:)`

Whether this interval has the same bounds as another (within tolerances).

```swift
public func isSimilar(to other: Interval) -> Bool
```

- **OCCT:** `Intrv_Interval::IsSimilar` via `OCCTIntrvIntervalIsSimilar`.

---

### `setStart(_:tolerance:)`

Sets the start bound.

```swift
public func setStart(_ start: Double, tolerance: Float = 0)
```

- **Parameters:** `start` — new start value; `tolerance` — new start tolerance.
- **OCCT:** `Intrv_Interval::SetStart` via `OCCTIntrvIntervalSetStart`.

---

### `setEnd(_:tolerance:)`

Sets the end bound.

```swift
public func setEnd(_ end: Double, tolerance: Float = 0)
```

- **Parameters:** `end` — new end value; `tolerance` — new end tolerance.
- **OCCT:** `Intrv_Interval::SetEnd` via `OCCTIntrvIntervalSetEnd`.

---

### `fuseAtStart(_:tolerance:)`

Extends the start bound outward (union at start).

```swift
public func fuseAtStart(_ start: Double, tolerance: Float = 0)
```

- **Parameters:** `start` — new start bound (must be ≤ current start to extend); `tolerance` — new tolerance.
- **OCCT:** `Intrv_Interval::FuseAtStart` via `OCCTIntrvIntervalFuseAtStart`.

---

### `fuseAtEnd(_:tolerance:)`

Extends the end bound outward (union at end).

```swift
public func fuseAtEnd(_ end: Double, tolerance: Float = 0)
```

- **OCCT:** `Intrv_Interval::FuseAtEnd` via `OCCTIntrvIntervalFuseAtEnd`.

---

### `cutAtStart(_:tolerance:)`

Trims the start bound inward.

```swift
public func cutAtStart(_ start: Double, tolerance: Float = 0)
```

- **OCCT:** `Intrv_Interval::CutAtStart` via `OCCTIntrvIntervalCutAtStart`.

---

### `cutAtEnd(_:tolerance:)`

Trims the end bound inward.

```swift
public func cutAtEnd(_ end: Double, tolerance: Float = 0)
```

- **OCCT:** `Intrv_Interval::CutAtEnd` via `OCCTIntrvIntervalCutAtEnd`.

---

## Intrv_Intervals (Sorted Non-Overlapping Interval Sequence)

### `IntervalSet`

A sorted sequence of non-overlapping `Intrv_Interval` objects supporting set-theoretic operations.

```swift
public final class IntervalSet: @unchecked Sendable
```

---

### `IntervalSet.init(start:end:)`

Creates an interval set containing a single interval.

```swift
public init(start: Double, end: Double)
```

- **OCCT:** `Intrv_Intervals(Intrv_Interval)` via `OCCTIntrvIntervalsCreate`.
- **Example:**
  ```swift
  let set = IntervalSet(start: 0.0, end: 10.0)
  ```

---

### `IntervalSet.init()`

Creates an empty interval set.

```swift
public init()
```

- **OCCT:** `Intrv_Intervals()` via `OCCTIntrvIntervalsCreateEmpty`.

---

### `count`

Number of non-overlapping intervals in the set.

```swift
public var count: Int { get }
```

- **OCCT:** `Intrv_Intervals::Length` via `OCCTIntrvIntervalsCount`.

---

### `bounds(at:)`

Gets the bounds of the interval at a zero-based index.

```swift
public func bounds(at index: Int) -> Interval.Bounds
```

- **Parameters:** `index` — zero-based interval index (internally maps to 1-based OCCT indexing).
- **Returns:** `Interval.Bounds` for that interval.
- **OCCT:** `Intrv_Intervals::Value` via `OCCTIntrvIntervalsValue`.

---

### `unite(start:end:)`

Adds an interval to the set (union).

```swift
public func unite(start: Double, end: Double)
```

- **OCCT:** `Intrv_Intervals::Unite` via `OCCTIntrvIntervalsUnite`.
- **Example:**
  ```swift
  let set = IntervalSet(start: 0.0, end: 5.0)
  set.unite(start: 7.0, end: 10.0)
  // set now has two intervals: [0,5] and [7,10]
  ```

---

### `subtract(start:end:)`

Subtracts an interval from the set.

```swift
public func subtract(start: Double, end: Double)
```

- **OCCT:** `Intrv_Intervals::Subtract` via `OCCTIntrvIntervalsSubtract`.

---

### `intersect(start:end:)`

Intersects the set with an interval, keeping only the overlap.

```swift
public func intersect(start: Double, end: Double)
```

- **OCCT:** `Intrv_Intervals::Intersect` via `OCCTIntrvIntervalsIntersect`.

---

### `xUnite(start:end:)`

Applies exclusive union (symmetric difference) with an interval.

```swift
public func xUnite(start: Double, end: Double)
```

- **OCCT:** `Intrv_Intervals::XUnite` via `OCCTIntrvIntervalsXUnite`.

---

## ShapeRayIntersection (BRepIntCurveSurface_Inter)

### `ShapeRayIntersection`

Iterator over line/curve–shape intersection results, wrapping `BRepIntCurveSurface_Inter`.

```swift
public final class ShapeRayIntersection: @unchecked Sendable
```

---

### `ShapeRayIntersection.Hit`

A single intersection hit between the line/curve and a face.

```swift
public struct Hit {
    public let x: Double, y: Double, z: Double  // 3D intersection point
    public let u: Double, v: Double              // UV parameters on face surface
    public let w: Double                         // parameter on the curve/line
}
```

---

### `ShapeRayIntersection.init?(shape:originX:originY:originZ:dirX:dirY:dirZ:tolerance:)`

Creates an intersection of a line with a shape.

```swift
public init?(shape: Shape, originX: Double, originY: Double, originZ: Double,
             dirX: Double, dirY: Double, dirZ: Double, tolerance: Double = 1e-6)
```

- **Parameters:** `shape` — target B-Rep shape; `originX/Y/Z` — ray origin; `dirX/Y/Z` — ray direction; `tolerance` — intersection tolerance.
- **Returns:** `nil` if initialisation fails.
- **OCCT:** `BRepIntCurveSurface_Inter::Init(shape, gp_Lin)` via `OCCTCurveSurfaceInterCreateLine`.
- **Example:**
  ```swift
  if let inter = ShapeRayIntersection(shape: box,
                                       originX: 0, originY: 0, originZ: -10,
                                       dirX: 0, dirY: 0, dirZ: 1) {
      let hits = inter.allHits()
  }
  ```

---

### `ShapeRayIntersection.init?(shape:curve:tolerance:)`

Creates an intersection of a `Curve3D` with a shape.

```swift
public init?(shape: Shape, curve: Curve3D, tolerance: Double = 1e-6)
```

- **Parameters:** `shape` — target shape; `curve` — 3D curve; `tolerance` — intersection tolerance.
- **Returns:** `nil` if initialisation fails.
- **OCCT:** `BRepIntCurveSurface_Inter::Init(shape, curve)` via `OCCTCurveSurfaceInterCreateCurve`.

---

### `hasMore`

Whether more intersection results are available for iteration.

```swift
public var hasMore: Bool { get }
```

- **OCCT:** `BRepIntCurveSurface_Inter::More` via `OCCTCurveSurfaceInterMore`.

---

### `next()`

Advances to the next intersection result.

```swift
public func next()
```

- **OCCT:** `BRepIntCurveSurface_Inter::Next` via `OCCTCurveSurfaceInterNext`.

---

### `currentHit`

Returns the current intersection hit data.

```swift
public var currentHit: Hit { get }
```

- **Returns:** `Hit` with 3D point, UV face parameters, and curve parameter `w`.
- **OCCT:** `BRepIntCurveSurface_Inter::Pnt`, `UParameter`, `VParameter`, `WParameter` via `OCCTCurveSurfaceInterHit`.

---

### `currentFace`

Returns the face at the current intersection.

```swift
public var currentFace: Face? { get }
```

- **Returns:** The `Face` that was hit, or `nil` on failure.
- **OCCT:** `BRepIntCurveSurface_Inter::Face` via `OCCTCurveSurfaceInterFace`.

---

### `allHits()`

Collects all intersection hits by draining the iterator.

```swift
public func allHits() -> [Hit]
```

- **Returns:** Array of all `Hit` values (may be empty if no intersections).
- **Note:** Calling this exhausts the iterator — `hasMore` will be `false` afterward.
- **Example:**
  ```swift
  if let inter = ShapeRayIntersection(shape: shape,
                                       originX: 0, originY: 0, originZ: 50,
                                       dirX: 0, dirY: 0, dirZ: -1) {
      for hit in inter.allHits() {
          print("hit at z=\(hit.z), u=\(hit.u), v=\(hit.v)")
      }
  }
  ```

---

## ShapeConstruct (Triangulation)

### `Shape.triangulationFromPoints(_:)`

Creates a triangulated face from a flat list of 3D points.

```swift
public static func triangulationFromPoints(_ points: [(Double, Double, Double)]) -> Shape?
```

- **Parameters:** `points` — ordered list of 3D coordinate triples.
- **Returns:** A triangulated `Shape` (face), or `nil` on failure.
- **OCCT:** `ShapeConstruct_MakeTriangulation` via `OCCTShapeConstructTriangulationFromPoints`.
- **Example:**
  ```swift
  let pts = [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.5, 1.0, 0.0)]
  if let tri = Shape.triangulationFromPoints(pts) {
      // tri is a triangulated face
  }
  ```

---

### `Shape.triangulationFromWire(_:)`

Creates a triangulated face from a planar wire.

```swift
public static func triangulationFromWire(_ wire: Wire) -> Shape?
```

- **Parameters:** `wire` — a closed planar wire to triangulate.
- **Returns:** A triangulated `Shape`, or `nil` on failure.
- **OCCT:** `ShapeConstruct_MakeTriangulation` via `OCCTShapeConstructTriangulationFromWire`.
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5),
     let tri = Shape.triangulationFromWire(rect) {
      // tri is a mesh of the rectangle
  }
  ```

---

## Surface Extensions (ShapeCustom_Surface periodic + gap)

### `Surface.convertToPeriodic()`

Converts a surface to periodic form.

```swift
public func convertToPeriodic() -> Surface?
```

- **Returns:** The periodified surface, or `nil` if the surface is already periodic or cannot be converted.
- **OCCT:** `ShapeCustom_Surface::ConvertToPeriodic` via `OCCTSurfaceConvertToPeriodic`.
- **Example:**
  ```swift
  if let periodic = surface.convertToPeriodic() {
      print(periodic.isUPeriodic)  // true for converted cylinder/cone
  }
  ```

---

### `conversionGap`

The distance between the original and periodically converted surface (conversion error).

```swift
public var conversionGap: Double { get }
```

- **Returns:** Gap value in model units; 0.0 if no conversion has been applied.
- **OCCT:** `ShapeCustom_Surface::Gap` via `OCCTSurfaceConversionGap`.

---

## MeshCinert (Linear Mass Properties from Mesh)

### `MeshCinertResult`

Result of linear mass property computation from polygon points.

```swift
public struct MeshCinertResult {
    public let mass: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}
```

---

### `Edge.meshPolygonPoints()`

Prepares polygon points from a meshed edge for use with `meshCinertCompute(points:)`.

```swift
public func meshPolygonPoints() -> [(Double, Double, Double)]
```

- **Returns:** Array of 3D coordinate triples from the edge's mesh polygon (up to 1000 points).
- **OCCT:** `BRepGProp_MeshCinert::PreparePolygon` via `OCCTMeshCinertPreparePolygon`.
- **Example:**
  ```swift
  let pts = someEdge.meshPolygonPoints()
  let props = meshCinertCompute(points: pts)
  ```

---

### `meshCinertCompute(points:)`

Computes linear mass properties (mass and centre of mass) from polygon point coordinates.

```swift
public func meshCinertCompute(points: [(Double, Double, Double)]) -> MeshCinertResult
```

This is a free function (not a method). Feed it the output of `Edge.meshPolygonPoints()`.

- **Parameters:** `points` — array of 3D coordinate triples.
- **Returns:** `MeshCinertResult` with `mass` (total arc length) and centre coordinates.
- **OCCT:** `BRepGProp_MeshCinert::Perform` via `OCCTMeshCinertCompute`.

---

## MeshProps (Surface/Volume Properties from Mesh)

### `MeshPropsType`

Selects the type of mesh property to compute.

```swift
public enum MeshPropsType {
    case volume
    case surface
}
```

---

### `MeshPropsResult`

Result of mesh property computation.

```swift
public struct MeshPropsResult {
    public let mass: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}
```

`mass` is surface area when `type == .surface`, or enclosed volume when `type == .volume`.

---

### `Face.meshProps(type:)`

Computes mesh surface or volume properties for a triangulated face.

```swift
public func meshProps(type: MeshPropsType) -> MeshPropsResult
```

- **Parameters:** `type` — `.surface` for area and centroid, `.volume` for enclosed volume and centroid.
- **Returns:** `MeshPropsResult` with mass and centre of mass.
- **OCCT:** `BRepGProp_MeshProps` (Sinert/Vinert path) via `OCCTMeshPropsCompute`.
- **Example:**
  ```swift
  let result = triangulatedFace.meshProps(type: .surface)
  print("area =", result.mass)
  ```

---

## MeshShapeTool (Static Mesh Utilities)

### `Face.maxMeshTolerance`

Maximum tolerance of edges and vertices on this face.

```swift
public var maxMeshTolerance: Double { get }
```

- **Returns:** Maximum tolerance in model units.
- **OCCT:** `BRepMesh_ShapeTool::MaxFaceTolerance` via `OCCTMeshShapeToolMaxFaceTolerance`.

---

### `Face.uvPoints(edge:)`

Gets the UV parameter points of an edge on this face.

```swift
public func uvPoints(edge: Edge) -> (u1: Double, v1: Double, u2: Double, v2: Double)?
```

- **Parameters:** `edge` — an edge that lies on this face.
- **Returns:** Tuple of UV parameters at each end of the edge, or `nil` if the edge is not on this face.
- **OCCT:** `BRepMesh_ShapeTool::UVPoints` via `OCCTMeshShapeToolUVPoints`.
- **Example:**
  ```swift
  if let uv = face.uvPoints(edge: edge) {
      print("start UV: (\(uv.u1), \(uv.v1))")
  }
  ```

---

### `Shape.meshMaxDimension`

Maximum dimension of this shape's bounding box (useful for mesh sizing heuristics).

```swift
public var meshMaxDimension: Double { get }
```

- **Returns:** The largest of the bounding box width, height, and depth.
- **OCCT:** `BRepMesh_ShapeTool::BoxMaxDimension` via `OCCTMeshShapeToolBoxMaxDimension`.

---

## ValidateEdge (BRepLib_ValidateEdge)

### `ValidateEdgeResult`

Result of 3D curve vs curve-on-surface consistency check.

```swift
public struct ValidateEdgeResult {
    public let isDone: Bool
    public let isWithinTolerance: Bool
    public let maxDistance: Double
    public let tolerance: Double
}
```

---

### `Edge.validate(on:tolerance:)`

Validates edge geometry against a face (3D curve vs curve-on-surface consistency).

```swift
public func validate(on face: Face, tolerance: Double = 1e-3) -> ValidateEdgeResult
```

- **Parameters:** `face` — the face containing this edge's pcurve; `tolerance` — acceptable maximum deviation.
- **Returns:** `ValidateEdgeResult` with `isDone`, `isWithinTolerance`, `maxDistance`, and the tested `tolerance`.
- **OCCT:** `BRepLib_ValidateEdge` via `OCCTValidateEdge`.
- **Example:**
  ```swift
  let result = edge.validate(on: face)
  if !result.isWithinTolerance {
      print("max deviation:", result.maxDistance)
  }
  ```

---

## BiTgte_Blend (Rolling-Ball Blend)

### `Shape.biTgteBlend(edgeIndices:radius:tolerance:nubs:)`

Creates a rolling-ball blend on specified edges using `BiTgte_Blend`.

```swift
public func biTgteBlend(edgeIndices: [Int], radius: Double, tolerance: Double = 1e-3,
                        nubs: Bool = false) -> Shape?
```

`BiTgte_Blend` is an alternative blend algorithm that can handle configurations where `BRepFilletAPI_MakeFillet` fails.

- **Parameters:**
  - `edgeIndices` — zero-based indices of edges to blend (as returned by the shape's topology explorer).
  - `radius` — blend radius.
  - `tolerance` — geometric tolerance.
  - `nubs` — if `true`, outputs NUBS (Non-Uniform B-Spline) surfaces; if `false`, outputs NURBS.
- **Returns:** Blended shape, or `nil` if blending fails.
- **OCCT:** `BiTgte_Blend::Perform` via `OCCTBiTgteBlend`.
- **Example:**
  ```swift
  if let blended = box.biTgteBlend(edgeIndices: [0, 1, 2], radius: 2.0) {
      // blended has rounded edges
  }
  ```

---

## GeomConvert_ApproxCurve/Surface

### `ApproxContinuity`

Continuity level for BSpline approximation.

```swift
public enum ApproxContinuity: Int32 {
    case c0 = 0, c1 = 1, c2 = 2, c3 = 3
}
```

---

### `ApproxCurveResult`

Result of curve approximation including the output curve, error, and status.

```swift
public struct ApproxCurveResult {
    public let curve: Curve3D?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}
```

---

### `Curve3D.approxWithDetails(tolerance:continuity:maxSegments:maxDegree:)`

Approximates a 3D curve as a BSpline with detailed result information.

```swift
public func approxWithDetails(tolerance: Double, continuity: ApproxContinuity = .c2,
                               maxSegments: Int = 100, maxDegree: Int = 8) -> ApproxCurveResult
```

- **Parameters:**
  - `tolerance` — maximum approximation deviation.
  - `continuity` — desired continuity of the output BSpline.
  - `maxSegments` — maximum number of BSpline segments.
  - `maxDegree` — maximum polynomial degree.
- **Returns:** `ApproxCurveResult` with the output `Curve3D` (or `nil`), `maxError`, and status flags.
- **OCCT:** `GeomConvert_ApproxCurve` via `OCCTGeomConvertApproxCurve`.
- **Example:**
  ```swift
  let result = curve.approxWithDetails(tolerance: 0.01, continuity: .c2)
  if result.isDone, let bsp = result.curve {
      print("max error:", result.maxError)
  }
  ```

---

### `ApproxSurfaceResult`

Result of surface approximation including the output surface, error, and status.

```swift
public struct ApproxSurfaceResult {
    public let surface: Surface?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}
```

---

### `Surface.approxWithDetails(tolerance:uContinuity:vContinuity:maxDegree:maxSegments:)`

Approximates a surface as a BSpline with detailed result information.

```swift
public func approxWithDetails(tolerance: Double, uContinuity: ApproxContinuity = .c1,
                               vContinuity: ApproxContinuity = .c1,
                               maxDegree: Int = 8, maxSegments: Int = 100) -> ApproxSurfaceResult
```

- **Parameters:**
  - `tolerance` — maximum approximation deviation.
  - `uContinuity` — desired continuity in U direction.
  - `vContinuity` — desired continuity in V direction.
  - `maxDegree` — maximum polynomial degree.
  - `maxSegments` — maximum number of BSpline segments.
- **Returns:** `ApproxSurfaceResult` with the output `Surface` (or `nil`), `maxError`, and status flags.
- **OCCT:** `GeomConvert_ApproxSurface` via `OCCTGeomConvertApproxSurface`.
- **Note:** Prefer `Surface.approximated(tolerance:continuity:maxSegments:maxDegree:)` for simpler use; use this variant when you need the error and status separately.
- **Example:**
  ```swift
  let result = surface.approxWithDetails(tolerance: 0.001)
  if result.isDone, let bsp = result.surface {
      print("max error:", result.maxError)
  }
  ```

---

## GCPnts_QuasiUniformAbscissa

### `Edge.quasiUniformParameters(count:)`

Computes a quasi-uniform parameter distribution along an edge.

```swift
public func quasiUniformParameters(count: Int) -> [Double]
```

The returned parameters are distributed so that the chord lengths between consecutive curve points are approximately equal.

- **Parameters:** `count` — desired number of parameter values.
- **Returns:** Array of curve parameters of length ≤ `count`.
- **OCCT:** `GCPnts_QuasiUniformAbscissa` via `OCCTGCPntsQuasiUniform`.
- **Example:**
  ```swift
  let params = edge.quasiUniformParameters(count: 20)
  // params has ~20 evenly-spaced (by chord) parameter values
  ```

---

## GCPnts_TangentialDeflection

### `TangentialDeflectionPoint`

A sampled point from tangential deflection discretisation.

```swift
public struct TangentialDeflectionPoint {
    public let parameter: Double
    public let x: Double, y: Double, z: Double
}
```

---

### `Edge.tangentialDeflectionPoints(angularDeflection:curvatureDeflection:minPoints:)`

Samples an edge using combined angular and chordal deflection criteria.

```swift
public func tangentialDeflectionPoints(angularDeflection: Double = 0.1,
                                       curvatureDeflection: Double = 0.1,
                                       minPoints: Int = 2) -> [TangentialDeflectionPoint]
```

This is the standard adaptive sampling algorithm used by OCCT's meshing pipeline; it produces denser samples where curvature is high.

- **Parameters:**
  - `angularDeflection` — maximum angular deviation between consecutive tangents (radians).
  - `curvatureDeflection` — maximum chordal deviation (model units).
  - `minPoints` — minimum number of sample points (must be ≥ 2).
- **Returns:** Array of `TangentialDeflectionPoint` values (up to 10000).
- **OCCT:** `GCPnts_TangentialDeflection` via `OCCTGCPntsTangentialDeflection`.
- **Example:**
  ```swift
  let pts = edge.tangentialDeflectionPoints(angularDeflection: 0.05,
                                             curvatureDeflection: 0.1)
  for pt in pts {
      print("t=\(pt.parameter): (\(pt.x), \(pt.y), \(pt.z))")
  }
  ```

---

## BRepGProp_Cinert (Curve Inertia per Edge)

### `CurveInertia`

Curve linear inertia properties (arc length and centre of mass).

```swift
public struct CurveInertia {
    public let length: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}
```

---

### `Edge.curveInertia`

Computes linear inertia (arc length and centre of mass) for this edge.

```swift
public var curveInertia: CurveInertia { get }
```

- **Returns:** `CurveInertia` with `length` and centre of mass coordinates.
- **OCCT:** `BRepGProp_Cinert` via `OCCTBRepGPropCinert`.
- **Example:**
  ```swift
  let inertia = edge.curveInertia
  print("length:", inertia.length)
  print("center:", inertia.centerX, inertia.centerY, inertia.centerZ)
  ```

---

## BRepGProp_Sinert (Surface Inertia per Face)

### `FaceSurfaceInertia`

Face surface inertia properties (area and centre of mass).

```swift
public struct FaceSurfaceInertia {
    public let area: Double
    public let centerX: Double, centerY: Double, centerZ: Double
    public let epsilon: Double
}
```

`epsilon` is the integration error bound; it is `0` for the non-adaptive overload.

---

### `Face.surfaceInertia`

Computes surface inertia (area and centre of mass) for this face.

```swift
public var surfaceInertia: FaceSurfaceInertia { get }
```

- **Returns:** `FaceSurfaceInertia` with `area` and centre of mass (`epsilon` = 0).
- **OCCT:** `BRepGProp_Sinert` via `OCCTBRepGPropSinert`.
- **Example:**
  ```swift
  let inertia = face.surfaceInertia
  print("area:", inertia.area)
  ```

---

### `Face.surfaceInertia(epsilon:)`

Computes surface inertia using adaptive numerical integration to the given error bound.

```swift
public func surfaceInertia(epsilon: Double) -> FaceSurfaceInertia
```

- **Parameters:** `epsilon` — target integration error bound.
- **Returns:** `FaceSurfaceInertia` with `area`, centre of mass, and actual `epsilon` achieved.
- **OCCT:** `BRepGProp_Sinert` adaptive overload via `OCCTBRepGPropSinertAdaptive`.

---

## BRepGProp_Vinert (Volume Inertia per Face)

### `FaceVolumeInertia`

Face volume inertia contribution.

```swift
public struct FaceVolumeInertia {
    public let volume: Double
    public let centerX: Double, centerY: Double, centerZ: Double
}
```

---

### `Face.volumeInertia`

Computes the volume inertia contribution from this face (relative to the origin).

```swift
public var volumeInertia: FaceVolumeInertia { get }
```

- **Returns:** `FaceVolumeInertia` with signed `volume` and centre of mass.
- **OCCT:** `BRepGProp_Vinert` via `OCCTBRepGPropVinert`.
- **Example:**
  ```swift
  let vi = face.volumeInertia
  print("volume contribution:", vi.volume)
  ```

---

### `Face.volumeInertia(planeNormal:planeDistance:)`

Computes volume inertia with respect to a reference plane.

```swift
public func volumeInertia(planeNormal: SIMD3<Double>, planeDistance: Double = 0) -> FaceVolumeInertia
```

- **Parameters:**
  - `planeNormal` — normal of the reference plane.
  - `planeDistance` — signed distance from origin to the plane along `planeNormal`.
- **Returns:** `FaceVolumeInertia` measured relative to the given plane.
- **OCCT:** `BRepGProp_Vinert(face, gp_Pln)` via `OCCTBRepGPropVinertPlane`.

---

## ShapeConstruct_ProjectCurveOnSurface

### `Curve3D.projectOnSurface(_:firstParam:lastParam:precision:)`

Projects a 3D curve onto a surface, returning a 2D (UV) curve.

```swift
public func projectOnSurface(_ surface: Surface, firstParam: Double? = nil,
                              lastParam: Double? = nil, precision: Double = 1e-6) -> Curve2D?
```

- **Parameters:**
  - `surface` — target surface.
  - `firstParam` — start of the curve parameter range (default: `domain.lowerBound`).
  - `lastParam` — end of the curve parameter range (default: `domain.upperBound`).
  - `precision` — projection tolerance.
- **Returns:** A `Curve2D` in UV parameter space of the surface, or `nil` if projection fails.
- **OCCT:** `ShapeConstruct_ProjectCurveOnSurface::Perform` via `OCCTProjectCurveOnSurface`.
- **Example:**
  ```swift
  if let pcurve = curve3D.projectOnSurface(surface, precision: 1e-6) {
      // pcurve is the 2D UV representation of curve3D on surface
  }
  ```

---

## BRepPreviewAPI_MakeBox

### `Shape.previewBox(width:height:depth:)`

Creates a preview box shape that handles degenerate dimensions gracefully.

```swift
public static func previewBox(width: Double, height: Double, depth: Double) -> Shape?
```

Unlike `Shape.box(width:height:depth:)`, this factory accepts degenerate inputs and returns the appropriate lower-dimensional shape: a box for fully 3D dimensions, a face for one zero dimension, an edge for two zero dimensions, or a vertex for all-zero dimensions.

- **Parameters:** `width` — X dimension; `height` — Y dimension; `depth` — Z dimension.
- **Returns:** A `Shape` (solid, face, edge, or vertex), or `nil` on failure.
- **OCCT:** `BRepPreviewAPI_MakeBox` via `OCCTPreviewBox`.
- **Example:**
  ```swift
  // Returns a Face (sheet) when depth is 0
  if let sheet = Shape.previewBox(width: 10, height: 5, depth: 0) {
      print(sheet.shapeType)  // .face
  }
  ```

---

## GeomPoint3D (Geom_CartesianPoint)

### `GeomPoint3D`

A Handle-managed 3D geometric point, wrapping `Geom_CartesianPoint`.

```swift
public final class GeomPoint3D: @unchecked Sendable
```

Useful when you need OCCT's geometry-level point entity (rather than a raw `SIMD3<Double>`) for operations that take `Handle(Geom_Point)` arguments.

---

### `GeomPoint3D.init(x:y:z:)`

Creates a geometric point at the given coordinates.

```swift
public init(x: Double, y: Double, z: Double)
```

- **OCCT:** `Geom_CartesianPoint(x, y, z)` via `OCCTGeomPoint3DCreate`.

---

### `GeomPoint3D.init(simd:)`

Creates a geometric point from a `SIMD3<Double>`.

```swift
public init(simd: SIMD3<Double>)
```

---

### `x`, `y`, `z`

The Cartesian coordinates of this point.

```swift
public var x: Double { get }
public var y: Double { get }
public var z: Double { get }
```

- **OCCT:** `Geom_CartesianPoint::X`, `Y`, `Z`.

---

### `coordinates`

The coordinates as a `SIMD3<Double>`.

```swift
public var coordinates: SIMD3<Double> { get }
```

---

### `setCoordinates(x:y:z:)`

Sets the point coordinates.

```swift
public func setCoordinates(x: Double, y: Double, z: Double)
```

- **OCCT:** `Geom_CartesianPoint::SetCoord` via `OCCTGeomPoint3DSetCoord`.

---

### `distance(to:)`

Returns the Euclidean distance to another geometric point.

```swift
public func distance(to other: GeomPoint3D) -> Double
```

- **OCCT:** `Geom_Point::Distance` via `OCCTGeomPoint3DDistance`.
- **Example:**
  ```swift
  let a = GeomPoint3D(x: 0, y: 0, z: 0)
  let b = GeomPoint3D(x: 3, y: 4, z: 0)
  print(a.distance(to: b))  // 5.0
  ```

---

### `squareDistance(to:)`

Returns the squared Euclidean distance to another geometric point.

```swift
public func squareDistance(to other: GeomPoint3D) -> Double
```

- **OCCT:** `Geom_Point::SquareDistance` via `OCCTGeomPoint3DSquareDistance`.

---

### `translate(dx:dy:dz:)`

Translates this point in place.

```swift
public func translate(dx: Double, dy: Double, dz: Double)
```

- **OCCT:** `Geom_CartesianPoint::Translate(gp_Vec)` via `OCCTGeomPoint3DTranslate`.

---

## GeomDirection (Geom_Direction)

### `GeomDirection`

A Handle-managed 3D unit vector (always normalised), wrapping `Geom_Direction`.

```swift
public final class GeomDirection: @unchecked Sendable
```

The input vector is automatically normalised on construction. Use this when downstream OCCT APIs require a `Handle(Geom_Direction)`.

---

### `GeomDirection.init(x:y:z:)`

Creates a unit direction from component values. The vector is normalised automatically.

```swift
public init(x: Double, y: Double, z: Double)
```

- **OCCT:** `Geom_Direction(x, y, z)` via `OCCTGeomDirectionCreate`.
- **Example:**
  ```swift
  let up = GeomDirection(x: 0, y: 0, z: 1)
  ```

---

### `GeomDirection.init(simd:)`

Creates a unit direction from a `SIMD3<Double>`.

```swift
public init(simd: SIMD3<Double>)
```

---

### `coordinates`

The unit vector as a `SIMD3<Double>`.

```swift
public var coordinates: SIMD3<Double> { get }
```

- **OCCT:** `Geom_Direction::X`, `Y`, `Z` via `OCCTGeomDirectionCoords`.

---

### `setCoordinates(x:y:z:)`

Sets the direction; the new vector is automatically normalised.

```swift
public func setCoordinates(x: Double, y: Double, z: Double)
```

- **OCCT:** `Geom_Direction::SetCoord` via `OCCTGeomDirectionSetCoord`.

---

### `crossed(with:)`

Returns the cross product with another direction.

```swift
public func crossed(with other: GeomDirection) -> GeomDirection?
```

- **Returns:** A new `GeomDirection` perpendicular to both, or `nil` if the vectors are parallel (cross product is zero).
- **OCCT:** `Geom_Direction::Cross` via `OCCTGeomDirectionCrossed`.
- **Example:**
  ```swift
  let x = GeomDirection(x: 1, y: 0, z: 0)
  let y = GeomDirection(x: 0, y: 1, z: 0)
  if let z = x.crossed(with: y) {
      print(z.coordinates)  // SIMD3(0, 0, 1)
  }
  ```

---

## GeomVector3D (Geom_VectorWithMagnitude)

### `GeomVector3D`

A Handle-managed 3D vector with arbitrary magnitude, wrapping `Geom_VectorWithMagnitude`. Unlike `GeomDirection`, the vector may have any non-negative length including zero.

```swift
public final class GeomVector3D: @unchecked Sendable
```

---

### `GeomVector3D.init(x:y:z:)`

Creates a vector from component values.

```swift
public init(x: Double, y: Double, z: Double)
```

- **OCCT:** `Geom_VectorWithMagnitude(x, y, z)` via `OCCTGeomVector3DCreate`.

---

### `GeomVector3D.init(simd:)`

Creates a vector from a `SIMD3<Double>`.

```swift
public init(simd: SIMD3<Double>)
```

---

### `GeomVector3D.init(from:to:)`

Creates a vector from point `p1` to point `p2`.

```swift
public init(from p1: SIMD3<Double>, to p2: SIMD3<Double>)
```

- **OCCT:** `Geom_VectorWithMagnitude(p1, p2)` via `OCCTGeomVector3DFromPoints`.
- **Example:**
  ```swift
  let v = GeomVector3D(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0))
  print(v.magnitude)  // 5.0
  ```

---

### `coordinates`

The vector components as a `SIMD3<Double>`.

```swift
public var coordinates: SIMD3<Double> { get }
```

- **OCCT:** `Geom_Vector::X`, `Y`, `Z` via `OCCTGeomVector3DCoords`.

---

### `magnitude`

The Euclidean length of this vector.

```swift
public var magnitude: Double { get }
```

- **OCCT:** `Geom_Vector::Magnitude` via `OCCTGeomVector3DMagnitude`.

---

### `dot(_:)`

Dot product with another vector.

```swift
public func dot(_ other: GeomVector3D) -> Double
```

- **OCCT:** `Geom_Vector::Dot` via `OCCTGeomVector3DDot`.

---

### `added(_:)`

Returns the sum of this vector and another.

```swift
public func added(_ other: GeomVector3D) -> GeomVector3D
```

- **OCCT:** `Geom_Vector::Added` via `OCCTGeomVector3DAdded`.

---

### `multiplied(by:)`

Returns this vector scaled by a scalar.

```swift
public func multiplied(by scalar: Double) -> GeomVector3D
```

- **OCCT:** `Geom_VectorWithMagnitude::Multiplied` via `OCCTGeomVector3DMultiplied`.

---

### `normalized()`

Returns a normalised copy of this vector.

```swift
public func normalized() -> GeomVector3D?
```

- **Returns:** Unit vector in the same direction, or `nil` if `magnitude` is near zero.
- **OCCT:** `Geom_VectorWithMagnitude::Normalized` via `OCCTGeomVector3DNormalized`.
- **Example:**
  ```swift
  let v = GeomVector3D(x: 3, y: 4, z: 0)
  if let u = v.normalized() {
      print(u.magnitude)  // ~1.0
  }
  ```

---

### `crossed(_:)`

Returns the cross product with another vector.

```swift
public func crossed(_ other: GeomVector3D) -> GeomVector3D
```

- **Returns:** A new `GeomVector3D` perpendicular to both inputs.
- **OCCT:** `Geom_VectorWithMagnitude::Crossed` via `OCCTGeomVector3DCrossed`.

---

## Axis1Placement (Geom_Axis1Placement)

### `Axis1Placement`

A Handle-managed 3D axis (origin point + direction), wrapping `Geom_Axis1Placement`. Used as a placement entity for geometry operations that require an `Axis1`.

```swift
public final class Axis1Placement: @unchecked Sendable
```

---

### `Axis1Placement.init(origin:direction:)`

Creates an axis placement from an origin point and a direction vector.

```swift
public init(origin: SIMD3<Double>, direction: SIMD3<Double>)
```

- **Parameters:** `origin` — the axis origin point; `direction` — the axis direction (normalised internally).
- **OCCT:** `Geom_Axis1Placement(gp_Pnt, gp_Dir)` via `OCCTAxis1PlacementCreate`.
- **Example:**
  ```swift
  let axis = Axis1Placement(origin: .zero, direction: SIMD3(0, 0, 1))
  ```

---

### `location`

The origin point of the axis.

```swift
public var location: SIMD3<Double> { get }
```

- **OCCT:** `Geom_Axis1Placement::Location` via `OCCTAxis1PlacementLocation`.

---

### `direction`

The unit direction of the axis.

```swift
public var direction: SIMD3<Double> { get }
```

- **OCCT:** `Geom_Axis1Placement::Direction` via `OCCTAxis1PlacementDirection`.

---

### `reverse()`

Reverses the axis direction in place.

```swift
public func reverse()
```

- **OCCT:** `Geom_Axis1Placement::Reverse` via `OCCTAxis1PlacementReverse`.

---

### `reversed()`

Returns a new axis with the direction reversed.

```swift
public func reversed() -> Axis1Placement
```

- **Returns:** A new `Axis1Placement` with the same origin and the direction negated.
- **OCCT:** `Geom_Axis1Placement::Reversed` via `OCCTAxis1PlacementReversed`.
- **Example:**
  ```swift
  let axis = Axis1Placement(origin: .zero, direction: SIMD3(0, 0, 1))
  let flipped = axis.reversed()
  print(flipped.direction)  // SIMD3(0, 0, -1)
  ```

---

### `setDirection(_:)`

Sets the axis direction.

```swift
public func setDirection(_ dir: SIMD3<Double>)
```

- **OCCT:** `Geom_Axis1Placement::SetDirection` via `OCCTAxis1PlacementSetDirection`.

---

### `setLocation(_:)`

Sets the axis origin point.

```swift
public func setLocation(_ loc: SIMD3<Double>)
```

- **OCCT:** `Geom_Axis1Placement::SetLocation` via `OCCTAxis1PlacementSetLocation`.
