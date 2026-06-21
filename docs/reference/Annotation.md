---
title: Annotation & GD&T
parent: API Reference
---

# Annotation & GD&T

OCCTSwift provides 3D annotation types for attaching measurement dimensions and positioned text to geometry (`Annotation.swift`), plus a typed GD&T authoring layer that creates STEP AP242-compatible dimensions, geometric tolerances, and datums on a `Document` (`GDTWrite.swift`).

## Topics

- [DimensionGeometry](#dimensiongeometry) · [LengthDimension](#lengthdimension) · [RadiusDimension](#radiusdimension) · [AngleDimension](#angledimension) · [DiameterDimension](#diameterdimension) · [TextLabel](#textlabel) · [PointCloud](#pointcloud) · [Document Extensions — GD&T Enums & Structs](#document-extensions--gdt-enums--structs) · [Document Extensions — Typed Read Path](#document-extensions--typed-read-path) · [Document Extensions — Write Path](#document-extensions--write-path)

---

## DimensionGeometry

Geometry extracted from a dimension measurement, ready for Metal rendering or downstream layout.

```swift
public struct DimensionGeometry: Sendable {
    public let firstPoint: SIMD3<Double>
    public let secondPoint: SIMD3<Double>
    public let centerPoint: SIMD3<Double>
    public let textPosition: SIMD3<Double>
    public let circleNormal: SIMD3<Double>
    public let circleRadius: Double
    public let value: Double
    public let isValid: Bool
}
```

Returned by the `geometry` property on all four dimension types. Fields:

- `firstPoint` — first attachment point on the measured geometry.
- `secondPoint` — second attachment point on the measured geometry.
- `centerPoint` — angle vertex, or circle center for radius / diameter dimensions.
- `textPosition` — suggested 3D location for placing the dimension label.
- `circleNormal` — axis direction of the measured circle (radius / diameter only).
- `circleRadius` — radius of the measured circle (radius / diameter only; `0` for linear / angle dims).
- `value` — measured value: distance in model units for length/radius/diameter, radians for angle.
- `isValid` — whether the extraction succeeded; check before using the other fields.

---

## LengthDimension

Measures distance between two points, along a linear edge, or between two parallel faces.

### `LengthDimension.init?(from:to:)`

Creates a length dimension between two 3D points.

```swift
public init?(from p1: SIMD3<Double>, to p2: SIMD3<Double>)
```

- **Parameters:** `p1`, `p2` — endpoints of the measured span.
- **Returns:** `nil` if `PrsDim_LengthDimension` construction fails (e.g. coincident points).
- **OCCT:** `PrsDim_LengthDimension(gp_Pnt, gp_Pnt, gp_Pln)` — plane is chosen automatically perpendicular to the connecting vector.
- **Example:**
  ```swift
  if let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) {
      print(dim.value)  // 10.0
  }
  ```

---

### `LengthDimension.init?(edge:)`

Creates a length dimension measuring a single linear edge.

```swift
public init?(edge: Shape)
```

- **Parameters:** `edge` — a `Shape` wrapping a `TopoDS_Edge` that is straight (line segment).
- **Returns:** `nil` if `edge` is not a valid linear edge or dimension construction fails.
- **OCCT:** `PrsDim_LengthDimension(TopoDS_Edge, gp_Pln)`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 5, depth: 2)!
  for e in box.edges() {
      if let dim = LengthDimension(edge: e), dim.isValid {
          print(dim.value)
          break
      }
  }
  ```

---

### `LengthDimension.init?(face1:face2:)`

Creates a length dimension between two parallel planar faces.

```swift
public init?(face1: Shape, face2: Shape)
```

- **Parameters:** `face1`, `face2` — `Shape` values each wrapping a `TopoDS_Face`; the faces must be parallel planes.
- **Returns:** `nil` if the faces are not parallel or dimension construction fails.
- **OCCT:** `PrsDim_LengthDimension(TopoDS_Face, TopoDS_Face)`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 5, depth: 2)!
  let faces = box.faces()
  if let dim = LengthDimension(face1: faces[0].shape, face2: faces[1].shape) {
      print(dim.value)
  }
  ```

