---
title: Feature Recognition & Medial Axis
parent: API Reference
---

# Feature Recognition & Medial Axis

`FeatureRecognition.swift` provides an Attributed Adjacency Graph (AAG) for B-Rep feature recognition — classifying faces and their shared-edge convexity to detect pockets and holes. `MedialAxis.swift` computes the Voronoi skeleton (medial axis transform) of a planar face, producing a graph of bisector arcs annotated with inscribed-circle radii for thin-wall detection and tool-path planning.

## Topics

- [EdgeConvexity](#edgeconvexity) · [AAGNode](#aagnode) · [AAGEdge](#aagedge) · [AAG](#aag) · [PocketFeature](#pocketfeature) · [Feature Recognition Extensions (AAG)](#feature-recognition-extensions-aag) · [Shape Extension — Feature Recognition](#shape-extension--feature-recognition) · [MedialAxisNode](#medialaxisnode) · [MedialAxisArc](#medialaxisarc) · [MedialAxis](#medialaxis)

---

## EdgeConvexity

Classification of the dihedral angle at a shared edge between two adjacent faces.

```swift
public enum EdgeConvexity: Int32, Sendable {
    case concave = -1   // Interior angle > 180° (pocket-like, going inward)
    case smooth = 0     // Tangent faces (~180°)
    case convex = 1     // Interior angle < 180° (fillet-like, going outward)
}
```

Maps to `OCCTEdgeConvexity` from the bridge. The classification is computed by `OCCTEdgeGetConvexity` using `BRepAdaptor_Surface` surface normals and edge tangents — specifically the sign of `(tangent × n1) · n2` at the edge midpoint.

- `concave` — the two face normals "open inward"; typical of pocket walls meeting a floor.
- `smooth` — faces are tangent (within ~0.5°); typical of filleted edges.
- `convex` — the two face normals "open outward"; typical of external edges.

---

## AAGNode

A node in the Attributed Adjacency Graph, representing a single B-Rep face with precomputed analysis results.

```swift
public struct AAGNode: Sendable {
    public let faceIndex: Int
    public let normal: SIMD3<Double>?
    public let isPlanar: Bool
    public let isHorizontal: Bool
    public let isUpward: Bool
    public let isDownward: Bool
    public let isVertical: Bool
    public let zLevel: Double?
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
}
```

All fields are populated once during `AAG.buildGraph()` by querying the corresponding `Face` properties. `normal` is `nil` for degenerate faces; `zLevel` is `nil` for non-planar or non-horizontal faces.

---

## AAGEdge

An edge in the Attributed Adjacency Graph, representing the adjacency relationship between two faces that share at least one B-Rep edge.

```swift
public struct AAGEdge: Sendable {
    public let face1Index: Int
    public let face2Index: Int
    public let convexity: EdgeConvexity
    public let sharedEdgeCount: Int
}
```

`convexity` is taken from the first shared edge between the two faces. `sharedEdgeCount` is the total number of B-Rep edges shared by the pair.

---

## AAG

Attributed Adjacency Graph for feature recognition. Nodes are faces; graph edges connect pairs of adjacent faces and carry convexity attributes.

### `AAG.init(shape:)`

Constructs the AAG by traversing all face pairs in the shape.

```swift
public init(shape: Shape)
```

Calls `buildGraph()` which iterates all `(i, j)` face pairs, tests adjacency via `OCCTFacesAreAdjacent` (backed by `TopExp::MapShapes` + `TopoDS_Edge::IsSame`), retrieves shared edges via `OCCTFaceGetSharedEdges`, and classifies each shared edge via `OCCTEdgeGetConvexity` (`BRepAdaptor_Surface` + `BRep_Tool::CurveOnSurface`).

- **Parameters:** `shape` — the solid to analyse. Works best on closed solids.
- **OCCT:** `TopExp::MapShapes` / `TopoDS_Edge::IsSame` (adjacency); `BRepAdaptor_Surface` + `BRep_Tool::CurveOnSurface` (convexity).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let aag = AAG(shape: box)
  print(aag.nodes.count)   // 6
  print(aag.edges.count)   // 12
  ```

---

### `shape`

The shape this graph was built from.

```swift
public let shape: Shape
```

---

### `nodes`

All nodes (one per face) in the graph, in face traversal order.

```swift
public private(set) var nodes: [AAGNode]
```

---

### `edges`

All adjacency edges in the graph.

```swift
public private(set) var edges: [AAGEdge]
```

---

### `adjacencyList`

Bidirectional adjacency map: `adjacencyList[faceIndex][neighborIndex]` gives the index into `edges` for that pair.

```swift
public private(set) var adjacencyList: [[Int: Int]]
```

---

### `neighbors(of:)`

Returns the face indices of all faces adjacent to the given face.

```swift
public func neighbors(of faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex` — 0-based index into `nodes`.
- **Returns:** Array of neighbor face indices; empty if `faceIndex` is out of range.
- **Example:**
  ```swift
  let aag = Shape.box(width: 10, height: 10, depth: 5)!.buildAAG()
  let neighbors = aag.neighbors(of: 0)
  // A box face has 4 adjacent neighbors
  ```

---

### `edge(between:and:)`

Returns the `AAGEdge` between two faces, if they are adjacent.

```swift
public func edge(between face1: Int, and face2: Int) -> AAGEdge?
```

- **Parameters:** `face1` — first face index; `face2` — second face index.
- **Returns:** The `AAGEdge` describing their shared boundary, or `nil` if they are not adjacent or the index is out of range.
- **Example:**
  ```swift
  if let e = aag.edge(between: 0, and: 1) {
      print(e.convexity)  // .convex for an external box edge
  }
  ```

---

### `concaveNeighbors(of:)`

Returns the face indices of all neighbors connected to this face via concave edges.

```swift
public func concaveNeighbors(of faceIndex: Int) -> [Int]
```

Pocket floors are typically surrounded by concave-edge neighbors (vertical walls). Returns empty if `faceIndex` is out of range.

- **Parameters:** `faceIndex` — 0-based face index.
- **Returns:** Indices of neighbor faces where the shared edge is classified `.concave`.
- **Example:**
  ```swift
  let pocketFloor = 2
  let walls = aag.concaveNeighbors(of: pocketFloor)
  ```

---

### `convexNeighbors(of:)`

Returns the face indices of all neighbors connected to this face via convex edges.

```swift
public func convexNeighbors(of faceIndex: Int) -> [Int]
```

- **Parameters:** `faceIndex` — 0-based face index.
- **Returns:** Indices of neighbor faces where the shared edge is classified `.convex`.

---

## PocketFeature

A recognized pocket feature detected from the AAG.

```swift
public struct PocketFeature: Sendable {
    public let floorFaceIndex: Int
    public let wallFaceIndices: [Int]
    public let zLevel: Double
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
    public let isOpen: Bool
    public var depth: Double
}
```

### `floorFaceIndex`

0-based index of the upward-facing horizontal face identified as the pocket floor.

```swift
public let floorFaceIndex: Int
```

---

### `wallFaceIndices`

0-based indices of the vertical faces that form the pocket walls.

```swift
public let wallFaceIndices: [Int]
```

---

### `zLevel`

Z coordinate of the pocket floor plane.

```swift
public let zLevel: Double
```

---

### `bounds`

Axis-aligned bounding box of the pocket (floor + walls combined).

```swift
public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
```

`bounds.min.z` equals `zLevel`; `bounds.max.z` is the height of the tallest wall.

---

### `isOpen`

Whether the pocket is considered open (fewer than 3 walls).

```swift
public let isOpen: Bool
```

A pocket with fewer than 3 wall faces does not form a closed loop and is treated as open (e.g. a slot that opens at the side of a part).

---

### `depth`

Approximate depth of the pocket: `bounds.max.z - zLevel`.

```swift
public var depth: Double
```

Pure-Swift computed property; no bridge call.

---

## Feature Recognition Extensions (AAG)

These methods extend `AAG` with higher-level feature detection.

### `AAG.detectPockets()`

Detects pocket features in the shape by AAG analysis.

```swift
public func detectPockets() -> [PocketFeature]
```

A pocket is identified when: (1) an upward-facing, horizontal, planar face exists as the floor; (2) that floor has at least one concave-edge neighbor; (3) the concave neighbors are vertical faces (walls). Results are sorted by ascending `zLevel` (deepest pocket first).

- **Returns:** Array of `PocketFeature` values, sorted deepest-first.
- **Example:**
  ```swift
  let part = Shape.box(width: 20, height: 20, depth: 10)!
  let aag = part.buildAAG()
  let pockets = aag.detectPockets()
  for p in pockets {
      print("floor \(p.floorFaceIndex), depth \(p.depth), open: \(p.isOpen)")
  }
  ```

---

### `AAG.detectHoles()`

Detects candidate hole features (cylindrical or conical faces with all-concave adjacency).

```swift
public func detectHoles() -> [(faceIndex: Int, radius: Double, depth: Double)]
```

Identifies faces where every adjacent face is connected via a concave edge and the face's XY bounding box has an aspect ratio under 1.2 (roughly circular) while being non-planar. `radius` and `depth` are estimated from the bounding box.

- **Returns:** Array of `(faceIndex, radius, depth)` tuples; `radius` is `(width + height) / 4`, `depth` is `bounds.max.z - bounds.min.z`.
- **Note:** This is a heuristic approximation — it does not inspect the surface type. For precise cylindrical detection, check `Face.surfaceType == .cylinder`.
- **Example:**
  ```swift
  let holes = aag.detectHoles()
  for h in holes {
      print("face \(h.faceIndex), r≈\(h.radius), d≈\(h.depth)")
  }
  ```

---

## Shape Extension — Feature Recognition

### `Shape.buildAAG()`

Constructs an Attributed Adjacency Graph for this shape.

```swift
public func buildAAG() -> AAG
```

Convenience wrapper around `AAG(shape: self)`.

- **Returns:** A fully built `AAG` for the receiver.
- **Example:**
  ```swift
  let aag = Shape.box(width: 10, height: 10, depth: 5)!.buildAAG()
  ```

---

### `Shape.detectPocketsAAG()`

Detects pockets using AAG-based feature recognition.

```swift
public func detectPocketsAAG() -> [PocketFeature]
```

Equivalent to `buildAAG().detectPockets()`.

- **Returns:** Array of `PocketFeature` values, sorted deepest-first.
- **Example:**
  ```swift
  let pockets = myPart.detectPocketsAAG()
  for pocket in pockets {
      print("Z=\(pocket.zLevel), depth=\(pocket.depth)")
  }
  ```

---

## MedialAxisNode

A node in the medial axis graph, representing a point on the skeleton with an associated inscribed-circle radius.

```swift
public struct MedialAxisNode: Sendable {
    public let index: Int32
    public let position: SIMD2<Double>
    public let distance: Double
    public let isPending: Bool
    public let isOnBoundary: Bool
}
```

- `index` — 1-based index within the `MAT_Graph`.
- `position` — 2D coordinates of the node in the plane of the face.
- `distance` — distance to the nearest boundary curve (inscribed-circle radius at this node). Half of local wall thickness.
- `isPending` — `true` if the node has only one linked arc (a skeleton endpoint). Wraps `MAT_Node::PendingNode`.
- `isOnBoundary` — `true` if the node lies on the shape boundary. Wraps `MAT_Node::OnBasicElt`.

---

## MedialAxisArc

An arc in the medial axis graph, connecting two nodes along a bisector curve.

```swift
public struct MedialAxisArc: Sendable {
    public let index: Int32
    public let geomIndex: Int32
    public let firstNodeIndex: Int32
    public let secondNodeIndex: Int32
    public let firstElementIndex: Int32
    public let secondElementIndex: Int32
}
```

- `index` — 1-based index within the `MAT_Graph`.
- `geomIndex` — geometry index referencing the bisector curve in the `BRepMAT2d_BisectingLocus`.
- `firstNodeIndex` / `secondNodeIndex` — 1-based indices of the endpoint nodes.
- `firstElementIndex` / `secondElementIndex` — 1-based indices of the boundary elements (input edges) the arc bisects.

---

## MedialAxis

Medial axis (Voronoi skeleton) of a planar face. Computes the locus of centers of maximal inscribed circles within a 2D profile using `BRepMAT2d_BisectingLocus`.

### `MedialAxis.init?(of:tolerance:)`

Computes the medial axis of the first planar face found in `shape`.

```swift
public init?(of shape: Shape, tolerance: Double = 1e-4)
```

Extracts the first face via `TopExp_Explorer`, runs `BRepMAT2d_Explorer::Perform` on it, then calls `BRepMAT2d_BisectingLocus::Compute` with `MAT_Left` join type and `GeomAbs_Arc` bisector type. Returns `nil` if no face is found, the computation does not complete, or the resulting graph has no arcs.

- **Parameters:** `shape` — a shape containing at least one face; `tolerance` — computation tolerance (default 1e-4).
- **Returns:** `nil` if computation fails or the shape has no faces.
- **OCCT:** `BRepMAT2d_Explorer::Perform` + `BRepMAT2d_BisectingLocus::Compute` + `MAT_Graph`.
- **Example:**
  ```swift
  let rect = Shape.makeFace(
      wire: Shape.makePolygon([
          SIMD3(0, 0, 0), SIMD3(10, 0, 0),
          SIMD3(10, 4, 0), SIMD3(0, 4, 0)
      ], closed: true)!
  )!
  if let ma = MedialAxis(of: rect) {
      print("Arcs: \(ma.arcCount), nodes: \(ma.nodeCount)")
  }
  ```

---

## Graph Counts

### `arcCount`

Number of bisector arcs in the medial axis graph.

```swift
public var arcCount: Int { get }
```

- **OCCT:** `MAT_Graph::NumberOfArcs`.

---

### `nodeCount`

Number of nodes (arc endpoints) in the medial axis graph.

```swift
public var nodeCount: Int { get }
```

- **OCCT:** `MAT_Graph::NumberOfNodes`.

---

### `basicElementCount`

Number of boundary elements (input edges) used in the computation.

```swift
public var basicElementCount: Int { get }
```

- **OCCT:** `BRepMAT2d_BisectingLocus` basic element count via `MAT_Graph`.

---

## Node Access

### `MedialAxis.node(at:)`

Returns a node by its 1-based index.

```swift
public func node(at index: Int) -> MedialAxisNode?
```

- **Parameters:** `index` — 1-based node index (1…`nodeCount`).
- **Returns:** `MedialAxisNode`, or `nil` if the index is out of range or the graph is null.
- **OCCT:** `MAT_Graph::Node` + `BRepMAT2d_BisectingLocus::GeomElt(node)`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face), let n = ma.node(at: 1) {
      print(n.position, n.distance)
  }
  ```

---

### `nodes`

All nodes in the graph.

```swift
public var nodes: [MedialAxisNode] { get }
```

Iterates 1-based indices 1…`nodeCount` via `node(at:)`.

- **Returns:** Array of all `MedialAxisNode` values; empty if the graph has no nodes.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let minDist = ma.nodes.map { $0.distance }.min() ?? 0
      print("Min inscribed radius: \(minDist)")
  }
  ```

---

## Arc Access

### `MedialAxis.arc(at:)`

Returns an arc by its 1-based index.

```swift
public func arc(at index: Int) -> MedialAxisArc?
```

- **Parameters:** `index` — 1-based arc index (1…`arcCount`).
- **Returns:** `MedialAxisArc`, or `nil` if the index is out of range or the graph is null.
- **OCCT:** `MAT_Graph::Arc`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face), let a = ma.arc(at: 1) {
      print(a.firstNodeIndex, a.secondNodeIndex)
  }
  ```

---

### `arcs`

All arcs in the graph.

```swift
public var arcs: [MedialAxisArc] { get }
```

Iterates 1-based indices 1…`arcCount` via `arc(at:)`.

- **Returns:** Array of all `MedialAxisArc` values; empty if the graph has no arcs.

---

## Distance / Thickness

### `minThickness`

Minimum inscribed circle radius across all nodes. Represents half of the minimum wall thickness.

```swift
public var minThickness: Double { get }
```

- **Returns:** Minimum `distance` value across all nodes, or `-1` if the computation fails.
- **OCCT:** `OCCTMedialAxisMinThickness` — iterates all `MAT_Node` positions, computes distance to nearest boundary curve via `Geom2dAPI_ProjectPointOnCurve`, returns the minimum.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: thinWallPart) {
      let halfThickness = ma.minThickness
      print("Min wall thickness ≈ \(halfThickness * 2)")
  }
  ```

---

### `distanceToBoundary(arcIndex:parameter:)`

Interpolated inscribed-circle radius along an arc at a given parameter.

```swift
public func distanceToBoundary(arcIndex: Int, parameter t: Double) -> Double
```

Samples a point on the arc's bisector curve at parameter `t` and computes the distance to the nearest boundary element via `Geom2dAPI_ProjectPointOnCurve`.

- **Parameters:** `arcIndex` — 1-based arc index; `t` — parameter in [0, 1] (0 = first node, 1 = second node).
- **Returns:** Inscribed circle radius at the sampled point, or `-1` on error.
- **OCCT:** `BRepMAT2d_BisectingLocus::GeomBis` + `Geom2d_TrimmedCurve::Value` + `Geom2dAPI_ProjectPointOnCurve`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let radiusMid = ma.distanceToBoundary(arcIndex: 1, parameter: 0.5)
  }
  ```

