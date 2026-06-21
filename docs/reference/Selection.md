---
title: Bill of Materials & Selection
parent: API Reference
---

# Bill of Materials & Selection

`BillOfMaterials` is a pure-Swift value type for assembling and rendering tabular parts lists onto DXF drawings. `Selector` is a BVH-accelerated headless hit-testing engine for interactive picking (point, rectangle, or lasso) without a display context. The `Selection.swift` extensions add ray casting and index-based face access to `Shape`.

## Topics

- [BillOfMaterials](#billofmaterials) · [BillOfMaterials.Item](#billofmaterialsitem) · [BillOfMaterials.Column](#billofmaterialscolumn) · [Sheet Extension — BOM Rendering](#sheet-extension--bom-rendering) · [RayHit](#rayhit) · [Shape Extension — Ray Casting](#shape-extension--ray-casting) · [Shape Extension — Face Index Access](#shape-extension--face-index-access) · [Selector](#selector) · [Selector.SelectionMode](#selectorselectonmode) · [Selector.SubShapeType](#selectorsubshapetype) · [Selector.PickResult](#selectorpickresult)

---

## BillOfMaterials

A pure-Swift, `Sendable`, `Hashable`, `Codable` value type that holds a list of parts and renders them as a bordered table into a `DXFWriter`.

---

### `BillOfMaterials.init(items:title:)`

Creates a `BillOfMaterials` with an explicit item list and optional title string.

```swift
public init(items: [Item], title: String? = nil)
```

- **Parameters:**
  - `items` — ordered array of `Item` rows; rendered top-down from the header.
  - `title` — optional label for the table (not rendered by `render(into:at:)` itself; reserved for caller use).
- **Example:**
  ```swift
  let bom = BillOfMaterials(
      items: [
          .init(number: 1, partNumber: "P-001", description: "Base Plate",
                quantity: 1, material: "6061-T6", mass: 0.48),
          .init(number: 2, description: "M5 Socket Screw", quantity: 8)
      ],
      title: "Assembly BOM"
  )
  ```

---

### `items`

The ordered array of `Item` rows in the bill of materials.

```swift
public var items: [Item]
```

- **Example:**
  ```swift
  bom.items.append(.init(number: 3, description: "Washer", quantity: 16))
  ```

---

### `title`

An optional title string for the BOM table.

```swift
public var title: String?
```

---

### `render(into:at:rowHeight:columnWidths:)`

Renders the BOM as a bordered table into a `DXFWriter`, growing upward and leftward from the given origin.

```swift
@discardableResult
public func render(into writer: DXFWriter,
                    at origin: SIMD2<Double>,
                    rowHeight: Double = 6,
                    columnWidths: [Double]? = nil) -> SIMD2<Double>
```

The `origin` is the **bottom-right** corner of the table; the table expands upward and to the left, placing it naturally above a title block. All cells are written on the `"TEXT"` layer; border lines on the `"BORDER"` layer.

- **Parameters:**
  - `into writer` — the `DXFWriter` receiving the geometry.
  - `at origin` — bottom-right anchor point of the table in model coordinates.
  - `rowHeight` — height of each row in model units (default 6).
  - `columnWidths` — per-column widths in model units, one per `Column.allCases`; if `nil` uses `Column.defaultWidth` for each column.
- **Returns:** The top-right corner of the rendered table (useful for chaining further annotations above the BOM). Returns `origin` if `columnWidths.count != Column.allCases.count`.
- **Note:** Pure-Swift; no OCCT bridge involved.
- **Example:**
  ```swift
  var writer = DXFWriter()
  let topRight = bom.render(into: writer, at: SIMD2(190, 30))
  // topRight.y is the Y coordinate above which the next annotation can be placed
  ```

---

## BillOfMaterials.Item

A single row in the bill of materials. All fields except `number`, `description`, and `quantity` are optional.

---

### `BillOfMaterials.Item.init(number:partNumber:description:quantity:material:mass:notes:)`

Creates a BOM row.

```swift
public init(number: Int,
            partNumber: String? = nil,
            description: String,
            quantity: Int = 1,
            material: String? = nil,
            mass: Double? = nil,
            notes: String? = nil)
```

- **Parameters:**
  - `number` — balloon/callout number (ITEM column).
  - `partNumber` — drawing part number (PART NO column); `nil` renders as empty.
  - `description` — human-readable description (DESCRIPTION column).
  - `quantity` — part count (QTY column); default 1.
  - `material` — material specification (MAT column); `nil` renders as empty.
  - `mass` — mass in model units (MASS column); formatted `"%.2f"`; `nil` renders as empty.
  - `notes` — freeform notes (NOTES column); `nil` renders as empty.
- **Example:**
  ```swift
  let row = BillOfMaterials.Item(
      number: 1,
      partNumber: "SH-42",
      description: "Shaft",
      quantity: 2,
      material: "4140 Steel",
      mass: 1.35,
      notes: "Heat treat to 40 HRC"
  )
  ```

---

### `number`

The item/balloon number for this row (ITEM column).

```swift
public var number: Int
```

---

### `partNumber`

The part number string (PART NO column). `nil` renders as blank.

```swift
public var partNumber: String?
```

---

### `description`

Human-readable description of the part (DESCRIPTION column).

```swift
public var description: String
```

---

### `quantity`

Number of instances of this part (QTY column).

```swift
public var quantity: Int
```

---

### `material`

Material specification string (MAT column). `nil` renders as blank.

```swift
public var material: String?
```

---

### `mass`

Mass value in model units (MASS column), formatted as `"%.2f"`. `nil` renders as blank.

```swift
public var mass: Double?
```

---

### `notes`

Freeform annotation text (NOTES column). `nil` renders as blank.

```swift
public var notes: String?
```

---

## BillOfMaterials.Column

Enumerates the fixed set of columns rendered by `BillOfMaterials.render(into:at:)`, in source order.

```swift
public enum Column: String, Sendable, CaseIterable {
    case item, partNumber, description, quantity, material, mass, notes
}
```

---

### `header`

The column header label as rendered in the top row of the table.

```swift
public var header: String { get }
```

Returns `"ITEM"`, `"PART NO"`, `"DESCRIPTION"`, `"QTY"`, `"MAT"`, `"MASS"`, or `"NOTES"` respectively.

- **Example:**
  ```swift
  let headers = BillOfMaterials.Column.allCases.map(\.header)
  // ["ITEM", "PART NO", "DESCRIPTION", "QTY", "MAT", "MASS", "NOTES"]
  ```

---

### `defaultWidth`

The default column width in model units used when `columnWidths` is `nil` in `render(into:at:)`.

```swift
public var defaultWidth: Double { get }
```

Values: `.item` → 12, `.partNumber` → 25, `.description` → 60, `.quantity` → 10, `.material` → 25, `.mass` → 15, `.notes` → 30.

---

## Sheet Extension — BOM Rendering

### `Sheet.renderBOM(_:into:at:rowHeight:columnWidths:)`

Renders a `BillOfMaterials` onto the sheet at a position automatically aligned to the inner frame's top-right corner.

```swift
@discardableResult
public func renderBOM(_ bom: BillOfMaterials,
                       into writer: DXFWriter,
                       at origin: SIMD2<Double>? = nil,
                       rowHeight: Double = 6,
                       columnWidths: [Double]? = nil) -> SIMD2<Double>
```

When `origin` is `nil`, the anchor is computed as `(frame.max.x, frame.max.y − totalTableHeight)`, placing the table flush with the inner frame's right edge and dropping it so the bottom lands at the top of the title block area.

- **Parameters:**
  - `bom` — the `BillOfMaterials` to render.
  - `into writer` — the `DXFWriter` receiving the geometry.
  - `at origin` — explicit bottom-right anchor; `nil` uses the automatic frame-relative placement.
  - `rowHeight` — height of each row in model units (default 6).
  - `columnWidths` — per-column widths; `nil` uses `Column.defaultWidth`.
- **Returns:** Top-right corner of the rendered table (forwarded from `BillOfMaterials.render`).
- **Note:** Pure-Swift; no OCCT bridge involved.
- **Example:**
  ```swift
  var writer = DXFWriter()
  let sheet = Sheet(size: .a3, orientation: .landscape)
  sheet.render(into: &writer)
  sheet.renderBOM(bom, into: writer)
  ```

---

## RayHit

Result of a single ray-surface intersection from `Shape.raycast(origin:direction:tolerance:maxHits:)`.

```swift
public struct RayHit: Sendable {
    public let point: SIMD3<Double>
    public let normal: SIMD3<Double>
    public let faceIndex: Int
    public let distance: Double
    public let uv: SIMD2<Double>
}
```

- `point` — 3D world-space intersection point on the surface.
- `normal` — unit outward normal at the intersection; respects face orientation (`TopAbs_REVERSED`). Falls back to `(0, 0, 1)` if the normal is undefined at the hit point.
- `faceIndex` — 0-based index of the intersected face within the shape's `TopTools_IndexedMapOfShape`.
- `distance` — signed ray parameter (distance from origin along the ray direction).
- `uv` — UV surface parameters at the intersection point.

---

## Shape Extension — Ray Casting

### `Shape.raycast(origin:direction:tolerance:maxHits:)`

Casts a ray against all faces of the shape and returns every intersection, sorted nearest-first.

```swift
public func raycast(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    tolerance: Double = 0.001,
    maxHits: Int = 100
) -> [RayHit]
```

The direction vector is automatically normalised by `gp_Dir`. Intersections beyond `maxHits` are discarded. Returns an empty array if the ray does not intersect the shape or an error occurs.

- **Parameters:**
  - `origin` — ray start point in world space.
  - `direction` — ray direction (normalised internally).
  - `tolerance` — intersection tolerance (default 0.001).
  - `maxHits` — maximum number of hits to collect (default 100).
- **Returns:** Array of `RayHit` sorted by ascending `distance`; empty if no intersection.
- **OCCT:** `IntCurvesFace_ShapeIntersector::Load` / `Perform` / `NbPnt` / `Pnt` / `WParameter` / `Face` / `UParameter` / `VParameter`; normals via `BRepAdaptor_Surface` + `BRepLProp_SLProps`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let hits = box.raycast(
      origin: SIMD3(5, 5, -20),
      direction: SIMD3(0, 0, 1)
  )
  if let first = hits.first {
      print(first.point, first.normal, first.faceIndex)
  }
  ```

---

### `Shape.raycastNearest(origin:direction:tolerance:)`

Convenience wrapper that returns only the nearest ray intersection.

```swift
public func raycastNearest(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    tolerance: Double = 0.001
) -> RayHit?
```

Equivalent to `raycast(origin:direction:tolerance:maxHits:100).first`.

- **Parameters:**
  - `origin` — ray start point.
  - `direction` — ray direction (normalised internally).
  - `tolerance` — intersection tolerance (default 0.001).
- **Returns:** The nearest `RayHit`, or `nil` if the ray does not intersect the shape.
- **OCCT:** `IntCurvesFace_ShapeIntersector` (via `raycast`).
- **Example:**
  ```swift
  let sphere = Shape.sphere(radius: 5)!
  if let hit = sphere.raycastNearest(
      origin: SIMD3(0, 0, -20),
      direction: SIMD3(0, 0, 1)
  ) {
      print(hit.distance)  // ≈ 15.0 (front of sphere)
  }
  ```

---

## Shape Extension — Face Index Access

### `Shape.faceCount`

Total number of face sub-shapes in the shape.

```swift
public var faceCount: Int { get }
```

- **Returns:** Count of `TopoDS_Face` sub-shapes; 0 on error or if the shape has no faces.
- **OCCT:** `TopExp::MapShapes(shape, TopAbs_FACE, faceMap)` → `faceMap.Extent()`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  print(box.faceCount)  // 6
  ```

---

### `Shape.face(at:)`

Returns the face at a 0-based index within the shape's indexed face map.

```swift
public func face(at index: Int) -> Face?
```

The index corresponds to `TopTools_IndexedMapOfShape` ordering, matching the `faceIndex` field returned by `RayHit`.

- **Parameters:** `index` — 0-based face index.
- **Returns:** `Face` at the given index, or `nil` if `index` is out of bounds or the shape is null.
- **OCCT:** `TopExp::MapShapes` + `TopoDS::Face(faceMap(index + 1))` (OCCT maps are 1-based internally).
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let hits = box.raycast(origin: SIMD3(5, 5, -20), direction: SIMD3(0, 0, 1))
  if let hit = hits.first, let face = box.face(at: hit.faceIndex) {
      print(face.surfaceType)  // .plane
  }
  ```

---

## Selector

BVH-accelerated headless hit-testing for point, rectangle, and lasso picking against registered `Shape` objects, without requiring an OpenGL or Metal display context.

```swift
public final class Selector: @unchecked Sendable
```

Internally wraps an `OCCTHeadlessSelector` — a subclass of OCCT's `SelectMgr_ViewerSelector` — paired with a `SelectMgr_SelectionManager`. Shapes are decomposed into `SelectMgr_Selection` sensitive primitives by `StdSelect_BRepSelectionTool`.

---

### `Selector.init()`

Creates an empty `Selector` with no registered shapes.

```swift
public init()
```

- **OCCT:** `SelectMgr_SelectionManager` + `OCCTHeadlessSelector` (custom `SelectMgr_ViewerSelector` subclass).
- **Example:**
  ```swift
  let selector = Selector()
  ```

---

## Selector.SelectionMode

Controls which level of sub-shape topology is made selectable for a given shape.

```swift
public enum SelectionMode: Int32, Sendable {
    case shape  = 0
    case vertex = 1
    case edge   = 2
    case wire   = 3
    case face   = 4
}
```

Maps to `TopAbs_ShapeEnum` decomposition as used by `StdSelect_BRepSelectionTool`. Mode `.shape` (0) is activated automatically when a shape is added. Multiple modes can be active simultaneously.

---

## Selector.SubShapeType

Identifies the topology type of the sub-shape that was hit in a pick result.

```swift
public enum SubShapeType: Int32, Sendable {
    case compound  = 0
    case compsolid = 1
    case solid     = 2
    case shell     = 3
    case face      = 4
    case wire      = 5
    case edge      = 6
    case vertex    = 7
    case shape     = 8
}
```

Maps directly to OCCT's `TopAbs_ShapeEnum` integer values.

---

## Selector.PickResult

Result of a single hit from a pick operation.

```swift
public struct PickResult: Sendable {
    public let shapeId: Int32
    public let depth: Double
    public let point: SIMD3<Double>
    public let subShapeType: SubShapeType
    public let subShapeIndex: Int32
}
```

- `shapeId` — the integer ID assigned when the shape was added via `add(shape:id:)`.
- `depth` — distance from the camera to the hit.
- `point` — 3D world-space point where the pick ray intersected the sensitive primitive.
- `subShapeType` — topology type of the sub-shape hit (e.g. `.face`, `.edge`).
- `subShapeIndex` — 1-based index of the hit sub-shape within its parent shape; 0 when the whole shape is selected (mode 0).

---

## Shape Management

### `Selector.add(shape:id:)`

Registers a shape with a unique integer ID and activates whole-shape selection (mode 0).

```swift
@discardableResult
public func add(shape: Shape, id: Int32) -> Bool
```

If a shape with the same `id` is already registered, it is replaced. Use `activateMode(_:for:)` after adding to enable sub-shape picking modes.

- **Parameters:**
  - `shape` — the `Shape` to register.
  - `id` — unique integer identifier; used to correlate `PickResult.shapeId` back to the shape.
- **Returns:** `true` if the shape was added successfully.
- **OCCT:** `SelectMgr_SelectionManager::Load` + `StdSelect_BRepSelectionTool::Load`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  selector.add(shape: box, id: 1)
  ```

---

### `Selector.remove(id:)`

Removes the shape registered under the given ID.

```swift
@discardableResult
public func remove(id: Int32) -> Bool
```

- **Parameters:** `id` — the shape ID to remove.
- **Returns:** `true` if the shape was found and removed; `false` if no shape with that ID exists.
- **OCCT:** `SelectMgr_SelectionManager::Remove`.
- **Example:**
  ```swift
  selector.remove(id: 1)
  ```

---

### `Selector.clearAll()`

Removes all registered shapes and their selection owners.

```swift
public func clearAll()
```

- **OCCT:** `SelectMgr_SelectionManager::Remove` called for each registered shape.
- **Example:**
  ```swift
  selector.clearAll()
  ```

---

## Selection Modes

### `Selector.activateMode(_:for:)`

Activates a selection mode for a registered shape, making that sub-shape level pickable.

```swift
public func activateMode(_ mode: SelectionMode, for shapeId: Int32)
```

Multiple modes can be active simultaneously. Calling this with `.face` enables face picking without disabling the whole-shape mode already active.

- **Parameters:**
  - `mode` — the `SelectionMode` to activate.
  - `shapeId` — the ID of the shape to configure.
- **OCCT:** `SelectMgr_SelectionManager::Activate(selectable, mode.rawValue)` + `StdSelect_BRepSelectionTool::Load`.
- **Example:**
  ```swift
  selector.add(shape: box, id: 1)
  selector.activateMode(.face, for: 1)
  selector.activateMode(.edge, for: 1)
  ```

---

### `Selector.deactivateMode(_:for:)`

Deactivates a selection mode for a registered shape.

```swift
public func deactivateMode(_ mode: SelectionMode, for shapeId: Int32)
```

- **Parameters:**
  - `mode` — the `SelectionMode` to deactivate.
  - `shapeId` — the ID of the shape to configure.
- **OCCT:** `SelectMgr_SelectionManager::Deactivate(selectable, mode.rawValue)`.
- **Example:**
  ```swift
  selector.deactivateMode(.edge, for: 1)
  ```

---

### `Selector.isModeActive(_:for:)`

Checks whether a given selection mode is currently active for a shape.

```swift
public func isModeActive(_ mode: SelectionMode, for shapeId: Int32) -> Bool
```

- **Parameters:**
  - `mode` — the mode to query.
  - `shapeId` — the shape ID.
- **Returns:** `true` if the mode is active.
- **OCCT:** Queries `SelectMgr_Selection` activation state via `SelectMgr_SelectionManager`.
- **Example:**
  ```swift
  if selector.isModeActive(.face, for: 1) {
      print("face picking is on")
  }
  ```

---

## Pixel Tolerance

### `Selector.pixelTolerance`

Pixel radius used to detect picks near thin geometry such as edges and vertices.

```swift
public var pixelTolerance: Int32 { get set }
```

Higher values increase the catchment area around edges and vertices, making them easier to pick in densely packed scenes. Default is 2 pixels.

- **OCCT:** `SelectMgr_ViewerSelector::SetPixelTolerance` / `PixelTolerance`.
- **Example:**
  ```swift
  selector.pixelTolerance = 5  // easier to pick edges
  ```

---

## Picking

### `Selector.pick(at:camera:viewSize:maxResults:)`

Picks shapes at a single pixel coordinate.

```swift
public func pick(at pixel: SIMD2<Double>,
                 camera: Camera,
                 viewSize: SIMD2<Double>,
                 maxResults: Int = 32) -> [PickResult]
```

Results are sorted by depth (nearest first). Only shapes and sub-shape modes that have been activated are returned.

- **Parameters:**
  - `pixel` — pixel coordinate in the viewport (origin at top-left).
  - `camera` — camera providing the projection and view transforms.
  - `viewSize` — viewport dimensions in pixels `(width, height)`.
  - `maxResults` — maximum number of results (default 32).
- **Returns:** Array of `PickResult` sorted by ascending depth; empty if nothing was hit.
- **OCCT:** `OCCTHeadlessSelector::PickPoint` → `SelectMgr_ViewerSelector::Pick` (point volume) + `SelectMgr_SortCriterion` for depth ordering.
- **Example:**
  ```swift
  let results = selector.pick(at: SIMD2(320, 240),
                               camera: camera,
                               viewSize: SIMD2(640, 480))
  if let hit = results.first {
      print(hit.shapeId, hit.subShapeType, hit.point)
  }
  ```

---

### `Selector.pick(rect:camera:viewSize:maxResults:)`

Picks all shapes that intersect a rectangular pixel region (rubber-band selection).

```swift
public func pick(rect: (min: SIMD2<Double>, max: SIMD2<Double>),
                 camera: Camera,
                 viewSize: SIMD2<Double>,
                 maxResults: Int = 32) -> [PickResult]
```

- **Parameters:**
  - `rect` — rectangle defined by `(min, max)` pixel corners.
  - `camera` — camera providing the projection and view transforms.
  - `viewSize` — viewport dimensions in pixels.
  - `maxResults` — maximum number of results (default 32).
- **Returns:** Array of `PickResult` for all shapes intersecting the rectangle.
- **OCCT:** `OCCTHeadlessSelector::PickRect` → `SelectMgr_ViewerSelector::Pick` (box volume).
- **Example:**
  ```swift
  let selected = selector.pick(
      rect: (min: SIMD2(100, 100), max: SIMD2(400, 300)),
      camera: camera,
      viewSize: SIMD2(640, 480)
  )
  print("\(selected.count) shapes in rectangle")
  ```

---

### `Selector.pick(polygon:camera:viewSize:maxResults:)`

Picks all shapes inside a closed polygon (lasso selection).

```swift
public func pick(polygon: [SIMD2<Double>],
                 camera: Camera,
                 viewSize: SIMD2<Double>,
                 maxResults: Int = 32) -> [PickResult]
```

The polygon must have at least 3 points. The last point is automatically connected back to the first. Returns an empty array immediately if `polygon.count < 3`.

- **Parameters:**
  - `polygon` — array of pixel coordinates defining the polygon vertices (minimum 3 points).
  - `camera` — camera providing the projection and view transforms.
  - `viewSize` — viewport dimensions in pixels.
  - `maxResults` — maximum number of results (default 32).
- **Returns:** Array of `PickResult` for all shapes whose sensitive primitives fall inside the polygon.
- **OCCT:** `OCCTHeadlessSelector::PickPoly` → `SelectMgr_ViewerSelector::Pick` (polyline volume); pixel XY pairs passed as interleaved `double` array.
- **Example:**
  ```swift
  let lasso: [SIMD2<Double>] = [
      SIMD2(100, 100), SIMD2(400, 80),
      SIMD2(420, 350), SIMD2(80,  330)
  ]
  let inside = selector.pick(polygon: lasso,
                              camera: camera,
                              viewSize: SIMD2(640, 480))
  print("\(inside.count) shapes inside lasso")
  ```
