---
title: Drawing Automation & Helpers
parent: API Reference
---

# Drawing Automation & Helpers

This page covers the helper types and extension methods that automate annotation production on a `Drawing`: multi-view sheet composition (`TransformedDrawing`), auto-centreline and auto-centermark placement, ISO thread callouts, ISO surface-finish and GD&T symbols, heuristic auto-dimensioning, and 2D hatch-pattern generation. See `Drawing.md` (forthcoming) for the core `Drawing` type and its base annotation primitives.

## Topics

- [TransformedDrawing](#transformeddrawing) · [Drawing (sheet composition)](#drawing-sheet-composition) · [Drawing (auto centrelines)](#drawing-auto-centrelines) · [Drawing (auto centermarks)](#drawing-auto-centermarks) · [DrawingAnnotation (thread)](#drawingannotation-thread) · [Drawing (thread convenience)](#drawing-thread-convenience) · [DXFWriter (thread)](#dxfwriter-thread) · [SurfaceFinishSymbol](#surfacefinishsymbol) · [GDTSymbol](#gdtsymbol) · [DrawingAnnotation (symbols)](#drawingannotation-symbols) · [Drawing (detail view)](#drawing-detail-view) · [DrawingAnnotation (break line)](#drawingannotation-break-line) · [Drawing (auto dimensions)](#drawing-auto-dimensions) · [HatchSegment](#hatchsegment) · [HatchPattern](#hatchpattern)

---

## TransformedDrawing

`TransformedDrawing` wraps a `Drawing` together with a uniform scale and a 2D translation offset, enabling multiple views to be composed onto the same DXF sheet. Introduced in v0.144 (issue #75).

### `TransformedDrawing.source`

The underlying `Drawing` being transformed.

```swift
public let source: Drawing
```

- **Example:**
  ```swift
  let td = TransformedDrawing(source: frontView, translate: SIMD2(100, 0), scale: 2.0)
  print(td.source === frontView)  // true
  ```

---

### `TransformedDrawing.translate`

The 2D translation applied after scaling.

```swift
public let translate: SIMD2<Double>
```

- **Example:**
  ```swift
  let td = TransformedDrawing(source: frontView, translate: SIMD2(50, 0), scale: 1.0)
  print(td.translate)  // SIMD2<Double>(50.0, 0.0)
  ```

---

### `TransformedDrawing.scale`

The uniform scale factor applied to all geometry and annotation coordinates.

```swift
public let scale: Double
```

- **Example:**
  ```swift
  let td = frontView.transformed(translate: .zero, scale: 0.5)
  print(td.scale)  // 0.5
  ```

---

### `TransformedDrawing.init(source:translate:scale:)`

Initialises a `TransformedDrawing` directly.

```swift
public init(source: Drawing, translate: SIMD2<Double> = .zero, scale: Double = 1.0)
```

- **Parameters:**
  - `source` — the `Drawing` to wrap.
  - `translate` — 2D offset applied after scaling (default `.zero`).
  - `scale` — uniform scale factor (default `1.0`).
- **Example:**
  ```swift
  let placed = TransformedDrawing(source: sideView,
                                   translate: SIMD2(200, 0),
                                   scale: 1.0)
  ```

---

### `TransformedDrawing.apply(_:)`

Applies the transform to a single 2D point.

```swift
public func apply(_ p: SIMD2<Double>) -> SIMD2<Double>
```

Computes `scale * p + translate`. Pure-Swift; used internally by `DXFWriter.collectFromDrawing`.

- **Parameters:** `p` — input 2D point in drawing-local coordinates.
- **Returns:** Transformed point in sheet coordinates.
- **Example:**
  ```swift
  let td = TransformedDrawing(source: view, translate: SIMD2(10, 5), scale: 2.0)
  let sheet = td.apply(SIMD2(3, 4))  // SIMD2(16.0, 13.0)
  ```

---

## Drawing (sheet composition)

These methods are declared as extensions on `Drawing` in `DrawingComposition.swift`.

### `Drawing.transformed(translate:scale:)`

Returns a `TransformedDrawing` wrapping this drawing with a uniform scale and 2D translation.

```swift
public func transformed(translate: SIMD2<Double>, scale: Double = 1.0) -> TransformedDrawing
```

Sugar for `TransformedDrawing(source: self, translate: translate, scale: scale)`. Pass the result to `DXFWriter.collectFromDrawing` to emit all edges and annotations with the transform applied.

- **Parameters:**
  - `translate` — 2D offset in sheet coordinates.
  - `scale` — uniform scale factor (default `1.0`).
- **Returns:** A `TransformedDrawing` ready to pass to `DXFWriter.collectFromDrawing`.
- **Example:**
  ```swift
  for (view, placement) in layout {
      writer.collectFromDrawing(view.transformed(translate: placement.offset,
                                                  scale: placement.scale))
  }
  ```

---

### `Drawing.bounds(deflection:includeAnnotations:)`

Computes the 2D axis-aligned bounding box of all visible, hidden, and outline edges in the drawing.

```swift
public func bounds(deflection: Double = 0.1,
                   includeAnnotations: Bool = true) -> (min: SIMD2<Double>, max: SIMD2<Double>)?
```

Iterates all edge polylines (tessellated at `deflection`) and, when `includeAnnotations` is true, also expands the box to include the key points of all dimensions and annotations.

- **Parameters:**
  - `deflection` — tessellation deflection for edge polyline sampling (default `0.1`).
  - `includeAnnotations` — when `true`, annotation extents are included in the bounding box (default `true`).
- **Returns:** Tuple of min and max 2D corners, or `nil` if the drawing contains no geometry.
- **Example:**
  ```swift
  if let bb = frontView.bounds() {
      let width  = bb.max.x - bb.min.x
      let height = bb.max.y - bb.min.y
      print("view extents: \(width) × \(height)")
  }
  ```

---

## Drawing (auto centrelines)

Extensions on `Drawing` in `DrawingAutoCenterlines.swift` that project a shape's axes of revolution into the view plane as centreline annotations.

### `Drawing.AutoCentrelineResult`

Result returned by `addAutoCentrelines(from:viewDirection:overshoot:tolerance:bounds:)`.

```swift
public struct AutoCentrelineResult: Sendable {
    public let added: [DrawingAnnotation]
    public let skipped: [ShapeAxis]
}
```

- `added` — the `.centreline` annotations appended to the drawing.
- `skipped` — axes that projected to a point in the view (i.e. the axis is parallel to the view direction) and were therefore omitted.

---

### `Drawing.addAutoCentrelines(from:viewDirection:overshoot:tolerance:bounds:)`

Projects the shape's revolution axes into this drawing's view plane and adds them as `.chain` centreline annotations.

```swift
@discardableResult
public func addAutoCentrelines(from shape: Shape,
                               viewDirection: SIMD3<Double>,
                               overshoot: Double = 5,
                               tolerance: Double = 1e-6,
                               bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil) -> AutoCentrelineResult
```

Calls `Shape.revolutionAxes(tolerance:)` on `shape`, then projects and clips each axis to the drawing's 2D bounding box, extending each end by `overshoot`. Axes whose direction is parallel to the view direction are recorded in `AutoCentrelineResult.skipped`.

- **Parameters:**
  - `shape` — the source 3D shape (typically the one this drawing was projected from).
  - `viewDirection` — the projection direction used when creating the drawing; assumed unit-length.
  - `overshoot` — extra length (drawing units) added past the bounding box at both ends of each projected axis (default `5`).
  - `tolerance` — axis-deduplication tolerance passed to `Shape.revolutionAxes` (default `1e-6`).
  - `bounds` — optional 2D clipping rectangle; when `nil` falls back to `±1000` centred at the origin. Pass `Drawing.bounds()` for best accuracy.
- **Returns:** `AutoCentrelineResult` listing added annotations and skipped axes.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 10, height: 50)!
  let drawing = Drawing.project(cyl, direction: SIMD3(0, 1, 0))!
  let bb = drawing.bounds()
  let result = drawing.addAutoCentrelines(from: cyl,
                                           viewDirection: SIMD3(0, 1, 0),
                                           overshoot: 5,
                                           bounds: bb)
  print("\(result.added.count) centrelines added")
  ```

---

## Drawing (auto centermarks)

Extensions on `Drawing` in `DrawingAutoCenterlines.swift` that add centermark crosses at the projected centres of visible circular edges.

### `Drawing.AutoCentermarkResult`

Result returned by `addAutoCentermarks(from:viewDirection:extent:minRadius:bounds:)`.

```swift
public struct AutoCentermarkResult: Sendable {
    public let added: [DrawingAnnotation]
    public let skipped: [Edge]
}
```

- `added` — the `.centermark` annotations appended to the drawing.
- `skipped` — circular edges that project edge-on (circle plane parallel to view direction) and were therefore omitted.

---

### `Drawing.addAutoCentermarks(from:viewDirection:extent:minRadius:bounds:)`

Walks the shape's circular edges, projects each circle's centre into the view plane, and adds a `.centermark` annotation for each circle visible face-on.

```swift
@discardableResult
public func addAutoCentermarks(from shape: Shape,
                                viewDirection: SIMD3<Double>,
                                extent: Double = 8,
                                minRadius: Double = 0,
                                bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil) -> AutoCentermarkResult
```

A circle is considered edge-on (and is skipped) when `abs(dot(circleNormal, viewDirection)) < 0.1`. This complements `addAutoCentrelines`, which handles revolution axes.

- **Parameters:**
  - `shape` — the 3D shape whose circular edges are inspected.
  - `viewDirection` — the projection direction; assumed unit-length.
  - `extent` — full arm length of the centermark cross in drawing units (default `8`).
  - `minRadius` — circles with radius smaller than this value are skipped (default `0`).
  - `bounds` — optional 2D clipping rectangle; circles whose projected centre falls outside are skipped.
- **Returns:** `AutoCentermarkResult` listing added annotations and skipped edges.
- **Example:**
  ```swift
  let part = Shape.cylinder(radius: 5, height: 20)!
  let drw  = Drawing.project(part, direction: SIMD3(0, 0, 1))!
  let result = drw.addAutoCentermarks(from: part,
                                       viewDirection: SIMD3(0, 0, 1),
                                       extent: 6,
                                       minRadius: 1.0)
  print("\(result.added.count) centermarks added")
  ```

---

## DrawingAnnotation (thread)

Static factory methods on `DrawingAnnotation` in `DrawingThreadAnnotation.swift` for ISO 6410 cosmetic thread representations. These produce annotation primitives; add them to a `Drawing` via `Drawing.addCosmeticThreadSide` or insert them directly into `annotationStore`.

### `DrawingAnnotation.ArcSegment`

A 2D arc defined by centre, radius, start angle, and end angle (all in radians).

```swift
public struct ArcSegment: Sendable, Hashable {
    public let centre: SIMD2<Double>
    public let radius: Double
    public let startAngle: Double    // radians
    public let endAngle: Double      // radians
}
```

Returned by `cosmeticThreadEndView(centre:majorDiameter:pitch:)`.

---

### `DrawingAnnotation.cosmeticThreadSideView(axisStart:axisEnd:majorDiameter:pitch:callout:)`

Produces an ISO 6410 cosmetic thread side-view pattern as an array of `DrawingAnnotation` values.

```swift
public static func cosmeticThreadSideView(
    axisStart: SIMD2<Double>,
    axisEnd: SIMD2<Double>,
    majorDiameter: Double,
    pitch: Double,
    callout: String? = nil
) -> [DrawingAnnotation]
```

Generates two parallel solid centrelines at the minor diameter (computed as `max(majorDiameter - 1.0825 × pitch, majorDiameter × 0.8)`) on each side of the thread axis, plus an optional text label positioned at the thread midline. Returns an empty array if `axisStart == axisEnd`.

- **Parameters:**
  - `axisStart` — projected 2D start of the thread axis.
  - `axisEnd` — projected 2D end of the thread axis.
  - `majorDiameter` — nominal (major) thread diameter.
  - `pitch` — thread pitch; used to compute minor diameter per ISO 68.
  - `callout` — optional thread callout string (e.g. `"M10×1.5"`); placed with a leader 10 units past the minor radius.
- **Returns:** Array of `DrawingAnnotation` values (`.centreline` lines, and optionally `.textLabel`).
- **Example:**
  ```swift
  let anns = DrawingAnnotation.cosmeticThreadSideView(
      axisStart: SIMD2(0, 0),
      axisEnd:   SIMD2(20, 0),
      majorDiameter: 10,
      pitch: 1.5,
      callout: "M10×1.5")
  // anns contains 2 centreline lines + 1 textLabel
  ```

---

### `DrawingAnnotation.cosmeticThreadEndView(centre:majorDiameter:pitch:)`

Produces an ISO 6410 cosmetic thread end-view pattern as three `ArcSegment` values.

```swift
public static func cosmeticThreadEndView(
    centre: SIMD2<Double>,
    majorDiameter: Double,
    pitch: Double
) -> [ArcSegment]
```

Returns a 3/4 broken arc at the minor diameter: three arcs covering 0–90°, 90–180°, and 180–315°, leaving a 45° gap in the last quadrant per the ISO convention.

- **Parameters:**
  - `centre` — projected 2D centre of the threaded hole or shaft.
  - `majorDiameter` — nominal (major) thread diameter.
  - `pitch` — thread pitch; used to compute minor diameter.
- **Returns:** Array of three `ArcSegment` values ready to pass to `DXFWriter.addArc`.
- **Example:**
  ```swift
  let arcs = DrawingAnnotation.cosmeticThreadEndView(
      centre: SIMD2(30, 30),
      majorDiameter: 10,
      pitch: 1.5)
  for arc in arcs {
      writer.addArc(centre: arc.centre, radius: arc.radius,
                    startAngleDeg: arc.startAngle * 180 / .pi,
                    endAngleDeg:   arc.endAngle   * 180 / .pi,
                    layer: "CENTER")
  }
  ```

---

## Drawing (thread convenience)

### `Drawing.addCosmeticThreadSide(axisStart:axisEnd:majorDiameter:pitch:callout:)`

Adds an ISO 6410 cosmetic thread side-view pattern to this drawing and returns the appended annotations.

```swift
@discardableResult
public func addCosmeticThreadSide(
    axisStart: SIMD2<Double>,
    axisEnd: SIMD2<Double>,
    majorDiameter: Double,
    pitch: Double,
    callout: String? = nil
) -> [DrawingAnnotation]
```

Delegates to `DrawingAnnotation.cosmeticThreadSideView` and appends each annotation to `annotationStore`.

- **Parameters:** Same as `DrawingAnnotation.cosmeticThreadSideView(axisStart:axisEnd:majorDiameter:pitch:callout:)`.
- **Returns:** The annotations that were appended.
- **Example:**
  ```swift
  drawing.addCosmeticThreadSide(
      axisStart: SIMD2(0, 0),
      axisEnd:   SIMD2(30, 0),
      majorDiameter: 12,
      pitch: 1.75,
      callout: "M12×1.75")
  ```

---

## DXFWriter (thread)

### `DXFWriter.addCosmeticThreadEndView(centre:majorDiameter:pitch:)`

Writes an ISO 6410 cosmetic thread end-view 3/4-arc set directly onto the DXF writer on the `CENTER` layer.

```swift
public func addCosmeticThreadEndView(centre: SIMD2<Double>,
                                      majorDiameter: Double,
                                      pitch: Double)
```

Delegates to `DrawingAnnotation.cosmeticThreadEndView` and writes each arc via `DXFWriter.addArc`.

- **Parameters:**
  - `centre` — 2D centre of the threaded hole or shaft in drawing coordinates.
  - `majorDiameter` — nominal (major) thread diameter.
  - `pitch` — thread pitch.
- **Example:**
  ```swift
  writer.addCosmeticThreadEndView(centre: SIMD2(50, 50),
                                   majorDiameter: 10,
                                   pitch: 1.5)
  ```

---

## SurfaceFinishSymbol

ISO 1302 surface-texture symbol type.

```swift
public enum SurfaceFinishSymbol: String, Sendable, Hashable, Codable {
    case any
    case machiningRequired
    case machiningProhibited
}
```

- `any` — any manufacturing method permitted; renders as a basic check-mark V.
- `machiningRequired` — machining required; V with a horizontal bar across the top.
- `machiningProhibited` — machining prohibited; V with a circle in the apex.

---

## GDTSymbol

ISO 1101 geometric characteristic symbol, matching `Document.GeomToleranceType` raw values for round-tripping XDE data into drawings.

```swift
public enum GDTSymbol: String, Sendable, Hashable, Codable {
    case straightness, flatness, circularity, cylindricity
    case profileOfLine, profileOfSurface
    case perpendicularity, parallelism, angularity
    case position, concentricity, symmetry, coaxiality
    case circularRunout, totalRunout
}
```

### `GDTSymbol.glyph`

A Unicode glyph or short textual representation for use in DXF plain-text entities.

```swift
public var glyph: String { get }
```

Full Unicode glyphs (e.g. `"⊥"`, `"⌖"`) render correctly in AutoCAD with a TrueType font. The textual fallbacks (`"STR"`, `"FLT"`, `"O"`) are always safe.

- **Example:**
  ```swift
  let sym = GDTSymbol.perpendicularity
  print(sym.glyph)  // "⊥"
  ```

---

## DrawingAnnotation (symbols)

Static factory methods on `DrawingAnnotation` in `DrawingSymbols.swift` for ISO standard engineering-drawing symbols.

### `DrawingAnnotation.surfaceFinish(at:leaderTo:ra:symbol:method:)`

Produces an ISO 1302 surface finish annotation as an array of `DrawingAnnotation` values.

```swift
public static func surfaceFinish(
    at position: SIMD2<Double>,
    leaderTo target: SIMD2<Double>,
    ra: Double,
    symbol: SurfaceFinishSymbol = .machiningRequired,
    method: String? = nil
) -> [DrawingAnnotation]
```

Generates the check-mark geometry (two lines at `position`), the appropriate symbol modifier (horizontal bar or apex circle), an Ra text label, an optional production-method text, and a leader line to `target`. The symbol is 8×10 drawing-units with the apex at `position`.

- **Parameters:**
  - `position` — apex position of the check-mark symbol.
  - `target` — feature point the leader line points to.
  - `ra` — roughness value (Ra); formatted as `"Ra X.XX"`.
  - `symbol` — ISO 1302 symbol type (default `.machiningRequired`).
  - `method` — optional production method text placed below the Ra label.
- **Returns:** Array of `DrawingAnnotation` values (`.centreline` lines and `.textLabel` entries).
- **Example:**
  ```swift
  let anns = DrawingAnnotation.surfaceFinish(
      at: SIMD2(40, 10),
      leaderTo: SIMD2(40, 30),
      ra: 1.6,
      symbol: .machiningRequired,
      method: "Mill")
  for a in anns { drawing.annotationStore.appendAnnotation(a) }
  ```

---

### `DrawingAnnotation.featureControlFrame(at:symbol:tolerance:datums:leaderTo:)`

Produces an ISO 1101 feature control frame — the classic rectangular box divided into symbol, tolerance, and datum-reference cells.

```swift
public static func featureControlFrame(
    at position: SIMD2<Double>,
    symbol: GDTSymbol,
    tolerance: String,
    datums: [String] = [],
    leaderTo target: SIMD2<Double>? = nil
) -> [DrawingAnnotation]
```

Generates the outer rectangle, vertical cell dividers, the symbol glyph, tolerance text, one cell per datum, and an optional leader from the left edge of the frame to `target`.

- **Parameters:**
  - `position` — bottom-left corner of the frame.
  - `symbol` — GD&T characteristic symbol.
  - `tolerance` — tolerance string, e.g. `"0.1"` or `"0.1 M"` for MMC modifier.
  - `datums` — ordered datum reference letters, e.g. `["A", "B", "C"]` (default empty).
  - `leaderTo` — optional feature point for the leader line (default `nil`).
- **Returns:** Array of `DrawingAnnotation` values.
- **Example:**
  ```swift
  let frame = DrawingAnnotation.featureControlFrame(
      at: SIMD2(10, 60),
      symbol: .position,
      tolerance: "0.1 M",
      datums: ["A", "B", "C"],
      leaderTo: SIMD2(10, 50))
  for a in frame { drawing.annotationStore.appendAnnotation(a) }
  ```

---

### `DrawingAnnotation.datumFeature(label:at:pointingTo:)`

Produces an ISO 1101 datum feature symbol — a letter in a square box with a filled-triangle pointer.

```swift
public static func datumFeature(
    label: String,
    at position: SIMD2<Double>,
    pointingTo target: SIMD2<Double>
) -> [DrawingAnnotation]
```

Generates a 8×8 box with the label text centred, then a filled triangle (rendered as three lines) pointing from the box edge toward `target`, connected by a leader line.

- **Parameters:**
  - `label` — single-letter datum identifier, e.g. `"A"`.
  - `position` — bottom-left corner of the datum box.
  - `target` — the feature surface point the triangle points to.
- **Returns:** Array of `DrawingAnnotation` values.
- **Example:**
  ```swift
  let datum = DrawingAnnotation.datumFeature(
      label: "A",
      at: SIMD2(5, 70),
      pointingTo: SIMD2(5, 55))
  for a in datum { drawing.annotationStore.appendAnnotation(a) }
  ```

---

## Drawing (detail view)

### `Drawing.detailView(at:scale:)`

Composes a magnified detail view of this drawing, placed at `placement` on the sheet.

```swift
public func detailView(at placement: SIMD2<Double>, scale: Double) -> TransformedDrawing
```

Returns a `TransformedDrawing` with the given placement and scale. Pass the result to `DXFWriter.collectFromDrawing`. The caller is responsible for adding a bubble label on the parent view and a scale label on the detail placement.

- **Parameters:**
  - `placement` — 2D position of the detail view's origin on the sheet.
  - `scale` — magnification factor (e.g. `2.0` for 2:1).
- **Returns:** A `TransformedDrawing` ready for `DXFWriter.collectFromDrawing`.
- **Example:**
  ```swift
  let detail = mainView.detailView(at: SIMD2(300, 0), scale: 4.0)
  writer.collectFromDrawing(detail)
  // Add reference bubble and scale callout manually:
  mainView.annotationStore.appendAnnotation(
      .textLabel(.init(position: SIMD2(80, 60), text: "DETAIL A", height: 3.5)))
  ```

---

## DrawingAnnotation (break line)

### `DrawingAnnotation.breakLine(from:to:amplitude:)`

Produces an ISO 128-30 break line marking a compressed (foreshortened) length.

```swift
public static func breakLine(from: SIMD2<Double>, to: SIMD2<Double>,
                              amplitude: Double = 2.0) -> [DrawingAnnotation]
```

Renders as five line segments forming a zigzag at the midpoint of `from`–`to`: straight run to the midpoint, then a Z-shaped kink of the given amplitude, then a straight run to the end.

- **Parameters:**
  - `from` — start point of the break line.
  - `to` — end point of the break line.
  - `amplitude` — lateral displacement of the zigzag peak (default `2.0`).
- **Returns:** Five `.centreline` annotations forming the break-line geometry.
- **Example:**
  ```swift
  let bl = DrawingAnnotation.breakLine(from: SIMD2(0, 50),
                                        to:   SIMD2(100, 50),
                                        amplitude: 3.0)
  for a in bl { drawing.annotationStore.appendAnnotation(a) }
  ```

---

## Drawing (auto dimensions)

Extension on `Drawing` in `DrawingAutoDimensions.swift` for heuristic dimension placement.

### `Drawing.AutoDimensionResult`

Result returned by `addAutoDimensions(from:viewDirection:minRadius:dimensionOffset:bounds:)`.

```swift
public struct AutoDimensionResult: Sendable {
    public let added: [DrawingDimension]
    public let skipped: [String]
}
```

- `added` — the `DrawingDimension` values appended to the drawing.
- `skipped` — human-readable reasons for features that were not dimensioned; useful for debugging missing hole dimensions.

---

### `Drawing.addAutoDimensions(from:viewDirection:minRadius:dimensionOffset:bounds:)`

Heuristically adds overall width and height dimensions plus a diameter dimension on every visible circular edge.

```swift
@discardableResult
public func addAutoDimensions(from shape: Shape,
                               viewDirection: SIMD3<Double>,
                               minRadius: Double = 0.1,
                               dimensionOffset: Double = 10,
                               bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil) -> AutoDimensionResult
```

Projects all eight corners of the shape's 3D bounding box into the view plane to derive overall X and Y extents, then places `addLinearDimension` calls for each non-zero extent. Then iterates circular edges: skips edge-on circles (`abs(dot(circleNormal, viewDirection)) < 0.1`), skips circles with radius below `minRadius`, and places `addDiameterDimension` for each remaining circle.

- **Parameters:**
  - `shape` — the 3D source shape.
  - `viewDirection` — the projection direction; assumed unit-length.
  - `minRadius` — minimum circle radius to dimension (default `0.1`).
  - `dimensionOffset` — distance in drawing units between the view boundary and the dimension line for overall extents (default `10`).
  - `bounds` — optional 2D clipping rectangle; circles outside are skipped.
- **Returns:** `AutoDimensionResult` with all added dimensions and skip reasons.
- **Example:**
  ```swift
  let part = Shape.cylinder(radius: 15, height: 40)!
  let drw  = Drawing.project(part, direction: SIMD3(0, 1, 0))!
  let result = drw.addAutoDimensions(from: part,
                                      viewDirection: SIMD3(0, 1, 0),
                                      minRadius: 1.0,
                                      dimensionOffset: 12)
  print("\(result.added.count) dimensions added, skipped: \(result.skipped)")
  ```

---

## HatchSegment

A single hatch line segment in a 2D fill pattern.

```swift
public struct HatchSegment: Sendable {
    public let start: SIMD2<Double>
    public let end: SIMD2<Double>
}
```

- `start` — start point of the hatch line segment.
- `end` — end point of the hatch line segment.

---

## HatchPattern

Caseless enum with a single static factory that generates 2D hatch fill segments within a polygon boundary.

### `HatchPattern.generate(boundary:direction:spacing:offset:maxSegments:)`

Generates hatch line segments within a 2D polygon boundary.

```swift
public static func generate(
    boundary: [SIMD2<Double>],
    direction: SIMD2<Double>,
    spacing: Double,
    offset: Double = 0,
    maxSegments: Int = 10000
) -> [HatchSegment]
```

Clips an infinite family of parallel lines at the given `spacing` against the boundary polygon using `Hatch_Hatcher`. Returns an empty array if `boundary.count < 3`, `spacing <= 0`, or `maxSegments <= 0`.

- **Parameters:**
  - `boundary` — ordered polygon vertices defining the closed fill region.
  - `direction` — direction of the hatch lines (need not be unit-length).
  - `spacing` — perpendicular distance between consecutive hatch lines.
  - `offset` — offset of the first hatch line from the origin along the perpendicular axis (default `0`).
  - `maxSegments` — maximum number of output segments; acts as a safety cap (default `10000`).
- **Returns:** Array of `HatchSegment` values clipped inside `boundary`.
- **OCCT:** `Hatch_Hatcher::AddLine` + `Hatch_Hatcher::Trim` — adds one directed line per spacing interval, then trims against each boundary edge.
- **Example:**
  ```swift
  // Cross-hatch a rectangle at 45° with 2mm spacing
  let boundary: [SIMD2<Double>] = [
      SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(0, 5)
  ]
  let segments = HatchPattern.generate(
      boundary: boundary,
      direction: SIMD2(1, 1),
      spacing: 2.0)
  for seg in segments {
      writer.addLine(from: seg.start, to: seg.end, layer: "HATCH")
  }
  ```
- **Note:** The `maxSegments` cap silently truncates dense fills. Increase it for large areas or fine spacing; decrease it to bound output size.
