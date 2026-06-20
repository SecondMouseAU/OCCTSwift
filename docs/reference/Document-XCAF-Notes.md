---
title: Document — XCAF Notes, Views & Materials
parent: API Reference
---

# Document — XCAF Notes, Views & Materials

This page covers the XCAF annotation, view, material, and utility subsystems exposed on `Document`, `AssemblyNode`, and several standalone types (lines 2381–3349 of `Document.swift`). For the core document lifecycle, shape tools, and STEP/IGES I/O see the main [Document](Document.md) page.

## Topics

- [XCAFDoc_NotesTool](#xcafdoc_notestool) · [XCAFDoc_ClippingPlaneTool](#xcafdoc_clippingplanetool) · [XCAFDoc_ShapeMapTool](#xcafdoc_shapemaptool) · [XCAFDoc_AssemblyGraph](#xcafdoc_assemblygraph) · [XCAFDoc_AssemblyItemId](#xcafdoc_assemblyitemid) · [XCAFView_Object](#xcafview_object) · [XCAFNoteObjects_NoteObject](#xcafnoteobjects_noteobject) · [XCAFPrs_Style](#xcafprs_style) · [XCAFDoc_VisMaterialCommon](#xcafdoc_vismaterialcommon) · [XCAFDoc_VisMaterialPBR](#xcafdoc_vismaterialpbr) · [VrmlAPI_Writer](#vrmlapi_writer) · [TDataStd_Directory](#tdatastd_directory) · [TDataStd_Variable](#tdatastd_variable) · [TDataStd_Expression](#tdatastd_expression) · [TDocStd_XLink](#tdocstd_xlink) · [XCAFDimTolObjects_Tool](#xcafdimtolobjects_tool) · [TPrsStd_DriverTable](#tprsstd_drivertable) · [TObj_Application](#tobj_application) · [UnitsAPI](#unitsapi) · [BinTools Shape I/O](#bintools-shape-io) · [Message_Messenger](#message_messenger)

---

## XCAFDoc_NotesTool

Annotations (notes) attached to assembly labels via `XCAFDoc_NotesTool`. Notes may be comments, balloons, or opaque binary data blobs.

### `notesToolNoteCount`

Total number of notes in the document.

```swift
public var notesToolNoteCount: Int32 { get }
```

- **OCCT:** `XCAFDoc_NotesTool::NbNotes`
- **Example:**
  ```swift
  let count = document.notesToolNoteCount
  ```

---

### `notesToolCreateComment(userName:timeStamp:comment:)`

Create a plain-text comment note and attach it to the notes tool.

```swift
public func notesToolCreateComment(userName: String, timeStamp: String, comment: String) -> AssemblyNode?
```

- **Parameters:** `userName` — author identifier; `timeStamp` — ISO-8601 string; `comment` — note text.
- **Returns:** The label node for the new note, or `nil` if the notes tool could not be found.
- **OCCT:** `XCAFDoc_NotesTool::CreateComment`
- **Example:**
  ```swift
  if let node = document.notesToolCreateComment(
      userName: "alice", timeStamp: "2026-01-01T00:00:00Z", comment: "Check radius") {
      // node.labelId identifies the note label
  }
  ```

---

### `notesToolCreateBalloon(userName:timeStamp:comment:)`

Create a balloon (callout) note.

```swift
public func notesToolCreateBalloon(userName: String, timeStamp: String, comment: String) -> AssemblyNode?
```

- **Parameters:** `userName` — author identifier; `timeStamp` — ISO-8601 string; `comment` — balloon text.
- **Returns:** The label node for the new note, or `nil` on failure.
- **OCCT:** `XCAFDoc_NotesTool::CreateBalloon`
- **Example:**
  ```swift
  if let node = document.notesToolCreateBalloon(
      userName: "bob", timeStamp: "2026-06-01T12:00:00Z", comment: "Datum A") { }
  ```

---

### `notesToolCreateBinData(userName:timeStamp:title:mimeType:data:)`

Create a binary data note (e.g. an embedded image or PDF attachment).

```swift
public func notesToolCreateBinData(
    userName: String,
    timeStamp: String,
    title: String,
    mimeType: String,
    data: [UInt8]
) -> AssemblyNode?
```

- **Parameters:** `userName` — author; `timeStamp` — ISO-8601 string; `title` — display name; `mimeType` — MIME type string (e.g. `"image/png"`); `data` — raw byte payload.
- **Returns:** The label node, or `nil` on failure.
- **OCCT:** `XCAFDoc_NotesTool::CreateBinData`
- **Example:**
  ```swift
  let bytes: [UInt8] = Array(pngData)
  if let node = document.notesToolCreateBinData(
      userName: "ci", timeStamp: "2026-06-01T00:00:00Z",
      title: "thumbnail", mimeType: "image/png", data: bytes) { }
  ```

---

### `notesToolDeleteNote(_:)`

Delete a single note identified by its label node.

```swift
@discardableResult
public func notesToolDeleteNote(_ node: AssemblyNode) -> Bool
```

- **Parameters:** `node` — the label node previously returned by a `notesToolCreate*` call.
- **Returns:** `true` if the note was found and deleted.
- **OCCT:** `XCAFDoc_NotesTool::DeleteNote`
- **Example:**
  ```swift
  if let node = document.notesToolCreateComment(userName: "x", timeStamp: "t", comment: "tmp") {
      document.notesToolDeleteNote(node)
  }
  ```

---

### `notesToolDeleteAllNotes()`

Delete every note in the document.

```swift
@discardableResult
public func notesToolDeleteAllNotes() -> Int32
```

- **Returns:** Number of notes deleted.
- **OCCT:** `XCAFDoc_NotesTool::DeleteAllNotes`
- **Example:**
  ```swift
  let removed = document.notesToolDeleteAllNotes()
  ```

---

### `notesToolOrphanNoteCount`

Number of orphan notes (notes whose referenced labels no longer exist).

```swift
public var notesToolOrphanNoteCount: Int32 { get }
```

- **OCCT:** `XCAFDoc_NotesTool::NbOrphanNotes`
- **Example:**
  ```swift
  if document.notesToolOrphanNoteCount > 0 {
      document.notesToolDeleteOrphanNotes()
  }
  ```

---

### `notesToolDeleteOrphanNotes()`

Delete all orphan notes.

```swift
@discardableResult
public func notesToolDeleteOrphanNotes() -> Int32
```

- **Returns:** Number of orphan notes deleted.
- **OCCT:** `XCAFDoc_NotesTool::DeleteOrphanNotes`
- **Example:**
  ```swift
  let pruned = document.notesToolDeleteOrphanNotes()
  ```

---

## XCAFDoc_ClippingPlaneTool

Named, storable clipping planes attached to the XCAF document.

### `clippingPlaneToolAdd(originX:originY:originZ:normalX:normalY:normalZ:name:capping:)`

Add a named clipping plane defined by an origin point and a normal direction.

```swift
public func clippingPlaneToolAdd(
    originX: Double, originY: Double, originZ: Double,
    normalX: Double, normalY: Double, normalZ: Double,
    name: String,
    capping: Bool
) -> AssemblyNode?
```

- **Parameters:** `originX/Y/Z` — plane origin; `normalX/Y/Z` — plane normal (need not be unit-length); `name` — display name; `capping` — whether the open cross-section is capped.
- **Returns:** Label node for the new clipping plane entry, or `nil` on failure.
- **OCCT:** `XCAFDoc_ClippingPlaneTool::AddClippingPlane`
- **Example:**
  ```swift
  if let node = document.clippingPlaneToolAdd(
      originX: 0, originY: 0, originZ: 5,
      normalX: 0, normalY: 0, normalZ: 1,
      name: "Z-cut", capping: true) { }
  ```

---

### `clippingPlaneToolGet(_:)`

Read back the clipping plane parameters stored on a label.

```swift
public func clippingPlaneToolGet(_ node: AssemblyNode)
    -> (originX: Double, originY: Double, originZ: Double,
        normalX: Double, normalY: Double, normalZ: Double,
        capping: Bool)?
```

- **Parameters:** `node` — label node returned by `clippingPlaneToolAdd`.
- **Returns:** A named tuple with origin, normal, and capping flag; `nil` if the label is not a clipping plane.
- **OCCT:** `XCAFDoc_ClippingPlaneTool::GetClippingPlane`
- **Example:**
  ```swift
  if let node = document.clippingPlaneToolAdd(
      originX: 0, originY: 0, originZ: 0,
      normalX: 1, normalY: 0, normalZ: 0,
      name: "X-cut", capping: false),
     let plane = document.clippingPlaneToolGet(node) {
      print(plane.normalX) // 1.0
  }
  ```

---

### `clippingPlaneToolIsClipPlane(_:)`

Test whether a label holds a clipping plane attribute.

```swift
public func clippingPlaneToolIsClipPlane(_ node: AssemblyNode) -> Bool
```

- **Parameters:** `node` — any assembly label node.
- **Returns:** `true` if the label carries a `XCAFDoc_ClippingPlane` attribute.
- **OCCT:** `XCAFDoc_ClippingPlaneTool::IsClippingPlane`
- **Example:**
  ```swift
  let isPlane = document.clippingPlaneToolIsClipPlane(someNode)
  ```

---

### `clippingPlaneToolRemove(_:)`

Remove a clipping plane from the document.

```swift
@discardableResult
public func clippingPlaneToolRemove(_ node: AssemblyNode) -> Bool
```

- **Parameters:** `node` — label node of the clipping plane to remove.
- **Returns:** `true` if the removal succeeded.
- **OCCT:** `XCAFDoc_ClippingPlaneTool::RemoveClippingPlane`
- **Example:**
  ```swift
  if let node = document.clippingPlaneToolAdd(
      originX: 0, originY: 0, originZ: 0,
      normalX: 0, normalY: 1, normalZ: 0,
      name: "tmp", capping: false) {
      document.clippingPlaneToolRemove(node)
  }
  ```

---

## XCAFDoc_ShapeMapTool

Extension on `AssemblyNode`. Maps sub-shapes within a label's shape for fast membership testing via `XCAFDoc_ShapeMapTool`.

### `setShapeMapTool()`

Attach a `XCAFDoc_ShapeMapTool` attribute to this label.

```swift
@discardableResult
public func setShapeMapTool() -> Bool
```

- **Returns:** `true` if the attribute was set successfully.
- **OCCT:** `XCAFDoc_ShapeMapTool::Set`
- **Example:**
  ```swift
  let ok = node.setShapeMapTool()
  ```

---

### `shapeMapToolSetShape(_:)`

Register a shape in the tool's map, enabling sub-shape lookup.

```swift
@discardableResult
public func shapeMapToolSetShape(_ shape: Shape) -> Bool
```

- **Parameters:** `shape` — the shape whose sub-shapes should be indexed.
- **Returns:** `true` on success.
- **OCCT:** `XCAFDoc_ShapeMapTool::SetShape`
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10) {
      node.shapeMapToolSetShape(box)
  }
  ```

---

### `shapeMapToolIsSubShape(_:)`

Test whether a given shape is a sub-shape of the indexed shape.

```swift
public func shapeMapToolIsSubShape(_ shape: Shape) -> Bool
```

- **Parameters:** `shape` — shape to test for membership.
- **Returns:** `true` if `shape` is a sub-shape of the shape registered via `shapeMapToolSetShape`.
- **OCCT:** `XCAFDoc_ShapeMapTool::IsSubShape`
- **Example:**
  ```swift
  let sub: Shape = // an edge or face extracted from the box
  let isSub = node.shapeMapToolIsSubShape(sub)
  ```

---

### `shapeMapToolExtent`

Number of entries (sub-shapes) currently in the map.

```swift
public var shapeMapToolExtent: Int32 { get }
```

- **OCCT:** `XCAFDoc_ShapeMapTool::Map().Extent()`
- **Example:**
  ```swift
  print(node.shapeMapToolExtent)
  ```

---

## XCAFDoc_AssemblyGraph

`AssemblyGraph` — a read-only snapshot of the assembly hierarchy as a directed graph. Instantiate once per document and query counts or per-node type.

### `AssemblyGraph.init?(document:)`

Build a graph from a document.

```swift
public init?(document: Document)
```

- **Parameters:** `document` — the document whose assembly structure to traverse.
- **Returns:** A populated graph, or `nil` if the document contains no assembly hierarchy.
- **OCCT:** `XCAFDoc_AssemblyGraph` constructor
- **Example:**
  ```swift
  if let graph = AssemblyGraph(document: document) {
      print(graph.nodeCount)
  }
  ```

---

### `nodeCount`

Total number of nodes in the graph.

```swift
public var nodeCount: Int32 { get }
```

- **OCCT:** `XCAFDoc_AssemblyGraph::NbNodes`

---

### `linkCount`

Total number of directed links (parent→child edges) in the graph.

```swift
public var linkCount: Int32 { get }
```

- **OCCT:** `XCAFDoc_AssemblyGraph::NbLinks`

---

### `rootCount`

Number of root nodes (nodes with no parent).

```swift
public var rootCount: Int32 { get }
```

- **OCCT:** `XCAFDoc_AssemblyGraph::NbRoots`

---

### `AssemblyGraph.NodeType`

Classification of each node in the assembly graph.

```swift
public enum NodeType: Int32 {
    case node       = 0
    case occurrence = 1
    case part       = 2
    case instance   = 3
    case subshape   = 4
    case free       = 5
}
```

- **OCCT:** `XCAFDoc_AssemblyGraph::NodeType`

---

### `nodeType(at:)`

Return the type of a node by 1-based index.

```swift
public func nodeType(at index: Int32) -> NodeType?
```

- **Parameters:** `index` — 1-based node index (1 … `nodeCount`).
- **Returns:** The node type, or `nil` if `index` is out of range.
- **OCCT:** `XCAFDoc_AssemblyGraph::GetNodeType`
- **Example:**
  ```swift
  if let graph = AssemblyGraph(document: document) {
      for i in 1...graph.nodeCount {
          if let type = graph.nodeType(at: i) {
              print(i, type)
          }
      }
  }
  ```

---

## XCAFDoc_AssemblyItemId

`AssemblyItemId` — a lightweight value type representing an assembly path as a `/`-separated string of label entries (e.g. `"0:1:1:1/0:1:1:2"`).

### `AssemblyItemId.init(_:)`

Create an assembly item ID from a path string.

```swift
public init(_ path: String)
```

- **Parameters:** `path` — colon-and-slash separated label path.
- **OCCT:** `XCAFDoc_AssemblyItemId` constructor
- **Example:**
  ```swift
  let id = AssemblyItemId("0:1:1:1/0:1:1:2")
  ```

---

### `path`

The raw string representation of this item ID.

```swift
public let path: String
```

---

### `isValid`

Whether the path is a non-empty, well-formed item ID.

```swift
public var isValid: Bool { get }
```

- **OCCT:** `XCAFDoc_AssemblyItemId::IsNull` (negated)
- **Example:**
  ```swift
  let id = AssemblyItemId("")
  print(id.isValid) // false
  ```

---

### `pathCount`

Number of individual label entries in the path.

```swift
public var pathCount: Int32 { get }
```

- **OCCT:** `XCAFDoc_AssemblyItemId::GetPathLength`
- **Example:**
  ```swift
  let id = AssemblyItemId("0:1:1:1/0:1:1:2")
  print(id.pathCount) // 2
  ```

---

### `isEqual(to:)`

Test equality with another item ID.

```swift
public func isEqual(to other: AssemblyItemId) -> Bool
```

- **Parameters:** `other` — the ID to compare.
- **Returns:** `true` if both paths are identical.
- **OCCT:** `XCAFDoc_AssemblyItemId::IsEqual`
- **Example:**
  ```swift
  let a = AssemblyItemId("0:1:1:1")
  let b = AssemblyItemId("0:1:1:1")
  print(a.isEqual(to: b)) // true
  ```

---

## XCAFView_Object

`ViewObject` — a standalone view definition (camera parameters) that can be stored in an XDE document's view tool.

### `ViewObject.init?()`

Create a new empty view object.

```swift
public init?()
```

- **Returns:** A new view object, or `nil` if the OCCT handle could not be allocated.
- **OCCT:** `XCAFView_Object` constructor

---

### `ViewObject.ProjectionType`

Projection mode for this view.

```swift
public enum ProjectionType: Int32 {
    case central = 0
    case parallel = 1
}
```

- **OCCT:** `XCAFView_Object::Type` / `XCAFView_ProjType`

---

### `setType(_:)`

Set the projection type (central or parallel).

```swift
public func setType(_ type: ProjectionType)
```

- **Parameters:** `type` — `.central` (perspective) or `.parallel` (orthographic).
- **OCCT:** `XCAFView_Object::SetType`

---

### `type`

Get the current projection type.

```swift
public var type: ProjectionType { get }
```

- **OCCT:** `XCAFView_Object::Type`
- **Example:**
  ```swift
  if let view = ViewObject() {
      view.setType(.parallel)
      print(view.type) // parallel
  }
  ```

---

### `setViewDirection(x:y:z:)`

Set the view direction vector.

```swift
public func setViewDirection(x: Double, y: Double, z: Double)
```

- **OCCT:** `XCAFView_Object::SetViewDirection`

---

### `viewDirection`

Get the view direction vector as `(x, y, z)`.

```swift
public var viewDirection: (x: Double, y: Double, z: Double) { get }
```

- **OCCT:** `XCAFView_Object::ViewDirection`

---

### `setUpDirection(x:y:z:)`

Set the up direction vector.

```swift
public func setUpDirection(x: Double, y: Double, z: Double)
```

- **OCCT:** `XCAFView_Object::SetUpDirection`

---

### `upDirection`

Get the up direction vector as `(x, y, z)`.

```swift
public var upDirection: (x: Double, y: Double, z: Double) { get }
```

- **OCCT:** `XCAFView_Object::UpDirection`

---

### `setWindowHorizontalSize(_:)`

Set the window horizontal size (used for orthographic scale).

```swift
public func setWindowHorizontalSize(_ size: Double)
```

- **OCCT:** `XCAFView_Object::SetWindowHorizontalSize`

---

### `windowHorizontalSize`

Get the window horizontal size.

```swift
public var windowHorizontalSize: Double { get }
```

- **OCCT:** `XCAFView_Object::WindowHorizontalSize`

---

### `setWindowVerticalSize(_:)`

Set the window vertical size.

```swift
public func setWindowVerticalSize(_ size: Double)
```

- **OCCT:** `XCAFView_Object::SetWindowVerticalSize`

---

### `windowVerticalSize`

Get the window vertical size.

```swift
public var windowVerticalSize: Double { get }
```

- **OCCT:** `XCAFView_Object::WindowVerticalSize`

---

### `setFrontPlaneDistance(_:)`

Set the front clipping plane distance and enable front clipping.

```swift
public func setFrontPlaneDistance(_ dist: Double)
```

- **OCCT:** `XCAFView_Object::SetFrontPlaneDistance`

---

### `frontPlaneDistance`

Get the front clipping plane distance.

```swift
public var frontPlaneDistance: Double { get }
```

- **OCCT:** `XCAFView_Object::FrontPlaneDistance`

---

### `hasFrontPlaneClipping`

Whether front plane clipping is enabled for this view.

```swift
public var hasFrontPlaneClipping: Bool { get }
```

- **OCCT:** `XCAFView_Object::HasFrontPlaneClipping`

---

### `unsetFrontPlaneClipping()`

Disable front plane clipping.

```swift
public func unsetFrontPlaneClipping()
```

- **OCCT:** `XCAFView_Object::UnsetFrontPlaneClipping`

---

### `setBackPlaneDistance(_:)`

Set the back clipping plane distance and enable back clipping.

```swift
public func setBackPlaneDistance(_ dist: Double)
```

- **OCCT:** `XCAFView_Object::SetBackPlaneDistance`

---

### `backPlaneDistance`

Get the back clipping plane distance.

```swift
public var backPlaneDistance: Double { get }
```

- **OCCT:** `XCAFView_Object::BackPlaneDistance`

---

### `hasBackPlaneClipping`

Whether back plane clipping is enabled for this view.

```swift
public var hasBackPlaneClipping: Bool { get }
```

- **OCCT:** `XCAFView_Object::HasBackPlaneClipping`

---

### `unsetBackPlaneClipping()`

Disable back plane clipping.

```swift
public func unsetBackPlaneClipping()
```

- **OCCT:** `XCAFView_Object::UnsetBackPlaneClipping`

---

### `setName(_:)`

Set a display name for this view.

```swift
public func setName(_ name: String)
```

- **OCCT:** `XCAFView_Object::SetName`

---

### `name`

Get the display name, or `nil` if none has been set.

```swift
public var name: String? { get }
```

- **OCCT:** `XCAFView_Object::Name`
- **Example:**
  ```swift
  if let view = ViewObject() {
      view.setName("Front")
      print(view.name ?? "") // "Front"
  }
  ```

---

## XCAFNoteObjects_NoteObject

`NoteObject` — annotation geometry data (plane, point, presentation shape) associated with a note.

### `NoteObject.init?()`

Create a new empty note object.

```swift
public init?()
```

- **Returns:** A new note object, or `nil` if allocation fails.
- **OCCT:** `XCAFNoteObjects_NoteObject` constructor

---

### `hasPlane`

Whether a plane has been set on this note object.

```swift
public var hasPlane: Bool { get }
```

- **OCCT:** `XCAFNoteObjects_NoteObject::HasPlane`

---

### `hasPoint`

Whether a 3-D anchor point has been set.

```swift
public var hasPoint: Bool { get }
```

- **OCCT:** `XCAFNoteObjects_NoteObject::HasPoint`

---

### `hasPointText`

Whether a point-text annotation has been set.

```swift
public var hasPointText: Bool { get }
```

- **OCCT:** `XCAFNoteObjects_NoteObject::HasPointText`

---

### `setPlane(originX:originY:originZ:normalX:normalY:normalZ:)`

Set the annotation plane by origin point and normal direction.

```swift
public func setPlane(
    originX: Double, originY: Double, originZ: Double,
    normalX: Double, normalY: Double, normalZ: Double
)
```

- **OCCT:** `XCAFNoteObjects_NoteObject::SetPlane`

---

### `planeOrigin`

Get the origin of the annotation plane as `(x, y, z)`.

```swift
public var planeOrigin: (x: Double, y: Double, z: Double) { get }
```

- **OCCT:** `XCAFNoteObjects_NoteObject::GetPlane` (origin component)
- **Note:** Returns the plane origin only; the normal is not separately exposed at the Swift level.

---

### `setPoint(x:y:z:)`

Set the 3-D anchor point of the note.

```swift
public func setPoint(x: Double, y: Double, z: Double)
```

- **OCCT:** `XCAFNoteObjects_NoteObject::SetPoint`

---

### `point`

Get the anchor point as `(x, y, z)`.

```swift
public var point: (x: Double, y: Double, z: Double) { get }
```

- **OCCT:** `XCAFNoteObjects_NoteObject::GetPoint`

---

### `setPresentation(_:)`

Attach a shape as the visual presentation for the note callout.

```swift
public func setPresentation(_ shape: Shape)
```

- **Parameters:** `shape` — any `Shape` to use as the note's geometry.
- **OCCT:** `XCAFNoteObjects_NoteObject::SetPresentation`

---

### `presentation`

Get the presentation shape, or `nil` if none has been set.

```swift
public var presentation: Shape? { get }
```

- **OCCT:** `XCAFNoteObjects_NoteObject::GetPresentation`

---

### `reset()`

Clear all data (plane, point, presentation) on this note object.

```swift
public func reset()
```

- **OCCT:** `XCAFNoteObjects_NoteObject::Reset`
- **Example:**
  ```swift
  if let note = NoteObject() {
      note.setPoint(x: 1, y: 2, z: 3)
      note.reset()
      print(note.hasPoint) // false
  }
  ```

---

## XCAFPrs_Style

`PresentationStyle` — a value type capturing surface color, curve color, alpha, and visibility for a shape in an XDE scene.

### `PresentationStyle.init()`

Create an empty style (no colors set, fully opaque, visible).

```swift
public init()
```

- **OCCT:** `XCAFPrs_Style` default constructor

---

### `PresentationStyle.init(surfaceRed:surfaceGreen:surfaceBlue:surfaceAlpha:)`

Create a style with a surface color and optional alpha.

```swift
public init(
    surfaceRed: Double,
    surfaceGreen: Double,
    surfaceBlue: Double,
    surfaceAlpha: Float = 1.0
)
```

- **Parameters:** `surfaceRed/Green/Blue` — RGB in [0, 1]; `surfaceAlpha` — opacity in [0, 1], default `1.0`.
- **OCCT:** `XCAFPrs_Style::SetColorSurf`
- **Example:**
  ```swift
  let red = PresentationStyle(surfaceRed: 1, surfaceGreen: 0, surfaceBlue: 0)
  ```

---

### `surfaceColor`

The surface (face fill) color as an optional `(red, green, blue)` tuple.

```swift
public var surfaceColor: (red: Double, green: Double, blue: Double)?
```

---

### `surfaceAlpha`

Surface opacity (0 = transparent, 1 = opaque).

```swift
public var surfaceAlpha: Float
```

---

### `curveColor`

The curve (edge/wire) color as an optional `(red, green, blue)` tuple.

```swift
public var curveColor: (red: Double, green: Double, blue: Double)?
```

---

### `isVisible`

Whether this style marks the shape as visible.

```swift
public var isVisible: Bool
```

---

### `isEmpty`

Whether the style carries no color attributes and is fully visible (default state).

```swift
public var isEmpty: Bool { get }
```

- **OCCT:** `XCAFPrs_Style::IsEmpty`

---

### `isEqual(to:)`

Test equality with another `PresentationStyle`.

```swift
public func isEqual(to other: PresentationStyle) -> Bool
```

- **OCCT:** `XCAFPrs_Style::IsEqual`
- **Example:**
  ```swift
  var s1 = PresentationStyle()
  var s2 = PresentationStyle()
  print(s1.isEqual(to: s2)) // true
  ```

---

## XCAFDoc_VisMaterialCommon

`VisMaterialCommon` — Phong shading parameters (diffuse, ambient, specular, emissive, shininess, transparency).

### `VisMaterialCommon.init()`

Create material with OCCT default values.

```swift
public init()
```

- **OCCT:** `XCAFDoc_VisMaterialCommon` default field values

---

### `diffuseColor`

Diffuse color as `(red, green, blue)`.

```swift
public var diffuseColor: (red: Double, green: Double, blue: Double)
```

---

### `ambientColor`

Ambient color as `(red, green, blue)`.

```swift
public var ambientColor: (red: Double, green: Double, blue: Double)
```

---

### `specularColor`

Specular highlight color as `(red, green, blue)`.

```swift
public var specularColor: (red: Double, green: Double, blue: Double)
```

---

### `emissiveColor`

Emissive (self-illuminating) color as `(red, green, blue)`.

```swift
public var emissiveColor: (red: Double, green: Double, blue: Double)
```

---

### `shininess`

Phong shininess exponent.

```swift
public var shininess: Float
```

---

### `transparency`

Transparency in [0, 1] (0 = opaque).

```swift
public var transparency: Float
```

---

### `isDefined`

Whether this material has been explicitly defined (as opposed to being a placeholder).

```swift
public var isDefined: Bool
```

---

### `isEqual(to:)`

Test equality with another `VisMaterialCommon`.

```swift
public func isEqual(to other: VisMaterialCommon) -> Bool
```

- **OCCT:** `XCAFDoc_VisMaterialCommon::IsEqual`
- **Example:**
  ```swift
  let m1 = VisMaterialCommon()
  let m2 = VisMaterialCommon()
  print(m1.isEqual(to: m2)) // true
  ```

---

## XCAFDoc_VisMaterialPBR

`VisMaterialPBR` — PBR (physically-based rendering) material parameters.

### `VisMaterialPBR.init()`

Create PBR material with OCCT default values.

```swift
public init()
```

- **OCCT:** `XCAFDoc_VisMaterialPBR` default field values

---

### `baseColor`

Base color as `(red, green, blue)`.

```swift
public var baseColor: (red: Double, green: Double, blue: Double)
```

---

### `baseColorAlpha`

Base color alpha (opacity).

```swift
public var baseColorAlpha: Float
```

---

### `metallic`

Metallic factor in [0, 1].

```swift
public var metallic: Float
```

---

### `roughness`

Roughness factor in [0, 1].

```swift
public var roughness: Float
```

---

### `refractionIndex`

Index of refraction (IOR).

```swift
public var refractionIndex: Float
```

---

### `emissionColor`

Emission color as `(red, green, blue)`.

```swift
public var emissionColor: (red: Double, green: Double, blue: Double)
```

---

### `isDefined`

Whether this PBR material has been explicitly defined.

```swift
public var isDefined: Bool
```

---

### `isEqual(to:)`

Test equality with another `VisMaterialPBR`.

```swift
public func isEqual(to other: VisMaterialPBR) -> Bool
```

- **OCCT:** `XCAFDoc_VisMaterialPBR::IsEqual`
- **Example:**
  ```swift
  var m1 = VisMaterialPBR()
  m1.metallic = 0.8
  var m2 = VisMaterialPBR()
  print(m1.isEqual(to: m2)) // false
  ```

---

## VrmlAPI_Writer

VRML export for `Shape` and `Document` objects.

### `VrmlRepresentation`

Visual representation mode for VRML export.

```swift
public enum VrmlRepresentation: Int32, Sendable {
    case shaded    = 0
    case wireFrame = 1
    case both      = 2
}
```

- **OCCT:** `VrmlAPI_RepresentationOfShape`

---

### `Shape.writeVRML(to:version:deflection:representation:)`

Write a shape to a VRML file.

```swift
@discardableResult
public func writeVRML(
    to url: URL,
    version: Int = 2,
    deflection: Double = 0.01,
    representation: VrmlRepresentation = .shaded
) -> Bool
```

- **Parameters:** `url` — destination file URL (`.wrl`); `version` — VRML version (1 or 2); `deflection` — triangulation chord deviation; `representation` — shading mode.
- **Returns:** `true` on success.
- **OCCT:** `VrmlAPI_Writer::Write`
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10) {
      box.writeVRML(to: URL(fileURLWithPath: "/tmp/box.wrl"))
  }
  ```