---

### `value`

The measured distance.

```swift
public var value: Double { get }
```

- **Returns:** Distance in model units between the attached geometry points.
- **OCCT:** `PrsDim_Dimension::GetValue()`.
- **Example:**
  ```swift
  let dim = LengthDimension(from: .zero, to: SIMD3(3, 4, 0))!
  print(dim.value)  // 5.0
  ```

---

### `isValid`

Whether the dimension geometry is valid and the measured value is meaningful.

```swift
public var isValid: Bool { get }
```

- **Returns:** `true` if the underlying `PrsDim_Dimension` considers its geometry valid.
- **OCCT:** `PrsDim_Dimension::IsValid()`.

---

### `setCustomValue(_:)`

Overrides the measured value with a display value for annotation purposes.

```swift
public func setCustomValue(_ value: Double)
```

- **Parameters:** `value` — custom display value in model units.
- **OCCT:** `PrsDim_Dimension::SetCustomValue(Standard_Real)`.
- **Note:** Affects rendered label text only; `value` continues to return the originally measured distance.

---

### `geometry`

Geometry data for Metal rendering — attachment points, text position, and the measured value.

```swift
public var geometry: DimensionGeometry? { get }
```

- **Returns:** `DimensionGeometry` populated from the dimension's internal geometry, or `nil` if extraction fails.
- **OCCT:** `PrsDim_LengthDimension::FirstPoint()`, `SecondPoint()`, `GetValue()`.
- **Example:**
  ```swift
  if let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0)),
     let geo = dim.geometry {
      print(geo.firstPoint, geo.secondPoint, geo.textPosition)
  }
  ```

---

## RadiusDimension

Measures the radius of circular geometry such as a circle edge, arc, or cylindrical face.

### `RadiusDimension.init?(shape:)`

Creates a radius dimension from a shape with circular geometry.

```swift
public init?(shape: Shape)
```

- **Parameters:** `shape` — a `Shape` wrapping circular geometry (edge or face).
- **Returns:** `nil` if the shape does not contain circular geometry or construction fails.
- **OCCT:** `PrsDim_RadiusDimension(TopoDS_Shape)`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  if let dim = RadiusDimension(shape: cyl) {
      print(dim.value)  // ≈ 5.0
  }
  ```

---

### `value`

The measured radius.

```swift
public var value: Double { get }
```

- **OCCT:** `PrsDim_Dimension::GetValue()`.

---

### `isValid`

Whether the dimension is valid.

```swift
public var isValid: Bool { get }
```

- **OCCT:** `PrsDim_Dimension::IsValid()`.

---

### `setCustomValue(_:)`

Overrides the displayed radius with a custom value.

```swift
public func setCustomValue(_ value: Double)
```

- **OCCT:** `PrsDim_Dimension::SetCustomValue(Standard_Real)`.

---

### `geometry`

Geometry data for Metal rendering.

```swift
public var geometry: DimensionGeometry? { get }
```

- **Returns:** `DimensionGeometry` with `centerPoint` set to the circle center and `circleNormal` set to the axis direction; `nil` on failure.
- **OCCT:** `PrsDim_RadiusDimension::Circle()`, `GetValue()`.

---

## AngleDimension

Measures angles between edges, faces, or a vertex-defined triple of points.

### `AngleDimension.init?(edge1:edge2:)`

Creates an angle dimension between two edges.

```swift
public init?(edge1: Shape, edge2: Shape)
```

- **Parameters:** `edge1`, `edge2` — `Shape` values wrapping linear or planar edges.
- **Returns:** `nil` if the edges are parallel or dimension construction fails.
- **OCCT:** `PrsDim_AngleDimension(TopoDS_Edge, TopoDS_Edge)`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 5)!
  let edges = box.edges()
  if edges.count >= 2,
     let dim = AngleDimension(edge1: edges[0].shape, edge2: edges[1].shape) {
      print(dim.degrees)
  }
  ```

---

### `AngleDimension.init?(first:vertex:second:)`

Creates an angle dimension from three points: first, vertex, second.

