---
title: Document — Persistence, I/O & XDE Tools
parent: API Reference
---

# Document — Persistence, I/O & XDE Tools

This page covers the `Document` type's persistence (OCAF save/load), STEP/OBJ/PLY import-export, and XDE tooling (ShapeTool assembly management, ColorTool, LayerTool, XDE Editor, and the low-level `XCAFDoc_*` attribute types). For the core `Document` type, lifecycle, undo/redo, and attribute primitives see the main **Document** page (forthcoming).

## Topics

- [TFunction Logbook](#tfunction-logbook) · [TFunction GraphNode](#tfunction-graphnode) · [TFunction Function Attribute](#tfunction-function-attribute) · [TNaming CopyShape](#tnaming-copyshape) · [PCDM Status Enums](#pcdm-status-enums) · [Format Registration](#format-registration) · [Save / Load](#save--load) · [Document Metadata](#document-metadata) · [STEP Mode-Controlled Import/Export](#step-mode-controlled-importexport) · [STEP Model Type](#step-model-type) · [STEP Reader/Writer Modes](#step-readerwriter-modes) · [OBJ/PLY Document I/O](#objply-document-io) · [Mesh Coordinate System](#mesh-coordinate-system) · [XDE ShapeTool Expansion](#xde-shapetool-expansion) · [XDE Label Queries](#xde-label-queries) · [XDE ColorTool by Shape](#xde-colortool-by-shape) · [XDE Area / Volume / Centroid](#xde-area--volume--centroid) · [XDE LayerTool Expansion](#xde-layertool-expansion) · [XDE Editor](#xde-editor) · [XCAFDoc_Location](#xcafdoc_location) · [XCAFDoc_GraphNode](#xcafdoc_graphnode) · [XCAFDoc_Color](#xcafdoc_color) · [XCAFDoc_Material](#xcafdoc_material) · [XCAFDoc Note Types](#xcafdoc-note-types)

---

## TFunction Logbook

Methods on `AssemblyNode` that wrap `TFunction_Logbook` — OCCT's dependency-tracking attribute that records which labels were touched or impacted by a parametric function execution.

### `setLogbook()`

Create a `TFunction_Logbook` attribute on this label.

```swift
@discardableResult
public func setLogbook() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TFunction_Logbook::Set`.

---

### `logbookSetTouched(_:)`

Mark a target label as *touched* (directly modified) in this label's logbook.

```swift
@discardableResult
public func logbookSetTouched(_ target: AssemblyNode) -> Bool
```

- **Parameters:** `target` — the label to mark as touched.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_Logbook::SetTouched`.

---

### `logbookSetImpacted(_:)`

Mark a target label as *impacted* (indirectly affected) in this label's logbook.

```swift
@discardableResult
public func logbookSetImpacted(_ target: AssemblyNode) -> Bool
```

- **Parameters:** `target` — the label to mark as impacted.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_Logbook::SetImpacted`.

---

### `logbookIsModified(_:)`

Check whether a target label is modified (touched) in this label's logbook.

```swift
public func logbookIsModified(_ target: AssemblyNode) -> Bool
```

- **Parameters:** `target` — the label to query.
- **Returns:** `true` if the label is touched.
- **OCCT:** `TFunction_Logbook::IsModified`.

---

### `logbookClear()`

Clear all touched/impacted entries from this label's logbook.

```swift
@discardableResult
public func logbookClear() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TFunction_Logbook` — clears the attribute.

---

### `logbookIsEmpty`

Whether this label's logbook has no touched or impacted entries.

```swift
public var logbookIsEmpty: Bool
```

- **OCCT:** `TFunction_Logbook::IsEmpty`.
- **Example:**
  ```swift
  if node.logbookIsEmpty {
      // no pending function updates
  }
  ```

---

## TFunction GraphNode

Methods on `AssemblyNode` that wrap `TFunction_GraphNode` — a directed-graph attribute recording execution-order dependencies between parametric functions.

### `setGraphNode()`

Create a `TFunction_GraphNode` attribute on this label.

```swift
@discardableResult
public func setGraphNode() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TFunction_GraphNode::Set`.

---

### `graphNodeAddPrevious(tag:)`

Add a *previous* (upstream) dependency to this graph node by tag ID.

```swift
@discardableResult
public func graphNodeAddPrevious(tag: Int32) -> Bool
```

- **Parameters:** `tag` — tag integer identifying the upstream label.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_GraphNode::AddPrevious`.

---

### `graphNodeAddNext(tag:)`

Add a *next* (downstream) dependency to this graph node by tag ID.

```swift
@discardableResult
public func graphNodeAddNext(tag: Int32) -> Bool
```

- **Parameters:** `tag` — tag integer identifying the downstream label.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_GraphNode::AddNext`.

---

### `setGraphNodeStatus(_:)`

Set the execution status of this graph node.

```swift
@discardableResult
public func setGraphNodeStatus(_ status: ExecutionStatus) -> Bool
```

- **Parameters:** `status` — one of `.wrongDefinition`, `.notExecuted`, `.executing`, `.succeeded`, `.failed`.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_GraphNode::SetStatus`.

---

### `graphNodeStatus()`

Get the execution status of this graph node.

```swift
public func graphNodeStatus() -> ExecutionStatus?
```

- **Returns:** The current `ExecutionStatus`, or `nil` if the attribute is absent.
- **OCCT:** `TFunction_GraphNode::GetStatus`.
- **Example:**
  ```swift
  if let status = node.graphNodeStatus(), status == .succeeded {
      // function ran cleanly
  }
  ```

---

### `graphNodeRemoveAllPrevious()`

Remove all previous (upstream) dependencies from this graph node.

```swift
@discardableResult
public func graphNodeRemoveAllPrevious() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TFunction_GraphNode::RemoveAllPrevious`.

---

### `graphNodeRemoveAllNext()`

Remove all next (downstream) dependencies from this graph node.

```swift
@discardableResult
public func graphNodeRemoveAllNext() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TFunction_GraphNode::RemoveAllNext`.

---

## TFunction Function Attribute

Methods on `AssemblyNode` that wrap `TFunction_Function` — the attribute that stores a driver GUID and failure mode on a parametric-function label.

### `setFunctionAttribute()`

Create a `TFunction_Function` attribute on this label.

```swift
@discardableResult
public func setFunctionAttribute() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TFunction_Function::Set`.

---

### `functionIsFailed`

Whether the function attribute on this label has entered a failed state.

```swift
public var functionIsFailed: Bool
```

- **OCCT:** `TFunction_Function::IsFailed`.

---

### `functionFailure`

The failure mode code of the function attribute on this label.

```swift
public var functionFailure: Int32?
```

- **Returns:** Failure mode integer, or `nil` if the attribute is absent or not failed.
- **OCCT:** `TFunction_Function::GetFailure`.

---

### `setFunctionFailure(_:)`

Set the failure mode code of the function attribute on this label.

```swift
@discardableResult
public func setFunctionFailure(_ mode: Int32) -> Bool
```

- **Parameters:** `mode` — application-defined failure code.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_Function::SetFailure`.

---

## TNaming CopyShape

An extension on `Shape` that wraps `TNaming_CopyShape` to produce a topology-independent deep copy.

### `deepCopy()`

Create a deep copy of this shape with independent topology — no shared sub-shapes with the original.

```swift
public func deepCopy() -> Shape?
```

- **Returns:** A new `Shape` whose topology is entirely independent of `self`, or `nil` on failure.
- **OCCT:** `TNaming_CopyShape::CopyTool`.
- **Example:**
  ```swift
  if let original = Shape.box(width: 5, height: 5, depth: 5),
     let copy = original.deepCopy() {
      // modifying copy does not affect original
  }
  ```

---

## PCDM Status Enums

Two top-level enums that relay OCCT's `PCDM_StoreStatus` and `PCDM_ReaderStatus` back to Swift callers.

### `StoreStatus`

Status returned by OCAF document save operations.

```swift
public enum StoreStatus: Int32 {
    case ok = 0
    case driverFailure = 1
    case writeFailure = 2
    case failure = 3
    case docIsNull = 4
    case noObj = 5
    case infoSectionError = 6
    case userBreak = 7
    case unrecognizedFormat = 8
}
```

- **OCCT:** `PCDM_StoreStatus`.

---

### `ReaderStatus`

Status returned by OCAF document load operations.

```swift
public enum ReaderStatus: Int32 {
    case ok = 0
    case noDriver = 1
    case unknownFileDriver = 2
    case openError = 3
    case noVersion = 4
    case noSchema = 5
    case noDocument = 6
    case extensionFailure = 7
    case wrongStreamMode = 8
    case formatFailure = 9
    case typeFailure = 10
    case typeNotFoundInSchema = 11
    case unrecognizedFileFormat = 12
    case makeFailure = 13
    case permissionDenied = 14
    case driverFailure = 15
    case alreadyRetrievedAndModified = 16
    case alreadyRetrieved = 17
    case unknownDocument = 18
    case wrongResource = 19
    case readerException = 20
    case noModel = 21
    case userBreak = 22
}
```

- **OCCT:** `PCDM_ReaderStatus`.

---

## Format Registration

Methods on `Document` to register OCCT persistence-driver plug-ins before saving or loading. Call `defineAllFormats()` as a convenience, or register only the drivers you need to minimize overhead.

### `defineFormatBin()`

Register binary OCAF format drivers (`BinOcaf`).

```swift
public func defineFormatBin()
```

- **OCCT:** `BinDrivers::DefineFormat`.

---

### `defineFormatBinL()`

Register lite binary OCAF format drivers (`BinLOcaf`).

```swift
public func defineFormatBinL()
```

- **OCCT:** `BinLDrivers::DefineFormat`.

---

### `defineFormatXml()`

Register XML OCAF format drivers (`XmlOcaf`).

```swift
public func defineFormatXml()
```

- **OCCT:** `XmlDrivers::DefineFormat`.

---

### `defineFormatXmlL()`

Register lite XML OCAF format drivers (`XmlLOcaf`).

```swift
public func defineFormatXmlL()
```

- **OCCT:** `XmlLDrivers::DefineFormat`.

---

### `defineFormatBinXCAF()`

Register binary XCAF format drivers (`BinXCAF`), required for saving XDE documents with shapes, colors, and layers.

```swift
public func defineFormatBinXCAF()
```

- **OCCT:** `BinXCAFDrivers::DefineFormat`.

---

### `defineFormatXmlXCAF()`

Register XML XCAF format drivers (`XmlXCAF`), required for saving XDE documents in human-readable XML.

```swift
public func defineFormatXmlXCAF()
```

- **OCCT:** `XmlXCAFDrivers::DefineFormat`.

---

### `defineAllFormats()`

Register all six available persistence format drivers in one call — the simplest way to ensure save/load works regardless of format.

```swift
public func defineAllFormats()
```

Calls `defineFormatBin()`, `defineFormatBinL()`, `defineFormatXml()`, `defineFormatXmlL()`, `defineFormatBinXCAF()`, and `defineFormatXmlXCAF()` in sequence.

---

## Save / Load

Methods on `Document` for OCAF native persistence (`.cbf`, `.xml`, or XCAF variants).

### `saveOCAF(to:)`

Save the document to a file path. The on-disk format is determined by the document's storage format — call `defineAllFormats()` first.

```swift
public func saveOCAF(to path: String) -> StoreStatus
```

- **Parameters:** `path` — absolute file path.
- **Returns:** `StoreStatus.ok` on success; a failure case otherwise.
- **OCCT:** `XCAFApp_Application::SaveAs` / `PCDM_StoreStatus`.
- **Example:**
  ```swift
  doc.defineAllFormats()
  let status = doc.saveOCAF(to: "/tmp/model.cbf")
  guard status == .ok else { /* handle error */ return }
  ```

---

### `saveOCAFInPlace()`

Save the document to the path it was previously saved to (equivalent to "Save" rather than "Save As").

```swift
public func saveOCAFInPlace() -> StoreStatus
```

- **Returns:** `StoreStatus.ok` on success, or a failure case if the document was never saved.
- **OCCT:** `XCAFApp_Application::Save`.

---

### `Document.loadOCAF(from:)`

Load an OCAF document from a file. Automatically registers all format drivers before opening.

```swift
public static func loadOCAF(from path: String) -> (document: Document?, status: ReaderStatus)
```

- **Parameters:** `path` — absolute file path.
- **Returns:** A tuple `(document, status)`. `document` is non-nil only when `status == .ok`.
- **OCCT:** `XCAFApp_Application::Open` (with `BinDrivers`, `XmlDrivers`, `BinXCAFDrivers`, `XmlXCAFDrivers` registered).
- **Example:**
  ```swift
  let result = Document.loadOCAF(from: "/tmp/model.cbf")
  if let doc = result.document {
      // use doc
  }
  ```

---

### `Document.create(format:)`

Create a new empty document bound to a specific OCAF storage format.

```swift
public static func create(format: String) -> Document?
```

- **Parameters:** `format` — one of `"BinOcaf"`, `"XmlOcaf"`, `"BinLOcaf"`, `"XmlLOcaf"`, `"BinXCAF"`, `"XmlXCAF"`.
- **Returns:** A new empty `Document`, or `nil` if the format string is unrecognised.
- **OCCT:** `XCAFApp_Application::NewDocument`.
- **Example:**
  ```swift
  if let doc = Document.create(format: "BinXCAF") {
      // doc is ready for XDE operations
  }
  ```

---

## Document Metadata

Properties and setters on `Document` for querying and changing format and session state.

### `isSaved`

Whether the document has been saved to disk at least once.

```swift
public var isSaved: Bool
```

- **OCCT:** `TDocStd_Document::IsSaved`.

---

### `storageFormat`

The storage-format identifier of the document (e.g. `"MDTV-XCAF"`, `"BinOcaf"`).

```swift
public var storageFormat: String?
```

- **Returns:** Format string, or `nil` if unavailable.
- **OCCT:** `TDocStd_Document::StorageFormat`.

---

### `setStorageFormat(_:)`

Change the storage format of the document.

```swift
@discardableResult
public func setStorageFormat(_ format: String) -> Bool
```

- **Parameters:** `format` — new format string.
- **Returns:** `true` on success.
- **OCCT:** `TDocStd_Document::ChangeStorageFormat`.

---

### `documentCount`

Number of documents currently open in the application session.

```swift
public var documentCount: Int32
```

- **OCCT:** `CDF_Application::NbDocuments`.

---

### `readingFormats`

The list of format identifiers that the application can currently read.

```swift
public var readingFormats: [String]
```

- **OCCT:** `CDF_Application::ReadingFormats`.

---

### `writingFormats`

The list of format identifiers that the application can currently write.

```swift
public var writingFormats: [String]
```

- **OCCT:** `CDF_Application::WritingFormats`.

---

## STEP Mode-Controlled Import/Export

Fine-grained STEP import and export using `STEPCAFControl_Reader` / `STEPCAFControl_Writer` with per-data-type mode flags.

### `Document.loadSTEP(from:modes:)`

Load a STEP file into a new XDE document with individual per-mode control.

```swift
public static func loadSTEP(from url: URL, modes: STEPReaderModes) -> Document?
```

- **Parameters:**
  - `url` — file URL.
  - `modes` — `STEPReaderModes` controlling color, name, layer, props, GD&T, material import.
- **Returns:** A new `Document`, or `nil` on failure.
- **OCCT:** `STEPCAFControl_Reader`.
- **Example:**
  ```swift
  var modes = STEPReaderModes()
  modes.gdt = true
  if let doc = Document.loadSTEP(from: stepURL, modes: modes) {
      // doc contains shapes + GD&T annotations
  }
  ```

---

### `Document.loadSTEP(fromPath:modes:)`

Load a STEP file by path with mode control.

```swift
public static func loadSTEP(fromPath path: String, modes: STEPReaderModes) -> Document?
```

- **Parameters:** `path` — absolute file path; `modes` — mode flags.
- **Returns:** A new `Document`, or `nil` on failure.
- **OCCT:** `STEPCAFControl_Reader`.

---

### `Document.loadSTEP(from:modes:progress:)`

Load a STEP file with mode control plus progress reporting and cancellation support.

```swift
public static func loadSTEP(from url: URL, modes: STEPReaderModes, progress: ImportProgress?) throws -> Document
```

- **Parameters:**
  - `url` — file URL.
  - `modes` — mode flags.
  - `progress` — optional `ImportProgress` closure for progress updates and cancellation.
- **Returns:** A `Document` on success.
- **Throws:** `ImportError.cancelled` if the user cancelled; `ImportError.importFailed` on other failure.
- **OCCT:** `STEPCAFControl_Reader` with `Message_ProgressRange`.

---

### `writeSTEP(to:modelType:modes:)`

Write the document to a STEP file with model type and per-mode control.

```swift
@discardableResult
public func writeSTEP(to url: URL, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()) -> Bool
```

- **Parameters:**
  - `url` — output file URL.
  - `modelType` — STEP representation type (default `.asIs`).
  - `modes` — `STEPWriterModes` controlling color, name, layer, dim/tol, material export.
- **Returns:** `true` on success.
- **OCCT:** `STEPCAFControl_Writer`.

---

### `writeSTEP(toPath:modelType:modes:)`

Write the document to a STEP file by path.

```swift
@discardableResult
public func writeSTEP(toPath path: String, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()) -> Bool
```

- **Parameters:** `path` — absolute output file path; other parameters as above.
- **Returns:** `true` on success.
- **OCCT:** `STEPCAFControl_Writer`.

---

## STEP Model Type

Enum controlling the STEP product representation entity written for each shape.

### `StepModelType`

```swift
public enum StepModelType: Int32, Sendable {
    case asIs = 0
    case manifoldSolidBrep = 1
    case brepWithVoids = 2
    case facetedBrep = 3
    case facetedBrepAndBrepWithVoids = 4
    case shellBasedSurfaceModel = 5
    case geometricCurveSet = 6
}
```

- **OCCT:** `STEPControl_StepModelType`.
- **Note:** `.asIs` lets the writer choose the most appropriate representation automatically. Use `.manifoldSolidBrep` for solids when downstream tools require it explicitly.

---

## STEP Reader/Writer Modes

Structs of Boolean flags that mirror `STEPCAFControl_Reader` / `STEPCAFControl_Writer` mode setters.

### `STEPReaderModes`

Mode flags controlling which data categories are imported from a STEP file.

```swift
public struct STEPReaderModes: Sendable {
    public var color: Bool      // default true
    public var name: Bool       // default true
    public var layer: Bool      // default true
    public var props: Bool      // default true
    public var gdt: Bool        // default false
    public var material: Bool   // default true

    public init(color: Bool = true, name: Bool = true, layer: Bool = true,
                props: Bool = true, gdt: Bool = false, material: Bool = true)
}
```

- **OCCT:** `STEPCAFControl_Reader::SetColorMode`, `SetNameMode`, `SetLayerMode`, `SetPropsMode`, `SetGDTMode`, `SetMatMode`.
- **Note:** `gdt` (GD&T / dimension-and-tolerance) defaults to `false` because it requires additional downstream parsing; enable explicitly when PMI data is needed.

---

### `STEPWriterModes`

Mode flags controlling which data categories are exported to a STEP file.

```swift
public struct STEPWriterModes: Sendable {
    public var color: Bool      // default true
    public var name: Bool       // default true
    public var layer: Bool      // default true
    public var dimTol: Bool     // default false
    public var material: Bool   // default true

    public init(color: Bool = true, name: Bool = true, layer: Bool = true,
                dimTol: Bool = false, material: Bool = true)
}
```

- **OCCT:** `STEPCAFControl_Writer::SetColorMode`, `SetNameMode`, `SetLayerMode`, `SetDimTolMode`, `SetMatMode`.

---

## OBJ/PLY Document I/O

Methods on `Document` for loading OBJ meshes into XDE documents (preserving materials and names) and writing OBJ or PLY files from a document.

### `Document.loadOBJ(from:)`

Load an OBJ file into a new XDE document.

```swift
public static func loadOBJ(from url: URL) -> Document?
```

- **Parameters:** `url` — file URL.
- **Returns:** A new `Document` containing the mesh, or `nil` on failure.
- **OCCT:** `RWObj_CafReader`.
- **Example:**
  ```swift
  if let doc = Document.loadOBJ(from: objURL) {
      let count = doc.freeShapeCount
  }
  ```

---

### `Document.loadOBJ(fromPath:)`

Load an OBJ file by path into a new XDE document.

```swift
public static func loadOBJ(fromPath path: String) -> Document?
```

- **Parameters:** `path` — absolute file path.
- **Returns:** A new `Document`, or `nil` on failure.
- **OCCT:** `RWObj_CafReader`.

---

### `Document.loadOBJ(from:singlePrecision:systemLengthUnit:)`

Load an OBJ file with precision and unit options.

```swift
public static func loadOBJ(from url: URL, singlePrecision: Bool, systemLengthUnit: Double = 0) -> Document?
```

- **Parameters:**
  - `url` — file URL.
  - `singlePrecision` — use single-precision vertex data (reduces memory; trades off accuracy).
  - `systemLengthUnit` — system length unit in metres (e.g. `0.001` for mm); `0` = use OBJ file default.
- **Returns:** A new `Document`, or `nil` on failure.
- **OCCT:** `RWObj_CafReader` with `SetSinglePrecision` / `SetSystemLengthUnit`.

---

### `Document.loadOBJ(from:inputCS:outputCS:inputLengthUnit:outputLengthUnit:)`

Load an OBJ file with coordinate-system conversion.

```swift
public static func loadOBJ(
    from url: URL,
    inputCS: MeshCoordinateSystem,
    outputCS: MeshCoordinateSystem,
    inputLengthUnit: Double = 0,
    outputLengthUnit: Double = 0
) -> Document?
```

- **Parameters:**
  - `url` — file URL.
  - `inputCS` — coordinate system of the OBJ file (e.g. `.zUp` for Blender exports).
  - `outputCS` — desired coordinate system in the resulting document (e.g. `.yUp` for glTF).
  - `inputLengthUnit` / `outputLengthUnit` — length units in metres; `0` = default.
- **Returns:** A new `Document`, or `nil` on failure.
- **OCCT:** `RWObj_CafReader` with `SetFileCoordinateSystem` / `SetSystemCoordinateSystem` via `RWMesh_CoordinateSystemConverter`.

---

### `writeOBJ(to:deflection:)`

Write the document's geometry to an OBJ file.

```swift
@discardableResult
public func writeOBJ(to url: URL, deflection: Double = 1.0) -> Bool
```

- **Parameters:**
  - `url` — output file URL.
  - `deflection` — mesh chord deflection for tessellation; pass `0` to skip re-meshing and use existing facets.
- **Returns:** `true` on success.
- **OCCT:** `RWObj_CafWriter`.

---

### `writePLY(to:deflection:normals:colors:texCoords:)`

Write the document's geometry to a PLY file.

```swift
@discardableResult
public func writePLY(
    to url: URL,
    deflection: Double = 1.0,
    normals: Bool = true,
    colors: Bool = false,
    texCoords: Bool = false
) -> Bool
```

- **Parameters:**
  - `url` — output file URL.
  - `deflection` — chord deflection for tessellation; `0` skips re-meshing.
  - `normals` — include per-vertex normals (default `true`).
  - `colors` — include per-vertex colors (default `false`).
  - `texCoords` — include texture coordinates (default `false`).
- **Returns:** `true` on success.
- **OCCT:** `RWPly_CafWriter`.

---

## Mesh Coordinate System

Enum that maps to `RWMesh_CoordinateSystem` for specifying axis conventions in mesh import/export.

### `MeshCoordinateSystem`

```swift
public enum MeshCoordinateSystem: Int32, Sendable {
    case undefined = -1
    case zUp = 0   // +Y forward, +Z up (Blender)
    case yUp = 1   // -Z forward, +Y up (glTF)

    public static let blender: MeshCoordinateSystem  // alias for .zUp
    public static let gltf: MeshCoordinateSystem     // alias for .yUp
}
```

- **OCCT:** `RWMesh_CoordinateSystem`.
- **Note:** Use `MeshCoordinateSystem.blender` / `.gltf` as readable aliases when the source or target format is known.

---

## XDE ShapeTool Expansion

Methods on `Document` that wrap `XCAFDoc_ShapeTool` for managing the shape hierarchy — adding, removing, finding, and assembling shapes.

### `shapeCount`

Total number of shapes in the document at all levels.

```swift
public var shapeCount: Int32
```

- **OCCT:** `XCAFDoc_ShapeTool::GetShapes`.

---

### `shapeLabelId(at:)`

Get the label ID for a shape at the given index in the flat list of all shapes.

```swift
public func shapeLabelId(at index: Int32) -> Int64
```

- **Parameters:** `index` — zero-based index (valid range: `0 ..< shapeCount`).
- **OCCT:** `XCAFDoc_ShapeTool::GetShapes`.

---

### `freeShapeCount`

Number of top-level (free) shapes — shapes that are not components of any assembly.

```swift
public var freeShapeCount: Int32
```

- **OCCT:** `XCAFDoc_ShapeTool::GetFreeShapes`.

---

### `freeShapeLabelId(at:)`

Get the label ID for the free shape at the given index.

```swift
public func freeShapeLabelId(at index: Int32) -> Int64
```

- **Parameters:** `index` — zero-based index (valid range: `0 ..< freeShapeCount`).
- **OCCT:** `XCAFDoc_ShapeTool::GetFreeShapes`.

---

### `addShape(_:makeAssembly:)`

Add a shape to the document.

```swift
@discardableResult
public func addShape(_ shape: Shape, makeAssembly: Bool = true) -> Int64
```

- **Parameters:**
  - `shape` — the shape to add.
  - `makeAssembly` — if `true`, compound shapes are registered as assemblies (default `true`).
- **Returns:** Label ID of the added shape, or `-1` on failure.
- **OCCT:** `XCAFDoc_ShapeTool::AddShape`.

---

### `newShapeLabel()`

Create a new empty shape label with no geometry attached.

```swift
public func newShapeLabel() -> Int64
```

- **Returns:** Label ID of the new label, or `-1` on failure.
- **OCCT:** `XCAFDoc_ShapeTool::NewShape`.

---

### `removeShape(labelId:)`

Remove a shape from the document by its label ID.

```swift
@discardableResult
public func removeShape(labelId: Int64) -> Bool
```

- **Parameters:** `labelId` — label ID of the shape to remove.
- **Returns:** `true` if removed successfully.
- **OCCT:** `XCAFDoc_ShapeTool::RemoveShape`.

---

### `findShape(_:)`

Find the label ID for an exact shape match.

```swift
public func findShape(_ shape: Shape) -> Int64
```

- **Parameters:** `shape` — shape to locate.
- **Returns:** Label ID, or `-1` if not found.
- **OCCT:** `XCAFDoc_ShapeTool::FindShape`.

---

### `searchShape(_:)`

Search for a shape in the document including sub-shapes.

```swift
public func searchShape(_ shape: Shape) -> Int64
```

- **Parameters:** `shape` — shape to search for.
- **Returns:** Label ID, or `-1` if not found.
- **OCCT:** `XCAFDoc_ShapeTool::SearchUsingMap` or equivalent search.

---

### `addComponent(assemblyLabelId:shapeLabelId:translation:)`

Add a component to an assembly with a simple translation placement.

```swift
@discardableResult
public func addComponent(
    assemblyLabelId: Int64,
    shapeLabelId: Int64,
    translation: (Double, Double, Double) = (0, 0, 0)
) -> Int64
```

- **Parameters:**
  - `assemblyLabelId` — label ID of the parent assembly.
  - `shapeLabelId` — label ID of the shape to instantiate.
  - `translation` — `(tx, ty, tz)` offset in model units.
- **Returns:** Component label ID, or `-1` on failure.
- **OCCT:** `XCAFDoc_ShapeTool::AddComponent`.

---

### `addComponent(assemblyLabelId:shapeLabelId:matrix:)`

Add a component with a full rigid placement specified as a 12-element row-major matrix.

```swift
@discardableResult
public func addComponent(assemblyLabelId: Int64, shapeLabelId: Int64, matrix: [Double]) -> Int64
```

- **Parameters:**
  - `assemblyLabelId` — parent assembly label ID.
  - `shapeLabelId` — shape to instantiate.
  - `matrix` — 12 `Double` values `[r00 r01 r02 r10 r11 r12 r20 r21 r22 tx ty tz]` (row-major rotation + translation). Must be a proper rigid transform — reflections return `-1`.
- **Returns:** Component label ID, or `-1` on failure or bad matrix.
- **OCCT:** `XCAFDoc_ShapeTool::AddComponent` with `TopLoc_Location`.
- **Note:** The matrix must not be a reflection (det = +1). Build a mirrored product shape separately if mirroring is required.

---

### `removeComponent(labelId:)`

Remove a component instance from an assembly.

```swift
public func removeComponent(labelId: Int64)
```

- **Parameters:** `labelId` — the component label to remove.
- **OCCT:** `XCAFDoc_ShapeTool::RemoveComponent`.

---

### `componentCount(assemblyLabelId:)`

Get the number of components in an assembly.

```swift
public func componentCount(assemblyLabelId: Int64) -> Int32
```

- **OCCT:** `XCAFDoc_ShapeTool::GetComponents`.

---

### `componentLabelId(assemblyLabelId:at:)`

Get the label ID of a component at a given index within an assembly.

```swift
public func componentLabelId(assemblyLabelId: Int64, at index: Int32) -> Int64
```

- **Parameters:** `assemblyLabelId` — assembly label; `index` — zero-based component index.
- **OCCT:** `XCAFDoc_ShapeTool::GetComponents`.

---

### `componentReferredLabelId(_:)`

Get the label of the shape that a component label references (i.e., the prototype, not the instance).

```swift
public func componentReferredLabelId(_ componentLabelId: Int64) -> Int64
```

- **Parameters:** `componentLabelId` — a component (instance) label.
- **Returns:** Referred shape label ID, or `-1` if the label is not a reference.
- **OCCT:** `XCAFDoc_ShapeTool::GetReferredShape`.

---

### `shapeUserCount(shapeLabelId:)`

Count how many component labels reference a given shape label.

```swift
public func shapeUserCount(shapeLabelId: Int64) -> Int32
```

- **OCCT:** `XCAFDoc_ShapeTool::GetUsers`.

---

### `updateAssemblies()`

Recompute all assembly compound shapes from their current component placements.

```swift
public func updateAssemblies()
```

- **OCCT:** `XCAFDoc_ShapeTool::UpdateAssemblies`.
- **Note:** Call after adding, removing, or repositioning components to keep the computed compounds in sync.

---

### `expandShape(labelId:)`

Expand a compound shape label into an assembly using `XCAFDoc_ShapeTool::Expand`.

```swift
@discardableResult
public func expandShape(labelId: Int64) -> Bool
```

- **Parameters:** `labelId` — label of the compound to expand.
- **Returns:** `true` if the expansion succeeded.
- **OCCT:** `XCAFDoc_ShapeTool::Expand`.

---

## XDE Label Queries

Properties on `AssemblyNode` for querying the structural role of a label within the XDE hierarchy.

### `isTopLevel`

Whether this label is a top-level (free) shape.

```swift
public var isTopLevel: Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsTopLevel`.

---

### `isComponent`

Whether this label is a component instance inside an assembly.

```swift
public var isComponent: Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsComponent`.

---

### `isCompound`

Whether this label represents a compound shape.

```swift
public var isCompound: Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsCompound`.

---

### `isSubShape`

Whether this label represents a sub-shape (a face, edge, or vertex belonging to another shape).

```swift
public var isSubShape: Bool
```

- **OCCT:** `XCAFDoc_ShapeTool::IsSubShape`.

---

### `subShapeCount`

Number of sub-shapes registered under this label.

```swift
public var subShapeCount: Int32
```

- **OCCT:** `XCAFDoc_ShapeTool::GetSubShapes`.

---

### `subShapeNode(at:)`

Get the `AssemblyNode` for a sub-shape at the given index.

```swift
public func subShapeNode(at index: Int32) -> AssemblyNode?
```

- **Parameters:** `index` — zero-based sub-shape index.
- **Returns:** `AssemblyNode`, or `nil` if index is out of range.
- **OCCT:** `XCAFDoc_ShapeTool::GetSubShapes`.

---

### `userCount`

Number of component labels that reference this shape label.

```swift
public var userCount: Int32
```

- **OCCT:** `XCAFDoc_ShapeTool::GetUsers`.

---

### `isVisible`

Visibility flag for this label — gets and sets XDE display visibility.

```swift
public var isVisible: Bool { get set }
```

- **OCCT:** `XCAFDoc_ColorTool` visibility attribute (`GetVisibility` / `SetVisibility`).
- **Example:**
  ```swift
  node.isVisible = false   // hide this shape in viewers
  ```

---

## XDE ColorTool by Shape

Methods on `Document` for assigning and querying colors directly on `Shape` values (rather than by label ID) via `XCAFDoc_ColorTool`.

### `setShapeColor(_:color:type:)`

Set a color on a shape.

```swift
public func setShapeColor(_ shape: Shape, color: Color, type: OCCTColorType = OCCTColorTypeSurface)
```

- **Parameters:**
  - `shape` — the shape to color.
  - `color` — RGB color value.
  - `type` — `OCCTColorTypeGeneric` (0), `OCCTColorTypeSurface` (1), or `OCCTColorTypeCurve` (2). Default is surface color.
- **OCCT:** `XCAFDoc_ColorTool::SetColor`.

---

### `shapeColor(_:type:)`

Get the color assigned to a shape.

```swift
public func shapeColor(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Color?
```

- **Parameters:** `shape` — shape to query; `type` — color type.
- **Returns:** `Color` if a color of the given type is set, `nil` otherwise.
- **OCCT:** `XCAFDoc_ColorTool::GetColor`.

---

### `isShapeColorSet(_:type:)`

Check whether a color of the given type is set on a shape.

```swift
public func isShapeColorSet(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Bool
```

- **OCCT:** `XCAFDoc_ColorTool::IsSet`.

---

## XDE Area / Volume / Centroid

Properties and setters on `AssemblyNode` for storing and retrieving physical-property annotations (area, volume, centroid) as OCAF attributes.

### `setArea(_:)`

Set an area attribute on this label.

```swift
public func setArea(_ area: Double)
```

- **Parameters:** `area` — area value in document units².
- **OCCT:** `XCAFDoc_Area::Set`.

---

### `area`

Get the area attribute from this label.

```swift
public var area: Double?
```

- **Returns:** Area value, or `nil` if no area attribute is set.
- **OCCT:** `XCAFDoc_Area::Get`.

---

### `setVolume(_:)`

Set a volume attribute on this label.

```swift
public func setVolume(_ volume: Double)
```

- **Parameters:** `volume` — volume in document units³.
- **OCCT:** `XCAFDoc_Volume::Set`.

---

### `volume`

Get the volume attribute from this label.

```swift
public var volume: Double?
```

- **Returns:** Volume value, or `nil` if no volume attribute is set.
- **OCCT:** `XCAFDoc_Volume::Get`.

---

### `setCentroid(x:y:z:)`

Set a centroid attribute on this label.

```swift
public func setCentroid(x: Double, y: Double, z: Double)
```

- **Parameters:** `x`, `y`, `z` — centroid coordinates in document units.
- **OCCT:** `XCAFDoc_Centroid::Set`.

---

### `centroid`

Get the centroid attribute from this label.

```swift
public var centroid: (x: Double, y: Double, z: Double)?
```

- **Returns:** Centroid tuple, or `nil` if no centroid attribute is set.
- **OCCT:** `XCAFDoc_Centroid::Get`.

---

## XDE LayerTool Expansion

Methods on `AssemblyNode` for assigning named layers, and methods on `Document` for finding layers and managing their visibility via `XCAFDoc_LayerTool`.

### `setLayer(_:)`

Assign a named layer to this label.

```swift
public func setLayer(_ name: String)
```

- **Parameters:** `name` — layer name string.
- **OCCT:** `XCAFDoc_LayerTool::SetLayer`.

---

### `isLayerSet(_:)`

Check whether a specific named layer is assigned to this label.

```swift
public func isLayerSet(_ name: String) -> Bool
```

- **Parameters:** `name` — layer name to check.
- **OCCT:** `XCAFDoc_LayerTool::IsSet`.

---

### `layers`

All layer names assigned to this label.

```swift
public var layers: [String]
```

- **Returns:** Array of layer name strings (up to 16 entries).
- **OCCT:** `XCAFDoc_LayerTool::GetLayers`.

---

### `findLayer(_:)`

Find the label ID of a layer by name.

```swift
public func findLayer(_ name: String) -> Int64
```

- **Parameters:** `name` — layer name.
- **Returns:** Label ID, or `-1` if no such layer exists.
- **OCCT:** `XCAFDoc_LayerTool::FindLayer`.

---

### `setLayerVisibility(layerLabelId:visible:)`

Set the visibility flag for a layer label.

```swift
public func setLayerVisibility(layerLabelId: Int64, visible: Bool)
```

- **OCCT:** `XCAFDoc_LayerTool::SetVisibility`.

---

### `layerVisibility(layerLabelId:)`

Get the visibility flag for a layer label.

```swift
public func layerVisibility(layerLabelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_LayerTool::IsVisible`.

---

## XDE Editor

Methods on `Document` that wrap `XCAFDoc_Editor` for structural and geometric modifications to the XDE hierarchy.

### `editorExpand(labelId:recursively:)`

Expand a compound shape label into an assembly, optionally recursing into nested compounds.

```swift
@discardableResult
public func editorExpand(labelId: Int64, recursively: Bool = true) -> Bool
```

- **Parameters:**
  - `labelId` — label of the compound to expand.
  - `recursively` — if `true` (default), expand all nested compounds too.
- **Returns:** `true` if expansion succeeded.
- **OCCT:** `XCAFDoc_Editor::Expand`.

---

### `rescaleGeometry(labelId:scaleFactor:forceIfNotRoot:)`

Rescale geometry stored on a label by a uniform scale factor.

```swift
@discardableResult
public func rescaleGeometry(labelId: Int64, scaleFactor: Double, forceIfNotRoot: Bool = false) -> Bool
```

- **Parameters:**
  - `labelId` — label whose geometry to rescale.
  - `scaleFactor` — uniform scale factor (e.g. `0.001` to convert mm → m).
  - `forceIfNotRoot` — if `true`, rescale even when the label is not the document root (default `false`).
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_Editor::RescaleGeometry`.

---

## XCAFDoc_Location

Properties on `AssemblyNode` wrapping the `XCAFDoc_Location` attribute — a `TopLoc_Location` stored directly on a label (distinct from the placement location on a component reference).

### `setLocationTranslation(x:y:z:)`

Set a translation-only `TopLoc_Location` on this label.

```swift
@discardableResult
public func setLocationTranslation(x: Double, y: Double, z: Double) -> Bool
```

- **Parameters:** `x`, `y`, `z` — translation in model units.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_Location::Set`.

---

### `locationTranslation`

Get the translation component of the `XCAFDoc_Location` attribute on this label.

```swift
public var locationTranslation: (x: Double, y: Double, z: Double)?
```

- **Returns:** Translation tuple, or `nil` if no `XCAFDoc_Location` attribute is present.
- **OCCT:** `XCAFDoc_Location::Get` → `TopLoc_Location::IsTranslation`.

---

### `hasLocationAttribute`

Whether this label has an `XCAFDoc_Location` attribute.

```swift
public var hasLocationAttribute: Bool
```

- **OCCT:** `TDF_Label::FindAttribute(XCAFDoc_Location::GetID(), …)`.

---

## XCAFDoc_GraphNode

Properties on `AssemblyNode` wrapping `XCAFDoc_GraphNode` — XCAF's own directed-graph attribute for shape DAG relationships (distinct from `TFunction_GraphNode`).

### `setXCAFGraphNode()`

Set an `XCAFDoc_GraphNode` attribute on this label.

```swift
@discardableResult
public func setXCAFGraphNode() -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::Set`.

---

### `xcafGraphNodeSetChild(_:)`

Establish a child relationship: this label's graph node gains `child` as a child.

```swift
@discardableResult
public func xcafGraphNodeSetChild(_ child: AssemblyNode) -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::SetChild`.

---

### `xcafGraphNodeSetFather(_:)`

Establish a parent relationship: this label's graph node gains `parent` as a father.

```swift
@discardableResult
public func xcafGraphNodeSetFather(_ parent: AssemblyNode) -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::SetFather`.

---

### `xcafGraphNodeUnSetChild(_:)`

Remove a child relationship.

```swift
@discardableResult
public func xcafGraphNodeUnSetChild(_ child: AssemblyNode) -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::UnSetChild`.

---

### `xcafGraphNodeUnSetFather(_:)`

Remove a parent relationship.

```swift
@discardableResult
public func xcafGraphNodeUnSetFather(_ parent: AssemblyNode) -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::UnSetFather`.

---

### `xcafGraphNodeChildCount`

Number of children in this label's `XCAFDoc_GraphNode`.

```swift
public var xcafGraphNodeChildCount: Int32
```

- **OCCT:** `XCAFDoc_GraphNode::NbChildren`.

---

### `xcafGraphNodeFatherCount`

Number of fathers (parents) in this label's `XCAFDoc_GraphNode`.

```swift
public var xcafGraphNodeFatherCount: Int32
```

- **OCCT:** `XCAFDoc_GraphNode::NbFathers`.

---

### `xcafGraphNodeIsFather(of:)`

Check whether this node is a father (parent) of another node in the graph.

```swift
public func xcafGraphNodeIsFather(of other: AssemblyNode) -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::IsFather`.

---

### `xcafGraphNodeIsChild(of:)`

Check whether this node is a child of another node in the graph.

```swift
public func xcafGraphNodeIsChild(of other: AssemblyNode) -> Bool
```

- **OCCT:** `XCAFDoc_GraphNode::IsChild`.

---

## XCAFDoc_Color

Properties on `AssemblyNode` wrapping `XCAFDoc_Color` — a direct color attribute stored on a label (as opposed to the `XCAFDoc_ColorTool` mapping).

### `setColorAttribute(red:green:blue:)`

Set an `XCAFDoc_Color` attribute from RGB components.

```swift
@discardableResult
public func setColorAttribute(red: Double, green: Double, blue: Double) -> Bool
```

- **Parameters:** `red`, `green`, `blue` — colour components in [0, 1].
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_Color::Set`.

---

### `setColorAttribute(red:green:blue:alpha:)`

Set an `XCAFDoc_Color` attribute from RGBA components.

```swift
@discardableResult
public func setColorAttribute(red: Double, green: Double, blue: Double, alpha: Float) -> Bool
```

- **Parameters:** `red`, `green`, `blue` in [0, 1]; `alpha` in [0, 1].
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_Color::Set` with `Quantity_ColorRGBA`.

---

### `setColorAttribute(namedColor:)`

Set an `XCAFDoc_Color` attribute from a `Quantity_NameOfColor` integer constant.

```swift
@discardableResult
public func setColorAttribute(namedColor noc: Int32) -> Bool
```

- **Parameters:** `noc` — `Quantity_NameOfColor` raw value (e.g. `1` = `Quantity_NOC_BLACK`).
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_Color::Set` with `Quantity_NameOfColor`.

---

### `colorAttribute`

Get the RGB colour from this label's `XCAFDoc_Color` attribute.

```swift
public var colorAttribute: (red: Double, green: Double, blue: Double)?
```

- **Returns:** RGB tuple, or `nil` if no colour attribute is present.
- **OCCT:** `XCAFDoc_Color::GetColor`.

---

### `colorRGBAAttribute`

Get the RGBA colour from this label's `XCAFDoc_Color` attribute.

```swift
public var colorRGBAAttribute: (red: Double, green: Double, blue: Double, alpha: Float)?
```

- **Returns:** RGBA tuple, or `nil` if no colour attribute is present.
- **OCCT:** `XCAFDoc_Color::GetColor` with `Quantity_ColorRGBA`.

---

### `colorAlphaAttribute`

Get the alpha component of this label's `XCAFDoc_Color` attribute.

```swift
public var colorAlphaAttribute: Float
```

- **Returns:** Alpha in [0, 1]; returns `1.0` if no colour attribute is present.
- **OCCT:** `XCAFDoc_Color::GetColor` — `.Alpha()`.

---

### `colorNOCAttribute`

Get the `Quantity_NameOfColor` integer from this label's `XCAFDoc_Color` attribute.

```swift
public var colorNOCAttribute: Int32
```

- **Returns:** Named-colour integer, or `-1` if not set as a named colour.
- **OCCT:** `XCAFDoc_Color::GetColor` → `Quantity_Color::Name`.

---

## XCAFDoc_Material

Properties on `AssemblyNode` wrapping `XCAFDoc_Material` — stores material name, description, and density directly on a label.

### `setMaterialAttribute(name:description:density:densityName:densityValueType:)`

Set an `XCAFDoc_Material` attribute on this label.

```swift
@discardableResult
public func setMaterialAttribute(
    name: String,
    description: String,
    density: Double,
    densityName: String,
    densityValueType: String
) -> Bool
```

- **Parameters:**
  - `name` — material name (e.g. `"Steel"`).
  - `description` — free-text description.
  - `density` — density value.
  - `densityName` — name of the density measure (e.g. `"MASS DENSITY"`).
  - `densityValueType` — value type string (e.g. `"POSITIVE_RATIO_MEASURE"`).
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_Material::Set`.

---

### `materialAttributeName`

Get the material name from this label's `XCAFDoc_Material` attribute.

```swift
public var materialAttributeName: String?
```

- **Returns:** Material name string, or `nil` if no material attribute is present.
- **OCCT:** `XCAFDoc_Material::GetName`.

---

### `materialAttributeDescription`

Get the material description from this label's `XCAFDoc_Material` attribute.

```swift
public var materialAttributeDescription: String?
```

- **Returns:** Description string, or `nil` if absent.
- **OCCT:** `XCAFDoc_Material::GetDescription`.

---

### `materialAttributeDensity`

Get the material density from this label's `XCAFDoc_Material` attribute.

```swift
public var materialAttributeDensity: Double?
```

- **Returns:** Density value, or `nil` if no material attribute is present.
- **OCCT:** `XCAFDoc_Material::GetDensity`.

---

### `hasMaterialAttribute`

Whether this label has an `XCAFDoc_Material` attribute.

```swift
public var hasMaterialAttribute: Bool
```

- **OCCT:** `TDF_Label::FindAttribute(XCAFDoc_Material::GetID(), …)`.

---

## XCAFDoc Note Types

Properties on `AssemblyNode` for attaching XCAF annotation notes (`XCAFDoc_NoteComment`, `XCAFDoc_NoteBalloon`, `XCAFDoc_NoteBinData`).

### `setNoteComment(userName:timeStamp:comment:)`

Set an `XCAFDoc_NoteComment` attribute — a text annotation with author and timestamp.

```swift
@discardableResult
public func setNoteComment(userName: String, timeStamp: String, comment: String) -> Bool
```

- **Parameters:**
  - `userName` — author identifier.
  - `timeStamp` — ISO 8601 timestamp string.
  - `comment` — free-text comment body.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_NoteComment::Set`.

---

### `noteCommentText`

Get the comment body from an `XCAFDoc_NoteComment` attribute.

```swift
public var noteCommentText: String?
```

- **Returns:** Comment string, or `nil` if no note comment attribute is present.
- **OCCT:** `XCAFDoc_NoteComment::Comment`.

---

### `noteUserName`

Get the author user name from a note attribute on this label.

```swift
public var noteUserName: String?
```

- **Returns:** User name string, or `nil` if absent.
- **OCCT:** `XCAFDoc_Note::UserName`.

---

### `setNoteBalloon(userName:timeStamp:comment:)`

Set an `XCAFDoc_NoteBalloon` attribute — a balloon-style annotation displayed attached to a shape.

```swift
@discardableResult
public func setNoteBalloon(userName: String, timeStamp: String, comment: String) -> Bool
```

- **Parameters:** As for `setNoteComment(userName:timeStamp:comment:)`.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_NoteBalloon::Set`.

---

### `setNoteBinData(userName:timeStamp:title:mimeType:data:)`

Set an `XCAFDoc_NoteBinData` attribute — an arbitrary binary payload attached to a label (e.g. an embedded image or custom data blob).

```swift
@discardableResult
public func setNoteBinData(
    userName: String,
    timeStamp: String,
    title: String,
    mimeType: String,
    data: [UInt8]
) -> Bool
```

- **Parameters:**
  - `userName` — author identifier.
  - `timeStamp` — ISO 8601 timestamp.
  - `title` — human-readable title for the blob.
  - `mimeType` — MIME type string (e.g. `"image/png"`).
  - `data` — raw byte payload.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_NoteBinData::Set`.

---

### `noteBinDataSize`

Get the byte length of the binary payload from an `XCAFDoc_NoteBinData` attribute.

```swift
public var noteBinDataSize: Int32
```

- **Returns:** Byte count of the stored blob, or `0` if no `XCAFDoc_NoteBinData` attribute is present.
- **OCCT:** `XCAFDoc_NoteBinData::Size`.
