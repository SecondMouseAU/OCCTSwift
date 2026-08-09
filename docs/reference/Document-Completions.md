---
title: Document — XCAF & API Completions
parent: API Reference
---

# Document — XCAF & API Completions

This page covers the last group of public members declared in `Sources/OCCTSwift/Document.swift`: a collection of extension completions added across versions 0.122.0–0.130.0, spanning `WireFixer`, `ShapeFix_Edge`, `BRepTools`/`BRepLib` statics, shape history, sewing, builder extensions, section operations, curve/surface queries, XCAF color/shape-tool completions, fillet/chamfer history queries, a standalone `SectionBuilder`, and the `GeomEval`/`Geom2dEval` analytical evaluators. See the main [`Document`](Document.md) page for core load/save and assembly operations.

## Topics

- [WireFixer Extended](#wirefixer-extended) · [ShapeFix_Edge Statics](#shapefixedge-statics) · [BRepTools Statics](#breptools-statics) · [BRepLib Extended Statics](#breplib-extended-statics) · [Shape.History Extended](#shapehistory-extended) · [SewingBuilder Extended](#sewingbuilder-extended) · [ThruSectionsBuilder Extensions](#thrусectionsbuilder-extensions) · [CellsBuilder Extensions](#cellsbuilder-extensions) · [PipeShellStatus](#pipeshellstatus) · [PipeShellBuilder Extensions](#pipeshellbuilder-extensions) · [UnifySameDomainBuilder](#unifysamedomain-builder) · [Section Ops on Shape](#section-ops-on-shape) · [Curve3D Extended Queries](#curve3d-extended-queries) · [Additional Shape Queries](#additional-shape-queries) · [XCAFDoc_ColorTool Completions on Document](#xcafdoc_colortool-completions-on-document) · [XCAFDoc_ShapeTool Completions on Document](#xcafdoc_shapetool-completions-on-document) · [ColorTool Completions v0.127.0](#colortool-completions-v01270) · [FilletBuilder History Queries](#filletbuilder-history-queries) · [ChamferBuilder History & Extras](#chamferbuilder-history--extras) · [SectionBuilder](#sectionbuilder) · [GeomEval Standalone Evaluators](#geomeval-standalone-evaluators) · [Geom2dEval Standalone Evaluators](#geom2deval-standalone-evaluators)

---

## WireFixer Extended

Extensions on `WireFixer` added in v0.122.0.

### `WireFixer.fixGaps2d()`

Fix 2D parametric gaps between edges on the wire.

```swift
@discardableResult public func fixGaps2d() -> Bool
```

- **Returns:** `true` if any gaps were fixed.
- **OCCT:** `ShapeFix_Wire::FixGaps2d`.
- **Example:**
  ```swift
  let fixer = WireFixer(wire: someWire, face: someFace, precision: 1e-6)
  fixer.fixGaps2d()
  ```

---

### `WireFixer.fixSeam(edgeIndex:)`

Fix the seam edge at the given 1-based index within the wire.

```swift
@discardableResult public func fixSeam(edgeIndex: Int) -> Bool
```

- **Parameters:** `edgeIndex` — 1-based index of the seam edge in the wire.
- **Returns:** `true` if the seam was fixed.
- **OCCT:** `ShapeFix_Wire::FixSeam`.
- **Example:**
  ```swift
  fixer.fixSeam(edgeIndex: 1)
  ```

---

### `WireFixer.fixShifted()`

Fix edges whose pcurves are shifted by a period.

```swift
@discardableResult public func fixShifted() -> Bool
```

- **Returns:** `true` if any edges were corrected.
- **OCCT:** `ShapeFix_Wire::FixShifted`.
- **Example:**
  ```swift
  fixer.fixShifted()
  ```

---

### `WireFixer.fixNotchedEdges()`

Fix notched (overhanging) edges in the wire.

```swift
@discardableResult public func fixNotchedEdges() -> Bool
```

- **Returns:** `true` if notches were removed.
- **OCCT:** `ShapeFix_Wire::FixNotchedEdges`.
- **Example:**
  ```swift
  fixer.fixNotchedEdges()
  ```

---

### `WireFixer.fixTails()`

Remove tail edges (degenerate end edges) from the wire.

```swift
@discardableResult public func fixTails() -> Bool
```

- **Returns:** `true` if tails were removed.
- **OCCT:** `ShapeFix_Wire::FixTails`.
- **Example:**
  ```swift
  fixer.fixTails()
  ```

---

### `WireFixer.setMaxTailAngle(_:)`

Set the angular threshold (radians) below which an edge is considered a tail.

```swift
public func setMaxTailAngle(_ angle: Double)
```

- **Parameters:** `angle` — maximum angle in radians.
- **OCCT:** `ShapeFix_Wire::SetMaxTailAngle`.
- **Example:**
  ```swift
  fixer.setMaxTailAngle(0.01)
  ```

---

### `WireFixer.setMaxTailWidth(_:)`

Set the width threshold below which an edge is considered a tail.

```swift
public func setMaxTailWidth(_ width: Double)
```

- **Parameters:** `width` — maximum width.
- **OCCT:** `ShapeFix_Wire::SetMaxTailWidth`.
- **Example:**
  ```swift
  fixer.setMaxTailWidth(1e-4)
  ```

---

## ShapeFix_Edge Statics

Static helpers on `Shape` wrapping `ShapeFix_Edge`, added in v0.122.0.

### `Shape.fixEdgeAddCurve3d(_:)`

Add a missing 3D curve to an edge.

```swift
public static func fixEdgeAddCurve3d(_ edge: Shape) -> Bool
```

- **Parameters:** `edge` — an edge shape missing its 3D curve.
- **Returns:** `true` if the 3D curve was successfully added.
- **OCCT:** `ShapeFix_Edge::AddCurve3d`.
- **Example:**
  ```swift
  if Shape.fixEdgeAddCurve3d(myEdge) {
      print("3D curve added")
  }
  ```

---

### `Shape.fixEdgeAddPCurve(_:face:isSeam:)`

Add a missing PCurve (2D parametric curve) to an edge on a face.

```swift
public static func fixEdgeAddPCurve(_ edge: Shape, face: Shape, isSeam: Bool = false) -> Bool
```

- **Parameters:** `edge` — the edge; `face` — the face to add the PCurve on; `isSeam` — whether the edge is a seam.
- **Returns:** `true` if the PCurve was added.
- **OCCT:** `ShapeFix_Edge::AddPCurve`.
- **Example:**
  ```swift
  Shape.fixEdgeAddPCurve(edge, face: face, isSeam: false)
  ```

---

### `Shape.fixEdgeRemoveCurve3d(_:)`

Remove the 3D curve from an edge.

```swift
public static func fixEdgeRemoveCurve3d(_ edge: Shape) -> Bool
```

- **Parameters:** `edge` — edge whose 3D curve should be removed.
- **Returns:** `true` on success.
- **OCCT:** `ShapeFix_Edge::RemoveCurve3d`.
- **Example:**
  ```swift
  Shape.fixEdgeRemoveCurve3d(myEdge)
  ```

---

### `Shape.fixEdgeRemovePCurve(_:face:)`

Remove the PCurve from an edge on a face.

```swift
public static func fixEdgeRemovePCurve(_ edge: Shape, face: Shape) -> Bool
```

- **Parameters:** `edge` — the edge; `face` — the face carrying the PCurve to remove.
- **Returns:** `true` on success.
- **OCCT:** `ShapeFix_Edge::RemovePCurve`.
- **Example:**
  ```swift
  Shape.fixEdgeRemovePCurve(edge, face: face)
  ```

---

### `Shape.fixEdgeReversed2d(_:face:)`

Fix a reversed 2D parametric curve on an edge/face pair.

```swift
public static func fixEdgeReversed2d(_ edge: Shape, face: Shape) -> Bool
```

- **Parameters:** `edge` — the edge with the reversed PCurve; `face` — the owning face.
- **Returns:** `true` if the reversal was fixed.
- **OCCT:** `ShapeFix_Edge::FixReversed2d`.
- **Example:**
  ```swift
  Shape.fixEdgeReversed2d(edge, face: face)
  ```

---

## BRepTools Statics

Extensions on `Shape` wrapping `BRepTools` utilities, added in v0.122.0.

### `Shape.cleanTriangulation()`

Remove all triangulation data from this shape (`BRepTools::Clean`).

```swift
public func cleanTriangulation()
```

- **OCCT:** `BRepTools::Clean`.
- **Example:**
  ```swift
  shape.cleanTriangulation()
  ```

---

### `Shape.removeInternals()`

Remove internal edges and vertices from this shape (`BRepTools::RemoveInternals`).

```swift
public func removeInternals()
```

- **OCCT:** `BRepTools::RemoveInternals`.
- **Example:**
  ```swift
  shape.removeInternals()
  ```

---

### `Shape.detectClosedness()`

Detect whether a face is closed in U and/or V.

```swift
public func detectClosedness() -> (isClosedU: Bool, isClosedV: Bool)
```

- **Returns:** A tuple `(isClosedU, isClosedV)` — `true` where the face wraps around.
- **OCCT:** `BRepTools::DetectClosedness`.
- **Example:**
  ```swift
  let closed = face.detectClosedness()
  if closed.isClosedU { print("closed in U") }
  ```

---

### `Shape.evalAndUpdateTolerance(edge:face:)`

Evaluate and update the tolerance of an edge on a face. Returns the new tolerance.

```swift
public static func evalAndUpdateTolerance(edge: Shape, face: Shape) -> Double
```

- **Parameters:** `edge` — the edge; `face` — the face it lies on.
- **Returns:** The updated tolerance value.
- **OCCT:** `BRepTools::EvalAndUpdateTol`.
- **Example:**
  ```swift
  let tol = Shape.evalAndUpdateTolerance(edge: myEdge, face: myFace)
  ```

---

### `Shape.map3DEdgeCount`

Count of distinct 3D edges in this shape.

```swift
public var map3DEdgeCount: Int
```

- **OCCT:** `BRepTools::Map3DEdges` → count.
- **Example:**
  ```swift
  print(shape.map3DEdgeCount)
  ```

---

### `Shape.updateFaceUVPoints()`

Update the UV poles/points of all faces in this shape.

```swift
public func updateFaceUVPoints()
```

- **OCCT:** `BRepTools::UpdateFaceUVPoints`.
- **Example:**
  ```swift
  shape.updateFaceUVPoints()
  ```

---

### `Shape.compareVertices(_:_:)`

Compare two vertex shapes for geometric equality.

```swift
public static func compareVertices(_ v1: Shape, _ v2: Shape) -> Bool
```

- **Returns:** `true` if the vertices are geometrically equal.
- **OCCT:** `BRepTools::Compare` (vertex overload).
- **Example:**
  ```swift
  if Shape.compareVertices(v1, v2) { print("same vertex") }
  ```

---

### `Shape.compareEdges(_:_:)`

Compare two edge shapes for geometric equality.

```swift
public static func compareEdges(_ e1: Shape, _ e2: Shape) -> Bool
```

- **Returns:** `true` if the edges are geometrically equal.
- **OCCT:** `BRepTools::Compare` (edge overload).
- **Example:**
  ```swift
  if Shape.compareEdges(e1, e2) { print("same edge") }
  ```

---

### `Shape.isReallyClosed(edge:face:)`

Check whether an edge is truly closed on a face (seam check beyond topology flags).

```swift
public static func isReallyClosed(edge: Shape, face: Shape) -> Bool
```

- **Returns:** `true` if the edge is a genuine seam on the face.
- **OCCT:** `BRepTools::IsReallyClosed`.
- **Example:**
  ```swift
  if Shape.isReallyClosed(edge: e, face: f) { print("seam") }
  ```

---

### `Shape.updateTopology()`

Update the internal topology state of this shape (`BRepTools::Update`).

```swift
public func updateTopology()
```

- **OCCT:** `BRepTools::Update`.
- **Example:**
  ```swift
  shape.updateTopology()
  ```

---

## BRepLib Extended Statics

Extensions on `Shape` wrapping `BRepLib`, added in v0.122.0.

### `Shape.ensureNormalConsistency(maxAngle:)`

Ensure normal consistency of a triangulated shape, optionally clamping to `maxAngle`.

```swift
@discardableResult
public func ensureNormalConsistency(maxAngle: Double = 0.001) -> Bool
```

- **Parameters:** `maxAngle` — maximum deviation angle in radians; defaults to 0.001.
- **Returns:** `true` if normals were corrected.
- **OCCT:** `BRepLib::EnsureNormalConsistency`.
- **Example:**
  ```swift
  shape.ensureNormalConsistency()
  ```

---

### `Shape.updateDeflection()`

Update the deflection information stored on this shape.

```swift
public func updateDeflection()
```

- **OCCT:** `BRepLib::UpdateDeflection`.
- **Example:**
  ```swift
  shape.updateDeflection()
  ```

---

### `Shape.continuityClassOfFaces(edge:face1:face2:tolerance:)`

Get the geometric continuity of the surface across an edge shared by two faces.

```swift
public static func continuityClassOfFaces(edge: Shape, face1: Shape, face2: Shape,
                                          tolerance: Double = 1e-6) -> ContinuityClass?
```

- **Parameters:** `edge` — the shared edge; `face1`, `face2` — the two faces; `tolerance` — comparison tolerance.
- **Returns:** the measured `ContinuityClass`, or `nil` on failure (null handle, or OCCT throwing).
- **OCCT:** `BRepLib::ContinuityOfFaces`.
- **Domain:** six of the seven classes are reachable — `.c0` for a sharp join, `.g1` for a fillet's tangent join, and `.cN` for a seam on an elementary surface (or any elementary pair measuring C2, which OCCT promotes). `.c3` is never returned.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let faces = box.subShapes(ofType: .face), edges = box.subShapes(ofType: .edge)
  Shape.continuityClassOfFaces(edge: edges[0], face1: faces[0], face2: faces[1])  // .c0
  ```

`continuityOfFaces(edge:face1:face2:tolerance:) -> Int`, the raw-ordinal spelling that reported the
same measurement (its doc comment claimed `5=CN`, wrong twice over: CN is ordinal 6, and 5/C3 is a
value the function could not return, #495), and `buildCurves3dAll(tolerance:)`, a byte-identical
second wrapper over `BRepLib::BuildCurves3d` whose default had drifted 100x from `buildCurves3d`'s
own (#498), were both deprecated in favour of the methods above and removed at v2.0.0 (#784).

---

### `Shape.sameParameterAll(tolerance:forced:)`

Apply same-parameter correction to all edges in the shape.

```swift
public func sameParameterAll(tolerance: Double = 1e-5, forced: Bool = false)
```

- **Parameters:** `tolerance` — target tolerance; `forced` — if `true`, forces reparametrization even when already same-parameter.
- **OCCT:** `BRepLib::SameParameter` (shape overload).
- **Example:**
  ```swift
  shape.sameParameterAll(tolerance: 1e-7, forced: true)
  ```

---

## Shape.History Extended

Extensions on `Shape.History` added in v0.122.0.

### `Shape.History.merge(_:)`

Merge another history into this one, combining all modified and generated mappings.

```swift
public func merge(_ other: Shape.History)
```

- **Parameters:** `other` — the history to absorb.
- **OCCT:** `BRepTools_History::Merge`.
- **Example:**
  ```swift
  let combined = Shape.History()
  combined.merge(history1)
  combined.merge(history2)
  ```

---

### `Shape.History.replaceGenerated(initial:generated:)`

Replace an existing generated-shape entry.

```swift
public func replaceGenerated(initial: Shape, generated: Shape)
```

- **Parameters:** `initial` — the original shape; `generated` — the replacement generated shape.
- **OCCT:** `BRepTools_History::ReplaceGenerated`.
- **Example:**
  ```swift
  history.replaceGenerated(initial: oldEdge, generated: newFace)
  ```

---

### `Shape.History.replaceModified(initial:modified:)`

Replace an existing modified-shape entry.

```swift
public func replaceModified(initial: Shape, modified: Shape)
```

- **Parameters:** `initial` — the original shape; `modified` — the replacement modified shape.
- **OCCT:** `BRepTools_History::ReplaceModified`.
- **Example:**
  ```swift
  history.replaceModified(initial: oldFace, modified: newFace)
  ```

---

### `Shape.History.modifiedShapes(of:)`

Get all shapes that the given initial shape was modified into.

```swift
public func modifiedShapes(of initial: Shape) -> [Shape]
```

- **Parameters:** `initial` — the input shape to query.
- **Returns:** Array of modified shapes (up to 64 results).
- **OCCT:** `BRepTools_History::Modified`.
- **Example:**
  ```swift
  let mods = history.modifiedShapes(of: originalFace)
  ```

---

### `Shape.History.generatedShapes(of:)`

Get all shapes generated from the given initial shape.

```swift
public func generatedShapes(of initial: Shape) -> [Shape]
```

- **Parameters:** `initial` — the input shape to query.
- **Returns:** Array of generated shapes (up to 64 results).
- **OCCT:** `BRepTools_History::Generated`.
- **Example:**
  ```swift
  let gen = history.generatedShapes(of: originalEdge)
  ```

---

## SewingBuilder Extended

Extensions on `SewingBuilder` added in v0.122.0.

### `SewingBuilder.nbDeletedFaces`

Number of faces deleted during sewing.

```swift
public var nbDeletedFaces: Int
```

- **OCCT:** `BRepBuilderAPI_Sewing::NbDeletedFaces`.
- **Example:**
  ```swift
  print(sewer.nbDeletedFaces)
  ```

---

### `SewingBuilder.deletedFace(at:)`

Get a deleted face by 1-based index.

```swift
public func deletedFace(at index: Int) -> Shape?
```

- **Parameters:** `index` — 1-based index.
- **Returns:** The deleted face shape, or `nil` if the index is out of range.
- **OCCT:** `BRepBuilderAPI_Sewing::DeletedFace`.
- **Example:**
  ```swift
  for i in 1...sewer.nbDeletedFaces {
      if let df = sewer.deletedFace(at: i) { print(df.typeName ?? "") }
  }
  ```

---

### `SewingBuilder.isModified(_:)`

Check if a sub-shape was modified by the sewing operation.

```swift
public func isModified(_ shape: Shape) -> Bool
```

- **Parameters:** `shape` — the sub-shape to query.
- **Returns:** `true` if the shape was changed.
- **OCCT:** `BRepBuilderAPI_Sewing::IsModified`.
- **Example:**
  ```swift
  if sewer.isModified(myFace) { print("face was merged") }
  ```

---

### `SewingBuilder.modified(_:)`

Get the sewed version of a shape.

```swift
public func modified(_ shape: Shape) -> Shape?
```

- **Parameters:** `shape` — the original sub-shape.
- **Returns:** The sewed replacement, or `nil` if unmodified.
- **OCCT:** `BRepBuilderAPI_Sewing::Modified`.
- **Example:**
  ```swift
  if let sewn = sewer.modified(origFace) { ... }
  ```

---

### `SewingBuilder.isDegenerated(_:)`

Check if a shape is degenerated after sewing.

```swift
public func isDegenerated(_ shape: Shape) -> Bool
```

- **Returns:** `true` if the shape collapsed to a degenerate form.
- **OCCT:** `BRepBuilderAPI_Sewing::IsDegenerated`.
- **Example:**
  ```swift
  if sewer.isDegenerated(edge) { print("degenerate") }
  ```

---

### `SewingBuilder.isSectionBound(_:)`

Check if an edge is a section boundary after sewing.

```swift
public func isSectionBound(_ edge: Shape) -> Bool
```

- **Returns:** `true` if the edge is a boundary of a sewed section.
- **OCCT:** `BRepBuilderAPI_Sewing::IsSectionBound`.
- **Example:**
  ```swift
  sewer.isSectionBound(edge)
  ```

---

### `SewingBuilder.whichFace(_:)`

Get the face that contains the given edge after sewing.

```swift
public func whichFace(_ edge: Shape) -> Shape?
```

- **Parameters:** `edge` — an edge in the sewed result.
- **Returns:** The enclosing face, or `nil`.
- **OCCT:** `BRepBuilderAPI_Sewing::WhichFace`.
- **Example:**
  ```swift
  if let f = sewer.whichFace(edge) { print("edge belongs to face") }
  ```

---

### `SewingBuilder.load(_:)`

Load a base shape as additional context for sewing (multi-part scenarios).

```swift
public func load(_ shape: Shape)
```

- **Parameters:** `shape` — the shape to load as base context.
- **OCCT:** `BRepBuilderAPI_Sewing::Load`.
- **Example:**
  ```swift
  sewer.load(baseShape)
  ```

---

### `SewingBuilder.setNonManifoldMode(_:)`

Enable or disable non-manifold sewing mode.

```swift
public func setNonManifoldMode(_ enabled: Bool)
```

- **Parameters:** `enabled` — `true` to allow non-manifold results.
- **OCCT:** `BRepBuilderAPI_Sewing::SetNonManifoldMode`.
- **Example:**
  ```swift
  sewer.setNonManifoldMode(true)
  ```

---

### `SewingBuilder.setFaceMode(_:)`

Enable or disable face analysis mode.

```swift
public func setFaceMode(_ enabled: Bool)
```

- **Parameters:** `enabled` — `true` to analyse free faces.
- **OCCT:** `BRepBuilderAPI_Sewing::SetFaceMode`.
- **Example:**
  ```swift
  sewer.setFaceMode(true)
  ```

---

### `SewingBuilder.setFloatingEdgesMode(_:)`

Enable or disable floating-edges mode.

```swift
public func setFloatingEdgesMode(_ enabled: Bool)
```

- **Parameters:** `enabled` — `true` to include floating edges in the result.
- **OCCT:** `BRepBuilderAPI_Sewing::SetFloatingEdgesMode`.
- **Example:**
  ```swift
  sewer.setFloatingEdgesMode(false)
  ```

---

### `SewingBuilder.setMinTolerance(_:)`

Set the minimum tolerance for sewing.

```swift
public func setMinTolerance(_ tolerance: Double)
```

- **Parameters:** `tolerance` — minimum sewing tolerance.
- **OCCT:** `BRepBuilderAPI_Sewing::SetMinTolerance`.
- **Example:**
  ```swift
  sewer.setMinTolerance(1e-7)
  ```

---

### `SewingBuilder.setMaxTolerance(_:)`

Set the maximum tolerance for sewing.

```swift
public func setMaxTolerance(_ tolerance: Double)
```

- **Parameters:** `tolerance` — maximum sewing tolerance.
- **OCCT:** `BRepBuilderAPI_Sewing::SetMaxTolerance`.
- **Example:**
  ```swift
  sewer.setMaxTolerance(0.1)
  ```

---

## ThruSectionsBuilder Extensions

Extensions on `ThruSectionsBuilder` added in v0.123.0.

### `ThruSectionsBuilder.checkCompatibility(_:)`

Enable or disable wire compatibility checking (reorders wires to avoid twists between sections).

```swift
public func checkCompatibility(_ check: Bool = true)
```

- **Parameters:** `check` — `true` to enable compatibility checking (default).
- **OCCT:** `BRepOffsetAPI_ThruSections::CheckCompatibility`.
- **Example:**
  ```swift
  let loft = ThruSectionsBuilder(isSolid: true)
  loft.checkCompatibility(true)
  ```

---

### `ThruSectionsBuilder.setParType(_:)`

Set the parameterization type for the loft approximation.

```swift
public func setParType(_ type: Int)
```

- **Parameters:** `type` — 0 = ChordLength, 1 = Centripetal, 2 = IsoParametric.
- **OCCT:** `BRepOffsetAPI_ThruSections::SetParType`.
- **Example:**
  ```swift
  loft.setParType(1)  // centripetal
  ```

---

### `ThruSectionsBuilder.setCriteriumWeight(w1:w2:w3:)`

Set the approximation criterion weights for the loft.

```swift
public func setCriteriumWeight(w1: Double, w2: Double, w3: Double)
```

- **Parameters:** `w1`, `w2`, `w3` — weights for the three approximation criteria.
- **OCCT:** `BRepOffsetAPI_ThruSections::SetCriteriumWeight`.
- **Example:**
  ```swift
  loft.setCriteriumWeight(w1: 1.0, w2: 0.5, w3: 0.5)
  ```

---

### `ThruSectionsBuilder.generatedFace(from:)`

Get the face generated from a profile edge after the loft is built.

```swift
public func generatedFace(from edge: Shape) -> Shape?
```

- **Parameters:** `edge` — a profile edge from one of the input wires.
- **Returns:** The generated face shape, or `nil` if not found.
- **OCCT:** `BRepOffsetAPI_ThruSections::GeneratedFace`.
- **Example:**
  ```swift
  if let loftFace = loft.generatedFace(from: profileEdge) { ... }
  ```

---

## CellsBuilder Extensions

Extensions on `CellsBuilder` added in v0.123.0.

### `CellsBuilder.addToResult(take:avoid:material:update:)`

Add cells to the result: cells present in all `take` shapes but absent from all `avoid` shapes.

```swift
public func addToResult(take: [Shape], avoid: [Shape] = [], material: Int32 = 0, update: Bool = false)
```

- **Parameters:** `take` — shapes whose cells to include; `avoid` — shapes whose cells to exclude; `material` — material tag; `update` — rebuild result immediately.
- **OCCT:** `BOPAlgo_CellsBuilder::AddToResult`.
- **Example:**
  ```swift
  cells.addToResult(take: [shapeA], avoid: [shapeB])
  ```

---

### `CellsBuilder.removeFromResult(take:avoid:)`

Remove cells from the result: cells present in all `take` shapes but absent from all `avoid` shapes.

```swift
public func removeFromResult(take: [Shape], avoid: [Shape] = [])
```

- **Parameters:** `take` — shapes identifying cells to remove; `avoid` — shapes to exclude from removal.
- **OCCT:** `BOPAlgo_CellsBuilder::RemoveFromResult`.
- **Example:**
  ```swift
  cells.removeFromResult(take: [shapeC])
  ```

---

### `CellsBuilder.allParts()`

Get all split parts before any result composition.

```swift
public func allParts() -> Shape?
```

- **Returns:** A compound of all split cells, or `nil` on failure.
- **OCCT:** `BOPAlgo_CellsBuilder::GetAllParts`.
- **Example:**
  ```swift
  if let parts = cells.allParts() { print(parts.faceCount) }
  ```

---

### `CellsBuilder.makeContainers()`

Convert accumulated parts into proper topology containers (wires from edges, shells from faces, etc.).

```swift
public func makeContainers()
```

- **OCCT:** `BOPAlgo_CellsBuilder::MakeContainers`.
- **Example:**
  ```swift
  cells.makeContainers()
  ```

---

## PipeShellStatus

Status code returned by `PipeShellBuilder.status` after a build attempt.

```swift
public enum PipeShellStatus: Int32, Sendable {
    case ok = 0
    case notOk = 1
    case planeNotIntersectGuide = 2
    case impossibleContact = 3
}
```

---

## PipeShellBuilder Extensions

Extensions on `PipeShellBuilder` added in v0.123.0.

### `PipeShellBuilder.status`

The current build status of the pipe shell.

```swift
public var status: PipeShellStatus
```

- **Returns:** A `PipeShellStatus` value.
- **OCCT:** `BRepOffsetAPI_MakePipeShell::GetStatus`.
- **Example:**
  ```swift
  if pipe.status == .ok { print("success") }
  ```

---

### `PipeShellBuilder.simulate(numberOfSections:)`

Simulate the pipe shell, generating intermediate cross-section wire shapes along the spine.

```swift
public func simulate(numberOfSections: Int) -> [Shape]
```

- **Parameters:** `numberOfSections` — number of cross-section samples to generate.
- **Returns:** An array of wire-shaped cross-sections along the spine; empty on failure.
- **OCCT:** `BRepOffsetAPI_MakePipeShell::Simulate`.
- **Example:**
  ```swift
  let sections = pipe.simulate(numberOfSections: 10)
  ```

---

## UnifySameDomain Builder

A builder that merges co-planar or co-cylindrical adjacent faces/edges in a shape.

### `UnifySameDomainBuilder.init(shape:unifyEdges:unifyFaces:concatBSplines:)`

Create a `UnifySameDomainBuilder` for the given shape.

```swift
public init(shape: Shape, unifyEdges: Bool = true, unifyFaces: Bool = true, concatBSplines: Bool = false)
```

- **Parameters:** `shape` — the input shape, left unchanged; `unifyEdges` — merge same-domain edges; `unifyFaces` — merge same-domain faces; `concatBSplines` — concatenate adjacent BSplines (note `Shape.unified(...)` defaults this to `true`, this initialiser to `false`).
- **OCCT:** `ShapeUpgrade_UnifySameDomain`.
- **Input is not modified:** the builder works on a private copy. `ShapeUpgrade_UnifySameDomain` rewrites sub-shapes of the shape it is given, and those rewrites reached the caller's own shape — so discarding the result was not enough to keep it (#446).
- **Example:**
  ```swift
  let unifier = UnifySameDomainBuilder(shape: body)
  unifier.setAngularTolerance(10.0 * .pi / 180)
  unifier.build()
  if let merged = unifier.shape, merged.isValidSolid { body = merged }
  // else: body is untouched, and usable
  ```

---

### `UnifySameDomainBuilder.allowInternalEdges(_:)`

Allow or disallow internal edges in the unified result.

```swift
public func allowInternalEdges(_ allow: Bool)
```

- **Parameters:** `allow` — `true` to keep internal edges.
- **OCCT:** `ShapeUpgrade_UnifySameDomain::AllowInternalEdges`.
- **Example:**
  ```swift
  unifier.allowInternalEdges(false)
  ```

---

### `UnifySameDomainBuilder.keepShape(_:)`

Prevent a specific sub-shape from being unified.

```swift
public func keepShape(_ shape: Shape)
```

- **Parameters:** `shape` — the sub-shape to preserve unchanged. Pass a sub-shape of the shape the builder was created with; it is matched to its counterpart in the builder's private copy for you (#446).
- **OCCT:** `ShapeUpgrade_UnifySameDomain::KeepShape`.
- **Example:**
  ```swift
  unifier.keepShape(importantEdge)
  ```

---

### `UnifySameDomainBuilder.setSafeInputMode(_:)`

Set OCCT's safe-input mode, which governs how freely the algorithm may rewrite the shape it is working on.

```swift
public func setSafeInputMode(_ safe: Bool)
```

- **Parameters:** `safe` — OCCT's own default is `true`.
- **OCCT:** `ShapeUpgrade_UnifySameDomain::SetSafeInputMode`.
- **This says nothing about your shape:** the builder always works on a private copy, so the shape passed to the initialiser is untouched either way. Safe mode does not fully protect the algorithm's own input in any case — `TransformPCurves` writes temporary pcurves onto it regardless (#446).
- **Example:**
  ```swift
  unifier.setSafeInputMode(true)
  ```

---

### `UnifySameDomainBuilder.setLinearTolerance(_:)`

Set the linear tolerance for unification.

```swift
public func setLinearTolerance(_ tol: Double)
```

- **Parameters:** `tol` — linear tolerance.
- **OCCT:** `ShapeUpgrade_UnifySameDomain::SetLinearTolerance`.
- **Example:**
  ```swift
  unifier.setLinearTolerance(1e-5)
  ```

---

### `UnifySameDomainBuilder.setAngularTolerance(_:)`

Set the angular tolerance for unification.

```swift
public func setAngularTolerance(_ tol: Double)
```

- **Parameters:** `tol` — angular tolerance in radians.
- **OCCT:** `ShapeUpgrade_UnifySameDomain::SetAngularTolerance`.
- **Example:**
  ```swift
  unifier.setAngularTolerance(1e-4)
  ```

---

### `UnifySameDomainBuilder.build()`

Perform the unification (must call before accessing `shape`).

```swift
public func build()
```

- **OCCT:** `ShapeUpgrade_UnifySameDomain::Build`.
- **Example:**
  ```swift
  unifier.build()
  ```

---

### `UnifySameDomainBuilder.shape`

The unified result shape after `build()`.

```swift
public var shape: Shape?
```

- **Returns:** The unified shape, or `nil` if the build has not been called or failed.
- **OCCT:** `ShapeUpgrade_UnifySameDomain::Shape`.
- **Example:**
  ```swift
  unifier.build()
  if let result = unifier.shape { print(result.isValid) }
  ```

---

## Section Ops on Shape

Static helpers on `Shape` for `BRepAlgoAPI_Section`, added in v0.123.0.

### `Shape.sectionWithOptions(_:_:approximation:computePCurve1:computePCurve2:)`

Compute the section (intersection wireframe) between two shapes with explicit options.

```swift
public static func sectionWithOptions(_ shape1: Shape, _ shape2: Shape,
                                       approximation: Bool = false,
                                       computePCurve1: Bool = false,
                                       computePCurve2: Bool = false) -> Shape?
```

- **Parameters:** `shape1`, `shape2` — the two shapes to intersect; `approximation` — approximate result curves as BSplines; `computePCurve1` — compute PCurves on `shape1`; `computePCurve2` — compute PCurves on `shape2`.
- **Returns:** A compound of intersection edges, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Section`.
- **Example:**
  ```swift
  if let section = Shape.sectionWithOptions(box, cylinder, approximation: true) {
      print(section.edgeCount)
  }
  ```

---

### `Shape.sectionAncestorFaceOn1(_:_:edge:approximation:computePCurve1:computePCurve2:)`

Get the ancestor face from `shape1` for a given section edge.

```swift
public static func sectionAncestorFaceOn1(_ shape1: Shape, _ shape2: Shape, edge: Shape,
                                           approximation: Bool = false,
                                           computePCurve1: Bool = false,
                                           computePCurve2: Bool = false) -> Shape?
```

- **Parameters:** `shape1`, `shape2` — the two intersection inputs; `edge` — a section result edge; remaining flags as in `sectionWithOptions`.
- **Returns:** The face on `shape1` that generated the edge, or `nil`.
- **OCCT:** `BRepAlgoAPI_Section::HasAncestorFaceOn1` / `AncestorFaceOn1`.
- **Example:**
  ```swift
  if let face = Shape.sectionAncestorFaceOn1(box, cyl, edge: sectionEdge) { ... }
  ```

---

### `Shape.sectionAncestorFaceOn2(_:_:edge:approximation:computePCurve1:computePCurve2:)`

Get the ancestor face from `shape2` for a given section edge.

```swift
public static func sectionAncestorFaceOn2(_ shape1: Shape, _ shape2: Shape, edge: Shape,
                                           approximation: Bool = false,
                                           computePCurve1: Bool = false,
                                           computePCurve2: Bool = false) -> Shape?
```

- **Parameters:** `shape1`, `shape2` — the two intersection inputs; `edge` — a section result edge.
- **Returns:** The face on `shape2` that generated the edge, or `nil`.
- **OCCT:** `BRepAlgoAPI_Section::HasAncestorFaceOn2` / `AncestorFaceOn2`.
- **Example:**
  ```swift
  if let face = Shape.sectionAncestorFaceOn2(box, cyl, edge: sectionEdge) { ... }
  ```

---

## Curve3D Extended Queries

Extensions on `Curve3D` added in v0.123.0.

### `Curve3D.firstParameter`

The first (lower bound) parameter of the curve's parametric domain.

```swift
public var firstParameter: Double
```

- **OCCT:** `Geom_Curve::FirstParameter`.
- **Example:**
  ```swift
  let t0 = curve.firstParameter
  ```

---

### `Curve3D.lastParameter`

The last (upper bound) parameter of the curve's parametric domain.

```swift
public var lastParameter: Double
```

- **OCCT:** `Geom_Curve::LastParameter`.
- **Example:**
  ```swift
  let t1 = curve.lastParameter
  ```

---

## Additional Shape Queries

Extensions on `Shape` added in v0.123.0.

### `Shape.nullified`

Return a null copy of this shape (a shape with the same type but no sub-shapes or geometry).

```swift
public var nullified: Shape?
```

- **Returns:** A nullified shape, or `nil` on failure.
- **OCCT:** `TopoDS_Shape::Nullify`.
- **Example:**
  ```swift
  if let empty = shape.nullified { print(empty.isNull) }
  ```

---

### `Shape.typeName`

The shape type as a human-readable string (e.g. `"Solid"`, `"Face"`, `"Edge"`).

```swift
public var typeName: String?
```

- **Returns:** The shape type name, or `nil` if the shape is null.
- **OCCT:** `TopoDS_Shape::ShapeType` → string mapping.
- **Example:**
  ```swift
  print(shape.typeName ?? "null")
  ```

---

### `Shape.isNotEqual(to:)`

Check whether this shape is NOT the same shape as `other` (by identity, not geometry).

```swift
public func isNotEqual(to other: Shape) -> Bool
```

- **Returns:** `true` if the two shapes are different.
- **OCCT:** `TopoDS_Shape::IsNotEqual`.
- **Example:**
  ```swift
  if shape.isNotEqual(to: otherShape) { print("different") }
  ```

---

### `Shape.emptied`

Return a copy of this shape with all sub-shapes removed but the same location and orientation.

```swift
public var emptied: Shape?
```

- **Returns:** The emptied shell shape, or `nil` on failure.
- **OCCT:** `TopoDS_Shape::EmptyCopied`.
- **Example:**
  ```swift
  if let shell = shape.emptied { ... }
  ```

---

### `Shape.moved(dx:dy:dz:)`

Translate this shape by the given vector and return a new shape.

```swift
public func moved(dx: Double, dy: Double, dz: Double) -> Shape?
```

- **Parameters:** `dx`, `dy`, `dz` — translation components.
- **Returns:** The translated shape, or `nil` on failure.
- **OCCT:** `gp_Trsf` translation → `BRepBuilderAPI_Transform`.
- **Example:**
  ```swift
  if let shifted = box.moved(dx: 10, dy: 0, dz: 0) { ... }
  ```

---

### `Shape.orientationValue`

The orientation of this shape as an integer: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL.

```swift
public var orientationValue: Int
```

- **OCCT:** `TopoDS_Shape::Orientation`.
- **Example:**
  ```swift
  print(shape.orientationValue) // 0 = FORWARD
  ```

---

`Shape.nbEdges`, `Shape.nbFaces` and `Shape.nbVertices` (#651) counted bare `TopExp_Explorer`
occurrences (24/6/48 on a 12-edge/6-face/8-vertex box; `nbFaces` agreed with `faceCount` only on a
shape with no shared face), against this page's own documentation of the distinct count. Deprecated
as forwards to [`edgeCount`](Edge.md#edgecount), [`faceCount`](Selection.md#shapefacecount) and
[`vertexCount`](Shape-Features.md#vertexcount), and removed at v2.0.0 (#784). Use those three
directly.

---

## XCAFDoc_ColorTool Completions on Document

Extensions on `Document` providing additional `XCAFDoc_ColorTool` operations, added in v0.126.0.

### `Document.colorToolAddColor(r:g:b:)`

Add an RGB color to the document color table.

```swift
public func colorToolAddColor(r: Double, g: Double, b: Double) -> Int64
```

- **Parameters:** `r`, `g`, `b` — red, green, blue components in [0, 1].
- **Returns:** The label tag of the new color entry, or -1 on failure.
- **OCCT:** `XCAFDoc_ColorTool::AddColor`.
- **Example:**
  ```swift
  let redId = doc.colorToolAddColor(r: 1, g: 0, b: 0)
  ```

---

### `Document.colorToolRemoveColor(labelId:)`

Remove a color from the document color table by label ID.

```swift
@discardableResult
public func colorToolRemoveColor(labelId: Int64) -> Bool
```

- **Parameters:** `labelId` — the label tag of the color to remove.
- **Returns:** `true` if removed.
- **OCCT:** `XCAFDoc_ColorTool::RemoveColor`.
- **Example:**
  ```swift
  doc.colorToolRemoveColor(labelId: redId)
  ```

---

### `Document.colorToolColorCount`

The number of colors in the document color table.

```swift
public var colorToolColorCount: Int
```

- **OCCT:** `XCAFDoc_ColorTool::GetColors` → count.
- **Example:**
  ```swift
  print(doc.colorToolColorCount)
  ```

---

### `Document.colorToolUnSetColor(labelId:colorType:)`

Remove the color of a specific type from a label.

```swift
@discardableResult
public func colorToolUnSetColor(labelId: Int64, colorType: Int) -> Bool
```

- **Parameters:** `labelId` — the shape label; `colorType` — 0 = generic, 1 = surface, 2 = curve.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_ColorTool::UnSetColor`.
- **Example:**
  ```swift
  doc.colorToolUnSetColor(labelId: partId, colorType: 1)
  ```

---

### `Document.colorToolIsVisible(labelId:)`

Check whether a label is visible.

```swift
public func colorToolIsVisible(labelId: Int64) -> Bool
```

- **Returns:** `true` if visible.
- **OCCT:** `XCAFDoc_ColorTool::IsVisible`.
- **Example:**
  ```swift
  if doc.colorToolIsVisible(labelId: partId) { ... }
  ```

---

### `Document.colorToolSetVisibility(labelId:visible:)`

Set the visibility of a label.

```swift
@discardableResult
public func colorToolSetVisibility(labelId: Int64, visible: Bool) -> Bool
```

- **Parameters:** `labelId` — the label; `visible` — `true` to show, `false` to hide.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_ColorTool::SetVisibility`.
- **Example:**
  ```swift
  doc.colorToolSetVisibility(labelId: partId, visible: false)
  ```

---

### `Document.colorToolIsColorByLayer(labelId:)`

Check whether the color of a label is defined by its layer.

```swift
public func colorToolIsColorByLayer(labelId: Int64) -> Bool
```

- **Returns:** `true` if the color is inherited from the layer.
- **OCCT:** `XCAFDoc_ColorTool::IsColorByLayer`.
- **Example:**
  ```swift
  doc.colorToolIsColorByLayer(labelId: partId)
  ```

---

### `Document.colorToolSetColorByLayer(labelId:isByLayer:)`

Set or unset the color-by-layer flag on a label.

```swift
@discardableResult
public func colorToolSetColorByLayer(labelId: Int64, isByLayer: Bool) -> Bool
```

- **Parameters:** `labelId` — the label; `isByLayer` — `true` to inherit color from layer.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_ColorTool::SetColorByLayer`.
- **Example:**
  ```swift
  doc.colorToolSetColorByLayer(labelId: partId, isByLayer: true)
  ```

---

### `Document.colorToolFindColor(r:g:b:)`

Search for a color in the color table by RGB value.

```swift
public func colorToolFindColor(r: Double, g: Double, b: Double) -> Int64
```

- **Parameters:** `r`, `g`, `b` — red, green, blue components in [0, 1].
- **Returns:** The label tag if found, or -1.
- **OCCT:** `XCAFDoc_ColorTool::FindColor`.
- **Example:**
  ```swift
  let existing = doc.colorToolFindColor(r: 1, g: 0, b: 0)
  ```

---

### `Document.colorToolSetInstanceColor(shape:colorType:r:g:b:)`

Set the instance color of a shape component (overrides the referenced shape's color for this instance).

```swift
@discardableResult
public func colorToolSetInstanceColor(shape: Shape, colorType: Int, r: Double, g: Double, b: Double) -> Bool
```

- **Parameters:** `shape` — the component shape; `colorType` — 0/1/2; `r`, `g`, `b` — RGB.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_ColorTool::SetInstanceColor`.
- **Example:**
  ```swift
  doc.colorToolSetInstanceColor(shape: component, colorType: 1, r: 0, g: 1, b: 0)
  ```

---

### `Document.colorToolGetInstanceColor(shape:colorType:)`

Get the instance color of a shape component.

```swift
public func colorToolGetInstanceColor(shape: Shape, colorType: Int) -> (r: Double, g: Double, b: Double)?
```

- **Parameters:** `shape` — the component; `colorType` — 0/1/2.
- **Returns:** An `(r, g, b)` tuple in [0, 1], or `nil` if no instance color is set.
- **OCCT:** `XCAFDoc_ColorTool::GetInstanceColor`.
- **Example:**
  ```swift
  if let color = doc.colorToolGetInstanceColor(shape: component, colorType: 1) {
      print(color.r, color.g, color.b)
  }
  ```

---

## XCAFDoc_ShapeTool Completions on Document

Extensions on `Document` providing additional `XCAFDoc_ShapeTool` operations, added in v0.126.0.

### `Document.shapeToolIsFree(labelId:)`

Check whether a label is a free shape (top-level, not referenced by other shapes).

```swift
public func shapeToolIsFree(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsFree`.
- **Example:**
  ```swift
  if doc.shapeToolIsFree(labelId: id) { print("top-level") }
  ```

---

### `Document.shapeToolIsSimpleShape(labelId:)`

Check whether a label is a simple shape (not an assembly, not a compound).

```swift
public func shapeToolIsSimpleShape(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsSimpleShape`.
- **Example:**
  ```swift
  doc.shapeToolIsSimpleShape(labelId: id)
  ```

---

### `Document.shapeToolIsComponent(labelId:)`

Check whether a label is a component (a reference to another shape label).

```swift
public func shapeToolIsComponent(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsComponent`.
- **Example:**
  ```swift
  doc.shapeToolIsComponent(labelId: id)
  ```

---

### `Document.shapeToolIsCompound(labelId:)`

Check whether a label is a compound shape.

```swift
public func shapeToolIsCompound(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsCompound`.
- **Example:**
  ```swift
  doc.shapeToolIsCompound(labelId: id)
  ```

---

### `Document.shapeToolIsSubShape(labelId:)`

Check whether a label represents a sub-shape of another label.

```swift
public func shapeToolIsSubShape(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsSubShape`.
- **Example:**
  ```swift
  doc.shapeToolIsSubShape(labelId: id)
  ```

---

### `Document.shapeToolIsExternRef(labelId:)`

Check whether a label is an external reference.

```swift
public func shapeToolIsExternRef(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsExternRef`.
- **Example:**
  ```swift
  doc.shapeToolIsExternRef(labelId: id)
  ```

---

### `Document.shapeToolGetUsers(labelId:)`

Get the number of users (references) of a shape label.

```swift
public func shapeToolGetUsers(labelId: Int64) -> Int
```

- **Returns:** The count of labels that reference this one.
- **OCCT:** `XCAFDoc_ShapeTool::GetUsers`.
- **Example:**
  ```swift
  print(doc.shapeToolGetUsers(labelId: id))
  ```

---

### `Document.shapeToolComputeShapes(labelId:)`

Trigger a shape computation/update on a label (refreshes cached shape data).

```swift
public func shapeToolComputeShapes(labelId: Int64)
```

- **OCCT:** `XCAFDoc_ShapeTool::ComputeShapes`.
- **Example:**
  ```swift
  doc.shapeToolComputeShapes(labelId: id)
  ```

---

### `Document.shapeToolNbComponents(labelId:getSubChildren:)`

Get the number of direct components of an assembly label.

```swift
public func shapeToolNbComponents(labelId: Int64, getSubChildren: Bool = false) -> Int
```

- **Parameters:** `labelId` — the assembly label; `getSubChildren` — if `true`, recurse into sub-assemblies.
- **Returns:** Component count.
- **OCCT:** `XCAFDoc_ShapeTool::NbComponents`.
- **Example:**
  ```swift
  let count = doc.shapeToolNbComponents(labelId: assemblyId)
  ```

---

## ColorTool Completions v0.127.0

### `Document.colorToolGetAllColors()`

Get the label IDs of all colors defined in the document color table.

```swift
public func colorToolGetAllColors() -> [Int64]
```

- **Returns:** An array of label IDs; empty if no colors are defined.
- **OCCT:** `XCAFDoc_ColorTool::GetColors`.
- **Example:**
  ```swift
  let colorIds = doc.colorToolGetAllColors()
  for id in colorIds {
      print(doc.colorToolIsVisible(labelId: id))
  }
  ```

---

## FilletBuilder History Queries

Extensions on `FilletBuilder` added in v0.127.0.

All three are keyed by an `(contour index, edge)` pair, take the `Edge` type the rest of
`FilletBuilder` speaks, and answer "there is no law" the same way (`nil`, or `false` for `setLaw`)
in the same four cases (#505):

| rejected because | detail |
|---|---|
| no such contour | `contour` outside `1...contourCount`. OCCT checks only the upper end. |
| the contour does not hold `edge` | including an edge in no contour at all, and an edge from a *different* contour. |
| the spine is not split yet | before `build()`, or before `simulate(contour:)`. |
| the radius is constant | OCCT stores a constant radius as no law rather than as a flat one; ask `isConstant(contour:)`. |

### `FilletBuilder.getBounds(contour:edge:)`

Parameter bounds of the radius law on one edge of a contour, in the contour's own spine
parameterisation. After `build()` the range runs past both ends of the edge, because the blend
surface does.

```swift
public func getBounds(contour: Int, edge: Edge) -> (first: Double, last: Double)?
```

- **Parameters:** `contour` is a 1-based contour index; `edge` is an edge the contour holds.
- **Returns:** `(first, last)` parameter range, or `nil` (see the table above).
- **OCCT:** `BRepFilletAPI_MakeFillet::GetBounds`.
- **Example:**
  ```swift
  let builder = FilletBuilder(shape: box)!
  let edge = box.edges()[0]
  builder.addEdge(edge, radius1: 0.5, radius2: 2.0)   // evolving: there is a law
  _ = builder.build()
  if let bounds = builder.getBounds(contour: 1, edge: edge) {
      print(bounds.first, bounds.last)
  }
  ```

The `edge: Shape` spelling is deprecated: OCCT's own parameter is a `TopoDS_Edge`, so a `Shape` only
ever reached it through a downcast. Convert with `Edge(_:)` if a `Shape` is what you hold.

---

### `FilletBuilder.getLaw(contour:edge:)`

The law function controlling the fillet radius on one edge of a contour.

```swift
public func getLaw(contour: Int, edge: Edge) -> LawFunction?
```

- **Parameters:** `contour` is a 1-based contour index; `edge` is an edge the contour holds.
- **Returns:** A `LawFunction`, or `nil` (see the table above).
- **OCCT:** `BRepFilletAPI_MakeFillet::GetLaw`.
- **Example:**
  ```swift
  if let law = builder.getLaw(contour: 1, edge: edge) {
      print(law.value(at: law.bounds.lowerBound))   // 0.5, the radius at the start
  }
  ```

The `edge: Shape` spelling is deprecated, as for `getBounds`.

---

### `FilletBuilder.setLaw(contour:edge:law:)`

Assign the law function controlling the fillet radius along one edge of a contour.

```swift
@discardableResult
public func setLaw(contour: Int, edge: Edge, law: LawFunction) -> Bool
```

- **Parameters:** `contour` is a 1-based contour index; `edge` is an edge the contour holds; `law` is
  the radius law, over the range `getBounds(contour:edge:)` reports.
- **Returns:** `true` if the law was set, `false` in the four cases above.
- **OCCT:** `BRepFilletAPI_MakeFillet::SetLaw`.
- **Example:**
  ```swift
  let bounds = builder.getBounds(contour: 1, edge: edge)!
  let law = LawFunction.linear(from: 4, to: 4, parameterRange: bounds.first...bounds.last)!
  builder.setLaw(contour: 1, edge: edge, law: law)
  builder.getLaw(contour: 1, edge: edge)?.value(at: bounds.first)   // 4.0
  ```

`getLaw` reads the new law back, but it does not reach the geometry: measured against the pinned
kernel, a `build()` after this call reports success and hands back the *unfilleted* input shape, and
setting the law before the first build (via `simulate(contour:)`) then building produces the volume
the original `addEdge` radii give, not the one this law asks for
(`Scripts/repro/505-filletbuilder-edge-type/`). Treat it as editing the builder's recorded law.

---

### `FilletBuilder.generated(from:)`

Get the shapes generated from an input shape by the fillet operation (call after `build()`).

```swift
public func generated(from shape: Shape) -> [Shape]
```

- **Parameters:** `shape` — an input shape (typically an edge).
- **Returns:** Array of generated shapes (fillet faces, etc.).
- **OCCT:** `BRepFilletAPI_MakeFillet::Generated`.
- **Example:**
  ```swift
  let filletFaces = fillet.generated(from: myEdge)
  ```

---

### `FilletBuilder.modified(from:)`

Get the shapes modified from an input shape by the fillet operation (call after `build()`).

```swift
public func modified(from shape: Shape) -> [Shape]
```

- **Parameters:** `shape` — an input shape (typically a face).
- **Returns:** Array of modified shapes.
- **OCCT:** `BRepFilletAPI_MakeFillet::Modified`.
- **Example:**
  ```swift
  let modFaces = fillet.modified(from: originalFace)
  ```

---

### `FilletBuilder.isDeleted(_:)`

Check whether an input shape was deleted by the fillet operation (call after `build()`).

```swift
public func isDeleted(_ shape: Shape) -> Bool
```

- **Returns:** `true` if the shape no longer exists in the result.
- **OCCT:** `BRepFilletAPI_MakeFillet::IsDeleted`.
- **Example:**
  ```swift
  if fillet.isDeleted(smallEdge) { print("edge was consumed") }
  ```

---

## ChamferBuilder History & Extras

Extensions on `ChamferBuilder` added in v0.128.0.

### `ChamferBuilder.generated(from:)`

Get the shapes generated from an input shape by the chamfer operation.

```swift
public func generated(from shape: Shape) -> [Shape]
```

- **Parameters:** `shape` — an input edge or face.
- **Returns:** Array of generated shapes.
- **OCCT:** `BRepFilletAPI_MakeChamfer::Generated`.
- **Example:**
  ```swift
  let chamferFaces = chamfer.generated(from: myEdge)
  ```

---

### `ChamferBuilder.modified(from:)`

Get the shapes modified from an input shape by the chamfer operation.

```swift
public func modified(from shape: Shape) -> [Shape]
```

- **Parameters:** `shape` — an input face.
- **Returns:** Array of modified shapes.
- **OCCT:** `BRepFilletAPI_MakeChamfer::Modified`.
- **Example:**
  ```swift
  let modFaces = chamfer.modified(from: originalFace)
  ```

---

### `ChamferBuilder.isDeleted(_:)`

Check whether an input shape was deleted by the chamfer operation.

```swift
public func isDeleted(_ shape: Shape) -> Bool
```

- **Returns:** `true` if deleted.
- **OCCT:** `BRepFilletAPI_MakeChamfer::IsDeleted`.
- **Example:**
  ```swift
  chamfer.isDeleted(myEdge)
  ```

---

### `ChamferBuilder.ChamferMode`

The three available chamfer construction modes.

```swift
public enum ChamferMode: Int32, Sendable {
    case classic = 0
    case constThroat = 1
    case constThroatWithPenetration = 2
}
```

- `classic` — standard equal-distance chamfer.
- `constThroat` — constant throat width.
- `constThroatWithPenetration` — constant throat with surface penetration.

---

### `ChamferBuilder.setMode(_:)`

Set the chamfer construction mode.

```swift
public func setMode(_ mode: ChamferMode)
```

- **Parameters:** `mode` — the desired `ChamferMode`.
- **OCCT:** `BRepFilletAPI_MakeChamfer::SetMode`.
- **Example:**
  ```swift
  chamfer.setMode(.constThroat)
  ```

---

### `ChamferBuilder.simulate(contour:)`

Simulate the chamfer on a contour (1-based) without building; populates surface count.

```swift
@discardableResult
public func simulate(contour: Int) -> Bool
```

- **Parameters:** `contour` — 1-based contour index.
- **Returns:** `true` if simulation succeeded.
- **OCCT:** `BRepFilletAPI_MakeChamfer::Simulate`.
- **Example:**
  ```swift
  if chamfer.simulate(contour: 1) {
      print(chamfer.simulatedSurfaceCount(contour: 1))
  }
  ```

---

### `ChamferBuilder.simulatedSurfaceCount(contour:)`

Get the number of simulated chamfer surfaces on a contour (after calling `simulate`).

```swift
public func simulatedSurfaceCount(contour: Int) -> Int
```

- **Parameters:** `contour` — 1-based contour index.
- **Returns:** Number of surfaces that would be generated.
- **OCCT:** `BRepFilletAPI_MakeChamfer::NbSurf`.
- **Example:**
  ```swift
  let n = chamfer.simulatedSurfaceCount(contour: 1)
  ```

---

## SectionBuilder

A fine-grained builder for intersecting shapes, planes, and surfaces. Wraps `BRepAlgoAPI_Section` with explicit argument-setting and PCurve controls. Added in v0.128.0.

### `SectionBuilder.handle`

The opaque `OCCTSectionBuilderRef` handle this wrapper owns.

```swift
let handle: OCCTSectionBuilderRef
```

Internal, not part of the public API. Set at construction (`init()` or `init(shape1:shape2:)`) and released in `deinit` via `OCCTSectionBuilderRelease`.

---

### `SectionBuilder.init()`

Create an empty section builder (arguments set via `init1`/`init2`).

```swift
public init?()
```

- **Returns:** `nil` if internal allocation fails.
- **OCCT:** `BRepAlgoAPI_Section` default constructor.
- **Example:**
  ```swift
  guard let sb = SectionBuilder() else { return }
  ```

---

### `SectionBuilder.init(shape1:shape2:)`

Create a section builder pre-loaded with two shapes.

```swift
public init?(shape1: Shape, shape2: Shape)
```

- **Parameters:** `shape1`, `shape2` — the two shapes to section.
- **Returns:** `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Section(s1, s2)`.
- **Example:**
  ```swift
  if let sb = SectionBuilder(shape1: box, shape2: sphere) {
      if let result = sb.build() { print(result.edgeCount) }
  }
  ```

---

### `SectionBuilder.init1(shape:)`

Set the first argument as a shape.

```swift
public func init1(shape: Shape)
```

- **OCCT:** `BRepAlgoAPI_Section::Init1(TopoDS_Shape)`.
- **Example:**
  ```swift
  sb.init1(shape: box)
  ```

---

### `SectionBuilder.init1(plane:_:_:_:)`

Set the first argument as a plane defined by the equation `ax + by + cz + d = 0`.

```swift
public func init1(plane a: Double, _ b: Double, _ c: Double, _ d: Double)
```

- **Parameters:** `a`, `b`, `c`, `d` — plane equation coefficients.
- **OCCT:** `BRepAlgoAPI_Section::Init1(gp_Pln)`.
- **Example:**
  ```swift
  sb.init1(plane: 0, 0, 1, 0)  // XY plane (z=0)
  ```

---

### `SectionBuilder.init1(surface:)`

Set the first argument as a surface.

```swift
public func init1(surface: Surface)
```

- **OCCT:** `BRepAlgoAPI_Section::Init1(Geom_Surface)`.
- **Example:**
  ```swift
  sb.init1(surface: mySurface)
  ```

---

### `SectionBuilder.init2(shape:)`

Set the second argument as a shape.

```swift
public func init2(shape: Shape)
```

- **OCCT:** `BRepAlgoAPI_Section::Init2(TopoDS_Shape)`.
- **Example:**
  ```swift
  sb.init2(shape: sphere)
  ```

---

### `SectionBuilder.init2(plane:_:_:_:)`

Set the second argument as a plane defined by `ax + by + cz + d = 0`.

```swift
public func init2(plane a: Double, _ b: Double, _ c: Double, _ d: Double)
```

- **OCCT:** `BRepAlgoAPI_Section::Init2(gp_Pln)`.
- **Example:**
  ```swift
  sb.init2(plane: 0, 1, 0, -5)  // y=5 plane
  ```

---

### `SectionBuilder.init2(surface:)`

Set the second argument as a surface.

```swift
public func init2(surface: Surface)
```

- **OCCT:** `BRepAlgoAPI_Section::Init2(Geom_Surface)`.
- **Example:**
  ```swift
  sb.init2(surface: otherSurface)
  ```

---

### `SectionBuilder.setApproximation(_:)`

Toggle approximation of result curves as BSplines (default: `false`).

```swift
public func setApproximation(_ enabled: Bool)
```

- **OCCT:** `BRepAlgoAPI_Section::Approximation`.
- **Example:**
  ```swift
  sb.setApproximation(true)
  ```

---

### `SectionBuilder.computePCurveOn1(_:)`

Toggle computation of PCurves on the first shape/surface (default: `false`).

```swift
public func computePCurveOn1(_ enabled: Bool)
```

- **OCCT:** `BRepAlgoAPI_Section::ComputePCurveOn1`.
- **Example:**
  ```swift
  sb.computePCurveOn1(true)
  ```

---

### `SectionBuilder.computePCurveOn2(_:)`

Toggle computation of PCurves on the second shape/surface (default: `false`).

```swift
public func computePCurveOn2(_ enabled: Bool)
```

- **OCCT:** `BRepAlgoAPI_Section::ComputePCurveOn2`.
- **Example:**
  ```swift
  sb.computePCurveOn2(true)
  ```

---

### `SectionBuilder.build()`

Execute the section computation and return the result.

```swift
public func build() -> Shape?
```

- **Returns:** A compound of intersection edges, or `nil` on failure.
- **OCCT:** `BRepAlgoAPI_Section::Build` → `Shape`.
- **Example:**
  ```swift
  if let result = sb.build() {
      print(result.edgeCount)
  }
  ```

---

### `SectionBuilder.ancestorFaceOn1(edge:)`

Get the ancestor face from the first argument for a section result edge.

```swift
public func ancestorFaceOn1(edge: Shape) -> Shape?
```

- **Parameters:** `edge` — a section result edge.
- **Returns:** The face on the first argument that produced the edge, or `nil`.
- **OCCT:** `BRepAlgoAPI_Section::HasAncestorFaceOn1` / `AncestorFaceOn1`.
- **Example:**
  ```swift
  if let f = sb.ancestorFaceOn1(edge: e) { ... }
  ```

---

### `SectionBuilder.ancestorFaceOn2(edge:)`

Get the ancestor face from the second argument for a section result edge.

```swift
public func ancestorFaceOn2(edge: Shape) -> Shape?
```

- **Parameters:** `edge` — a section result edge.
- **Returns:** The face on the second argument that produced the edge, or `nil`.
- **OCCT:** `BRepAlgoAPI_Section::HasAncestorFaceOn2` / `AncestorFaceOn2`.
- **Example:**
  ```swift
  if let f = sb.ancestorFaceOn2(edge: e) { ... }
  ```

---

## GeomEval Standalone Evaluators

A namespace of static mathematical evaluators for analytical 3D curves and surfaces that compute function values without creating persistent OCCT geometry objects. Added in v0.130.0.

### 3D Curves

### `GeomEval.circularHelixD0(radius:pitch:u:)`

Evaluate a circular helix at parameter `u`: `C(t) = R·cos(t)·X + R·sin(t)·Y + (P·t/(2π))·Z`.

```swift
public static func circularHelixD0(radius: Double, pitch: Double, u: Double) -> SIMD3<Double>
```

- **Parameters:** `radius` — helix radius; `pitch` — axial advance per full turn; `u` — parameter.
- **Returns:** 3D point on the helix.
- **OCCT:** Custom bridge (`OCCTGeomEvalCircularHelixD0`) — analytical evaluation.
- **Example:**
  ```swift
  let pt = GeomEval.circularHelixD0(radius: 5, pitch: 2, u: .pi)
  ```

---

### `GeomEval.circularHelixD1(radius:pitch:u:)`

Evaluate a circular helix point and first derivative at `u`.

```swift
public static func circularHelixD1(radius: Double, pitch: Double, u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>)
```

- **Returns:** Tuple of `(point, d1)` — position and tangent vector.
- **OCCT:** `OCCTGeomEvalCircularHelixD1`.
- **Example:**
  ```swift
  let (pt, tangent) = GeomEval.circularHelixD1(radius: 5, pitch: 2, u: 0)
  ```

---

### `GeomEval.circularHelixD2(radius:pitch:u:)`

Evaluate a circular helix point, first, and second derivatives at `u`.

```swift
public static func circularHelixD2(radius: Double, pitch: Double, u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>)
```

- **Returns:** Tuple of `(point, d1, d2)`.
- **OCCT:** `OCCTGeomEvalCircularHelixD2`.
- **Example:**
  ```swift
  let (pt, d1, d2) = GeomEval.circularHelixD2(radius: 5, pitch: 2, u: 0)
  ```

---

### `GeomEval.sineWaveD0(amplitude:omega:phase:u:)`

Evaluate a 3D sine wave at parameter `u`: `C(t) = t·X + A·sin(ω·t + φ)·Y`.

```swift
public static func sineWaveD0(amplitude: Double, omega: Double, phase: Double, u: Double) -> SIMD3<Double>
```

- **Parameters:** `amplitude` — wave amplitude; `omega` — angular frequency; `phase` — phase offset; `u` — parameter.
- **Returns:** 3D point on the wave.
- **OCCT:** `OCCTGeomEvalSineWaveD0`.
- **Example:**
  ```swift
  let pt = GeomEval.sineWaveD0(amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.5)
  ```

---

### `GeomEval.sineWaveD1(amplitude:omega:phase:u:)`

Evaluate a 3D sine wave point and first derivative at `u`.

```swift
public static func sineWaveD1(amplitude: Double, omega: Double, phase: Double, u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>)
```

- **Returns:** `(point, d1)` tuple.
- **OCCT:** `OCCTGeomEvalSineWaveD1`.
- **Example:**
  ```swift
  let (pt, d1) = GeomEval.sineWaveD1(amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.25)
  ```

---

### Surfaces

### `GeomEval.ellipsoidD0(a:b:c:u:v:)`

Evaluate an ellipsoid at `(u, v)`: `P(u,v) = A·cos(v)·cos(u)·X + B·cos(v)·sin(u)·Y + C·sin(v)·Z`.

```swift
public static func ellipsoidD0(a: Double, b: Double, c: Double, u: Double, v: Double) -> SIMD3<Double>
```

- **Parameters:** `a`, `b`, `c` — semi-axes along X, Y, Z; `u`, `v` — longitude, latitude parameters.
- **Returns:** 3D point on the ellipsoid.
- **OCCT:** `OCCTGeomEvalEllipsoidD0`.
- **Example:**
  ```swift
  let pt = GeomEval.ellipsoidD0(a: 3, b: 2, c: 1, u: 0, v: 0)
  ```

---

### `GeomEval.hyperboloidD0(r1:r2:twoSheets:u:v:)`

Evaluate a hyperboloid at `(u, v)`.

```swift
public static func hyperboloidD0(r1: Double, r2: Double, twoSheets: Bool, u: Double, v: Double) -> SIMD3<Double>
```

- **Parameters:** `r1`, `r2` — radii; `twoSheets` — `false` = one-sheet, `true` = two-sheet hyperboloid; `u`, `v` — parameters.
- **Returns:** 3D point on the hyperboloid.
- **OCCT:** `OCCTGeomEvalHyperboloidD0`.
- **Example:**
  ```swift
  let pt = GeomEval.hyperboloidD0(r1: 2, r2: 1, twoSheets: false, u: 0, v: 0)
  ```

---

### `GeomEval.paraboloidD0(focal:u:v:)`

Evaluate a paraboloid at `(u, v)`.

```swift
public static func paraboloidD0(focal: Double, u: Double, v: Double) -> SIMD3<Double>
```

- **Parameters:** `focal` — focal distance; `u`, `v` — surface parameters.
- **Returns:** 3D point on the paraboloid.
- **OCCT:** `OCCTGeomEvalParaboloidD0`.
- **Example:**
  ```swift
  let pt = GeomEval.paraboloidD0(focal: 1.0, u: 0.5, v: 0.5)
  ```

---

### `GeomEval.circularHelicoidD0(pitch:u:v:)`

Evaluate a circular helicoid (screw surface) at `(u, v)`.

```swift
public static func circularHelicoidD0(pitch: Double, u: Double, v: Double) -> SIMD3<Double>
```

- **Parameters:** `pitch` — axial advance per 2π radians; `u` — angular parameter; `v` — radial parameter.
- **Returns:** 3D point on the helicoid.
- **OCCT:** `OCCTGeomEvalCircularHelicoidD0`.
- **Example:**
  ```swift
  let pt = GeomEval.circularHelicoidD0(pitch: 1.0, u: .pi, v: 1.0)
  ```

---

### `GeomEval.hyperbolicParaboloidD0(a:b:u:v:)`

Evaluate a hyperbolic paraboloid (saddle surface) at `(u, v)`.

```swift
public static func hyperbolicParaboloidD0(a: Double, b: Double, u: Double, v: Double) -> SIMD3<Double>
```

- **Parameters:** `a`, `b` — shape parameters; `u`, `v` — surface parameters.
- **Returns:** 3D point on the saddle surface.
- **OCCT:** `OCCTGeomEvalHypParaboloidD0`.
- **Example:**
  ```swift
  let pt = GeomEval.hyperbolicParaboloidD0(a: 1, b: 1, u: 0.5, v: -0.5)
  ```

---

## Geom2dEval Standalone Evaluators

A namespace of static evaluators for analytical 2D curves. Added in v0.130.0.

### `Geom2dEval.archimedeanSpiralD0(initialRadius:growthRate:u:)`

Evaluate an Archimedean spiral at `u`: `C(t) = (a + b·t)·cos(t)·X + (a + b·t)·sin(t)·Y`.

```swift
public static func archimedeanSpiralD0(initialRadius: Double, growthRate: Double, u: Double) -> SIMD2<Double>
```

- **Parameters:** `initialRadius` — `a`, the starting radius; `growthRate` — `b`, expansion per radian; `u` — parameter.
- **Returns:** 2D point on the spiral.
- **OCCT:** `OCCTGeom2dEvalArchimedeanSpiralD0`.
- **Example:**
  ```swift
  let pt = Geom2dEval.archimedeanSpiralD0(initialRadius: 1, growthRate: 0.1, u: 2 * .pi)
  ```

---

### `Geom2dEval.archimedeanSpiralD1(initialRadius:growthRate:u:)`

Evaluate an Archimedean spiral point and first derivative at `u`.

```swift
public static func archimedeanSpiralD1(initialRadius: Double, growthRate: Double, u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>)
```

- **Returns:** `(point, d1)` tuple.
- **OCCT:** `OCCTGeom2dEvalArchimedeanSpiralD1`.
- **Example:**
  ```swift
  let (pt, d1) = Geom2dEval.archimedeanSpiralD1(initialRadius: 1, growthRate: 0.1, u: .pi)
  ```

---

### `Geom2dEval.logarithmicSpiralD0(scale:growthExponent:u:)`

Evaluate a logarithmic (equiangular) spiral at `u`: `C(t) = a·exp(b·t)·cos(t)·X + a·exp(b·t)·sin(t)·Y`.

```swift
public static func logarithmicSpiralD0(scale: Double, growthExponent: Double, u: Double) -> SIMD2<Double>
```

- **Parameters:** `scale` — `a`, initial scale; `growthExponent` — `b`, exponential growth rate; `u` — parameter.
- **Returns:** 2D point on the spiral.
- **OCCT:** `OCCTGeom2dEvalLogSpiralD0`.
- **Example:**
  ```swift
  let pt = Geom2dEval.logarithmicSpiralD0(scale: 1, growthExponent: 0.2, u: 2 * .pi)
  ```

---

### `Geom2dEval.logarithmicSpiralD1(scale:growthExponent:u:)`

Evaluate a logarithmic spiral point and first derivative at `u`.

```swift
public static func logarithmicSpiralD1(scale: Double, growthExponent: Double, u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>)
```

- **Returns:** `(point, d1)` tuple.
- **OCCT:** `OCCTGeom2dEvalLogSpiralD1`.
- **Example:**
  ```swift
  let (pt, d1) = Geom2dEval.logarithmicSpiralD1(scale: 1, growthExponent: 0.2, u: .pi)
  ```

---

### `Geom2dEval.circleInvoluteD0(radius:u:)`

Evaluate a circle involute at `u`: `C(t) = R·(cos(t) + t·sin(t))·X + R·(sin(t) − t·cos(t))·Y`.

```swift
public static func circleInvoluteD0(radius: Double, u: Double) -> SIMD2<Double>
```

- **Parameters:** `radius` — base circle radius `R`; `u` — involute parameter.
- **Returns:** 2D point on the involute.
- **OCCT:** `OCCTGeom2dEvalCircleInvoluteD0`.
- **Note:** The circle involute is the curve traced by the endpoint of a taut string unwinding from a circle — widely used for gear tooth profiles.
- **Example:**
  ```swift
  let pt = Geom2dEval.circleInvoluteD0(radius: 10, u: 0.5)
  ```

---

### `Geom2dEval.circleInvoluteD1(radius:u:)`

Evaluate a circle involute point and first derivative at `u`.

```swift
public static func circleInvoluteD1(radius: Double, u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>)
```

- **Returns:** `(point, d1)` tuple.
- **OCCT:** `OCCTGeom2dEvalCircleInvoluteD1`.
- **Example:**
  ```swift
  let (pt, d1) = Geom2dEval.circleInvoluteD1(radius: 10, u: 0.5)
  ```

---

### `Geom2dEval.sineWaveD0(amplitude:omega:phase:u:)`

Evaluate a 2D sine wave at `u`: `C(t) = t·X + A·sin(ω·t + φ)·Y`.

```swift
public static func sineWaveD0(amplitude: Double, omega: Double, phase: Double, u: Double) -> SIMD2<Double>
```

- **Parameters:** `amplitude` — wave amplitude; `omega` — angular frequency; `phase` — phase shift; `u` — parameter.
- **Returns:** 2D point on the wave.
- **OCCT:** `OCCTGeom2dEvalSineWaveD0`.
- **Example:**
  ```swift
  let pt = Geom2dEval.sineWaveD0(amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.25)
  ```

---

### `Geom2dEval.sineWaveD1(amplitude:omega:phase:u:)`

Evaluate a 2D sine wave point and first derivative at `u`.

```swift
public static func sineWaveD1(amplitude: Double, omega: Double, phase: Double, u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>)
```

- **Returns:** `(point, d1)` tuple.
- **OCCT:** `OCCTGeom2dEvalSineWaveD1`.
- **Example:**
  ```swift
  let (pt, d1) = Geom2dEval.sineWaveD1(amplitude: 1, omega: 2 * .pi, phase: 0, u: 0.25)
  ```