---

### `Document.writeVRML(to:scale:)`

Write an XDE document to a VRML file, applying a uniform scale.

```swift
@discardableResult
public func writeVRML(to url: URL, scale: Double = 1.0) -> Bool
```

- **Parameters:** `url` — destination file URL (`.wrl`); `scale` — uniform scale factor applied before export.
- **Returns:** `true` on success.
- **OCCT:** `VrmlAPI_Writer::WriteDoc`
- **Example:**
  ```swift
  let ok = document.writeVRML(to: URL(fileURLWithPath: "/tmp/model.wrl"), scale: 0.001)
  ```

---

## TDataStd_Directory

Hierarchical container attribute for grouping OCAF labels, analogous to a filesystem directory.

### `createDirectory(at:)`

Create a `TDataStd_Directory` attribute on a label.

```swift
@discardableResult
public func createDirectory(at labelTag: Int = 0) -> Bool
```

- **Parameters:** `labelTag` — child tag of the main label to target (0 = main label).
- **Returns:** `true` if the attribute was created.
- **OCCT:** `TDataStd_Directory::New`
- **Example:**
  ```swift
  document.createDirectory()
  ```

---

### `hasDirectory(at:)`

Check whether a `TDataStd_Directory` attribute exists on a label.

```swift
public func hasDirectory(at labelTag: Int = 0) -> Bool
```

