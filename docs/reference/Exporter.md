---
title: Exporter
parent: API Reference
---

# Exporter

`Exporter` is a caseless `enum` namespace that collects all write-to-file operations for
OCCTSwift shapes. It covers two families of format:

- **Tessellated** (STL, OBJ, PLY, GLTF/GLB) — the shape is meshed internally; a `deflection`
  parameter controls triangle density.
- **Exact B-Rep** (STEP, IGES, BREP) — the full analytic geometry is written without
  approximation; these are round-trippable via the corresponding `Shape.load*` importers.

All write methods throw `Exporter.ExportError` on failure. Convenience instance methods are
defined on `Shape` (see [Shape Convenience Extensions](#shape-convenience-extensions)).

The `StepModelType` enum and `Document.writeGLTF` are defined in `Document.swift` but are part
of the export surface; both are documented here.

## Topics

- [ExportError](#exporterror) · [STL Export](#stl-export) · [STEP Export](#step-export) ·
  [IGES Export](#iges-export) · [BREP Export](#brep-export) · [OBJ Export](#obj-export) ·
  [PLY Export](#ply-export) · [GLTF Export](#gltf-export) ·
  [STEP Optimisation](#step-optimisation) · [StepModelType](#stepmodeltype) ·
  [Shape Convenience Extensions](#shape-convenience-extensions)

---

## ExportError

Error type thrown by all `Exporter` write methods.

```swift
public enum ExportError: Error, LocalizedError {
    case exportFailed(String)
    case invalidPath
    case invalidShape
    case cancelled
}
```

- `exportFailed(String)` — the underlying OCCT writer returned false or threw; the associated
  string names the failing file.
- `invalidPath` — the destination URL resolved to an empty path string.
- `invalidShape` — `shape.isValid` returned `false` before the write was attempted.
- `cancelled` — the export was cooperatively cancelled via `ImportProgress.shouldCancel()`.
  Only thrown by the progress-overloads `writeSTEP(shape:to:progress:)` and
  `writeIGES(shape:to:progress:)`.

---

## STL Export

### `Exporter.writeSTL(shape:to:deflection:ascii:)`

Tessellates a shape and writes an STL file.

```swift
public static func writeSTL(
    shape: Shape,
    to url: URL,
    deflection: Double = 0.1,
    ascii: Bool = false
) throws
```

`deflection` is the maximum chord deviation in model units — smaller values produce finer meshes
and larger files. Binary mode (`ascii: false`) is the default and produces smaller files.

| Use case | deflection |
|---|---|
| Quick preview | 0.5 |
| FDM print (0.2 mm layers) | 0.1 |
| Fine FDM (0.1 mm) | 0.05 |
| SLA / display-quality | 0.02 |

- **Parameters:** `shape` — shape to tessellate; `url` — output URL (conventionally `.stl`);
  `deflection` — max chord deviation (default 0.1); `ascii` — `true` for ASCII STL (default `false`).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidShape` if `shape.isValid` is false;
  `ExportError.invalidPath` if `url.path` is empty;
  `ExportError.exportFailed` if `StlAPI_Writer` fails.
- **OCCT:** `StlAPI_Writer::Write` (binary or ASCII mode).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 5, depth: 3)!
  try Exporter.writeSTL(shape: box, to: URL(fileURLWithPath: "/tmp/box.stl"), deflection: 0.05)
  try Exporter.writeSTL(shape: box, to: asciiURL, deflection: 0.1, ascii: true)
  ```

---

### `Exporter.stlData(shape:deflection:)`

Tessellates a shape and returns the STL file contents as `Data`, without touching a permanent file.

```swift
public static func stlData(
    shape: Shape,
    deflection: Double = 0.1
) throws -> Data
```

Internally writes to a UUID-named temporary file, reads it back, and removes it. Useful for
sharing via AirDrop, email attachments, or uploading over the network.

- **Parameters:** `shape` — shape to export; `deflection` — tessellation quality (default 0.1).
- **Returns:** Binary STL `Data`.
- **Throws:** Same as `writeSTL`; also rethrows `Data(contentsOf:)` errors if the temp file cannot be read.
- **OCCT:** `StlAPI_Writer` (via `writeSTL`).
- **Example:**
  ```swift
  let data = try Exporter.stlData(shape: myShape)
  // Share via AirDrop, email, etc.
  ```

---

## STEP Export

### `Exporter.writeSTEP(shape:to:name:)`

Writes a shape to STEP AP214 format. Preserves exact analytic B-Rep geometry.

```swift
public static func writeSTEP(
    shape: Shape,
    to url: URL,
    name: String? = nil
) throws
```

STEP is the standard CAD interchange format and is importable by Fusion 360, SolidWorks, FreeCAD,
and most CAM tools. When `name` is supplied it is embedded as the product name in the STEP file.

- **Parameters:** `shape` — shape to export; `url` — output URL (conventionally `.step` or `.stp`);
  `name` — optional product name.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidShape`; `ExportError.invalidPath`;
  `ExportError.exportFailed` if `STEPControl_Writer` transfer or write fails.
- **OCCT:** `STEPControl_Writer::Transfer` + `Write` (AP214, `STEPControl_AsIs` model type when no name; `STEPControl_AsIs` via `OCCTExportSTEPWithName` when a name is given).
- **Example:**
  ```swift
  try Exporter.writeSTEP(shape: turnout,
                          to: projectURL.appendingPathComponent("turnout.step"),
                          name: "Number8Turnout")
  ```
- **Note:** STEP preserves topology (faces, edges, vertices). File sizes are larger than STL.

---

### `Exporter.writeSTEP(shape:to:progress:)`

Writes a shape to STEP with cooperative progress reporting and cancellation support.

```swift
public static func writeSTEP(
    shape: Shape,
    to url: URL,
    progress: ImportProgress?
) throws
```

Pass `nil` for `progress` to disable cancellation; otherwise the export polls
`progress.shouldCancel()` cooperatively via the OCCT message range mechanism.

- **Parameters:** `shape` — shape to export; `url` — output URL; `progress` — optional
  cancellation/progress token.
- **Returns:** `Void`.
- **Throws:** `ExportError.cancelled` if `progress.shouldCancel()` fires;
  `ExportError.invalidShape`; `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `STEPControl_Writer::Transfer` with a `Message_ProgressRange` derived from the
  `ImportProgress` context.
- **Example:**
  ```swift
  let progress = ImportProgress()
  try Exporter.writeSTEP(shape: largeModel, to: stepURL, progress: progress)
  ```

---

### `Exporter.stepData(shape:name:)`

Writes a shape to STEP and returns the file contents as `Data`.

```swift
public static func stepData(
    shape: Shape,
    name: String? = nil
) throws -> Data
```

- **Parameters:** `shape` — shape to export; `name` — optional product name.
- **Returns:** STEP file as `Data`.
- **Throws:** Same as `writeSTEP(shape:to:name:)`.
- **OCCT:** `STEPControl_Writer` (via `writeSTEP`).
- **Example:**
  ```swift
  let data = try Exporter.stepData(shape: model, name: "Part1")
  ```

---

### `Exporter.writeSTEP(shape:to:modelType:)`

Writes a shape to STEP with an explicit STEP representation type.

```swift
public static func writeSTEP(shape: Shape, to url: URL, modelType: StepModelType) throws
```

Use `modelType` to control how geometry is encoded in the STEP file. See
[StepModelType](#stepmodeltype) for available values.

- **Parameters:** `shape` — shape; `url` — output URL; `modelType` — STEP representation type.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `STEPControl_Writer::Transfer` with the given `STEPControl_StepModelType`.
- **Example:**
  ```swift
  try Exporter.writeSTEP(shape: solid, to: stepURL, modelType: .manifoldSolidBrep)
  ```

---

### `Exporter.writeSTEP(shape:to:modelType:tolerance:)`

Writes a shape to STEP with an explicit model type and geometric tolerance.

```swift
public static func writeSTEP(shape: Shape, to url: URL, modelType: StepModelType, tolerance: Double) throws
```

- **Parameters:** `shape` — shape; `url` — output URL; `modelType` — representation type;
  `tolerance` — geometric tolerance written into the STEP file header.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `STEPControl_Writer::Transfer` with explicit tolerance.
- **Example:**
  ```swift
  try Exporter.writeSTEP(shape: part, to: stepURL,
                          modelType: .asIs, tolerance: 1e-4)
  ```

---

### `Exporter.writeSTEPCleanDuplicates(shape:to:modelType:)`

Writes a shape to STEP and deduplicates shared geometric entities to reduce file size.

```swift
public static func writeSTEPCleanDuplicates(shape: Shape, to url: URL, modelType: StepModelType = .asIs) throws
```

Merges identical surfaces, curves, and vertices during the transfer. Most effective for
assemblies or swept shapes where many faces share the same underlying geometry.

- **Parameters:** `shape` — shape; `url` — output URL; `modelType` — representation type (default `.asIs`).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `STEPControl_Writer` with a pre-transfer deduplication pass.
- **Example:**
  ```swift
  try Exporter.writeSTEPCleanDuplicates(shape: assembly, to: stepURL)
  ```

---

### `Exporter.writeSTEPAssembly(_:to:)`

Writes an XCAF `Document` as a product-structured STEP assembly.

```swift
public static func writeSTEPAssembly(_ document: Document, to url: URL) throws
```

Unlike `writeSTEP(shape:to:)`, which flattens everything into one geometry object, this
preserves the document's assembly tree: each unique part label is written once as a STEP
`PRODUCT` / `PRODUCT_DEFINITION` and referenced by its placed occurrences via
`NEXT_ASSEMBLY_USAGE_OCCURRENCE` + `TopLoc_Location`. A part placed N times generates one
`MANIFOLD_SOLID_BREP`, not N copies. Component names and colors set on the document labels are
also written. Build the assembly tree with `Document.addShape` and `Document.addComponent`
before calling this. Output uses AP214 schema.

- **Parameters:** `document` — XCAF document holding the assembly tree; `url` — output URL.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath` if `url.path` is empty;
  `ExportError.exportFailed` if the `STEPCAFControl_Writer` transfer or write fails.
- **OCCT:** `STEPCAFControl_Writer` (via `Document.writeSTEP(to:)`).
- **Example:**
  ```swift
  let doc = Document()
  let partId = doc.addShape(shaft)
  let asmId  = doc.addShape(Shape.compound([]), makeAssembly: true)
  doc.addComponent(assemblyLabelId: asmId, shapeLabelId: partId, matrix: .identity)
  try Exporter.writeSTEPAssembly(doc, to: URL(fileURLWithPath: "/tmp/assembly.step"))
  ```
- **Note:** See the [XCAF Assemblies](../guides/cookbook/xcaf-assemblies.md) cookbook page for
  a full assembly-build example.

---

## IGES Export

### `Exporter.writeIGES(shape:to:)`

Writes a shape to IGES format.

```swift
public static func writeIGES(
    shape: Shape,
    to url: URL
) throws
```

IGES (Initial Graphics Exchange Specification) is a legacy format still commonly accepted by
CNC machines and older CAD tools. Uses Faces mode with MM units by default. Validates the shape
with `BRepCheck_Analyzer` before writing; returns `exportFailed` for invalid geometry.

- **Parameters:** `shape` — shape to export; `url` — output URL (conventionally `.igs` or `.iges`).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidShape`; `ExportError.invalidPath`;
  `ExportError.exportFailed` if `IGESControl_Writer` fails.
- **OCCT:** `IGESControl_Writer::AddShape` + `ComputeModel` + `Write`.
- **Note:** IGES writes are serialised through an internal mutex because `IGESControl_Writer`
  has internal global state that is not thread-safe.
- **Example:**
  ```swift
  try Exporter.writeIGES(shape: part, to: URL(fileURLWithPath: "/tmp/part.igs"))
  ```

---

### `Exporter.writeIGES(shape:to:progress:)`

Writes a shape to IGES with cooperative progress reporting and cancellation.

```swift
public static func writeIGES(
    shape: Shape,
    to url: URL,
    progress: ImportProgress?
) throws
```

- **Parameters:** `shape` — shape; `url` — output URL; `progress` — optional cancellation token.
- **Returns:** `Void`.
- **Throws:** `ExportError.cancelled`; `ExportError.invalidShape`; `ExportError.invalidPath`;
  `ExportError.exportFailed`.
- **OCCT:** `IGESControl_Writer` with `Message_ProgressRange`.
- **Example:**
  ```swift
  try Exporter.writeIGES(shape: model, to: igesURL, progress: ImportProgress())
  ```

---

### `Exporter.writeIGES(shape:to:unit:)`

Writes a shape to IGES with an explicit unit string.

```swift
public static func writeIGES(shape: Shape, to url: URL, unit: String) throws
```

- **Parameters:** `shape` — shape; `url` — output URL; `unit` — unit identifier, e.g. `"MM"`,
  `"IN"`, `"M"`, `"FT"`.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `IGESControl_Writer(unit, 0)` — Faces mode with the specified unit.
- **Example:**
  ```swift
  try Exporter.writeIGES(shape: part, to: igesURL, unit: "IN")
  ```

---

### `Exporter.writeIGESBRep(shape:to:)`

Writes a shape to IGES in BRep mode (exact geometry, not tessellated faces).

```swift
public static func writeIGESBRep(shape: Shape, to url: URL) throws
```

Passes `mode = 1` to `IGESControl_Writer`, causing it to write B-Rep entities rather than
tessellated face entities.

- **Parameters:** `shape` — shape; `url` — output URL.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `IGESControl_Writer("MM", 1)` — BRep mode.
- **Example:**
  ```swift
  try Exporter.writeIGESBRep(shape: solid, to: igesURL)
  ```

---

### `Exporter.writeIGES(shapes:to:)`

Writes multiple shapes to a single IGES file.

```swift
public static func writeIGES(shapes: [Shape], to url: URL) throws
```

Iterates `shapes`, validates each with `BRepCheck_Analyzer`, and adds valid shapes to one
`IGESControl_Writer`. Shapes that fail validation are silently skipped. Throws
`ExportError.exportFailed` if no shapes were successfully added.

- **Parameters:** `shapes` — array of shapes; `url` — output URL.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `IGESControl_Writer::AddShape` called per valid shape.
- **Example:**
  ```swift
  try Exporter.writeIGES(shapes: [rail, sleeper, ballast], to: trackURL)
  ```

---

### `Exporter.igesData(shape:)`

Writes a shape to IGES and returns the file contents as `Data`.

```swift
public static func igesData(shape: Shape) throws -> Data
```

- **Parameters:** `shape` — shape to export.
- **Returns:** IGES file as `Data`.
- **Throws:** Same as `writeIGES(shape:to:)`.
- **OCCT:** `IGESControl_Writer` (via `writeIGES`).
- **Example:**
  ```swift
  let data = try Exporter.igesData(shape: part)
  ```

---

## BREP Export

### `Exporter.writeBREP(shape:to:withTriangles:withNormals:)`

Writes a shape to OCCT's native BREP format.

```swift
public static func writeBREP(
    shape: Shape,
    to url: URL,
    withTriangles: Bool = true,
    withNormals: Bool = false
) throws
```

BREP is OCCT's own serialisation format. It preserves full B-Rep precision (curves, surfaces,
topology) with no conversion loss, and is the fastest format to write and read back. Optionally
embeds existing triangulation data so that re-meshing on import is not required.

- **Parameters:** `shape` — shape to export; `url` — output URL (conventionally `.brep`);
  `withTriangles` — embed triangulation (default `true`);
  `withNormals` — embed per-vertex normals with the triangulation (default `false`).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidShape`; `ExportError.invalidPath`;
  `ExportError.exportFailed` if `BRepTools::Write` fails.
- **OCCT:** `BRepTools::Write(shape, path, withTriangles, withNormals, TopTools_FormatVersion_CURRENT)`.
- **Example:**
  ```swift
  try Exporter.writeBREP(shape: model,
                          to: cacheURL,
                          withTriangles: true,
                          withNormals: false)
  ```
- **Note:** BREP files are not portable across OCCT major versions; use STEP for long-term archival.

---

### `Exporter.brepData(shape:withTriangles:withNormals:)`

Writes a shape to BREP and returns the file contents as `Data`.

```swift
public static func brepData(
    shape: Shape,
    withTriangles: Bool = true,
    withNormals: Bool = false
) throws -> Data
```

- **Parameters:** `shape` — shape; `withTriangles` — embed triangulation; `withNormals` — embed normals.
- **Returns:** BREP file as `Data`.
- **Throws:** Same as `writeBREP`.
- **OCCT:** `BRepTools::Write` (via `writeBREP`).
- **Example:**
  ```swift
  let data = try Exporter.brepData(shape: model)
  ```

---

## OBJ Export

### `Exporter.writeOBJ(shape:to:deflection:)`

Tessellates a shape and writes a Wavefront OBJ file.

```swift
public static func writeOBJ(
    shape: Shape,
    to url: URL,
    deflection: Double = 0.1
) throws
```

OBJ is widely supported for 3D visualisation and modelling. The bridge meshes the shape into
an XCAF document and writes it via `RWObj_CafWriter`.

- **Parameters:** `shape` — shape; `url` — output URL (conventionally `.obj`); `deflection` — tessellation quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidShape`; `ExportError.invalidPath`;
  `ExportError.exportFailed` if `RWObj_CafWriter` fails.
- **OCCT:** `RWObj_CafWriter`.
- **Example:**
  ```swift
  try Exporter.writeOBJ(shape: box, to: URL(fileURLWithPath: "/tmp/box.obj"), deflection: 0.1)
  ```

---

## PLY Export

### `Exporter.writePLY(shape:to:deflection:)`

Tessellates a shape and writes a PLY (Stanford Polygon Format) file.

```swift
public static func writePLY(
    shape: Shape,
    to url: URL,
    deflection: Double = 0.1
) throws
```

PLY is common in 3D scanning and point-cloud pipelines.

- **Parameters:** `shape` — shape; `url` — output URL (conventionally `.ply`); `deflection` — tessellation quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidShape`; `ExportError.invalidPath`;
  `ExportError.exportFailed` if `RWPly_CafWriter` fails.
- **OCCT:** `RWPly_CafWriter`.
- **Example:**
  ```swift
  try Exporter.writePLY(shape: scan, to: URL(fileURLWithPath: "/tmp/scan.ply"))
  ```

---

### `Exporter.writePLY(shape:to:deflection:normals:colors:texCoords:)`

Tessellates a shape and writes a PLY file with optional per-vertex attributes.

```swift
public static func writePLY(shape: Shape, to url: URL, deflection: Double,
                              normals: Bool = true, colors: Bool = false, texCoords: Bool = false) throws
```

- **Parameters:** `shape` — shape; `url` — output URL; `deflection` — tessellation quality;
  `normals` — include per-vertex normals (default `true`);
  `colors` — include per-vertex colour (default `false`);
  `texCoords` — include UV texture coordinates (default `false`).
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath`; `ExportError.exportFailed`.
- **OCCT:** `RWPly_CafWriter` with attribute flags.
- **Example:**
  ```swift
  try Exporter.writePLY(shape: mesh, to: plyURL, deflection: 0.05,
                         normals: true, colors: true, texCoords: false)
  ```

---

## GLTF Export

`Exporter.writeGLTF` is defined in an `extension Exporter` block in `Document.swift`.

### `Exporter.writeGLTF(shape:to:binary:deflection:)`

Tessellates a shape and writes a GLTF or GLB file for real-time rendering or web delivery.

```swift
public static func writeGLTF(shape: Shape, to url: URL, binary: Bool = true, deflection: Double = 0.1) throws
```

`binary: true` (default) produces a self-contained `.glb` file (binary GLTF). `binary: false`
produces a text `.gltf` file. The shape is meshed inside the bridge with the given `deflection`.
To write GLTF with full materials/names from an XCAF document, use `Document.writeGLTF(to:binary:)`
instead.

- **Parameters:** `shape` — shape to tessellate and export; `url` — output URL (`.glb` or `.gltf`);
  `binary` — `true` for GLB, `false` for text GLTF (default `true`);
  `deflection` — tessellation quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `ExportError.exportFailed` if `RWGltf_CafWriter` fails.
- **OCCT:** `RWGltf_CafWriter(path, isBinary)`.
- **Example:**
  ```swift
  // GLB (binary) — single self-contained file
  try Exporter.writeGLTF(shape: box, to: URL(fileURLWithPath: "/tmp/box.glb"))

  // text GLTF
  try Exporter.writeGLTF(shape: box, to: URL(fileURLWithPath: "/tmp/box.gltf"), binary: false)
  ```
- **Note:** There is no separate `writeGLB` method — GLB is `writeGLTF(shape:to:binary:)` with
  `binary: true`.

---

## STEP Optimisation

### `Exporter.optimizeSTEP(input:output:)`

Reads a STEP file, deduplicates shared geometric entities, and writes the result to a new file.

```swift
public static func optimizeSTEP(input: URL, output: URL) throws
```

Can significantly reduce file size for STEP files with repeated geometry (assemblies, patterned
features). The input file is read fresh — no in-memory shape is required.

- **Parameters:** `input` — URL of the source STEP file; `output` — URL for the deduplicated output.
- **Returns:** `Void`.
- **Throws:** `ExportError.invalidPath` if either path is empty;
  `ExportError.exportFailed` if the read-deduplicate-write cycle fails.
- **OCCT:** `STEPControl_Reader` + `STEPControl_Writer` with entity deduplication.
- **Example:**
  ```swift
  try Exporter.optimizeSTEP(
      input:  URL(fileURLWithPath: "/tmp/large.step"),
      output: URL(fileURLWithPath: "/tmp/large_opt.step")
  )
  ```

---

## StepModelType

Defined in `Document.swift`; used by the `writeSTEP` and `writeSTEPCleanDuplicates` overloads.

```swift
public enum StepModelType: Int32, Sendable {
    case asIs                        = 0
    case manifoldSolidBrep           = 1
    case brepWithVoids               = 2
    case facetedBrep                 = 3
    case facetedBrepAndBrepWithVoids = 4
    case shellBasedSurfaceModel      = 5
    case geometricCurveSet           = 6
}
```

Maps to `STEPControl_StepModelType` in OCCT:

| Case | OCCT value | When to use |
|---|---|---|
| `.asIs` | `STEPControl_AsIs` | Automatic — OCCT picks the most appropriate representation. Default for most exports. |
| `.manifoldSolidBrep` | `STEPControl_ManifoldSolidBrep` | Solid bodies only; most interoperable with CAD tools. |
| `.brepWithVoids` | `STEPControl_BrepWithVoids` | Solids with interior voids. |
| `.facetedBrep` | `STEPControl_FacetedBrep` | Polyhedral shapes only. |
| `.facetedBrepAndBrepWithVoids` | `STEPControl_FacetedBrepAndBrepWithVoids` | Mixed polyhedral + voids. |
| `.shellBasedSurfaceModel` | `STEPControl_ShellBasedSurfaceModel` | Open shells, surface models. |
| `.geometricCurveSet` | `STEPControl_GeometricCurveSet` | Wireframe / curve-only exports. |

---

## Shape Convenience Extensions

The following instance methods are defined on `Shape` in `Exporter.swift`. Each delegates
directly to the corresponding `Exporter.write…` static, accepting `self` as the `shape` argument.

### `Shape.writeSTL(to:deflection:)`

```swift
public func writeSTL(to url: URL, deflection: Double = 0.1) throws
```

Delegates to `Exporter.writeSTL(shape:to:deflection:ascii:)` with `ascii: false`.

- **Throws:** Same as `Exporter.writeSTL`.
- **Example:**
  ```swift
  try shape.writeSTL(to: URL(fileURLWithPath: "/tmp/part.stl"), deflection: 0.05)
  ```

---

### `Shape.stlData(deflection:)`

```swift
public func stlData(deflection: Double = 0.1) throws -> Data
```

- **Throws:** Same as `Exporter.stlData`.

---

### `Shape.writeSTEP(to:name:)`

```swift
public func writeSTEP(to url: URL, name: String? = nil) throws
```

- **Throws:** Same as `Exporter.writeSTEP(shape:to:name:)`.
- **Example:**
  ```swift
  try shape.writeSTEP(to: stepURL, name: "Shaft")
  ```

---

### `Shape.writeSTEP(to:modelType:)`

```swift
public func writeSTEP(to url: URL, modelType: StepModelType) throws
```

---

### `Shape.writeSTEP(to:modelType:tolerance:)`

```swift
public func writeSTEP(to url: URL, modelType: StepModelType, tolerance: Double) throws
```

---

### `Shape.writeSTEPCleanDuplicates(to:modelType:)`

```swift
public func writeSTEPCleanDuplicates(to url: URL, modelType: StepModelType = .asIs) throws
```

---

### `Shape.stepData(name:)`

```swift
public func stepData(name: String? = nil) throws -> Data
```

---

### `Shape.writeIGES(to:)`

```swift
public func writeIGES(to url: URL) throws
```

---

### `Shape.igesData()`

```swift
public func igesData() throws -> Data
```

---

### `Shape.writeIGES(to:unit:)`

```swift
public func writeIGES(to url: URL, unit: String) throws
```

---

### `Shape.writeIGESBRep(to:)`

```swift
public func writeIGESBRep(to url: URL) throws
```

---

### `Shape.writeBREP(to:withTriangles:withNormals:)`

```swift
public func writeBREP(to url: URL, withTriangles: Bool = true, withNormals: Bool = false) throws
```

---

### `Shape.brepData(withTriangles:withNormals:)`

```swift
public func brepData(withTriangles: Bool = true, withNormals: Bool = false) throws -> Data
```

---

### `Shape.writeOBJ(to:deflection:)`

```swift
public func writeOBJ(to url: URL, deflection: Double = 0.1) throws
```

---

### `Shape.writePLY(to:deflection:)`

```swift
public func writePLY(to url: URL, deflection: Double = 0.1) throws
```

---

### `Shape.writePLY(to:deflection:normals:colors:texCoords:)`

```swift
public func writePLY(to url: URL, deflection: Double,
                      normals: Bool = true, colors: Bool = false, texCoords: Bool = false) throws
```