```swift
public init?(first: SIMD3<Double>, vertex: SIMD3<Double>, second: SIMD3<Double>)
```

- **Parameters:** `first` — first arm point; `vertex` — the angle's apex; `second` — second arm point.
- **Returns:** `nil` if the points are collinear or construction fails.
- **OCCT:** `PrsDim_AngleDimension(gp_Pnt p1, gp_Pnt center, gp_Pnt p2)`.
- **Example:**
  ```swift
  let dim = AngleDimension(
      first:  SIMD3(1, 0, 0),
      vertex: SIMD3(0, 0, 0),
      second: SIMD3(0, 1, 0))
  print(dim?.degrees)  // Optional(90.0)
  ```

---

### `AngleDimension.init?(face1:face2:)`

Creates an angle dimension between two planar faces.

```swift
public init?(face1: Shape, face2: Shape)
```

- **Parameters:** `face1`, `face2` — `Shape` values wrapping planar `TopoDS_Face` sub-shapes.
- **Returns:** `nil` if either face is non-planar or construction fails.
- **OCCT:** `PrsDim_AngleDimension(TopoDS_Face, TopoDS_Face)`.

---

### `value`

The measured angle in radians.

```swift
public var value: Double { get }
```

- **OCCT:** `PrsDim_Dimension::GetValue()`.

---

### `degrees`

The measured angle converted to degrees.

```swift
public var degrees: Double { get }
```

Pure-Swift: `value * 180.0 / .pi`.

- **Example:**
  ```swift
  let dim = AngleDimension(first: SIMD3(1,0,0), vertex: .zero, second: SIMD3(0,1,0))!
  print(dim.degrees)  // 90.0
  ```

---

### `isValid`

Whether the dimension is valid.

```swift
public var isValid: Bool { get }
```

- **OCCT:** `PrsDim_Dimension::IsValid()`.

---

### `setCustomValue(_:)`

Overrides the displayed angle (in radians).

```swift
public func setCustomValue(_ value: Double)
```

- **Parameters:** `value` — custom angle in radians.
- **OCCT:** `PrsDim_Dimension::SetCustomValue(Standard_Real)`.

---

### `geometry`

Geometry data for Metal rendering.

```swift
public var geometry: DimensionGeometry? { get }
```

- **Returns:** `DimensionGeometry` with `centerPoint` at the angle vertex and `value` in radians; `nil` on failure.
- **OCCT:** `PrsDim_AngleDimension::FirstPoint()`, `SecondPoint()`, `CenterPoint()`, `GetValue()`.

---

## DiameterDimension

Measures the diameter of circular geometry (edge, arc, or cylindrical face).

### `DiameterDimension.init?(shape:)`

Creates a diameter dimension from a shape with circular geometry.

```swift
public init?(shape: Shape)
```

- **Parameters:** `shape` — a `Shape` wrapping circular geometry.
- **Returns:** `nil` if the shape does not contain circular geometry or construction fails.
- **OCCT:** `PrsDim_DiameterDimension(TopoDS_Shape)`.
- **Example:**
  ```swift
  let cyl = Shape.cylinder(radius: 5, height: 10)!
  if let dim = DiameterDimension(shape: cyl) {
      print(dim.value)  // ≈ 10.0
  }
  ```

---

### `value`

The measured diameter.

```swift
public var value: Double { get }
```

- **OCCT:** `PrsDim_Dimension::GetValue()`.

---

### `isValid`

Whether the dimension is valid.

```swift
public var isValid: Bool { get }
```

- **OCCT:** `PrsDim_Dimension::IsValid()`.

---

### `setCustomValue(_:)`

Overrides the displayed diameter with a custom value.

```swift
public func setCustomValue(_ value: Double)
```

- **OCCT:** `PrsDim_Dimension::SetCustomValue(Standard_Real)`.

---

### `geometry`

Geometry data for Metal rendering.

```swift
public var geometry: DimensionGeometry? { get }
```

- **Returns:** `DimensionGeometry` with `centerPoint` at the circle center, `circleRadius` set, and `value` equal to the diameter; `nil` on failure.
- **OCCT:** `PrsDim_DiameterDimension::Circle()`, `GetValue()`.

