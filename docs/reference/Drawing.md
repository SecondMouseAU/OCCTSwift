---
title: Drawing & Sheets
parent: API Reference
---

# Drawing & Sheets

The drawing subsystem converts 3D solid geometry into 2D projected views using OCCT's Hidden Line Removal (HLR) pipeline. `Drawing` produces exact or polygon-approximate orthographic/perspective views of a `Shape` and carries dimension and annotation objects. `DrawingSheet` provides ISO 5457/7200 sheet scaffolding (paper sizes, title blocks, projection symbols). `DrawingStyle` encodes ISO 128/3098/5455 line-width, text-height, arrow, and scale conventions. `DisplayDrawer` controls tessellation quality and wireframe rendering via OCCT's `Prs3d_Drawer`.

## Topics

- [Drawing](#drawing) · [DrawingError](#drawingerror) · [PaperSize](#papersize) · [Orientation](#orientation) · [ProjectionAngle](#projectionangle) · [TitleBlock](#titleblock) · [Sheet](#sheet) · [ProjectionSymbol](#projectionsymbol) · [DrawingLineWidth](#drawinglinewidth) · [DrawingLineStyle extension](#drawinglinestyle-extension) · [DrawingTextHeight](#drawingtextheight) · [DrawingArrowStyle](#drawingarrowstyle) · [DrawingScale](#drawingscale) · [DisplayDrawer](#displaydrawer)

---

## Drawing

A 2D projection of a 3D shape produced by OCCT's Hidden Line Removal algorithm. Holds visible, hidden, and outline edge compounds plus an in-memory store of attached dimension and annotation objects.

```swift
public final class Drawing: @unchecked Sendable
```

Obtain a `Drawing` by calling one of the static factory methods (`project(_:direction:type:)`, `topView(of:)`, etc.). The object is memory-managed via `OCCTDrawingRef`; `deinit` calls `OCCTDrawingRelease`.

---

### Enumerations

### `Drawing.ProjectionType`

Projection algorithm applied during HLR computation.

```swift
public enum ProjectionType: UInt32 {
    case orthographic = 0
    case perspective  = 1
}
```

- `.orthographic` — parallel-line projection (engineering drawings).
- `.perspective` — converging-line projection.
- **OCCT:** Passed as `OCCTProjectionType` to `HLRAlgo_Projector` construction inside `OCCTDrawingCreate`.

---

### `Drawing.EdgeType`

Selects which class of projected edges to retrieve from a `Drawing`.

```swift
public enum EdgeType: UInt32 {
    case visible = 0
    case hidden  = 1
    case outline = 2
}
```

- `.visible` — sharp and smooth edges not obscured by other geometry (`VCompound` + `Rg1LineVCompound`).
- `.hidden` — edges behind other geometry (`HCompound` + `Rg1LineHCompound`).
- `.outline` — silhouette / outline edges (`OutLineVCompound` / `OutLineHCompound`).
- **OCCT:** `HLRBRep_HLRToShape` / `HLRBRep_PolyHLRToShape` compound accessors, selected via `OCCTEdgeType` in `OCCTDrawingGetEdges`.

---

### Dimensions and annotations (v0.137, #64)

### `dimensions`

All dimension annotations attached to this drawing.

```swift
public var dimensions: [DrawingDimension] { get }
```

Returns the live contents of the internal `DrawingAnnotationStore`. Mutations via `addLinearDimension(...)`, `addRadialDimension(...)`, etc. are reflected immediately.

- **Example:**
  ```swift
  let drawing = Drawing.topView(of: myShape)!
  drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(100, 0))
  print(drawing.dimensions.count)  // 1
  ```

---

### `annotations`

All non-dimensional annotations (centrelines, centremarks, text, hatches, balloons, cutting-plane lines) attached to this drawing.

```swift
public var annotations: [DrawingAnnotation] { get }
```

- **Example:**
  ```swift
  drawing.addCentreLine(from: SIMD2(50, 0), to: SIMD2(50, 100))
  print(drawing.annotations.count)  // 1
  ```

---

### `addLinearDimension(from:to:offset:label:style:id:)`

Attaches a linear (distance) dimension between two 2D points.

```swift
@discardableResult
public func addLinearDimension(from: SIMD2<Double>, to: SIMD2<Double>,
                               offset: Double = 10,
                               label: String? = nil,
                               style: DrawingLineStyle = .solid,
                               id: String? = nil) -> DrawingDimension
```

- **Parameters:**
  - `from` — start point in drawing coordinates (mm).
  - `to` — end point in drawing coordinates (mm).
  - `offset` — perpendicular distance of the dimension line from the measured line (default 10 mm).
  - `label` — optional override text; `nil` auto-formats the measured distance.
  - `style` — line style for extension and dimension lines (default `.solid`).
  - `id` — optional stable identifier for downstream DXF/SVG export.
- **Returns:** The appended `DrawingDimension.linear(...)` value.
- **Example:**
  ```swift
  let drawing = Drawing.topView(of: Shape.box(width: 100, height: 50, depth: 30)!)!
  drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(100, 0), offset: 15)
  ```

---

### `addRadialDimension(centre:radius:leaderAngle:label:style:id:)`

Attaches a radial dimension (R notation) from the centre of an arc or circle.

```swift
@discardableResult
public func addRadialDimension(centre: SIMD2<Double>, radius: Double,
                               leaderAngle: Double = .pi / 4,
                               label: String? = nil,
                               style: DrawingLineStyle = .solid,
                               id: String? = nil) -> DrawingDimension
```

- **Parameters:**
  - `centre` — centre point of the arc/circle in drawing coordinates.
  - `radius` — radius value in drawing units (mm).
  - `leaderAngle` — angle of the leader line from the positive X axis (default π/4 = 45°).
  - `label` — optional override; `nil` auto-formats as "R\<value\>".
  - `style` — line style (default `.solid`).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingDimension.radial(...)` value.
- **Example:**
  ```swift
  drawing.addRadialDimension(centre: SIMD2(50, 50), radius: 25)
  ```

---

### `addDiameterDimension(centre:radius:leaderAngle:label:style:id:)`

Attaches a diameter dimension (⌀ notation) across a circle.

```swift
@discardableResult
public func addDiameterDimension(centre: SIMD2<Double>, radius: Double,
                                 leaderAngle: Double = .pi / 4,
                                 label: String? = nil,
                                 style: DrawingLineStyle = .solid,
                                 id: String? = nil) -> DrawingDimension
```

- **Parameters:**
  - `centre` — centre of the circle in drawing coordinates.
  - `radius` — radius value (the label shows the diameter, 2 × radius).
  - `leaderAngle` — leader line angle (default π/4).
  - `label` — optional override; `nil` auto-formats as "⌀\<diameter\>".
  - `style` — line style (default `.solid`).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingDimension.diameter(...)` value.
- **Example:**
  ```swift
  drawing.addDiameterDimension(centre: SIMD2(50, 50), radius: 25, leaderAngle: .pi / 6)
  ```

---

### `addAngularDimension(vertex:ray1:ray2:arcRadius:label:style:id:)`

Attaches an angular dimension measuring the angle between two rays from a common vertex.

```swift
@discardableResult
public func addAngularDimension(vertex: SIMD2<Double>,
                                ray1: SIMD2<Double>,
                                ray2: SIMD2<Double>,
                                arcRadius: Double = 20,
                                label: String? = nil,
                                style: DrawingLineStyle = .solid,
                                id: String? = nil) -> DrawingDimension
```

- **Parameters:**
  - `vertex` — vertex point of the angle.
  - `ray1` — direction of the first ray (as a 2D point from `vertex`).
  - `ray2` — direction of the second ray.
  - `arcRadius` — radius of the dimension arc drawn between the rays (default 20 mm).
  - `label` — optional override; `nil` auto-formats the angle in degrees.
  - `style` — line style (default `.solid`).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingDimension.angular(...)` value.
- **Example:**
  ```swift
  drawing.addAngularDimension(vertex: SIMD2(50, 50),
                              ray1: SIMD2(1, 0),
                              ray2: SIMD2(0, 1),
                              arcRadius: 15)
  ```

---

### `addOrdinateDimensions(origin:features:tolerance:id:)`

Attaches ISO 129-1 §9.3 ordinate dimensions: X and Y offsets from a shared origin to a set of features.

```swift
@discardableResult
public func addOrdinateDimensions(origin: SIMD2<Double>,
                                   features: [(position: SIMD2<Double>, label: String?)],
                                   tolerance: DrawingTolerance = .none,
                                   id: String? = nil) -> DrawingDimension
```

- **Parameters:**
  - `origin` — the datum origin from which all offsets are measured.
  - `features` — array of `(position, optional label)` tuples; `nil` labels are auto-formatted as the offset value.
  - `tolerance` — optional tolerance to apply to each offset value (default `.none`).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingDimension.ordinate(...)` value.
- **Example:**
  ```swift
  drawing.addOrdinateDimensions(
      origin: .zero,
      features: [
          (SIMD2(25, 0), nil),
          (SIMD2(60, 0), nil),
          (SIMD2(90, 0), "X3")
      ]
  )
  ```

---

### `addCentreLine(from:to:style:id:)`

Attaches a centre-line annotation between two 2D points.

```swift
@discardableResult
public func addCentreLine(from: SIMD2<Double>, to: SIMD2<Double>,
                          style: DrawingLineStyle = .chain,
                          id: String? = nil) -> DrawingAnnotation
```

- **Parameters:**
  - `from` — start point.
  - `to` — end point.
  - `style` — line style (default `.chain`, per ISO 128-24 for axes and centre lines).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingAnnotation.centreline(...)` value.
- **Example:**
  ```swift
  drawing.addCentreLine(from: SIMD2(50, 0), to: SIMD2(50, 100))
  ```

---

### `addCentermark(centre:extent:style:id:)`

Attaches a centre-mark cross (two perpendicular centre lines) at a point.

```swift
@discardableResult
public func addCentermark(centre: SIMD2<Double>, extent: Double = 8,
                          style: DrawingLineStyle = .chain,
                          id: String? = nil) -> DrawingAnnotation
```

- **Parameters:**
  - `centre` — centre of the mark.
  - `extent` — half-length of each arm of the cross (default 8 mm).
  - `style` — line style (default `.chain`).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingAnnotation.centermark(...)` value.
- **Example:**
  ```swift
  drawing.addCentermark(centre: SIMD2(50, 50), extent: 6)
  ```

---

### `addTextLabel(_:at:height:rotation:id:)`

Attaches a free text label at a 2D position.

```swift
@discardableResult
public func addTextLabel(_ text: String, at position: SIMD2<Double>,
                         height: Double = 3.5, rotation: Double = 0,
                         id: String? = nil) -> DrawingAnnotation
```

- **Parameters:**
  - `text` — the string to display.
  - `position` — insertion point in drawing coordinates.
  - `height` — text height in mm (default 3.5 mm, the ISO 3098 standard body height).
  - `rotation` — rotation angle in radians counter-clockwise (default 0).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingAnnotation.textLabel(...)` value.
- **Example:**
  ```swift
  drawing.addTextLabel("SECTION A-A", at: SIMD2(10, 200), height: 5)
  ```

---

### `addBalloon(itemNumber:at:leaderTo:radius:id:)`

Attaches an assembly-drawing balloon callout keyed to a bill-of-materials row.

```swift
@discardableResult
public func addBalloon(itemNumber: Int,
                       at position: SIMD2<Double>,
                       leaderTo target: SIMD2<Double>? = nil,
                       radius: Double = 5,
                       id: String? = nil) -> DrawingAnnotation
```

- **Parameters:**
  - `itemNumber` — BOM item number displayed inside the balloon circle.
  - `position` — centre of the balloon circle in drawing coordinates.
  - `target` — optional leader-line endpoint pointing at the referenced part; `nil` draws no leader.
  - `radius` — balloon circle radius in mm (default 5 mm).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingAnnotation.balloon(...)` value.
- **Example:**
  ```swift
  drawing.addBalloon(itemNumber: 3, at: SIMD2(120, 80),
                     leaderTo: SIMD2(95, 60), radius: 6)
  ```

---

### `addCuttingPlaneLine(label:cuttingPlaneOrigin:cuttingPlaneNormal:sectionViewDirection:viewDirection:traceLength:)`

Attaches an ISO 128-40 cutting-plane line, projecting the 3D plane into this drawing's 2D frame.

```swift
@discardableResult
public func addCuttingPlaneLine(label: String,
                                 cuttingPlaneOrigin: SIMD3<Double>,
                                 cuttingPlaneNormal: SIMD3<Double>,
                                 sectionViewDirection: SIMD3<Double>,
                                 viewDirection: SIMD3<Double>,
                                 traceLength: Double = 60) -> DrawingAnnotation?
```

- **Parameters:**
  - `label` — identifier letter(s) shown at the arrow tips (e.g. `"A"`).
  - `cuttingPlaneOrigin` — a 3D point on the cutting plane.
  - `cuttingPlaneNormal` — normal of the cutting plane in 3D.
  - `sectionViewDirection` — the direction in which the section view is projected (controls arrow orientation).
  - `viewDirection` — the projection direction of this parent drawing (used to project the trace into 2D).
  - `traceLength` — length of the trace line in drawing units (default 60 mm).
- **Returns:** The appended annotation, or `nil` if the cutting plane is parallel to the view plane (trace degenerates to a point).
- **Note:** Pure-Swift: computes the 2D trace via `simd_cross(cuttingPlaneNormal, viewDirection)` and projects both trace and arrow direction into the drawing plane.
- **Example:**
  ```swift
  if let cpl = drawing.addCuttingPlaneLine(
      label: "A",
      cuttingPlaneOrigin: SIMD3(50, 0, 0),
      cuttingPlaneNormal: SIMD3(1, 0, 0),
      sectionViewDirection: SIMD3(1, 0, 0),
      viewDirection: SIMD3(0, 0, 1)) {
      print("Cutting plane line added")
  }
  ```

---

### `addHatch(boundary:angle:spacing:islands:layer:id:)`

Attaches ISO 128-50 section-view hatching over a closed boundary polygon.

```swift
@discardableResult
public func addHatch(boundary: [SIMD2<Double>],
                     angle: Double = .pi / 4,
                     spacing: Double = 3.0,
                     islands: [[SIMD2<Double>]] = [],
                     layer: String = "HATCH",
                     id: String? = nil) -> DrawingAnnotation
```

- **Parameters:**
  - `boundary` — ordered polygon vertices of the hatch region.
  - `angle` — hatch line angle in radians (default π/4 = 45°, the ISO 128-50 convention for metals).
  - `spacing` — distance between hatch lines in mm (default 3 mm per ISO).
  - `islands` — optional inner boundary polygons excluded from the fill (holes).
  - `layer` — DXF layer name for the hatch (default `"HATCH"`).
  - `id` — optional stable identifier.
- **Returns:** The appended `DrawingAnnotation.hatch(...)` value.
- **Example:**
  ```swift
  drawing.addHatch(boundary: [SIMD2(10,10), SIMD2(90,10),
                               SIMD2(90,60), SIMD2(10,60)],
                   spacing: 4)
  ```

---

### `clearAnnotations()`

Removes all dimensions and annotations from this drawing.

```swift
public func clearAnnotations()
```

- **Example:**
  ```swift
  drawing.clearAnnotations()
  print(drawing.dimensions.count)   // 0
  print(drawing.annotations.count)  // 0
  ```

---

### Uniform append API (v0.148, #83, #84)

### `append(_:) — DrawingAnnotation`

Appends a pre-built annotation to this drawing.

```swift
public func append(_ annotation: DrawingAnnotation)
```

Use to install the result of a static factory (e.g. `DrawingAnnotation.surfaceFinish(...)`, `DrawingAnnotation.featureControlFrame(...)`).

- **Parameters:** `annotation` — any `DrawingAnnotation` case.
- **Example:**
  ```swift
  let sf = DrawingAnnotation.surfaceFinish(...)
  drawing.append(sf)
  ```

---

### `append(contentsOf:) — [DrawingAnnotation]`

Appends a batch of pre-built annotations.

```swift
public func append(contentsOf annotations: [DrawingAnnotation])
```

- **Parameters:** `annotations` — array of `DrawingAnnotation` values.
- **Example:**
  ```swift
  let cosmetics = DrawingAnnotation.cosmeticThreadSideView(...)
  drawing.append(contentsOf: cosmetics)
  ```

---

### `append(_:) — DrawingDimension`

Appends a pre-built dimension.

```swift
public func append(_ dimension: DrawingDimension)
```

- **Parameters:** `dimension` — any `DrawingDimension` case.
- **Example:**
  ```swift
  let dim = DrawingDimension.linear(.init(from: .zero, to: SIMD2(80, 0), offset: 12))
  drawing.append(dim)
  ```

---

### `append(contentsOf:) — [DrawingDimension]`

Appends a batch of pre-built dimensions.

```swift
public func append(contentsOf dimensions: [DrawingDimension])
```

- **Parameters:** `dimensions` — array of `DrawingDimension` values.
- **Example:**
  ```swift
  drawing.append(contentsOf: autoDimensions)
  ```

---

### Creation

### `Drawing.project(_:direction:type:)`

Creates a 2D projection of a 3D shape using exact HLR.

```swift
public static func project(
    _ shape: Shape,
    direction: SIMD3<Double>,
    type: ProjectionType = .orthographic
) -> Drawing?
```

The underlying algorithm uses `HLRBRep_Algo` for exact edge-geometry HLR — slower but produces precise curves.

- **Parameters:**
  - `shape` — the 3D shape to project.
  - `direction` — view direction vector (need not be normalised).
  - `type` — projection type (default `.orthographic`).
- **Returns:** `Drawing` containing the projected edge compounds, or `nil` if the shape is null or HLR fails.
- **OCCT:** `HLRBRep_Algo` + `HLRAlgo_Projector` + `HLRBRep_HLRToShape`.
- **Example:**
  ```swift
  let box = Shape.box(width: 100, height: 50, depth: 30)!
  if let view = Drawing.project(box, direction: SIMD3(0, 0, 1)) {
      let edges = view.visibleEdges
  }
  ```

---

### Standard Views

### `Drawing.topView(of:)`

Creates a top (plan) view — looking down the −Z axis.

```swift
public static func topView(of shape: Shape) -> Drawing?
```

Shorthand for `project(shape, direction: SIMD3(0, 0, 1))`.

- **Returns:** `Drawing?`, `nil` on failure.
- **Example:**
  ```swift
  let top = Drawing.topView(of: myShape)
  ```

---

### `Drawing.frontView(of:)`

Creates a front view — looking down the −Y axis.

```swift
public static func frontView(of shape: Shape) -> Drawing?
```

Shorthand for `project(shape, direction: SIMD3(0, 1, 0))`.

- **Returns:** `Drawing?`, `nil` on failure.
- **Example:**
  ```swift
  let front = Drawing.frontView(of: myShape)
  ```

---

### `Drawing.sideView(of:)`

Creates a right side view — looking down the −X axis.

```swift
public static func sideView(of shape: Shape) -> Drawing?
```

Shorthand for `project(shape, direction: SIMD3(1, 0, 0))`.

- **Returns:** `Drawing?`, `nil` on failure.
- **Example:**
  ```swift
  let side = Drawing.sideView(of: myShape)
  ```

---

### `Drawing.isometricView(of:)`

Creates an isometric view — looking from direction (1, 1, 1) / √3.

```swift
public static func isometricView(of shape: Shape) -> Drawing?
```

- **Returns:** `Drawing?`, `nil` on failure.
- **Example:**
  ```swift
  let iso = Drawing.isometricView(of: myShape)
  ```

---

### Fast Polygon-Based Projection (v0.39.0)

### `Drawing.projectFast(_:direction:deflection:)`

Creates a fast polygon-based 2D projection using triangulation HLR.

```swift
public static func projectFast(
    _ shape: Shape,
    direction: SIMD3<Double>,
    deflection: Double = 0.01
) -> Drawing?
```

Uses `BRepMesh_IncrementalMesh` + `HLRBRep_PolyAlgo` — significantly faster than exact HLR but the edges follow the tessellation facets rather than the true curves. Suitable for interactive previews.

- **Parameters:**
  - `shape` — the 3D shape to project.
  - `direction` — view direction vector.
  - `deflection` — triangulation chord deflection (default 0.01); smaller = more accurate, slower.
- **Returns:** `Drawing?`, `nil` on failure.
- **OCCT:** `BRepMesh_IncrementalMesh` + `HLRBRep_PolyAlgo` + `HLRBRep_PolyHLRToShape`.
- **Example:**
  ```swift
  let preview = Drawing.projectFast(myShape, direction: SIMD3(0, 0, 1), deflection: 0.05)
  ```

---

### `Drawing.fastTopView(of:deflection:)`

Creates a fast polygon-based top view.

```swift
public static func fastTopView(of shape: Shape, deflection: Double = 0.01) -> Drawing?
```

Shorthand for `projectFast(shape, direction: SIMD3(0, 0, 1), deflection: deflection)`.

- **Returns:** `Drawing?`, `nil` on failure.
- **Example:**
  ```swift
  let top = Drawing.fastTopView(of: myShape, deflection: 0.02)
  ```

---

### `Drawing.fastIsometricView(of:deflection:)`

Creates a fast polygon-based isometric view.

```swift
public static func fastIsometricView(of shape: Shape, deflection: Double = 0.01) -> Drawing?
```

Shorthand for `projectFast(shape, direction: SIMD3(1,1,1)/√3, deflection: deflection)`.

- **Returns:** `Drawing?`, `nil` on failure.
- **Example:**
  ```swift
  let iso = Drawing.fastIsometricView(of: myShape)
  ```

---

### Edge Access

### `edges(ofType:)`

Returns the projected edges of the given type as a compound `Shape`.

```swift
public func edges(ofType type: EdgeType) -> Shape?
```

- **Parameters:** `type` — `.visible`, `.hidden`, or `.outline`.
- **Returns:** A `Shape` wrapping the compound of matching edges, or `nil` if none are present.
- **OCCT:** `OCCTDrawingGetEdges` — selects the appropriate `HLRBRep_HLRToShape` compounds.
- **Example:**
  ```swift
  if let visible = drawing.edges(ofType: .visible) {
      // visible is a compound Shape of all non-hidden edges
  }
  ```

---

### `visibleEdges`

Shorthand for `edges(ofType: .visible)`.

```swift
public var visibleEdges: Shape? { get }
```

- **Returns:** Compound `Shape` of visible edges, or `nil`.
- **Example:**
  ```swift
  let vis = drawing.visibleEdges
  ```

---

### `hiddenEdges`

Shorthand for `edges(ofType: .hidden)`.

```swift
public var hiddenEdges: Shape? { get }
```

- **Returns:** Compound `Shape` of hidden edges, or `nil`.
- **Example:**
  ```swift
  let hid = drawing.hiddenEdges
  ```

---

### `outlineEdges`

Shorthand for `edges(ofType: .outline)`.

```swift
public var outlineEdges: Shape? { get }
```

- **Returns:** Compound `Shape` of outline/silhouette edges, or `nil`.
- **Example:**
  ```swift
  let outline = drawing.outlineEdges
  ```

---

## DrawingError

Error type for 2D drawing operations.

```swift
public enum DrawingError: Error, LocalizedError {
    case projectionFailed
}
```

### `DrawingError.projectionFailed`

Thrown (or surfaced as a `nil` return) when `OCCTDrawingCreate` cannot construct the HLR projection.

```swift
case projectionFailed
```

- `errorDescription` returns `"Failed to create 2D projection"`.

---

## PaperSize

ISO 5457 paper size enumeration.

```swift
public enum PaperSize: String, Sendable, Hashable, CaseIterable {
    case A0, A1, A2, A3, A4
}
```

### `PaperSize.dimensions`

ISO 5457 trimmed-sheet dimensions in mm for landscape orientation.

```swift
public var dimensions: SIMD2<Double> { get }
```

- A0 → (1189, 841), A1 → (841, 594), A2 → (594, 420), A3 → (420, 297), A4 → (297, 210).
- **Example:**
  ```swift
  let w = PaperSize.A3.dimensions.x  // 420.0
  ```

---

### `PaperSize.size(in:)`

Returns the sheet dimensions for the given orientation.

```swift
public func size(in orientation: Orientation) -> SIMD2<Double>
```

- **Parameters:** `orientation` — `.landscape` or `.portrait`; portrait swaps X and Y.
- **Returns:** Width × Height in mm.
- **Example:**
  ```swift
  let sz = PaperSize.A4.size(in: .portrait)  // (210, 297)
  ```

---

## Orientation

Drawing sheet orientation.

```swift
public enum Orientation: String, Sendable, Hashable {
    case landscape
    case portrait
}
```

---

## ProjectionAngle

ISO 5456-2 first-angle vs. third-angle projection convention.

```swift
public enum ProjectionAngle: String, Sendable, Hashable {
    case first   // ISO / Europe: top view below front view
    case third   // ANSI / USA:  top view above front view
}
```

Used by `Sheet` and rendered by `ProjectionSymbol.render(_:at:into:)`.

---

## TitleBlock

ISO 7200 title block data. Rendered into the bottom-right of the drawable frame by `Sheet.render(into:)`.

```swift
public struct TitleBlock: Sendable, Hashable
```

### `TitleBlock.init(title:drawingNumber:owner:creator:approver:documentType:dateOfIssue:revision:sheetNumber:language:material:weight:scale:)`

```swift
public init(title: String,
            drawingNumber: String? = nil,
            owner: String? = nil,
            creator: String? = nil,
            approver: String? = nil,
            documentType: String? = nil,
            dateOfIssue: String? = nil,
            revision: String? = nil,
            sheetNumber: String? = nil,
            language: String? = nil,
            material: String? = nil,
            weight: String? = nil,
            scale: String? = nil)
```

All fields except `title` are optional. `dateOfIssue` should follow ISO 8601. `scale` overrides the sheet-level scale in the title-block cell.

- **Parameters:** ISO 7200 mandatory and optional fields — see inline comments in source.
- **Example:**
  ```swift
  let tb = TitleBlock(
      title: "Mounting Bracket",
      drawingNumber: "MB-042",
      creator: "J. Smith",
      dateOfIssue: "2026-06-21",
      revision: "B",
      scale: "1:2"
  )
  ```

---

### Stored properties of `TitleBlock`

All stored as `var` so they can be mutated after construction.

| Property | Type | ISO 7200 status |
|---|---|---|
| `title` | `String` | mandatory |
| `drawingNumber` | `String?` | optional |
| `owner` | `String?` | optional |
| `creator` | `String?` | optional |
| `approver` | `String?` | optional |
| `documentType` | `String?` | optional |
| `dateOfIssue` | `String?` | optional |
| `revision` | `String?` | optional |
| `sheetNumber` | `String?` | optional |
| `language` | `String?` | optional |
| `material` | `String?` | optional |
| `weight` | `String?` | optional |
| `scale` | `String?` | optional |

---

## Sheet

ISO 5457/7200 drawing sheet scaffolding. Renders a trimmed outer edge, inner drawable frame, centring marks, title block, and projection-angle symbol.

```swift
public struct Sheet: Sendable, Hashable
```

### `Sheet.init(size:orientation:projection:title:scale:)`

```swift
public init(size: PaperSize,
            orientation: Orientation = .landscape,
            projection: ProjectionAngle = .first,
            title: TitleBlock? = nil,
            scale: String = "1:1")
```

- **Parameters:**
  - `size` — ISO 5457 paper size.
  - `orientation` — landscape (default) or portrait.
  - `projection` — first-angle (ISO/Europe) or third-angle (ANSI/USA) convention.
  - `title` — optional ISO 7200 title block data; pass `nil` to omit the title block.
  - `scale` — drawing scale string displayed in the title block (default `"1:1"`).
- **Example:**
  ```swift
  let sheet = Sheet(size: .A3, orientation: .landscape,
                    projection: .first,
                    title: TitleBlock(title: "Bracket", drawingNumber: "B-001"),
                    scale: "1:2")
  ```

---

### `Sheet.size`

The paper size.

```swift
public var size: PaperSize
```

---

### `Sheet.orientation`

Landscape or portrait orientation.

```swift
public var orientation: Orientation
```

---

### `Sheet.projection`

ISO 5456-2 projection-angle convention.

```swift
public var projection: ProjectionAngle
```

---

### `Sheet.title`

Optional ISO 7200 title block.

```swift
public var title: TitleBlock?
```

---

### `Sheet.scale`

Scale string shown in the title block (e.g. `"1:2"`, `"2:1"`).

```swift
public var scale: String
```

---

### `Sheet.dimensions`

Overall sheet dimensions in mm for the current size and orientation.

```swift
public var dimensions: SIMD2<Double> { get }
```

Delegates to `size.size(in: orientation)`.

- **Example:**
  ```swift
  let sheet = Sheet(size: .A3)
  let w = sheet.dimensions.x  // 420.0
  ```

---

### `Sheet.inset`

ISO 5457 border insets in mm: binding margin on the left, 10 mm on other sides for A0–A4.

```swift
public var inset: (left: Double, right: Double, top: Double, bottom: Double) { get }
```

- **Returns:** Tuple `(left: 20, right: 10, top: 10, bottom: 10)` for all sizes (A0–A4).
- **Example:**
  ```swift
  let ins = Sheet(size: .A3).inset  // (left: 20, right: 10, top: 10, bottom: 10)
  ```

---

### `Sheet.innerFrame`

The inner drawable rectangle corners in sheet coordinates.

```swift
public var innerFrame: (min: SIMD2<Double>, max: SIMD2<Double>) { get }
```

- **Returns:** `min` = `(inset.left, inset.bottom)`, `max` = `(width − inset.right, height − inset.top)`.
- **Example:**
  ```swift
  let frame = Sheet(size: .A3).innerFrame
  // frame.min = (20, 10), frame.max = (410, 287)
  ```

---

### `Sheet.render(into:)`

Renders the sheet border, centring marks, title block, and projection symbol into a `DXFWriter`.

```swift
public func render(into writer: DXFWriter)
```

Writes to layers `"BORDER"`, `"CENTER"`, `"TITLE"`, and `"TEXT"`. Outer sheet edge and inner frame are polylines; centring marks are short lines at midpoints of each frame edge; the title block is a 170 × 55 mm rectangle in the bottom-right with ISO 7200 fields; the projection symbol is rendered by `ProjectionSymbol.render(_:at:into:)` above the title block.

- **Parameters:** `writer` — a `DXFWriter` that accumulates geometry for eventual file output.
- **Note:** Pure-Swift; no OCCT bridge call.
- **Example:**
  ```swift
  let sheet = Sheet(size: .A3, title: TitleBlock(title: "Part A"))
  let writer = DXFWriter()
  sheet.render(into: writer)
  // Now add view geometry into writer, then call writer.write(to:)
  ```

---

## ProjectionSymbol

Namespace for rendering ISO 5456-2 first/third-angle projection symbols into a `DXFWriter`.

```swift
public enum ProjectionSymbol
```

### `ProjectionSymbol.render(_:at:into:)`

Renders a projection-angle symbol at a 2D origin.

```swift
public static func render(_ angle: ProjectionAngle,
                          at origin: SIMD2<Double>,
                          into writer: DXFWriter)
```

The symbol is approximately 30 × 15 mm. First-angle: truncated-cone view on the left, circle on the right. Third-angle: circle on the left, truncated-cone on the right.

- **Parameters:**
  - `angle` — `.first` (ISO) or `.third` (ANSI).
  - `origin` — bottom-left origin of the symbol bounding box in drawing coordinates.
  - `writer` — the `DXFWriter` to emit lines and circles into (layer `"TEXT"`).
- **Note:** Pure-Swift; no OCCT bridge call. Called automatically by `Sheet.render(into:)`.
- **Example:**
  ```swift
  let writer = DXFWriter()
  ProjectionSymbol.render(.first, at: SIMD2(370, 20), into: writer)
  ```

---

## DrawingLineWidth

ISO 128-20 standard line-width values in mm.

```swift
public enum DrawingLineWidth: Double, Sendable, Hashable, CaseIterable {
    case w013 = 0.13
    case w018 = 0.18
    case w025 = 0.25
    case w035 = 0.35
    case w050 = 0.50
    case w070 = 0.70
    case w100 = 1.00
    case w140 = 1.40
    case w200 = 2.00
}
```

Only these values are recognised by ISO-compliant DXF/SVG readers. The geometric series increments by ≈ 1.4× per tier.

### `DrawingLineWidth.thin`

ISO-standard thin weight for general drawing features (0.25 mm).

```swift
public static let thin: DrawingLineWidth = .w025
```

### `DrawingLineWidth.thick`

ISO-standard thick weight — 2× thin (0.50 mm).

```swift
public static let thick: DrawingLineWidth = .w050
```

---

## DrawingLineStyle extension

Extension on `DrawingLineStyle` (defined in `DrawingAnnotation.swift`) adding ISO 128-20 default widths.

### `DrawingLineStyle.defaultWidth`

ISO 128-20 default line width for each style.

```swift
public var defaultWidth: DrawingLineWidth { get }
```

| Style | ISO usage | Default width |
|---|---|---|
| `.solid` | Visible edges, extension lines | `.thin` (0.25 mm) |
| `.dashed` | Hidden edges | `.thin` |
| `.chain` | Centrelines, axes, pitch lines | `.thin` |
| `.phantom` | Alternative / adjacent positions | `.thin` |
| `.dotted` | Bend lines, construction | `.thin` |

- **Example:**
  ```swift
  let w = DrawingLineStyle.solid.defaultWidth  // .w025
  ```

---

### `DrawingLineStyle.boldWidth`

The bold (thick) counterpart for cutting-plane lines and section identifiers.

```swift
public var boldWidth: DrawingLineWidth { .thick }
```

Returns `.thick` (0.50 mm) regardless of style. ISO 128-24 recommends thick lines for cutting-plane annotations.

- **Example:**
  ```swift
  let bold = DrawingLineStyle.chain.boldWidth  // .w050
  ```

---

## DrawingTextHeight

ISO 3098 standard text-height series in mm.

```swift
public enum DrawingTextHeight: Double, Sendable, Hashable, CaseIterable {
    case h25  = 2.5
    case h35  = 3.5
    case h50  = 5.0
    case h70  = 7.0
    case h100 = 10.0
    case h140 = 14.0
    case h200 = 20.0
}
```

Each tier is ≈ 1.4× the previous, matching the ISO geometric series.

### `DrawingTextHeight.recommended(forPaper:)`

Returns the recommended dimension-text height for a given ISO 5457 paper size.

```swift
public static func recommended(forPaper paper: String) -> DrawingTextHeight
```

- **Parameters:** `paper` — paper size string, e.g. `"A3"` (case-insensitive).
- **Returns:** `.h50` for A0/A1; `.h35` for A2, A3, A4, and any unrecognised size.
- **Example:**
  ```swift
  let h = DrawingTextHeight.recommended(forPaper: "A0")  // .h50
  ```

---

### `DrawingTextHeight.snap(_:)`

Snaps an arbitrary height in mm to the nearest ISO 3098 tier.

```swift
public static func snap(_ mm: Double) -> DrawingTextHeight
```

- **Parameters:** `mm` — desired text height in mm.
- **Returns:** The `DrawingTextHeight` case whose `rawValue` is closest to `mm`; falls back to `.h35` if the cases are empty.
- **Example:**
  ```swift
  let h = DrawingTextHeight.snap(4.0)  // .h35 (3.5 is closer than 5.0)
  ```

---

## DrawingArrowStyle

ISO 128-21 arrow-head conventions.

```swift
public enum DrawingArrowStyle: String, Sendable, Hashable, Codable {
    case filledClosed       // solid triangle — ISO default
    case openClosed90       // stroked triangle, 90° included angle
    case openClosed30       // stroked triangle, 30° included angle (narrow)
    case tick               // 45° tick (architectural; not ISO default)
}
```

### `DrawingArrowStyle.length(forLineWidth:)`

Recommended arrow length in mm for a given dimension line width.

```swift
public func length(forLineWidth width: DrawingLineWidth) -> Double
```

Returns `width.rawValue * 6` — approximately 1.5 mm at the standard thin width of 0.25 mm, within the ISO 129 recommendation of 3–5× thin width.

- **Parameters:** `width` — the dimension line's `DrawingLineWidth`.
- **Returns:** Arrow length in mm.
- **Example:**
  ```swift
  let len = DrawingArrowStyle.filledClosed.length(forLineWidth: .thin)  // 0.25 * 6 = 1.5
  ```

---

## DrawingScale

ISO 5455 preferred drawing scales.

```swift
public enum DrawingScale: Sendable, Hashable {
    case one                // 1:1
    case reduction(Int)     // 1:N  (N > 1)
    case enlargement(Int)   // N:1  (N > 1)
    case custom(Double)     // any ratio
}
```

### `DrawingScale.factor`

Drawing-to-model scale factor.

```swift
public var factor: Double { get }
```

- `.one` → 1.0; `.reduction(2)` → 0.5; `.enlargement(5)` → 5.0; `.custom(f)` → `f`.
- **Example:**
  ```swift
  let f = DrawingScale.reduction(2).factor  // 0.5
  ```

---

### `DrawingScale.label`

Human-readable scale label.

```swift
public var label: String { get }
```

- `.one` → `"1:1"`, `.reduction(5)` → `"1:5"`, `.enlargement(2)` → `"2:1"`, `.custom(0.333)` → `"0.333:1"`.
- **Example:**
  ```swift
  let s = DrawingScale.enlargement(10).label  // "10:1"
  ```

---

### `DrawingScale.preferred`

ISO 5455 preferred scale values.

```swift
public static var preferred: [DrawingScale] { get }
```

Returns the 15 ISO-standard scales from 50:1 down to 1:1000, plus 1:1.

- **Example:**
  ```swift
  for scale in DrawingScale.preferred {
      print(scale.label)
  }
  ```

---

## DisplayDrawer

Display attribute controller wrapping OCCT's `Prs3d_Drawer`. Controls tessellation quality and which edge types are emitted by a Metal renderer.

```swift
public final class DisplayDrawer: @unchecked Sendable
```

Obtain by calling `DisplayDrawer()`. The underlying `Prs3d_Drawer` handle is created in `OCCTDrawerCreate` and destroyed in `deinit` via `OCCTDrawerDestroy`.

### `DisplayDrawer.DeflectionType`

```swift
public enum DeflectionType: Int32, Sendable {
    case relative = 0
    case absolute = 1
}
```

- `.relative` — chordal deviation is expressed as a fraction of the bounding-box diagonal.
- `.absolute` — chordal deviation is a fixed distance in model units.

---

### `DisplayDrawer.init()`

Creates a `DisplayDrawer` with OCCT default settings.

```swift
public init()
```

- **OCCT:** `Prs3d_Drawer` default constructor via `OCCTDrawerCreate`.
- **Example:**
  ```swift
  let drawer = DisplayDrawer()
  drawer.deviationCoefficient = 0.0005  // finer tessellation
  ```

---

### Tessellation Quality

### `deviationCoefficient`

Chordal deviation coefficient relative to the bounding-box diagonal.

```swift
public var deviationCoefficient: Double { get set }
```

Lower values produce finer tessellation. Default ≈ 0.001. Only applies when `deflectionType` is `.relative`.

- **OCCT:** `Prs3d_Drawer::DeviationCoefficient` / `SetDeviationCoefficient`.
- **Example:**
  ```swift
  drawer.deviationCoefficient = 0.0002  // high-quality render
  ```

---

### `deviationAngle`

Angular deviation in radians controlling curved surface approximation.

```swift
public var deviationAngle: Double { get set }
```

Default ≈ 0.35 radians (20°). Smaller angles produce smoother curved surfaces but more triangles.

- **OCCT:** `Prs3d_Drawer::DeviationAngle` / `SetDeviationAngle`.
- **Example:**
  ```swift
  drawer.deviationAngle = 0.1  // smoother curves (~5.7°)
  ```

---

### `maximalChordialDeviation`

Maximum chordal deviation as an absolute distance in model units.

```swift
public var maximalChordialDeviation: Double { get set }
```

The maximum allowed distance between a tessellation facet and the true surface. Only applies when `deflectionType` is `.absolute`.

- **OCCT:** `Prs3d_Drawer::MaximalChordialDeviation` / `SetMaximalChordialDeviation`.
- **Example:**
  ```swift
  drawer.deflectionType = .absolute
  drawer.maximalChordialDeviation = 0.05  // 0.05 mm max chord error
  ```

---

### `deflectionType`

Whether deflection is measured relative to the bounding box or as an absolute distance.

```swift
public var deflectionType: DeflectionType { get set }
```

- **OCCT:** `Prs3d_Drawer::TypeOfDeflection` / `SetTypeOfDeflection` (mapped to `Aspect_TypeOfDeflection`).
- **Example:**
  ```swift
  drawer.deflectionType = .absolute
  ```

---

### `autoTriangulation`

Whether automatic triangulation is performed before display. Default `true`.

```swift
public var autoTriangulation: Bool { get set }
```

When `true`, OCCT will automatically triangulate shapes that lack a mesh before rendering. Set to `false` if you manage triangulation explicitly.

- **OCCT:** `Prs3d_Drawer::IsAutoTriangulation` / `SetAutoTriangulation`.
- **Example:**
  ```swift
  drawer.autoTriangulation = false
  ```

---

### Isolines and Discretisation

### `isoOnTriangulation`

Whether iso-parameter lines are drawn on triangulated surfaces.

```swift
public var isoOnTriangulation: Bool { get set }
```

- **OCCT:** `Prs3d_Drawer::IsoOnTriangulation` / `SetIsoOnTriangulation`.
- **Example:**
  ```swift
  drawer.isoOnTriangulation = true
  ```

---

### `discretisation`

Number of discretisation points for curve approximation. Default 30.

```swift
public var discretisation: Int32 { get set }
```

Higher values produce smoother curves in wireframe rendering at the cost of more geometry.

- **OCCT:** `Prs3d_Drawer::Discretisation` / `SetDiscretisation`.
- **Example:**
  ```swift
  drawer.discretisation = 60  // smoother wireframe curves
  ```

---

### Edge Display

### `faceBoundaryDraw`

Whether face boundary edges are included in wireframe rendering. Default `false`.

```swift
public var faceBoundaryDraw: Bool { get set }
```

When `true`, edges where two faces meet are drawn in addition to true wire edges.

- **OCCT:** `Prs3d_Drawer::FaceBoundaryDraw` / `SetFaceBoundaryDraw`.
- **Example:**
  ```swift
  drawer.faceBoundaryDraw = true  // show all face-boundary seams
  ```

---

### `wireDraw`

Whether wireframe edges are drawn. Default `true`.

```swift
public var wireDraw: Bool { get set }
```

Set to `false` for shaded-only rendering without any edge lines.

- **OCCT:** `Prs3d_Drawer::WireDraw` / `SetWireDraw`.
- **Example:**
  ```swift
  drawer.wireDraw = false  // shaded only, no wireframe overlay
  ```