- **OCCT:** `TDataStd_Directory::Find`
- **Example:**
  ```swift
  if document.hasDirectory() { }
  ```

---

### `addSubDirectory(under:)`

Create a child directory label under an existing directory.

```swift
public func addSubDirectory(under parentLabelTag: Int = 0) -> Int?
```

- **Parameters:** `parentLabelTag` — label tag of the parent directory.
- **Returns:** The child label tag, or `nil` on failure.
- **OCCT:** `TDataStd_Directory::AddDirectory`
- **Example:**
  ```swift
  if let childTag = document.addSubDirectory() {
      print(childTag)
  }
  ```

---

### `makeObjectLabel(under:)`

Create an object (leaf) label under a directory.

```swift
public func makeObjectLabel(under parentLabelTag: Int = 0) -> Int?
```

- **Parameters:** `parentLabelTag` — label tag of the parent directory.
- **Returns:** The new label tag, or `nil` on failure.
- **OCCT:** `TDataStd_Directory::MakeObjectLabel`

---

## TDataStd_Variable

Parametric variable attributes stored on OCAF labels. Variables may be named, typed, unit-annotated, and linked to expressions.

### `setVariable(at:)`

Attach a `TDataStd_Variable` attribute to a label.

```swift
@discardableResult
public func setVariable(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Set`