---

## Drawing

### `drawArc(at:maxPoints:)`

Samples points along a single bisector arc for visualization.

```swift
public func drawArc(at index: Int, maxPoints: Int = 32) -> [SIMD2<Double>]
```

Evaluates the arc's bisector curve (`BRepMAT2d_BisectingLocus::GeomBis`) at uniformly spaced parameters. Infinite curve parameters are clamped to ±1000.

- **Parameters:** `index` — 1-based arc index; `maxPoints` — maximum number of sample points (default 32).
- **Returns:** Array of 2D points along the arc; empty on error.
- **OCCT:** `MAT_Graph::Arc` + `BRepMAT2d_BisectingLocus::GeomBis` + `Geom2d_TrimmedCurve::Value`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let pts = ma.drawArc(at: 1, maxPoints: 20)
      for pt in pts { print(pt) }
  }
  ```

---

### `drawAll(maxPointsPerArc:)`

Samples points along all bisector arcs, returning one polyline per arc.

```swift
public func drawAll(maxPointsPerArc: Int = 32) -> [[SIMD2<Double>]]
```

Calls `OCCTMedialAxisDrawAll` which fills a flat XY buffer and per-arc start/length arrays in one pass. More efficient than calling `drawArc(at:)` in a loop.

- **Parameters:** `maxPointsPerArc` — maximum sample points per arc (default 32).
- **Returns:** Array of polylines, one per arc; empty if `arcCount == 0`.
- **OCCT:** `BRepMAT2d_BisectingLocus::GeomBis` (per arc) + `Geom2d_TrimmedCurve::Value`.
- **Example:**
  ```swift
  if let ma = MedialAxis(of: face) {
      let skeleton = ma.drawAll()
      for polyline in skeleton {
          // render each bisector arc as a 2D polyline
          print(polyline.count, "points")
      }
  }
  ```