---

## TextLabel

A positioned 3D text annotation — a label with a location, string content, and optional character height.

### `TextLabel.init?(text:position:)`

Creates a text label at a 3D position.

```swift
public init?(text: String, position: SIMD3<Double>)
```

- **Parameters:** `text` — label string; `position` — 3D anchor point in model space.
- **Returns:** `nil` if construction fails (e.g. empty string or bridge allocation error).
- **OCCT:** Internal `OCCTTextLabel` struct — stores string + `gp_Pnt` position.
- **Example:**
  ```swift
  if let label = TextLabel(text: "Datum A", position: SIMD3(0, 0, 10)) {
      label.setHeight(2.0)
      print(label.text)
  }
  ```

---

### `text`

The label string. Readable and writable.

```swift
public var text: String { get set }
```

- **OCCT (get):** `OCCTTextLabelGetInfo` → copies the stored C string.
- **OCCT (set):** `OCCTTextLabelSetText` → replaces the stored string.
- **Note:** Returns `""` if the info retrieval fails.

---

### `position`

The 3D anchor point of the label. Readable and writable.

```swift
public var position: SIMD3<Double> { get set }
```

- **OCCT (get):** `OCCTTextLabelGetInfo` → reads the stored `gp_Pnt`.
- **OCCT (set):** `OCCTTextLabelSetPosition(x:y:z:)`.
- **Returns:** `.zero` if info retrieval fails.

---

### `setHeight(_:)`

Sets the character height for rendering the label text.

```swift
public func setHeight(_ height: Double)
```

- **Parameters:** `height` — character height in model units.
- **OCCT:** `OCCTTextLabelSetHeight`.
- **Example:**
  ```swift
  label.setHeight(3.5)
  ```

---

## PointCloud

A colored point set for 3D visualization, backed by packed coordinate / color buffers.

### `PointCloud.init?(points:)` (uncolored)

Creates a point cloud from an array of 3D positions without per-point colors.

```swift
public init?(points: [SIMD3<Double>])
```

- **Parameters:** `points` — array of 3D positions.
- **Returns:** `nil` if `points` is empty or allocation fails.
- **OCCT:** `OCCTPointCloudCreate(const double*, int32_t)` — packs XYZ into a flat `Double` buffer.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0)]
  if let cloud = PointCloud(points: pts) {
      print(cloud.count)  // 3
  }
  ```

---

### `PointCloud.init?(points:colors:)` (colored)

Creates a colored point cloud with per-point RGB values.

```swift
public init?(points: [SIMD3<Double>], colors: [SIMD3<Float>])
```

- **Parameters:** `points` — 3D positions; `colors` — per-point RGB values with components in [0, 1]. Must have the same count as `points`.
- **Returns:** `nil` if `points.count != colors.count` or allocation fails.
- **OCCT:** `OCCTPointCloudCreateColored(const double*, const float*, int32_t)`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,0,0)]
  let cols: [SIMD3<Float>] = [SIMD3(1,0,0), SIMD3(0,1,0)]
  if let cloud = PointCloud(points: pts, colors: cols) {
      print(cloud.colors.count)  // 2
  }
  ```

---

### `count`

Number of points in the cloud.

```swift
public var count: Int { get }
```

- **OCCT:** `OCCTPointCloudGetCount`.

---

### `bounds`

Axis-aligned bounding box of the point cloud.

```swift
public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)? { get }
```

- **Returns:** Tuple of min/max corners, or `nil` if the cloud is empty or bounds computation fails.
- **OCCT:** `OCCTPointCloudGetBounds` — iterates stored points to compute AABB.
- **Example:**
  ```swift
  if let cloud = PointCloud(points: [SIMD3(0,0,0), SIMD3(5,5,5)]),
     let bb = cloud.bounds {
      print(bb.min, bb.max)  // (0,0,0) (5,5,5)
  }
  ```

---

### `points`

All point positions as an array.

```swift
public var points: [SIMD3<Double>] { get }
```

