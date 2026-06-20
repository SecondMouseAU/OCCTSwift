---
title: Document — OCAF Attributes, Naming & Elementary Geometry
parent: API Reference
---

# Document — OCAF Attributes, Naming & Elementary Geometry

This page covers the OCAF attribute types, shape-naming extensions, geometry helpers, and elementary curve/surface utilities declared in lines 3350–4958 of `Document.swift`. See the main `Document` page for lifecycle, I/O, label management, and the core XCAF operations.

## Topics

- [Message_Report](#message_report) · [RWMesh_CoordinateSystemConverter](#rwmesh_coordinatesystemconverter) · [TDF_IDFilter](#tdf_idfilter) · [TDataStd_BooleanArray](#tdatastd_booleanarray) · [TDataStd_BooleanList](#tdatastd_booleanlist) · [TDataStd_ByteArray](#tdatastd_bytearray) · [TDataStd_IntegerList](#tdatastd_integerlist) · [TDataStd_RealList](#tdatastd_reallist) · [TDataStd_ExtStringArray](#tdatastd_extstringarray) · [TDataStd_ExtStringList](#tdatastd_extstringlist) · [TDataStd_ReferenceArray](#tdatastd_referencearray) · [TDataStd_ReferenceList](#tdatastd_referencelist) · [TDataStd_Relation](#tdatastd_relation) · [ShapeFix_Solid](#shapefix_solid) · [ShapeFix_EdgeConnect](#shapefix_edgeconnect) · [BRepOffsetAPI_FindContigousEdges](#brepoffsetapi_findcontigousedges) · [TDataStd_Tick](#tdatastd_tick) · [TDataStd_Current](#tdatastd_current) · [ShapeAnalysis_Shell](#shapeanalysis_shell) · [ShapeAnalysis_CanonicalRecognition](#shapeanalysis_canonicalrecognition) · [Geom_Transformation](#geom_transformation) · [Geom_OffsetCurve](#geom_offsetcurve) · [Geom_RectangularTrimmedSurface](#geom_rectangulartrimmedsurface) · [TNaming Extensions](#tnamingextensions) · [TDataStd_IntPackedMap](#tdatastd_intpackedmap) · [TDataStd_NoteBook](#tdatastd_notebook) · [TDataStd_UAttribute](#tdatastd_uattribute) · [TDataStd_ChildNodeIterator](#tdatastd_childnodeiterator) · [TDF_Transaction Named](#tdf_transaction-named) · [TDF_ComparisonTool](#tdf_comparisontool) · [TDocStd_XLinkTool](#tdocstd_xlinktool) · [TFunction_IFunction](#tfunction_ifunction) · [TFunction_Scope](#tfunction_scope) · [TDF_AttributeIterator](#tdf_attributeiterator) · [TDF_ChildIDIterator](#tdf_childiditerator) · [TDocStd_PathParser](#tdocstd_pathparser) · [TFunction_DriverTable](#tfunction_drivertable) · [TNaming_Scope](#tnamingscope) · [TNaming_Translator](#tnamingtraslator) · [TDataXtd_Placement](#tdataxtd_placement) · [TDataXtd_Presentation](#tdataxtd_presentation) · [XCAFDoc_AssemblyIterator](#xcafdoc_assemblyiterator) · [XCAFDoc_DimTol](#xcafdoc_dimtol) · [IntTools_Tools](#inttools_tools) · [ElCLib](#elclib) · [ElSLib](#elslib)

---

## Message_Report

Swift class: `Report` (maps to `Message_Report`). A collection of alerts produced during an operation, queryable by gravity level.

### `Report.init?()`

Create a new empty `Message_Report`.

```swift
public init?()
```

- **Returns:** A new empty report, or `nil` if OCCT allocation failed.
- **OCCT:** `Message_Report` constructor.
- **Example:**
  ```swift
  if let report = Report() {
      // use report.dump() after an operation
  }
  ```

---

### `Report.limit`

Maximum number of alerts the report will collect before discarding further ones.

```swift
public var limit: Int { get set }
```

- **OCCT:** `Message_Report::GetLimit` / `Message_Report::SetLimit`.
- **Example:**
  ```swift
  report.limit = 100
  ```

---

### `Report.clear()`

Remove all alerts from the report.

```swift
public func clear()
```

- **OCCT:** `Message_Report::Clear`.

---

### `Report.clear(gravity:)`

Remove alerts of a specific gravity.

```swift
public func clear(gravity: Messenger.Gravity)
```

- **Parameters:** `gravity` — the severity level whose alerts should be removed.
- **OCCT:** `Message_Report::Clear(Message_Gravity)`.

---

### `Report.dump()`

Serialise all alerts in the report to a human-readable string.

```swift
public func dump() -> String
```

- **Returns:** Multi-line string; empty if the report contains no alerts.
- **OCCT:** `Message_Report::Dump`.
- **Example:**
  ```swift
  if let report = Report() {
      print(report.dump())
  }
  ```

---

### `Report.dump(gravity:)`

Serialise only alerts at the given gravity level.

```swift
public func dump(gravity: Messenger.Gravity) -> String
```

- **Parameters:** `gravity` — the severity level to include.
- **Returns:** Filtered dump string; empty if no matching alerts.
- **OCCT:** `Message_Report::Dump(Message_Gravity, …)`.

---

## RWMesh_CoordinateSystemConverter

Two free functions (module-level) for converting points between Z-up and Y-up coordinate systems with explicit unit scaling.

### `convertCoordinateSystem(x:y:z:from:inputUnit:to:outputUnit:)`

Convert a 3D point between two coordinate systems with unit scaling.

```swift
public func convertCoordinateSystem(
    x: Double, y: Double, z: Double,
    from inputSystem: CoordinateSystem,
    inputUnit: Double,
    to outputSystem: CoordinateSystem,
    outputUnit: Double
) -> SIMD3<Double>
```

- **Parameters:**
  - `x`, `y`, `z` — point in the input system.
  - `inputSystem` — `.zUp` or `.yUp`.
  - `inputUnit` — scale factor of the input unit (e.g. `0.001` for mm→m).
  - `outputSystem` — target coordinate system.
  - `outputUnit` — scale factor of the output unit.
- **Returns:** Point expressed in the output system.
- **OCCT:** `RWMesh_CoordinateSystemConverter::TransformPoint`.
- **Example:**
  ```swift
  let pt = convertCoordinateSystem(x: 0, y: 1, z: 0,
                                   from: .yUp, inputUnit: 1.0,
                                   to: .zUp, outputUnit: 1.0)
  // pt ≈ SIMD3(0, 0, 1)
  ```

---

### `coordinateSystemUpDirection(_:)`

Return the up-axis direction vector for a coordinate system.

```swift
public func coordinateSystemUpDirection(_ system: CoordinateSystem) -> SIMD3<Double>
```

- **Parameters:** `system` — `.zUp` or `.yUp`.
- **Returns:** Unit vector for the up axis (`(0,0,1)` for `.zUp`, `(0,1,0)` for `.yUp`).
- **OCCT:** `RWMesh_CoordinateSystemConverter` axis query.

---

## TDF_IDFilter

### `IDFilter.init?(ignoreAll:)`

Create an attribute-ID filter governing which GUID-keyed attributes are included or excluded during OCAF copy/paste operations.

```swift
public init?(ignoreAll: Bool = true)
```

- **Parameters:** `ignoreAll` — when `true` the filter starts in deny-all mode and only GUIDs explicitly `keep`-ed pass through; when `false` it starts in allow-all mode and only `ignore`-ed GUIDs are excluded.
- **Returns:** A configured filter, or `nil` on allocation failure.
- **OCCT:** `TDF_IDFilter` constructor.
- **Example:**
  ```swift
  if let f = IDFilter(ignoreAll: true) {
      f.keep("2a96b614-ec8b-11d0-bee7-080009dc3333")
  }
  ```

---

### `IDFilter.isIgnoreAll`

Whether the filter is in deny-all (ignore-all) mode.

```swift
public var isIgnoreAll: Bool { get set }
```

- **OCCT:** `TDF_IDFilter::IgnoreAll` / `TDF_IDFilter::IgnoreAll(Standard_Boolean)`.

---

### `IDFilter.keep(_:)`

Mark a GUID as kept (active in ignore-all mode).

```swift
public func keep(_ guidString: String)
```

- **Parameters:** `guidString` — GUID in standard hyphenated form.
- **OCCT:** `TDF_IDFilter::Keep`.

---

### `IDFilter.ignore(_:)`

Mark a GUID as ignored (active in keep-all mode).

```swift
public func ignore(_ guidString: String)
```

- **Parameters:** `guidString` — GUID in standard hyphenated form.
- **OCCT:** `TDF_IDFilter::Ignore`.

---

### `IDFilter.isKept(_:)`

Return `true` if the given GUID would pass the filter.

```swift
public func isKept(_ guidString: String) -> Bool
```

- **OCCT:** `TDF_IDFilter::IsKept`.

---

### `IDFilter.isIgnored(_:)`

Return `true` if the given GUID is excluded by the filter.

```swift
public func isIgnored(_ guidString: String) -> Bool
```

- **OCCT:** `TDF_IDFilter::IsIgnored`.

---

## TDataStd_BooleanArray

Methods on `Document` that store and retrieve a `TDataStd_BooleanArray` attribute on a numbered label. The array is 1-based internally; the Swift API takes zero-based `[Bool]` arrays.

### `setBooleanArray(tag:values:)`

Store a `Bool` array on a label.

```swift
func setBooleanArray(tag: Int, values: [Bool]) -> Bool
```

- **Parameters:** `tag` — label tag; `values` — array to store.
- **Returns:** `true` on success.
- **OCCT:** `TDataStd_BooleanArray::Set`.
- **Example:**
  ```swift
  doc.setBooleanArray(tag: 10, values: [true, false, true])
  ```

---

### `booleanArray(tag:)`

Retrieve the stored `Bool` array.

```swift
func booleanArray(tag: Int) -> [Bool]?
```

- **Returns:** The array, `[]` if empty, or `nil` if no attribute exists.
- **OCCT:** `TDataStd_BooleanArray`.

---

### `hasBooleanArray(tag:)`

Check whether a `TDataStd_BooleanArray` attribute exists.

```swift
func hasBooleanArray(tag: Int) -> Bool
```

- **OCCT:** `TDF_Label::FindAttribute`.

---

## TDataStd_BooleanList

### `setBooleanList(tag:values:)`

Store a `Bool` list attribute on a label.

```swift
func setBooleanList(tag: Int, values: [Bool]) -> Bool
```

- **OCCT:** `TDataStd_BooleanList::Set`.

---

### `booleanList(tag:)`

Retrieve the stored `Bool` list.

```swift
func booleanList(tag: Int) -> [Bool]?
```

- **Returns:** The list, `[]` if empty, or `nil` if not present.
- **OCCT:** `TDataStd_BooleanList`.

---

### `booleanListAppend(tag:value:)`

Append one value to an existing `Bool` list attribute.

```swift
func booleanListAppend(tag: Int, value: Bool) -> Bool
```

- **OCCT:** `TDataStd_BooleanList::Append`.

---

### `booleanListClear(tag:)`

Remove all entries from the `Bool` list attribute.

```swift
func booleanListClear(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_BooleanList::Clear`.

---

### `hasBooleanList(tag:)`

Check whether a `TDataStd_BooleanList` attribute exists.

```swift
func hasBooleanList(tag: Int) -> Bool
```

---

## TDataStd_ByteArray

### `setByteArray(tag:values:)`

Store a `UInt8` array attribute on a label.

```swift
func setByteArray(tag: Int, values: [UInt8]) -> Bool
```

- **OCCT:** `TDataStd_ByteArray::Set`.
- **Example:**
  ```swift
  doc.setByteArray(tag: 20, values: [0xDE, 0xAD, 0xBE, 0xEF])
  ```

---

### `byteArray(tag:)`

Retrieve the stored byte array.

```swift
func byteArray(tag: Int) -> [UInt8]?
```

- **Returns:** The array, `[]` if empty, or `nil` if not present.
- **OCCT:** `TDataStd_ByteArray`.

---

### `hasByteArray(tag:)`

Check whether a `TDataStd_ByteArray` attribute exists.

```swift
func hasByteArray(tag: Int) -> Bool
```

---

## TDataStd_IntegerList

### `setIntegerList(tag:values:)`

Store an `Int32` list attribute on a label.

```swift
func setIntegerList(tag: Int, values: [Int32]) -> Bool
```

- **OCCT:** `TDataStd_IntegerList::Set`.

---

### `integerList(tag:)`

Retrieve the stored `Int32` list.

```swift
func integerList(tag: Int) -> [Int32]?
```

- **Returns:** The list, `[]` if empty, or `nil` if not present.
- **OCCT:** `TDataStd_IntegerList`.

---

### `integerListAppend(tag:value:)`

Append one integer to an existing list attribute.

```swift
func integerListAppend(tag: Int, value: Int32) -> Bool
```

- **OCCT:** `TDataStd_IntegerList::Append`.

---

### `integerListClear(tag:)`

Remove all entries from the integer list attribute.

```swift
func integerListClear(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_IntegerList::Clear`.

---

### `hasIntegerList(tag:)`

Check whether a `TDataStd_IntegerList` attribute exists.

```swift
func hasIntegerList(tag: Int) -> Bool
```

---

## TDataStd_RealList

### `setRealList(tag:values:)`

Store a `Double` list attribute on a label.

```swift
func setRealList(tag: Int, values: [Double]) -> Bool
```

- **OCCT:** `TDataStd_RealList::Set`.

---

### `realList(tag:)`

Retrieve the stored `Double` list.

```swift
func realList(tag: Int) -> [Double]?
```

- **Returns:** The list, `[]` if empty, or `nil` if not present.
- **OCCT:** `TDataStd_RealList`.

---

### `realListAppend(tag:value:)`

Append one real value to an existing list attribute.

```swift
func realListAppend(tag: Int, value: Double) -> Bool
```

- **OCCT:** `TDataStd_RealList::Append`.

---

### `realListClear(tag:)`

Remove all entries from the real list attribute.

```swift
func realListClear(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_RealList::Clear`.

---

### `hasRealList(tag:)`

Check whether a `TDataStd_RealList` attribute exists.

```swift
func hasRealList(tag: Int) -> Bool
```

---

## TDataStd_ExtStringArray

The array is 1-based; `index` in element accessors follows that convention.

### `setExtStringArray(tag:values:)`

Store a `String` array attribute on a label.

```swift
func setExtStringArray(tag: Int, values: [String]) -> Bool
```

- **OCCT:** `TDataStd_ExtStringArray::Set`.
- **Example:**
  ```swift
  doc.setExtStringArray(tag: 30, values: ["alpha", "beta", "gamma"])
  ```

---

### `extStringArrayValue(tag:index:)`

Retrieve one element from the string array by 1-based index.

```swift
func extStringArrayValue(tag: Int, index: Int) -> String?
```

- **Parameters:** `index` — 1-based position.
- **Returns:** The string at that position, or `nil` if out of range or attribute missing.
- **OCCT:** `TDataStd_ExtStringArray::Value`.

---

### `extStringArrayLength(tag:)`

Return the number of elements in the string array.

```swift
func extStringArrayLength(tag: Int) -> Int?
```

- **Returns:** Element count, or `nil` if no attribute exists.
- **OCCT:** `TDataStd_ExtStringArray::Length`.

---

### `hasExtStringArray(tag:)`

Check whether a `TDataStd_ExtStringArray` attribute exists.

```swift
func hasExtStringArray(tag: Int) -> Bool
```

---

## TDataStd_ExtStringList

Elements are 0-based in the Swift API.

### `setExtStringList(tag:values:)`

Store a `String` list attribute on a label (replaces any existing list).

```swift
func setExtStringList(tag: Int, values: [String]) -> Bool
```

- **OCCT:** `TDataStd_ExtStringList::Set`.

---

### `extStringListCount(tag:)`

Return the number of elements in the string list.

```swift
func extStringListCount(tag: Int) -> Int?
```

- **Returns:** Element count, or `nil` if not present.
- **OCCT:** `TDataStd_ExtStringList::Extent`.

---

### `extStringListValue(tag:index:)`

Retrieve one element from the string list by 0-based index.

```swift
func extStringListValue(tag: Int, index: Int) -> String?
```

- **Parameters:** `index` — 0-based position.
- **Returns:** The string, or `nil` if out of range or attribute missing.
- **OCCT:** `TDataStd_ExtStringList` iteration.

---

### `extStringListAppend(tag:value:)`

Append a string to an existing string list attribute.

```swift
func extStringListAppend(tag: Int, value: String) -> Bool
```

- **OCCT:** `TDataStd_ExtStringList::Append`.

---

### `extStringListClear(tag:)`

Remove all entries from the string list attribute.

```swift
func extStringListClear(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_ExtStringList::Clear`.

---

### `hasExtStringList(tag:)`

Check whether a `TDataStd_ExtStringList` attribute exists.

```swift
func hasExtStringList(tag: Int) -> Bool
```

---

## TDataStd_ReferenceArray

Label cross-references stored as `Int32` tag arrays; the array is 1-based internally.

### `setReferenceArray(tag:refTags:)`

Store a reference array (list of label tags) on a label.

```swift
func setReferenceArray(tag: Int, refTags: [Int32]) -> Bool
```

- **OCCT:** `TDataStd_ReferenceArray::Set`.

---

### `referenceArray(tag:)`

Retrieve the stored reference array.

```swift
func referenceArray(tag: Int) -> [Int32]?
```

- **Returns:** Array of label tags, `[]` if empty, or `nil` if not present.
- **OCCT:** `TDataStd_ReferenceArray`.

---

### `hasReferenceArray(tag:)`

Check whether a `TDataStd_ReferenceArray` attribute exists.

```swift
func hasReferenceArray(tag: Int) -> Bool
```

---

## TDataStd_ReferenceList

### `setReferenceList(tag:refTags:)`

Store a reference list (list of label tags) on a label.

```swift
func setReferenceList(tag: Int, refTags: [Int32]) -> Bool
```

- **OCCT:** `TDataStd_ReferenceList::Set`.

---

### `referenceList(tag:)`

Retrieve the stored reference list.

```swift
func referenceList(tag: Int) -> [Int32]?
```

- **Returns:** Array of label tags, `[]` if empty, or `nil` if not present.
- **OCCT:** `TDataStd_ReferenceList`.

---

### `referenceListAppend(tag:refTag:)`

Append a single label tag to the reference list attribute.

```swift
func referenceListAppend(tag: Int, refTag: Int32) -> Bool
```

- **OCCT:** `TDataStd_ReferenceList::Append`.

---

### `referenceListClear(tag:)`

Remove all entries from the reference list attribute.

```swift
func referenceListClear(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_ReferenceList::Clear`.

---

### `hasReferenceList(tag:)`

Check whether a `TDataStd_ReferenceList` attribute exists.

```swift
func hasReferenceList(tag: Int) -> Bool
```

---

## TDataStd_Relation

A single expression string attached to a label; used by parametric solvers to record constraints.

### `setRelation(tag:relation:)`

Attach a relation expression string to a label.

```swift
func setRelation(tag: Int, relation: String) -> Bool
```

- **OCCT:** `TDataStd_Relation::Set`.
- **Example:**
  ```swift
  doc.setRelation(tag: 5, relation: "width = height / 2")
  ```

---

### `relation(tag:)`

Retrieve the relation string stored on a label.

```swift
func relation(tag: Int) -> String?
```

- **Returns:** The expression string, or `nil` if no attribute exists.
- **OCCT:** `TDataStd_Relation::GetRelation`.

---

### `hasRelation(tag:)`

Check whether a `TDataStd_Relation` attribute exists.

```swift
func hasRelation(tag: Int) -> Bool
```

---

## ShapeFix_Solid

Extensions on `Shape` that wrap `ShapeFix_Solid` healing.

### `Shape.fixSolid()`

Fix topology and orientation problems in a solid shape.

```swift
public func fixSolid() -> Shape?
```

- **Returns:** The repaired solid, or `nil` on failure.
- **OCCT:** `ShapeFix_Solid::Perform`.
- **Example:**
  ```swift
  if let solid = importedShape.fixSolid() {
      // solid.isValid == true
  }
  ```

---

### `Shape.solidFromShellFixed()`

Create a closed solid from a shell, using `ShapeFix_Solid` to orient and close the shell.

```swift
public func solidFromShellFixed() -> Shape?
```

- **Returns:** A solid shape, or `nil` if the shell cannot be closed.
- **OCCT:** `ShapeFix_Solid::SolidFromShell`.

---

## ShapeFix_EdgeConnect

### `Shape.fixEdgeConnect()`

Connect edges in a shape by extending or trimming them to meet at their endpoints.

```swift
public func fixEdgeConnect() -> Shape?
```

- **Returns:** The repaired shape, or `nil` on failure.
- **OCCT:** `ShapeFix_EdgeConnect::Build`.

---

## BRepOffsetAPI_FindContigousEdges

### `Shape.ContigousEdgeResult`

Result value type returned by `findContigousEdges(tolerance:)`.

```swift
public struct ContigousEdgeResult: Sendable {
    public let contigousEdgeCount: Int
    public let degeneratedShapeCount: Int
}
```

- `contigousEdgeCount` — number of edge pairs found to be geometrically contiguous.
- `degeneratedShapeCount` — number of degenerate sub-shapes encountered.

---

### `Shape.findContigousEdges(tolerance:)`

Find contiguous (sewable) edge pairs in a shape within the given tolerance.

```swift
public func findContigousEdges(tolerance: Double = 1.0e-6) -> ContigousEdgeResult
```

- **Parameters:** `tolerance` — maximum gap between edge endpoints to be considered contiguous.
- **Returns:** A `ContigousEdgeResult` with counts; always succeeds (returns zero counts if none found).
- **OCCT:** `BRepOffsetAPI_FindContigousEdges::Perform`.
- **Example:**
  ```swift
  let result = myShell.findContigousEdges(tolerance: 1e-5)
  print("contiguous pairs:", result.contigousEdgeCount)
  ```

---

## TDataStd_Tick

A presence-only boolean flag attribute (no value — its existence on a label is the signal).

### `setTick(tag:)`

Attach a tick (marker) attribute to a label.

```swift
func setTick(tag: Int) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TDataStd_Tick::Set`.

---

### `hasTick(tag:)`

Check whether a tick attribute is present on a label.

```swift
func hasTick(tag: Int) -> Bool
```

- **OCCT:** `TDF_Label::FindAttribute`.

---

### `removeTick(tag:)`

Remove the tick attribute from a label.

```swift
func removeTick(tag: Int) -> Bool
```

- **OCCT:** `TDF_Label::ForgetAttribute`.

---

## TDataStd_Current

Marks one label in the document as the "current" label — a document-wide cursor concept used by some interactive tools.

### `setCurrentLabel(tag:)`

Make a label the current label.

```swift
func setCurrentLabel(tag: Int) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TDataStd_Current::Set`.

---

### `currentLabel()`

Return the tag of the current label.

```swift
func currentLabel() -> Int?
```

- **Returns:** Tag integer, or `nil` if no current label is set.
- **OCCT:** `TDataStd_Current::Get`.

---

### `hasCurrentLabel()`

Check whether the document has a current label set.

```swift
func hasCurrentLabel() -> Bool
```

- **OCCT:** `TDataStd_Current` attribute presence check.

---

## ShapeAnalysis_Shell

### `Shape.ShellAnalysisResult`

Result value type returned by `analyzeShell()`.

```swift
public struct ShellAnalysisResult: Sendable {
    public let hasOrientationProblems: Bool
    public let hasFreeEdges: Bool
    public let hasBadEdges: Bool
    public let hasConnectedEdges: Bool
    public let freeEdgeCount: Int
}
```

---

### `Shape.analyzeShell()`

Analyse shell orientation and edge connectivity.

```swift
public func analyzeShell() -> ShellAnalysisResult
```

- **Returns:** A `ShellAnalysisResult` with flags and counts; always returns (checks never throw).
- **OCCT:** `ShapeAnalysis_Shell::CheckOrientedShells`.
- **Example:**
  ```swift
  let info = shell.analyzeShell()
  if info.hasFreeEdges {
      print("open shell — \(info.freeEdgeCount) free edges")
  }
  ```

---

## ShapeAnalysis_CanonicalRecognition

Detailed recognition that also returns the geometry parameters (origin, direction, radii/angles).

### `Shape.CanonicalGeometryType`

Discriminator for the recognised geometry class.

```swift
public enum CanonicalGeometryType: Int, Sendable {
    case none = 0
    case plane = 1
    case cylinder = 2
    case cone = 3
    case sphere = 4
    case line = 5
    case circle = 6
    case ellipse = 7
}
```

---

### `Shape.CanonicalRecognitionResult`

Full result of canonical recognition, including numeric parameters.

```swift
public struct CanonicalRecognitionResult: Sendable {
    public let type: CanonicalGeometryType
    public let gap: Double
    public let origin: (x: Double, y: Double, z: Double)
    public let direction: (x: Double, y: Double, z: Double)
    public let param1: Double
    public let param2: Double
}
```

- `gap` — deviation from the ideal canonical shape.
- `origin` / `direction` — position and axis of the canonical geometry.
- `param1` / `param2` — primary and secondary size parameters (e.g. radius, semi-angle).

---

### `Shape.recognizeCanonicalSurface(tolerance:)`

Attempt to recognise the underlying surface geometry of a face as a canonical type.

```swift
public func recognizeCanonicalSurface(tolerance: Double = 0.01) -> CanonicalRecognitionResult
```

- **Parameters:** `tolerance` — maximum allowed deviation for a positive recognition.
- **Returns:** Result with `.type == .none` if no match within tolerance.
- **OCCT:** `ShapeAnalysis_CanonicalRecognition::IsCanonicalSurface`.
- **Example:**
  ```swift
  let r = face.recognizeCanonicalSurface(tolerance: 0.001)
  if r.type == .cylinder {
      print("radius:", r.param1)
  }
  ```

---

### `Shape.recognizeCanonicalCurve(tolerance:)`

Attempt to recognise the underlying curve of an edge as a canonical type.

```swift
public func recognizeCanonicalCurve(tolerance: Double = 0.01) -> CanonicalRecognitionResult
```

- **Parameters:** `tolerance` — maximum allowed deviation.
- **Returns:** Result with `.type == .none` if no match.
- **OCCT:** `ShapeAnalysis_CanonicalRecognition::IsCanonicalCurve`.

---

## Geom_Transformation

Swift class `GeomTransformation` wrapping `Geom_Transformation` (a handle-based 3D affine transform that can be composed and inverted).

### `GeomTransformation.init?()`

Create an identity transformation.

```swift
public init?()
```

- **Returns:** A new identity transform, or `nil` on allocation failure.
- **OCCT:** `Geom_Transformation` constructor.

---

### `GeomTransformation.setTranslation(dx:dy:dz:)`

Set this transformation to a pure translation.

```swift
public func setTranslation(dx: Double, dy: Double, dz: Double)
```

- **OCCT:** `Geom_Transformation::SetTranslation`.

---

### `GeomTransformation.setRotation(originX:originY:originZ:dirX:dirY:dirZ:angle:)`

Set this transformation to a rotation about an arbitrary axis.

```swift
public func setRotation(
    originX: Double, originY: Double, originZ: Double,
    dirX: Double, dirY: Double, dirZ: Double,
    angle: Double
)
```

- **Parameters:** `originX/Y/Z` — axis origin; `dirX/Y/Z` — axis direction (need not be normalised); `angle` — rotation angle in radians.
- **OCCT:** `Geom_Transformation::SetRotation`.
- **Example:**
  ```swift
  let t = GeomTransformation()!
  t.setRotation(originX: 0, originY: 0, originZ: 0,
                dirX: 0, dirY: 0, dirZ: 1,
                angle: .pi / 4)
  ```

---

### `GeomTransformation.setScale(centerX:centerY:centerZ:factor:)`

Set this transformation to uniform scaling about a centre point.

```swift
public func setScale(centerX: Double, centerY: Double, centerZ: Double, factor: Double)
```

- **OCCT:** `Geom_Transformation::SetScale`.

---

### `GeomTransformation.setMirrorPoint(x:y:z:)`

Set this transformation to a point-mirror (inversion through a point).

```swift
public func setMirrorPoint(x: Double, y: Double, z: Double)
```

- **OCCT:** `Geom_Transformation::SetMirror(gp_Pnt)`.

---

### `GeomTransformation.setMirrorAxis(originX:originY:originZ:dirX:dirY:dirZ:)`

Set this transformation to a mirror about an axis.

```swift
public func setMirrorAxis(
    originX: Double, originY: Double, originZ: Double,
    dirX: Double, dirY: Double, dirZ: Double
)
```

- **OCCT:** `Geom_Transformation::SetMirror(gp_Ax1)`.

---

### `GeomTransformation.scaleFactor`

The scale factor of this transformation (1.0 for pure rotations).

```swift
public var scaleFactor: Double { get }
```

- **OCCT:** `Geom_Transformation::ScaleFactor`.

---

### `GeomTransformation.isNegative`

`true` if the transformation includes a reflection (determinant < 0).

```swift
public var isNegative: Bool { get }
```

- **OCCT:** `Geom_Transformation::IsNegative`.

---

### `GeomTransformation.apply(x:y:z:)`

Apply this transformation to a point and return the result.

```swift
public func apply(x: Double, y: Double, z: Double) -> (x: Double, y: Double, z: Double)
```

- **Returns:** Transformed point coordinates.
- **OCCT:** `Geom_Transformation::TransformCoord` / `gp_Trsf::Transforms`.
- **Example:**
  ```swift
  let t = GeomTransformation()!
  t.setTranslation(dx: 5, dy: 0, dz: 0)
  let p = t.apply(x: 1, y: 0, z: 0)
  // p.x == 6
  ```

---

### `GeomTransformation.value(row:col:)`

Read one element of the 3×4 transformation matrix.

```swift
public func value(row: Int, col: Int) -> Double
```

- **Parameters:** `row` — 1 to 3; `col` — 1 to 4.
- **OCCT:** `Geom_Transformation::Value`.

---

### `GeomTransformation.multiplied(by:)`

Compose two transformations and return the result as a new object.

```swift
public func multiplied(by other: GeomTransformation) -> GeomTransformation?
```

- **Returns:** `self ∘ other`, or `nil` on failure.
- **OCCT:** `Geom_Transformation::Multiplied`.

---

### `GeomTransformation.inverted()`

Return the inverse of this transformation.

```swift
public func inverted() -> GeomTransformation?
```

- **Returns:** The inverse, or `nil` if the transformation is singular.
- **OCCT:** `Geom_Transformation::Inverted`.

---

## Geom_OffsetCurve

Extensions on `Curve3D` for offset curves.

### `Curve3D.offset(basis:offset:dirX:dirY:dirZ:)`

Create a `Geom_OffsetCurve` at a fixed lateral distance from a basis curve.

```swift
public static func offset(
    basis: Curve3D,
    offset: Double,
    dirX: Double, dirY: Double, dirZ: Double
) -> Curve3D?
```

- **Parameters:** `basis` — the underlying curve; `offset` — lateral distance; `dirX/Y/Z` — the offset direction (perpendicular to the curve tangent).
- **Returns:** The offset curve, or `nil` on failure.
- **OCCT:** `Geom_OffsetCurve` constructor.
- **Example:**
  ```swift
  if let line = Curve3D.line(originX: 0, originY: 0, originZ: 0,
                              dirX: 1, dirY: 0, dirZ: 0),
     let off = Curve3D.offset(basis: line, offset: 2.0,
                               dirX: 0, dirY: 1, dirZ: 0) {
      // off is a parallel line at y = 2
  }
  ```

---

### `Curve3D.offsetValue`

The stored lateral offset distance (0 if this is not an offset curve).

```swift
public var offsetValue: Double { get }
```

- **OCCT:** `Geom_OffsetCurve::Offset`.

---

### `Curve3D.offsetDirection`

The offset direction vector, or `nil` if this is not an offset curve.

```swift
public var offsetDirection: (x: Double, y: Double, z: Double)? { get }
```

- **OCCT:** `Geom_OffsetCurve::Direction`.

---

## Geom_RectangularTrimmedSurface

Extensions on `Surface` for trimming an infinite (or semi-infinite) surface to a finite rectangular parameter window.

### `Surface.rectangularTrimmed(basis:u1:u2:v1:v2:)`

Trim a surface to a rectangular parameter range `[u1, u2] × [v1, v2]`.

```swift
public static func rectangularTrimmed(
    basis: Surface,
    u1: Double, u2: Double,
    v1: Double, v2: Double
) -> Surface?
```

- **Parameters:** `basis` — the underlying (possibly infinite) surface; `u1`/`u2` — parameter bounds in U; `v1`/`v2` — bounds in V.
- **Returns:** The trimmed surface, or `nil` on failure.
- **OCCT:** `Geom_RectangularTrimmedSurface` constructor.
- **Note:** Infinite OCCT surfaces (planes, cylinders, cones) must be trimmed before converting to BSpline — this is the standard approach.
- **Example:**
  ```swift
  if let plane = Surface.plane(originX: 0, originY: 0, originZ: 0,
                                normalX: 0, normalY: 0, normalZ: 1),
     let patch = Surface.rectangularTrimmed(basis: plane,
                                             u1: 0, u2: 10,
                                             v1: 0, v2: 10) {
      // patch is a 10×10 finite planar surface
  }
  ```

---

### `Surface.trimmedInU(basis:param1:param2:)`

Trim a surface in the U direction only, leaving V unbounded.

```swift
public static func trimmedInU(basis: Surface, param1: Double, param2: Double) -> Surface?
```

- **OCCT:** `Geom_RectangularTrimmedSurface` U-trim constructor.

---

### `Surface.trimmedInV(basis:param1:param2:)`

Trim a surface in the V direction only, leaving U unbounded.

```swift
public static func trimmedInV(basis: Surface, param1: Double, param2: Double) -> Surface?
```

- **OCCT:** `Geom_RectangularTrimmedSurface` V-trim constructor.

---

## TNaming Extensions

Extensions on `Document` that expose the `TNaming_NamedShape` attribute, which records the history of topological shapes across modelling steps.

### `Document.namingIsEmpty(on:)`

Check whether the `TNaming_NamedShape` attribute on a node's label holds no shapes.

```swift
public func namingIsEmpty(on node: AssemblyNode) -> Bool
```

- **OCCT:** `TNaming_NamedShape::IsEmpty`.

---

### `Document.namingVersion(on:)`

Get the version number of the `TNaming_NamedShape` attribute on a node.

```swift
public func namingVersion(on node: AssemblyNode) -> Int
```

- **OCCT:** `TNaming_NamedShape::Version`.

---

### `Document.setNamingVersion(on:version:)`

Set the version number of a `TNaming_NamedShape` attribute.

```swift
@discardableResult
public func setNamingVersion(on node: AssemblyNode, version: Int) -> Bool
```

- **OCCT:** `TNaming_NamedShape::SetVersion`.

---

### `Document.namingOriginalShape(on:)`

Retrieve the original (pre-modification) shape stored in a named shape attribute.

```swift
public func namingOriginalShape(on node: AssemblyNode) -> Shape?
```

- **Returns:** The old shape, or `nil` if none recorded.
- **OCCT:** `TNaming_NamedShape::Get` / `TNaming_Iterator`.

---

### `Document.namingHasLabel(shape:)`

Check whether `shape` has a corresponding label in the document's naming framework.

```swift
public func namingHasLabel(shape: Shape) -> Bool
```

- **OCCT:** `TNaming_Tool::HasLabel`.

---

### `Document.namingFindLabel(shape:)`

Find the `AssemblyNode` for `shape` in the naming framework.

```swift
public func namingFindLabel(shape: Shape) -> AssemblyNode?
```

- **Returns:** The node, or `nil` if the shape is not registered.
- **OCCT:** `TNaming_Tool::Label`.

---

### `Document.namingValidUntil(shape:)`

Return the transaction number up to which `shape` is considered valid.

```swift
public func namingValidUntil(shape: Shape) -> Int
```

- **OCCT:** `TNaming_Tool::ValidUntil`.

---

### `Document.sameShapeCount(shape:)`

Count how many labels in the document contain the same topological shape.

```swift
public func sameShapeCount(shape: Shape) -> Int
```

- **OCCT:** `TNaming_Tool::SameShape` count variant.

---

### `Document.sameShapeLabels(shape:)`

Return all `AssemblyNode`s whose `TNaming_NamedShape` contains `shape`.

```swift
public func sameShapeLabels(shape: Shape) -> [AssemblyNode]
```

- **Returns:** Empty array if no labels carry the shape.
- **OCCT:** `TNaming_Tool::SameShape`.

---

## TDataStd_IntPackedMap

A set of integers stored as a compact bit-map on a label. Suitable for large sparse integer sets.

### `Document.setIntPackedMap(tag:isDelta:)`

Create (or reset) an `IntPackedMap` attribute on a label.

```swift
@discardableResult
public func setIntPackedMap(tag: Int, isDelta: Bool = false) -> Bool
```

- **Parameters:** `isDelta` — when `true` the map records incremental changes for undo/redo; `false` stores the absolute set.
- **OCCT:** `TDataStd_IntPackedMap::Set`.

---

### `Document.intPackedMapAdd(tag:value:)`

Insert an integer into the packed map.

```swift
@discardableResult
public func intPackedMapAdd(tag: Int, value: Int) -> Bool
```

- **OCCT:** `TDataStd_IntPackedMap::Add`.

---

### `Document.intPackedMapRemove(tag:value:)`

Remove an integer from the packed map.

```swift
@discardableResult
public func intPackedMapRemove(tag: Int, value: Int) -> Bool
```

- **OCCT:** `TDataStd_IntPackedMap::Remove`.

---

### `Document.intPackedMapContains(tag:value:)`

Return `true` if the packed map contains the given integer.

```swift
public func intPackedMapContains(tag: Int, value: Int) -> Bool
```

- **OCCT:** `TDataStd_IntPackedMap::Contains`.

---

### `Document.intPackedMapCount(tag:)`

Return the number of integers in the packed map.

```swift
public func intPackedMapCount(tag: Int) -> Int
```

- **OCCT:** `TDataStd_IntPackedMap::Extent`.

---

### `Document.intPackedMapClear(tag:)`

Remove all integers from the packed map.

```swift
@discardableResult
public func intPackedMapClear(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_IntPackedMap::Clear`.

---

### `Document.intPackedMapIsEmpty(tag:)`

Return `true` if the packed map has no entries.

```swift
public func intPackedMapIsEmpty(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_IntPackedMap::IsEmpty`.

---

### `Document.intPackedMapValues(tag:)`

Return all integers currently in the packed map.

```swift
public func intPackedMapValues(tag: Int) -> [Int]
```

- **Returns:** Empty array if the map is empty or not found.
- **OCCT:** `TDataStd_IntPackedMap` + `TColStd_PackedMapOfInteger` iteration.

---

### `Document.intPackedMapSetValues(tag:values:)`

Replace the entire contents of the packed map.

```swift
@discardableResult
public func intPackedMapSetValues(tag: Int, values: [Int]) -> Bool
```

- **OCCT:** `TDataStd_IntPackedMap::ChangeMap`.

---

## TDataStd_NoteBook

A hierarchical container attribute for accumulating named scalar values. Useful for parameter spreadsheets in OCAF documents.

### `Document.setNoteBook(tag:)`

Create a `NoteBook` attribute on a label (or find the existing one).

```swift
@discardableResult
public func setNoteBook(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_NoteBook::New`.

---

### `Document.noteBookAppendReal(tag:value:)`

Append a real (double) value to the NoteBook and return the child label tag.

```swift
public func noteBookAppendReal(tag: Int, value: Double) -> Int?
```

- **Returns:** The child label tag where the value is stored, or `nil` on failure.
- **OCCT:** `TDataStd_NoteBook::Append(Standard_Real)`.

---

### `Document.noteBookAppendInteger(tag:value:)`

Append an integer value to the NoteBook and return the child label tag.

```swift
public func noteBookAppendInteger(tag: Int, value: Int) -> Int?
```

- **Returns:** The child label tag, or `nil` on failure.
- **OCCT:** `TDataStd_NoteBook::Append(Standard_Integer)`.

---

### `Document.noteBookExists(tag:)`

Check whether a NoteBook attribute exists on or above `tag` in the label hierarchy.

```swift
public func noteBookExists(tag: Int) -> Bool
```

- **OCCT:** `TDataStd_NoteBook::Find`.

---

## TDataStd_UAttribute

A user-defined marker attribute identified by a GUID. Acts as a typed tag with no payload beyond its identifier.

### `Document.setUAttribute(tag:guid:)`

Attach a `UAttribute` with the given GUID to a label.

```swift
@discardableResult
public func setUAttribute(tag: Int, guid: String) -> Bool
```

- **OCCT:** `TDataStd_UAttribute::Set`.

---

### `Document.hasUAttribute(tag:guid:)`

Check whether a `UAttribute` with the given GUID exists on a label.

```swift
public func hasUAttribute(tag: Int, guid: String) -> Bool
```

- **OCCT:** `TDF_Label::FindAttribute`.

---

### `Document.uAttributeID(tag:guid:)`

Retrieve the GUID string of a `UAttribute` from a label (round-trips the GUID through OCCT's `Standard_GUID`).

```swift
public func uAttributeID(tag: Int, guid: String) -> String?
```

- **Returns:** The normalised GUID string, or `nil` if not found.
- **OCCT:** `TDataStd_UAttribute::ID`.

---

## TDataStd_ChildNodeIterator

### `Document.childNodeCount(tag:allLevels:)`

Count the tree-node children on a label.

```swift
public func childNodeCount(tag: Int, allLevels: Bool = false) -> Int
```

- **Parameters:** `allLevels` — when `true`, count descendants at all depths; `false` counts direct children only.
- **OCCT:** `TDataStd_ChildNodeIterator`.

---

## TDF_Transaction Named

Named-transaction extensions on `Document` plus the `TransactionDelta` value type.

### `Document.openNamedTransaction(_:)`

Open a new transaction and assign it a human-readable name.

```swift
@discardableResult
public func openNamedTransaction(_ name: String) -> Int
```

- **Parameters:** `name` — a label used to identify this transaction in undo histories.
- **Returns:** Transaction number (≥ 1 on success, 0 on error).
- **OCCT:** `TDocStd_Document::NewCommand` + `TDF_Transaction::Open`.

---

### `Document.transactionNumber`

The current (open) transaction number.

```swift
public var transactionNumber: Int { get }
```

- **OCCT:** `TDF_Data::Transaction`.

---

### `Document.commitWithDelta()`

Commit the current transaction and return a `TransactionDelta` describing what changed.

```swift
public func commitWithDelta() -> TransactionDelta?
```

- **Returns:** A delta object, or `nil` if the transaction contained no changes.
- **OCCT:** `TDF_Transaction::Commit`.
- **Example:**
  ```swift
  doc.openNamedTransaction("add part")
  // ... make changes ...
  if let delta = doc.commitWithDelta() {
      print("changed attributes:", delta.attributeDeltaCount)
  }
  ```

---

### `TransactionDelta.isEmpty`

Whether the delta contains no recorded attribute changes.

```swift
public var isEmpty: Bool { get }
```

- **OCCT:** `TDF_Delta::IsEmpty`.

---

### `TransactionDelta.beginTime`

The transaction number at which the delta begins.

```swift
public var beginTime: Int { get }
```

- **OCCT:** `TDF_Delta::BeginTime`.

---

### `TransactionDelta.endTime`

The transaction number at which the delta ends.

```swift
public var endTime: Int { get }
```

- **OCCT:** `TDF_Delta::EndTime`.

---

### `TransactionDelta.attributeDeltaCount`

The number of individual attribute changes recorded in this delta.

```swift
public var attributeDeltaCount: Int { get }
```

- **OCCT:** `TDF_Delta::AttributeDeltas` list extent.

---

### `TransactionDelta.setName(_:)`

Assign a display name to this delta.

```swift
public func setName(_ name: String)
```

- **OCCT:** `TDF_Delta::SetName`.

---

### `TransactionDelta.name`

The display name of this delta, if one was set.

```swift
public var name: String? { get }
```

- **OCCT:** `TDF_Delta::Name`.

---

## TDF_ComparisonTool

### `Document.isSelfContained(labelId:)`

Check that all references from a label's sub-tree stay within that sub-tree (no dangling cross-references).

```swift
public func isSelfContained(labelId: Int64) -> Bool
```

- **Parameters:** `labelId` — root label to inspect.
- **Returns:** `true` if no reference leaves the sub-tree.
- **OCCT:** `TDF_ComparisonTool::IsSelfContained`.

---

## TDocStd_XLinkTool

Label-copy operations that optionally record cross-document links.

### `Document.xlinkCopy(targetLabelId:sourceLabelId:)`

Copy a label and all its attributes to another label within (or across) the same document.

```swift
@discardableResult
public func xlinkCopy(targetLabelId: Int64, sourceLabelId: Int64) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TDocStd_XLinkTool::Copy`.

---

### `Document.xlinkCopyWithLink(targetLabelId:sourceLabelId:)`

Copy a label and record an XLink attribute on the target so the origin can be tracked.

```swift
@discardableResult
public func xlinkCopyWithLink(targetLabelId: Int64, sourceLabelId: Int64) -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `TDocStd_XLinkTool::CopyWithLink`.

---

## TFunction_IFunction

The OCAF parametric function mechanism allows labels to carry a "function" with an execution status. These methods manage that mechanism.

### `Document.FunctionExecutionStatus`

Execution state of a function attached to a label.

```swift
public enum FunctionExecutionStatus: Int32 {
    case wrongDefinition = 0
    case notExecuted = 1
    case executing = 2
    case succeeded = 3
    case failed = 4
}
```

---

### `Document.newFunction(labelId:guid:)`

Attach a function definition to a label. Creates a `TFunction_Scope` at the document root if one does not exist.

```swift
@discardableResult
public func newFunction(labelId: Int64, guid: String) -> Bool
```

- **Parameters:** `labelId` — label to attach to; `guid` — identifies the driver.
- **Returns:** `true` on success.
- **OCCT:** `TFunction_IFunction::NewFunction`.

---

### `Document.deleteFunction(labelId:)`

Remove a function from a label.

```swift
@discardableResult
public func deleteFunction(labelId: Int64) -> Bool
```

- **OCCT:** `TFunction_IFunction::DeleteFunction`.

---

### `Document.functionExecStatus(labelId:)`

Get the execution status of the function on a label.

```swift
public func functionExecStatus(labelId: Int64) -> FunctionExecutionStatus?
```

- **Returns:** The status, or `nil` if no function is attached to the label.
- **OCCT:** `TFunction_IFunction::GetStatus`.

---

### `Document.setFunctionExecStatus(labelId:status:)`

Set the execution status of the function on a label.

```swift
@discardableResult
public func setFunctionExecStatus(labelId: Int64, status: FunctionExecutionStatus) -> Bool
```

- **OCCT:** `TFunction_IFunction::SetStatus`.

---

## TFunction_Scope

The function scope is a root-level index of all functions registered in the document.

### `Document.setFunctionScope()`

Find or create the `TFunction_Scope` on the document root.

```swift
@discardableResult
public func setFunctionScope() -> Bool
```

- **OCCT:** `TFunction_Scope::Set`.

---

### `Document.functionScopeAdd(labelId:)`

Register a label as a function in the scope.

```swift
@discardableResult
public func functionScopeAdd(labelId: Int64) -> Bool
```

- **OCCT:** `TFunction_Scope::AddFunction`.

---

### `Document.functionScopeRemove(labelId:)`

Unregister a label from the scope.

```swift
@discardableResult
public func functionScopeRemove(labelId: Int64) -> Bool
```

- **OCCT:** `TFunction_Scope::RemoveFunction`.

---

### `Document.functionScopeHas(labelId:)`

Check whether a label is registered in the scope.

```swift
public func functionScopeHas(labelId: Int64) -> Bool
```

- **OCCT:** `TFunction_Scope::HasFunction`.

---

### `Document.functionScopeRemoveAll()`

Unregister all functions from the scope.

```swift
@discardableResult
public func functionScopeRemoveAll() -> Bool
```

- **OCCT:** `TFunction_Scope::RemoveAllFunctions`.

---

### `Document.functionScopeCount`

Number of functions registered in the scope.

```swift
public var functionScopeCount: Int { get }
```

- **OCCT:** `TFunction_Scope::GetFunctions` count.

---

### `Document.functionScopeFreeID`

The next available function ID that can be assigned within the scope.

```swift
public var functionScopeFreeID: Int { get }
```

- **OCCT:** `TFunction_Scope::GetFreeID`.

---

## TDF_AttributeIterator

### `Document.attributeCount(labelId:withoutForgotten:)`

Count the attributes on a label.

```swift
public func attributeCount(labelId: Int64, withoutForgotten: Bool = true) -> Int
```

- **Parameters:** `withoutForgotten` — when `true` (default) skips attributes that have been "forgotten" (logically deleted in the current transaction).
- **OCCT:** `TDF_AttributeIterator`.

---

### `Document.dataSetIsEmpty(labelId:)`

Return `true` if the label has never had any content added to the data framework.

```swift
public func dataSetIsEmpty(labelId: Int64) -> Bool
```

- **Note:** Returns `false` (i.e. "not empty") when the label has been used, even if all attributes were later removed.
- **OCCT:** `TDF_DataSet::IsEmpty` / label content check.

---

## TDF_ChildIDIterator

### `Document.childIDCount(labelId:guid:allLevels:)`

Count child labels that carry an attribute with the given GUID.

```swift
public func childIDCount(labelId: Int64, guid: String, allLevels: Bool = false) -> Int
```

- **Parameters:** `labelId` — parent label; `guid` — attribute type GUID; `allLevels` — if `true`, recurse into all descendants.
- **OCCT:** `TDF_ChildIDIterator`.

---

## TDocStd_PathParser

Static utilities for decomposing a file path into its components, wrapping `TDocStd_PathParser`.

### `PathParser.trek(_:)`

Extract the directory (trek) component from a file path.

```swift
public static func trek(_ path: String) -> String?
```

- **Returns:** Directory portion, or `nil` on parse failure.
- **OCCT:** `TDocStd_PathParser::Trek`.
- **Example:**
  ```swift
  PathParser.trek("/Users/foo/model.stp")   // → "/Users/foo"
  ```

---

### `PathParser.name(_:)`

Extract the filename without extension from a file path.

```swift
public static func name(_ path: String) -> String?
```

- **Returns:** Base name, or `nil` on parse failure.
- **OCCT:** `TDocStd_PathParser::Name`.

---

### `PathParser.fileExtension(_:)`

Extract the file extension from a file path.

```swift
public static func fileExtension(_ path: String) -> String?
```

- **Returns:** Extension (without leading `.`), or `nil` on parse failure.
- **OCCT:** `TDocStd_PathParser::Extension`.

---

## TFunction_DriverTable

Global registry that maps function GUIDs to their driver implementations.

### `FunctionDriverTable.hasDriver(guid:)`

Check whether a driver with the given GUID is registered in the global table.

```swift
public static func hasDriver(guid: String) -> Bool
```

- **OCCT:** `TFunction_DriverTable::HasDriver`.

---

### `FunctionDriverTable.clear()`

Remove all driver registrations from the global table.

```swift
public static func clear()
```

- **OCCT:** `TFunction_DriverTable::Clear`.
- **Note:** This affects the process-global singleton; use with care in tests.

---

## TNaming_Scope

Controls which labels are considered "valid" within a naming scope, influencing shape-evolution queries.

### `Document.namingScopeValid(labelId:)`

Mark a label as valid in the naming scope.

```swift
@discardableResult
public func namingScopeValid(labelId: Int64) -> Bool
```

- **OCCT:** `TNaming_Scope::Valid`.

---

### `Document.namingScopeValidChildren(labelId:withRoot:)`

Mark a label and its descendants as valid.

```swift
@discardableResult
public func namingScopeValidChildren(labelId: Int64, withRoot: Bool = true) -> Bool
```

- **Parameters:** `withRoot` — include the label itself when `true`.
- **OCCT:** `TNaming_Scope::ValidChildren`.

---

### `Document.namingScopeIsValid(labelId:)`

Check whether a label is in the valid set.

```swift
public func namingScopeIsValid(labelId: Int64) -> Bool
```

- **OCCT:** `TNaming_Scope::IsValid`.

---

### `Document.namingScopeUnvalid(labelId:)`

Remove a label from the valid set.

```swift
@discardableResult
public func namingScopeUnvalid(labelId: Int64) -> Bool
```

- **OCCT:** `TNaming_Scope::Unvalid`.

---

### `Document.namingScopeClear()`

Clear all labels from the valid set.

```swift
public func namingScopeClear()
```

- **OCCT:** `TNaming_Scope::Clear`.

---

### `Document.namingScopeValidCount`

Number of labels currently in the valid set.

```swift
public var namingScopeValidCount: Int { get }
```

- **OCCT:** `TNaming_Scope::GetValid` map extent.

---

## TNaming_Translator

Extensions on `Shape` for deep-copying shapes via `TNaming_Translator` (produces topologically independent copies).

### `Shape.translatorCopy()`

Create a deep copy of this shape. The copy shares no `TShape` pointers with the original.

```swift
public func translatorCopy() -> Shape?
```

- **Returns:** An independent copy, or `nil` on failure.
- **OCCT:** `TNaming_Translator::Add` + `TNaming_Translator::Perform`.
- **Example:**
  ```swift
  if let copy = solid.translatorCopy() {
      // solid.isSame(as: copy) == false
  }
  ```

---

### `Shape.isSame(as:)`

Return `true` if two shapes share the same underlying `TShape` (pointer-level equality).

```swift
public func isSame(as other: Shape) -> Bool
```

- **OCCT:** `TopoDS_Shape::IsSame`.

---

## TDataXtd_Placement

A marker attribute that designates a label as a geometric placement point (no position data; presence is the signal).

### `Document.setPlacement(labelId:)`

Attach a placement marker attribute to a label.

```swift
@discardableResult
public func setPlacement(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_Placement::Set`.

---

### `Document.hasPlacement(labelId:)`

Check whether a label carries a placement marker.

```swift
public func hasPlacement(labelId: Int64) -> Bool
```

- **OCCT:** `TDF_Label::FindAttribute(TDataXtd_Placement::GetID())`.

---

## TDataXtd_Presentation

Stores AIS presentation parameters (color, transparency, line width, display mode) on a label.

### `Document.setPresentation(labelId:driverGUID:)`

Attach a presentation attribute to a label, associated with the given AIS driver GUID.

```swift
@discardableResult
public func setPresentation(labelId: Int64, driverGUID: String) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::Set`.

---

### `Document.unsetPresentation(labelId:)`

Remove the presentation attribute from a label.

```swift
public func unsetPresentation(labelId: Int64)
```

- **OCCT:** `TDF_Label::ForgetAttribute(TDataXtd_Presentation::GetID())`.

---

### `Document.hasPresentation(labelId:)`

Check whether a label has a presentation attribute.

```swift
public func hasPresentation(labelId: Int64) -> Bool
```

---

### `Document.presentationSetDisplayed(labelId:displayed:)`

Set the display visibility flag on a presentation.

```swift
@discardableResult
public func presentationSetDisplayed(labelId: Int64, displayed: Bool) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::SetDisplayed`.

---

### `Document.presentationIsDisplayed(labelId:)`

Return `true` if the presentation is set to be displayed.

```swift
public func presentationIsDisplayed(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::IsDisplayed`.

---

### `Document.presentationSetColor(labelId:colorIndex:)`

Set the color of a presentation by `Quantity_NameOfColor` index.

```swift
@discardableResult
public func presentationSetColor(labelId: Int64, colorIndex: Int32) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::SetColor`.

---

### `Document.presentationGetColor(labelId:)`

Get the color index of a presentation.

```swift
public func presentationGetColor(labelId: Int64) -> Int32?
```

- **Returns:** `Quantity_NameOfColor` index, or `nil` if no own color is set.
- **OCCT:** `TDataXtd_Presentation::GetColor`.

---

### `Document.presentationSetTransparency(labelId:value:)`

Set the transparency of a presentation in `[0.0, 1.0]` (0 = opaque).

```swift
@discardableResult
public func presentationSetTransparency(labelId: Int64, value: Double) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::SetTransparency`.

---

### `Document.presentationGetTransparency(labelId:)`

Get the transparency of a presentation.

```swift
public func presentationGetTransparency(labelId: Int64) -> Double?
```

- **Returns:** Transparency value, or `nil` if not set.
- **OCCT:** `TDataXtd_Presentation::GetTransparency`.

---

### `Document.presentationSetWidth(labelId:width:)`

Set the line width of a presentation.

```swift
@discardableResult
public func presentationSetWidth(labelId: Int64, width: Double) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::SetWidth`.

---

### `Document.presentationGetWidth(labelId:)`

Get the line width of a presentation.

```swift
public func presentationGetWidth(labelId: Int64) -> Double?
```

- **Returns:** Width, or `nil` if not set.
- **OCCT:** `TDataXtd_Presentation::GetWidth`.

---

### `Document.presentationSetMode(labelId:mode:)`

Set the display mode (e.g. `0` = wireframe, `1` = shaded) of a presentation.

```swift
@discardableResult
public func presentationSetMode(labelId: Int64, mode: Int32) -> Bool
```

- **OCCT:** `TDataXtd_Presentation::SetMode`.

---

### `Document.presentationGetMode(labelId:)`

Get the display mode of a presentation.

```swift
public func presentationGetMode(labelId: Int64) -> Int32?
```

- **Returns:** Mode integer, or `nil` if not set.
- **OCCT:** `TDataXtd_Presentation::GetMode`.

---

## XCAFDoc_AssemblyIterator

### `Document.assemblyItemCount(maxDepth:)`

Count the total number of assembly items (component instances) in the document.

```swift
public func assemblyItemCount(maxDepth: Int = 0) -> Int
```

- **Parameters:** `maxDepth` — maximum traversal depth; `0` means unlimited.
- **OCCT:** `XCAFDoc_AssemblyIterator`.
- **Example:**
  ```swift
  let total = doc.assemblyItemCount()
  ```

---

## XCAFDoc_DimTol

Dimension and tolerance annotations attached to labels.

### `Document.setDimTol(labelId:kind:values:name:description:)`

Attach a `XCAFDoc_DimTol` attribute to a label.

```swift
@discardableResult
public func setDimTol(
    labelId: Int64,
    kind: Int32,
    values: [Double],
    name: String,
    description: String
) -> Bool
```

- **Parameters:** `kind` — tolerance type code (see XDE docs); `values` — numeric parameters; `name`, `description` — textual annotation strings.
- **OCCT:** `XCAFDoc_DimTol::Set`.

---

### `Document.dimTolKind(labelId:)`

Return the kind code of the `DimTol` attribute.

```swift
public func dimTolKind(labelId: Int64) -> Int32?
```

- **Returns:** Kind code, or `nil` if no attribute.
- **OCCT:** `XCAFDoc_DimTol::GetKind`.

---

### `Document.dimTolName(labelId:)`

Return the name string of the `DimTol` attribute.

```swift
public func dimTolName(labelId: Int64) -> String?
```

- **OCCT:** `XCAFDoc_DimTol::GetName`.

---

### `Document.dimTolDescription(labelId:)`

Return the description string of the `DimTol` attribute.

```swift
public func dimTolDescription(labelId: Int64) -> String?
```

- **OCCT:** `XCAFDoc_DimTol::GetDescription`.

---

### `Document.dimTolValues(labelId:)`

Return the numeric parameters of the `DimTol` attribute.

```swift
public func dimTolValues(labelId: Int64) -> [Double]?
```

- **Returns:** Array of parameter values (up to 32), or `nil` if not found.
- **OCCT:** `XCAFDoc_DimTol::GetVal`.

---

## IntTools_Tools

Static geometry utilities used internally by Boolean operations.

### `IntTools.computeVV(_:_:)`

Check whether two vertex shapes are geometrically coincident (within their combined tolerances).

```swift
public static func computeVV(_ vertex1: Shape, _ vertex2: Shape) -> Int
```

- **Returns:** `0` if coincident, non-zero otherwise.
- **OCCT:** `IntTools_Tools::ComputeVV`.

---

### `IntTools.intermediatePoint(first:last:)`

Compute a parameter value that lies between `first` and `last`, suitable as a midpoint sample.

```swift
public static func intermediatePoint(first: Double, last: Double) -> Double
```

- **OCCT:** `IntTools_Tools::IntermediatePoint`.

---

### `IntTools.isDirsCoinside(dx1:dy1:dz1:dx2:dy2:dz2:)`

Check whether two direction vectors are coincident (parallel or anti-parallel) using the default angular tolerance.

```swift
public static func isDirsCoinside(
    dx1: Double, dy1: Double, dz1: Double,
    dx2: Double, dy2: Double, dz2: Double
) -> Bool
```

- **OCCT:** `IntTools_Tools::IsDirsCoinside`.

---

### `IntTools.isDirsCoinside(dx1:dy1:dz1:dx2:dy2:dz2:tolerance:)`

Check whether two direction vectors are coincident within a specified angular tolerance.

```swift
public static func isDirsCoinside(
    dx1: Double, dy1: Double, dz1: Double,
    dx2: Double, dy2: Double, dz2: Double,
    tolerance: Double
) -> Bool
```

- **OCCT:** `IntTools_Tools::IsDirsCoinside(…, Standard_Real)`.

---

### `IntTools.computeIntRange(tol1:tol2:angle:)`

Compute the intersection range from two tolerances and an included angle; used by the edge-edge intersector.

```swift
public static func computeIntRange(tol1: Double, tol2: Double, angle: Double) -> Double
```

- **OCCT:** `IntTools_Tools::ComputeIntRange`.

---

## ElCLib

Static utilities for evaluating elementary 3D curves at parameter values.

### `ElCLib.valueOnLine(u:origin:direction:)`

Evaluate a point on a line at parameter `u`.

```swift
public static func valueOnLine(u: Double, origin: SIMD3<Double>, direction: SIMD3<Double>) -> SIMD3<Double>
```

- **OCCT:** `ElCLib::LineValue`.
- **Example:**
  ```swift
  let pt = ElCLib.valueOnLine(u: 3.0,
                               origin: SIMD3(0, 0, 0),
                               direction: SIMD3(1, 0, 0))
  // pt == SIMD3(3, 0, 0)
  ```

---

### `ElCLib.valueOnCircle(u:center:normal:radius:)`

Evaluate a point on a circle at parameter `u` (radians).

```swift
public static func valueOnCircle(
    u: Double,
    center: SIMD3<Double>,
    normal: SIMD3<Double>,
    radius: Double
) -> SIMD3<Double>
```

- **OCCT:** `ElCLib::CircleValue`.

---

### `ElCLib.valueOnEllipse(u:center:normal:majorRadius:minorRadius:)`

Evaluate a point on an ellipse at parameter `u`.

```swift
public static func valueOnEllipse(
    u: Double,
    center: SIMD3<Double>,
    normal: SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double
) -> SIMD3<Double>
```

- **OCCT:** `ElCLib::EllipseValue`.

---

### `ElCLib.d1OnLine(u:origin:direction:)`

Evaluate a point and its tangent vector on a line at parameter `u`.

```swift
public static func d1OnLine(
    u: Double,
    origin: SIMD3<Double>,
    direction: SIMD3<Double>
) -> (point: SIMD3<Double>, tangent: SIMD3<Double>)
```

- **OCCT:** `ElCLib::LineD1`.

---

### `ElCLib.d1OnCircle(u:center:normal:radius:)`

Evaluate a point and its tangent vector on a circle at parameter `u`.

```swift
public static func d1OnCircle(
    u: Double,
    center: SIMD3<Double>,
    normal: SIMD3<Double>,
    radius: Double
) -> (point: SIMD3<Double>, tangent: SIMD3<Double>)
```

- **OCCT:** `ElCLib::CircleD1`.

---

### `ElCLib.parameterOnLine(origin:direction:point:)`

Find the parameter of the nearest point on a line to a given 3D point.

```swift
public static func parameterOnLine(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    point: SIMD3<Double>
) -> Double
```

- **OCCT:** `ElCLib::Parameter(gp_Lin, gp_Pnt)`.

---

### `ElCLib.parameterOnCircle(center:normal:radius:point:)`

Find the parameter of the nearest point on a circle to a given 3D point.

```swift
public static func parameterOnCircle(
    center: SIMD3<Double>,
    normal: SIMD3<Double>,
    radius: Double,
    point: SIMD3<Double>
) -> Double
```

- **OCCT:** `ElCLib::Parameter(gp_Circ, gp_Pnt)`.

---

### `ElCLib.inPeriod(u:uFirst:uLast:)`

Normalise a parameter to the periodic range `[uFirst, uLast)`.

```swift
public static func inPeriod(u: Double, uFirst: Double, uLast: Double) -> Double
```

- **OCCT:** `ElCLib::InPeriod`.
- **Example:**
  ```swift
  ElCLib.inPeriod(u: 7.0, uFirst: 0, uLast: 2 * .pi)
  // → ~0.717 (7 mod 2π)
  ```

---

## ElSLib

Static utilities for evaluating elementary surfaces at `(u, v)` parameter values.

### `ElSLib.valueOnPlane(u:v:origin:normal:)`

Evaluate a point on a plane at `(u, v)`.

```swift
public static func valueOnPlane(
    u: Double, v: Double,
    origin: SIMD3<Double>,
    normal: SIMD3<Double>
) -> SIMD3<Double>
```

- **OCCT:** `ElSLib::PlaneValue`.
- **Example:**
  ```swift
  let pt = ElSLib.valueOnPlane(u: 1, v: 2,
                                origin: .zero,
                                normal: SIMD3(0, 0, 1))
  // pt ≈ SIMD3(1, 2, 0)
  ```

---

### `ElSLib.valueOnCylinder(u:v:origin:axis:radius:)`

Evaluate a point on a cylinder at `(u, v)`.

```swift
public static func valueOnCylinder(
    u: Double, v: Double,
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    radius: Double
) -> SIMD3<Double>
```

- **OCCT:** `ElSLib::CylinderValue`.

---

### `ElSLib.valueOnCone(u:v:origin:axis:refRadius:semiAngle:)`

Evaluate a point on a cone at `(u, v)`.

```swift
public static func valueOnCone(
    u: Double, v: Double,
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    refRadius: Double,
    semiAngle: Double
) -> SIMD3<Double>
```

- **OCCT:** `ElSLib::ConeValue`.

---

### `ElSLib.valueOnSphere(u:v:origin:axis:radius:)`

Evaluate a point on a sphere at `(u, v)`.

```swift
public static func valueOnSphere(
    u: Double, v: Double,
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    radius: Double
) -> SIMD3<Double>
```

- **OCCT:** `ElSLib::SphereValue`.

---

### `ElSLib.valueOnTorus(u:v:origin:axis:majorRadius:minorRadius:)`

Evaluate a point on a torus at `(u, v)`.

```swift
public static func valueOnTorus(
    u: Double, v: Double,
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    majorRadius: Double,
    minorRadius: Double
) -> SIMD3<Double>
```

- **OCCT:** `ElSLib::TorusValue`.

---

### `ElSLib.parametersOnSphere(origin:axis:radius:point:)`

Find the `(u, v)` parameters of the nearest point on a sphere to a 3D point.

```swift
public static func parametersOnSphere(
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    radius: Double,
    point: SIMD3<Double>
) -> (u: Double, v: Double)
```

- **OCCT:** `ElSLib::Parameters(gp_Sphere, gp_Pnt)`.

---

### `ElSLib.d1OnSphere(u:v:origin:axis:radius:)`

Evaluate a point and its partial derivative vectors on a sphere.

```swift
public static func d1OnSphere(
    u: Double, v: Double,
    origin: SIMD3<Double>,
    axis: SIMD3<Double>,
    radius: Double
) -> (point: SIMD3<Double>, dU: SIMD3<Double>, dV: SIMD3<Double>)
```

- **Returns:** `point` — position; `dU` — partial derivative with respect to U; `dV` — partial with respect to V.
- **OCCT:** `ElSLib::SphereD1`.
- **Example:**
  ```swift
  let (pt, du, dv) = ElSLib.d1OnSphere(u: 0, v: 0,
                                         origin: .zero,
                                         axis: SIMD3(0, 0, 1),
                                         radius: 5.0)
  ```
