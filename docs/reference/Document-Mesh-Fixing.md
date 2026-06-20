---
title: Document — Mesh I/O, Projection & Shape Fixing
parent: API Reference
---

# Document — Mesh I/O, Projection & Shape Fixing

This page covers the low-level mesh-iteration types, interference and ancestry helpers, shape-manipulation extensions, curve/surface extras, full projection and distance classes, shape-fixing wrappers, `BSpline` mutation methods, the low-level `TopoDS_Builder` extensions, free-bounds analysis, incremental wire building, tolerance-aware booleans, offset and thick-solid operations, mass-property expansions, and the `Helix` geometry namespace. All are declared in `Sources/OCCTSwift/Document.swift` across four consecutive `// MARK:` sections.

See the main [Document](Document.md) page for the XDE document, assembly, colour, GD&T, and OCAF attribute APIs.

## Topics

- [RWMesh Iterators, Intf Tool, BRepAlgo AsDes, BiTgte, Shape Extras, Extrema](#rwmesh-iterators-intf-tool-brepalgo-asdes-bitgte-shape-extras-extrema)
- [MakeEdge Completions, ProjOnCurve/Surf, DistShapeShape, ShapeFix Wire/Face](#makeedge-completions-projoncurvesurf-distshapeshape-shapefix-wireface)
- [TopoDS Builder, ShapeContents Expanded, FreeBoundsProperties, WireBuilder](#topods-builder-shapecontents-expanded-freeboundsproperties-wirebuilder)
- [HelixGeom](#helixgeom)

---

## RWMesh Iterators, Intf Tool, BRepAlgo AsDes, BiTgte, Shape Extras, Extrema

### `MeshFaceIterator`

Iterator over triangulated faces of a meshed `Shape`.

```swift
public final class MeshFaceIterator: @unchecked Sendable
```

The shape must already be meshed (e.g. via `Mesh.fromShape(_:deflection:angle:)`) before creating this iterator.

- **OCCT:** `RWMesh_FaceIterator`.

---

### `MeshFaceIterator.init(shape:)`

Create a face iterator over a meshed shape.

```swift
public init?(shape: Shape)
```

- **Parameters:** `shape` — a `Shape` with an existing `Poly_Triangulation` on its faces.
- **Returns:** An iterator positioned before the first face, or `nil` on failure.
- **OCCT:** `OCCTMeshFaceIterCreate` → `RWMesh_FaceIterator`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  _ = Mesh.fromShape(box, deflection: 0.1, angle: 0.5)
  if let iter = MeshFaceIterator(shape: box) {
      while iter.hasMore {
          print("triangles:", iter.triangleCount)
          iter.next()
      }
  }
  ```

---

### `MeshFaceIterator.hasMore`

Whether the iterator has more faces remaining.

```swift
public var hasMore: Bool { get }
```

- **OCCT:** `RWMesh_FaceIterator::More`.

---

### `MeshFaceIterator.next()`

Advance to the next face.

```swift
public func next()
```

- **OCCT:** `RWMesh_FaceIterator::Next`.

---

### `MeshFaceIterator.nodeCount`

Number of nodes in the current face triangulation.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `Poly_Triangulation::NbNodes`.

---

### `MeshFaceIterator.triangleCount`

Number of triangles in the current face triangulation.

```swift
public var triangleCount: Int { get }
```

- **OCCT:** `Poly_Triangulation::NbTriangles`.

---

### `MeshFaceIterator.node(at:)`

Get the 3D position of the node at a 1-based index.

```swift
public func node(at index: Int) -> SIMD3<Double>
```

- **Parameters:** `index` — 1-based node index (1 … `nodeCount`).
- **Returns:** Node position in model space.
- **OCCT:** `Poly_Triangulation::Node`.

---

### `MeshFaceIterator.hasNormals`

Whether the current face has per-node normals.

```swift
public var hasNormals: Bool { get }
```

- **OCCT:** `Poly_Triangulation::HasNormals`.

---

### `MeshFaceIterator.normal(at:)`

Get the surface normal at a 1-based node index.

```swift
public func normal(at index: Int) -> SIMD3<Double>
```

- **Parameters:** `index` — 1-based node index.
- **Returns:** Normal vector (not guaranteed to be unit length if the mesh was built without normals).
- **OCCT:** `Poly_Triangulation::Normal`.

---

### `MeshFaceIterator.triangle(at:)`

Get the three node indices of a triangle at a 1-based triangle index.

```swift
public func triangle(at index: Int) -> (n1: Int, n2: Int, n3: Int)
```

- **Parameters:** `index` — 1-based triangle index (1 … `triangleCount`).
- **Returns:** A tuple of three 1-based node indices.
- **OCCT:** `Poly_Triangulation::Triangle`.
- **Example:**
  ```swift
  if let iter = MeshFaceIterator(shape: box) {
      while iter.hasMore {
          for t in 1...iter.triangleCount {
              let tri = iter.triangle(at: t)
              let p1 = iter.node(at: tri.n1)
              let p2 = iter.node(at: tri.n2)
              let p3 = iter.node(at: tri.n3)
              _ = (p1, p2, p3)
          }
          iter.next()
      }
  }
  ```

---

### `MeshVertexIterator`

Iterator over vertices of a shape.

```swift
public final class MeshVertexIterator: @unchecked Sendable
```

- **OCCT:** `RWMesh_VertexIterator`.

---

### `MeshVertexIterator.init(shape:)`

Create a vertex iterator over a shape.

```swift
public init?(shape: Shape)
```

- **Parameters:** `shape` — the shape to iterate.
- **Returns:** An iterator, or `nil` on failure.
- **OCCT:** `OCCTMeshVertexIterCreate` → `RWMesh_VertexIterator`.
- **Example:**
  ```swift
  if let iter = MeshVertexIterator(shape: box) {
      while iter.hasMore {
          print(iter.point)
          iter.next()
      }
  }
  ```

---

### `MeshVertexIterator.hasMore`

Whether the iterator has more vertices remaining.

```swift
public var hasMore: Bool { get }
```

---

### `MeshVertexIterator.next()`

Advance to the next vertex.

```swift
public func next()
```

---

### `MeshVertexIterator.point`

The 3D position of the current vertex.

```swift
public var point: SIMD3<Double> { get }
```

- **OCCT:** `BRep_Tool::Pnt` on the current `TopoDS_Vertex`.

---

### `IntfTool`

Line-box clipping utility wrapping `Intf_Tool`.

```swift
public final class IntfTool: @unchecked Sendable
```

Computes the parameter intervals where an infinite line intersects an axis-aligned bounding box.

---

### `IntfTool.init()`

Create a new `IntfTool` instance.

```swift
public init()
```

- **OCCT:** `OCCTIntfToolCreate` → `Intf_Tool`.

---

### `IntfTool.clipLineToBox(lineOrigin:lineDirection:boxMin:boxMax:)`

Clip a line to an axis-aligned bounding box and return the number of intersection segments.

```swift
@discardableResult
public func clipLineToBox(
    lineOrigin: SIMD3<Double>, lineDirection: SIMD3<Double>,
    boxMin: SIMD3<Double>, boxMax: SIMD3<Double>
) -> Int
```

- **Parameters:**
  - `lineOrigin` — any point on the line.
  - `lineDirection` — direction vector of the line (need not be normalised).
  - `boxMin`, `boxMax` — corner extremes of the axis-aligned bounding box.
- **Returns:** Number of intersection segments (0, 1, or 2).
- **OCCT:** `Intf_Tool::LinBox`.
- **Example:**
  ```swift
  let tool = IntfTool()
  let n = tool.clipLineToBox(
      lineOrigin: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
      boxMin: SIMD3(-5, -5, -5), boxMax: SIMD3(5, 5, 5))
  if n > 0 {
      print("enters at t =", tool.beginParam(segment: 1))
      print("exits at t =", tool.endParam(segment: 1))
  }
  ```

---

### `IntfTool.beginParam(segment:)`

Get the entry parameter of a clipped segment.

```swift
public func beginParam(segment: Int) -> Double
```

- **Parameters:** `segment` — 1-based segment index.
- **OCCT:** `Intf_Tool::BeginParam`.

---

### `IntfTool.endParam(segment:)`

Get the exit parameter of a clipped segment.

```swift
public func endParam(segment: Int) -> Double
```

- **Parameters:** `segment` — 1-based segment index.
- **OCCT:** `Intf_Tool::EndParam`.

---

### `AsDesTracker`

Ascendant-descendant relationship tracker wrapping `BRepAlgo_AsDes`.

```swift
public final class AsDesTracker: @unchecked Sendable
```

Used internally by filleting and other operations to record how new shapes descend from originals.

---

### `AsDesTracker.init()`

Create an empty ascendant-descendant tracker.

```swift
public init()
```

- **OCCT:** `OCCTAsDesCreate` → `BRepAlgo_AsDes`.

---

### `AsDesTracker.add(parent:child:)`

Record a parent-child (ascendant-descendant) relationship.

```swift
public func add(parent: Shape, child: Shape)
```

- **OCCT:** `BRepAlgo_AsDes::Add`.

---

### `AsDesTracker.hasDescendant(_:)`

Check whether a shape has any recorded descendants.

```swift
public func hasDescendant(_ shape: Shape) -> Bool
```

- **OCCT:** `BRepAlgo_AsDes::HasDescendant`.

---

### `AsDesTracker.descendantCount(_:)`

Get the number of descendants recorded for a shape.

```swift
public func descendantCount(_ shape: Shape) -> Int
```

- **OCCT:** `BRepAlgo_AsDes::Descendant` count.
- **Example:**
  ```swift
  let tracker = AsDesTracker()
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let face = box.faces().first!
  tracker.add(parent: box, child: face)
  print(tracker.hasDescendant(box))        // true
  print(tracker.descendantCount(box))      // 1
  ```

---

### `BiTgteCurveOnEdge`

A curve defined by an edge lying on another edge, from blend operations (`BiTgte_CurveOnEdge`).

```swift
public final class BiTgteCurveOnEdge: @unchecked Sendable
```

---

### `BiTgteCurveOnEdge.init(edgeOnFace:edge:)`

Create a curve-on-edge from two edge shapes.

```swift
public init?(edgeOnFace: Shape, edge: Shape)
```

- **Parameters:** `edgeOnFace` — the edge lying on a face; `edge` — the reference edge.
- **Returns:** The curve-on-edge, or `nil` on failure.
- **OCCT:** `BiTgte_CurveOnEdge`.

---

### `BiTgteCurveOnEdge.domain`

Parameter domain of the curve.

```swift
public var domain: ClosedRange<Double> { get }
```

- **OCCT:** `BiTgte_CurveOnEdge::FirstParameter` / `LastParameter`.

---

### `BiTgteCurveOnEdge.point(at:)`

Evaluate the curve position at parameter `u`.

```swift
public func point(at u: Double) -> SIMD3<Double>
```

- **Parameters:** `u` — curve parameter within `domain`.
- **OCCT:** `BiTgte_CurveOnEdge::Value`.
- **Example:**
  ```swift
  if let coe = BiTgteCurveOnEdge(edgeOnFace: edgeA, edge: edgeB) {
      let mid = (coe.domain.lowerBound + coe.domain.upperBound) / 2
      print(coe.point(at: mid))
  }
  ```

---

### `Shape.child(at:)`

Get a direct child sub-shape at a 0-based index.

```swift
public func child(at index: Int) -> Shape?
```

- **Parameters:** `index` — zero-based child index.
- **Returns:** The child shape, or `nil` if `index` is out of range.
- **OCCT:** `TopoDS_Iterator` (via `OCCTShapeChild`).

---

### `Shape.isLocked`

Whether the shape is locked against modification.

```swift
public var isLocked: Bool { get }
```

- **OCCT:** `TopoDS_Shape::Locked`.

---

### `Shape.setLocked(_:)`

Set the locked state of the shape.

```swift
public func setLocked(_ locked: Bool)
```

- **OCCT:** `TopoDS_Shape::Locked`.

---

### `Shape.located(matrix:)`

Create a copy of this shape with a new location transform applied.

```swift
public func located(matrix: [Double]) -> Shape?
```

- **Parameters:** `matrix` — at least 12 elements encoding a 4×3 row-major transform matrix (rows: x-axis, y-axis, z-axis, translation).
- **Returns:** A new located shape, or `nil` if `matrix.count < 12` or the operation fails.
- **OCCT:** `TopLoc_Location` + `TopoDS_Shape::Located` (via `OCCTShapeLocated`).

---

### `Shape.locationMatrix`

Get the current location as a 4×3 row-major matrix (12 elements).

```swift
public var locationMatrix: [Double] { get }
```

- **Returns:** 12-element array; identity if no location is set.
- **OCCT:** `TopLoc_Location::IsIdentity` / `gp_Trsf::VectorialPart` (via `OCCTShapeGetLocation`).

---

### `Shape.setLocation(matrix:)`

Set the location transform in-place (4×3 row-major matrix).

```swift
public func setLocation(matrix: [Double])
```

- **Parameters:** `matrix` — at least 12 elements. Silently ignored if `matrix.count < 12`.
- **OCCT:** `TopLoc_Location` + `TopoDS_Shape::Location` (via `OCCTShapeSetLocation`).

---

### `Shape.oriented(_:)`

Create a copy with a specific orientation.

```swift
public func oriented(_ orientation: Int) -> Shape?
```

- **Parameters:** `orientation` — `0` = Forward, `1` = Reversed, `2` = Internal, `3` = External.
- **Returns:** Oriented copy, or `nil` on failure.
- **OCCT:** `TopoDS_Shape::Oriented` (via `OCCTShapeOriented`).

---

### `Shape.empty(type:)`

Create an empty shape of the given topology type.

```swift
public static func empty(type: Int) -> Shape?
```

- **Parameters:** `type` — `0` = Compound, `2` = Solid, `3` = Shell, `5` = Wire.
- **Returns:** An empty shape of that type, or `nil` on failure.
- **OCCT:** `TopoDS_Shape` with `TopAbs_ShapeEnum` (via `OCCTShapeEmpty`).

---

### `Shape.isCompound`

Whether this shape is a compound.

```swift
public var isCompound: Bool { get }
```

- **OCCT:** `TopoDS_Shape::ShapeType` == `TopAbs_COMPOUND`.

---

### `Shape.isSolid`

Whether this shape is a solid.

```swift
public var isSolid: Bool { get }
```

- **OCCT:** `TopoDS_Shape::ShapeType` == `TopAbs_SOLID`.

---

### `Shape.isShell`

Whether this shape is a shell.

```swift
public var isShell: Bool { get }
```

---

### `Shape.isFace`

Whether this shape is a face.

```swift
public var isFace: Bool { get }
```

---

### `Shape.isEdge`

Whether this shape is an edge.

```swift
public var isEdge: Bool { get }
```

---

### `Shape.wireFromEdges(_:)`

Create a wire from an array of edge shapes.

```swift
public static func wireFromEdges(_ edges: [Shape]) -> Shape?
```

- **Parameters:** `edges` — array of edge shapes to connect.
- **Returns:** A connected wire, or `nil` if the edges cannot be connected.
- **OCCT:** `BRepBuilderAPI_MakeWire` (via `OCCTMakeWireFromEdges`).
- **Example:**
  ```swift
  let e1 = Shape.edgeFromLine(from: .zero, to: SIMD3(10, 0, 0))!
  let e2 = Shape.edgeFromLine(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 0))!
  if let wire = Shape.wireFromEdges([e1, e2]) {
      print(wire.isValid)
  }
  ```

---

### `Shape.shellFromFaces(_:)`

Create a shell from an array of face shapes.

```swift
public static func shellFromFaces(_ faces: [Shape]) -> Shape?
```

- **Parameters:** `faces` — face shapes to assemble into a shell.
- **Returns:** A shell, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_Sewing` or `TopoDS_Builder` (via `OCCTMakeShell`).

---

### `Shape.checkFaceStatus(face:)`

Check the validity status of a face within this shape.

```swift
public func checkFaceStatus(face: Shape) -> Int
```

- **Returns:** A `BRepCheck_Status` integer; `0` = `NoError`.
- **OCCT:** `BRepCheck_Analyzer` → `BRepCheck_Face::Status` (via `OCCTCheckFaceStatus`).

---

### `Shape.checkEdgeStatus(edge:)`

Check the validity status of an edge within this shape.

```swift
public func checkEdgeStatus(edge: Shape) -> Int
```

- **Returns:** A `BRepCheck_Status` integer; `0` = `NoError`.
- **OCCT:** `BRepCheck_Analyzer` → `BRepCheck_Edge::Status`.

---

### `Shape.checkVertexStatus(vertex:)`

Check the validity status of a vertex within this shape.

```swift
public func checkVertexStatus(vertex: Shape) -> Int
```

- **Returns:** A `BRepCheck_Status` integer; `0` = `NoError`.
- **OCCT:** `BRepCheck_Analyzer` → `BRepCheck_Vertex::Status`.

---

### `Shape.maxTolerance(type:)`

Get the maximum tolerance of sub-shapes of the given type.

```swift
public func maxTolerance(type: Int) -> Double
```

- **Parameters:** `type` — `0` = vertex, `1` = edge, `2` = face.
- **OCCT:** `ShapeAnalysis_ShapeTolerance::Tolerance` with `Standard_True` (max).

---

### `Shape.minTolerance(type:)`

Get the minimum tolerance of sub-shapes of the given type.

```swift
public func minTolerance(type: Int) -> Double
```

- **Parameters:** `type` — `0` = vertex, `1` = edge, `2` = face.
- **OCCT:** `ShapeAnalysis_ShapeTolerance::Tolerance` with `Standard_False` (min).

---

### `Shape.avgTolerance(type:)`

Get the average tolerance of sub-shapes of the given type.

```swift
public func avgTolerance(type: Int) -> Double
```

- **Parameters:** `type` — `0` = vertex, `1` = edge, `2` = face.
- **OCCT:** `ShapeAnalysis_ShapeTolerance::Tolerance` with `0` (average mode).

---

### `Shape.fixTolerance(_:)`

Fix the tolerance on all sub-shapes of this shape to a specific value.

```swift
@discardableResult
public func fixTolerance(_ tolerance: Double) -> Bool
```

- **Parameters:** `tolerance` — target tolerance value.
- **Returns:** `true` if the operation succeeded.
- **OCCT:** `ShapeFix_ShapeTolerance::SetTolerance` (via `OCCTShapeFixTolerance`).

---

### `Shape.limitMaxTolerance(_:)`

Limit the maximum tolerance on all sub-shapes to the given value.

```swift
@discardableResult
public func limitMaxTolerance(_ maxTol: Double) -> Bool
```

- **Parameters:** `maxTol` — maximum allowed tolerance.
- **Returns:** `true` if the limit was applied.
- **OCCT:** `ShapeFix_ShapeTolerance::LimitTolerance` (via `OCCTShapeLimitMaxTolerance`).
- **Example:**
  ```swift
  if let shape = Shape.box(width: 10, height: 10, depth: 10) {
      _ = shape.limitMaxTolerance(1e-4)
      print("max vertex tol:", shape.maxTolerance(type: 0))
  }
  ```

---

### `Curve3D.curveType`

The geometric curve type integer.

```swift
public var curveType: Int { get }
```

Returns: `0` = Line, `1` = Circle, `2` = Ellipse, `3` = Hyperbola, `4` = Parabola, `5` = BezierCurve, `6` = BSplineCurve, `7` = Other.

- **OCCT:** `Geom_Curve` dynamic type check (via `OCCTCurve3DCurveType`).

---

### `Curve3D.parameterAtPoint(_:)`

Find the curve parameter nearest to a 3D point.

```swift
public func parameterAtPoint(_ point: SIMD3<Double>) -> Double
```

- **Parameters:** `point` — the 3D query point.
- **Returns:** The nearest parameter `u` on the curve.
- **OCCT:** `GeomAPI_ProjectPointOnCurve` (via `OCCTCurve3DParameterAtPoint`).

---

### `Curve2D.curveType`

The geometric 2D curve type integer.

```swift
public var curveType: Int { get }
```

Returns same codes as `Curve3D.curveType` but for `Geom2d_Curve`.

- **OCCT:** `Geom2d_Curve` dynamic type (via `OCCTCurve2DCurveType`).

---

### `Curve2D.parameterAtPoint(_:)`

Find the 2D curve parameter nearest to a 2D point.

```swift
public func parameterAtPoint(_ point: SIMD2<Double>) -> Double
```

- **OCCT:** `Geom2dAPI_ProjectPointOnCurve` (via `OCCTCurve2DParameterAtPoint`).

---

### `Surface.surfaceType`

The geometric surface type integer.

```swift
public var surfaceType: Int { get }
```

Returns: `0` = Plane, `1` = Cylinder, `2` = Cone, `3` = Sphere, `4` = Torus, … `10` = Other.

- **OCCT:** `Geom_Surface` dynamic type (via `OCCTSurfaceGetType`).

---

### `Curve3D.locateNearestPoint(_:initParam:tolerance:)`

Local point-on-curve search from an initial parameter guess.

```swift
public func locateNearestPoint(
    _ point: SIMD3<Double>,
    initParam: Double,
    tolerance: Double = 1e-6
) -> (parameter: Double, distance: Double)?
```

- **Parameters:**
  - `point` — the 3D query point.
  - `initParam` — starting parameter for the local search.
  - `tolerance` — convergence tolerance.
- **Returns:** `(parameter, distance)` tuple, or `nil` if the search diverges.
- **OCCT:** `Extrema_ExtPC` local mode (via `OCCTExtremaLocateOnCurve`).

---

### `Curve3D.projectPointAll(_:maxResults:)`

Global point-to-curve projection returning all extrema.

```swift
public func projectPointAll(
    _ point: SIMD3<Double>,
    maxResults: Int = 10
) -> [(parameter: Double, distance: Double)]
```

- **Parameters:**
  - `point` — the 3D query point.
  - `maxResults` — maximum number of results to return (default 10).
- **Returns:** Array of `(parameter, distance)` pairs for every extremum found.
- **OCCT:** `GeomAPI_ExtremaCurveCurve` / `Extrema_ExtPC` (via `OCCTExtremaPointCurve`).
- **Example:**
  ```swift
  if let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
      let results = circle.projectPointAll(SIMD3(3, 4, 0))
      for r in results { print("param:", r.parameter, "dist:", r.distance) }
  }
  ```

---

### `Surface.locateNearestPoint(_:initU:initV:tolerance:)`

Local point-on-surface search from an initial (u, v) guess.

```swift
public func locateNearestPoint(
    _ point: SIMD3<Double>,
    initU: Double,
    initV: Double,
    tolerance: Double = 1e-6
) -> (u: Double, v: Double, distance: Double)?
```

- **Parameters:**
  - `point` — the 3D query point.
  - `initU`, `initV` — starting UV parameters.
  - `tolerance` — convergence tolerance.
- **Returns:** `(u, v, distance)` or `nil` on failure.
- **OCCT:** `Extrema_ExtPS` local mode (via `OCCTExtremaLocateOnSurface`).

---

### `Surface.projectPointAll(_:maxResults:)`

Global point-to-surface projection returning all extrema.

```swift
public func projectPointAll(
    _ point: SIMD3<Double>,
    maxResults: Int = 10
) -> [(u: Double, v: Double, distance: Double)]
```

- **Parameters:** `point` — 3D query point; `maxResults` — upper bound on results returned.
- **Returns:** Array of `(u, v, distance)` tuples for every extremum.
- **OCCT:** `GeomAPI_ProjectPointOnSurf` (via `OCCTExtremaPointSurface`).

---

## MakeEdge Completions, ProjOnCurve/Surf, DistShapeShape, ShapeFix Wire/Face

### `Shape.edgeFromEllipse(center:normal:majorRadius:minorRadius:)`

Create a full closed ellipse edge.

```swift
public static func edgeFromEllipse(
    center: SIMD3<Double> = .zero,
    normal: SIMD3<Double> = SIMD3(0, 0, 1),
    majorRadius: Double,
    minorRadius: Double
) -> Shape?
```

- **Parameters:** `center` — ellipse centre; `normal` — plane normal; `majorRadius`, `minorRadius` — semi-axes.
- **Returns:** A closed ellipse edge, or `nil` on failure.
- **OCCT:** `BRepBuilderAPI_MakeEdge(gp_Elips)` (via `OCCTMakeEdgeFromEllipse`).
- **Example:**
  ```swift
  if let e = Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 5) {
      print(e.isValid)
  }
  ```

---

### `Shape.edgeFromEllipseArc(center:normal:majorRadius:minorRadius:u1:u2:)`

Create an ellipse arc edge between two parameter values.

```swift
public static func edgeFromEllipseArc(
    center: SIMD3<Double> = .zero,
    normal: SIMD3<Double> = SIMD3(0, 0, 1),
    majorRadius: Double,
    minorRadius: Double,
    u1: Double,
    u2: Double
) -> Shape?
```

- **Parameters:** `u1`, `u2` — start and end parameter angles (radians).
- **OCCT:** `BRepBuilderAPI_MakeEdge(gp_Elips, u1, u2)` (via `OCCTMakeEdgeFromEllipseArc`).

---

### `Shape.edgeFromHyperbolaArc(center:normal:majorRadius:minorRadius:u1:u2:)`

Create a hyperbola arc edge between two parameter values.

```swift
public static func edgeFromHyperbolaArc(
    center: SIMD3<Double> = .zero,
    normal: SIMD3<Double> = SIMD3(0, 0, 1),
    majorRadius: Double,
    minorRadius: Double,
    u1: Double,
    u2: Double
) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeEdge(gp_Hypr, u1, u2)` (via `OCCTMakeEdgeFromHyperbolaArc`).

---

### `Shape.edgeFromParabolaArc(center:normal:focalLength:u1:u2:)`

Create a parabola arc edge between two parameter values.

```swift
public static func edgeFromParabolaArc(
    center: SIMD3<Double> = .zero,
    normal: SIMD3<Double> = SIMD3(0, 0, 1),
    focalLength: Double,
    u1: Double,
    u2: Double
) -> Shape?
```

- **Parameters:** `focalLength` — focal parameter of the parabola.
- **OCCT:** `BRepBuilderAPI_MakeEdge(gp_Parab, u1, u2)` (via `OCCTMakeEdgeFromParabolaArc`).

---

### `Shape.edgeFromCurve(_:)` (full domain)

Create an edge from a 3D curve over its full natural domain.

```swift
public static func edgeFromCurve(_ curve: Curve3D) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeEdge(Handle(Geom_Curve))` (via `OCCTMakeEdgeFromCurve`).

---

### `Shape.edgeFromCurve(_:u1:u2:)`

Create an edge from a 3D curve trimmed to `[u1, u2]`.

```swift
public static func edgeFromCurve(_ curve: Curve3D, u1: Double, u2: Double) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeEdge(Handle(Geom_Curve), u1, u2)` (via `OCCTMakeEdgeFromCurveParams`).
- **Example:**
  ```swift
  if let bsp = Curve3D.bspline(poles: pts, knots: ks, multiplicities: ms, degree: 3),
     let edge = Shape.edgeFromCurve(bsp, u1: 0, u2: 0.5) {
      print(edge.isValid)
  }
  ```

---

### `Shape.edgeFromCurve(_:from:to:)`

Create an edge from a 3D curve bounded by two 3D points.

```swift
public static func edgeFromCurve(
    _ curve: Curve3D,
    from p1: SIMD3<Double>,
    to p2: SIMD3<Double>
) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeEdge(Handle(Geom_Curve), P1, P2)` (via `OCCTMakeEdgeFromCurvePoints`).

---

### `Shape.edgeOnSurface(pcurve:surface:)`

Create an edge from a 2D parametric curve on a surface (full domain).

```swift
public static func edgeOnSurface(pcurve: Curve2D, surface: Surface) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeEdge(Handle(Geom2d_Curve), Handle(Geom_Surface))` (via `OCCTMakeEdgeOnSurface`).

---

### `Shape.edgeOnSurface(pcurve:surface:u1:u2:)`

Create an edge from a 2D parametric curve on a surface trimmed to `[u1, u2]`.

```swift
public static func edgeOnSurface(
    pcurve: Curve2D,
    surface: Surface,
    u1: Double,
    u2: Double
) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeEdge(Handle(Geom2d_Curve), Handle(Geom_Surface), u1, u2)` (via `OCCTMakeEdgeOnSurfaceParams`).

---

### `Shape.edgeVertex1()`

Get the first vertex point of an edge shape.

```swift
public func edgeVertex1() -> SIMD3<Double>
```

- **Returns:** The start vertex position. Returns `SIMD3.zero` if this shape is not an edge.
- **OCCT:** `BRep_Tool::Pnt` on `TopExp::FirstVertex` (via `OCCTEdgeVertex1`).

---

### `Shape.edgeVertex2()`

Get the last vertex point of an edge shape.

```swift
public func edgeVertex2() -> SIMD3<Double>
```

- **OCCT:** `BRep_Tool::Pnt` on `TopExp::LastVertex` (via `OCCTEdgeVertex2`).

---

### `Shape.face(from:uBounds:vBounds:tolerance:)`

Create a face from a surface with explicit UV bounds and tolerance.

```swift
public static func face(
    from surface: Surface,
    uBounds: ClosedRange<Double>,
    vBounds: ClosedRange<Double>,
    tolerance: Double = 1e-6
) -> Shape?
```

- **Parameters:** `surface` — the underlying surface; `uBounds`, `vBounds` — parameter ranges; `tolerance` — construction tolerance.
- **OCCT:** `BRepBuilderAPI_MakeFace(surface, u1, u2, v1, v2, tol)` (via `OCCTMakeFaceFromSurfaceUV`).

---

### `Shape.faceFromPlane(origin:normal:uBounds:vBounds:)`

Create a planar face from a `gp_Plane` with UV bounds.

```swift
public static func faceFromPlane(
    origin: SIMD3<Double> = .zero,
    normal: SIMD3<Double> = SIMD3(0, 0, 1),
    uBounds: ClosedRange<Double>,
    vBounds: ClosedRange<Double>
) -> Shape?
```

- **OCCT:** `BRepBuilderAPI_MakeFace(gp_Pln, u1, u2, v1, v2)` (via `OCCTMakeFaceFromGpPlane`).
- **Example:**
  ```swift
  if let face = Shape.faceFromPlane(uBounds: -5...5, vBounds: -5...5) {
      print(face.isFace)  // true
  }
  ```

---

### `Shape.faceFromCylinder(origin:axis:radius:uBounds:vBounds:)`

Create a cylindrical face from a `gp_Cylinder` with UV bounds.

```swift
public static func faceFromCylinder(
    origin: SIMD3<Double> = .zero,
    axis: SIMD3<Double> = SIMD3(0, 0, 1),
    radius: Double,
    uBounds: ClosedRange<Double>,
    vBounds: ClosedRange<Double>
) -> Shape?
```

- **Parameters:** `radius` — cylinder radius; `uBounds` — angular range (radians); `vBounds` — axial height range.
- **OCCT:** `BRepBuilderAPI_MakeFace(gp_Cylinder, u1, u2, v1, v2)` (via `OCCTMakeFaceFromGpCylinder`).

---

### `ProjectionOnCurve`

Multi-result projection of a 3D point onto a 3D curve, wrapping `GeomAPI_ProjectPointOnCurve`.

```swift
public final class ProjectionOnCurve: @unchecked Sendable
```

---

### `ProjectionOnCurve.init(curve:point:)`

Compute projections of a point onto a curve.

```swift
public init?(curve: Curve3D, point: SIMD3<Double>)
```

- **Parameters:** `curve` — the target curve; `point` — the 3D point to project.
- **Returns:** The projection object, or `nil` on failure.
- **OCCT:** `GeomAPI_ProjectPointOnCurve` (via `OCCTProjOnCurveCreate`).

---

### `ProjectionOnCurve.count`

Number of projection results.

```swift
public var count: Int { get }
```

- **OCCT:** `GeomAPI_ProjectPointOnCurve::NbPoints`.

---

### `ProjectionOnCurve.point(at:)`

Get the `i`-th projected point (0-based).

```swift
public func point(at index: Int) -> SIMD3<Double>
```

- **OCCT:** `GeomAPI_ProjectPointOnCurve::Point` (1-based internally).

---

### `ProjectionOnCurve.parameter(at:)`

Get the curve parameter of the `i`-th projection (0-based).

```swift
public func parameter(at index: Int) -> Double
```

- **OCCT:** `GeomAPI_ProjectPointOnCurve::Parameter`.

---

### `ProjectionOnCurve.distance(at:)`

Get the distance from the query point to the `i`-th projection (0-based).

```swift
public func distance(at index: Int) -> Double
```

- **OCCT:** `GeomAPI_ProjectPointOnCurve::Distance`.

---

### `ProjectionOnCurve.lowerDistance`

Minimum distance across all projection results.

```swift
public var lowerDistance: Double { get }
```

- **OCCT:** `GeomAPI_ProjectPointOnCurve::LowerDistance`.

---

### `ProjectionOnCurve.lowerParameter`

Curve parameter of the nearest projection.

```swift
public var lowerParameter: Double { get }
```

- **OCCT:** `GeomAPI_ProjectPointOnCurve::LowerDistanceParameter`.
- **Example:**
  ```swift
  if let circ = Curve3D.circle(center: .zero, normal: SIMD3(0,0,1), radius: 5),
     let proj = ProjectionOnCurve(curve: circ, point: SIMD3(3, 4, 0)) {
      print("nearest param:", proj.lowerParameter)
      print("nearest dist:", proj.lowerDistance)
  }
  ```

---

### `ProjectionOnSurface`

Multi-result projection of a 3D point onto a surface, wrapping `GeomAPI_ProjectPointOnSurf`.

```swift
public final class ProjectionOnSurface: @unchecked Sendable
```

---

### `ProjectionOnSurface.init(surface:point:)`

Compute projections of a point onto a surface.

```swift
public init?(surface: Surface, point: SIMD3<Double>)
```

- **OCCT:** `GeomAPI_ProjectPointOnSurf` (via `OCCTProjOnSurfCreate`).

---

### `ProjectionOnSurface.count`

Number of projection results.

```swift
public var count: Int { get }
```

---

### `ProjectionOnSurface.point(at:)`

Get the `i`-th projected point (0-based).

```swift
public func point(at index: Int) -> SIMD3<Double>
```

---

### `ProjectionOnSurface.parameters(at:)`

Get the `(u, v)` parameters of the `i`-th projection (0-based).

```swift
public func parameters(at index: Int) -> (u: Double, v: Double)
```

- **OCCT:** `GeomAPI_ProjectPointOnSurf::Parameters`.

---

### `ProjectionOnSurface.distance(at:)`

Get the distance from the query point to the `i`-th projection (0-based).

```swift
public func distance(at index: Int) -> Double
```

---

### `ProjectionOnSurface.lowerDistance`

Minimum distance across all results.

```swift
public var lowerDistance: Double { get }
```

---

### `ProjectionOnSurface.lowerParameters`

`(u, v)` of the nearest projection.

```swift
public var lowerParameters: (u: Double, v: Double) { get }
```

- **Example:**
  ```swift
  if let plane = Surface.plane(),
     let proj = ProjectionOnSurface(surface: plane, point: SIMD3(3, 4, 5)) {
      let (u, v) = proj.lowerParameters
      print("nearest UV:", u, v)
  }
  ```

---

### `DistanceSupportType`

The topology type of a distance solution support entity.

```swift
public enum DistanceSupportType: Int32, Sendable {
    case vertex = 0
    case edge   = 1
    case face   = 2
}
```

---

### `ShapeDistance`

Full multi-result shape-to-shape distance computation wrapping `BRepExtrema_DistShapeShape`.

```swift
public final class ShapeDistance: @unchecked Sendable
```

---

### `ShapeDistance.init(shape1:shape2:)`

Compute the distance between two shapes.

```swift
public init?(shape1: Shape, shape2: Shape)
```

- **Returns:** The distance object, or `nil` on failure.
- **OCCT:** `BRepExtrema_DistShapeShape` (via `OCCTDistSSCreate`).

---

### `ShapeDistance.isDone`

Whether the distance computation succeeded.

```swift
public var isDone: Bool { get }
```

---

### `ShapeDistance.value`

The minimum distance between the two shapes.

```swift
public var value: Double { get }
```

- **OCCT:** `BRepExtrema_DistShapeShape::Value`.

---

### `ShapeDistance.solutionCount`

Number of distance solutions found.

```swift
public var solutionCount: Int { get }
```

- **OCCT:** `BRepExtrema_DistShapeShape::NbSolution`.

---

### `ShapeDistance.pointOnShape1(at:)`

Get the `i`-th closest point on shape 1 (0-based).

```swift
public func pointOnShape1(at index: Int) -> SIMD3<Double>
```

- **OCCT:** `BRepExtrema_DistShapeShape::PointOnShape1` (1-based internally).

---

### `ShapeDistance.pointOnShape2(at:)`

Get the `i`-th closest point on shape 2 (0-based).

```swift
public func pointOnShape2(at index: Int) -> SIMD3<Double>
```

---

### `ShapeDistance.supportType1(at:)`

Get the support topology type on shape 1 for the `i`-th solution (0-based).

```swift
public func supportType1(at index: Int) -> DistanceSupportType?
```

---

### `ShapeDistance.supportType2(at:)`

Get the support topology type on shape 2 for the `i`-th solution (0-based).

```swift
public func supportType2(at index: Int) -> DistanceSupportType?
```

---

### `ShapeDistance.supportShape1(at:)`

Get the sub-shape on shape 1 that supports the `i`-th solution (0-based).

```swift
public func supportShape1(at index: Int) -> Shape?
```

---

### `ShapeDistance.supportShape2(at:)`

Get the sub-shape on shape 2 that supports the `i`-th solution (0-based).

```swift
public func supportShape2(at index: Int) -> Shape?
```

- **Example:**
  ```swift
  let box1 = Shape.box(width: 5, height: 5, depth: 5)!
  let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 5, height: 5, depth: 5)!
  if let dist = ShapeDistance(shape1: box1, shape2: box2), dist.isDone {
      print("min distance:", dist.value)   // 5.0
      print("p1:", dist.pointOnShape1(at: 0))
      print("p2:", dist.pointOnShape2(at: 0))
  }
  ```

---

### `WireFixer`

Individual wire repair operations using `ShapeFix_Wire`.

```swift
public final class WireFixer: @unchecked Sendable
```

---

### `WireFixer.init(wire:face:precision:)`

Create a wire fixer for a wire on a face with the given precision.

```swift
public init?(wire: Shape, face: Shape, precision: Double = 1e-6)
```

- **Parameters:** `wire` — the wire to fix; `face` — the supporting face; `precision` — working precision.
- **Returns:** The fixer, or `nil` on failure.
- **OCCT:** `ShapeFix_Wire` (via `OCCTWireFixerCreate`).

---

### `WireFixer.fixReorder()`

Fix the order of edges in the wire.

```swift
@discardableResult public func fixReorder() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixReorder`.

---

### `WireFixer.fixConnected()`

Fix connectivity gaps between consecutive edges.

```swift
@discardableResult public func fixConnected() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixConnected`.

---

### `WireFixer.fixSmall(precision:)`

Remove or collapse edges smaller than the given precision.

```swift
@discardableResult public func fixSmall(precision: Double = 1e-6) -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixSmall`.

---

### `WireFixer.fixDegenerated()`

Fix degenerated edges (e.g. collapsed to a point on a seam).

```swift
@discardableResult public func fixDegenerated() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixDegenerated`.

---

### `WireFixer.fixSelfIntersection()`

Fix self-intersecting edges in the wire.

```swift
@discardableResult public func fixSelfIntersection() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixSelfIntersection`.

---

### `WireFixer.fixLacking()`

Fix lacking (missing) edges that cause gaps.

```swift
@discardableResult public func fixLacking() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixLacking`.

---

### `WireFixer.fixClosed()`

Fix the wire closure (ensure start/end vertices coincide).

```swift
@discardableResult public func fixClosed() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixClosed`.

---

### `WireFixer.fixGaps3d()`

Fix 3D gaps between consecutive edges.

```swift
@discardableResult public func fixGaps3d() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixGaps3d`.

---

### `WireFixer.fixEdgeCurves()`

Fix the 3D and 2D curves on edges within the wire.

```swift
@discardableResult public func fixEdgeCurves() -> Bool
```

- **OCCT:** `ShapeFix_Wire::FixEdgeCurves`.

---

### `WireFixer.wire`

The resulting fixed wire.

```swift
public var wire: Shape? { get }
```

- **Returns:** The repaired wire shape, or `nil` if the fixer has not produced a valid result.
- **OCCT:** `ShapeFix_Wire::Wire`.
- **Example:**
  ```swift
  let face = Shape.faceFromPlane(uBounds: -10...10, vBounds: -10...10)!
  let wire = Wire.rectangle(width: 5, height: 5)!.asShape()
  if let fixer = WireFixer(wire: wire, face: face) {
      _ = fixer.fixReorder()
      _ = fixer.fixConnected()
      if let fixed = fixer.wire { print(fixed.isValid) }
  }
  ```

---

### `FaceFixer`

Individual face repair operations using `ShapeFix_Face`.

```swift
public final class FaceFixer: @unchecked Sendable
```

---

### `FaceFixer.init(face:precision:)`

Create a face fixer with the given precision.

```swift
public init?(face: Shape, precision: Double = 1e-6)
```

- **OCCT:** `ShapeFix_Face` (via `OCCTFaceFixerCreate`).

---

### `FaceFixer.perform()`

Perform all available face fixes in one call.

```swift
@discardableResult public func perform() -> Bool
```

- **OCCT:** `ShapeFix_Face::Perform`.

---

### `FaceFixer.fixOrientation()`

Fix the orientation of wires on the face.

```swift
@discardableResult public func fixOrientation() -> Bool
```

- **OCCT:** `ShapeFix_Face::FixOrientation`.

---

### `FaceFixer.fixAddNaturalBound()`

Add a natural boundary wire if one is missing (e.g. on a periodic surface).

```swift
@discardableResult public func fixAddNaturalBound() -> Bool
```

- **OCCT:** `ShapeFix_Face::FixAddNaturalBound`.

---

### `FaceFixer.fixMissingSeam()`

Fix a missing seam edge on a periodic surface.

```swift
@discardableResult public func fixMissingSeam() -> Bool
```

- **OCCT:** `ShapeFix_Face::FixMissingSeam`.

---

### `FaceFixer.fixSmallAreaWire()`

Remove wires whose enclosed area is negligibly small.

```swift
@discardableResult public func fixSmallAreaWire() -> Bool
```

- **OCCT:** `ShapeFix_Face::FixSmallAreaWire`.

---

### `FaceFixer.face`

The resulting fixed face.

```swift
public var face: Shape? { get }
```

- **OCCT:** `ShapeFix_Face::Face`.
- **Example:**
  ```swift
  if let fixer = FaceFixer(face: importedFace, precision: 1e-5) {
      _ = fixer.perform()
      if let fixed = fixer.face { print("fixed:", fixed.isValid) }
  }
  ```

---

### `IntCSResult`

Full multi-result curve-surface intersection using `GeomAPI_IntCS`.

```swift
public final class IntCSResult: @unchecked Sendable
```

---

### `IntCSResult.init(curve:surface:)`

Compute intersections between a 3D curve and a surface.

```swift
public init?(curve: Curve3D, surface: Surface)
```

- **OCCT:** `GeomAPI_IntCS` (via `OCCTIntCSCreate`).

---

### `IntCSResult.pointCount`

Number of intersection points.

```swift
public var pointCount: Int { get }
```

---

### `IntCSResult.segmentCount`

Number of intersection segments.

```swift
public var segmentCount: Int { get }
```

---

### `IntCSResult.IntersectionPoint`

A single curve-surface intersection result.

```swift
public struct IntersectionPoint: Sendable {
    public let point: SIMD3<Double>
    public let curveParam: Double
    public let surfaceU: Double
    public let surfaceV: Double
}
```

---

### `IntCSResult.point(at:)`

Get the `i`-th intersection point (0-based).

```swift
public func point(at index: Int) -> IntersectionPoint
```

- **OCCT:** `GeomAPI_IntCS::Point` (1-based internally).
- **Example:**
  ```swift
  if let line = Curve3D.line(origin: SIMD3(0, 0, -5), direction: SIMD3(0, 0, 1)),
     let plane = Surface.plane(),
     let result = IntCSResult(curve: line, surface: plane) {
      for i in 0..<result.pointCount {
          let ip = result.point(at: i)
          print("hit:", ip.point, "at t=", ip.curveParam)
      }
  }
  ```

---

### `Curve3D.bsplineSetKnot(index:value:)`

Set the knot value at a 1-based index on a BSpline curve.

```swift
public func bsplineSetKnot(index: Int, value: Double) -> Bool
```

- **OCCT:** `Geom_BSplineCurve::SetKnot` (via `OCCTCurve3DBSplineSetKnot`).

---

### `Curve3D.bsplineKnotSequence()`

Get the full knot sequence with multiplicities expanded.

```swift
public func bsplineKnotSequence() -> [Double]
```

- **Returns:** Up to 1024 knot values in the flat (expanded) sequence.
- **OCCT:** `Geom_BSplineCurve::KnotSequence` (via `OCCTCurve3DBSplineGetKnotSequence`).

---

### `Curve3D.bsplineWeights()`

Get all pole weights (one per control point).

```swift
public func bsplineWeights() -> [Double]
```

- **OCCT:** `Geom_BSplineCurve::Weights` (via `OCCTCurve3DBSplineGetWeights`).

---

### `Curve3D.bsplineInsertKnots(_:multiplicities:tolerance:)`

Insert multiple knots at once.

```swift
public func bsplineInsertKnots(
    _ knots: [Double],
    multiplicities: [Int],
    tolerance: Double = 1e-10
) -> Bool
```

- **Parameters:** `knots` — new knot values; `multiplicities` — insertion multiplicities; `tolerance` — parametric tolerance.
- **OCCT:** `Geom_BSplineCurve::InsertKnots` (via `OCCTCurve3DBSplineInsertKnots`).

---

### `Curve3D.bsplineMovePoint(u:to:poleRange:)`

Move the curve to pass through a new 3D point at parameter `u`, adjusting poles within `poleRange`.

```swift
public func bsplineMovePoint(
    u: Double,
    to point: SIMD3<Double>,
    poleRange: ClosedRange<Int>
) -> Bool
```

- **Parameters:** `poleRange` — 1-based inclusive range of poles allowed to move.
- **OCCT:** `Geom_BSplineCurve::MovePoint` (via `OCCTCurve3DBSplineMovePoint`).

---

### `Curve3D.bsplineLocalValue(u:fromKnot:toKnot:)`

Evaluate the curve locally within a knot span.

```swift
public func bsplineLocalValue(u: Double, fromKnot: Int, toKnot: Int) -> SIMD3<Double>
```

- **Parameters:** `fromKnot`, `toKnot` — 1-based knot span indices.
- **OCCT:** `Geom_BSplineCurve::LocalValue` (via `OCCTCurve3DBSplineLocalValue`).

---

### `Curve3D.bsplineLocalD0(u:fromKnot:toKnot:)`

Evaluate the curve point within a knot span (alias of `bsplineLocalValue`).

```swift
public func bsplineLocalD0(u: Double, fromKnot: Int, toKnot: Int) -> SIMD3<Double>
```

- **OCCT:** `Geom_BSplineCurve::LocalD0`.

---

### `Curve3D.bsplineLocalD1(u:fromKnot:toKnot:)`

Evaluate point and first derivative within a knot span.

```swift
public func bsplineLocalD1(
    u: Double,
    fromKnot: Int,
    toKnot: Int
) -> (point: SIMD3<Double>, d1: SIMD3<Double>)
```

- **OCCT:** `Geom_BSplineCurve::LocalD1`.

---

### `Curve3D.bsplineLocalD2(u:fromKnot:toKnot:)`

Evaluate point, first, and second derivatives within a knot span.

```swift
public func bsplineLocalD2(
    u: Double,
    fromKnot: Int,
    toKnot: Int
) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>)
```

- **OCCT:** `Geom_BSplineCurve::LocalD2`.

---

### `Curve3D.bsplineLocalD3(u:fromKnot:toKnot:)`

Evaluate point through third derivative within a knot span.

```swift
public func bsplineLocalD3(
    u: Double,
    fromKnot: Int,
    toKnot: Int
) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>)
```

- **OCCT:** `Geom_BSplineCurve::LocalD3`.

---

### `Curve3D.bsplineLocalDN(u:fromKnot:toKnot:n:)`

Evaluate the N-th derivative within a knot span.

```swift
public func bsplineLocalDN(
    u: Double,
    fromKnot: Int,
    toKnot: Int,
    n: Int
) -> SIMD3<Double>
```

- **OCCT:** `Geom_BSplineCurve::LocalDN`.

---

### `Curve3D.bsplineMaxDegree`

Maximum BSpline degree supported (static property).

```swift
public static var bsplineMaxDegree: Int { get }
```

- **OCCT:** `Geom_BSplineCurve::MaxDegree`.

---

### `Curve3D.bsplineLocateU(_:tolerance:)`

Locate the knot span index containing parameter `u`.

```swift
public func bsplineLocateU(_ u: Double, tolerance: Double = 1e-10) -> Int
```

- **Returns:** 1-based knot index of the span containing `u`.
- **OCCT:** `Geom_BSplineCurve::LocateU`.
- **Example:**
  ```swift
  if let bsp = Curve3D.bspline(poles: pts, knots: ks, multiplicities: ms, degree: 3) {
      let span = bsp.bsplineLocateU(0.5)
      let localPt = bsp.bsplineLocalValue(u: 0.5, fromKnot: span, toKnot: span + 1)
      print(localPt)
  }
  ```

---

### `Surface.bsplineSetUKnot(index:value:)`

Set a U knot at a 1-based index on a BSpline surface.

```swift
public func bsplineSetUKnot(index: Int, value: Double) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetUKnot`.

---

### `Surface.bsplineSetVKnot(index:value:)`

Set a V knot at a 1-based index on a BSpline surface.

```swift
public func bsplineSetVKnot(index: Int, value: Double) -> Bool
```

- **OCCT:** `Geom_BSplineSurface::SetVKnot`.

---

### `Surface.bsplineUKnots()`

Get all U knots (distinct values, without multiplicities expanded).

```swift
public func bsplineUKnots() -> [Double]
```

- **OCCT:** `Geom_BSplineSurface::UKnots`.

---

### `Surface.bsplineVKnots()`

Get all V knots (distinct values, without multiplicities expanded).

```swift
public func bsplineVKnots() -> [Double]
```

- **OCCT:** `Geom_BSplineSurface::VKnots`.

---

### `Surface.bsplineWeights()`

Get all pole weights as a row-major flat array (NbUPoles × NbVPoles).

```swift
public func bsplineWeights() -> (weights: [Double], rows: Int, cols: Int)
```

- **Returns:** `(weights, rows, cols)` where `weights.count == rows * cols`.
- **OCCT:** `Geom_BSplineSurface::Weights`.

---

### `Surface.bsplineRemoveUKnot(index:multiplicity:tolerance:)`

Remove a U knot at the given 1-based index, reducing its multiplicity.

```swift
public func bsplineRemoveUKnot(
    index: Int,
    multiplicity: Int,
    tolerance: Double
) -> Bool
```

- **Parameters:** `multiplicity` — target multiplicity after removal (0 to remove completely); `tolerance` — geometric tolerance.
- **Returns:** `true` if the knot was removed within tolerance.
- **OCCT:** `Geom_BSplineSurface::RemoveUKnot`.

---

## TopoDS Builder, ShapeContents Expanded, FreeBoundsProperties, WireBuilder

### `Shape.builderMakeWire()`

Create an empty wire via `TopoDS_Builder`.

```swift
public static func builderMakeWire() -> Shape?
```

- **OCCT:** `TopoDS_Builder::MakeWire` (via `OCCTBuilderMakeWire`).

---

### `Shape.builderMakeShell()`

Create an empty shell via `TopoDS_Builder`.

```swift
public static func builderMakeShell() -> Shape?
```

- **OCCT:** `TopoDS_Builder::MakeShell`.

---

### `Shape.builderMakeSolid()`

Create an empty solid via `TopoDS_Builder`.

```swift
public static func builderMakeSolid() -> Shape?
```

- **OCCT:** `TopoDS_Builder::MakeSolid`.

---

### `Shape.builderMakeCompound()`

Create an empty compound via `TopoDS_Builder`.

```swift
public static func builderMakeCompound() -> Shape?
```

- **OCCT:** `TopoDS_Builder::MakeCompound`.

---

### `Shape.builderMakeCompSolid()`

Create an empty comp-solid via `TopoDS_Builder`.

```swift
public static func builderMakeCompSolid() -> Shape?
```

- **OCCT:** `TopoDS_Builder::MakeCompSolid`.

---

### `Shape.builderAdd(_:)`

Add a child shape into this shape using `TopoDS_Builder`.

```swift
@discardableResult
public func builderAdd(_ child: Shape) -> Bool
```

- **Returns:** `true` if the child was added.
- **OCCT:** `TopoDS_Builder::Add`.
- **Example:**
  ```swift
  let compound = Shape.builderMakeCompound()!
  let box = Shape.box(width: 5, height: 5, depth: 5)!
  _ = compound.builderAdd(box)
  print(compound.isCompound)  // true
  ```

---

### `Shape.builderRemove(_:)`

Remove a child shape from this shape using `TopoDS_Builder`.

```swift
@discardableResult
public func builderRemove(_ child: Shape) -> Bool
```

- **Returns:** `true` if the child was removed.
- **OCCT:** `TopoDS_Builder::Remove`.

---

### `ShapeContentsExtended`

Detailed shape-contents analysis result from `ShapeAnalysis_ShapeContents`.

```swift
public struct ShapeContentsExtended: Sendable {
    public let nbSolids: Int
    public let nbShells: Int
    public let nbFaces: Int
    public let nbWires: Int
    public let nbEdges: Int
    public let nbVertices: Int
    public let nbFreeEdges: Int
    public let nbFreeWires: Int
    public let nbFreeFaces: Int
    public let nbSolidsWithVoids: Int
    public let nbBigSplines: Int
    public let nbC0Surfaces: Int
    public let nbC0Curves: Int
    public let nbOffsetSurf: Int
    public let nbIndirectSurf: Int
    public let nbOffsetCurves: Int
    public let nbTrimmedCurve2d: Int
    public let nbTrimmedCurve3d: Int
    public let nbBSplineSurf: Int
    public let nbBezierSurf: Int
    public let nbTrimSurf: Int
    public let nbWireWithSeam: Int
    public let nbWireWithSevSeams: Int
    public let nbFaceWithSevWires: Int
    public let nbNoPCurve: Int
    public let nbSharedSolids: Int
    public let nbSharedShells: Int
    public let nbSharedFaces: Int
    public let nbSharedWires: Int
    public let nbSharedEdges: Int
    public let nbSharedVertices: Int
}
```

---

### `Shape.contentsExtended()`

Get extended shape-contents analysis with 31 topology and geometry counters.

```swift
public func contentsExtended() -> ShapeContentsExtended
```

- **OCCT:** `ShapeAnalysis_ShapeContents` (via `OCCTShapeGetContentsExtended`).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let c = box.contentsExtended()
  print("faces:", c.nbFaces, "edges:", c.nbEdges)
  print("B-spline surfaces:", c.nbBSplineSurf)
  ```

---

### `FreeBoundsProperties`

Persistent free-bounds analysis wrapping `ShapeAnalysis_FreeBoundsProperties`.

```swift
public final class FreeBoundsProperties: @unchecked Sendable
```

Computes area, perimeter, ratio, and width for each free (open and closed) boundary loop in a shape.

---

### `FreeBoundsProperties.init(shape:tolerance:)`

Create a free-bounds properties analyser.

```swift
public init?(shape: Shape, tolerance: Double = 1e-7)
```

- **Returns:** The analyser, or `nil` on failure.
- **OCCT:** `ShapeAnalysis_FreeBoundsProperties` (via `OCCTFreeBoundsPropsCreate`).

---

### `FreeBoundsProperties.perform()`

Perform the analysis.

```swift
@discardableResult
public func perform() -> Bool
```

- **OCCT:** `ShapeAnalysis_FreeBoundsProperties::Perform`.

---

### `FreeBoundsProperties.closedCount`

Number of closed free bounds found.

```swift
public var closedCount: Int { get }
```

---

### `FreeBoundsProperties.openCount`

Number of open free bounds found.

```swift
public var openCount: Int { get }
```

---

### `FreeBoundsProperties.closedArea(at:)`

Area enclosed by the `i`-th closed free bound (0-based).

```swift
public func closedArea(at index: Int) -> Double
```

---

### `FreeBoundsProperties.closedPerimeter(at:)`

Perimeter of the `i`-th closed free bound (0-based).

```swift
public func closedPerimeter(at index: Int) -> Double
```

---

### `FreeBoundsProperties.closedRatio(at:)`

Length-to-width ratio of the `i`-th closed free bound (0-based).

```swift
public func closedRatio(at index: Int) -> Double
```

---

### `FreeBoundsProperties.closedWidth(at:)`

Width of the `i`-th closed free bound (0-based).

```swift
public func closedWidth(at index: Int) -> Double
```

---

### `FreeBoundsProperties.closedWire(at:)`

Wire shape for the `i`-th closed free bound (0-based).

```swift
public func closedWire(at index: Int) -> Shape?
```

---

### `FreeBoundsProperties.openArea(at:)`

Swept area of the `i`-th open free bound (0-based).

```swift
public func openArea(at index: Int) -> Double
```

---

### `FreeBoundsProperties.openPerimeter(at:)`

Length of the `i`-th open free bound (0-based).

```swift
public func openPerimeter(at index: Int) -> Double
```

---

### `FreeBoundsProperties.openWire(at:)`

Wire shape for the `i`-th open free bound (0-based).

```swift
public func openWire(at index: Int) -> Shape?
```

- **Example:**
  ```swift
  let shell = Shape.box(width: 10, height: 10, depth: 10)!  // closed — 0 free bounds
  if let fp = FreeBoundsProperties(shape: shell) {
      _ = fp.perform()
      print("closed:", fp.closedCount, "open:", fp.openCount)
  }
  ```

---

### `WireBuilder`

Incremental wire builder wrapping `BRepBuilderAPI_MakeWire`.

```swift
public final class WireBuilder: @unchecked Sendable
```

Unlike `Shape.wireFromEdges(_:)`, `WireBuilder` lets you add edges one-by-one and inspect the error state before retrieving the result.

---

### `WireBuilder.init()`

Create an empty wire builder.

```swift
public init()
```

- **OCCT:** `BRepBuilderAPI_MakeWire()` (via `OCCTWireBuilderCreate`).

---

### `WireBuilder.addEdge(_:)`

Add an edge to the wire being built.

```swift
public func addEdge(_ edge: Shape)
```

- **OCCT:** `BRepBuilderAPI_MakeWire::Add(TopoDS_Edge)`.

---

### `WireBuilder.addWire(_:)`

Add a wire (all its edges) to the wire being built.

```swift
public func addWire(_ wire: Shape)
```

- **OCCT:** `BRepBuilderAPI_MakeWire::Add(TopoDS_Wire)`.

---

### `WireBuilder.wire`

The resulting wire.

```swift
public var wire: Shape? { get }
```

- **Returns:** The built wire, or `nil` if the builder is not done or failed.
- **OCCT:** `BRepBuilderAPI_MakeWire::Wire`.

---

### `WireBuilder.isDone`

Whether the builder has produced a valid wire.

```swift
public var isDone: Bool { get }
```

---

### `WireBuilder.WireError`

Error status from the wire builder.

```swift
public enum WireError: Int32, Sendable {
    case wireDone        = 0
    case emptyWire       = 1
    case disconnectedWire = 2
    case nonManifoldWire  = 3
}
```

---

### `WireBuilder.error`

Get the current error status.

```swift
public var error: WireError { get }
```

- **OCCT:** `BRepBuilderAPI_MakeWire::Error`.
- **Example:**
  ```swift
  let builder = WireBuilder()
  builder.addEdge(Shape.edgeFromLine(from: .zero, to: SIMD3(5, 0, 0))!)
  builder.addEdge(Shape.edgeFromLine(from: SIMD3(5, 0, 0), to: SIMD3(5, 5, 0))!)
  if builder.isDone, let wire = builder.wire {
      print("built wire with", wire.edges().count, "edges")
  } else {
      print("error:", builder.error)
  }
  ```

---

### `Shape.fused(with:tolerance:)`

Fuse two shapes using a fuzzy Boolean tolerance.

```swift
public func fused(with other: Shape, tolerance: Double) -> Shape?
```

- **Parameters:** `tolerance` — fuzzy tolerance for coincident geometry detection.
- **OCCT:** `BRepAlgoAPI_Fuse` with `SetFuzzyValue` (via `OCCTBooleanFuseWithTolerance`).

---

### `Shape.subtracted(_:tolerance:)`

Cut another shape from this shape using a fuzzy Boolean tolerance.

```swift
public func subtracted(_ other: Shape, tolerance: Double) -> Shape?
```

- **OCCT:** `BRepAlgoAPI_Cut` with `SetFuzzyValue` (via `OCCTBooleanCutWithTolerance`).

---

### `Shape.intersected(with:tolerance:)`

Compute the Boolean common of two shapes using a fuzzy tolerance.

```swift
public func intersected(with other: Shape, tolerance: Double) -> Shape?
```

- **OCCT:** `BRepAlgoAPI_Common` with `SetFuzzyValue` (via `OCCTBooleanCommonWithTolerance`).

---

### `Shape.GlueMode`

Glue hint for Boolean operations on nearly-coincident faces.

```swift
public enum GlueMode: Int32, Sendable {
    case shift = 0   // Shift glue — one-face difference
    case full  = 1   // Full glue — all faces coincident
    case off   = 2   // No glue
}
```

---

### `Shape.fused(with:glue:)`

Fuse two shapes with a glue mode hint for better performance on coincident faces.

```swift
public func fused(with other: Shape, glue: GlueMode) -> Shape?
```

- **OCCT:** `BRepAlgoAPI_Fuse` with `SetGlue` (via `OCCTBooleanFuseGlue`).

---

### `Shape.subtracted(_:glue:)`

Cut another shape with a glue mode hint.

```swift
public func subtracted(_ other: Shape, glue: GlueMode) -> Shape?
```

- **OCCT:** `BRepAlgoAPI_Cut` with `SetGlue` (via `OCCTBooleanCutGlue`).

---

### `Shape.intersected(with:glue:)`

Compute the Boolean common with a glue mode hint.

```swift
public func intersected(with other: Shape, glue: GlueMode) -> Shape?
```

- **OCCT:** `BRepAlgoAPI_Common` with `SetGlue` (via `OCCTBooleanCommonGlue`).
- **Example:**
  ```swift
  let a = Shape.box(width: 10, height: 10, depth: 10)!
  let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)!
  if let result = a.fused(with: b, glue: .shift) {
      print(result.isValid)
  }
  ```

---

### `Shape.OffsetJoinType`

Join type for wire and face offset operations.

```swift
public enum OffsetJoinType: Int32, Sendable {
    case arc          = 0   // Arcs at corners
    case tangent      = 1   // Tangent extensions
    case intersection = 2   // Intersection of extended edges
}
```

---

### `Shape.offsetWireOnPlane(distance:joinType:)`

Offset a planar wire by the given distance on its containing plane.

```swift
public func offsetWireOnPlane(
    distance: Double,
    joinType: OffsetJoinType = .arc
) -> Shape?
```

- **Parameters:** `distance` — signed offset distance (positive = outward); `joinType` — corner handling.
- **OCCT:** `BRepOffsetAPI_MakeOffset` (via `OCCTOffsetWireOnPlane`).
- **Example:**
  ```swift
  if let rect = Wire.rectangle(width: 10, height: 5)?.asShape(),
     let offsetWire = rect.offsetWireOnPlane(distance: 2) {
      print(offsetWire.isValid)
  }
  ```

---

### `Shape.offsetFace(distance:joinType:)`

Offset a face by the given distance.

```swift
public func offsetFace(
    distance: Double,
    joinType: OffsetJoinType = .arc
) -> Shape?
```

- **OCCT:** `BRepOffsetAPI_MakeOffset` on a face (via `OCCTOffsetFace`).

---

### `Shape.thickSolid(facesToRemove:offset:tolerance:joinType:)`

Create a thick solid by removing specified faces and offsetting the remainder.

```swift
public func thickSolid(
    facesToRemove: [Shape],
    offset: Double,
    tolerance: Double = 1e-3,
    joinType: OffsetJoinType = .arc
) -> Shape?
```

- **Parameters:**
  - `facesToRemove` — faces to open (remove from the shell before offsetting).
  - `offset` — wall thickness (signed; positive = outward).
  - `tolerance` — Boolean tolerance.
  - `joinType` — corner type.
- **OCCT:** `BRepOffsetAPI_MakeThickSolid` (via `OCCTThickSolidWithOptions`).
- **Example:**
  ```swift
  let box = Shape.box(width: 20, height: 20, depth: 20)!
  let topFace = box.faces().max(by: { $0.area < $1.area })!
  if let hollow = box.thickSolid(facesToRemove: [topFace], offset: -2) {
      print(hollow.isValid)
  }
  ```

---

### `Shape.orientClosedSolid()`

Orient a closed solid so that face normals point consistently outward.

```swift
@discardableResult
public func orientClosedSolid() -> Bool
```

- **Returns:** `true` if the orientation was fixed.
- **OCCT:** `BRepLib::OrientClosedSolid` (via `OCCTBRepLibOrientClosedSolid`).

---

### `Shape.buildCurves3d(tolerance:)`

Build 3D curves for all edges in the shape that lack them.

```swift
@discardableResult
public func buildCurves3d(tolerance: Double = 1e-7) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `BRepLib::BuildCurves3d` (via `OCCTBRepLibBuildCurves3dForShape`).

---

### `Shape.sortedFaces()`

Get the faces sorted by decreasing area.

```swift
public func sortedFaces() -> Shape?
```

- **Returns:** A compound containing the faces in order from largest to smallest, or `nil` on failure.
- **OCCT:** `BRepLib::SortFaces` (via `OCCTBRepLibSortFaces`).

---

### `Shape.reverseSortedFaces()`

Get the faces sorted by increasing area.

```swift
public func reverseSortedFaces() -> Shape?
```

- **OCCT:** `BRepLib::ReverseSortFaces` (via `OCCTBRepLibReverseSortFaces`).

---

### `Shape.LinearProperties`

Linear properties result for edge/wire shapes.

```swift
public struct LinearProperties: Sendable {
    public let length: Double
    public let centerOfMass: SIMD3<Double>
}
```

---

### `Shape.linearProperties()`

Get linear properties (total length and center of mass) for an edge or wire shape.

```swift
public func linearProperties() -> LinearProperties
```

- **OCCT:** `GProp_GProps` linear analysis (via `OCCTShapeLinearProperties`).
- **Example:**
  ```swift
  let wire = Wire.rectangle(width: 10, height: 5)!.asShape()
  let lp = wire.linearProperties()
  print("length:", lp.length)              // 30.0
  print("centroid:", lp.centerOfMass)
  ```

---

### `Shape.InertiaTensor`

Inertia tensor components for a volumetric shape.

```swift
public struct InertiaTensor: Sendable {
    public let ixx: Double, iyy: Double, izz: Double
    public let ixy: Double, ixz: Double, iyz: Double
}
```

---

### `Shape.momentOfInertia()`

Get the inertia tensor for a volumetric shape about the world origin.

```swift
public func momentOfInertia() -> InertiaTensor
```

- **OCCT:** `GProp_GProps` volumetric analysis, `BRepGProp_MatrixOfInertia` (via `OCCTShapeMomentOfInertia`).

---

### `Shape.PrincipalAxes`

Three orthogonal principal inertia axis directions.

```swift
public struct PrincipalAxes: Sendable {
    public let axis1: SIMD3<Double>
    public let axis2: SIMD3<Double>
    public let axis3: SIMD3<Double>
}
```

---

### `Shape.principalAxes()`

Get the three principal axes of inertia.

```swift
public func principalAxes() -> PrincipalAxes
```

- **OCCT:** `GProp_GProps::PrincipalProperties` (via `OCCTShapePrincipalAxes`).

---

### `Shape.radiusOfGyration(axisOrigin:direction:)`

Get the radius of gyration about an arbitrary axis.

```swift
public func radiusOfGyration(
    axisOrigin: SIMD3<Double>,
    direction: SIMD3<Double>
) -> Double
```

- **Parameters:** `axisOrigin` — a point on the axis; `direction` — axis direction vector.
- **OCCT:** `GProp_GProps::RadiusOfGyration` (via `OCCTShapeRadiusOfGyration`).

---

### `Curve3D.isBounded`

Whether this curve is a bounded curve (`Geom_BoundedCurve` subclass).

```swift
public var isBounded: Bool { get }
```

- **OCCT:** dynamic type check against `Geom_BoundedCurve`.

---

### `Curve2D.isBounded`

Whether this 2D curve is bounded (`Geom2d_BoundedCurve` subclass).

```swift
public var isBounded: Bool { get }
```

---

### `Color.namedColorCount`

The total number of named OCCT colours available.

```swift
public static var namedColorCount: Int { get }
```

- **OCCT:** `Quantity_Color` named-colour registry (via `OCCTNamedColorCount`).

---

### `Shape.edgeCurveWithParams()`

Get the 3D geometric curve from an edge with its first and last parameters.

```swift
public func edgeCurveWithParams() -> (curve: Curve3D, first: Double, last: Double)?
```

- **Returns:** A tuple `(curve, first, last)`, or `nil` if this shape is not an edge or has no 3D curve.
- **OCCT:** `BRep_Tool::Curve` (via `OCCTShapeEdgeCurve`).
- **Example:**
  ```swift
  for edge in box.edges() {
      if let (c, t0, t1) = edge.edgeCurveWithParams() {
          let midpoint = c.point(at: (t0 + t1) / 2)
          print(midpoint)
      }
  }
  ```

---

### `Shape.faceSurfaceGeom()`

Get the underlying geometric surface from a face shape.

```swift
public func faceSurfaceGeom() -> Surface?
```

- **Returns:** The `Surface`, or `nil` if this shape is not a face.
- **OCCT:** `BRep_Tool::Surface` (via `OCCTShapeFaceSurface`).

---

### `Shape.isClosedShape`

Whether this shape (wire or shell) is closed.

```swift
public var isClosedShape: Bool { get }
```

- **OCCT:** `BRep_Tool::IsClosed` (via `OCCTShapeIsClosed`).

---

### `Shape.uniqueEdgeCount`

Number of unique (topologically distinct) edges in this shape.

```swift
public var uniqueEdgeCount: Int { get }
```

- **OCCT:** `TopExp_Explorer` with `TopAbs_EDGE`, deduplicated (via `OCCTShapeUniqueEdgeCount`).

---

### `Shape.uniqueFaceCount`

Number of unique faces in this shape.

```swift
public var uniqueFaceCount: Int { get }
```

---

### `Shape.uniqueVertexCount`

Number of unique vertices in this shape.

```swift
public var uniqueVertexCount: Int { get }
```

---

### `Shape.uniqueSubShapeCount(ofType:)`

Count unique sub-shapes of a specific topology type.

```swift
public func uniqueSubShapeCount(ofType type: ShapeType) -> Int
```

- **Parameters:** `type` — the `ShapeType` to count.
- **OCCT:** `TopExp_Explorer` deduplicated (via `OCCTShapeUniqueSubShapeCount`).

---

### `Shape.emptyCopied()`

Create an empty copy of this shape (same `TShape` type, no sub-shapes).

```swift
public func emptyCopied() -> Shape?
```

- **Returns:** An empty shape of the same topology type.
- **OCCT:** `TopoDS_Shape::EmptyCopied` (via `OCCTShapeEmptyCopied`).

---

### `Curve3D.dn(at:order:)`

Evaluate the N-th derivative at parameter `u`.

```swift
public func dn(at u: Double, order n: Int) -> SIMD3<Double>
```

- **Parameters:** `n` — derivative order (1 = tangent, 2 = curvature vector, …).
- **OCCT:** `Geom_Curve::DN` (via `OCCTCurve3DDN`).

---

### `Curve3D.typeName`

The runtime OCCT class name of this curve (e.g. `"Geom_Line"`, `"Geom_BSplineCurve"`).

```swift
public var typeName: String? { get }
```

- **OCCT:** `Standard_Type::Name` on the curve's dynamic type (via `OCCTCurve3DTypeName`).

---

### `Curve2D.dn(at:order:)`

Evaluate the N-th derivative at parameter `u` for a 2D curve.

```swift
public func dn(at u: Double, order n: Int) -> SIMD2<Double>
```

- **OCCT:** `Geom2d_Curve::DN` (via `OCCTCurve2DDN`).

---

### `Curve2D.typeName`

The runtime OCCT class name of this 2D curve (e.g. `"Geom2d_Line"`, `"Geom2d_Circle"`).

```swift
public var typeName: String? { get }
```

- **OCCT:** `Standard_Type::Name` on the 2D curve's dynamic type.

---

### `Surface.dn(u:v:nu:nv:)`

Evaluate the (Nu, Nv) mixed partial derivative at `(u, v)`.

```swift
public func dn(u: Double, v: Double, nu: Int, nv: Int) -> SIMD3<Double>
```

- **Parameters:** `nu`, `nv` — partial derivative orders with respect to U and V.
- **OCCT:** `Geom_Surface::DN` (via `OCCTSurfaceDN`).

---

### `Surface.typeName`

The runtime OCCT class name of this surface (e.g. `"Geom_Plane"`, `"Geom_BSplineSurface"`).

```swift
public var typeName: String? { get }
```

- **OCCT:** `Standard_Type::Name` on the surface's dynamic type.

---

## HelixGeom

### `Helix`

Namespace (enum) for helix curve construction using OCCT's `HelixGeom` classes.

```swift
public enum Helix
```

All members are static — `Helix` has no instances.

---

### `Helix.BuildResult`

The result of a helix build operation.

```swift
public struct BuildResult: Sendable {
    public let curve: Curve3D
    public let toleranceReached: Double
}
```

- `curve` — the resulting BSpline approximation of the helix.
- `toleranceReached` — the actual approximation error achieved.

---

### `Helix.build(origin:direction:xDirection:parameterRange:pitch:radius:taperAngle:isClockwise:tolerance:)`

Build a positioned helix curve approximated as a BSpline.

```swift
public static func build(
    origin: SIMD3<Double> = .zero,
    direction: SIMD3<Double> = SIMD3(0, 0, 1),
    xDirection: SIMD3<Double> = SIMD3(1, 0, 0),
    parameterRange: ClosedRange<Double>,
    pitch: Double,
    radius: Double,
    taperAngle: Double = 0,
    isClockwise: Bool = false,
    tolerance: Double = 0.001
) -> BuildResult?
```

- **Parameters:**
  - `origin` — centre point of the helix base.
  - `direction` — helix axis direction.
  - `xDirection` — X direction defining the angular starting position.
  - `parameterRange` — parameter domain `t1...t2` (one revolution ≈ 2π for circular cross-section).
  - `pitch` — axial advance per revolution.
  - `radius` — helix radius at the start.
  - `taperAngle` — cone half-angle in radians (`0` = constant radius).
  - `isClockwise` — `true` for left-hand helix winding.
  - `tolerance` — maximum approximation error.
- **Returns:** `BuildResult` with the BSpline curve and the achieved error, or `nil` on failure.
- **OCCT:** `HelixGeom_Helix` + `GeomAPI_PointsToBSpline` (via `OCCTHelixBuild`).
- **Example:**
  ```swift
  if let result = Helix.build(
      parameterRange: 0...(4 * .pi),
      pitch: 5,
      radius: 10
  ) {
      let curve = result.curve
      print("error:", result.toleranceReached)
      print("start:", curve.point(at: 0))
  }
  ```

---

### `Helix.buildCoil(parameterRange:pitch:radius:taperAngle:isClockwise:tolerance:)`

Build a helix coil (no explicit position or orientation — uses default axis).

```swift
public static func buildCoil(
    parameterRange: ClosedRange<Double>,
    pitch: Double,
    radius: Double,
    taperAngle: Double = 0,
    isClockwise: Bool = false,
    tolerance: Double = 0.001
) -> BuildResult?
```

- **Parameters:** Same geometric parameters as `build`, minus origin/direction (defaults to Z-axis origin).
- **Returns:** `BuildResult`, or `nil` on failure.
- **OCCT:** `HelixGeom_Helix` coil variant (via `OCCTHelixCoilBuild`).

---

### `Helix.evaluate(parameterRange:pitch:radius:taperAngle:isClockwise:at:)`

Evaluate a helix curve at a single parameter without building a BSpline.

```swift
public static func evaluate(
    parameterRange: ClosedRange<Double>,
    pitch: Double,
    radius: Double,
    taperAngle: Double = 0,
    isClockwise: Bool = false,
    at u: Double
) -> SIMD3<Double>
```

- **Parameters:** `u` — the parameter value to evaluate.
- **Returns:** The 3D point on the helix at `u`.
- **OCCT:** `HelixGeom_Helix::Value` (via `OCCTHelixCurveEval`).

---

### `Helix.evaluateD1(parameterRange:pitch:radius:taperAngle:isClockwise:at:)`

Evaluate helix position and tangent at a single parameter.

```swift
public static func evaluateD1(
    parameterRange: ClosedRange<Double>,
    pitch: Double,
    radius: Double,
    taperAngle: Double = 0,
    isClockwise: Bool = false,
    at u: Double
) -> (point: SIMD3<Double>, tangent: SIMD3<Double>)
```

- **OCCT:** `HelixGeom_Helix::D1` (via `OCCTHelixCurveD1`).

---

### `Helix.evaluateD2(parameterRange:pitch:radius:taperAngle:isClockwise:at:)`

Evaluate helix position, first, and second derivatives at a single parameter.

```swift
public static func evaluateD2(
    parameterRange: ClosedRange<Double>,
    pitch: Double,
    radius: Double,
    taperAngle: Double = 0,
    isClockwise: Bool = false,
    at u: Double
) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>)
```

- **OCCT:** `HelixGeom_Helix::D2` (via `OCCTHelixCurveD2`).

---

### `Helix.approximateToBSpline(parameterRange:pitch:radius:taperAngle:isClockwise:tolerance:)`

Directly approximate a helix to a BSpline curve and return the maximum fitting error.

```swift
public static func approximateToBSpline(
    parameterRange: ClosedRange<Double>,
    pitch: Double,
    radius: Double,
    taperAngle: Double = 0,
    isClockwise: Bool = false,
    tolerance: Double = 0.001
) -> (curve: Curve3D, maxError: Double)?
```

- **Returns:** `(curve, maxError)` or `nil` on failure. The returned BSpline is a direct approximation distinct from the helix-sampled interpolation used by `build`.
- **OCCT:** `HelixGeom_ApproxCurve` or equivalent BSpline fitting (via `OCCTHelixApproxToBSpline`).
- **Example:**
  ```swift
  if let (bsp, err) = Helix.approximateToBSpline(
      parameterRange: 0...(6 * .pi),
      pitch: 3,
      radius: 8,
      tolerance: 0.01
  ) {
      print("max error:", err)
      // Use bsp as a standard Curve3D for edge creation
      if let edge = Shape.edgeFromCurve(bsp) { print(edge.isValid) }
  }
  ```