- **Returns:** Array of 3D positions in insertion order. Returns `[]` if the cloud is empty.
- **OCCT:** `OCCTPointCloudGetPoints(cloud, buffer, count)` — copies the packed buffer into the returned array.

---

### `colors`

All per-point colors as an array.

```swift
public var colors: [SIMD3<Float>] { get }
```

- **Returns:** Array of RGB colors matching each point; `[]` if the cloud was created without colors.
- **OCCT:** `OCCTPointCloudGetColors(cloud, buffer, count)` — copies the packed Float buffer; returns empty if no color data is stored.

---

## Document Extensions — GD&T Enums & Structs

These types are declared as extensions on `Document` in `GDTWrite.swift` and encode the STEP AP242 GD&T vocabulary.

---

### `Document.DimensionType`

Maps OCCT's `XCAFDimTolObjects_DimensionType` — the 32 dimension sub-types that STEP AP242 dimensions can carry.

```swift
public enum DimensionType: Int32, Sendable, CaseIterable {
    case locationNone = 0
    case locationCurvedDistance = 1
    case locationLinearDistance = 2
    case locationLinearDistanceFromCenterToOuter = 3
    case locationLinearDistanceFromCenterToInner = 4
    case locationLinearDistanceFromOuterToCenter = 5
    case locationLinearDistanceFromOuterToOuter = 6
    case locationLinearDistanceFromOuterToInner = 7
    case locationLinearDistanceFromInnerToCenter = 8
    case locationLinearDistanceFromInnerToOuter = 9
    case locationLinearDistanceFromInnerToInner = 10
    case locationAngular = 11
    case locationOriented = 12
    case locationWithPath = 13
    case sizeCurveLength = 14
    case sizeDiameter = 15
    case sizeSphericalDiameter = 16
    case sizeRadius = 17
    case sizeSphericalRadius = 18
    case sizeToroidalMinorDiameter = 19
    case sizeToroidalMajorDiameter = 20
    case sizeToroidalMinorRadius = 21
    case sizeToroidalMajorRadius = 22
    case sizeToroidalHighMajorDiameter = 23
    case sizeToroidalLowMajorDiameter = 24
    case sizeToroidalHighMajorRadius = 25
    case sizeToroidalLowMajorRadius = 26
    case sizeThickness = 27
    case sizeAngular = 28
    case sizeWithPath = 29
    case commonLabel = 30
    case dimensionPresentation = 31
}
```

Raw values match `XCAFDimTolObjects_DimensionType` integer codes directly.

---

### `Document.GeomToleranceType`

Maps OCCT's `XCAFDimTolObjects_GeomToleranceType` — the 16 ASME / ISO geometric tolerance classes.

```swift
public enum GeomToleranceType: Int32, Sendable, CaseIterable {
    case none = 0
    case angularity = 1
    case circularRunout = 2
    case circularityOrRoundness = 3
    case coaxiality = 4
    case concentricity = 5
    case cylindricity = 6
    case flatness = 7
    case parallelism = 8
    case perpendicularity = 9
    case position = 10
    case profileOfLine = 11
    case profileOfSurface = 12
    case straightness = 13
    case symmetry = 14
    case totalRunout = 15
}
```

Raw values match `XCAFDimTolObjects_GeomToleranceType` integer codes.

---

### `Document.Dimension`

Typed snapshot of a dimension read from or created on a `Document`.

```swift
public struct Dimension: Sendable, Hashable {
    public let type: DimensionType
    public let value: Double
    public let lowerTolerance: Double
    public let upperTolerance: Double
    public let index: Int
}
```

- `type` — the STEP AP242 dimension sub-type.
- `value` — nominal value (model units).
- `lowerTolerance` — lower tolerance bound (may be 0 if not set).
- `upperTolerance` — upper tolerance bound (may be 0 if not set).
- `index` — position in the document's dimension sequence (for use with `setDimensionTolerance(at:lower:upper:)`).

---

### `Document.GeomTolerance`

Typed snapshot of a geometric tolerance entry.

```swift
public struct GeomTolerance: Sendable, Hashable {
    public let type: GeomToleranceType
    public let value: Double
    public let index: Int
}
```

