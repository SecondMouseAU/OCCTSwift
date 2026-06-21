---
title: Vector & Raster Export
parent: API Reference
---

# Vector & Raster Export

`PDFExporter`, `SVGExporter`, `DXFExporter`, and `PixMap` round out the 2D drawing pipeline:
the first three are pure-Swift vector writers that complement the 3D [`Exporter`](Exporter.md)
(STL/STEP/IGES/BREP/OBJ/PLY/GLTF), while `PixMap` wraps OCCT's `Image_AlienPixMap` for
pixel-level raster image I/O and manipulation.

## Topics

- [PDFError](#pdferror) · [Exporter — PDF](#exporter--pdf) · [PDFWriter](#pdfwriter)
- [SVGError](#svgerror) · [Exporter — SVG](#exporter--svg) · [SVGWriter](#svgwriter)
- [DXFError](#dxferror) · [Exporter — DXF](#exporter--dxf) · [DXFWriter](#dxfwriter)
- [PixMap.Format](#pixmapformat) · [PixMap](#pixmap)

---

## PDFError

Error type thrown by `PDFWriter.write(to:)` and `Exporter.writePDF` variants.

```swift
public enum PDFError: Error, LocalizedError {
    case writeFailed(String)
    case drawingEmpty
}
```

- `writeFailed(String)` — `Data.write(to:)` failed; the associated string is the underlying
  error description.
- `drawingEmpty` — the `PDFWriter` had no staged entities when `write(to:)` was called.

---

## Exporter — PDF

Two static methods on `Exporter` (defined as an extension in `PDFExporter.swift`).

### `Exporter.pdfA4Landscape`

A4 landscape page size in PDF points (297 × 210 mm).

```swift
public static let pdfA4Landscape = SIMD2<Double>(841, 595)
```

Pass directly as the `pageSize` argument to `Exporter.writePDF(drawing:to:pageSize:deflection:)`.

- **Note:** Pure-Swift constant — no OCCT mapping.

---

### `Exporter.pdfA3Landscape`

A3 landscape page size in PDF points (420 × 297 mm).

```swift
public static let pdfA3Landscape = SIMD2<Double>(1191, 842)
```

- **Note:** Pure-Swift constant — no OCCT mapping.

---

### `Exporter.writePDF(drawing:to:pageSize:deflection:)`

Project a `Drawing`'s edges and annotations to a single-page PDF 1.4 file.

```swift
public static func writePDF(
    drawing: Drawing,
    to url: URL,
    pageSize: SIMD2<Double> = SIMD2(841, 595),
    deflection: Double = 0.1
) throws
```

Creates a `PDFWriter` internally, calls `collectFromDrawing`, and writes. The default `pageSize`
is A4 landscape (841 × 595 pts). Content is scaled via a mm→pts CTM so geometry stays in
drawing-unit millimetres throughout.

- **Parameters:** `drawing` — HLR drawing to export; `url` — output URL (conventionally `.pdf`);
  `pageSize` — page dimensions in PDF points, default A4 landscape;
  `deflection` — tessellation quality for edge polylines (default 0.1).
- **Returns:** `Void`.
- **Throws:** `PDFError.writeFailed` if the file cannot be written.
- **OCCT:** Pure-Swift PDF serialisation — no bridge call.
- **Example:**
  ```swift
  let box = Shape.box(width: 100, height: 60, depth: 40)!
  if let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) {
      try Exporter.writePDF(drawing: drawing,
                            to: URL(fileURLWithPath: "/tmp/box.pdf"),
                            pageSize: Exporter.pdfA4Landscape)
  }
  ```

---

### `Exporter.writePDF(sheet:body:to:deflection:)`

Compose a PDF manually via a builder closure operating on a `PDFWriter` sized to a `Sheet`.

```swift
public static func writePDF(
    sheet: Sheet,
    body: (PDFWriter) -> Void,
    to url: URL,
    deflection: Double = 0.1
) throws
```

Derives the page size from `sheet.dimensions` (mm → pts at 72 dpi), then invokes `body` to let
the caller stage arbitrary entities before writing.

- **Parameters:** `sheet` — sheet defining page dimensions and orientation; `body` — closure that
  receives the `PDFWriter` and stages entities; `url` — output URL; `deflection` — tessellation
  quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `PDFError.writeFailed`.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let sheet = Sheet(paperSize: .a4, orientation: .landscape)
  try Exporter.writePDF(sheet: sheet, to: URL(fileURLWithPath: "/tmp/manual.pdf")) { writer in
      writer.addLine(from: SIMD2(10, 10), to: SIMD2(200, 10))
      writer.addText("Title", at: SIMD2(10, 5), height: 5)
  }
  ```

---

## PDFWriter

Pure-Swift PDF 1.4 writer. Public so callers can stage entities manually or combine multiple
views. All coordinates are in millimetres; the content stream installs a mm→pts CTM (72 dpi)
so you never convert units yourself.

Per-layer ISO 128-20 stroke weights: 0.5 mm (VISIBLE, OUTLINE, BORDER, TITLE), 0.25 mm
(HIDDEN, CENTER, DIMENSION, TEXT), 0.18 mm (HATCH). HIDDEN and CENTER layers carry dashed / chain
dash patterns automatically.

```swift
public final class PDFWriter: @unchecked Sendable
```

### `PDFWriter.init(pageSize:deflection:)`

Create a writer with an explicit page size (in PDF points) and tessellation deflection.

```swift
public init(pageSize: SIMD2<Double> = SIMD2(841, 595), deflection: Double = 0.1)
```

- **Parameters:** `pageSize` — page width × height in PDF points (default A4 landscape);
  `deflection` — chord deflection used by `collectFromDrawing` for edge polylines (default 0.1).

---

### `PDFWriter.pageSize`

The page size in PDF points supplied at initialisation.

```swift
public let pageSize: SIMD2<Double>
```

---

### `PDFWriter.deflection`

Tessellation deflection used when collecting edge polylines from a `Drawing`.

```swift
public let deflection: Double
```

---

### `PDFWriter.addLine(from:to:layer:)`

Stage a straight line segment.

```swift
public func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String = "VISIBLE")
```

- **Parameters:** `a` — start point in mm; `b` — end point in mm; `layer` — DXF-style layer name
  (default `"VISIBLE"`).
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  writer.addLine(from: SIMD2(0, 0), to: SIMD2(50, 0), layer: "VISIBLE")
  writer.addLine(from: SIMD2(0, 10), to: SIMD2(50, 10), layer: "HIDDEN")
  ```

---

### `PDFWriter.addPolyline(_:closed:layer:)`

Stage a polyline (sequence of connected line segments).

```swift
public func addPolyline(_ points: [SIMD2<Double>], closed: Bool = false, layer: String = "VISIBLE")
```

Silently ignored if `points.count < 2`.

- **Parameters:** `points` — vertices in mm; `closed` — if `true` a closing segment is appended
  from the last point back to the first; `layer` — layer name (default `"VISIBLE"`).
- **OCCT:** Pure-Swift.

---

### `PDFWriter.addCircle(centre:radius:layer:)`

Stage a full circle.

```swift
public func addCircle(centre: SIMD2<Double>, radius: Double, layer: String = "VISIBLE")
```

Rendered as four cubic Bézier curve segments (kappa approximation).

- **Parameters:** `centre` — centre in mm; `radius` — radius in mm; `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `PDFWriter.addArc(centre:radius:startAngleDeg:endAngleDeg:layer:)`

Stage a circular arc.

```swift
public func addArc(centre: SIMD2<Double>, radius: Double,
                    startAngleDeg: Double, endAngleDeg: Double,
                    layer: String = "VISIBLE")
```

The arc is split into chunks of at most 90° and rendered as cubic Bézier segments.

- **Parameters:** `centre` — centre in mm; `radius` — radius in mm; `startAngleDeg` — start angle
  in degrees (mathematical, CCW from positive X); `endAngleDeg` — end angle in degrees;
  `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `PDFWriter.addText(_:at:height:rotationDeg:layer:)`

Stage a text string.

```swift
public func addText(_ text: String, at position: SIMD2<Double>,
                    height: Double = 3.5, rotationDeg: Double = 0,
                    layer: String = "TEXT")
```

Uses Helvetica (Type1, embedded in the PDF as object 5). Special PDF characters (`(`, `)`, `\`)
are automatically escaped.

- **Parameters:** `text` — string to render; `position` — baseline origin in mm;
  `height` — font size in mm (default 3.5); `rotationDeg` — CCW rotation in degrees (default 0);
  `layer` — layer name (default `"TEXT"`).
- **OCCT:** Pure-Swift.

---

### `PDFWriter.addDimension(_:)`

Stage a `DrawingDimension` as exploded geometry (extension lines + text).

```swift
public func addDimension(_ d: DrawingDimension)
```

Dispatches to the shared annotation/dimension emitter (`DrawingDispatch.swift`). Supports
`.linear`, `.radial`, `.diameter`, `.angular`, and `.ordinate` cases including tolerance
rendering.

- **Parameters:** `d` — dimension to emit.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let dim = DrawingDimension.linear(.init(from: SIMD2(0,0), to: SIMD2(50,0),
                                          value: 50, offset: 8))
  writer.addDimension(dim)
  ```

---

### `PDFWriter.entityCounts`

Read-only tuple reporting the count of each staged entity type.

```swift
public var entityCounts: (lines: Int, polylines: Int, circles: Int, arcs: Int, texts: Int)
```

Useful for assertions in tests and for sanity-checking before writing.

- **OCCT:** Pure-Swift.

---

### `PDFWriter.collectFromDrawing(_:translate:scale:)` (Drawing overload)

Collect all edges, annotations, and dimensions from a `Drawing` into the writer.

```swift
public func collectFromDrawing(_ drawing: Drawing,
                                translate: SIMD2<Double> = .zero,
                                scale: Double = 1.0)
```

Walks `drawing.visibleEdges`, `hiddenEdges`, and `outlineEdges` through `Shape.allEdgePolylines`
and stages the resulting polylines on the matching layers. Then dispatches all
`DrawingAnnotation` and `DrawingDimension` values.

- **Parameters:** `drawing` — source drawing; `translate` — 2D offset applied to all coordinates;
  `scale` — uniform scale applied before the translation.
- **OCCT:** Pure-Swift (edge tessellation uses the bridge indirectly via `Shape.allEdgePolylines`).

---

### `PDFWriter.collectFromDrawing(_:)` (TransformedDrawing overload)

Collect a `TransformedDrawing` (pre-packaged translate + scale) onto this writer.

```swift
public func collectFromDrawing(_ transformed: TransformedDrawing)
```

Convenience for multi-view sheet composition; equivalent to passing `transformed.translate` and
`transformed.scale` to the `Drawing` overload.

- **Parameters:** `transformed` — a `TransformedDrawing` value wrapping a `Drawing` with an
  offset and scale.
- **OCCT:** Pure-Swift.

---

### `PDFWriter.write(to:)`

Serialise all staged entities to a PDF 1.4 file at `url`.

```swift
public func write(to url: URL) throws
```

Builds the PDF 1.4 binary in memory (catalog, pages, content stream, Helvetica font object, xref
table) and writes it atomically via `Data.write(to:)`.

- **Parameters:** `url` — output file URL (conventionally `.pdf`).
- **Returns:** `Void`.
- **Throws:** `PDFError.writeFailed` if `Data.write(to:)` fails.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let writer = PDFWriter(pageSize: Exporter.pdfA4Landscape)
  writer.addLine(from: SIMD2(10, 10), to: SIMD2(100, 10))
  try writer.write(to: URL(fileURLWithPath: "/tmp/output.pdf"))
  ```

---

## SVGError

Error type thrown by `SVGWriter.write(to:)` and `Exporter.writeSVG` variants.

```swift
public enum SVGError: Error, LocalizedError {
    case writeFailed(String)
}
```

- `writeFailed(String)` — `String.write(to:atomically:encoding:)` failed; the associated string
  is the underlying error description.

---

## Exporter — SVG

Two static methods on `Exporter` (defined as an extension in `SVGExporter.swift`).

### `Exporter.writeSVG(drawing:to:deflection:)`

Export a `Drawing` to an SVG 1.1 file.

```swift
public static func writeSVG(drawing: Drawing, to url: URL,
                             deflection: Double = 0.1) throws
```

Creates an `SVGWriter`, collects from the drawing, and writes. The viewBox is computed
automatically from the bounding box of all staged entities, padded by 5 mm.

- **Parameters:** `drawing` — HLR drawing to export; `url` — output URL (conventionally `.svg`);
  `deflection` — tessellation quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `SVGError.writeFailed`.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let box = Shape.box(width: 80, height: 40, depth: 30)!
  if let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) {
      try Exporter.writeSVG(drawing: drawing,
                            to: URL(fileURLWithPath: "/tmp/box.svg"))
  }
  ```

---

### `Exporter.writeSVG(sheet:body:to:deflection:)`

Compose an SVG manually via a builder closure operating on an `SVGWriter` sized to a `Sheet`.

```swift
public static func writeSVG(sheet: Sheet, body: (SVGWriter) -> Void,
                             to url: URL,
                             deflection: Double = 0.1) throws
```

Sets the viewBox from `sheet.dimensions` (in mm) and invokes `body` to let the caller stage
arbitrary entities.

- **Parameters:** `sheet` — sheet defining viewBox dimensions; `body` — staging closure;
  `url` — output URL; `deflection` — tessellation quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `SVGError.writeFailed`.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let sheet = Sheet(paperSize: .a4, orientation: .landscape)
  try Exporter.writeSVG(sheet: sheet, to: URL(fileURLWithPath: "/tmp/manual.svg")) { writer in
      writer.addCircle(centre: SIMD2(50, 50), radius: 20)
      writer.addText("ø40", at: SIMD2(55, 50))
  }
  ```

---

## SVGWriter

Pure-Swift SVG 1.1 writer. Emits one `<g>` group per layer (VISIBLE, OUTLINE, BORDER, TITLE,
HIDDEN, CENTER, DIMENSION, HATCH, TEXT) with per-layer `stroke-width` and `stroke-dasharray`
attributes following ISO 128-20. Mathematical Y (up) is mapped to SVG screen Y (down) by a
group-level `transform="translate(0,maxY) scale(1,-1)"`; each `<text>` carries its own
counter-transform so glyphs read right-side up.

```swift
public final class SVGWriter: @unchecked Sendable
```

### `SVGWriter.init(viewBox:deflection:)`

Create a writer with an optional explicit viewBox and tessellation deflection.

```swift
public init(viewBox: (min: SIMD2<Double>, size: SIMD2<Double>)? = nil,
             deflection: Double = 0.1)
```

When `viewBox` is `nil` (the default) the writer computes a tight bounding box from all staged
entities at `write(to:)` time, padded by 5 mm. Pass an explicit value to fix the viewport
(e.g. when staging an empty sheet frame).

- **Parameters:** `viewBox` — optional explicit viewBox; `deflection` — tessellation quality.

---

### `SVGWriter.viewBox`

Explicit viewBox override; `nil` means auto-compute from staged content.

```swift
public var viewBox: (min: SIMD2<Double>, size: SIMD2<Double>)?
```

Settable after initialisation.

---

### `SVGWriter.deflection`

Tessellation deflection used when collecting edge polylines from a `Drawing`.

```swift
public let deflection: Double
```

---

### `SVGWriter.addLine(from:to:layer:)`

Stage a straight line segment.

```swift
public func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String = "VISIBLE")
```

Emitted as `<line x1="…" y1="…" x2="…" y2="…"/>`.

- **Parameters:** `a` — start point in mm; `b` — end point in mm; `layer` — layer name (default
  `"VISIBLE"`).
- **OCCT:** Pure-Swift.

---

### `SVGWriter.addPolyline(_:closed:layer:)`

Stage a polyline or closed polygon.

```swift
public func addPolyline(_ points: [SIMD2<Double>], closed: Bool = false, layer: String = "VISIBLE")
```

Open polylines emit `<polyline>`; closed ones emit `<polygon>`. Silently ignored if
`points.count < 2`.

- **Parameters:** `points` — vertices in mm; `closed` — if `true` emits `<polygon>` (last vertex
  connects to first); `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `SVGWriter.addCircle(centre:radius:layer:)`

Stage a full circle.

```swift
public func addCircle(centre: SIMD2<Double>, radius: Double, layer: String = "VISIBLE")
```

Emitted as `<circle cx="…" cy="…" r="…"/>`.

- **Parameters:** `centre` — centre in mm; `radius` — radius in mm; `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `SVGWriter.addArc(centre:radius:startAngleDeg:endAngleDeg:layer:)`

Stage a circular arc.

```swift
public func addArc(centre: SIMD2<Double>, radius: Double,
                    startAngleDeg: Double, endAngleDeg: Double,
                    layer: String = "VISIBLE")
```

Emitted as an SVG `<path d="M … A …"/>` with correct large-arc and sweep flags accounting for
the group's Y-flip.

- **Parameters:** `centre` — centre in mm; `radius` — radius in mm; `startAngleDeg` / `endAngleDeg`
  — angles in degrees, mathematical CCW convention; `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `SVGWriter.addText(_:at:height:rotationDeg:layer:)`

Stage a text string.

```swift
public func addText(_ text: String, at position: SIMD2<Double>,
                    height: Double = 3.5, rotationDeg: Double = 0,
                    layer: String = "TEXT")
```

Uses `font-family="Helvetica"`. XML special characters are escaped. Each element carries a
counter-transform that undoes the group's Y-flip so glyphs are not mirrored.

- **Parameters:** `text` — string; `position` — baseline origin in mm; `height` — font size in mm
  (default 3.5); `rotationDeg` — CCW rotation in degrees (default 0); `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `SVGWriter.addDimension(_:)`

Stage a `DrawingDimension` as exploded geometry.

```swift
public func addDimension(_ d: DrawingDimension)
```

Dispatches via the shared `DrawingDispatch` emitter; supports all five dimension types including
tolerance labels.

- **Parameters:** `d` — dimension to emit.
- **OCCT:** Pure-Swift.

---

### `SVGWriter.entityCounts`

Read-only tuple reporting the count of each staged entity type.

```swift
public var entityCounts: (lines: Int, polylines: Int, circles: Int, arcs: Int, texts: Int)
```

- **OCCT:** Pure-Swift.

---

### `SVGWriter.collectFromDrawing(_:translate:scale:)` (Drawing overload)

Collect edges, annotations, and dimensions from a `Drawing`.

```swift
public func collectFromDrawing(_ drawing: Drawing,
                                translate: SIMD2<Double> = .zero,
                                scale: Double = 1.0)
```

Identical semantics to `PDFWriter.collectFromDrawing(_:translate:scale:)`.

- **Parameters:** `drawing` — source drawing; `translate` — 2D offset; `scale` — uniform scale.
- **OCCT:** Pure-Swift (edge tessellation indirectly uses the bridge via `Shape.allEdgePolylines`).

---

### `SVGWriter.collectFromDrawing(_:)` (TransformedDrawing overload)

Collect a `TransformedDrawing` onto this writer.

```swift
public func collectFromDrawing(_ transformed: TransformedDrawing)
```

- **Parameters:** `transformed` — wrapper holding a `Drawing` with a translate and scale.
- **OCCT:** Pure-Swift.

---

### `SVGWriter.write(to:)`

Serialise all staged entities to an SVG 1.1 file.

```swift
public func write(to url: URL) throws
```

Computes or applies the viewBox, emits one `<g>` group per non-empty layer, then writes the
complete SVG string atomically via `String.write(to:atomically:encoding:)`.

- **Parameters:** `url` — output file URL (conventionally `.svg`).
- **Returns:** `Void`.
- **Throws:** `SVGError.writeFailed`.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let writer = SVGWriter()
  writer.addLine(from: SIMD2(0, 0), to: SIMD2(100, 0))
  writer.addCircle(centre: SIMD2(50, 30), radius: 15)
  try writer.write(to: URL(fileURLWithPath: "/tmp/output.svg"))
  ```

---

## DXFError

Error type thrown by `DXFWriter.write(to:)` and `Exporter.writeDXF` variants.

```swift
public enum DXFError: Error, LocalizedError {
    case writeFailed(String)
    case drawingEmpty
}
```

- `writeFailed(String)` — `String.write(to:atomically:encoding:)` failed; the associated string
  is the underlying error description.
- `drawingEmpty` — the projection passed to `Exporter.writeDXF(shape:to:viewDirection:)` failed
  (returned `nil` from `Drawing.project`).

---

## Exporter — DXF

Two static methods on `Exporter` (defined as an extension in `DXFExporter.swift`).

### `Exporter.writeDXF(drawing:to:deflection:)`

Export a `Drawing` (HLR projection + optional dimensions/annotations) to DXF R12 ASCII.

```swift
public static func writeDXF(drawing: Drawing, to url: URL,
                             deflection: Double = 0.1) throws
```

Creates a `DXFWriter`, collects from the drawing, and writes. Layers, linetypes, and the STYLE
table are emitted automatically.

- **Parameters:** `drawing` — HLR drawing to export; `url` — output URL (conventionally `.dxf`);
  `deflection` — tessellation quality for edge polylines (default 0.1).
- **Returns:** `Void`.
- **Throws:** `DXFError.writeFailed`.
- **OCCT:** Pure-Swift (no native OCCT DXF support — confirmed by header audit).
- **Example:**
  ```swift
  let shaft = Shape.cylinder(radius: 15, height: 60)!
  if let drawing = Drawing.project(shaft, direction: SIMD3(0, 0, 1)) {
      try Exporter.writeDXF(drawing: drawing,
                            to: URL(fileURLWithPath: "/tmp/shaft.dxf"))
  }
  ```

---

### `Exporter.writeDXF(shape:to:viewDirection:deflection:)`

Project a shape and export the projection as DXF in one call.

```swift
public static func writeDXF(shape: Shape, to url: URL,
                             viewDirection: SIMD3<Double> = SIMD3(0, 0, 1),
                             deflection: Double = 0.1) throws
```

Calls `Drawing.project(shape, direction: viewDirection)` then delegates to
`writeDXF(drawing:to:deflection:)`. Throws `DXFError.writeFailed("projection failed")` if the
projection returns `nil`.

- **Parameters:** `shape` — shape to project; `url` — output URL;
  `viewDirection` — view direction vector (default `(0, 0, 1)` = top-down);
  `deflection` — tessellation quality (default 0.1).
- **Returns:** `Void`.
- **Throws:** `DXFError.writeFailed`.
- **OCCT:** Pure-Swift (projection via HLR is handled by the `Drawing` type).
- **Example:**
  ```swift
  let bracket = Shape.box(width: 50, height: 30, depth: 10)!
  try Exporter.writeDXF(shape: bracket,
                        to: URL(fileURLWithPath: "/tmp/bracket.dxf"),
                        viewDirection: SIMD3(0, 1, 0))
  ```

---

## DXFWriter

Pure-Swift DXF R12 ASCII writer covering the LINE, CIRCLE, ARC, LWPOLYLINE, and TEXT entity
types. Dimensions are emitted as exploded LINE + TEXT geometry (universally readable across DXF
consumers). Public so callers can compose DXF files from mixed sources or write unit tests
against the staged entity counts.

Layers defined in the output TABLES section: VISIBLE (solid, colour 7), HIDDEN (DASHED, colour 8),
OUTLINE (solid, 7), CENTER (CHAIN, 1), DIMENSION (solid, 5), TEXT (solid, 3), HATCH (solid, 9),
BORDER (solid, 7), TITLE (solid, 7).

```swift
public final class DXFWriter: @unchecked Sendable
```

### `DXFWriter.init(deflection:)`

Create a writer with a tessellation deflection value.

```swift
public init(deflection: Double = 0.1)
```

- **Parameters:** `deflection` — chord deflection used by `collectFromDrawing` (default 0.1).

---

### `DXFWriter.deflection`

Tessellation deflection used when collecting from a `Drawing`.

```swift
public let deflection: Double
```

---

### `DXFWriter.addLine(from:to:layer:)`

Stage a LINE entity.

```swift
public func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String = "VISIBLE")
```

- **Parameters:** `a` — start in mm; `b` — end in mm; `layer` — layer name (default `"VISIBLE"`).
- **OCCT:** Pure-Swift.

---

### `DXFWriter.addPolyline(_:closed:layer:)`

Stage a LWPOLYLINE entity.

```swift
public func addPolyline(_ points: [SIMD2<Double>], closed: Bool = false, layer: String = "VISIBLE")
```

Silently ignored if `points.count < 2`. The `closed` flag sets DXF group code 70 to 1.

- **Parameters:** `points` — vertices in mm; `closed` — close the polyline; `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `DXFWriter.addCircle(centre:radius:layer:)`

Stage a CIRCLE entity.

```swift
public func addCircle(centre: SIMD2<Double>, radius: Double, layer: String = "VISIBLE")
```

- **Parameters:** `centre` — centre in mm; `radius` — radius in mm; `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `DXFWriter.addArc(centre:radius:startAngleDeg:endAngleDeg:layer:)`

Stage an ARC entity.

```swift
public func addArc(centre: SIMD2<Double>, radius: Double,
                   startAngleDeg: Double, endAngleDeg: Double,
                   layer: String = "VISIBLE")
```

DXF ARC uses mathematical CCW convention matching the staged angles.

- **Parameters:** `centre` — centre in mm; `radius` — radius in mm; `startAngleDeg` / `endAngleDeg`
  — arc extent in degrees; `layer` — layer name.
- **OCCT:** Pure-Swift.

---

### `DXFWriter.addText(_:at:height:rotationDeg:layer:)`

Stage a TEXT entity.

```swift
public func addText(_ text: String, at position: SIMD2<Double>,
                    height: Double = 3.5, rotationDeg: Double = 0,
                    layer: String = "TEXT")
```

- **Parameters:** `text` — string; `position` — insertion point in mm;
  `height` — text height in mm (default 3.5); `rotationDeg` — CCW rotation in degrees (default 0);
  `layer` — layer name (default `"TEXT"`).
- **OCCT:** Pure-Swift.

---

### `DXFWriter.addDimension(_:)`

Emit a `DrawingDimension` as exploded LINE + TEXT entities.

```swift
public func addDimension(_ d: DrawingDimension)
```

Dispatches to inline emitters for each case (`.linear` → `emitLinear`, `.radial` → `emitRadial`,
`.diameter` → `emitDiameter`, `.angular` → `emitAngular`, `.ordinate` → `emitOrdinate`). All
`DrawingTolerance` variants are rendered: `.symmetric` and `.fitClass` are folded into the main
label; `.bilateral`, `.unilateral`, and `.limits` produce stacked upper/lower text lines at 55%
height.

- **Parameters:** `d` — dimension to emit.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let writer = DXFWriter()
  writer.addDimension(.linear(.init(from: SIMD2(0, 0), to: SIMD2(80, 0),
                                    value: 80, offset: 10)))
  try writer.write(to: URL(fileURLWithPath: "/tmp/dims.dxf"))
  ```

---

### `DXFWriter.collectFromDrawing(_:translate:scale:)` (Drawing overload)

Collect edges, annotations, and dimensions from a `Drawing`.

```swift
public func collectFromDrawing(_ drawing: Drawing,
                               translate: SIMD2<Double> = .zero,
                               scale: Double = 1.0)
```

Identical semantics to `PDFWriter.collectFromDrawing(_:translate:scale:)`.

- **Parameters:** `drawing` — source drawing; `translate` — 2D offset; `scale` — uniform scale.
- **OCCT:** Pure-Swift (edge tessellation indirectly uses the bridge via `Shape.allEdgePolylines`).

---

### `DXFWriter.collectFromDrawing(_:)` (TransformedDrawing overload)

Collect a `TransformedDrawing` onto this writer.

```swift
public func collectFromDrawing(_ transformed: TransformedDrawing)
```

- **Parameters:** `transformed` — wrapper holding a `Drawing` with a translate and scale.
- **OCCT:** Pure-Swift.

---

### `DXFWriter.entityCounts`

Read-only tuple reporting the count of each staged entity type.

```swift
public var entityCounts: (lines: Int, polylines: Int, circles: Int, arcs: Int, texts: Int)
```

Used by tests to assert that dimensions expand into the expected number of primitives.

- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let writer = DXFWriter()
  writer.addLine(from: .zero, to: SIMD2(10, 0))
  writer.addCircle(centre: SIMD2(5, 5), radius: 3)
  let counts = writer.entityCounts
  // counts.lines == 1, counts.circles == 1
  ```

---

### `DXFWriter.write(to:)`

Serialise all staged entities to a DXF R12 ASCII file.

```swift
public func write(to url: URL) throws
```

Emits HEADER (`$ACADVER = AC1009`, `$INSUNITS = 4` mm), TABLES (LTYPE, LAYER, STYLE), BLOCKS
(empty, required by R12), and ENTITIES sections, then writes atomically via
`String.write(to:atomically:encoding:)`.

- **Parameters:** `url` — output file URL (conventionally `.dxf`).
- **Returns:** `Void`.
- **Throws:** `DXFError.writeFailed`.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let writer = DXFWriter()
  writer.addLine(from: SIMD2(0, 0), to: SIMD2(100, 0))
  writer.addText("OCCTSwift", at: SIMD2(5, 5), height: 4)
  try writer.write(to: URL(fileURLWithPath: "/tmp/output.dxf"))
  ```

---

## PixMap.Format

Pixel format enum wrapping `Image_Format`.

```swift
public enum Format: Int32, Sendable {
    case gray   = 1
    case alpha  = 2
    case rgb    = 3
    case bgr    = 4
    case rgb32  = 5
    case bgr32  = 6
    case rgba   = 7
    case bgra   = 8
}
```

### `PixMap.Format.bytesPerPixel`

Bytes per pixel for this format.

```swift
public var bytesPerPixel: Int
```

- **Returns:** 1 for `.gray`/`.alpha`, 3 for `.rgb`/`.bgr`, 4 for `.rgb32`/`.bgr32`/`.rgba`/`.bgra`.
- **OCCT:** `Image_PixMap::SizePixelBytes(Image_Format)`.
- **Example:**
  ```swift
  #expect(PixMap.Format.rgba.bytesPerPixel == 4)
  #expect(PixMap.Format.gray.bytesPerPixel == 1)
  ```

---

## PixMap

Wraps OCCT `Image_AlienPixMap` — a reference-counted pixel image supporting multiple formats,
per-pixel colour access, file I/O, and gamma correction. Obtain an instance with `PixMap()`,
then call `initTrash` or `load` before reading pixel data.

```swift
public final class PixMap: @unchecked Sendable
```

### `PixMap.init()`

Create an empty `PixMap`.

```swift
public init?()
```

Returns `nil` if the underlying `Image_AlienPixMap` allocation fails (rare in practice). Call
`initTrash(format:width:height:)` or `load(from:)` before accessing pixel data.

- **Returns:** A new `PixMap` instance, or `nil` on allocation failure.
- **OCCT:** `Image_AlienPixMap()` constructor via `OCCTImageCreate`.
- **Example:**
  ```swift
  if let img = PixMap() {
      img.initTrash(format: .rgba, width: 256, height: 256)
      // img is ready for pixel writes
  }
  ```

---

### `PixMap.initTrash(format:width:height:)`

Allocate image data of the given format and dimensions (contents uninitialised).

```swift
@discardableResult
public func initTrash(format: Format, width: Int, height: Int) -> Bool
```

- **Parameters:** `format` — pixel format; `width` — width in pixels; `height` — height in pixels.
- **Returns:** `true` on success; `false` if allocation failed.
- **OCCT:** `Image_AlienPixMap::InitTrash(Image_Format, width, height)`.
- **Example:**
  ```swift
  if let img = PixMap() {
      let ok = img.initTrash(format: .rgb, width: 512, height: 512)
      #expect(ok)
  }
  ```

---

### `PixMap.initCopy(from:)`

Copy the data from another `PixMap` into this one.

```swift
@discardableResult
public func initCopy(from source: PixMap) -> Bool
```

After a successful copy, `self` has the same format, width, and height as `source`.

- **Parameters:** `source` — source pixel map to copy from.
- **Returns:** `true` on success.
- **OCCT:** `Image_AlienPixMap::InitCopy(Image_PixMap)`.
- **Example:**
  ```swift
  if let src = PixMap(), let dst = PixMap() {
      src.initTrash(format: .rgb, width: 64, height: 64)
      let ok = dst.initCopy(from: src)
      #expect(ok && dst.width == 64)
  }
  ```

---

### `PixMap.clear()`

Deallocate the image data, returning the pixel map to an empty state.

```swift
public func clear()
```

After calling `clear()`, `isEmpty` returns `true`.

- **OCCT:** `Image_AlienPixMap::Clear()`.
- **Example:**
  ```swift
  if let img = PixMap() {
      img.initTrash(format: .rgb, width: 32, height: 32)
      img.clear()
      #expect(img.isEmpty)
  }
  ```

---

### `PixMap.width`

Image width in pixels.

```swift
public var width: Int
```

Returns 0 if the image is empty.

- **OCCT:** `Image_AlienPixMap::SizeX()`.

---

### `PixMap.height`

Image height in pixels.

```swift
public var height: Int
```

Returns 0 if the image is empty.

- **OCCT:** `Image_AlienPixMap::SizeY()`.

---

### `PixMap.format`

The pixel format of the current image data.

```swift
public var format: Format
```

Falls back to `.rgb` if the raw format value is unrecognised.

- **OCCT:** `Image_AlienPixMap::Format()`.

---

### `PixMap.isEmpty`

Whether the image contains no allocated data.

```swift
public var isEmpty: Bool
```

- **OCCT:** `Image_AlienPixMap::IsEmpty()`.

---

### `PixMap.pixel(at:y:)`

Return the RGBA colour of the pixel at `(x, y)`.

```swift
public func pixel(at x: Int, y: Int) -> Color
```

- **Parameters:** `x` — column index (0-based); `y` — row index (0-based).
- **Returns:** `Color` with red, green, blue, alpha in [0, 1].
- **OCCT:** `Image_AlienPixMap::PixelColor(x, y)` → `Quantity_ColorRGBA`.
- **Example:**
  ```swift
  if let img = PixMap() {
      img.initTrash(format: .rgba, width: 4, height: 4)
      img.setPixel(at: 1, y: 1, color: Color(red: 1, green: 0, blue: 0, alpha: 1))
      let c = img.pixel(at: 1, y: 1)
      #expect(abs(c.red - 1.0) < 0.02)
  }
  ```

---

### `PixMap.setPixel(at:y:color:)`

Set the colour of the pixel at `(x, y)`.

```swift
public func setPixel(at x: Int, y: Int, color: Color)
```

- **Parameters:** `x` — column index; `y` — row index; `color` — RGBA colour to write.
- **OCCT:** `Image_AlienPixMap::SetPixelColor(x, y, Quantity_ColorRGBA)`.

---

### `PixMap.save(to:)`

Save the image to a file; format is determined by the file extension.

```swift
@discardableResult
public func save(to path: String) -> Bool
```

Supported extensions: `.ppm`, `.png`, `.jpg` / `.jpeg`, `.bmp`, `.tga`. PNG and JPEG require
FreeImage to be linked (available in the pre-built xcframework).

- **Parameters:** `path` — absolute file path including extension.
- **Returns:** `true` on success; `false` if the write fails or the format is unsupported.
- **OCCT:** `Image_AlienPixMap::Save(TCollection_AsciiString)`.
- **Example:**
  ```swift
  if let img = PixMap() {
      img.initTrash(format: .rgb, width: 16, height: 16)
      for y in 0..<16 {
          for x in 0..<16 {
              img.setPixel(at: x, y: y,
                           color: Color(red: Double(x)/16.0, green: Double(y)/16.0, blue: 0.5))
          }
      }
      let saved = img.save(to: "/tmp/gradient.ppm")
      #expect(saved)
  }
  ```

---

### `PixMap.load(from:)`

Load an image from a file.

```swift
@discardableResult
public func load(from path: String) -> Bool
```

- **Parameters:** `path` — absolute file path to an image file.
- **Returns:** `true` on success; `false` if the file cannot be read or decoded.
- **OCCT:** `Image_AlienPixMap::Load(TCollection_AsciiString)`.
- **Example:**
  ```swift
  if let img = PixMap() {
      let ok = img.load(from: "/tmp/gradient.ppm")
      if ok {
          // img.width, img.height, img.format are now populated
      }
  }
  ```

---

### `PixMap.adjustGamma(_:)`

Apply gamma correction to the image in-place.

```swift
@discardableResult
public func adjustGamma(_ gamma: Double) -> Bool
```

`1.0` leaves the image unchanged. Values less than 1.0 darken; values greater than 1.0 brighten.

- **Parameters:** `gamma` — gamma exponent (1.0 = no change).
- **Returns:** `true` on success.
- **OCCT:** `Image_AlienPixMap::AdjustGamma(gamma)`.
- **Example:**
  ```swift
  if let img = PixMap() {
      img.load(from: "/tmp/input.png")
      img.adjustGamma(2.2)
      img.save(to: "/tmp/corrected.png")
  }
  ```

---

### `PixMap.isTopDownDefault`

Whether the underlying image library uses top-down row order by default.

```swift
public static var isTopDownDefault: Bool
```

Reflects the FreeImage / stb_image row-order convention. Informational; most callers can ignore
this.

- **OCCT:** `Image_AlienPixMap::IsTopDownDefault()`.
- **Example:**
  ```swift
  let topDown = PixMap.isTopDownDefault
  ```