---

### `setVariableName(_:at:)`

Set the display name of a variable.

```swift
@discardableResult
public func setVariableName(_ name: String, at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Name`

---

### `variableName(at:)`

Get the display name of a variable, or `nil` if not set.

```swift
public func variableName(at labelTag: Int) -> String?
```

- **OCCT:** `TDataStd_Variable::Name`

---

### `setVariableValue(_:at:)`

Set the numeric value of a variable.

```swift
@discardableResult
public func setVariableValue(_ value: Double, at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Set` (real-valued overload)

---

### `variableValue(at:)`

Get the numeric value stored on a variable label.

```swift
public func variableValue(at labelTag: Int) -> Double
```

- **OCCT:** `TDataStd_Variable::Get`

---

### `variableIsValued(at:)`

Whether the variable label holds a numeric value.

```swift
public func variableIsValued(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::IsValued`

---

### `setVariableUnit(_:at:)`

Attach a unit string (e.g. `"mm"`) to a variable.

```swift
@discardableResult
public func setVariableUnit(_ unit: String, at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Unit`

---

### `variableUnit(at:)`

Get the unit string for a variable, or `nil` if not set.

```swift
public func variableUnit(at labelTag: Int) -> String?
```

- **OCCT:** `TDataStd_Variable::Unit`

