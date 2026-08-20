---
title: Annotation & GD&T
parent: API Reference
---

# Annotation & GD&T

OCCTSwift provides 3D annotation types for attaching measurement dimensions and positioned text to geometry (`Annotation.swift`), plus a typed GD&T layer that reads STEP AP242 dimensions, geometric tolerances and datums off a `Document` (`GDTRead.swift`) and authors them on one (`GDTWrite.swift`).

This page is the single reference for the whole GD&T surface. `docs/reference/Document.md` points here rather than repeating it: until #996 the read side existed twice, an untyped family on `Document` and a typed one behind `typed*` spellings, and both were documented separately. There is now one family, under the untyped names.

## Topics

- [DimensionGeometry](#dimensiongeometry) · [LengthDimension](#lengthdimension) · [RadiusDimension](#radiusdimension) · [AngleDimension](#angledimension) · [DiameterDimension](#diameterdimension) · [TextLabel](#textlabel) · [PointCloud](#pointcloud) · [Document Extensions — GD&T Enums & Structs](#document-extensions--gdt-enums--structs) · [Document Extensions — Read Path](#document-extensions--read-path) · [Document Extensions — Write Path](#document-extensions--write-path)

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

### `DimensionGeometry.circleRadius`

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

| Member | Kind | Meaning |
|---|---|---|
| `handle` | internal stored property | The opaque `OCCTDimensionRef` this wrapper owns. |

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

These types are declared as extensions on `Document` in `GDTRead.swift` and encode the STEP AP242 GD&T vocabulary.

The fourteen `Int32`-backed enums here are transcribed member for member from the pinned kernel's own
`XCAFDimTolObjects_*` headers, and the bridge casts OCCT's enum straight across with no sentinel and
no remap. `Scripts/derive-gdt-enums.py --verify` gates that transcription against
`Scripts/occt-gdt-enums.txt` on every CI run, and `--reverify-headers` re-derives the manifest from
the pinned headers after an OCCT bump. Without it, a member OCCT adds turns into a `nil` from
`dimension(at:)` rather than an error (#996). Ten more joined the gate with the accessors that
return them (#1004), leaving exactly one `XCAFDimTolObjects` enum unbound,
`ToleranceZoneAffectedPlane`; `--reverify-headers` names it, and
`docs/occtswift-wrapping-gaps.md` records why.

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

Raw values match `XCAFDimTolObjects_DimensionType` integer codes directly. The enum has two
families: `location*` cases (a dimension between two features, distinguished by which boundary of
each feature the measurement runs between: center, inner, or outer) and `size*` cases (a single
feature's own extent). Neither OCCT's header nor the STEP AP242 mapping documents each case beyond
its name; the meanings below are a direct, literal reading of that name, not a separate source.

| Case | Meaning |
|---|---|
| `.locationNone` | Location dimension with no more specific sub-type. |
| `.locationCurvedDistance` | Location distance measured along a curved path. |
| `.locationLinearDistance` | Location distance measured as a straight line. |
| `.locationLinearDistanceFromCenterToOuter` | Linear distance from one feature's center to another feature's outer boundary. |
| `.locationLinearDistanceFromCenterToInner` | Linear distance from one feature's center to another feature's inner boundary. |
| `.locationLinearDistanceFromOuterToCenter` | Linear distance from one feature's outer boundary to another feature's center. |
| `.locationLinearDistanceFromOuterToOuter` | Linear distance between two features' outer boundaries. |
| `.locationLinearDistanceFromOuterToInner` | Linear distance from one feature's outer boundary to another feature's inner boundary. |
| `.locationLinearDistanceFromInnerToCenter` | Linear distance from one feature's inner boundary to another feature's center. |
| `.locationLinearDistanceFromInnerToOuter` | Linear distance from one feature's inner boundary to another feature's outer boundary. |
| `.locationLinearDistanceFromInnerToInner` | Linear distance between two features' inner boundaries. |
| `.locationAngular` | Location expressed as an angle between two features. |
| `.locationOriented` | Location dimension oriented against a specified reference direction rather than a plain distance. |
| `.locationWithPath` | Location dimension measured along an explicit path curve. |
| `.sizeCurveLength` | Size given as the length of a curve. |
| `.sizeDiameter` | Size given as a diameter. |
| `.sizeSphericalDiameter` | Size given as a spherical feature's diameter. |
| `.sizeRadius` | Size given as a radius. |
| `.sizeSphericalRadius` | Size given as a spherical feature's radius. |
| `.sizeToroidalMinorDiameter` | Size given as a torus's minor (tube) diameter. |
| `.sizeToroidalMajorDiameter` | Size given as a torus's major diameter. |
| `.sizeToroidalMinorRadius` | Size given as a torus's minor (tube) radius. |
| `.sizeToroidalMajorRadius` | Size given as a torus's major radius. |
| `.sizeToroidalHighMajorDiameter` | Size given as a torus's major diameter at its highest point. |
| `.sizeToroidalLowMajorDiameter` | Size given as a torus's major diameter at its lowest point. |
| `.sizeToroidalHighMajorRadius` | Size given as a torus's major radius at its highest point. |
| `.sizeToroidalLowMajorRadius` | Size given as a torus's major radius at its lowest point. |
| `.sizeThickness` | Size given as a material thickness. |
| `.sizeAngular` | Size given as an angle. |
| `.sizeWithPath` | Size measured along an explicit path curve. |
| `.commonLabel` | Generic dimension label carrying no specific size or location sub-type. |
| `.dimensionPresentation` | Presentation-only dimension value, not a distinct measured sub-type. |

Each case is indexed below too, so a reference link can land on one directly; the table above is
the authoritative description.

#### `Document.DimensionType.dimensionPresentation`

#### `Document.DimensionType.isDimensionalLocation`

Whether this type measures a distance between two features rather than one feature's own size.

```swift
public var isDimensionalLocation: Bool { get }
```

- **Returns:** `true` for the `location*` family.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::IsDimensionalLocation`, a static classifier that
  needs no dimension object. Asked of OCCT rather than re-derived from the case list, so a type OCCT
  reclassifies moves with it.
- **Example:**
  ```swift
  let locations = doc.dimensions.filter(\.type.isDimensionalLocation)
  ```

#### `Document.DimensionType.isDimensionalSize`

Whether this type measures one feature's own size rather than a distance between two.

```swift
public var isDimensionalSize: Bool { get }
```

- **Returns:** `true` for the `size*` family.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::IsDimensionalSize`.
- **Example:**
  ```swift
  let sizes = doc.dimensions.filter(\.type.isDimensionalSize)
  ```

The two do not partition the enum: `.commonLabel` and `.dimensionPresentation` are neither, and no
case is both.

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

Raw values match `XCAFDimTolObjects_GeomToleranceType` integer codes. Names and meanings follow the
ASME Y14.5 / ISO 1101 geometric dimensioning and tolerancing (GD&T) standard; OCCT's enum is a
direct transcription of that standard's tolerance classes, grouped into form, orientation,
location, and runout controls.

| Case | GD&T class | Controls |
|---|---|---|
| `.none` | (unset) | No tolerance type assigned. |
| `.straightness` | Form | How close a line element of a feature is to a true straight line. |
| `.flatness` | Form | How close a surface is to a true plane. |
| `.circularityOrRoundness` | Form | How close a circular cross-section is to a true circle. |
| `.cylindricity` | Form | How close a cylindrical surface is to a true cylinder (circularity and axis straightness combined). |
| `.profileOfLine` | Profile | A 2D outline of a feature against a true profile. |
| `.profileOfSurface` | Profile | A 3D surface of a feature against a true profile. |
| `.angularity` | Orientation | A feature held at a specified angle (other than 0/90) to a datum. |
| `.perpendicularity` | Orientation | A feature held at 90 degrees to a datum. |
| `.parallelism` | Orientation | A feature held equidistant from, and parallel to, a datum. |
| `.position` | Location | A feature's true position relative to one or more datums. |
| `.concentricity` | Location | Median points of a feature of revolution, against a datum axis. |
| `.coaxiality` | Location | Two features' axes, against each other or a datum axis. |
| `.symmetry` | Location | A feature held equally disposed about a datum plane or axis. |
| `.circularRunout` | Runout | A single circular element of a surface, as the part rotates about a datum axis. |
| `.totalRunout` | Runout | An entire surface at once, as the part rotates about a datum axis (the multi-element counterpart of `.circularRunout`). |

#### `GeomToleranceType.totalRunout`

---

### `Document.DimensionFormVariance`

Maps OCCT's `XCAFDimTolObjects_DimensionFormVariance` — the 29 ISO 286 fundamental deviations, the "position letter" half of a tolerance class such as `H7`.

```swift
public enum DimensionFormVariance: Int32, Sendable, CaseIterable {
    case none = 0
    case a = 1
    case b = 2
    case c = 3
    case cd = 4
    case d = 5
    case e = 6
    case ef = 7
    case f = 8
    case fg = 9
    case g = 10
    case h = 11
    case js = 12
    case j = 13
    case k = 14
    case m = 15
    case n = 16
    case p = 17
    case r = 18
    case s = 19
    case t = 20
    case u = 21
    case v = 22
    case x = 23
    case y = 24
    case z = 25
    case za = 26
    case zb = 27
    case zc = 28
}
```

Case names are the ISO 286 letters lowercased. The letter selects where the tolerance zone sits relative to the nominal size: `.h` puts the zone entirely below it for a shaft and entirely above it for a hole (the basis of a clearance fit), `.js` centres it, and the letters run from the largest clearance (`.a`) through interference (`.p` onward). OCCT stores the letter and the grade separately, and `.none` is what `IsDimWithClassOfTolerance()` tests against: a dimension whose form variance is `.none` carries no class at all.

Note the declaration order: `.js` (12) precedes `.j` (13), matching OCCT's own header rather than alphabetical order. Raw values cross the bridge unremapped, so that order is load-bearing and `Scripts/derive-gdt-enums.py` gates it.

#### `Document.DimensionFormVariance.zc`

---

### `Document.DimensionGrade`

Maps OCCT's `XCAFDimTolObjects_DimensionGrade` — the 20 ISO 286 accuracy grades, the numeric half of a tolerance class such as `H7`.

```swift
public enum DimensionGrade: Int32, Sendable, CaseIterable {
    case it01 = 0
    case it0 = 1
    case it1 = 2
    case it2 = 3
    case it3 = 4
    case it4 = 5
    case it5 = 6
    case it6 = 7
    case it7 = 8
    case it8 = 9
    case it9 = 10
    case it10 = 11
    case it11 = 12
    case it12 = 13
    case it13 = 14
    case it14 = 15
    case it15 = 16
    case it16 = 17
    case it17 = 18
    case it18 = 19
}
```

Raw values run finest to coarsest, so `.it01` is 0 and `.it18` is 19. The raw value is **not** the IT number: `.it7` is raw value 8, because the sequence begins at IT01 and IT0 before IT1. Compare grades by `rawValue`, never by parsing the case name.

#### `Document.DimensionGrade.it18`

---

### `Document.DimensionQualifier`

Maps OCCT's `XCAFDimTolObjects_DimensionQualifier`: whether a dimension's value is a minimum, a
maximum or an average rather than a nominal.

```swift
public enum DimensionQualifier: Int32, Sendable, CaseIterable {
    case none = 0
    case min = 1
    case max = 2
    case avg = 3
}
```

| Case | Meaning |
|---|---|
| `.none` | The value is nominal. OCCT's own member for "no qualifier", so this is absence, not a stand-in for it. |
| `.min` | The value is the minimum the feature may take. |
| `.max` | The value is the maximum the feature may take. |
| `.avg` | The value is an average across the feature. |

OCCT's `HasQualifier()` is exactly `!= .none`, so there is no separate predicate on the Swift side.

**Spell the type out when comparing through an optional chain.** `doc.dimension(at: 0)?.qualifier
== .none` resolves `.none` to `Optional.none`, so it is true for a missing dimension as well as an
unqualified one. Write `== Document.DimensionQualifier.none`, or bind the dimension first.

```swift
if let dim = doc.dimension(at: 0), dim.qualifier == .max {
    print("\(dim.value ?? 0) is a maximum, not a nominal")
}
```

---

### `Document.AngularQualifier`

Maps OCCT's `XCAFDimTolObjects_AngularQualifier`: which of the two angles at a vertex an angular
dimension names.

```swift
public enum AngularQualifier: Int32, Sendable, CaseIterable {
    case none = 0
    case small = 1
    case large = 2
    case equal = 3
}
```

| Case | Meaning |
|---|---|
| `.none` | No angular qualifier. |
| `.small` | The dimension names the smaller of the two angles. |
| `.large` | The dimension names the larger of the two angles. |
| `.equal` | The two angles are equal, so the distinction does not apply. |

Independent of `DimensionQualifier`: OCCT stores them in two separate members, and a dimension can
carry both.

```swift
if let dim = doc.dimension(at: 0), dim.angularQualifier == .large {
    print("reflex angle")
}
```

---

### `Document.DimensionModifier`

Maps OCCT's `XCAFDimTolObjects_DimensionModif`: the 24 GD&T modifiers a dimension can carry. Unlike
the two qualifiers this enum has no `none` member: a dimension carries a *sequence* of modifiers, and
an empty sequence is what "no modifier" means.

```swift
public enum DimensionModifier: Int32, Sendable, CaseIterable {
    case controlledRadius = 0
    case square = 1
    case statisticalTolerance = 2
    case continuousFeature = 3
    case twoPointSize = 4
    case localSizeDefinedBySphere = 5
    case leastSquaresAssociationCriterion = 6
    case maximumInscribedAssociation = 7
    case minimumCircumscribedAssociation = 8
    case circumferenceDiameter = 9
    case areaDiameter = 10
    case volumeDiameter = 11
    case maximumSize = 12
    case minimumSize = 13
    case averageSize = 14
    case medianSize = 15
    case midRangeSize = 16
    case rangeOfSizes = 17
    case anyRestrictedPortionOfFeature = 18
    case anyCrossSection = 19
    case specificFixedCrossSection = 20
    case commonTolerance = 21
    case freeStateCondition = 22
    case between = 23
}
```

Raw values match `XCAFDimTolObjects_DimensionModif` integer codes. Names and meanings follow ISO 14405
and ASME Y14.5; OCCT's enum is a direct transcription of those standards' modifier symbols. Order is
preserved end to end: the sequence reads back in the order it was written, since it crosses the bridge
as a count plus a positional index rather than as a set.

```swift
doc.setDimensionModifiers(at: 0, [.statisticalTolerance, .anyCrossSection])
print(doc.dimension(at: 0)?.modifiers ?? [])   // [.statisticalTolerance, .anyCrossSection]
```

---

### `Document.Dimension`

A dimension read from, or created on, a `Document`.

```swift
public struct Dimension: Sendable, Hashable {
    public let type: DimensionType
    public let value: Double?
    public let bounds: Bounds
    public let classOfTolerance: ClassOfTolerance?
    public let qualifier: DimensionQualifier
    public let angularQualifier: AngularQualifier
    public let decimalPlaces: DecimalPlaces?
    public let modifiers: [DimensionModifier]
    public let index: Int

    public var lowerBound: Double? { get }
    public var upperBound: Double? { get }
    public var lowerTolerance: Double? { get }
    public var upperTolerance: Double? { get }
}
```

- `type` — the STEP AP242 dimension sub-type.
- `value` — the nominal value as OCCT's `GetValue()` reports it: a range's midpoint, the single value otherwise, `nil` when `bounds` is `.unset`.
- `bounds` — which of OCCT's dimension kinds this is, and its data.
- `classOfTolerance` — the ISO 286 class, or `nil` if the dimension carries none. Independent of `bounds`.
- `qualifier`: whether `value` is a minimum, a maximum, an average, or (`.none`) a nominal.
- `angularQualifier`: which of the two angles an angular dimension names.
- `decimalPlaces`: the drawn decimal-place pair, or `nil` when the dimension carries none.
- `modifiers`: the GD&T modifiers, in OCCT's own order. Empty when the dimension carries none.
- `index` — position in the document's dimension sequence, for use with `setDimensionTolerance(at:lower:upper:)` and its siblings.

`qualifier` and `angularQualifier` are not optional, unlike `classOfTolerance` and `decimalPlaces`.
OCCT's own enums carry a `_None` member for those two, so absence is already in the vocabulary and
wrapping them in an `Optional` would give two spellings of one state. The other two have no such
member and their zero reading is a real value, so they are optional (#1004).

The four computed accessors project out of `bounds` and answer `nil` where the kind does not carry that quantity. They exist so a caller that only wants one number does not have to `switch`; the enum is the model.

```swift
if let dim = doc.dimension(at: 0) {
    switch dim.bounds {
    case .range(let lower, let upper): print("ranges \(lower) to \(upper)")
    case .plusMinus(let lo, let hi): print("\(dim.value ?? 0) \(lo)/\(hi)")
    case .simple: print("\(dim.value ?? 0)")
    case .unset: print("no value")
    }
}
```

---

#### `Document.Dimension.Bounds`

How a dimension's magnitude is encoded, mirroring `XCAFDimTolObjects_DimensionObject`'s own predicates.

```swift
public enum Bounds: Sendable, Hashable {
    case unset
    case simple
    case range(lower: Double, upper: Double)
    case plusMinus(lowerTolerance: Double, upperTolerance: Double)
}
```

OCCT stores a dimension's magnitude in one values array whose **length** is the discriminator, and its predicates are the length test:

| Case | Array length | OCCT predicate | Slots |
|---|---|---|---|
| `.unset` | 0 (null array) | neither | nothing |
| `.simple` | 1 | neither | the nominal value |
| `.range` | 2 | `IsDimWithRange()` | lower bound, upper bound |
| `.plusMinus` | 3 | `IsDimWithPlusMinusTolerance()` | value, lower tol, upper tol |

Every accessor that does not apply to the kind at hand answers a flat `0` in OCCT, so this is an enum rather than five always-present fields: before #996 a 10..12 range read back as `value = 10, lowerTolerance = 0, upperTolerance = 0`, which is exactly what a plain 10mm dimension with zero tolerance reads back as. `Scripts/repro/996-gdt-read-surface/` has the measurement.

`.unset` is reachable only from imported data. Every dimension this package authors goes through `createDimension`, which always writes a one-element values array.

---

#### `Document.Dimension.ClassOfTolerance`

An ISO 286 tolerance class, present when OCCT's `IsDimWithClassOfTolerance()` holds.

```swift
public struct ClassOfTolerance: Sendable, Hashable {
    public let isHole: Bool
    public let formVariance: DimensionFormVariance
    public let grade: DimensionGrade
}
```

- `isHole` — `true` when the class applies to an internal feature.
- `formVariance` — the fundamental deviation, the letter in `H7`.
- `grade` — the accuracy grade, the number in `H7`.

Independent of `bounds`: OCCT keeps the class outside the values array, so a `.range` or `.plusMinus` dimension can carry one too. Measured both ways in `Scripts/repro/996-gdt-read-surface/`.

---

#### `Document.Dimension.DecimalPlaces`

The number of decimal places a dimension is drawn to.

```swift
public struct DecimalPlaces: Sendable, Hashable {
    public let left: Int
    public let right: Int
}
```

- `left`: places to the left of the decimal point.
- `right`: places to the right.

`Dimension.decimalPlaces` is `nil` when the dimension carries no pair, and `DecimalPlaces(0, 0)` is
not representable. That is not a Swift convention layered on top: `XCAFDoc_Dimension::SetObject`
stores the pair on the label only when `theL > 0 || theR > 0`, so that expression *is* the presence
test. `GetNbOfDecimalPlaces` has no predicate beside it and answers a flat `(0, 0)` for a dimension
that never had one, which a caller could not tell from a real request for zero places (#1004).

A zero on one side alone is a stored pair and reads back: `(0, 4)` survives the round trip.

---

#### `Document.Dimension.lowerTolerance`

The lower tolerance, or `nil` unless `bounds` is `.plusMinus`.

#### `Document.Dimension.upperTolerance`

The upper tolerance, or `nil` unless `bounds` is `.plusMinus`.

#### `Document.Dimension.lowerBound`

The lower bound, or `nil` unless `bounds` is `.range`.

#### `Document.Dimension.upperBound`

The upper bound, or `nil` unless `bounds` is `.range`.

---

### `Document.GeomToleranceValueType`

Maps OCCT's `XCAFDimTolObjects_GeomToleranceTypeValue`: what a tolerance's zone value measures.

```swift
public enum GeomToleranceValueType: Int32, Sendable, CaseIterable {
    case none = 0
    case diameter = 1
    case sphericalDiameter = 2
}
```

| Case | Meaning |
|---|---|
| `.none` | The value is a linear zone width. |
| `.diameter` | The value is a cylindrical zone's diameter. |
| `.sphericalDiameter` | The value is a spherical zone's diameter. |

Reading `value` without this reads it at half or twice its meaning, which is why it is wrapped
first among the tolerance accessors.

```swift
let diametral = doc.geomTolerances.filter { $0.valueType == .diameter }
```

---

### `Document.MaterialRequirement`

Maps OCCT's `XCAFDimTolObjects_GeomToleranceMatReqModif`: the ISO 2692 material condition a
tolerance applies at.

```swift
public enum MaterialRequirement: Int32, Sendable, CaseIterable {
    case none = 0
    case m = 1
    case l = 2
}
```

| Case | Symbol | Meaning |
|---|---|---|
| `.none` | (none) | Regardless of feature size (RFS). |
| `.m` | circle-M | Maximum material condition (MMC). |
| `.l` | circle-L | Least material condition (LMC). |

The two single-letter case names are the drawing symbols themselves, not abbreviations. They come
from OCCT's own member names, which `Scripts/derive-gdt-enums.py` re-derives rather than storing a
pairing, so renaming either to `maximumMaterial` would be a gate failure rather than a silently
accepted alias.

```swift
let mmc = doc.geomTolerances.filter { $0.materialRequirement == .m }
```

---

### `Document.GeomToleranceZoneModifier`

Maps OCCT's `XCAFDimTolObjects_GeomToleranceZoneModif`: how a tolerance zone is qualified.

```swift
public enum GeomToleranceZoneModifier: Int32, Sendable, CaseIterable {
    case none = 0
    case projected = 1
    case runout = 2
    case nonUniform = 3
}
```

| Case | Meaning |
|---|---|
| `.none` | The zone is not qualified. |
| `.projected` | A projected tolerance zone, extending outside the feature by `zoneModifierValue`. |
| `.runout` | A runout zone. |
| `.nonUniform` | A non-uniform zone. |

```swift
if let tol = doc.geomTolerance(at: 0), tol.zoneModifier == .projected {
    print("projected by \(tol.zoneModifierValue ?? 0)")
}
```

---

### `Document.GeomToleranceModifier`

Maps OCCT's `XCAFDimTolObjects_GeomToleranceModif`: the 17 GD&T modifiers a tolerance can carry.
Like `DimensionModifier`, no `none` member: a tolerance carries a sequence, and an empty sequence is
what "no modifier" means.

```swift
public enum GeomToleranceModifier: Int32, Sendable, CaseIterable {
    case anyCrossSection = 0
    case commonZone = 1
    case eachRadialElement = 2
    case freeState = 3
    case leastMaterialRequirement = 4
    case lineElement = 5
    case majorDiameter = 6
    case maximumMaterialRequirement = 7
    case minorDiameter = 8
    case notConvex = 9
    case pitchDiameter = 10
    case reciprocityRequirement = 11
    case separateRequirement = 12
    case statisticalTolerance = 13
    case tangentPlane = 14
    case allAround = 15
    case allOver = 16
}
```

Order is preserved end to end: the sequence crosses the bridge as a count plus a positional index,
not as a set.

```swift
doc.setGeomToleranceModifiers(at: 0, [.allAround, .freeState])
print(doc.geomTolerance(at: 0)?.modifiers ?? [])   // [.allAround, .freeState]
```

---

### `Document.DatumModifier`

Maps OCCT's `XCAFDimTolObjects_DatumSingleModif`: the 22 modifiers a datum can carry. No `none`
member, for the same reason as `GeomToleranceModifier`.

```swift
public enum DatumModifier: Int32, Sendable, CaseIterable {
    case anyCrossSection = 0
    case anyLongitudinalSection = 1
    case basic = 2
    case contactingFeature = 3
    case degreeOfFreedomConstraintU = 4
    case degreeOfFreedomConstraintV = 5
    case degreeOfFreedomConstraintW = 6
    case degreeOfFreedomConstraintX = 7
    case degreeOfFreedomConstraintY = 8
    case degreeOfFreedomConstraintZ = 9
    case distanceVariable = 10
    case freeState = 11
    case leastMaterialRequirement = 12
    case line = 13
    case majorDiameter = 14
    case maximumMaterialRequirement = 15
    case minorDiameter = 16
    case orientation = 17
    case pitchDiameter = 18
    case plane = 19
    case point = 20
    case translation = 21
}
```

The six `degreeOfFreedomConstraint*` cases are the ISO 5459 constrained degrees of freedom: `U`,
`V` and `W` are the rotational ones and `X`, `Y` and `Z` the translational.

```swift
let basic = doc.datums.filter { $0.modifiers.contains(.basic) }
```

---

### `Document.DatumModifierWithValue`

Maps OCCT's `XCAFDimTolObjects_DatumModifWithValue`: the one datum modifier that carries a number.

```swift
public enum DatumModifierWithValue: Int32, Sendable, CaseIterable {
    case none = 0
    case circularOrCylindrical = 1
    case distance = 2
    case projected = 3
    case spherical = 4
}
```

OCCT stores at most one of these per datum, alongside its value, which is why it is separate from
the `DatumModifier` sequence rather than a member of it. `Datum.modifierWithValue` pairs the two.

```swift
if let m = doc.datum(at: 0)?.modifierWithValue, m.modifier == .projected {
    print("projected by \(m.value)")
}
```

---

### `Document.DatumTargetType`

Maps OCCT's `XCAFDimTolObjects_DatumTargetType`: the shape of a datum target.

```swift
public enum DatumTargetType: Int32, Sendable, CaseIterable {
    case point = 0
    case line = 1
    case rectangle = 2
    case circle = 3
    case area = 4
}
```

Alone among the GD&T enums this one has **no `none` member** and starts at `.point`, so it means
nothing for a datum that is not a target at all. `Datum.target` carries it inside an optional for
exactly that reason, rather than exposing it as a field that would read `.point` for every ordinary
datum.

The type also decides which of a target's dimensions OCCT keeps; see `Document.Datum.Target`.

```swift
let areas = doc.datums.filter { $0.target?.type == .area }
```

---

### `Document.GeomTolerance`

A geometric tolerance read from, or created on, a `Document`.

```swift
public struct GeomTolerance: Sendable, Hashable {
    public let type: GeomToleranceType
    public let value: Double
    public let valueType: GeomToleranceValueType
    public let materialRequirement: MaterialRequirement
    public let zoneModifier: GeomToleranceZoneModifier
    public let zoneModifierValue: Double?
    public let maxValueModifier: Double?
    public let modifiers: [GeomToleranceModifier]
    public let index: Int
}
```

- `type`: the ASME / ISO tolerance class.
- `value`: the tolerance zone value, in model units.
- `valueType`: what `value` measures, a linear width or a diameter.
- `materialRequirement`: the material condition the tolerance applies at.
- `zoneModifier`: how the zone is qualified.
- `zoneModifierValue`: the value associated with `zoneModifier`, or `nil`.
- `maxValueModifier`: the maximal upper tolerance for a tolerance carrying modifiers, or `nil`.
- `modifiers`: the GD&T modifiers, in OCCT's own order. Empty when the tolerance carries none.
- `index`: position in the document's geometric tolerance sequence.

The three enums are not optional and the two doubles are, and the split is OCCT's rather than a
convention chosen here. Each enum carries its own `_None` member, so absence is already in its
vocabulary. Neither double has one, and `XCAFDoc_GeomTolerance::SetObject` stores each only when it
is positive, so a stored zero is not representable and an unstored one reads back as the fresh
object's unassigned member, which is also zero. Reporting either as `0.0` would be the defect #996
existed to fix; measured in `Scripts/repro/1004-gdt-accessors/transcript-gates.txt` (#1004).

- `type` — ASME / ISO tolerance class.
- `value` — tolerance zone value in model units.
- `index` — position in the document's geom-tolerance sequence.

`XCAFDimTolObjects_GeomToleranceObject` has no kind predicate of `Bounds`'s sort: `GetValue()` is a single stored number with nothing to discriminate. Its other 20 accessors (material requirement, zone modifier, modifier sequence, affected plane) are not wrapped; see #1004.

---

### `Document.Datum`

A datum reference read from, or created on, a `Document`.

```swift
public struct Datum: Sendable, Hashable {
    public let name: String
    public let position: Int?
    public let modifiers: [DatumModifier]
    public let modifierWithValue: ModifierWithValue?
    public let target: Target?
    public let index: Int
}
```

- `name`: the datum identifier, for example `"A"`.
- `position`: the datum's place in its geometric tolerance's reference frame, 1-based, or `nil`.
- `modifiers`: the modifiers on this datum, in OCCT's own order. Empty when it carries none.
- `modifierWithValue`: the single valued modifier, or `nil`.
- `target`: the datum target, or `nil` when this datum is not a target.
- `index`: position in the document's datum sequence.

`position` is what makes `A|B|C` an ordered reference frame rather than a set. It is 1-based, so `0`
is absence rather than a first place: `STEPCAFControl_Reader`'s frame counter starts at 0 and is
incremented before each datum is written, so an import never assigns 0. `nil` for `<= 0` follows
from that rather than from a convention chosen here (#1004).

**Reading the frame itself is not possible yet.** `Datum.position` gives the order, but nothing in
this package answers which geometric tolerance a datum belongs to: `XCAFDoc_DimTolTool`'s
`GetDatumOfTolerLabels` and `GetTolerOfDatumLabels` are unwrapped, and
`docs/occtswift-wrapping-gaps.md` records that as the largest remaining gap in this surface (#1021).

---

#### `Document.Datum.ModifierWithValue`

The one datum modifier that carries a number, present when OCCT stored one.

```swift
public struct ModifierWithValue: Sendable, Hashable {
    public let modifier: DatumModifierWithValue
    public let value: Double
}
```

- `modifier`: which modifier. Never `.none`, because absence is the enclosing optional.
- `value`: the number it carries, for example a projected datum's distance.

---

#### `Document.Datum.Target`

A datum target, present when OCCT's `IsDatumTarget()` holds.

```swift
public struct Target: Sendable, Hashable {
    public let type: DatumTargetType
    public let number: Int
    public let length: Double?
    public let width: Double?
}
```

- `type`: the target's shape.
- `number`: the target's number within its datum.
- `length`: the target's length along its placement X axis, or `nil`.
- `width`: the target's width along its placement Y axis, or `nil`.

`length` and `width` follow OCCT's own storage conditions rather than being reported
unconditionally, which is what keeps an unassigned member from reading as a measurement. Measured
per type against the pinned kernel:

| `type` | `HasDatumTargetParams()` | `length` | `width` |
|---|---|---|---|
| `.point` | true | `nil` | `nil` |
| `.line` | true | kept | `nil` |
| `.rectangle` | true | kept | kept |
| `.circle` | true | kept | `nil` |
| `.area` | **false** | `nil` | `nil` |

`.area` is the odd row: `XCAFDoc_Datum::SetObject` stores that target's own shape instead of a
placement, so it never writes the axis, `GetObject` never calls `SetDatumTargetAxis`, and the
params flag stays false. The shape itself is not wrapped; see
`docs/occtswift-wrapping-gaps.md`. The transcript is
`Scripts/repro/1004-gdt-accessors/transcript-gates.txt` (#1004).

---

- `name` — datum label string (e.g. `"A"`, `"B"`).
- `index` — position in the document's datum sequence.

`XCAFDimTolObjects_DatumObject`'s other 20 accessors (datum target shape, type, axis, length, width, number, modifiers, position) are not wrapped; see #1004.

---

## Document Extensions — Read Path

These methods read GD&T objects off a `Document`. There is one family: until #996 the same three
bridge calls were read twice, by an untyped family on `Document` returning raw `Int32` type codes
and by a typed family behind `typedDimension(at:)` and friends. The typed structs survive under the
untyped family's names, and the `typed*` spellings are gone.

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

- **OCCT:** `XCAFDoc_DimTolTool::GetGeomToleranceLabels` (via `OCCTDocumentGetGeomToleranceCount`).

---

### `datumCount`

Number of datums defined in this document.

```swift
public var datumCount: Int { get }
```

- **OCCT:** `XCAFDoc_DimTolTool::GetDatumLabels` (via `OCCTDocumentGetDatumCount`).

---

### `dimension(at:)`

The dimension at a given index.

```swift
public func dimension(at index: Int) -> Dimension?
```

- **Parameters:** `index` — zero-based index within the document's dimension label sequence.
- **Returns:** `Dimension` if the label exists and its `XCAFDimTolObjects_DimensionType` maps to a known `DimensionType` case; `nil` otherwise.
- **OCCT:** `XCAFDoc_DimTolTool::GetDimensionLabels` → `XCAFDoc_Dimension::GetObject()` → `XCAFDimTolObjects_DimensionObject::GetType()` / `GetValue()` / `GetValues()` / `IsDimWithRange()` / `GetLowerBound()` / `GetUpperBound()` / `IsDimWithPlusMinusTolerance()` / `GetLowerTolValue()` / `GetUpperTolValue()` / `IsDimWithClassOfTolerance()` / `GetClassOfTolerance()`.
- **Example:**
  ```swift
  for i in 0..<doc.dimensionCount {
      if let dim = doc.dimension(at: i) {
          print(dim.type, dim.value ?? 0, dim.bounds)
      }
  }
  ```

The pinned header's doc comments on `GetUpperTolValue` and `GetLowerTolValue` are swapped upstream, and the 8.0.1 refman renders the same swap. The functions are not swapped, measured two independent ways in `Scripts/repro/996-gdt-read-surface/`, and the bridge carries a comment saying so.

---

### `geomTolerance(at:)`

The geometric tolerance at a given index.

```swift
public func geomTolerance(at index: Int) -> GeomTolerance?
```

- **Parameters:** `index` — zero-based index within the document's geom-tolerance label sequence.
- **Returns:** `GeomTolerance` if the label exists and its type maps to a known `GeomToleranceType` case; `nil` otherwise.
- **OCCT:** `XCAFDoc_DimTolTool::GetGeomToleranceLabels` → `XCAFDoc_GeomTolerance::GetObject()` → `XCAFDimTolObjects_GeomToleranceObject::GetType()` / `GetValue()`.
- **Example:**
  ```swift
  for i in 0..<doc.geomToleranceCount {
      if let tol = doc.geomTolerance(at: i) {
          print(tol.type, tol.value)
      }
  }
  ```

---

### `datum(at:)`

The datum at a given index.

```swift
public func datum(at index: Int) -> Datum?
```

- **Parameters:** `index` — zero-based index within the document's datum label sequence.
- **Returns:** `Datum` wrapping the datum name and index; `nil` if the label does not exist.
- **OCCT:** `XCAFDoc_DimTolTool::GetDatumLabels` → `XCAFDoc_Datum::GetObject()` → `XCAFDimTolObjects_DatumObject::GetName()`.

---

### `dimensions`

All dimensions in the document.

```swift
public var dimensions: [Dimension] { get }
```

- **Returns:** Array of all `Dimension` values for which `dimension(at:)` succeeds.
- **Example:**
  ```swift
  let diameters = doc.dimensions.filter { $0.type == .sizeDiameter }
  ```

---

### `geomTolerances`

All geometric tolerances in the document.

```swift
public var geomTolerances: [GeomTolerance] { get }
```

- **Returns:** Array of all `GeomTolerance` values for which `geomTolerance(at:)` succeeds.

---

### `datums`

All datums in the document.

```swift
public var datums: [Datum] { get }
```

- **Returns:** Array of all `Datum` values for which `datum(at:)` succeeds.
- **Example:**
  ```swift
  let doc = try Document.load(from: gdtStepURL)
  print("Dimensions:", doc.dimensions.count)
  print("Tolerances:", doc.geomTolerances.count)
  for datum in doc.datums { print("Datum:", datum.name) }
  ```

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
  - `shapeLabel`: label ID of the shape to annotate (from `Document.namingFindLabel(shape:)?.labelId`, or from wherever the shape's label ID was captured when it was imported or added).
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
  - `index` — zero-based dimension index (as returned by `createDimension` or used in `dimension(at:)`).
  - `lower` — lower tolerance value in model units.
  - `upper` — upper tolerance value in model units.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or the dimension is already `.range`.
- **OCCT:** `XCAFDoc_DimTolTool::GetDimensionLabels` → `XCAFDoc_Dimension::GetObject()` → `XCAFDimTolObjects_DimensionObject::SetLowerTolValue` / `SetUpperTolValue` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .locationLinearDistance, value: 25.0)!
  let ok = doc.setDimensionTolerance(at: idx, lower: -0.05, upper: 0.05)
  #expect(ok)
  ```

Both OCCT setters return `false`, and change nothing, for a dimension that is already a range;
this method now returns their conjunction rather than discarding them, so a refused call reports
`false` instead of reporting success for a call that did nothing (#996).

---

### `setDimensionBounds(at:lower:upper:)`

Turns an existing dimension into a range dimension, making its `bounds` `.range`.

```swift
@discardableResult
public func setDimensionBounds(at index: Int,
                               lower: Double,
                               upper: Double) -> Bool
```

- **Parameters:**
  - `index` — zero-based dimension index.
  - `lower` — lower bound in model units.
  - `upper` — upper bound in model units.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::SetLowerBound` / `SetUpperBound` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .sizeDiameter, value: 10.0)!
  doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0)
  #expect(doc.dimension(at: idx)?.bounds == .range(lower: 10.0, upper: 12.0))
  ```

This is the only way to author the kind `Bounds.range` reports. `createDimension` always writes a
one-element values array, so a dimension starts `.simple` and becomes `.range` here or `.plusMinus`
through `setDimensionTolerance(at:lower:upper:)`. Call order does not matter within this method:
each OCCT setter resets a non-range dimension to a degenerate range holding its own argument twice,
so either sequence converges on `[lower, upper]` (measured both ways in
`Scripts/repro/996-gdt-read-surface/`).

---

### `setDimensionClassOfTolerance(at:isHole:formVariance:grade:)`

Sets the ISO 286 tolerance class of an existing dimension, leaving its `bounds` alone.

```swift
@discardableResult
public func setDimensionClassOfTolerance(at index: Int,
                                         isHole: Bool,
                                         formVariance: DimensionFormVariance,
                                         grade: DimensionGrade) -> Bool
```

- **Parameters:**
  - `index` — zero-based dimension index.
  - `isHole` — `true` when the class applies to an internal feature.
  - `formVariance` — the fundamental deviation, the letter in `H7`.
  - `grade` — the accuracy grade, the number in `H7`.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::SetClassOfTolerance` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .sizeDiameter, value: 20.0)!
  doc.setDimensionClassOfTolerance(at: idx, isHole: true, formVariance: .h, grade: .it7)
  #expect(doc.dimension(at: idx)?.classOfTolerance?.grade == .it7)
  ```

A class of tolerance lives outside the values array, so setting one does not change `bounds`, and a
`.range` or `.plusMinus` dimension can carry one.


---

### `setDimensionQualifier(at:_:)`

Sets whether an existing dimension's value is a minimum, a maximum or an average.

```swift
@discardableResult
public func setDimensionQualifier(at index: Int, _ qualifier: DimensionQualifier) -> Bool
```

- **Parameters:**
  - `index`: zero-based dimension index.
  - `qualifier`: pass `.none` to clear the qualifier, which is OCCT's own spelling for a nominal value.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `qualifier` is outside the enum.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::SetQualifier` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .sizeDiameter, value: 20.0)!
  doc.setDimensionQualifier(at: idx, .max)
  #expect(doc.dimension(at: idx)?.qualifier == .max)
  ```

The qualifier lives outside the values array, so setting one does not change `bounds` or `value`.

---

### `setDimensionAngularQualifier(at:_:)`

Sets which of the two angles an existing angular dimension names.

```swift
@discardableResult
public func setDimensionAngularQualifier(at index: Int, _ qualifier: AngularQualifier) -> Bool
```

- **Parameters:**
  - `index`: zero-based dimension index.
  - `qualifier`: pass `.none` to clear it.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `qualifier` is outside the enum.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::SetAngularQualifier` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .sizeAngular, value: 45.0)!
  doc.setDimensionAngularQualifier(at: idx, .large)
  #expect(doc.dimension(at: idx)?.angularQualifier == .large)
  ```

Independent of `setDimensionQualifier(at:_:)`: they write two separate OCCT members.

---

### `setDimensionDecimalPlaces(at:left:right:)`

Sets the number of decimal places an existing dimension is drawn to.

```swift
@discardableResult
public func setDimensionDecimalPlaces(at index: Int, left: Int, right: Int) -> Bool
```

- **Parameters:**
  - `index`: zero-based dimension index.
  - `left`: places to the left of the decimal point.
  - `right`: places to the right.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or either count is negative.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::SetNbOfDecimalPlaces` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .sizeDiameter, value: 20.0)!
  doc.setDimensionDecimalPlaces(at: idx, left: 2, right: 3)
  #expect(doc.dimension(at: idx)?.decimalPlaces?.right == 3)
  ```

Passing `0` for both clears the pair, so `dimension(at:)` reports `decimalPlaces` as `nil`. That
matches the condition OCCT itself stores the pair under.

---

### `setDimensionModifiers(at:_:)`

Replaces an existing dimension's GD&T modifier sequence.

```swift
@discardableResult
public func setDimensionModifiers(at index: Int, _ modifiers: [DimensionModifier]) -> Bool
```

- **Parameters:**
  - `index`: zero-based dimension index.
  - `modifiers`: the new sequence, in the order OCCT should store it. An empty array clears the sequence.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_DimensionObject::SetModifiers` → `XCAFDoc_Dimension::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDimension(on: shapeLabel, type: .sizeDiameter, value: 20.0)!
  doc.setDimensionModifiers(at: idx, [.anyCrossSection, .square])
  #expect(doc.dimension(at: idx)?.modifiers == [.anyCrossSection, .square])
  ```

This replaces rather than appends, which is what makes clearing expressible; OCCT's `AddModifier`
appends and has no counterpart that empties the sequence.

---

### `setGeomToleranceValueType(at:_:)`

Sets what an existing geometric tolerance's value measures.

```swift
@discardableResult
public func setGeomToleranceValueType(at index: Int, _ valueType: GeomToleranceValueType) -> Bool
```

- **Parameters:**
  - `index`: zero-based geometric tolerance index.
  - `valueType`: pass `.none` for a linear zone width.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `valueType` is outside the enum.
- **OCCT:** `XCAFDimTolObjects_GeomToleranceObject::SetTypeOfValue` -> `XCAFDoc_GeomTolerance::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createGeomTolerance(on: shapeLabel, type: .position, value: 0.1)!
  doc.setGeomToleranceValueType(at: idx, .diameter)
  #expect(doc.geomTolerance(at: idx)?.valueType == .diameter)
  ```

---

### `setGeomToleranceMaterialRequirement(at:_:)`

Sets the material condition an existing geometric tolerance applies at.

```swift
@discardableResult
public func setGeomToleranceMaterialRequirement(at index: Int, _ requirement: MaterialRequirement) -> Bool
```

- **Parameters:**
  - `index`: zero-based geometric tolerance index.
  - `requirement`: pass `.none` for regardless of feature size.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `requirement` is outside the enum.
- **OCCT:** `XCAFDimTolObjects_GeomToleranceObject::SetMaterialRequirementModifier` -> `XCAFDoc_GeomTolerance::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createGeomTolerance(on: shapeLabel, type: .position, value: 0.1)!
  doc.setGeomToleranceMaterialRequirement(at: idx, .m)
  #expect(doc.geomTolerance(at: idx)?.materialRequirement == .m)
  ```

---

### `setGeomToleranceZoneModifier(at:_:value:)`

Sets an existing geometric tolerance's zone modifier and its associated value.

```swift
@discardableResult
public func setGeomToleranceZoneModifier(at index: Int,
                                         _ modifier: GeomToleranceZoneModifier,
                                         value: Double = 0) -> Bool
```

- **Parameters:**
  - `index`: zero-based geometric tolerance index.
  - `modifier`: pass `.none` to clear the modifier.
  - `value`: the associated value, for example a projected zone's length. Zero or less clears it.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `modifier` is outside the enum.
- **OCCT:** `XCAFDimTolObjects_GeomToleranceObject::SetZoneModifier` and `SetValueOfZoneModifier` -> `XCAFDoc_GeomTolerance::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createGeomTolerance(on: shapeLabel, type: .position, value: 0.1)!
  doc.setGeomToleranceZoneModifier(at: idx, .projected, value: 15.0)
  #expect(doc.geomTolerance(at: idx)?.zoneModifierValue == 15.0)
  ```

The two are one call because the value only means something under a modifier. They remain
independently gated on the way out: the modifier on its own `.none` member, the value on `> 0`, so
clearing the value leaves the modifier standing.

---

### `setGeomToleranceMaxValueModifier(at:_:)`

Sets the maximal upper tolerance of an existing geometric tolerance with modifiers.

```swift
@discardableResult
public func setGeomToleranceMaxValueModifier(at index: Int, _ value: Double) -> Bool
```

- **Parameters:**
  - `index`: zero-based geometric tolerance index.
  - `value`: zero or less clears it, so `geomTolerance(at:)` reports `maxValueModifier` as `nil`.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_GeomToleranceObject::SetMaxValueModifier` -> `XCAFDoc_GeomTolerance::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createGeomTolerance(on: shapeLabel, type: .position, value: 0.1)!
  doc.setGeomToleranceMaxValueModifier(at: idx, 0.25)
  #expect(doc.geomTolerance(at: idx)?.maxValueModifier == 0.25)
  ```

---

### `setGeomToleranceModifiers(at:_:)`

Replaces an existing geometric tolerance's modifier sequence.

```swift
@discardableResult
public func setGeomToleranceModifiers(at index: Int, _ modifiers: [GeomToleranceModifier]) -> Bool
```

- **Parameters:**
  - `index`: zero-based geometric tolerance index.
  - `modifiers`: the new sequence, in the order OCCT should store it. An empty array clears it.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_GeomToleranceObject::SetModifiers` -> `XCAFDoc_GeomTolerance::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createGeomTolerance(on: shapeLabel, type: .position, value: 0.1)!
  doc.setGeomToleranceModifiers(at: idx, [.allAround, .freeState])
  #expect(doc.geomTolerance(at: idx)?.modifiers == [.allAround, .freeState])
  ```

---

### `setDatumPosition(at:_:)`

Sets an existing datum's place in its geometric tolerance's reference frame.

```swift
@discardableResult
public func setDatumPosition(at index: Int, _ position: Int) -> Bool
```

- **Parameters:**
  - `index`: zero-based datum index.
  - `position`: 1-based. Zero or less clears it, so `datum(at:)` reports `position` as `nil`.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_DatumObject::SetPosition` -> `XCAFDoc_Datum::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDatum(name: "A")!
  doc.setDatumPosition(at: idx, 1)
  #expect(doc.datum(at: idx)?.position == 1)
  ```

---

### `setDatumModifiers(at:_:)`

Replaces an existing datum's modifier sequence.

```swift
@discardableResult
public func setDatumModifiers(at index: Int, _ modifiers: [DatumModifier]) -> Bool
```

- **Parameters:**
  - `index`: zero-based datum index.
  - `modifiers`: the new sequence, in the order OCCT should store it. An empty array clears it.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_DatumObject::SetModifiers` -> `XCAFDoc_Datum::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDatum(name: "A")!
  doc.setDatumModifiers(at: idx, [.basic, .contactingFeature])
  #expect(doc.datum(at: idx)?.modifiers == [.basic, .contactingFeature])
  ```

---

### `setDatumModifierWithValue(at:_:value:)`

Sets an existing datum's single valued modifier.

```swift
@discardableResult
public func setDatumModifierWithValue(at index: Int,
                                      _ modifier: DatumModifierWithValue,
                                      value: Double = 0) -> Bool
```

- **Parameters:**
  - `index`: zero-based datum index.
  - `modifier`: pass `.none` to clear the pair, which also clears the value.
  - `value`: the number the modifier carries.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `modifier` is outside the enum.
- **OCCT:** `XCAFDimTolObjects_DatumObject::SetModifierWithValue` -> `XCAFDoc_Datum::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDatum(name: "A")!
  doc.setDatumModifierWithValue(at: idx, .projected, value: 12.5)
  #expect(doc.datum(at: idx)?.modifierWithValue?.value == 12.5)
  ```

Separate from `setDatumModifiers(at:_:)`: OCCT keeps one valued modifier and a sequence of unvalued
ones, in two different members, so clearing one leaves the other standing.

---

### `setDatumTarget(at:type:number:)`

Marks an existing datum as a datum target.

```swift
@discardableResult
public func setDatumTarget(at index: Int, type: DatumTargetType, number: Int) -> Bool
```

- **Parameters:**
  - `index`: zero-based datum index.
  - `type`: the target's shape.
  - `number`: the target's number within its datum.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `number` is negative.
- **OCCT:** `XCAFDimTolObjects_DatumObject::IsDatumTarget(bool)`, `SetDatumTargetType` and `SetDatumTargetNumber` -> `XCAFDoc_Datum::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDatum(name: "B")!
  doc.setDatumTarget(at: idx, type: .rectangle, number: 1)
  #expect(doc.datum(at: idx)?.target?.type == .rectangle)
  ```

---

### `clearDatumTarget(at:)`

Clears an existing datum's datum target mark.

```swift
@discardableResult
public func clearDatumTarget(at index: Int) -> Bool
```

- **Parameters:**
  - `index`: zero-based datum index.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range or the attribute is missing.
- **OCCT:** `XCAFDimTolObjects_DatumObject::IsDatumTarget(false)` -> `XCAFDoc_Datum::SetObject`.
- **Example:**
  ```swift
  doc.clearDatumTarget(at: 0)
  #expect(doc.datum(at: 0)?.target == nil)
  ```

A separate spelling rather than a `nil` argument on `setDatumTarget(at:type:number:)`, because the
type and number are not readable once the mark is cleared and passing them would suggest otherwise.

---

### `setDatumTargetPlacement(at:location:normal:reference:length:width:)`

Sets an existing datum target's placement axis, length and width together.

```swift
@discardableResult
public func setDatumTargetPlacement(at index: Int,
                                    location: SIMD3<Double>,
                                    normal: SIMD3<Double>,
                                    reference: SIMD3<Double>,
                                    length: Double,
                                    width: Double) -> Bool
```

- **Parameters:**
  - `index`: zero-based datum index.
  - `location`: the placement origin.
  - `normal`: the placement Z axis, pointing away from the material.
  - `reference`: the placement X axis, which `length` runs along.
  - `length`: the target's length.
  - `width`: the target's width.
- **Returns:** `true` if the update succeeded; `false` if the index is out of range, the attribute is missing, or `normal` or `reference` is degenerate.
- **OCCT:** `XCAFDimTolObjects_DatumObject::SetDatumTargetAxis`, `SetDatumTargetLength` and `SetDatumTargetWidth` -> `XCAFDoc_Datum::SetObject`.
- **Example:**
  ```swift
  let idx = doc.createDatum(name: "B")!
  doc.setDatumTarget(at: idx, type: .rectangle, number: 1)
  doc.setDatumTargetPlacement(at: idx,
                              location: SIMD3(1, 2, 3),
                              normal: SIMD3(0, 0, 1),
                              reference: SIMD3(1, 0, 0),
                              length: 30, width: 18)
  #expect(doc.datum(at: idx)?.target?.width == 18)
  ```

**One call rather than three on purpose.** Each of OCCT's three setters raises the same
`HasDatumTargetParams()` flag as a side effect, so writing any one of them alone would report the
other two as present while leaving them unassigned. Which of `length` and `width` then survives a
round trip depends on the target type; see `Document.Datum.Target`.
