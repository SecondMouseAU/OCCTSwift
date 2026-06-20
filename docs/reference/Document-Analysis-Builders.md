---
title: Document — Shape Analysis, OSD & Geometry Builders
parent: API Reference
---

# Document — Shape Analysis, OSD & Geometry Builders

This page covers the shape analysis, file I/O helpers, analytic bounding, geometry property computation, transformation factories, and conic curve builders introduced across v0.99–v0.105 (lines 6351–7633 of `Document.swift`). For the core document lifecycle and STEP/IGES I/O see the main [Document](Document.md) page.

## Topics

- [OSD_File](#osd_file) · [ShapeFix_Wireframe Extensions](#shapefix_wireframe-extensions) · [RWStl / ShapeAnalysis_Curve / BRepExtrema_SelfIntersection / StepHeader / ShapeAnalysis_FreeBounds](#rwstl--shapeanalysis_curve--brepextrema_selfintersection--stepheader--shapeanalysis_freebounds) · [Geom_TrimmedCurve](#geom_trimmedcurve) · [BRepLib_FindSurface](#breplib_findsurface) · [ShapeAnalysis_Surface](#shapeanalysis_surface) · [Resource_Manager](#resource_manager) · [TopExp Adjacency](#topexp-adjacency) · [Poly_Connect Mesh Adjacency](#poly_connect-mesh-adjacency) · [BRepOffset_Analyse Edge Classification](#brepoffset_analyse-edge-classification) · [BRepTools_WireExplorer Extensions](#breptools_wireexplorer-extensions) · [BndLib Analytic Bounding](#bndlib-analytic-bounding) · [OSD_Host / PerfMeter](#osd_host--perfmeter) · [GProp Cylinder/Cone](#gprop-cylindercone) · [IntAna_IntQuadQuad](#intana_intquadquad) · [XCAFPrs_DocumentExplorer](#xcafprs_documentexplorer) · [gce Transform Factories](#gce-transform-factories) · [GProp Element Properties](#gprop-element-properties) · [Plate Constraint Extensions](#plate-constraint-extensions) · [Law_Interpolate](#law_interpolate) · [Bnd_Sphere](#bnd_sphere) · [GC_MakeCircle](#gc_makecircle) · [GC_MakeEllipse](#gc_makeellipse) · [GC_MakeHyperbola](#gc_makehyperbola) · [GC_MakeCircle2d](#gc_makecircle2d) · [GC_MakeEllipse2d](#gc_makeellipse2d) · [GC_MakeHyperbola2d](#gc_makehyperbola2d)

---

## OSD_File

`OSDFile` wraps OCCT's `OSD_File` for platform-independent sequential file I/O. Obtain an instance by path, URL, or with no arguments to create a temporary file.

### `OSDFile.init(path:)`

Create a file object for the given file-system path.

```swift
public init(path: String)
```

- **Parameters:** `path` — absolute or relative path to the file.
- **OCCT:** `OSD_File` constructor via `OCCTFileCreate`.
- **Example:**
  ```swift
  let f = OSDFile(path: "/tmp/output.txt")
  ```

---

### `OSDFile.init(url:)`

Create a file object for a URL's file path.

```swift
public init(url: URL)
```

- **Parameters:** `url` — a `file://` URL; `.path` is extracted and forwarded.
- **OCCT:** `OSD_File` constructor via `OCCTFileCreate`.
- **Example:**
  ```swift
  let f = OSDFile(url: URL(fileURLWithPath: "/tmp/output.txt"))
  ```

---

### `OSDFile.init()`

Create a temporary file (path chosen by OCCT).

```swift
public init()
```

- **OCCT:** `OSD_File` default constructor via `OCCTFileCreateTemporary`.
- **Example:**
  ```swift
  let tmp = OSDFile()
  ```

---

### `open()`

Build (create/truncate) the file and open it for reading and writing.

```swift
@discardableResult
public func open() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `OSD_File::Build` via `OCCTFileOpen`.
- **Example:**
  ```swift
  let f = OSDFile(path: "/tmp/out.txt")
  if f.open() { f.write("hello") }
  ```

---

### `openReadOnly()`

Open an existing file for reading only.

```swift
@discardableResult
public func openReadOnly() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `OSD_File::Open` (read-only mode) via `OCCTFileOpenReadOnly`.

---

### `write(_:)` (String)

Write a string to the file.

```swift
@discardableResult
public func write(_ string: String) -> Bool
```

- **Parameters:** `string` — UTF-8 text to write.
- **Returns:** `true` on success.
- **OCCT:** `OSD_File::Write` via `OCCTFileWrite`.

---

### `write(_:)` (bytes)

Write raw bytes to the file.

```swift
@discardableResult
public func write(_ bytes: [UInt8]) -> Bool
```

- **Parameters:** `bytes` — raw byte buffer to write.
- **Returns:** `true` on success.
- **OCCT:** `OSD_File::Write` via `OCCTFileWrite`.

---

### `readLine(bufSize:)`

Read one line from the file.

```swift
public func readLine(bufSize: Int = 4096) -> String?
```

- **Parameters:** `bufSize` — maximum line length to read (default 4096).
- **Returns:** The line string, or `nil` at EOF or on error.
- **OCCT:** `OSD_File::ReadLine` via `OCCTFileReadLine`.

---

### `readAll()`

Read the entire remaining content of the file as a string.

```swift
public func readAll() -> String?
```

- **Returns:** The file content as a `String`, or `nil` on error.
- **OCCT:** `OSD_File::Read` (full) via `OCCTFileReadAll`.
- **Example:**
  ```swift
  let f = OSDFile(path: "/tmp/data.txt")
  if f.openReadOnly(), let content = f.readAll() {
      print(content)
  }
  ```

---

### `close()`

Close the file.

```swift
public func close()
```

- **OCCT:** `OSD_File::Close` via `OCCTFileClose`.

---

### `isOpen`

Whether the file is currently open.

```swift
public var isOpen: Bool
```

- **OCCT:** `OSD_File::IsOpen` via `OCCTFileIsOpen`.

---

### `fileSize`

File size in bytes, or `nil` on error.

```swift
public var fileSize: Int?
```

- **Returns:** Size in bytes, or `nil` if the size could not be determined.
- **OCCT:** `OSD_File::Size` via `OCCTFileSize`.

---

### `rewind()`

Rewind the file position to the beginning.

```swift
public func rewind()
```

- **OCCT:** `OSD_File::Rewind` via `OCCTFileRewind`.

---

### `isAtEnd`

Whether the file position is at the end.

```swift
public var isAtEnd: Bool
```

- **OCCT:** `OSD_File::IsAtEnd` via `OCCTFileIsAtEnd`.

---

## ShapeFix_Wireframe Extensions

Shape-healing extensions on `Shape` for wire gap and small-edge repair, backed by `ShapeFix_Wireframe`.

### `fixWireGaps(tolerance:)`

Fix only wire gaps in the shape (no small-edge removal).

```swift
public func fixWireGaps(tolerance: Double = 1e-7) -> Shape?
```

- **Parameters:** `tolerance` — precision for gap detection (default `1e-7`).
- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeFix_Wireframe::FixWireGaps` via `OCCTShapeFixWireGaps`.
- **Example:**
  ```swift
  if let fixed = shape.fixWireGaps(tolerance: 1e-6) {
      // gaps repaired
  }
  ```

---

### `fixSmallEdges(tolerance:dropSmall:limitAngle:)`

Fix only small edges in the shape (no gap repair).

```swift
public func fixSmallEdges(tolerance: Double = 1e-7,
                           dropSmall: Bool = false,
                           limitAngle: Double = -1) -> Shape?
```

- **Parameters:**
  - `tolerance` — precision for small-edge detection (default `1e-7`).
  - `dropSmall` — if `true`, remove small edges; if `false`, merge them with neighbours.
  - `limitAngle` — maximum tangent angle for merging in radians; pass `-1` for no limit.
- **Returns:** Fixed shape, or `nil` on failure.
- **OCCT:** `ShapeFix_Wireframe::FixSmallEdges` via `OCCTShapeFixSmallEdges`.

---

## RWStl / ShapeAnalysis_Curve / BRepExtrema_SelfIntersection / StepHeader / ShapeAnalysis_FreeBounds

### `writeSTLBinary(to:deflection:)`

Write this shape's triangulation to a binary STL file. The shape is meshed automatically.

```swift
public func writeSTLBinary(to filePath: String, deflection: Double = 0.1) -> Bool
```

- **Parameters:**
  - `filePath` — output file path.
  - `deflection` — linear mesh deflection in mm for auto-triangulation (default `0.1`).
- **Returns:** `true` on success.
- **OCCT:** `RWStl::WriteBinary` via `OCCTShapeWriteSTLBinary`.

---

### `writeSTLAscii(to:deflection:)`

Write this shape's triangulation to an ASCII STL file. The shape is meshed automatically.

```swift
public func writeSTLAscii(to filePath: String, deflection: Double = 0.1) -> Bool
```

- **Parameters:**
  - `filePath` — output file path.
  - `deflection` — linear mesh deflection in mm for auto-triangulation (default `0.1`).
- **Returns:** `true` on success.
- **OCCT:** `RWStl::WriteAscii` via `OCCTShapeWriteSTLAscii`.

---

### `Shape.readSTL(from:)`

Read an STL file and return as a triangulated shape.

```swift
public static func readSTL(from filePath: String) -> Shape?
```

- **Parameters:** `filePath` — input STL file path.
- **Returns:** Shape with triangulation, or `nil` on failure.
- **OCCT:** `RWStl::ReadFile` via `OCCTShapeReadSTL`.
- **Example:**
  ```swift
  if let mesh = Shape.readSTL(from: "/tmp/model.stl") {
      print(mesh.isValid)
  }
  ```

---

### `isClosedWithPrecision(_:)`

Check if this curve is closed within the given precision.

```swift
public func isClosedWithPrecision(_ precision: Double) -> Bool
```

- **Parameters:** `precision` — tolerance for closure check.
- **Returns:** `true` if the curve endpoints coincide within `precision`.
- **OCCT:** `ShapeAnalysis_Curve::IsClosed` (static) via `OCCTCurve3DIsClosedWithPreci`.

---

### `isPeriodicSA`

Check if this curve is periodic using `ShapeAnalysis_Curve::IsPeriodic`. More robust than the basic `isPeriodic` property.

```swift
public var isPeriodicSA: Bool
```

- **OCCT:** `ShapeAnalysis_Curve::IsPeriodic` (static) via `OCCTCurve3DIsPeriodicSA`.

---

### `OverlapPair`

A pair of overlapping face indices detected by self-intersection analysis.

```swift
public struct OverlapPair: Sendable {
    public let faceIndex1: Int
    public let faceIndex2: Int
}
```

---

### `selfIntersectionPairs(tolerance:maxPairs:deflection:)`

Detect self-intersecting face pairs in this shape. The shape is meshed automatically.

```swift
public func selfIntersectionPairs(tolerance: Double = 0.0,
                                   maxPairs: Int = 100,
                                   deflection: Double = 0.1) -> [OverlapPair]
```

- **Parameters:**
  - `tolerance` — overlap tolerance (default `0.0`).
  - `maxPairs` — maximum number of pairs to return (default `100`).
  - `deflection` — linear mesh deflection in mm for detection triangulation (default `0.1`).
- **Returns:** Array of overlapping face index pairs; empty if none found.
- **OCCT:** `BRepExtrema_SelfIntersection` via `OCCTShapeSelfIntersectionPairs`.
- **Example:**
  ```swift
  let pairs = shape.selfIntersectionPairs()
  for pair in pairs {
      print("faces \(pair.faceIndex1) and \(pair.faceIndex2) overlap")
  }
  ```

---

### `offsetBasisCurve`

Get the basis curve of this offset curve.

```swift
public var offsetBasisCurve: Curve3D?
```

- **Returns:** The basis curve, or `nil` if this is not an offset curve.
- **OCCT:** `Geom_OffsetCurve::BasisCurve` via `OCCTCurve3DOffsetBasis`.

---

### `StepHeader`

A STEP file header manager for reading and writing header fields (name, timestamp, author, organization, preprocessor version, originating system).

```swift
public final class StepHeader: @unchecked Sendable
```

---

### `StepHeader.init(filename:)`

Create a STEP header with the given filename.

```swift
public init?(filename: String)
```

- **Parameters:** `filename` — the STEP file name field value.
- **Returns:** `nil` if creation fails.
- **OCCT:** `APIHeaderSection_MakeHeader` via `OCCTStepHeaderCreate`.

---

### `StepHeader.isDone`

Whether the header is fully defined.

```swift
public var isDone: Bool
```

- **OCCT:** `APIHeaderSection_MakeHeader::IsDone` via `OCCTStepHeaderIsDone`.

---

### `StepHeader.name`

The file name field.

```swift
public var name: String?
```

- **OCCT:** `APIHeaderSection_MakeHeader` get/set name fields via `OCCTStepHeaderGetName` / `OCCTStepHeaderSetName`.

---

### `StepHeader.timeStamp`

The timestamp field.

```swift
public var timeStamp: String?
```

- **OCCT:** `APIHeaderSection_MakeHeader` timestamp field via `OCCTStepHeaderGetTimeStamp` / `OCCTStepHeaderSetTimeStamp`.

---

### `StepHeader.author`

The first author field.

```swift
public var author: String?
```

- **OCCT:** `APIHeaderSection_MakeHeader` author field via `OCCTStepHeaderGetAuthor` / `OCCTStepHeaderSetAuthor`.

---

### `StepHeader.organization`

The first organization field.

```swift
public var organization: String?
```

- **OCCT:** `APIHeaderSection_MakeHeader` organization field via `OCCTStepHeaderGetOrganization` / `OCCTStepHeaderSetOrganization`.

---

### `StepHeader.preprocessorVersion`

The preprocessor version field.

```swift
public var preprocessorVersion: String?
```

- **OCCT:** `APIHeaderSection_MakeHeader` preprocessor version field via `OCCTStepHeaderGetPreprocessorVersion` / `OCCTStepHeaderSetPreprocessorVersion`.

---

### `StepHeader.originatingSystem`

The originating system field.

```swift
public var originatingSystem: String?
```

- **OCCT:** `APIHeaderSection_MakeHeader` originating system field via `OCCTStepHeaderGetOriginatingSystem` / `OCCTStepHeaderSetOriginatingSystem`.
- **Example:**
  ```swift
  if let header = StepHeader(filename: "part.stp") {
      header.author = "Alice"
      header.organization = "ACME"
      print(header.isDone)
  }
  ```

---

### `freeBoundsClosedCount(tolerance:)`

Count the number of closed free-boundary wires.

```swift
public func freeBoundsClosedCount(tolerance: Double = 1e-6) -> Int
```

- **Parameters:** `tolerance` — sewing tolerance for boundary detection (default `1e-6`).
- **Returns:** Number of closed free-boundary wires.
- **OCCT:** `ShapeAnalysis_FreeBounds` via `OCCTShapeFreeBoundsClosedCount`.

---

### `freeBoundsClosedWires(tolerance:)`

Get the compound of closed free-boundary wires.

```swift
public func freeBoundsClosedWires(tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `tolerance` — sewing tolerance for boundary detection (default `1e-6`).
- **Returns:** Compound shape of closed wires, or `nil` if none.
- **OCCT:** `ShapeAnalysis_FreeBounds` via `OCCTShapeFreeBoundsClosed`.

---

### `freeBoundsOpenWires(tolerance:)`

Get the compound of open free-boundary wires.

```swift
public func freeBoundsOpenWires(tolerance: Double = 1e-6) -> Shape?
```

- **Parameters:** `tolerance` — sewing tolerance for boundary detection (default `1e-6`).
- **Returns:** Compound shape of open wires, or `nil` if none.
- **OCCT:** `ShapeAnalysis_FreeBounds` via `OCCTShapeFreeBoundsOpen`.

---

## Geom_TrimmedCurve

Extensions on `Curve3D` for trimming operations backed by `Geom_TrimmedCurve`.

### `trimmed(u1:u2:)`

Create a trimmed curve from this curve between parameters `u1` and `u2`.

```swift
public func trimmed(u1: Double, u2: Double) -> Curve3D?
```

- **Parameters:** `u1`, `u2` — parametric start and end values.
- **Returns:** Trimmed curve, or `nil` on failure.
- **OCCT:** `Geom_TrimmedCurve` constructor via `OCCTCurve3DTrimmed`.
- **Example:**
  ```swift
  if let arc = curve.trimmed(u1: 0, u2: .pi / 2) {
      print(arc.length())
  }
  ```

---

### `trimmedBasis`

Get the basis curve of a trimmed curve (nil if not trimmed).

```swift
public var trimmedBasis: Curve3D?
```

- **Returns:** The underlying basis curve, or `nil` if this curve is not a trimmed curve.
- **OCCT:** `Geom_TrimmedCurve::BasisCurve` via `OCCTCurve3DTrimmedBasis`.

---

### `setTrim(u1:u2:)`

Change the trim parameters on a trimmed curve.

```swift
@discardableResult
public func setTrim(u1: Double, u2: Double) -> Bool
```

- **Parameters:** `u1`, `u2` — new parametric start and end values.
- **Returns:** `true` on success.
- **OCCT:** `Geom_TrimmedCurve::SetTrim` via `OCCTCurve3DSetTrim`.

---

## BRepLib_FindSurface

Extensions on `Shape` to find a best-fit surface through a shape's edges.

### `findSurface(tolerance:onlyPlane:)`

Find a surface (typically a plane) through the edges of this shape.

```swift
public func findSurface(tolerance: Double = -1, onlyPlane: Bool = false) -> Surface?
```

- **Parameters:**
  - `tolerance` — search tolerance; pass `-1` to use the shape's own tolerance.
  - `onlyPlane` — if `true`, only a plane is accepted.
- **Returns:** Best-fit surface, or `nil` if none found.
- **OCCT:** `BRepLib_FindSurface` via `OCCTFindSurface`.
- **Example:**
  ```swift
  if let plane = wire.findSurface(onlyPlane: true) {
      // wire lies on `plane`
  }
  ```

---

### `findSurfaceTolerance(tolerance:onlyPlane:)`

Return the tolerance achieved by the surface finder.

```swift
public func findSurfaceTolerance(tolerance: Double = -1, onlyPlane: Bool = false) -> Double?
```

- **Returns:** Achieved tolerance, or `nil` on failure.
- **OCCT:** `BRepLib_FindSurface::ToleranceReached` via `OCCTFindSurfaceTolerance`.

---

### `findSurfaceExisted(tolerance:onlyPlane:)`

Check if a surface already existed on the shape's edges (rather than being computed).

```swift
public func findSurfaceExisted(tolerance: Double = -1, onlyPlane: Bool = false) -> Bool
```

- **OCCT:** `BRepLib_FindSurface::Existed` via `OCCTFindSurfaceExisted`.

---

## ShapeAnalysis_Surface

Extensions on `Surface` for robust projection and singularity analysis using `ShapeAnalysis_Surface`.

### `projectPointUV(_:precision:)`

Project a 3D point onto this surface using `ShapeAnalysis_Surface`, returning UV parameters and gap.

```swift
public func projectPointUV(_ point: SIMD3<Double>, precision: Double = 1e-6) -> (u: Double, v: Double, gap: Double)
```

- **Parameters:**
  - `point` — 3D point to project.
  - `precision` — projection precision (default `1e-6`).
- **Returns:** Tuple `(u, v, gap)` where `gap` is the distance from `point` to the projected surface point.
- **OCCT:** `ShapeAnalysis_Surface::ValueOfUV` via `OCCTSurfaceProjectPointUV`.
- **Example:**
  ```swift
  let (u, v, gap) = surface.projectPointUV(SIMD3(1, 0, 0))
  ```

---

### `hasSingularitiesSA(precision:)`

Check if the surface has singularities using `ShapeAnalysis_Surface`.

```swift
public func hasSingularitiesSA(precision: Double = 1e-6) -> Bool
```

- **Parameters:** `precision` — detection precision (default `1e-6`).
- **OCCT:** `ShapeAnalysis_Surface::HasSingularities` via `OCCTSurfaceHasSingularities`.

---

### `singularityCountSA(precision:)`

Number of singularities using `ShapeAnalysis_Surface`.

```swift
public func singularityCountSA(precision: Double = 1e-6) -> Int
```

- **Parameters:** `precision` — detection precision (default `1e-6`).
- **Returns:** Count of detected singularities.
- **OCCT:** `ShapeAnalysis_Surface::NbSingularities` via `OCCTSurfaceNbSingularities`.

---

### `isUClosedSA(precision:)`

Check if the surface is spatially U-closed using `ShapeAnalysis_Surface`.

```swift
public func isUClosedSA(precision: Double = -1) -> Bool
```

- **Parameters:** `precision` — closure precision; pass `-1` to use default.
- **OCCT:** `ShapeAnalysis_Surface::IsUClosed` via `OCCTSurfaceIsUClosedSA`.

---

### `isVClosedSA(precision:)`

Check if the surface is spatially V-closed using `ShapeAnalysis_Surface`.

```swift
public func isVClosedSA(precision: Double = -1) -> Bool
```

- **Parameters:** `precision` — closure precision; pass `-1` to use default.
- **OCCT:** `ShapeAnalysis_Surface::IsVClosed` via `OCCTSurfaceIsVClosedSA`.

---

## Resource_Manager

`ResourceManager` is a lightweight key-value configuration store backed by OCCT's `Resource_Manager`.

### `ResourceManager.init()`

Create an in-memory resource manager.

```swift
public init()
```

- **OCCT:** `Resource_Manager` constructor via `OCCTResourceManagerCreate`.

---

### `setString(_:value:)`

Store a string value for the given key.

```swift
public func setString(_ key: String, value: String)
```

- **OCCT:** `Resource_Manager::SetResource` (string) via `OCCTResourceManagerSetString`.

---

### `setInt(_:value:)`

Store an integer value for the given key.

```swift
public func setInt(_ key: String, value: Int)
```

- **OCCT:** `Resource_Manager::SetResource` (integer) via `OCCTResourceManagerSetInt`.

---

### `setReal(_:value:)`

Store a floating-point value for the given key.

```swift
public func setReal(_ key: String, value: Double)
```

- **OCCT:** `Resource_Manager::SetResource` (real) via `OCCTResourceManagerSetReal`.

---

### `find(_:)`

Check whether a key exists in the resource manager.

```swift
public func find(_ key: String) -> Bool
```

- **Returns:** `true` if the key is defined.
- **OCCT:** `Resource_Manager::Find` via `OCCTResourceManagerFind`.

---

### `string(_:)`

Retrieve a string value for the given key.

```swift
public func string(_ key: String) -> String?
```

- **Returns:** The stored string, or `nil` if the key does not exist or is not a string.
- **OCCT:** `Resource_Manager::Value` (string) via `OCCTResourceManagerGetString`.

---

### `integer(_:)`

Retrieve an integer value for the given key.

```swift
public func integer(_ key: String) -> Int
```

- **Returns:** The stored integer, or `0` if the key is not found.
- **OCCT:** `Resource_Manager::IntegerValue` via `OCCTResourceManagerGetInt`.

---

### `real(_:)`

Retrieve a floating-point value for the given key.

```swift
public func real(_ key: String) -> Double
```

- **Returns:** The stored real value, or `0.0` if the key is not found.
- **OCCT:** `Resource_Manager::RealValue` via `OCCTResourceManagerGetReal`.
- **Example:**
  ```swift
  let rm = ResourceManager()
  rm.setReal("tolerance", value: 1e-6)
  print(rm.real("tolerance")) // 1e-06
  ```

---

## TopExp Adjacency

`Shape` extensions for vertex and edge adjacency queries backed by `TopExp`.

### `edgeFirstVertex()`

Get the FORWARD vertex position of an edge shape.

```swift
public func edgeFirstVertex() -> SIMD3<Double>?
```

- **Returns:** Position of the first (FORWARD) vertex, or `nil` if the shape is not an edge.
- **OCCT:** `TopExp::FirstVertex` via `OCCTEdgeFirstVertex`.

---

### `edgeLastVertex()`

Get the REVERSED vertex position of an edge shape.

```swift
public func edgeLastVertex() -> SIMD3<Double>?
```

- **Returns:** Position of the last (REVERSED) vertex, or `nil` if the shape is not an edge.
- **OCCT:** `TopExp::LastVertex` via `OCCTEdgeLastVertex`.

---

### `edgeVertices()`

Get both vertex positions of an edge shape.

```swift
public func edgeVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)?
```

- **Returns:** Tuple of first and last vertex positions, or `nil` if not an edge.
- **OCCT:** `TopExp::Vertices` via `OCCTEdgeVertices`.

---

### `wireVertices()`

Get first and last vertex positions of a wire shape. For closed wires both are the same.

```swift
public func wireVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)?
```

- **Returns:** Tuple of first and last wire vertices, or `nil` if not a wire.
- **OCCT:** `TopExp::Vertices` on wire via `OCCTWireVertices`.

---

### `commonVertex(with:)`

Find common vertex between two edge shapes.

```swift
public func commonVertex(with other: Shape) -> SIMD3<Double>?
```

- **Parameters:** `other` — the second edge shape to compare.
- **Returns:** Shared vertex position, or `nil` if no shared vertex.
- **OCCT:** `TopExp::CommonVertex` via `OCCTEdgeCommonVertex`.

---

### `edgeFaceAdjacency()`

Build edge-to-face adjacency. Returns an array where each element is the number of faces sharing that edge.

```swift
public func edgeFaceAdjacency() -> [Int]
```

- **Returns:** Array of face counts per edge (in edge iteration order); empty if no edges.
- **OCCT:** `TopExp_Explorer` / adjacency map via `OCCTEdgeFaceAdjacency`.

---

### `vertexEdgeAdjacency()`

Build vertex-to-edge adjacency. Returns an array where each element is the number of edges sharing that vertex.

```swift
public func vertexEdgeAdjacency() -> [Int]
```

- **Returns:** Array of edge counts per vertex (in vertex iteration order); empty if no vertices.
- **OCCT:** `TopExp_Explorer` / adjacency map via `OCCTVertexEdgeAdjacency`.

---

### `adjacentFaces(forEdge:)`

Get 1-based face indices adjacent to a specific edge within this shape.

```swift
public func adjacentFaces(forEdge edge: Shape) -> [Int]
```

- **Parameters:** `edge` — the edge shape to query adjacency for.
- **Returns:** Array of 1-based face indices (up to 64).
- **OCCT:** `TopExp` adjacency map via `OCCTEdgeAdjacentFaces`.

---

### `adjacentEdges(forVertex:)`

Get 1-based edge indices adjacent to a specific vertex within this shape.

```swift
public func adjacentEdges(forVertex vertex: Shape) -> [Int]
```

- **Parameters:** `vertex` — the vertex shape to query adjacency for.
- **Returns:** Array of 1-based edge indices (up to 64).
- **OCCT:** `TopExp` adjacency map via `OCCTVertexAdjacentEdges`.
- **Example:**
  ```swift
  let faceCounts = box.edgeFaceAdjacency()
  // faceCounts[i] == 2 for interior edges shared by two faces
  ```

---

## Poly_Connect Mesh Adjacency

`Shape` extensions for mesh triangle adjacency queries via `Poly_Connect`.

### `meshTriangleAdjacency(faceIndex:triangleIndex:)`

Get adjacent triangles for a triangle in a meshed face. Indices are 1-based; `0` means no neighbour.

```swift
public func meshTriangleAdjacency(faceIndex: Int, triangleIndex: Int) -> (Int, Int, Int)?
```

- **Parameters:**
  - `faceIndex` — 1-based face index.
  - `triangleIndex` — 1-based triangle index within the face.
- **Returns:** Tuple `(adj1, adj2, adj3)` of adjacent triangle indices, or `nil` if not found.
- **OCCT:** `Poly_Connect` via `OCCTMeshTriangleAdjacency`.

---

### `meshNodeTriangle(faceIndex:nodeIndex:)`

Get a triangle index containing a given node.

```swift
public func meshNodeTriangle(faceIndex: Int, nodeIndex: Int) -> Int?
```

- **Parameters:**
  - `faceIndex` — 1-based face index.
  - `nodeIndex` — 1-based node index.
- **Returns:** 1-based triangle index, or `nil` if not found.
- **OCCT:** `Poly_Connect` via `OCCTMeshNodeTriangle`.

---

### `meshNodeTriangleCount(faceIndex:nodeIndex:)`

Count triangles sharing a node (triangle fan count).

```swift
public func meshNodeTriangleCount(faceIndex: Int, nodeIndex: Int) -> Int
```

- **Parameters:**
  - `faceIndex` — 1-based face index.
  - `nodeIndex` — 1-based node index.
- **Returns:** Number of triangles in the fan around this node.
- **OCCT:** `Poly_Connect` via `OCCTMeshNodeTriangleCount`.

---

## BRepOffset_Analyse Edge Classification

`Shape` extensions for concavity classification using `BRepOffset_Analyse`.

### `ConcavityType`

Concavity classification for edges.

```swift
public enum ConcavityType: Int, Sendable {
    case convex = 0
    case concave = 1
    case tangent = 2
    case freeBound = 3
    case other = 4
}
```

---

### `analyseEdgeConcavity(angle:)`

Analyze edge concavity for all edges in the shape.

```swift
public func analyseEdgeConcavity(angle: Double = .pi / 6.0) -> [ConcavityType]
```

- **Parameters:** `angle` — tangency threshold in radians (default `π/6`).
- **Returns:** Array of `ConcavityType` per edge in exploration order.
- **OCCT:** `BRepOffset_Analyse` via `OCCTAnalyseEdgeConcavity`.
- **Example:**
  ```swift
  let types = shape.analyseEdgeConcavity()
  let convexCount = types.filter { $0 == .convex }.count
  ```

---

### `analyseExplode(angle:type:)`

Explode shape into groups of faces connected by edges of a given concavity type.

```swift
public func analyseExplode(angle: Double = .pi / 6.0, type: ConcavityType) -> Shape?
```

- **Parameters:**
  - `angle` — tangency threshold in radians.
  - `type` — concavity type to group by.
- **Returns:** Compound shape of face groups, or `nil` on failure.
- **OCCT:** `BRepOffset_Analyse::Explode` via `OCCTAnalyseExplode`.

---

### `analyseEdgesOnFace(_:angle:type:)`

Count edges of a given concavity type on a specific face.

```swift
public func analyseEdgesOnFace(_ face: Shape, angle: Double = .pi / 6.0, type: ConcavityType) -> Int
```

- **Parameters:**
  - `face` — the face shape to analyse.
  - `angle` — tangency threshold in radians.
  - `type` — concavity type to count.
- **Returns:** Edge count of the given type on this face.
- **OCCT:** `BRepOffset_Analyse` via `OCCTAnalyseEdgesOnFace`.

---

### `analyseAncestorCount(edge:angle:)`

Count ancestor faces for an edge in offset analysis.

```swift
public func analyseAncestorCount(edge: Shape, angle: Double = .pi / 6.0) -> Int
```

- **Parameters:**
  - `edge` — edge shape to query.
  - `angle` — tangency threshold in radians.
- **Returns:** Number of ancestor faces.
- **OCCT:** `BRepOffset_Analyse::Ancestors` via `OCCTAnalyseAncestorCount`.

---

### `analyseTangentEdgeCount(edge:vertex:angle:)`

Count tangent edges at a vertex along a given edge.

```swift
public func analyseTangentEdgeCount(edge: Shape, vertex: Shape, angle: Double = .pi / 6.0) -> Int
```

- **Parameters:**
  - `edge` — the edge to query tangency along.
  - `vertex` — the vertex at which to count tangent edges.
  - `angle` — tangency threshold in radians.
- **Returns:** Number of tangent edges at the vertex.
- **OCCT:** `BRepOffset_Analyse` via `OCCTAnalyseTangentEdgeCount`.

---

## BRepTools_WireExplorer Extensions

`Shape` extensions for ordered wire traversal via `BRepTools_WireExplorer`.

### `EdgeOrientation`

Edge orientation within a wire.

```swift
public enum EdgeOrientation: Int, Sendable {
    case forward = 0
    case reversed = 1
    case `internal` = 2
    case external = 3
}
```

---

### `wireEdgeOrientations(face:)`

Get edge orientations within a wire, optionally with face context.

```swift
public func wireEdgeOrientations(face: Shape? = nil) -> [EdgeOrientation]
```

- **Parameters:** `face` — optional face context to resolve orientation ambiguity.
- **Returns:** Array of `EdgeOrientation` per edge in wire traversal order.
- **OCCT:** `BRepTools_WireExplorer` via `OCCTWireExplorerOrientations`.
- **Example:**
  ```swift
  let orientations = wire.wireEdgeOrientations()
  ```

---

### `wireExplorerVertices(face:)`

Get connecting vertex positions from wire explorer (vertex between consecutive edges).

```swift
public func wireExplorerVertices(face: Shape? = nil) -> [SIMD3<Double>]
```

- **Parameters:** `face` — optional face context.
- **Returns:** Array of 3D positions for the connecting vertices in traversal order.
- **OCCT:** `BRepTools_WireExplorer::CurrentVertex` via `OCCTWireExplorerVertices`.

---

## BndLib Analytic Bounding

`AnalyticBounds` and `BndLib` provide exact bounding boxes for analytic geometry primitives without discretisation.

### `AnalyticBounds`

Bounding box result from analytic geometry.

```swift
public struct AnalyticBounds: Sendable {
    public let min: SIMD3<Double>
    public let max: SIMD3<Double>
}
```

---

### `BndLib.line(origin:direction:p1:p2:tolerance:)`

Bounding box of a line segment.

```swift
public static func line(origin: SIMD3<Double>, direction: SIMD3<Double>,
                         p1: Double, p2: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `origin`, `direction` — line definition; `p1`, `p2` — parametric extents; `tolerance` — inflation.
- **OCCT:** `BndLib_Add3dCurve` / `BndLib` line via `OCCTBndLibLine`.

---

### `BndLib.circle(center:normal:radius:tolerance:)`

Bounding box of a full circle.

```swift
public static func circle(center: SIMD3<Double>, normal: SIMD3<Double>,
                           radius: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **OCCT:** `BndLib` circle via `OCCTBndLibCircle`.

---

### `BndLib.sphere(center:radius:tolerance:)`

Bounding box of a sphere.

```swift
public static func sphere(center: SIMD3<Double>, radius: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **OCCT:** `BndLib_AddSurface` / sphere via `OCCTBndLibSphere`.

---

### `BndLib.cylinder(center:axis:radius:vmin:vmax:tolerance:)`

Bounding box of a cylinder patch.

```swift
public static func cylinder(center: SIMD3<Double>, axis: SIMD3<Double>,
                             radius: Double, vmin: Double, vmax: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `vmin`, `vmax` — height extent along `axis`.
- **OCCT:** `BndLib` cylinder via `OCCTBndLibCylinder`.

---

### `BndLib.torus(center:axis:majorRadius:minorRadius:tolerance:)`

Bounding box of a torus.

```swift
public static func torus(center: SIMD3<Double>, axis: SIMD3<Double>,
                          majorRadius: Double, minorRadius: Double, tolerance: Double = 0) -> AnalyticBounds
```

- **OCCT:** `BndLib` torus via `OCCTBndLibTorus`.

---

### `BndLib.edge(_:tolerance:)`

Bounding box of a 3D edge curve.

```swift
public static func edge(_ edge: Shape, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `edge` — edge shape whose underlying curve is used.
- **OCCT:** `BndLib_Add3dCurve::Add` via `OCCTBndLibEdge`.

---

### `BndLib.face(_:tolerance:)`

Bounding box of a face surface.

```swift
public static func face(_ face: Shape, tolerance: Double = 0) -> AnalyticBounds
```

- **Parameters:** `face` — face shape whose underlying surface is used.
- **OCCT:** `BndLib_AddSurface::Add` via `OCCTBndLibFace`.
- **Example:**
  ```swift
  let bounds = BndLib.sphere(center: .zero, radius: 5)
  // bounds.min == SIMD3(-5, -5, -5), bounds.max == SIMD3(5, 5, 5)
  ```

---

## OSD_Host / PerfMeter

System host information and performance measurement.

### `HostInfo.hostName`

Get the hostname.

```swift
public static var hostName: String?
```

- **OCCT:** `OSD_Host::HostName` via `OCCTHostName`.

---

### `HostInfo.systemVersion`

Get the OS version string.

```swift
public static var systemVersion: String?
```

- **OCCT:** `OSD_Host::SystemVersion` via `OCCTSystemVersion`.

---

### `HostInfo.internetAddress`

Get the internet address.

```swift
public static var internetAddress: String?
```

- **OCCT:** `OSD_Host::InternetAddress` via `OCCTInternetAddress`.
- **Example:**
  ```swift
  if let host = HostInfo.hostName { print("Running on \(host)") }
  ```

---

### `PerfMeter.init(name:)`

Create a named performance measurement timer.

```swift
public init(name: String)
```

- **Parameters:** `name` — identifier for the meter.
- **OCCT:** `OSD_PerfMeter` constructor via `OCCTPerfMeterCreate`.

---

### `PerfMeter.start()`

Start the performance timer.

```swift
public func start()
```

- **OCCT:** `OSD_PerfMeter::Start` via `OCCTPerfMeterStart`.

---

### `PerfMeter.stop()`

Stop the performance timer.

```swift
public func stop()
```

- **OCCT:** `OSD_PerfMeter::Stop` via `OCCTPerfMeterStop`.

---

### `PerfMeter.elapsed`

Elapsed time in seconds.

```swift
public var elapsed: Double
```

- **OCCT:** `OSD_PerfMeter::Elapsed` via `OCCTPerfMeterElapsed`.
- **Example:**
  ```swift
  let meter = PerfMeter(name: "myOp")
  meter.start()
  // ... work ...
  meter.stop()
  print(meter.elapsed)
  ```

---

## GProp Cylinder/Cone

Extensions on `GeometryProperties` for analytical cylinder and cone property computation.

### `GeometryProperties.cylinderSurfaceArea(radius:height:)`

Cylinder lateral surface area.

```swift
public static func cylinderSurfaceArea(radius: Double, height: Double) -> Double
```

- **OCCT:** `GProp_PGProps` cylinder surface via `OCCTGPropCylinderSurface`.

---

### `GeometryProperties.cylinderVolume(radius:height:)`

Cylinder volume.

```swift
public static func cylinderVolume(radius: Double, height: Double) -> Double
```

- **OCCT:** `GProp_PGProps` cylinder volume via `OCCTGPropCylinderVolume`.

---

### `GeometryProperties.coneSurfaceArea(semiAngle:refRadius:height:)`

Cone lateral surface area.

```swift
public static func coneSurfaceArea(semiAngle: Double, refRadius: Double, height: Double) -> Double
```

- **Parameters:** `semiAngle` — cone half-angle in radians; `refRadius` — radius at reference plane; `height` — cone height.
- **OCCT:** `GProp_PGProps` cone surface via `OCCTGPropConeSurface`.

---

### `GeometryProperties.coneVolume(semiAngle:refRadius:height:)`

Cone volume.

```swift
public static func coneVolume(semiAngle: Double, refRadius: Double, height: Double) -> Double
```

- **OCCT:** `GProp_PGProps` cone volume via `OCCTGPropConeVolume`.
- **Example:**
  ```swift
  let area = GeometryProperties.cylinderSurfaceArea(radius: 5, height: 10)
  let vol  = GeometryProperties.cylinderVolume(radius: 5, height: 10)
  ```

---

## IntAna_IntQuadQuad

Analytic quadric-quadric intersection via `IntAna_IntQuadQuad`.

### `QuadricIntersection.cylinderSphere(cylinderRadius:sphereCenter:sphereRadius:tolerance:)`

Intersect a cylinder (Z-axis, given radius) with a sphere. Returns intersection curve count, or `nil` on failure.

```swift
public static func cylinderSphere(cylinderRadius: Double,
                                   sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                   tolerance: Double = 1e-6) -> Int?
```

- **Parameters:**
  - `cylinderRadius` — radius of the Z-axis cylinder.
  - `sphereCenter` — center of the sphere.
  - `sphereRadius` — radius of the sphere.
  - `tolerance` — intersection tolerance (default `1e-6`).
- **Returns:** Number of intersection curves, or `nil` on failure.
- **OCCT:** `IntAna_IntQuadQuad` via `OCCTIntAnaCylinderSphere`.

---

### `QuadricIntersection.cylinderSphereIdentical(cylinderRadius:sphereCenter:sphereRadius:tolerance:)`

Check if a cylinder and sphere surfaces are identical.

```swift
public static func cylinderSphereIdentical(cylinderRadius: Double,
                                            sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                            tolerance: Double = 1e-6) -> Bool
```

- **OCCT:** `IntAna_IntQuadQuad::IdenticalElements` via `OCCTIntAnaCylinderSphereIdentical`.
- **Example:**
  ```swift
  if let n = QuadricIntersection.cylinderSphere(cylinderRadius: 3,
                                                  sphereCenter: .zero,
                                                  sphereRadius: 5) {
      print("\(n) intersection curve(s)")
  }
  ```

---

## XCAFPrs_DocumentExplorer

Extensions on `Document` for traversing the document's shape tree using `XCAFPrs_DocumentExplorer`.

### `explorerNodeCount`

Count leaf shape nodes in the document.

```swift
public var explorerNodeCount: Int
```

- **OCCT:** `XCAFPrs_DocumentExplorer` node enumeration via `OCCTDocumentExplorerCount`.

---

### `explorerShape(at:)`

Get the shape at a 0-based index from the document explorer.

```swift
public func explorerShape(at index: Int) -> Shape?
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** Shape at the given index, or `nil` if out of range.
- **OCCT:** `XCAFPrs_DocumentExplorer` via `OCCTDocumentExplorerShape`.

---

### `explorerPathId(at:)`

Get the path ID string at a 0-based index from the document explorer.

```swift
public func explorerPathId(at index: Int) -> String?
```

- **Parameters:** `index` — 0-based node index.
- **Returns:** Path ID string, or `nil` if out of range.
- **OCCT:** `XCAFPrs_DocumentExplorer` via `OCCTDocumentExplorerPathId`.

---

### `explorerFindShape(pathId:)`

Find a shape from a path ID string.

```swift
public func explorerFindShape(pathId: String) -> Shape?
```

- **Parameters:** `pathId` — path ID string previously returned by `explorerPathId(at:)`.
- **Returns:** Matching shape, or `nil` if not found.
- **OCCT:** `XCAFPrs_DocumentExplorer` via `OCCTDocumentExplorerFindShape`.
- **Example:**
  ```swift
  for i in 0..<doc.explorerNodeCount {
      if let shape = doc.explorerShape(at: i),
         let path  = doc.explorerPathId(at: i) {
          print("\(path): valid=\(shape.isValid)")
      }
  }
  ```

---

## gce Transform Factories

Transformation matrix types and factory namespaces backed by the `gce_Make*` family and `gp_Trsf` / `gp_Trsf2d`.

### `TransformMatrix3D`

3D transformation matrix (row-major 3×4).

```swift
public struct TransformMatrix3D: Sendable {
    public let values: [Double] // 12 elements: row-major 3x4
}
```

---

### `TransformMatrix3D.apply(to:)`

Apply this transform to a 3D point.

```swift
public func apply(to point: SIMD3<Double>) -> SIMD3<Double>
```

- **Parameters:** `point` — input point.
- **Returns:** Transformed point.

---

### `TransformMatrix2D`

2D transformation matrix (row-major 2×3).

```swift
public struct TransformMatrix2D: Sendable {
    public let values: [Double] // 6 elements: row-major 2x3
}
```

---

### `TransformMatrix2D.apply(to:)`

Apply this transform to a 2D point.

```swift
public func apply(to point: SIMD2<Double>) -> SIMD2<Double>
```

- **Parameters:** `point` — input 2D point.
- **Returns:** Transformed 2D point.

---

### `TransformFactory3D.mirrorPoint(_:)`

Mirror about a point (central symmetry).

```swift
public static func mirrorPoint(_ point: SIMD3<Double>) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeMirror` (point) via `OCCTMakeMirrorPoint`.

---

### `TransformFactory3D.mirrorAxis(point:direction:)`

Mirror about an axis (line).

```swift
public static func mirrorAxis(point: SIMD3<Double>, direction: SIMD3<Double>) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeMirror` (axis) via `OCCTMakeMirrorAxis`.

---

### `TransformFactory3D.mirrorPlane(point:normal:)`

Mirror about a plane.

```swift
public static func mirrorPlane(point: SIMD3<Double>, normal: SIMD3<Double>) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeMirror` (plane) via `OCCTMakeMirrorPlane`.

---

### `TransformFactory3D.rotation(point:direction:angle:)`

Rotation about an axis by angle in radians.

```swift
public static func rotation(point: SIMD3<Double>, direction: SIMD3<Double>, angle: Double) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeRotation` via `OCCTMakeRotation`.

---

### `TransformFactory3D.scale(center:factor:)`

Uniform scale about a point.

```swift
public static func scale(center: SIMD3<Double>, factor: Double) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeScale` via `OCCTMakeScaleTransform`.

---

### `TransformFactory3D.translation(_:)`

Translation by a vector.

```swift
public static func translation(_ vector: SIMD3<Double>) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeTranslation` (vector) via `OCCTMakeTranslationVec`.

---

### `TransformFactory3D.translation(from:to:)`

Translation from one point to another.

```swift
public static func translation(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> TransformMatrix3D
```

- **OCCT:** `gce_MakeTranslation` (two points) via `OCCTMakeTranslationPoints`.
- **Example:**
  ```swift
  let m = TransformFactory3D.rotation(point: .zero, direction: SIMD3(0,0,1), angle: .pi / 4)
  let rotated = m.apply(to: SIMD3(1, 0, 0))
  ```

---

### `TransformFactory2D.mirrorPoint(_:)`

Mirror about a 2D point.

```swift
public static func mirrorPoint(_ point: SIMD2<Double>) -> TransformMatrix2D
```

- **OCCT:** `gce_MakeMirror2d` (point) via `OCCTMakeMirror2dPoint`.

---

### `TransformFactory2D.mirrorAxis(point:direction:)`

Mirror about a 2D axis.

```swift
public static func mirrorAxis(point: SIMD2<Double>, direction: SIMD2<Double>) -> TransformMatrix2D
```

- **OCCT:** `gce_MakeMirror2d` (axis) via `OCCTMakeMirror2dAxis`.

---

### `TransformFactory2D.rotation(center:angle:)`

Rotation about a 2D point by angle in radians.

```swift
public static func rotation(center: SIMD2<Double>, angle: Double) -> TransformMatrix2D
```

- **OCCT:** `gce_MakeRotation2d` via `OCCTMakeRotation2d`.

---

### `TransformFactory2D.scale(center:factor:)`

Uniform scale about a 2D point.

```swift
public static func scale(center: SIMD2<Double>, factor: Double) -> TransformMatrix2D
```

- **OCCT:** `gce_MakeScale2d` via `OCCTMakeScale2d`.

---

### `TransformFactory2D.translation(_:)` (vector)

Translation by a 2D vector.

```swift
public static func translation(_ vector: SIMD2<Double>) -> TransformMatrix2D
```

- **OCCT:** `gce_MakeTranslation2d` (vector) via `OCCTMakeTranslation2dVec`.

---

### `TransformFactory2D.translation(from:to:)`

Translation from one 2D point to another.

```swift
public static func translation(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> TransformMatrix2D
```

- **OCCT:** `gce_MakeTranslation2d` (two points) via `OCCTMakeTranslation2dPoints`.

---

### `TransformFactory2D.direction(x:y:)`

Create a unit 2D direction from coordinates. Returns `nil` if the input is a zero vector.

```swift
public static func direction(x: Double, y: Double) -> SIMD2<Double>?
```

- **OCCT:** `gce_MakeDir2d` via `OCCTMakeDir2d`.

---

### `TransformFactory2D.direction(from:to:)`

Create a unit 2D direction from two points. Returns `nil` if the points are coincident.

```swift
public static func direction(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> SIMD2<Double>?
```

- **OCCT:** `gce_MakeDir2d` (two points) via `OCCTMakeDir2dFromPoints`.

---

## GProp Element Properties

`GeometryProperties` provides analytical mass/center computations for primitive geometry elements.

### `GeometryProperties.lineSegment(from:to:)`

Line segment properties: returns `(length, centerOfMass)`.

```swift
public static func lineSegment(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> (length: Double, center: SIMD3<Double>)
```

- **OCCT:** `GProp_PEquation` / `GProp_PGProps` line via `OCCTGPropLineSegment`.

---

### `GeometryProperties.circularArc(center:normal:radius:u1:u2:)`

Circular arc properties: returns `(arcLength, centerOfMass)`.

```swift
public static func circularArc(center: SIMD3<Double>, normal: SIMD3<Double>,
                                radius: Double, u1: Double, u2: Double) -> (arcLength: Double, center: SIMD3<Double>)
```

- **Parameters:** `u1`, `u2` — parametric start and end angles in radians.
- **OCCT:** `GProp_PGProps` circular arc via `OCCTGPropCircularArc`.

---

### `GeometryProperties.pointSetCentroid(_:)`

Compute the centroid of a point set. Returns `(pointCount, centroid)`.

```swift
public static func pointSetCentroid(_ points: [SIMD3<Double>]) -> (count: Double, centroid: SIMD3<Double>)
```

- **Parameters:** `points` — array of 3D points.
- **Returns:** The point count (as `Double`) and the centroid.
- **OCCT:** `GProp_PGProps` point set via `OCCTGPropPointSetCentroid`.

---

### `GeometryProperties.sphereSurfaceArea(radius:)`

Sphere surface area (analytical).

```swift
public static func sphereSurfaceArea(radius: Double) -> Double
```

- **OCCT:** `GProp_PGProps` sphere surface via `OCCTGPropSphereSurface`.

---

### `GeometryProperties.sphereVolume(radius:)`

Sphere volume (analytical).

```swift
public static func sphereVolume(radius: Double) -> Double
```

- **OCCT:** `GProp_PGProps` sphere volume via `OCCTGPropSphereVolume`.
- **Example:**
  ```swift
  let (len, com) = GeometryProperties.lineSegment(from: .zero, to: SIMD3(3, 4, 0))
  // len == 5.0, com == SIMD3(1.5, 2.0, 0)
  ```

---

## Plate Constraint Extensions

Extensions on `PlateSolver` for additional constraint types.

### `loadPlaneConstraint(u:v:planePoint:planeNormal:)`

Load a plane constraint at a UV point.

```swift
@discardableResult
public func loadPlaneConstraint(u: Double, v: Double, planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Bool
```

- **Parameters:** `u`, `v` — parametric constraint location; `planePoint`, `planeNormal` — plane definition.
- **Returns:** `true` on success.
- **OCCT:** `Plate_PlaneConstraint` via `OCCTPlateLoadPlaneConstraint`.

---

### `loadLineConstraint(u:v:linePoint:lineDirection:)`

Load a line constraint at a UV point.

```swift
@discardableResult
public func loadLineConstraint(u: Double, v: Double, linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>) -> Bool
```

- **Parameters:** `u`, `v` — parametric constraint location; `linePoint`, `lineDirection` — line definition.
- **Returns:** `true` on success.
- **OCCT:** `Plate_LineConstraint` via `OCCTPlateLoadLineConstraint`.

---

### `loadFreeG1Constraint(u:v:du:dv:)`

Load a free G1 continuity constraint at a UV point.

```swift
@discardableResult
public func loadFreeG1Constraint(u: Double, v: Double, du: SIMD3<Double>, dv: SIMD3<Double>) -> Bool
```

- **Parameters:** `u`, `v` — parametric constraint location; `du`, `dv` — partial derivatives defining the tangent frame.
- **Returns:** `true` on success.
- **OCCT:** `Plate_FreeGthenCConstraint` (G1) via `OCCTPlateLoadFreeG1Constraint`.

---

## Law_Interpolate

Extension on `LawFunction` for creating interpolated law functions.

### `LawFunction.interpolated(values:parameters:periodic:)`

Create an interpolated law function from values.

```swift
public static func interpolated(values: [Double], parameters: [Double]? = nil, periodic: Bool = false) -> LawFunction?
```

- **Parameters:**
  - `values` — array of function values to interpolate.
  - `parameters` — optional parameter array; must match `values.count` if provided. If `nil`, uniform spacing is used.
  - `periodic` — if `true`, the interpolation is periodic.
- **Returns:** Interpolated `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_Interpolate` via `OCCTLawInterpolate`.
- **Example:**
  ```swift
  if let law = LawFunction.interpolated(values: [1.0, 2.0, 1.0]) {
      print(law.value(at: 0.5))
  }
  ```

---

## Bnd_Sphere

`BoundingSphere` wraps OCCT's `Bnd_Sphere` for fast spatial culling and proximity queries.

### `BoundingSphere.init(center:radius:)`

Create a bounding sphere.

```swift
public init(center: SIMD3<Double>, radius: Double)
```

- **OCCT:** `Bnd_Sphere` constructor via `OCCTBndSphereCreate`.

---

### `BoundingSphere.radius`

The sphere radius.

```swift
public var radius: Double
```

- **OCCT:** `Bnd_Sphere::Radius` via `OCCTBndSphereRadius`.

---

### `BoundingSphere.center`

The sphere center.

```swift
public var center: SIMD3<Double>
```

- **OCCT:** `Bnd_Sphere::Center` via `OCCTBndSphereCenter`.

---

### `BoundingSphere.distance(to:)`

Distance from sphere center to a point.

```swift
public func distance(to point: SIMD3<Double>) -> Double
```

- **OCCT:** `Bnd_Sphere::Distance` via `OCCTBndSphereDistance`.

---

### `BoundingSphere.isOutside(_:)` (point)

Check if a point is outside the sphere.

```swift
public func isOutside(_ point: SIMD3<Double>) -> Bool
```

- **OCCT:** `Bnd_Sphere::IsOut` (point) via `OCCTBndSphereIsOut`.

---

### `BoundingSphere.isOutside(_:)` (sphere)

Check if another sphere is disjoint from this sphere.

```swift
public func isOutside(_ other: BoundingSphere) -> Bool
```

- **OCCT:** `Bnd_Sphere::IsOut` (sphere) via `OCCTBndSphereIsOutSphere`.

---

### `BoundingSphere.add(_:)`

Merge (expand to contain) another sphere.

```swift
public func add(_ other: BoundingSphere)
```

- **OCCT:** `Bnd_Sphere::Add` via `OCCTBndSphereAdd`.
- **Example:**
  ```swift
  let s = BoundingSphere(center: .zero, radius: 5)
  print(s.isOutside(SIMD3(10, 0, 0))) // true
  ```

---

## GC_MakeCircle

`Curve3D` factory methods backed by `GC_MakeCircle`.

### `Curve3D.gcCircle(center:normal:radius:)`

Create a 3D circle from axis (center + normal) and radius.

```swift
public static func gcCircle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D?
```

- **OCCT:** `GC_MakeCircle` via `OCCTGCMakeCircle`.

---

### `Curve3D.gcCircle(p1:p2:p3:)`

Create a 3D circle through 3 points.

```swift
public static func gcCircle(p1: SIMD3<Double>, p2: SIMD3<Double>, p3: SIMD3<Double>) -> Curve3D?
```

- **OCCT:** `GC_MakeCircle` (3 points) via `OCCTGCMakeCircle3Points`.

---

### `Curve3D.gcCircleCenterNormal(center:normal:radius:)`

Create a 3D circle from center, normal, and radius (alias).

```swift
public static func gcCircleCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D?
```

- **OCCT:** `GC_MakeCircle` via `OCCTGCMakeCircleCenterNormal`.

---

### `Curve3D.gcCircleParallel(center:normal:radius:distance:)`

Create a 3D circle parallel to an existing circle at a given distance.

```swift
public static func gcCircleParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                     radius: Double, distance: Double) -> Curve3D?
```

- **Parameters:** `distance` — signed offset distance from the reference circle.
- **OCCT:** `GC_MakeCircle` (parallel) via `OCCTGCMakeCircleParallel`.
- **Example:**
  ```swift
  if let c = Curve3D.gcCircle(center: .zero, normal: SIMD3(0,0,1), radius: 10) {
      print(c.length())
  }
  ```

---

## GC_MakeEllipse

`Curve3D` factory methods backed by `GC_MakeEllipse`.

### `Curve3D.gcEllipse(center:normal:majorRadius:minorRadius:)`

Create a 3D ellipse from axis and major/minor radii.

```swift
public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                              majorRadius: Double, minorRadius: Double) -> Curve3D?
```

- **OCCT:** `GC_MakeEllipse` via `OCCTGCMakeEllipse`.

---

### `Curve3D.gcEllipse(s1:s2:center:)`

Create a 3D ellipse from 3 points (S1, S2, center).

```swift
public static func gcEllipse(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `s1`, `s2` — points on the ellipse; `center` — ellipse center.
- **OCCT:** `GC_MakeEllipse` (3 points) via `OCCTGCMakeEllipse3Points`.

---

### `Curve3D.gcEllipse(center:normal:xDirection:majorRadius:minorRadius:)`

Create a 3D ellipse from full Ax2 (center + normal + X direction) and radii.

```swift
public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                              majorRadius: Double, minorRadius: Double) -> Curve3D?
```

- **Parameters:** `xDirection` — explicit X-axis direction for the ellipse frame.
- **OCCT:** `GC_MakeEllipse` (Ax2) via `OCCTGCMakeEllipseFromElips`.

---

## GC_MakeHyperbola

`Curve3D` factory methods backed by `GC_MakeHyperbola`.

### `Curve3D.gcHyperbola(center:normal:majorRadius:minorRadius:)`

Create a 3D hyperbola from axis and major/minor radii.

```swift
public static func gcHyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                majorRadius: Double, minorRadius: Double) -> Curve3D?
```

- **OCCT:** `GC_MakeHyperbola` via `OCCTGCMakeHyperbola`.

---

### `Curve3D.gcHyperbola(s1:s2:center:)`

Create a 3D hyperbola from 3 points (S1, S2, center).

```swift
public static func gcHyperbola(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D?
```

- **Parameters:** `s1`, `s2` — points on the hyperbola; `center` — hyperbola center.
- **OCCT:** `GC_MakeHyperbola` (3 points) via `OCCTGCMakeHyperbola3Points`.

---

## GC_MakeCircle2d

`Curve2D` factory methods backed by `gce_MakeCirc2d`.

### `Curve2D.gceCircle(center:radius:)`

Create a 2D circle from center and radius.

```swift
public static func gceCircle(center: SIMD2<Double>, radius: Double) -> Curve2D?
```

- **OCCT:** `gce_MakeCirc2d` via `OCTGCE2dMakeCircleCenterRadius`.

---

### `Curve2D.gceCircle(p1:p2:p3:)`

Create a 2D circle through 3 points.

```swift
public static func gceCircle(p1: SIMD2<Double>, p2: SIMD2<Double>, p3: SIMD2<Double>) -> Curve2D?
```

- **OCCT:** `gce_MakeCirc2d` (3 points) via `OCTGCE2dMakeCircle3Points`.

---

### `Curve2D.gceCircle(center:pointOn:)`

Create a 2D circle from center and a point on the circle.

```swift
public static func gceCircle(center: SIMD2<Double>, pointOn: SIMD2<Double>) -> Curve2D?
```

- **OCCT:** `gce_MakeCirc2d` (center + point) via `OCTGCE2dMakeCircleCenterPoint`.

---

### `Curve2D.gceCircleParallel(center:direction:radius:distance:)`

Create a 2D circle parallel to an existing circle at a given distance.

```swift
public static func gceCircleParallel(center: SIMD2<Double>, direction: SIMD2<Double>,
                                      radius: Double, distance: Double) -> Curve2D?
```

- **OCCT:** `gce_MakeCirc2d` (parallel) via `OCTGCE2dMakeCircleParallel`.

---

### `Curve2D.gceCircle(axisCenter:axisDirection:radius:)`

Create a 2D circle from axis (center + direction) and radius.

```swift
public static func gceCircle(axisCenter: SIMD2<Double>, axisDirection: SIMD2<Double>,
                              radius: Double) -> Curve2D?
```

- **OCCT:** `gce_MakeCirc2d` (axis) via `OCTGCE2dMakeCircleAxis`.
- **Example:**
  ```swift
  if let c = Curve2D.gceCircle(center: SIMD2(0, 0), radius: 5) {
      print(c.length())
  }
  ```

---

## GC_MakeEllipse2d

`Curve2D` factory methods backed by `gce_MakeElips2d`.

### `Curve2D.gceEllipse(center:xDirection:majorRadius:minorRadius:)`

Create a 2D ellipse from axis and radii.

```swift
public static func gceEllipse(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                               majorRadius: Double, minorRadius: Double) -> Curve2D?
```

- **OCCT:** `gce_MakeElips2d` via `OCTGCE2dMakeEllipse`.

---

### `Curve2D.gceEllipse(s1:s2:center:)`

Create a 2D ellipse from 3 points (S1, S2, center).

```swift
public static func gceEllipse(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>) -> Curve2D?
```

- **OCCT:** `gce_MakeElips2d` (3 points) via `OCTGCE2dMakeEllipse3Points`.

---

### `Curve2D.gceEllipse(center:xDirection:yDirection:majorRadius:minorRadius:)`

Create a 2D ellipse from full Ax22d and radii.

```swift
public static func gceEllipse(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                               yDirection: SIMD2<Double>,
                               majorRadius: Double, minorRadius: Double) -> Curve2D?
```

- **Parameters:** `yDirection` — explicit Y-axis direction for the ellipse frame.
- **OCCT:** `gce_MakeElips2d` (Ax22d) via `OCTGCE2dMakeEllipseAxis22d`.

---

## GC_MakeHyperbola2d

`Curve2D` factory methods backed by `gce_MakeHypr2d`.

### `Curve2D.gceHyperbola(center:xDirection:majorRadius:minorRadius:)`

Create a 2D hyperbola from axis and radii.

```swift
public static func gceHyperbola(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                 majorRadius: Double, minorRadius: Double) -> Curve2D?
```

- **OCCT:** `gce_MakeHypr2d` via `OCTGCE2dMakeHyperbola`.

---

### `Curve2D.gceHyperbola(s1:s2:center:)`

Create a 2D hyperbola from 3 points (S1, S2, center).

```swift
public static func gceHyperbola(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>) -> Curve2D?
```

- **Parameters:** `s1`, `s2` — points on the hyperbola; `center` — hyperbola center.
- **OCCT:** `gce_MakeHypr2d` (3 points) via `OCTGCE2dMakeHyperbola3Points`.
- **Example:**
  ```swift
  if let h = Curve2D.gceHyperbola(center: .zero,
                                    xDirection: SIMD2(1, 0),
                                    majorRadius: 3, minorRadius: 2) {
      // h is a Geom2d_Hyperbola
  }
  ```