---

### `setVariableConstant(_:at:)`

Mark a variable as a constant (prevents parametric modification).

```swift
@discardableResult
public func setVariableConstant(_ isConstant: Bool, at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Constant`

---

### `variableIsConstant(at:)`

Whether the variable is marked constant.

```swift
public func variableIsConstant(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::IsConstant`

---

### `assignExpression(at:)`

Assign an expression attribute to a variable on the same label.

```swift
@discardableResult
public func assignExpression(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Assign`

---

### `desassignExpression(at:)`

Remove an expression assignment from a variable.

```swift
@discardableResult
public func desassignExpression(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::Desassign`

---

### `variableIsAssigned(at:)`

Whether the variable currently has an expression assigned.

```swift
public func variableIsAssigned(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Variable::IsAssigned`
- **Example:**
  ```swift
  document.setVariable(at: 1)
  document.setVariableName("Width", at: 1)
  document.setVariableValue(50.0, at: 1)
  document.setVariableUnit("mm", at: 1)
  print(document.variableIsValued(at: 1)) // true
  ```

---

## TDataStd_Expression

Algebraic expression string attributes stored on OCAF labels, evaluated by a constraint solver.

### `setExpression(at:)`

Attach a `TDataStd_Expression` attribute to a label.

```swift
@discardableResult
public func setExpression(at labelTag: Int) -> Bool
```

