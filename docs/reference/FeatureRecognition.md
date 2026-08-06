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

Maps to `OCCTEdgeConvexity` from the bridge. The classification is computed by `OCCTEdgeGetConvexity` using `BRepAdaptor_Surface` surface normals and each face's own area centroid (`BRepGProp::SurfaceProperties`) at the edge midpoint: specifically, whether a point deep inside one face falls on the material or void side of the other face's tangent plane, averaged over both faces so the result cannot depend on which one the caller passed as `face1` versus `face2` (#703; an earlier formula, the sign of `(tangent × n1) · n2`, silently depended on that argument order).

`OCCTEdgeGetConvexity` (like `OCCTFacesAreAdjacent`) has no notion of which solid `face1`/`face2` belong to; it is `AAG.buildGraph()` that restricts which pairs reach it to occurrences sharing a solid (#699). Called directly on two faces from different solids the result is not meaningful for either, see `AAG`, below.

- `concave` — the two face normals "open inward"; typical of pocket walls meeting a floor.
- `smooth` — faces are tangent (within ~0.5°); typical of filleted edges.
- `convex` — the two face normals "open outward"; typical of external edges.

---

## AAGNode

A node in the Attributed Adjacency Graph, representing a single B-Rep face **occurrence** (#642).

```swift
public struct AAGNode: Sendable {
    public let faceIndex: Int
    public let distinctFaceIndex: Int
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

- `faceIndex`: this node's position in the graph, the index every `AAG` method (`neighbors(of:)`, `edge(between:and:)`, `concaveNeighbors(of:)`, `convexNeighbors(of:)`) takes and returns. An occurrence index into `Shape.orientedFaces()`, not a distinct face index.
- `distinctFaceIndex`: this occurrence's underlying face, its position in `Shape.faces()`, the deduplicated enumeration. Two nodes with the same `distinctFaceIndex` are the two sides of one face shared between two solids in a compound, same geometry, opposite orientation, opposed normals. On a shape whose faces are not shared, every node has `distinctFaceIndex == faceIndex`.

Before #642, `AAG.buildGraph()` read `Shape.faces()`, the deduplicated enumeration, so a face shared by two solids collapsed to one node carrying whichever orientation the dedup happened to keep, and `isHorizontal`/`isUpward`/`isDownward`/`isVertical`/`zLevel` (all derived from that node's normal) silently depended on compound member order. Reading `Shape.orientedFaces()` instead gives each side its own node, so the node set no longer depends on that order.

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

Attributed Adjacency Graph for feature recognition. Nodes are face occurrences (`Shape.orientedFaces()`, #642); graph edges connect pairs of adjacent occurrences **within the same solid** (#699) and carry convexity attributes.

A face shared by two solids in a compound is two nodes, one per owning solid, each carrying that solid's own normal and derived predicates. `AAG` does not build a graph edge between the two occurrences of one shared face: they are the same face, not neighbors of it. On a shape whose faces are not shared this is exactly the node set the old `Shape.faces()`-based graph produced, in the same order.

### Adjacency is scoped to one solid (#699)

Two occurrences that share a B-Rep edge but belong to different solids in a compound are adjacent *in the compound* and not adjacent in *either* solid: a floor face's candidate walls are the faces bounding the same body, not any face anywhere in the compound that happens to touch the same edge locus. Neither `OCCTFacesAreAdjacent` nor `OCCTEdgeGetConvexity` has any notion of solid membership on their own (both compare two `TopoDS_Face` values purely on their own edge geometry), so `AAG.buildGraph()` restricts which pairs it hands to them: only occurrences it can establish share a solid are compared at all.

Solid membership per occurrence is derived from the shape's own traversal order rather than a new bridge entry point: `orientedFaces()`'s underlying `TopExp_Explorer` walk visits every occurrence under one top-level solid contiguously before moving to the next, in the same first-encountered order `Shape.solids` itself enumerates solids in, so the flat occurrence list partitions into contiguous runs sized by each solid's own face-occurrence count. On a shape with zero or one solid, including every single-solid shape, there is no cross-solid pair to restrict, so nothing changes: this is a compound-only concern.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let halves = box.split(atPlane: SIMD3(4, 0, 0), normal: SIMD3(1, 0, 0))!

// Same geometry, opposite compound member order.
let orderA = Shape.compound(halves)!
let orderB = Shape.compound(halves.reversed())!

// Order-independent: cross-solid pairs never reach OCCTFacesAreAdjacent at all.
print(orderA.detectPocketsAAG().count == orderB.detectPocketsAAG().count)   // true
```

### `AAG.init(shape:)`

Constructs the AAG by traversing all face-occurrence pairs in the shape.

```swift
public init(shape: Shape)
```

Calls `buildGraph()` which reads `shape.orientedFaces()`, computes each occurrence's own area centroid once via `OCCTFaceGetAreaCentroid` (`BRepGProp::SurfaceProperties`, adaptive integration) before the pairwise loop, iterates all `(i, j)` occurrence pairs (skipping any pair that is the two sides of one shared face, and any pair `AAG` can establish belongs to two different solids, #699), tests adjacency via `OCCTFacesAreAdjacent` (backed by `TopExp::MapShapes` + `TopoDS_Edge::IsSame`), retrieves shared edges via `OCCTFaceGetSharedEdges`, and classifies each shared edge via `OCCTEdgeGetConvexity` (`BRepAdaptor_Surface` + `BRep_Tool::CurveOnSurface` + the two precomputed centroids, #703). The centroids are computed once per occurrence rather than once per adjacent pair so a face with K neighbors pays for one whole-face integration, not K (PR #720's review of #703, finding 7).

- **Parameters:** `shape` — the solid to analyse. Works best on closed solids.
- **OCCT:** `TopExp::MapShapes` / `TopoDS_Edge::IsSame` (adjacency); `BRepAdaptor_Surface` + `BRep_Tool::CurveOnSurface` + `BRepGProp::SurfaceProperties` (convexity).
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

All nodes (one per face occurrence) in the graph, in `Shape.orientedFaces()` order. A face shared between two solids contributes two nodes here (#642).

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

- **Note:** An **occurrence** index, resolving against `Shape.orientedFaces()` and **not**
  `Shape.faces()` (#642). Before #642 it indexed `faces()`; the two differ on a compound whose
  solids share a face, where indexing `faces()` with it gives the wrong face or an out-of-range
  index, silently. Read `aag.nodes[pocket.floorFaceIndex].distinctFaceIndex` for the old identity.

```swift
let aag = shape.buildAAG()
for pocket in shape.detectPocketsAAG() {
    let floor = shape.orientedFaces()[pocket.floorFaceIndex]   // correct
    let distinct = aag?.nodes[pocket.floorFaceIndex].distinctFaceIndex
    print(floor.area, distinct as Any)
}
```

---

### `wallFaceIndices`

0-based indices of the vertical faces that form the pocket walls.

```swift
public let wallFaceIndices: [Int]
```

- **Note:** **Occurrence** indices into `Shape.orientedFaces()`, on the same footing as
  `floorFaceIndex` (#642).

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

A pocket is identified when: (1) an upward-facing, horizontal, planar face exists as the floor; (2) that floor has at least one concave-edge neighbor; (3) the concave neighbors are vertical faces (walls); (4) each such wall's own bounding-box minimum Z matches the floor's Z (#724), meaning the wall must actually rest ON that floor, not merely open past it. Results are sorted by ascending `zLevel` (deepest pocket first).

Requirement (4) exists because a wall's own exterior opening can satisfy (1)-(3) too: the exterior
surface a pocket opens through is upward-facing, horizontal and planar exactly like the real floor,
and its rim edge to the wall can classify concave in the same cases a real floor's does (a curved
wall's rim commonly does, pending #723's replacement of `OCCTEdgeGetConvexity`'s formula). Without
(4), a single blind cylindrical pocket reported **two** pockets: the real floor at the bottom of
the bore, and the box's own top face at the wall's other end, for what is physically one cavity. A
floor is always the low end of the walls that rise from it; a wall's high end is where it opens,
never where it floors. This does not depend on any edge's classification being correct, only on
the floor actually sitting at the bottom of its own walls, which is a geometric fact independent of
#723.

```swift
let box  = Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20)!
let tool = Shape.cylinder(at: .zero, direction: SIMD3(0, 0, 1), radius: 4, height: 20)!
let cut  = box.subtracting(tool)!
print(cut.detectPocketsAAG().count)   // 1, not 2 (#724)
```

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
- **Note:** This is a heuristic approximation, it does not inspect the surface type. For precise cylindrical detection, check `Face.surfaceType == .cylinder`.
- **Note:** `faceIndex` is an **occurrence** index into `Shape.orientedFaces()`, not `Shape.faces()`
  (#642), matching `AAGNode.faceIndex`. A hole's face is rarely shared between two solids, so the
  two usually coincide, but only the occurrence index is correct here.
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

Convenience wrapper around `AAG(shape: self)`. The graph's nodes are face occurrences (`Shape.orientedFaces()`), not distinct faces (`Shape.faces()`): a face shared by two solids in a compound is two nodes, one per owning solid, each with that solid's own normal (#642).

- **Returns:** A fully built `AAG` for the receiver.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let aag = box.buildAAG()
  print(aag.nodes.count)   // 6, one per face, nothing shared
  ```

---

### `Shape.detectPocketsAAG()`

Detects pockets using AAG-based feature recognition.

```swift
public func detectPocketsAAG() -> [PocketFeature]
```

Equivalent to `buildAAG().detectPockets()`. Selects on each node's `isUpward`, `isHorizontal` and `isPlanar`, which `buildAAG()` derives per face occurrence, so the result no longer depends on a compound's member order (#642): before that fix, a face shared between two solids in a compound could report a different pocket count depending only on which order the solids were compounded in, for identical geometry. #699 closed a second, independent source of the same symptom: `concaveNeighbors(of:)` (which `detectPockets()` reads to find candidate walls) used to include neighbors from a *different* solid than the floor's own, which could make the result order-dependent on a fixture #642 alone did not fix (a vertical, rather than horizontal, two-solid split) and could inflate the count with a wall that was never really adjacent to that floor in either solid.

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

- **Parameters:** `index` — 1-based arc index; `maxPoints` — sample points *requested* (default 32), honoured within `2...Sampling.maximumSampleCount` (10,000,000); outside that range the result is empty (#558). The name says capacity but the contract is a request: the bridge samples the arc at exactly `maxPoints` evenly-spaced parameters and always returns that many, so an unservable count is rejected rather than clamped — clamping would hand back a coarser sampling than asked for.
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

- **Parameters:** `maxPointsPerArc` — sample points *requested* per arc (default 32), at least 2. The bound is on the total: `arcCount * maxPointsPerArc` must not exceed `Sampling.maximumSampleCount` (10,000,000), else the result is empty; `maxPointsPerArc` is checked on its own too, since a negative count on a graph with no arcs multiplies to a plausible total (#558).
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