- `type` — ASME / ISO tolerance class.
- `value` — tolerance zone value in model units.
- `index` — position in the document's geom-tolerance sequence.

---

### `Document.Datum`

Typed snapshot of a datum reference.

```swift
public struct Datum: Sendable, Hashable {
    public let name: String
    public let index: Int
}
```

- `name` — datum label string (e.g. `"A"`, `"B"`).
- `index` — position in the document's datum sequence.

---

## Document Extensions — Typed Read Path

These methods provide type-safe access to GD&T objects stored in a `Document`, complementing the raw `Int32`-returning read path in `Document.swift`.

---

### `typedDimension(at:)`

Returns the typed dimension at a given index.

```swift
public func typedDimension(at index: Int) -> Dimension?
```

- **Parameters:** `index` — zero-based index within the document's dimension label sequence.
- **Returns:** `Dimension` if the label exists and its `XCAFDimTolObjects_DimensionType` maps to a known `DimensionType` case; `nil` otherwise.
- **OCCT:** `XCAFDoc_DimTolTool::GetDimensionLabels` → `XCAFDoc_Dimension::GetObject()` → `XCAFDimTolObjects_DimensionObject::GetType()` / `GetValues()` / `GetLowerTolValue()` / `GetUpperTolValue()`.
- **Example:**
  ```swift
  for i in 0..<doc.dimensionCount {
      if let dim = doc.typedDimension(at: i) {
          print(dim.type, dim.value)
      }
  }
  ```

---

### `typedGeomTolerance(at:)`

Returns the typed geometric tolerance at a given index.

```swift
public func typedGeomTolerance(at index: Int) -> GeomTolerance?
```

- **Parameters:** `index` — zero-based index within the document's geom-tolerance label sequence.
- **Returns:** `GeomTolerance` if the label exists and its type maps to a known `GeomToleranceType` case; `nil` otherwise.
- **OCCT:** `XCAFDoc_DimTolTool::GetGeomToleranceLabels` → `XCAFDoc_GeomTolerance::GetObject()` → `XCAFDimTolObjects_GeomToleranceObject::GetType()` / `GetValue()`.
- **Example:**
  ```swift
  for i in 0..<doc.geomToleranceCount {
      if let tol = doc.typedGeomTolerance(at: i) {
          print(tol.type, tol.value)
      }
  }
  ```

---

### `typedDatum(at:)`

Returns the typed datum at a given index.

```swift
public func typedDatum(at index: Int) -> Datum?
```

- **Parameters:** `index` — zero-based index within the document's datum label sequence.
- **Returns:** `Datum` wrapping the datum name and index; `nil` if the label does not exist.
- **OCCT:** Delegates to `Document.datum(at:)` → `XCAFDoc_DimTolTool::GetDatumLabels` → `XCAFDoc_Datum::GetObject()` → `XCAFDimTolObjects_DatumObject::GetName()`.

---

### `typedDimensions`

All typed dimensions in the document.

```swift
public var typedDimensions: [Dimension] { get }
```

- **Returns:** Array of all `Dimension` values for which `typedDimension(at:)` succeeds.
- **Example:**
  ```swift
  let dims = doc.typedDimensions
  let diameters = dims.filter { $0.type == .sizeDiameter }
  ```

---

### `typedGeomTolerances`

All typed geometric tolerances in the document.

```swift
public var typedGeomTolerances: [GeomTolerance] { get }
```

- **Returns:** Array of all `GeomTolerance` values for which `typedGeomTolerance(at:)` succeeds.

---

### `typedDatums`

All typed datums in the document.

```swift
public var typedDatums: [Datum] { get }
```

- **Returns:** Array of all `Datum` values for which `typedDatum(at:)` succeeds.

---

## Document Extensions — Write Path

Methods that author new GD&T objects on the document for round-trip through STEP AP242.

---

### `createDimension(on:type:value:lowerTolerance:upperTolerance:)`

Creates a new STEP AP242 dimension on the document, attached to a shape label.