- **OCCT:** `TDataStd_Expression::Set`

---

### `setExpressionString(_:at:)`

Set the expression string on a label.

```swift
@discardableResult
public func setExpressionString(_ expression: String, at labelTag: Int) -> Bool
```

- **Parameters:** `expression` — formula string (e.g. `"Width * 2"`).
- **OCCT:** `TDataStd_Expression::SetExpressionString`

---

### `expressionString(at:)`

Get the expression formula string, or `nil` if not set.

```swift
public func expressionString(at labelTag: Int) -> String?
```

- **OCCT:** `TDataStd_Expression::GetExpressionString`

---

### `expressionName(at:)`

Get the expression name (variable name it is bound to), or `nil` if not set.

```swift
public func expressionName(at labelTag: Int) -> String?
```

- **OCCT:** `TDataStd_Expression::Name`
- **Example:**
  ```swift
  document.setExpression(at: 2)
  document.setExpressionString("50 * 2", at: 2)
  print(document.expressionString(at: 2) ?? "") // "50 * 2"
  ```

---

## TDocStd_XLink

External link attributes that cross-reference labels in other documents.

### `setXLink(at:)`

Attach a `TDocStd_XLink` attribute to a label.

```swift
@discardableResult
public func setXLink(at labelTag: Int) -> Bool
```

