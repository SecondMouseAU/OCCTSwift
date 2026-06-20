---
title: Document
parent: API Reference
---

# Document

`Document` is OCCTSwift's XCAF/OCAF document type, wrapping OCCT's `TDocStd_Document` and the XDE layer (`XCAFDoc_DocumentTool`, `STEPCAFControl_Reader/Writer`). It preserves the full assembly hierarchy, names, colors, PBR materials, GD&T annotations, layer assignments, and OCAF attribute trees from STEP files — and lets you build or edit those structures programmatically. Obtain one via `Document.load(from:)` (STEP import), `Document.create()` (blank), or `Document.loadOCAF(from:)` (native OCAF/binary format).

> **Document is very large — documented across many pages.** This is the core (load/save, assembly structure, AssemblyNode, colors/materials, GD&T, core OCAF attributes); see the other **Document — …** pages for persistence/IO, XCAF tools, the OCAF attribute zoo, and the many low-level OCCT geometry/math wrappers exposed here.

## Topics

- [Loading](#loading) · [Assembly Structure](#assembly-structure) · [Convenience Methods](#convenience-methods) · [Writing](#writing) · [AssemblyNode](#assemblynode) · [GD&T / Dimensions and Tolerances](#gdt--dimensions-and-tolerances) · [TNaming: Topological Naming](#tnaming-topological-naming) · [Errors](#errors) · [Length Unit](#length-unit) · [Layers](#layers) · [Materials](#materials) · [TDF Label Properties](#tdf-label-properties) · [TDF Reference](#tdf-reference) · [TDF CopyLabel](#tdf-copylabel) · [Document Main Label](#document-main-label) · [Document Transactions](#document-transactions) · [Document Undo/Redo](#document-undoredo) · [Document Modified Labels](#document-modified-labels) · [TDataStd Scalar Attributes](#tdatastd-scalar-attributes) · [TDataStd Integer Array](#tdatastd-integer-array) · [TDataStd Real Array](#tdatastd-real-array) · [TDataStd TreeNode](#tdatastd-treenode) · [TDataStd NamedData](#tdatastd-nameddata) · [TDataXtd Shape Attribute](#tdataxtd-shape-attribute) · [TDataXtd Position Attribute](#tdataxtd-position-attribute) · [TDataXtd Geometry Attribute](#tdataxtd-geometry-attribute) · [TDataXtd Triangulation Attribute](#tdataxtd-triangulation-attribute) · [TDataXtd Point/Axis/Plane Attributes](#tdataxtd-pointaxisplane-attributes)

---

## Loading

### `Document.load(from:progress:)`

Load a STEP file with full XDE support (assembly structure, names, colors, materials).

```swift
public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Document
```

- **Parameters:** `url` — URL to the STEP file; `progress` — optional progress/cancellation channel.
- **Returns:** `Document` containing the assembly structure.
- **Throws:** `DocumentError.loadFailed` if loading fails; `ImportError.cancelled` if cancelled cooperatively.
- **OCCT:** `STEPCAFControl_Reader` with color, name, layer, props, and material modes enabled; `XCAFDoc_DocumentTool::ShapeTool/ColorTool/VisMaterialTool`.
- **Example:**
  ```swift
  guard let url = Bundle.main.url(forResource: "assembly", withExtension: "step") else { return }
  let doc = try Document.load(from: url)
  for node in doc.rootNodes {
      print(node.name ?? "<unnamed>", node.children.count)
  }
  ```

---

### `Document.loadSTEP(from:progress:)`

Alias for `load(from:progress:)` with explicit STEP naming.

```swift
public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Document
```

- **OCCT:** `STEPCAFControl_Reader` (same as `load(from:progress:)`).

---

### `Document.create()`

Create a new empty XCAF document.

```swift
public static func create() -> Document?
```

- **Returns:** A blank `Document` with empty shape, color, and material tools, or `nil` on failure.
- **OCCT:** `TDocStd_Application::NewDocument("MDTV-XCAF", …)` + `XCAFDoc_DocumentTool`.
- **Example:**
  ```swift
  guard let doc = Document.create() else { return }
  let labelId = doc.addShape(Shape.box(width: 10, height: 10, depth: 10)!)
  ```

---

## Assembly Structure

### `rootNodes`

Get the root nodes (top-level/free shapes) in the document.

```swift
public var rootNodes: [AssemblyNode] { get }
```

- **Returns:** Array of top-level `AssemblyNode` values. Assemblies have children; parts have a `shape`.
- **OCCT:** `XCAFDoc_ShapeTool` free-shape enumeration via `OCCTDocumentGetRootCount` / `OCCTDocumentGetRootLabelId`.
- **Example:**
  ```swift
  func printTree(_ node: AssemblyNode, indent: Int = 0) {
      print(String(repeating: "  ", count: indent) + (node.name ?? "<unnamed>"))
      for child in node.children { printTree(child, indent: indent + 1) }
  }
  doc.rootNodes.forEach { printTree($0) }
  ```

---

### `node(at:)`

Look up an `AssemblyNode` by its XCAF `labelId`.

```swift
public func node(at labelId: Int64) -> AssemblyNode?
```

`labelId` values are stable within a single `Document` instance; round-trip via `AssemblyNode.labelId`.

- **Parameters:** `labelId` — the identifier previously obtained from `rootNodes` traversal or a `shapeLabelId(at:)` call.
- **Returns:** The matching node, or `nil` if the `labelId` does not refer to a label in this document.
- **OCCT:** `TDF_Label` look-up in the document's label registry (`OCCTDocumentLabelIsNull`).
- **Example:**
  ```swift
  let id = doc.rootNodes.first?.labelId ?? -1
  if let node = doc.node(at: id) {
      print(node.name ?? "")
  }
  ```

---

## Convenience Methods

### `allShapes()`

Get all shapes from the document as a flat list (depth-first traversal).

```swift
public func allShapes() -> [Shape]
```

- **Returns:** Every `Shape` found by recursing `rootNodes`. Pure assemblies that have no direct geometry contribute no shapes.
- **Example:**
  ```swift
  let shapes = doc.allShapes()
  print("Total parts:", shapes.count)
  ```

---

### `shapesWithColors()`

Get all shapes with their associated colors.

```swift
public func shapesWithColors() -> [(shape: Shape, color: Color?)]
```

- **Returns:** Array of `(shape, color?)` pairs; `color` is `nil` for uncolored nodes.
- **Example:**
  ```swift
  for (shape, color) in doc.shapesWithColors() {
      if let c = color { print("color:", c.red, c.green, c.blue) }
  }
  ```

---

### `shapesWithMaterials()`

Get all shapes with their associated PBR materials.

```swift
public func shapesWithMaterials() -> [(shape: Shape, material: Material?)]
```

- **Returns:** Array of `(shape, material?)` pairs; `material` is `nil` for nodes without a PBR material.

---

## Writing

### `write(to:)`

Write the document to a STEP file, preserving assembly structure, colors, and materials.

```swift
public func write(to url: URL) throws
```

- **Parameters:** `url` — output file URL.
- **Throws:** `DocumentError.writeFailed` if writing fails.
- **OCCT:** `STEPCAFControl_Writer` with color, name, layer, props, and material modes.
- **Example:**
  ```swift
  let out = URL(fileURLWithPath: "/tmp/export.step")
  try doc.write(to: out)
  ```

---

### `writeSTEP(to:progress:)`

Write the document to a STEP file with optional progress and cancellation.

```swift
public func writeSTEP(to url: URL, progress: ImportProgress?) throws
```

- **Parameters:** `url` — output URL; `progress` — optional progress/cancellation channel.
- **Throws:** `ImportError.cancelled` if cancelled; `ImportError.importFailed` on other failure.
- **OCCT:** `STEPCAFControl_Writer` (via `OCCTDocumentWriteSTEPProgress`).

---

## AssemblyNode

`AssemblyNode` represents a node in an XDE assembly tree — a part or sub-assembly in a STEP file with name, transform, color, PBR material, child nodes, and shape geometry.

```swift
public final class AssemblyNode: @unchecked Sendable
```

`AssemblyNode` holds an `unowned` reference to its parent `Document` and is invalidated when the document is released.

### `labelId`

The XCAF label identifier for this node.

```swift
public let labelId: Int64
```

Stable within a single `Document` instance; pass it back to `Document.node(at:)` to recover the node.

---

### `name`

The name of this node (from CAD software).

```swift
public var name: String? { get }
```

- **Returns:** The label name string, or `nil` if unnamed.
- **OCCT:** `TDataStd_Name` attribute on the label (via `OCCTDocumentGetLabelName`).

---

### `isAssembly`

Whether this node is an assembly (has children).

```swift
public var isAssembly: Bool { get }
```

- **OCCT:** `XCAFDoc_ShapeTool::IsAssembly` (via `OCCTDocumentIsAssembly`).

---

### `isReference`

Whether this node is a reference (instance of another shape).

```swift
public var isReference: Bool { get }
```

- **OCCT:** `XCAFDoc_ShapeTool::IsReference` (via `OCCTDocumentIsReference`).

---

### `transform`

Transform matrix (position/rotation relative to parent), as a column-major `simd_float4x4`.

```swift
public var transform: simd_float4x4 { get }
```

- **OCCT:** `XCAFDoc_Location` attribute (via `OCCTDocumentGetLocation`).

---

### `color`

Color assigned to this node (if any). Checks surface color first, then generic.

```swift
public var color: Color? { get }
```

- **Returns:** `Color` (RGBA in 0–1 range), or `nil` if no color is assigned.
- **OCCT:** `XCAFDoc_ColorTool::GetColor` with `XCAFDoc_ColorSurf` then `XCAFDoc_ColorGen`.

---

### `setColor(_:)`

Set the surface color on this node.

```swift
public func setColor(_ color: Color)
```

- **Parameters:** `color` — the color to assign.
- **OCCT:** `XCAFDoc_ColorTool::SetColor` with `XCAFDoc_ColorSurf` (via `OCCTDocumentSetLabelColor`).
- **Example:**
  ```swift
  node.setColor(Color(red: 1, green: 0, blue: 0, alpha: 1))
  ```

---

### `setColor(_:type:)`

Set the color on this node with a specific color type.

```swift
public func setColor(_ color: Color, type: OCCTColorType)
```

- **Parameters:** `color` — the color to assign; `type` — `OCCTColorTypeGeneric` (0), `OCCTColorTypeSurface` (1), or `OCCTColorTypeCurve` (2).
- **OCCT:** `XCAFDoc_ColorTool::SetColor` (via `OCCTDocumentSetLabelColor`).

---

### `setMaterial(_:)`

Set the PBR material on this node.

```swift
public func setMaterial(_ material: Material)
```

- **Parameters:** `material` — `Material` struct with base color, metallic, roughness, emissive, and transparency.
- **OCCT:** `XCAFDoc_VisMaterialTool::SetShapeMaterial` (via `OCCTDocumentSetLabelMaterial`).

---

### `material`

PBR material assigned to this node (if any).

```swift
public var material: Material? { get }
```

- **Returns:** `Material` with PBR properties, or `nil` if none is assigned.
- **OCCT:** `XCAFDoc_VisMaterialTool::GetShapeMaterial` (via `OCCTDocumentGetLabelMaterial`).

---

### `children`

Child nodes for assemblies.

```swift
public var children: [AssemblyNode] { get }
```

- **Returns:** Array of direct child `AssemblyNode` values; empty for leaf parts.
- **OCCT:** `TDF_Label` child iteration (via `OCCTDocumentGetChildCount` / `OCCTDocumentGetChildLabelId`).

---

### `shape`

The shape geometry with transform applied.

```swift
public var shape: Shape? { get }
```

- **Returns:** `Shape` with the node's `TopLoc_Location` baked in, or `nil` for pure assemblies with no direct geometry.
- **OCCT:** `XCAFDoc_ShapeTool::GetShape` + `TopLoc_Location` (via `OCCTDocumentGetShapeWithLocation`).

---

### `shapeWithoutTransform`

The shape geometry without transform (original definition).

```swift
public var shapeWithoutTransform: Shape? { get }
```

- **Returns:** The un-located shape, or `nil` if none is attached.
- **OCCT:** `XCAFDoc_ShapeTool::GetShape` without location (via `OCCTDocumentGetShape`).

---

### `referredNode`

For references, get the referred (prototype) node.

```swift
public var referredNode: AssemblyNode? { get }
```

- **Returns:** The prototype node this reference points to, or `nil` if `isReference` is `false`.
- **OCCT:** `XCAFDoc_ShapeTool::GetReferredShape` (via `OCCTDocumentGetReferredLabelId`).

---

## GD&T / Dimensions and Tolerances

Supporting types for GD&T data read from STEP files.

### `DimensionInfo`

Dimension information from STEP GD&T data.

```swift
public struct DimensionInfo: Sendable {
    public let type: Int32         // XCAFDimTolObjects_DimensionType
    public let value: Double       // primary dimension value
    public let lowerTolerance: Double
    public let upperTolerance: Double
}
```

---

### `GeomToleranceInfo`

Geometric tolerance information from STEP GD&T data.

```swift
public struct GeomToleranceInfo: Sendable {
    public let type: Int32   // XCAFDimTolObjects_GeomToleranceType
    public let value: Double
}
```

---

### `DatumInfo`

Datum reference information from STEP GD&T data.

```swift
public struct DatumInfo: Sendable {
    public let name: String   // e.g. "A", "B", "C"
}
```

---

### `dimensionCount`

Number of dimensions defined in this document.

```swift
public var dimensionCount: Int { get }
```

- **OCCT:** `XCAFDoc_DimTolTool::GetDimensionLabels` (via `OCCTDocumentGetDimensionCount`).

---

### `geomToleranceCount`

Number of geometric tolerances defined in this document.

```swift
public var geomToleranceCount: Int { get }
```

- **OCCT:** `XCAFDoc_DimTolTool` (via `OCCTDocumentGetGeomToleranceCount`).

---

### `datumCount`

Number of datums defined in this document.

```swift
public var datumCount: Int { get }
```

- **OCCT:** `XCAFDoc_DimTolTool` (via `OCCTDocumentGetDatumCount`).

---

### `dimension(at:)`

Get dimension info at the given index.

```swift
public func dimension(at index: Int) -> DimensionInfo?
```

- **Parameters:** `index` — zero-based dimension index.
- **Returns:** `DimensionInfo`, or `nil` if index is out of range.
- **OCCT:** `XCAFDimTolObjects_DimensionObject` (via `OCCTDocumentGetDimensionInfo`).

---

### `geomTolerance(at:)`

Get geometric tolerance info at the given index.

```swift
public func geomTolerance(at index: Int) -> GeomToleranceInfo?
```

- **Returns:** `GeomToleranceInfo`, or `nil` if index is out of range.
- **OCCT:** `XCAFDimTolObjects_GeomToleranceObject` (via `OCCTDocumentGetGeomToleranceInfo`).

---

### `datum(at:)`

Get datum info at the given index.

```swift
public func datum(at index: Int) -> DatumInfo?
```

- **Returns:** `DatumInfo`, or `nil` if index is out of range.
- **OCCT:** `XCAFDimTolObjects_DatumObject` (via `OCCTDocumentGetDatumInfo`).

---

### `dimensions`

All dimensions in this document.

```swift
public var dimensions: [DimensionInfo] { get }
```

---

### `geomTolerances`

All geometric tolerances in this document.

```swift
public var geomTolerances: [GeomToleranceInfo] { get }
```

---

### `datums`

All datums in this document.

```swift
public var datums: [DatumInfo] { get }
```

- **Example:**
  ```swift
  let doc = try Document.load(from: gdt_step_url)
  print("Dimensions:", doc.dimensions.count)
  print("Tolerances:", doc.geomTolerances.count)
  for datum in doc.datums { print("Datum:", datum.name) }
  ```

---

## TNaming: Topological Naming

Types and methods for persistent topological naming (`TNaming_NamedShape`, `TNaming_Builder`).

### `NamingEvolution`

Evolution type for topological naming history.

```swift
public enum NamingEvolution: Int32, Sendable {
    case primitive = 0   // Created from scratch (no predecessor)
    case generated = 1   // Generated from another shape
    case modify    = 2   // Modified (e.g. filleted edge)
    case delete    = 3   // Deleted
    case selected  = 4   // Named selection for persistent identification
}
```

---

### `NamingHistoryEntry`

A single entry in the naming history of a label.

```swift
public struct NamingHistoryEntry: Sendable {
    public let evolution: NamingEvolution
    public let hasOldShape: Bool
    public let hasNewShape: Bool
    public let isModification: Bool
}
```

---

### `createLabel(parent:)`

Create a new TDF label for naming history tracking.

```swift
public func createLabel(parent: AssemblyNode? = nil) -> AssemblyNode?
```

- **Parameters:** `parent` — parent node; pass `nil` to create under the document main label.
- **Returns:** `AssemblyNode` representing the new label, or `nil` on failure.
- **OCCT:** `TDF_Label::NewChild` (via `OCCTDocumentCreateLabel`).

---

### `recordNaming(on:evolution:oldShape:newShape:)`

Record a naming evolution on a label.

```swift
@discardableResult
public func recordNaming(on node: AssemblyNode, evolution: NamingEvolution,
                         oldShape: Shape? = nil, newShape: Shape? = nil) -> Bool
```

- **Parameters:**
  - `node` — the label to record on.
  - `evolution` — type of topological evolution.
  - `oldShape` — predecessor shape (`nil` for `.primitive`).
  - `newShape` — result shape (`nil` for `.delete`).
- **Returns:** `true` if recording succeeded.
- **OCCT:** `TNaming_Builder::Generated/Modify/Delete/Select` (via `OCCTDocumentNamingRecord`).

---

### `currentShape(on:)`

Get the current (most recent) shape on a label.

```swift
public func currentShape(on node: AssemblyNode) -> Shape?
```

- **OCCT:** `TNaming_Tool::CurrentShape` + `TNaming_NamedShape` (via `OCCTDocumentNamingGetCurrentShape`).

---

### `storedShape(on:)`

Get the stored shape on a label.

```swift
public func storedShape(on node: AssemblyNode) -> Shape?
```

- **OCCT:** `TNaming_Tool::GetShape` (via `OCCTDocumentNamingGetShape`).

---

### `namingEvolution(on:)`

Get the naming evolution type on a label.

```swift
public func namingEvolution(on node: AssemblyNode) -> NamingEvolution?
```

- **Returns:** The `NamingEvolution` case, or `nil` if no naming attribute exists.
- **OCCT:** `TNaming_NamedShape::Evolution` (via `OCCTDocumentNamingGetEvolution`).

---

### `namingHistory(on:)`

Get the full naming history on a label.

```swift
public func namingHistory(on node: AssemblyNode) -> [NamingHistoryEntry]
```

- **Returns:** Array of `NamingHistoryEntry` values ordered from oldest to newest.
- **OCCT:** `TNaming_Iterator` over `TNaming_NamedShape` (via `OCCTDocumentNamingHistoryCount` / `OCCTDocumentNamingGetHistoryEntry`).

---

### `oldShape(on:at:)`

Get the old (input) shape from a history entry.

```swift
public func oldShape(on node: AssemblyNode, at index: Int) -> Shape?
```

- **Parameters:** `index` — zero-based history index.
- **OCCT:** `TNaming_Iterator` (via `OCCTDocumentNamingGetOldShape`).

---

### `newShape(on:at:)`

Get the new (result) shape from a history entry.

```swift
public func newShape(on node: AssemblyNode, at index: Int) -> Shape?
```

- **OCCT:** `TNaming_Iterator` (via `OCCTDocumentNamingGetNewShape`).

---

### `tracedForward(from:scope:)`

Trace forward: find shapes generated/modified from the given shape.

```swift
public func tracedForward(from shape: Shape, scope: AssemblyNode) -> [Shape]
```

- **Parameters:** `shape` — the source shape; `scope` — label providing document scope.
- **Returns:** Shapes that were generated or modified from `shape` (up to 64).
- **OCCT:** `TNaming_Tool::GeneratedShape` / forward-tracing (via `OCCTDocumentNamingTraceForward`).

---

### `tracedBackward(from:scope:)`

Trace backward: find shapes that generated/preceded the given shape.

```swift
public func tracedBackward(from shape: Shape, scope: AssemblyNode) -> [Shape]
```

- **Parameters:** `shape` — the shape to trace back from; `scope` — label scope.
- **Returns:** Predecessor shapes (up to 64).
- **OCCT:** `TNaming_Tool` backward-tracing (via `OCCTDocumentNamingTraceBackward`).

---

### `selectShape(_:context:on:)`

Create a persistent named selection.

```swift
@discardableResult
public func selectShape(_ selection: Shape, context: Shape, on node: AssemblyNode) -> Bool
```

- **Parameters:** `selection` — sub-shape to select; `context` — containing shape; `node` — label to store on.
- **OCCT:** `TNaming_Builder::Select` (via `OCCTDocumentNamingSelect`).

---

### `resolveShape(on:)`

Resolve a previously selected shape after modifications.

```swift
public func resolveShape(on node: AssemblyNode) -> Shape?
```

- **Returns:** The resolved shape, or `nil` if resolution fails.
- **OCCT:** `TNaming_Selector::Solve` (via `OCCTDocumentNamingResolve`).

---

## Errors

### `DocumentError`

Errors that can occur when working with XDE documents.

```swift
public enum DocumentError: Error, LocalizedError {
    case loadFailed(url: URL)
    case writeFailed(url: URL)
}
```

`errorDescription` produces a human-readable message such as `"Failed to load STEP file: assembly.step"`.

---

## Length Unit

### `LengthUnit`

Length unit information from a document.

```swift
public struct LengthUnit: Sendable {
    public let scale: Double   // e.g. 1.0 for mm, 25.4 for inch, 1000.0 for m
    public let name: String    // e.g. "mm", "inch", "m"
}
```

---

### `lengthUnit`

Get the length unit of this document.

```swift
public var lengthUnit: LengthUnit? { get }
```

Common `scale` values: `1.0` = mm, `10.0` = cm, `1000.0` = m, `25.4` = inch.

- **Returns:** `LengthUnit` with scale and name, or `nil` if not set.
- **OCCT:** `STEPCAFControl_Reader` unit info (via `OCCTDocumentGetLengthUnit`).
- **Example:**
  ```swift
  if let unit = doc.lengthUnit {
      print("Unit:", unit.name, "scale:", unit.scale)
  }
  ```

---

## Layers

### `layerCount`

Number of layers in this document.

```swift
public var layerCount: Int { get }
```

- **OCCT:** `XCAFDoc_LayerTool` (via `OCCTDocumentGetLayerCount`).

---

### `layerName(at:)`

Get the name of a layer by index.

```swift
public func layerName(at index: Int) -> String?
```

- **Parameters:** `index` — zero-based layer index.
- **Returns:** Layer name, or `nil` if out of range.
- **OCCT:** `XCAFDoc_LayerTool` (via `OCCTDocumentGetLayerName`).

---

### `layerNames`

All layer names in this document.

```swift
public var layerNames: [String] { get }
```

- **Example:**
  ```swift
  print("Layers:", doc.layerNames.joined(separator: ", "))
  ```

---

## Materials

### `MaterialInfo`

Material information from a document.

```swift
public struct MaterialInfo: Sendable {
    public let name: String
    public let description: String
    public let density: Double
}
```

---

### `materialCount`

Number of materials in this document.

```swift
public var materialCount: Int { get }
```

- **OCCT:** `XCAFDoc_MaterialTool::GetMaterialLabels` (via `OCCTDocumentGetMaterialCount`).

---

### `materialInfo(at:)`

Get material info by index.

```swift
public func materialInfo(at index: Int) -> MaterialInfo?
```

- **Parameters:** `index` — zero-based material index.
- **Returns:** `MaterialInfo`, or `nil` if out of range.
- **OCCT:** `XCAFDoc_MaterialTool::GetMaterial` (via `OCCTDocumentGetMaterialInfo`).

---

### `materials`

All materials in this document.

```swift
public var materials: [MaterialInfo] { get }
```

- **Example:**
  ```swift
  for mat in doc.materials {
      print(mat.name, "density:", mat.density)
  }
  ```

---

## TDF Label Properties

Extensions on `AssemblyNode` exposing low-level `TDF_Label` properties.

### `tag`

The tag integer identifying this label among its siblings.

```swift
public var tag: Int32 { get }
```

- **OCCT:** `TDF_Label::Tag` (via `OCCTDocumentLabelTag`).

---

### `depth`

The depth of this label in the tree (root = 0, main = 1, etc.).

```swift
public var depth: Int32 { get }
```

- **OCCT:** `TDF_Label::Depth` (via `OCCTDocumentLabelDepth`).

---

### `isNull`

Whether this label is null.

```swift
public var isNull: Bool { get }
```

- **OCCT:** `TDF_Label::IsNull`.

---

### `isRoot`

Whether this label is the root label (`0:`).

```swift
public var isRoot: Bool { get }
```

- **OCCT:** `TDF_Label::IsRoot`.

---

### `father`

The parent (father) node of this label.

```swift
public var father: AssemblyNode? { get }
```

- **Returns:** The parent node, or `nil` if this is the root.
- **OCCT:** `TDF_Label::Father`.

---

### `root`

The root node of the data framework.

```swift
public var root: AssemblyNode? { get }
```

- **OCCT:** `TDF_Label::Root`.

---

### `hasAttribute`

Whether this label has any attributes.

```swift
public var hasAttribute: Bool { get }
```

- **OCCT:** `TDF_Label::HasAttribute`.

---

### `attributeCount`

The number of attributes on this label.

```swift
public var attributeCount: Int32 { get }
```

- **OCCT:** `TDF_Label::NbAttributes`.

---

### `hasChild`

Whether this label has any child labels.

```swift
public var hasChild: Bool { get }
```

- **OCCT:** `TDF_Label::HasChild`.

---

### `childCount`

The number of direct child labels.

```swift
public var childCount: Int32 { get }
```

- **OCCT:** `TDF_Label::NbChildren`.

---

### `findChild(tag:create:)`

Find or create a child label by tag.

```swift
public func findChild(tag: Int32, create: Bool = false) -> AssemblyNode?
```

- **Parameters:** `tag` — tag to search for; `create` — if `true`, create the child if it doesn't exist.
- **Returns:** The child node, or `nil` if not found and `create` is `false`.
- **OCCT:** `TDF_Label::FindChild`.

---

### `forgetAllAttributes(clearChildren:)`

Remove all attributes from this label.

```swift
public func forgetAllAttributes(clearChildren: Bool = true)
```

- **Parameters:** `clearChildren` — if `true`, also clears attributes on child labels.
- **OCCT:** `TDF_Label::ForgetAllAttributes`.

---

### `descendants(allLevels:)`

Get all descendant labels.

```swift
public func descendants(allLevels: Bool = false) -> [AssemblyNode]
```

- **Parameters:** `allLevels` — if `true`, recurse all descendants; if `false`, direct children only.
- **Returns:** Array of descendant nodes (up to 1,024).
- **OCCT:** `TDF_LabelSequence` recursive traversal (via `OCCTDocumentGetDescendantLabels`).

---

### `setName(_:)`

Set the name (`TDataStd_Name`) on this label.

```swift
@discardableResult
public func setName(_ name: String) -> Bool
```

- **Returns:** `true` if the name was set successfully.
- **OCCT:** `TDataStd_Name::Set` (via `OCCTDocumentSetLabelName`).

---

## TDF Reference

### `setReference(to:)`

Set a `TDF_Reference` from this label to another label.

```swift
@discardableResult
public func setReference(to target: AssemblyNode) -> Bool
```

- **OCCT:** `TDF_Reference::Set` (via `OCCTDocumentLabelSetReference`).

---

### `referencedLabel`

Get the label referenced by a `TDF_Reference` attribute on this label.

```swift
public var referencedLabel: AssemblyNode? { get }
```

- **Returns:** The referenced node, or `nil` if no `TDF_Reference` attribute exists.
- **OCCT:** `TDF_Reference::Get` (via `OCCTDocumentLabelGetReference`).

---

## TDF CopyLabel

### `copyLabel(from:to:)`

Copy a label and all its attributes to a destination label.

```swift
@discardableResult
public func copyLabel(from source: AssemblyNode, to destination: AssemblyNode) -> Bool
```

- **Parameters:** `source` — label to copy from; `destination` — label to copy to.
- **Returns:** `true` if the copy succeeded.
- **OCCT:** `TDF_CopyLabel` (via `OCCTDocumentCopyLabel`).

---

## Document Main Label

### `mainLabel`

The main label (`0:1`) of the document — the root of the user data tree.

```swift
public var mainLabel: AssemblyNode? { get }
```

- **OCCT:** `TDocStd_Document::Main()` (via `OCCTDocumentGetMainLabel`).
- **Example:**
  ```swift
  if let main = doc.mainLabel {
      _ = main.setName("MyModel")
  }
  ```

---

## Document Transactions

### `openTransaction()`

Open a new transaction (command) on the document.

```swift
public func openTransaction()
```

All changes made after this call can be committed or aborted.

- **OCCT:** `TDocStd_Document::NewCommand` (via `OCCTDocumentOpenTransaction`).

---

### `commitTransaction()`

Commit the current transaction.

```swift
@discardableResult
public func commitTransaction() -> Bool
```

- **Returns:** `true` if committed successfully.
- **OCCT:** `TDocStd_Document::CommitCommand`.

---

### `abortTransaction()`

Abort the current transaction, undoing all changes since `openTransaction()`.

```swift
public func abortTransaction()
```

- **OCCT:** `TDocStd_Document::AbortCommand`.

---

### `hasOpenTransaction`

Whether a transaction is currently open.

```swift
public var hasOpenTransaction: Bool { get }
```

- **OCCT:** `TDocStd_Document::HasOpenCommand`.
- **Example:**
  ```swift
  doc.openTransaction()
  _ = doc.mainLabel?.setName("Rev1")
  _ = doc.commitTransaction()
  ```

---

## Document Undo/Redo

### `setUndoLimit(_:)`

Set the maximum number of undo steps.

```swift
public func setUndoLimit(_ limit: Int)
```

Must be called before any transactions. Pass `0` to disable undo.

- **OCCT:** `TDocStd_Document::SetUndoLimit`.

---

### `undoLimit`

The maximum number of undo steps.

```swift
public var undoLimit: Int { get }
```

- **OCCT:** `TDocStd_Document::GetUndoLimit`.

---

### `undo()`

Perform undo (reverses the last committed transaction).

```swift
@discardableResult
public func undo() -> Bool
```

- **Returns:** `true` if undo was performed.
- **OCCT:** `TDocStd_Document::Undo`.

---

### `redo()`

Perform redo (reapplies the last undone transaction).

```swift
@discardableResult
public func redo() -> Bool
```

- **Returns:** `true` if redo was performed.
- **OCCT:** `TDocStd_Document::Redo`.

---

### `availableUndos`

The number of available undo steps.

```swift
public var availableUndos: Int { get }
```

- **OCCT:** `TDocStd_Document::GetAvailableUndos`.

---

### `availableRedos`

The number of available redo steps.

```swift
public var availableRedos: Int { get }
```

- **OCCT:** `TDocStd_Document::GetAvailableRedos`.
- **Example:**
  ```swift
  doc.setUndoLimit(10)
  doc.openTransaction()
  _ = doc.mainLabel?.setInteger(42)
  _ = doc.commitTransaction()
  print("Undos available:", doc.availableUndos)
  _ = doc.undo()
  ```

---

## Document Modified Labels

### `setModified(_:)`

Mark a label as modified.

```swift
public func setModified(_ node: AssemblyNode)
```

- **OCCT:** `TDocStd_Document::SetModified` (via `OCCTDocumentSetModified`).

---

### `clearModified()`

Clear all modification marks.

```swift
public func clearModified()
```

- **OCCT:** `TDocStd_Document::PurgeModified` (via `OCCTDocumentClearModified`).

---

### `isModified(_:)`

Check if a label is marked as modified.

```swift
public func isModified(_ node: AssemblyNode) -> Bool
```

- **OCCT:** `TDocStd_Document::IsModified` (via `OCCTDocumentIsLabelModified`).

---

## TDataStd Scalar Attributes

Extensions on `AssemblyNode` for `TDataStd` scalar attribute types.

### `setInteger(_:)`

Set an integer attribute (`TDataStd_Integer`) on this label.

```swift
@discardableResult
public func setInteger(_ value: Int32) -> Bool
```

- **OCCT:** `TDataStd_Integer::Set` (via `OCCTDocumentSetIntegerAttr`).

---

### `integer`

Get the integer attribute from this label.

```swift
public var integer: Int32? { get }
```

- **Returns:** The stored value, or `nil` if no `TDataStd_Integer` exists.
- **OCCT:** `TDataStd_Integer::Get` (via `OCCTDocumentGetIntegerAttr`).

---

### `setReal(_:)`

Set a real attribute (`TDataStd_Real`) on this label.

```swift
@discardableResult
public func setReal(_ value: Double) -> Bool
```

- **OCCT:** `TDataStd_Real::Set` (via `OCCTDocumentSetRealAttr`).

---

### `real`

Get the real attribute from this label.

```swift
public var real: Double? { get }
```

- **OCCT:** `TDataStd_Real::Get` (via `OCCTDocumentGetRealAttr`).

---

### `setAsciiString(_:)`

Set an ASCII string attribute (`TDataStd_AsciiString`) on this label.

```swift
@discardableResult
public func setAsciiString(_ value: String) -> Bool
```

- **OCCT:** `TDataStd_AsciiString::Set` (via `OCCTDocumentSetAsciiStringAttr`).

---

### `asciiString`

Get the ASCII string attribute from this label.

```swift
public var asciiString: String? { get }
```

- **OCCT:** `TDataStd_AsciiString::Get` (via `OCCTDocumentGetAsciiStringAttr`).

---

### `setComment(_:)`

Set a comment attribute (`TDataStd_Comment`) on this label.

```swift
@discardableResult
public func setComment(_ value: String) -> Bool
```

- **OCCT:** `TDataStd_Comment::Set` (via `OCCTDocumentSetCommentAttr`).

---

### `comment`

Get the comment attribute from this label.

```swift
public var comment: String? { get }
```

- **OCCT:** `TDataStd_Comment::Get` (via `OCCTDocumentGetCommentAttr`).
- **Example:**
  ```swift
  guard let label = doc.createLabel() else { return }
  _ = label.setReal(3.14159)
  _ = label.setComment("pi approximation")
  print(label.real ?? 0, label.comment ?? "")
  ```

---

## TDataStd Integer Array

### `initIntegerArray(lower:upper:)`

Initialize an integer array attribute on this label.

```swift
@discardableResult
public func initIntegerArray(lower: Int32, upper: Int32) -> Bool
```

- **Parameters:** `lower`, `upper` — inclusive bounds of the array.
- **OCCT:** `TDataStd_IntegerArray::Init` (via `OCCTDocumentInitIntegerArray`).

---

### `setIntegerArrayValue(at:value:)`

Set a value in the integer array attribute.

```swift
@discardableResult
public func setIntegerArrayValue(at index: Int32, value: Int32) -> Bool
```

- **OCCT:** `TDataStd_IntegerArray::SetValue` (via `OCCTDocumentSetIntegerArrayValue`).

---

### `integerArrayValue(at:)`

Get a value from the integer array attribute.

```swift
public func integerArrayValue(at index: Int32) -> Int32?
```

- **Returns:** The value, or `nil` if the attribute doesn't exist or `index` is out of bounds.
- **OCCT:** `TDataStd_IntegerArray::Value` (via `OCCTDocumentGetIntegerArrayValue`).

---

### `integerArrayBounds`

Get the bounds of the integer array attribute.

```swift
public var integerArrayBounds: (lower: Int32, upper: Int32)? { get }
```

- **OCCT:** `TDataStd_IntegerArray::Lower/Upper` (via `OCCTDocumentGetIntegerArrayBounds`).
- **Example:**
  ```swift
  guard let label = doc.createLabel() else { return }
  _ = label.initIntegerArray(lower: 0, upper: 2)
  _ = label.setIntegerArrayValue(at: 0, value: 10)
  _ = label.setIntegerArrayValue(at: 1, value: 20)
  _ = label.setIntegerArrayValue(at: 2, value: 30)
  print(label.integerArrayValue(at: 1) ?? -1)  // 20
  ```

---

## TDataStd Real Array

### `initRealArray(lower:upper:)`

Initialize a real array attribute on this label.

```swift
@discardableResult
public func initRealArray(lower: Int32, upper: Int32) -> Bool
```

- **OCCT:** `TDataStd_RealArray::Init` (via `OCCTDocumentInitRealArray`).

---

### `setRealArrayValue(at:value:)`

Set a value in the real array attribute.

```swift
@discardableResult
public func setRealArrayValue(at index: Int32, value: Double) -> Bool
```

- **OCCT:** `TDataStd_RealArray::SetValue` (via `OCCTDocumentSetRealArrayValue`).

---

### `realArrayValue(at:)`

Get a value from the real array attribute.

```swift
public func realArrayValue(at index: Int32) -> Double?
```

- **OCCT:** `TDataStd_RealArray::Value` (via `OCCTDocumentGetRealArrayValue`).

---

### `realArrayBounds`

Get the bounds of the real array attribute.

```swift
public var realArrayBounds: (lower: Int32, upper: Int32)? { get }
```

- **OCCT:** `TDataStd_RealArray::Lower/Upper` (via `OCCTDocumentGetRealArrayBounds`).

---

## TDataStd TreeNode

### `setTreeNode()`

Set a tree node attribute (`TDataStd_TreeNode`) on this label.

```swift
@discardableResult
public func setTreeNode() -> Bool
```

- **OCCT:** `TDataStd_TreeNode::Set` (via `OCCTDocumentSetTreeNode`).

---

### `appendTreeChild(_:)`

Append a child to this tree node.

```swift
@discardableResult
public func appendTreeChild(_ child: AssemblyNode) -> Bool
```

- **OCCT:** `TDataStd_TreeNode::Append` (via `OCCTDocumentAppendTreeChild`).

---

### `treeNodeFather`

The father (parent) of this tree node.

```swift
public var treeNodeFather: AssemblyNode? { get }
```

- **OCCT:** `TDataStd_TreeNode::Father` (via `OCCTDocumentTreeNodeFather`).

---

### `treeNodeFirstChild`

The first child of this tree node.

```swift
public var treeNodeFirstChild: AssemblyNode? { get }
```

- **OCCT:** `TDataStd_TreeNode::First` (via `OCCTDocumentTreeNodeFirst`).

---

### `treeNodeNext`

The next sibling of this tree node.

```swift
public var treeNodeNext: AssemblyNode? { get }
```

- **OCCT:** `TDataStd_TreeNode::Next` (via `OCCTDocumentTreeNodeNext`).

---

### `treeNodeHasFather`

Whether this tree node has a father.

```swift
public var treeNodeHasFather: Bool { get }
```

- **OCCT:** `TDataStd_TreeNode::HasFather`.

---

### `treeNodeDepth`

The depth of this tree node (root = 0).

```swift
public var treeNodeDepth: Int32 { get }
```

- **OCCT:** `TDataStd_TreeNode::Depth`.

---

### `treeNodeChildCount`

The number of children of this tree node.

```swift
public var treeNodeChildCount: Int32 { get }
```

- **OCCT:** `TDataStd_TreeNode::NbChildren`.
- **Example:**
  ```swift
  guard let parent = doc.createLabel(),
        let child1 = doc.createLabel(),
        let child2 = doc.createLabel() else { return }
  _ = parent.setTreeNode()
  _ = child1.setTreeNode()
  _ = child2.setTreeNode()
  _ = parent.appendTreeChild(child1)
  _ = parent.appendTreeChild(child2)
  print("Children:", parent.treeNodeChildCount)  // 2
  ```

---

## TDataStd NamedData

### `setNamedInteger(_:value:)`

Set a named integer value on this label.

```swift
@discardableResult
public func setNamedInteger(_ name: String, value: Int32) -> Bool
```

- **OCCT:** `TDataStd_NamedData::SetInteger` (via `OCCTDocumentNamedDataSetInteger`).

---

### `namedInteger(_:)`

Get a named integer value from this label.

```swift
public func namedInteger(_ name: String) -> Int32?
```

- **OCCT:** `TDataStd_NamedData::GetInteger` (via `OCCTDocumentNamedDataGetInteger`).

---

### `hasNamedInteger(_:)`

Check if a named integer exists on this label.

```swift
public func hasNamedInteger(_ name: String) -> Bool
```

- **OCCT:** `TDataStd_NamedData::HasInteger`.

---

### `setNamedReal(_:value:)`

Set a named real value on this label.

```swift
@discardableResult
public func setNamedReal(_ name: String, value: Double) -> Bool
```

- **OCCT:** `TDataStd_NamedData::SetReal` (via `OCCTDocumentNamedDataSetReal`).

---

### `namedReal(_:)`

Get a named real value from this label.

```swift
public func namedReal(_ name: String) -> Double?
```

- **OCCT:** `TDataStd_NamedData::GetReal`.

---

### `hasNamedReal(_:)`

Check if a named real exists on this label.

```swift
public func hasNamedReal(_ name: String) -> Bool
```

---

### `setNamedString(_:value:)`

Set a named string value on this label.

```swift
@discardableResult
public func setNamedString(_ name: String, value: String) -> Bool
```

- **OCCT:** `TDataStd_NamedData::SetString` (via `OCCTDocumentNamedDataSetString`).

---

### `namedString(_:)`

Get a named string value from this label.

```swift
public func namedString(_ name: String) -> String?
```

- **OCCT:** `TDataStd_NamedData::GetString`.

---

### `hasNamedString(_:)`

Check if a named string exists on this label.

```swift
public func hasNamedString(_ name: String) -> Bool
```

- **Example:**
  ```swift
  guard let label = doc.createLabel() else { return }
  _ = label.setNamedReal("mass_kg", value: 2.75)
  _ = label.setNamedString("material", value: "Aluminium 6061")
  print(label.namedReal("mass_kg") ?? 0)        // 2.75
  print(label.namedString("material") ?? "")    // Aluminium 6061
  ```

---

## TDataXtd Shape Attribute

### `GeometryType`

Geometry type for `TDataXtd_Geometry` attributes.

```swift
public enum GeometryType: Int32 {
    case anyGeom  = 0
    case point    = 1
    case line     = 2
    case circle   = 3
    case ellipse  = 4
    case spline   = 5
    case plane    = 6
    case cylinder = 7
}
```

---

### `ExecutionStatus`

Execution status for `TFunction` graph nodes.

```swift
public enum ExecutionStatus: Int32 {
    case wrongDefinition = 0
    case notExecuted     = 1
    case executing       = 2
    case succeeded       = 3
    case failed          = 4
}
```

---

### `setShapeAttribute(_:)`

Set a shape attribute on this label (stores the shape via TNaming).

```swift
@discardableResult
public func setShapeAttribute(_ shape: Shape) -> Bool
```

- **OCCT:** `TDataXtd_Shape::Set` (via `OCCTDocumentSetShapeAttr`).

---

### `shapeAttribute()`

Get the shape stored in a `TDataXtd_Shape` attribute on this label.

```swift
public func shapeAttribute() -> Shape?
```

- **OCCT:** `TDataXtd_Shape::Get` (via `OCCTDocumentGetShapeAttr`).

---

### `hasShapeAttribute`

Check if this label has a `TDataXtd_Shape` attribute.

```swift
public var hasShapeAttribute: Bool { get }
```

- **OCCT:** `TDataXtd_Shape::Find`.

---

## TDataXtd Position Attribute

### `setPositionAttribute(x:y:z:)`

Set a position (3D point) attribute on this label.

```swift
@discardableResult
public func setPositionAttribute(x: Double, y: Double, z: Double) -> Bool
```

- **OCCT:** `TDataXtd_Position::Set` (via `OCCTDocumentSetPositionAttr`).

---

### `positionAttribute()`

Get the position attribute from this label.

```swift
public func positionAttribute() -> (x: Double, y: Double, z: Double)?
```

- **Returns:** The stored position, or `nil` if no attribute exists.
- **OCCT:** `TDataXtd_Position::Get` (via `OCCTDocumentGetPositionAttr`).

---

### `hasPositionAttribute`

Check if this label has a `TDataXtd_Position` attribute.

```swift
public var hasPositionAttribute: Bool { get }
```

---

## TDataXtd Geometry Attribute

### `setGeometryType(_:)`

Set a geometry type attribute on this label.

```swift
@discardableResult
public func setGeometryType(_ type: GeometryType) -> Bool
```

- **OCCT:** `TDataXtd_Geometry::Set` (via `OCCTDocumentSetGeometryAttr`).

---

### `geometryType()`

Get the geometry type from this label.

```swift
public func geometryType() -> GeometryType?
```

- **Returns:** The `GeometryType` case, or `nil` if no attribute exists.
- **OCCT:** `TDataXtd_Geometry::GetType` (via `OCCTDocumentGetGeometryType`).

---

### `hasGeometryAttribute`

Check if this label has a `TDataXtd_Geometry` attribute.

```swift
public var hasGeometryAttribute: Bool { get }
```

---

## TDataXtd Triangulation Attribute

### `setTriangulationFromShape(_:deflection:)`

Set a triangulation attribute on this label by meshing a shape.

```swift
@discardableResult
public func setTriangulationFromShape(_ shape: Shape, deflection: Double = 1.0) -> Bool
```

- **Parameters:** `shape` — the shape to tessellate; `deflection` — linear deflection for meshing (default `1.0`).
- **OCCT:** `BRepMesh_IncrementalMesh` + `TDataXtd_Triangulation::Set` (via `OCCTDocumentSetTriangulationFromShape`).

---

### `triangulationNodeCount`

Get the number of nodes in the triangulation attribute.

```swift
public var triangulationNodeCount: Int32 { get }
```

- **OCCT:** `Poly_Triangulation::NbNodes` (via `OCCTDocumentTriangulationNbNodes`).

---

### `triangulationTriangleCount`

Get the number of triangles in the triangulation attribute.

```swift
public var triangulationTriangleCount: Int32 { get }
```

- **OCCT:** `Poly_Triangulation::NbTriangles` (via `OCCTDocumentTriangulationNbTriangles`).

---

### `triangulationDeflection`

Get the deflection of the triangulation attribute.

```swift
public var triangulationDeflection: Double { get }
```

- **OCCT:** `Poly_Triangulation::Deflection` (via `OCCTDocumentTriangulationDeflection`).

---

## TDataXtd Point/Axis/Plane Attributes

### `setPointAttribute(x:y:z:)`

Set a point attribute on this label.

```swift
@discardableResult
public func setPointAttribute(x: Double, y: Double, z: Double) -> Bool
```

- **OCCT:** `TDataXtd_Point::Set` (via `OCCTDocumentSetPointAttr`).

---

### `setAxisAttribute(originX:originY:originZ:directionX:directionY:directionZ:)`

Set an axis attribute on this label (origin + direction).

```swift
@discardableResult
public func setAxisAttribute(originX: Double, originY: Double, originZ: Double,
                              directionX: Double, directionY: Double, directionZ: Double) -> Bool
```

- **OCCT:** `TDataXtd_Axis::Set` (via `OCCTDocumentSetAxisAttr`).

---

### `setPlaneAttribute(originX:originY:originZ:normalX:normalY:normalZ:)`

Set a plane attribute on this label (origin + normal).

```swift
@discardableResult
public func setPlaneAttribute(originX: Double, originY: Double, originZ: Double,
                               normalX: Double, normalY: Double, normalZ: Double) -> Bool
```

- **OCCT:** `TDataXtd_Plane::Set` (via `OCCTDocumentSetPlaneAttr`).
- **Example:**
  ```swift
  guard let label = doc.createLabel() else { return }
  _ = label.setPlaneAttribute(originX: 0, originY: 0, originZ: 5,
                               normalX: 0, normalY: 0, normalZ: 1)
  ```