```swift
@discardableResult
public func createDimension(on shapeLabel: Int64,
                            type: DimensionType,
                            value: Double,
                            lowerTolerance: Double = 0,
                            upperTolerance: Double = 0) -> Int?
```

- **Parameters:**
  - `shapeLabel` — label ID of the shape to annotate (from `Document.labelForShape(_:)` or equivalent).
  - `type` — the dimension sub-type (e.g. `.sizeDiameter`, `.locationLinearDistance`).
  - `value` — nominal measured value in model units.
  - `lowerTolerance` — lower tolerance; omit or pass `0` to leave unset.
  - `upperTolerance` — upper tolerance; omit or pass `0` to leave unset.
- **Returns:** Zero-based index of the new dimension in the document's sequence, or `nil` on failure.
- **OCCT:** `XCAFDoc_DimTolTool::AddDimension` → `XCAFDoc_DimTolTool::SetDimension` → `XCAFDimTolObjects_DimensionObject::SetType` / `SetValues` + optionally `SetLowerTolValue` / `SetUpperTolValue` via `setDimensionTolerance(at:lower:upper:)`.
- **Example:**
  ```swift
  if let shapeLabel = doc.labelForShape(shaft),
     let idx = doc.createDimension(on: shapeLabel,
                                   type: .sizeDiameter,
                                   value: 20.0,
                                   lowerTolerance: -0.1,
                                   upperTolerance: 0.0) {
      print("Created dimension at index \(idx)")
  }
  ```

---

### `createGeomTolerance(on:type:value:)`

Creates a new geometric tolerance on the document, attached to a shape label.

```swift
@discardableResult
public func createGeomTolerance(on shapeLabel: Int64,
                                type: GeomToleranceType,
                                value: Double) -> Int?
```

- **Parameters:**
  - `shapeLabel` — label ID of the shape to annotate.
  - `type` — the ASME / ISO tolerance class (e.g. `.flatness`, `.perpendicularity`).
  - `value` — tolerance zone size in model units.
- **Returns:** Zero-based index of the new tolerance in the document's geom-tolerance sequence, or `nil` on failure.
- **OCCT:** `XCAFDoc_DimTolTool::AddGeomTolerance` → `XCAFDoc_DimTolTool::SetGeomTolerance` → `XCAFDimTolObjects_GeomToleranceObject::SetType` / `SetValue`.
- **Example:**
  ```swift
  if let shapeLabel = doc.labelForShape(face),
     let idx = doc.createGeomTolerance(on: shapeLabel,
                                       type: .flatness,
                                       value: 0.05) {
      print("Flatness tolerance at index \(idx)")
  }
  ```

---

### `createDatum(name:)`

Creates a new datum reference on the document.

```swift
@discardableResult
public func createDatum(name: String) -> Int?
```

- **Parameters:** `name` — datum identifier string (typically a single letter, e.g. `"A"`).
- **Returns:** Zero-based index of the new datum in the document's datum sequence, or `nil` on failure.
- **OCCT:** `XCAFDoc_DimTolTool::AddDatum` → `XCAFDimTolObjects_DatumObject::SetName(TCollection_HAsciiString)`.
- **Example:**
  ```swift
  if let idxA = doc.createDatum(name: "A") {
      print("Datum A at index \(idxA)")
  }
  ```

---

### `setDimensionTolerance(at:lower:upper:)`

Updates the tolerance bounds on an existing dimension.

```swift
@discardableResult
public func setDimensionTolerance(at index: Int,
                                  lower: Double,
                                  upper: Double) -> Bool
```

- **Parameters:**
  - `index` — zero-based dimension index (as returned by `createDimension` or used in `typedDimension(at:)`).
  - `lower` — lower tolerance value in model units.
  - `upper` — upper tolerance value in model units.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDoc_DimTolTool::GetDimensionLabels` → `XCAFDoc_Dimension::GetObject()` → `XCAFDimTolObjects_DimensionObject::SetLowerTolValue` / `SetUpperTolValue` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .locationLinearDistance, value: 25.0)!
  let ok = doc.setDimensionTolerance(at: idx, lower: -0.05, upper: 0.05)
  #expect(ok)
  ```