- **OCCT:** `TDocStd_XLink::Set`

---

### `setXLinkDocumentEntry(_:at:)`

Set the document entry path (URL or path) of the external link.

```swift
@discardableResult
public func setXLinkDocumentEntry(_ entry: String, at labelTag: Int) -> Bool
```

- **OCCT:** `TDocStd_XLink::SetDocumentEntry`

---

### `xLinkDocumentEntry(at:)`

Get the document entry path of the external link, or `nil` if not set.

```swift
public func xLinkDocumentEntry(at labelTag: Int) -> String?
```

- **OCCT:** `TDocStd_XLink::GetDocumentEntry`

---

### `setXLinkLabelEntry(_:at:)`

Set the label entry string (e.g. `"0:1:2"`) within the external document.

```swift
@discardableResult
public func setXLinkLabelEntry(_ entry: String, at labelTag: Int) -> Bool
```

- **OCCT:** `TDocStd_XLink::SetLabelEntry`

---

### `xLinkLabelEntry(at:)`

Get the label entry string of the external link, or `nil` if not set.

```swift
public func xLinkLabelEntry(at labelTag: Int) -> String?
```

- **OCCT:** `TDocStd_XLink::GetLabelEntry`
- **Example:**
  ```swift
  document.setXLink(at: 3)
  document.setXLinkDocumentEntry("/models/base.xde", at: 3)
  document.setXLinkLabelEntry("0:1:1", at: 3)
  print(document.xLinkDocumentEntry(at: 3) ?? "")
  ```

---

## XCAFDimTolObjects_Tool

Read-only query interface for dimension and geometric tolerance objects stored in the XCAF DimTol subsystem.

### `dimTolToolDimensionCount`

Number of dimension annotation objects in the document.

```swift
public var dimTolToolDimensionCount: Int { get }
```

- **OCCT:** `XCAFDimTolObjects_Tool` dimension list size
- **Example:**
  ```swift
  print(document.dimTolToolDimensionCount)
  ```

---

### `dimTolToolToleranceCount`

Number of geometric tolerance annotation objects in the document.

```swift
public var dimTolToolToleranceCount: Int { get }
```

- **OCCT:** `XCAFDimTolObjects_Tool` tolerance list size
- **Example:**
  ```swift
  print(document.dimTolToolToleranceCount)
  ```

---

## TPrsStd_DriverTable

`DriverTable` — a caseless enum namespace for managing the global singleton table of OCAF presentation drivers.

### `DriverTable.initStandard()`

Populate the global driver table with the standard set of OCAF presentation drivers.

```swift
public static func initStandard()
```

- **OCCT:** `TPrsStd_DriverTable::Get` + `TPrsStd_AISPresentation` standard driver registration
- **Example:**
  ```swift
  DriverTable.initStandard()
  ```

---

### `DriverTable.exists`

Whether the global driver table has been initialized.

```swift
public static var exists: Bool { get }
```

- **OCCT:** `TPrsStd_DriverTable::Get` (non-nil check)

---

### `DriverTable.clear()`

Remove all drivers from the global table.

```swift
public static func clear()
```

- **OCCT:** `TPrsStd_DriverTable::Get().Clear()`
- **Example:**
  ```swift
  if DriverTable.exists {
      DriverTable.clear()
  }
  ```

---

## TObj_Application

`TObjApplication` — Swift wrapper for the `TObj_Application` singleton, the OCAF application context for TObj-based documents.

### `TObjApplication.shared`

Get the singleton `TObj_Application` instance.

```swift
public static var shared: TObjApplication? { get }
```

- **Returns:** The singleton, or `nil` if the OCAF framework has not been initialized.
- **OCCT:** `TObj_Application::GetInstance`
- **Example:**
  ```swift
  if let app = TObjApplication.shared {
      let doc = app.createDocument()
  }
  ```

---

### `isVerbose`

Whether verbose diagnostic logging is enabled on this TObj application.

```swift
public var isVerbose: Bool { get set }
```

- **OCCT:** `TObj_Application::IsVerbose` / `TObj_Application::SetVerbose`

---

### `createDocument()`

Create a new `Document` managed by this TObj application.

```swift
public func createDocument() -> Document?
```

- **Returns:** A new document, or `nil` if the OCAF framework could not allocate one.
- **OCCT:** `TObj_Application::NewDocument`
- **Example:**
  ```swift
  if let app = TObjApplication.shared, let doc = app.createDocument() {
      print(doc.isValid)
  }
  ```

---

## UnitsAPI

`Units` — a caseless enum namespace for unit conversion via OCCT's `UnitsAPI`.

### `Units.convert(_:from:to:)`

Convert a value from one named unit to another.

```swift
public static func convert(_ value: Double, from fromUnit: String, to toUnit: String) -> Double
```

- **Parameters:** `value` — numeric quantity; `fromUnit` — source unit name (e.g. `"mm"`); `toUnit` — target unit name (e.g. `"m"`).
- **Returns:** Converted value.
- **OCCT:** `UnitsAPI::AnyToAny`
- **Example:**
  ```swift
  let meters = Units.convert(1000, from: "mm", to: "m") // 1.0
  ```

---

### `Units.toSI(_:from:)`

Convert a value from a named unit to its SI base unit.

```swift
public static func toSI(_ value: Double, from unit: String) -> Double
```

- **OCCT:** `UnitsAPI::AnyToSI`
- **Example:**
  ```swift
  let radians = Units.toSI(180, from: "deg") // π
  ```

---

### `Units.fromSI(_:to:)`

Convert a value from the SI base unit to a named unit.

```swift
public static func fromSI(_ value: Double, to unit: String) -> Double
```

- **OCCT:** `UnitsAPI::AnyFromSI`

---

### `Units.toLocalSystem(_:from:)`

Convert a value from a named unit to the local unit system.

```swift
public static func toLocalSystem(_ value: Double, from unit: String) -> Double
```

- **OCCT:** `UnitsAPI::AnyToLS`

---

### `Units.fromLocalSystem(_:to:)`

Convert a value from the local unit system to a named unit.

```swift
public static func fromLocalSystem(_ value: Double, to unit: String) -> Double
```

- **OCCT:** `UnitsAPI::AnyFromLS`

---

### `Units.SystemType`

Available local unit system presets.

```swift
public enum SystemType: Int32, Sendable {
    case defaultSystem = 0
    case si            = 1
    case mdtv          = 2
}
```

- **OCCT:** `UnitsAPI_SystemUnits`

---

### `Units.setLocalSystem(_:)`

Set the local unit system used by `toLocalSystem` / `fromLocalSystem`.

```swift
public static func setLocalSystem(_ system: SystemType)
```

- **OCCT:** `UnitsAPI::SetLocalSystem`
- **Example:**
  ```swift
  Units.setLocalSystem(.si)
  ```

---

### `Units.localSystem`

Get the current local unit system.

```swift
public static var localSystem: SystemType { get }
```

- **OCCT:** `UnitsAPI::LocalSystem`

---

## BinTools Shape I/O

Binary serialisation for `Shape` using OCCT's `BinTools` format (compact, version-stable).

### `Shape.toBinaryData()`

Serialise this shape to an in-memory binary blob.

```swift
public func toBinaryData() -> Data?
```

- **Returns:** `Data` containing the binary shape representation, or `nil` if serialisation fails.
- **OCCT:** `BinTools::Write`
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10),
     let data = box.toBinaryData() {
      let restored = Shape.fromBinaryData(data)
  }
  ```

---

### `Shape.fromBinaryData(_:)`

Deserialise a shape from a binary blob produced by `toBinaryData()`.

```swift
public static func fromBinaryData(_ data: Data) -> Shape?
```

- **Parameters:** `data` — binary data previously produced by `toBinaryData()`.
- **Returns:** The restored `Shape`, or `nil` if the data is invalid.
- **OCCT:** `BinTools::Read`

---

### `Shape.writeBinary(to:)`

Write this shape to a binary file.

```swift
@discardableResult
public func writeBinary(to url: URL) -> Bool
```

- **Parameters:** `url` — destination file URL.
- **Returns:** `true` on success.
- **OCCT:** `BinTools::Write` (file overload)
- **Example:**
  ```swift
  if let box = Shape.box(width: 5, height: 5, depth: 5) {
      box.writeBinary(to: URL(fileURLWithPath: "/tmp/box.bin"))
  }
  ```

---

### `Shape.loadBinary(from:)`

Read a shape from a binary file written by `writeBinary(to:)`.

```swift
public static func loadBinary(from url: URL) -> Shape?
```

- **Parameters:** `url` — source file URL.
- **Returns:** The restored `Shape`, or `nil` if the file is missing or invalid.
- **OCCT:** `BinTools::Read` (file overload)
- **Example:**
  ```swift
  if let shape = Shape.loadBinary(from: URL(fileURLWithPath: "/tmp/box.bin")) {
      print(shape.isValid)
  }
  ```

---

## Message_Messenger

`Messenger` — a thin wrapper around OCCT's `Message_Messenger`, allowing messages to be dispatched to one or more attached printers (stdout, file, custom).

### `Messenger.Gravity`

Severity levels for messages.

```swift
public enum Gravity: Int32, Sendable {
    case trace   = 0
    case info    = 1
    case warning = 2
    case alarm   = 3
    case fail    = 4
}
```

- **OCCT:** `Message_Gravity`

---

### `Messenger.init?()`

Create a messenger with a default stdout printer attached.

```swift
public init?()
```

- **Returns:** A messenger, or `nil` if OCCT allocation fails.
- **OCCT:** `Message_Messenger::New`
- **Example:**
  ```swift
  if let messenger = Messenger() {
      messenger.send("Hello from OCCTSwift", gravity: .info)
  }
  ```

---

### `printerCount`

Number of printers currently attached to this messenger.

```swift
public var printerCount: Int { get }
```

- **OCCT:** `Message_Messenger::Printers().Size()`

---

### `send(_:gravity:)`

Dispatch a message to all attached printers at the given severity.

```swift
public func send(_ message: String, gravity: Gravity = .info)
```

- **Parameters:** `message` — message text; `gravity` — severity level (default `.info`).
- **OCCT:** `Message_Messenger::Send`
- **Example:**
  ```swift
  if let messenger = Messenger() {
      messenger.send("Tolerance exceeded", gravity: .warning)
  }
  ```

---

### `addFilePrinter(path:gravity:)`

Attach a file printer that writes messages at or above the given gravity to a log file.

```swift
@discardableResult
public func addFilePrinter(path: String, gravity: Gravity = .info) -> Bool
```

- **Parameters:** `path` — filesystem path for the log file; `gravity` — minimum severity to log.
- **Returns:** `true` if the printer was attached successfully.
- **OCCT:** `Message_PrinterOStream` / `Message_Messenger::AddPrinter`
- **Example:**
  ```swift
  if let messenger = Messenger() {
      messenger.addFilePrinter(path: "/tmp/occt.log", gravity: .warning)
      messenger.send("Test warning", gravity: .warning)
  }
  ```

---

### `removeAllPrinters()`

Detach all printers from this messenger.

```swift
public func removeAllPrinters()
```

- **OCCT:** `Message_Messenger::RemoveAllPrinters`
