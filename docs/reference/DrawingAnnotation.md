---
title: DrawingAnnotation
parent: API Reference
---

# DrawingAnnotation

`DrawingAnnotation.swift` defines the complete set of pure-Swift value types used to describe 2D technical-drawing annotations and dimensions. These types carry no OCCT handles, they are data models consumed by `Drawing`'s DXF/PDF/SVG writers and the viewport renderer. All types are `Sendable`, `Hashable`, and (where sensible) `Codable`.

The file contains four public types at the top level and their associated nested types:

- `DrawingLineStyle`: linetype selector
- `DrawingTolerance`: structured tolerance values
- `DrawingDimension`: dimensioning elements (linear, radial, diameter, angular, ordinate)
- `DrawingAnnotation`: non-dimensional annotation elements (centreline, centermark, text, hatch, cutting-plane, balloon)

`DrawingAnnotationStore` is `internal` and is not documented here.

## Topics

- [DrawingLineStyle](#drawinglinestyle) · [DrawingTolerance](#drawingtolerance) · [DrawingDimension](#drawingdimension) · [DrawingDimension.Linear](#drawingdimensionlinear) · [DrawingDimension.Circular](#drawingdimensioncircular) · [DrawingDimension.Radial](#drawingdimensionradial) · [DrawingDimension.Diameter](#drawingdimensiondiameter) · [DrawingDimension.Angular](#drawingdimensionangular) · [DrawingDimension.Ordinate](#drawingdimensionordinate) · [DrawingDimension.Ordinate.Feature](#drawingdimensionordinatefeature) · [DrawingDimension computed properties](#drawingdimension-computed-properties) · [DrawingAnnotation](#drawingannotation-1) · [DrawingAnnotation.Centreline](#drawingannotationcentreline) · [DrawingAnnotation.Centermark](#drawingannotationcentermark) · [DrawingAnnotation.DrawingTextLabel](#drawingannotationdrawingtextlabel) · [DrawingAnnotation.CuttingPlaneLine](#drawingannotationcuttingplaneline) · [DrawingAnnotation.Hatch](#drawingannotationhatch) · [DrawingAnnotation.Balloon](#drawingannotationballoon) · [DrawingAnnotation.Arc](#drawingannotationarc) · [DrawingAnnotationStore](#drawingannotationstore)

---

## DrawingLineStyle

Standard technical-drawing linetypes used when rendering a `DrawingDimension` or `DrawingAnnotation` to DXF, PDF, or a viewport.

### `DrawingLineStyle`

Enumeration of standard ISO/ANSI linetype identifiers.

```swift
public enum DrawingLineStyle: String, Sendable, Hashable, Codable {
    case solid
    case dashed      // hidden-line pattern
    case phantom     // long-dash + 2 short-dash
    case chain       // long-dash + short-dash (centreline)
    case dotted
}
```

- `solid`: continuous line; default for dimensions.
- `dashed`: hidden-line (dash) pattern; use for hidden edges.
- `phantom`: long-dash + two short-dashes; ISO designation "phantom".
- `chain`: long-dash + one short-dash (also called "chain-dot"); ISO designation for centrelines.
- `dotted`: equally-spaced dots.

Pure-Swift; no OCCT mapping.

- **Example:**
  ```swift
  let dim = DrawingDimension.Linear(
      from: SIMD2(0, 0),
      to: SIMD2(50, 0),
      style: .solid
  )
  let cl = DrawingAnnotation.Centreline(
      from: SIMD2(-5, 25),
      to: SIMD2(55, 25),
      style: .chain
  )
  ```

---

#### `DrawingLineStyle.dashed`

Hidden-line (dash) pattern; use for hidden edges.

#### `DrawingLineStyle.phantom`

Long-dash plus two short-dashes; ISO designation "phantom".

#### `DrawingLineStyle.chain`

Long-dash plus one short-dash (also called "chain-dot"); ISO designation for centrelines.

#### `DrawingLineStyle.dotted`

Equally-spaced dots.

Pure-Swift; no OCCT mapping.

- **Example:**
  ```swift
  let dim = DrawingDimension.Linear(
      from: SIMD2(0, 0),
      to: SIMD2(50, 0),
      style: .solid
  )
  let cl = DrawingAnnotation.Centreline(
      from: SIMD2(-5, 25),
      to: SIMD2(55, 25),
      style: .chain
  )
  ```

---

## DrawingTolerance

### `DrawingTolerance`

Typed tolerance value attached to a `DrawingDimension`. Replaces the old `label: "⌀10 ±0.05"` escape hatch with structured data that dimension writers can format correctly.

```swift
public enum DrawingTolerance: Sendable, Hashable, Codable {
    case none
    case symmetric(Double)
    case bilateral(plus: Double, minus: Double)
    case unilateral(Double)
    case fitClass(String)
    case limits(lower: Double, upper: Double)
}
```

| Case | Rendered form | Meaning |
|---|---|---|
| `none` | no tolerance text | No tolerance is displayed. |
| `symmetric(Double)` | `20 ±0.05` | Symmetric plus/minus tolerance; the associated value is the magnitude. |
| `bilateral(plus:minus:)` | `20 +0.10 / -0.05` | Independent plus and minus magnitudes; the writer adds the signs. |
| `unilateral(Double)` | `20 +0.10 / 0` or `20 0 / -0.10` | Single-sided tolerance; the sign of the associated value picks the side. |
| `fitClass(String)` | `H7`, `g6`, `h7/H8` | ISO 286 fit class appended as a suffix. |
| `limits(lower:upper:)` | stacked upper/lower over the nominal | Explicit lower and upper limits, rendered on two lines. |

Pure-Swift; no OCCT mapping.

- **Example:**
  ```swift
  let sym  = DrawingTolerance.symmetric(0.05)       // ±0.05
  let bil  = DrawingTolerance.bilateral(plus: 0.10, minus: 0.05)
  let fit  = DrawingTolerance.fitClass("H7")
  let lims = DrawingTolerance.limits(lower: 19.95, upper: 20.10)
  ```

---

#### `DrawingTolerance.limits`

Explicit lower and upper limits stacked over the nominal value.

- **Example:**
  ```swift
  let sym  = DrawingTolerance.symmetric(0.05)       // ±0.05
  let bil  = DrawingTolerance.bilateral(plus: 0.10, minus: 0.05)
  let fit  = DrawingTolerance.fitClass("H7")
  let lims = DrawingTolerance.limits(lower: 19.95, upper: 20.10)
  ```

---

## DrawingDimension

A dimensioning element attached to a `Drawing`. Each case carries the geometric definition needed to render it; there is no OCCT handle inside.

### `DrawingDimension`

```swift
public enum DrawingDimension: Sendable, Hashable {
    case linear(Linear)
    case radial(Radial)
    case diameter(Diameter)
    case angular(Angular)
    case ordinate(Ordinate)
}
```

| Case | Meaning |
|---|---|
| `linear(Linear)` | Measured distance between two 2D points with an offset dimension line. |
| `radial(Radial)` | Radius callout on a circle or arc with a leader. |
| `diameter(Diameter)` | Diameter callout (prefixed `⌀`) on a circle with a leader. |
| `angular(Angular)` | Angle between two rays sharing a vertex. |
| `ordinate(Ordinate)` | ISO 129-1 §9.3 reference-datum dimensions for a set of features relative to a shared origin. |

Pure-Swift; no OCCT mapping.

- **Example:**
  ```swift
  let d: DrawingDimension = .linear(
      DrawingDimension.Linear(from: SIMD2(0, 0), to: SIMD2(100, 0))
  )
  ```

---

#### `DrawingDimension.ordinate`

ISO 129-1 §9.3 reference-datum dimensions.

- **Example:**
  ```swift
  let d: DrawingDimension = .linear(
      DrawingDimension.Linear(from: SIMD2(0, 0), to: SIMD2(100, 0))
  )
  ```

---

## DrawingDimension.Linear

### `DrawingDimension.Linear`

A linear (straight-line) dimension between two 2D points.

```swift
public struct Linear: Sendable, Hashable {
    public var from: SIMD2<Double>
    public var to: SIMD2<Double>
    public var offset: Double
    public var label: String?
    public var style: DrawingLineStyle
    public var id: String?
    public var tolerance: DrawingTolerance
}
```

- `from`: start point of the measured segment (drawing-unit coordinates).
- `to`: end point of the measured segment.
- `offset`: perpendicular distance of the dimension line from the segment (drawing units).
- `label`: optional user text; `nil` means auto-format from `value`.
- `style`: linestyle for the dimension lines and extension lines.
- `id`: optional identifier for round-tripping through DXF entity handles.
- `tolerance`: structured tolerance; see `DrawingTolerance`.

*(Per-field anchors below, for cross-reference; the list above has the actual meaning of each.)*

#### `DrawingDimension.Linear.tolerance`

---

### `DrawingDimension.Linear.init(from:to:offset:label:style:id:tolerance:)`

Creates a linear dimension between two points.

```swift
public init(from: SIMD2<Double>, to: SIMD2<Double>,
            offset: Double = 10, label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none)
```

- **Parameters:**
  - `from`: start point.
  - `to`: end point.
  - `offset`: perpendicular offset of the dimension line (default `10` drawing units).
  - `label`: override text; `nil` auto-formats `value`.
  - `style`: linestyle (default `.solid`).
  - `id`: optional string identifier.
  - `tolerance`: tolerance annotation (default `.none`).
- **Example:**
  ```swift
  let lin = DrawingDimension.Linear(
      from: SIMD2(0, 0),
      to: SIMD2(80, 0),
      offset: 12,
      tolerance: .symmetric(0.1)
  )
  ```

---

### `DrawingDimension.Linear.value`

The measured 2D distance between `from` and `to`.

```swift
public var value: Double { get }
```

Pure-Swift: `simd_distance(from, to)`.

- **Returns:** Euclidean distance in drawing units.
- **Example:**
  ```swift
  let lin = DrawingDimension.Linear(from: SIMD2(0, 0), to: SIMD2(30, 40))
  print(lin.value)  // 50.0
  ```

---

## DrawingDimension.Circular

### `DrawingDimension.Circular`

Shared field set for `.radial` and `.diameter` dimensions (#1185): a circle or arc defined by
`centre` + `radius`, with a leader line exiting at `leaderAngle`. `Radial` and `Diameter` (below)
are both public typealiases of this one type — the two enum cases differ only in how
`DrawingDimension.value` reads `radius` (`radius` for `.radial`, `2 * radius` for `.diameter`) and
in how the writers render the leader and label prefix (`R` vs `⌀`); everything else is one shared
declaration.

```swift
public struct Circular: Sendable, Hashable {
    public var centre: SIMD2<Double>
    public var radius: Double
    public var leaderAngle: Double
    public var label: String?
    public var style: DrawingLineStyle
    public var id: String?
    public var tolerance: DrawingTolerance
}
```

- `centre`: centre of the circle or arc.
- `radius`: radius of the circle or arc (drawing units). For a `.diameter` dimension this is still
  the stored *radius* — `DrawingDimension.value` reports `2 * radius` for that case.
- `leaderAngle`: angle in radians at which the leader line exits the circle (measured from positive X axis).
- `label`: optional override text (writers prefix `.radial` with `R`, `.diameter` with `⌀`).
- `id`: same semantics as `Linear`.

---

#### `DrawingDimension.Circular.centre`

Centre of the circle or arc.

#### `DrawingDimension.Circular.leaderAngle`

Angle in radians at which the leader line exits the circle, measured from the positive X axis.

#### `DrawingDimension.Circular.style`

Line style for the leader and dimension line; same `DrawingLineStyle` semantics as `Linear`.

#### `DrawingDimension.Circular.tolerance`

Tolerance annotation for the radius value; same `DrawingTolerance` semantics as `Linear`.

---

### `DrawingDimension.Circular.init(centre:radius:leaderAngle:label:style:id:tolerance:)`

Creates a circular-dimension payload, shared by both `.radial` and `.diameter`.

```swift
public init(centre: SIMD2<Double>, radius: Double,
            leaderAngle: Double = .pi / 4,
            label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none)
```

- **Parameters:**
  - `centre`: centre of the circle.
  - `radius`: radius value (for `.diameter`, `DrawingDimension.value` doubles this).
  - `leaderAngle`: leader exit angle in radians (default `π/4` = 45°).
  - `label`: override text; `nil` means auto-format from the wrapping case's own value
    (`R<radius>` for `.radial`, `⌀<2*radius>` for `.diameter`).
  - `style`, `id`, `tolerance`, standard dimension fields.
- **Example:**
  ```swift
  let radial = DrawingDimension.radial(
      .init(centre: SIMD2(50, 50), radius: 20, leaderAngle: .pi / 3))
  let diameter = DrawingDimension.diameter(
      .init(centre: SIMD2(30, 30), radius: 10, tolerance: .fitClass("H7")))
  print(radial.value)    // 20.0  (radius)
  print(diameter.value)  // 20.0  (2 * radius)
  ```

---

## DrawingDimension.Radial

### `DrawingDimension.Radial`

A radius dimension callout on a circle or arc (`DrawingDimension.value` reports `radius`
unchanged; writers prefix the label with `R`). Public typealias of
[`DrawingDimension.Circular`](#drawingdimensioncircular), which documents the fields and
initializer shared with `.diameter`.

```swift
public typealias Radial = Circular
```

---

## DrawingDimension.Diameter

### `DrawingDimension.Diameter`

A diameter dimension callout on a circle, typically prefixed `⌀` in output
(`DrawingDimension.value` reports `2 * radius`). Public typealias of
[`DrawingDimension.Circular`](#drawingdimensioncircular), which documents the fields and
initializer shared with `.radial`.

```swift
public typealias Diameter = Circular
```

---

## DrawingDimension.Angular

### `DrawingDimension.Angular`

An angular dimension between two rays from a shared vertex.

```swift
public struct Angular: Sendable, Hashable {
    public var vertex: SIMD2<Double>
    public var ray1: SIMD2<Double>
    public var ray2: SIMD2<Double>
    public var arcRadius: Double
    public var label: String?
    public var style: DrawingLineStyle
    public var id: String?
    public var tolerance: DrawingTolerance
}
```

- `vertex`: the point where the two rays originate.
- `label`: standard dimension field.

---

#### `DrawingDimension.Angular.ray1`

A point on the first ray (not necessarily a unit vector).

#### `DrawingDimension.Angular.ray2`

A point on the second ray (not necessarily a unit vector).

#### `DrawingDimension.Angular.arcRadius`

Radius at which the dimension arc is drawn (drawing units).

#### `DrawingDimension.Angular.style`

Line style for the dimension arc and extension lines; same `DrawingLineStyle` semantics as `Linear`.

#### `DrawingDimension.Angular.tolerance`

Tolerance annotation for the angle value; same `DrawingTolerance` semantics as `Linear`.

---

### `DrawingDimension.Angular.init(vertex:ray1:ray2:arcRadius:label:style:id:tolerance:)`

Creates an angular dimension between two rays.

```swift
public init(vertex: SIMD2<Double>, ray1: SIMD2<Double>, ray2: SIMD2<Double>,
            arcRadius: Double = 20,
            label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none)
```

- **Parameters:**
  - `vertex`: common origin of the two rays.
  - `ray1`, `ray2`, points on each bounding ray.
  - `arcRadius`: radius of the dimension arc in drawing units (default `20`).
  - `label`: override text; `nil` auto-formats the angle in degrees.
  - `style`, `id`, `tolerance`, standard dimension fields.
- **Example:**
  ```swift
  let ang = DrawingDimension.Angular(
      vertex: SIMD2(0, 0),
      ray1:   SIMD2(40, 0),
      ray2:   SIMD2(0, 40),
      arcRadius: 25
  )
  print(ang.value * 180 / .pi)  // 90.0
  ```

---

### `DrawingDimension.Angular.value`

The angle between the two rays in radians (0 ≤ θ ≤ π).

```swift
public var value: Double { get }
```

Pure-Swift: normalises `ray1 - vertex` and `ray2 - vertex`, returns `acos(dot(v1, v2))` clamped to `[-1, 1]`.

- **Returns:** Angle in radians.
- **Example:**
  ```swift
  let ang = DrawingDimension.Angular(
      vertex: .zero, ray1: SIMD2(1, 0), ray2: SIMD2(0, 1)
  )
  print(ang.value)  // ~1.5708 (π/2)
  ```

---

## DrawingDimension.Ordinate

### `DrawingDimension.Ordinate`

ISO 129-1 §9.3 ordinate dimensions: a shared datum origin plus one or more features, each located by its X and Y offset from that origin. Suitable for CNC-style reference-datum dimensioning where chains of linear dimensions would clutter the view.

```swift
public struct Ordinate: Sendable, Hashable, Codable {
    public var origin: SIMD2<Double>
    public var features: [Feature]
    public var id: String?
    public var tolerance: DrawingTolerance
}
```

- `origin`: datum origin from which all feature offsets are measured.
- `features`: ordered list of `Feature` values, each with a position and optional label.
- `id`: optional identifier.
- `tolerance`: common tolerance applied to all feature values (individual tolerances are expressed via feature labels).

*(Per-field anchors below, for cross-reference; the list above has the actual meaning of each.)*

#### `DrawingDimension.Ordinate.tolerance`

---

### `DrawingDimension.Ordinate.init(origin:features:tolerance:id:)`

Creates an ordinate dimension group.

```swift
public init(origin: SIMD2<Double>, features: [Feature],
            tolerance: DrawingTolerance = .none, id: String? = nil)
```

- **Parameters:**
  - `origin`: datum origin point.
  - `features`: array of `Feature` values (positions relative to origin).
  - `tolerance`: common tolerance (default `.none`).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let ord = DrawingDimension.Ordinate(
      origin: SIMD2(0, 0),
      features: [
          .init(position: SIMD2(20, 0)),
          .init(position: SIMD2(45, 0)),
          .init(position: SIMD2(80, 0), label: "80 REF"),
      ]
  )
  ```

---

## DrawingDimension.Ordinate.Feature

### `DrawingDimension.Ordinate.Feature`

A single feature location within an ordinate dimension group.

```swift
public struct Feature: Sendable, Hashable, Codable {
    public var position: SIMD2<Double>
    public var label: String?
    public var id: String?
}
```

- `position`: 2D location of the feature in drawing coordinates.
- `label`: optional override text; `nil` means auto-format the (x, y) offset from the parent `Ordinate.origin`.
- `id`: optional identifier.

---

### `DrawingDimension.Ordinate.Feature.init(position:label:id:)`

Creates a single feature entry for an ordinate dimension.

```swift
public init(position: SIMD2<Double>, label: String? = nil, id: String? = nil)
```

- **Parameters:**
  - `position`: 2D location of the feature.
  - `label`: optional override text.
  - `id`: optional identifier.
- **Example:**
  ```swift
  let f = DrawingDimension.Ordinate.Feature(position: SIMD2(35, 0))
  ```

---

## DrawingDimension Computed Properties

These computed properties are declared on `DrawingDimension` itself and dispatch over all cases.

### `DrawingDimension.id`

The `id` of the wrapped dimension case.

```swift
public var id: String? { get }
```

Pure-Swift switch over all cases returning the nested struct's `id`.

- **Returns:** The `id` string of the active case, or `nil` if none was set. For `.ordinate`, returns the ordinate-level `id` (not per-feature ids).
- **Example:**
  ```swift
  let d = DrawingDimension.linear(
      DrawingDimension.Linear(from: .zero, to: SIMD2(10, 0), id: "dim-1")
  )
  print(d.id)  // Optional("dim-1")
  ```

---

### `DrawingDimension.label`

The user-supplied label of the wrapped dimension case.

```swift
public var label: String? { get }
```

Pure-Swift switch over all cases returning the nested struct's `label`. Returns `nil` for `.ordinate`, ordinate features carry per-feature labels; there is no single dimension-level label.

- **Returns:** The `label` string, or `nil` if none was set or the case is `.ordinate`.
- **Example:**
  ```swift
  let d = DrawingDimension.radial(
      DrawingDimension.Radial(centre: .zero, radius: 10, label: "R10")
  )
  print(d.label)  // Optional("R10")
  ```

---

### `DrawingDimension.value`

The scalar measured value of the wrapped dimension case.

```swift
public var value: Double { get }
```

Pure-Swift dispatch: returns `Linear.value` (distance), `radius` for `.radial`, `2 * radius` for `.diameter` (#1185: both cases share `Circular`, which has no `value` member of its own — that differing formula lives here, not on the struct), `Angular.value` (radians), or `0` for `.ordinate` (which has no single scalar measurement, read `.ordinate` features directly).

- **Returns:** The measurement value in drawing units (or radians for angular); `0` for ordinate.
- **Example:**
  ```swift
  let d = DrawingDimension.diameter(
      DrawingDimension.Diameter(centre: .zero, radius: 5)
  )
  print(d.value)  // 10.0
  ```

---

```swift
```
---
## DrawingAnnotation

Non-dimensional 2D annotations attached to a `Drawing`, centrelines, centremarks, construction points, free-form text, hatch fills, cutting-plane indicators, and assembly balloons.

### `DrawingAnnotation`

```swift
public enum DrawingAnnotation: Sendable, Hashable {
    case centreline(Centreline)
    case centermark(Centermark)
    case textLabel(DrawingTextLabel)
    case hatch(Hatch)
    case cuttingPlaneLine(CuttingPlaneLine)
    case balloon(Balloon)
    case arc(Arc)
}
```

- `centreline`: a chain-style line segment marking a symmetry or rotation axis.
- `centermark`: a cross mark at the centre of a circle or arc.
- `textLabel`: free-form text at a 2D position with optional rotation.
- `hatch`: ISO 128-50 section-view hatching fill within a polygon boundary.
- `cuttingPlaneLine`: ISO 128-40 section mark indicating where a section view was cut.
- `balloon`: assembly-drawing numbered callout balloon, optionally with a leader line.
- `arc`: a single 2D arc primitive (centre, radius, start/end angle, layer) — e.g. ISO 6410's cosmetic-thread end-view broken arc (#1179).

Pure-Swift; no OCCT mapping.

*(Per-case anchors below, for cross-reference; the list above has the actual meaning of each.)*

#### `DrawingAnnotation.balloon`

Internal, not public API: `DrawingAnnotation.keyPoints` (`internal var`, declared in an extension in `DrawingComposition.swift`) returns each case's key 2D points, used by `Drawing.bounds(deflection:includeAnnotations:)` to include annotation extents and by the internal `transformed(translate:scale:)` composition helpers. Not part of the public API surface.

---
## DrawingAnnotation.Centreline

### `DrawingAnnotation.Centreline`

A chain-linestyle segment marking a centreline, symmetry axis, or pitch-circle diameter.

```swift
public struct Centreline: Sendable, Hashable {
    public var from: SIMD2<Double>
    public var to: SIMD2<Double>
    public var style: DrawingLineStyle    // typically .chain
    public var id: String?
}
```

- `from`, `to`, endpoints of the centreline segment.
- `style`: linestyle (default `.chain` to produce the long-dash + short-dash pattern).
- `id`: optional identifier.

| Field | Meaning |
|---|---|
| `from` | Start endpoint of the centreline segment. |
| `to` | End endpoint of the centreline segment. |
| `style` | Linestyle, typically `.chain`. |
| `id` | Optional identifier. |

#### `DrawingAnnotation.Centreline.style`

Linestyle, typically `.chain`.

---

### `DrawingAnnotation.Centreline.init(from:to:style:id:)`

Creates a centreline annotation.

```swift
public init(from: SIMD2<Double>, to: SIMD2<Double>,
            style: DrawingLineStyle = .chain,
            id: String? = nil)
```

- **Parameters:**
  - `from`: start endpoint.
  - `to`: end endpoint.
  - `style`: linestyle (default `.chain`).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let cl = DrawingAnnotation.centreline(
      DrawingAnnotation.Centreline(
          from: SIMD2(-5, 0),
          to: SIMD2(105, 0)
      )
  )
  ```

---

## DrawingAnnotation.Centermark

### `DrawingAnnotation.Centermark`

A cross mark at the centre of a circle or arc, consisting of two crossing line segments.

```swift
public struct Centermark: Sendable, Hashable {
    public var centre: SIMD2<Double>
    public var extent: Double
    public var style: DrawingLineStyle    // typically .chain
    public var id: String?
}
```

- `centre`: position of the cross centre.
- `extent`: full length of each crossing segment (drawing units); the cross arm extends `extent/2` on each side.
- `style`: linestyle (default `.chain`).
- `id`: optional identifier.

---

#### `DrawingAnnotation.Centermark.centre`

Position of the cross centre.

#### `DrawingAnnotation.Centermark.style`

Line style for the crossing segments; defaults to `.chain` (the ISO centreline convention).

---

### `DrawingAnnotation.Centermark.init(centre:extent:style:id:)`

Creates a centermark annotation.

```swift
public init(centre: SIMD2<Double>, extent: Double = 8,
            style: DrawingLineStyle = .chain,
            id: String? = nil)
```

- **Parameters:**
  - `centre`: cross centre position.
  - `extent`: total arm length for each crossing segment (default `8` drawing units).
  - `style`: linestyle (default `.chain`).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let cm = DrawingAnnotation.centermark(
      DrawingAnnotation.Centermark(centre: SIMD2(50, 50), extent: 10)
  )
  ```

---

## DrawingAnnotation.DrawingTextLabel

### `DrawingAnnotation.DrawingTextLabel`

Free-form text placed at a 2D position, with optional rotation.

```swift
public struct DrawingTextLabel: Sendable, Hashable {
    public var position: SIMD2<Double>
    public var text: String
    public var height: Double
    public var rotation: Double     // radians
    public var id: String?
}
```

- `position`: insertion point of the text (bottom-left of the text baseline).
- `text`: the string content to render.
- `height`: character height in drawing units.
- `rotation`: counter-clockwise rotation angle in radians.
- `id`: optional identifier.

---

### `DrawingAnnotation.DrawingTextLabel.init(position:text:height:rotation:id:)`

Creates a text label annotation.

```swift
public init(position: SIMD2<Double>, text: String,
            height: Double = 3.5, rotation: Double = 0,
            id: String? = nil)
```

- **Parameters:**
  - `position`: text insertion point.
  - `text`: content string.
  - `height`: character height (default `3.5` drawing units, corresponding to ISO standard 3.5 mm text).
  - `rotation`: rotation in radians (default `0`, i.e. horizontal).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let note = DrawingAnnotation.textLabel(
      DrawingAnnotation.DrawingTextLabel(
          position: SIMD2(10, 200),
          text: "SECTION A-A",
          height: 5.0
      )
  )
  ```

---

## TextLabel (OCCT-backed class)

Renamed from `DrawingAnnotation.TextLabel` to `DrawingAnnotation.DrawingTextLabel` (#1175), to stop
colliding by bare name with this unrelated type: `TextLabel` (declared with no enclosing type, in
`Annotation.swift`) is an OCCT-backed 3D text label used for viewport/Metal-rendered scene labels,
not the pure-Swift 2D annotation struct above. See [Annotation](Annotation.md) for its public
surface (`text`, `position`, `setHeight(_:)`).

*(Internal, not public API: `TextLabel.handle` is an `internal let handle: OCCTTextLabelRef` wrapping the underlying bridge object, released in `deinit`. See [Memory Management](../architecture/overview.md#occt-handles).)*

---
## DrawingAnnotation.CuttingPlaneLine

### `DrawingAnnotation.CuttingPlaneLine`

ISO 128-40 cutting-plane line, the section mark on a parent view indicating where a section view is cut.

```swift
public struct CuttingPlaneLine: Sendable, Hashable {
    public var label: String
    public var traceStart: SIMD2<Double>
    public var traceEnd: SIMD2<Double>
    public var arrowDirection: SIMD2<Double>   // perpendicular to trace, in view 2D
    public var id: String?
}
```

Rendered as heavy-chain segments at each endpoint (~10 mm), a thin-chain segment joining them, perpendicular arrows at each end pointing in the section's view direction, and a label letter (typically a capital letter such as "A") at each arrow.

- `label`: the callout letter(s) placed at each arrow end (e.g. `"A"`, `"B"`).
- `traceStart`, `traceEnd`, endpoints of the cutting-plane trace across the view.
- `arrowDirection`: unit vector perpendicular to the trace pointing in the section look direction; stored normalised.
- `id`: optional identifier.

*(Per-field anchors below, for cross-reference; the list above has the actual meaning of each.)*

#### `DrawingAnnotation.CuttingPlaneLine.traceStart`

---

### `DrawingAnnotation.CuttingPlaneLine.init(label:traceStart:traceEnd:arrowDirection:id:)`

Creates a cutting-plane-line annotation. The `arrowDirection` is normalised on construction.

```swift
public init(label: String,
            traceStart: SIMD2<Double>,
            traceEnd: SIMD2<Double>,
            arrowDirection: SIMD2<Double>,
            id: String? = nil)
```

- **Parameters:**
  - `label`: callout letter(s) placed at each arrow (e.g. `"A"`).
  - `traceStart`: start of the cutting-plane trace.
  - `traceEnd`: end of the cutting-plane trace.
  - `arrowDirection`: view direction for the section (need not be unit length; stored as `simd_normalize(arrowDirection)`).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let cpl = DrawingAnnotation.cuttingPlaneLine(
      DrawingAnnotation.CuttingPlaneLine(
          label: "A",
          traceStart: SIMD2(0, 50),
          traceEnd:   SIMD2(100, 50),
          arrowDirection: SIMD2(0, -1)   // section looks downward
      )
  )
  ```

---

## DrawingAnnotation.Hatch

### `DrawingAnnotation.Hatch`

ISO 128-50 section-view hatching, a closed polygon filled with evenly-spaced parallel lines.

```swift
public struct Hatch: Sendable, Hashable {
    public var boundary: [SIMD2<Double>]     // closed polygon (first != last)
    public var angle: Double                 // radians; ISO default π/4 = 45°
    public var spacing: Double               // drawing units; ISO typical 2–4 mm
    public var islands: [[SIMD2<Double>]]    // inner holes (each closed polygon)
    public var layer: String                 // DXF layer, default "HATCH"
    public var id: String?
}
```

- `boundary`: vertices of the outer polygon (closed; first and last vertices must differ).
- `angle`: hatch line angle in radians (ISO default `π/4` = 45°).
- `spacing`: distance between hatch lines in drawing units (ISO typical 2–4 mm).
- `islands`: inner boundaries (holes) each as a closed polygon subtracted from the hatched region.
- `layer`: DXF layer name for the hatch entity (default `"HATCH"`).
- `id`: optional identifier.

*(Per-field anchors below, for cross-reference; the list above has the actual meaning of each.)*

#### `DrawingAnnotation.Hatch.spacing`

---

### `DrawingAnnotation.Hatch.init(boundary:angle:spacing:islands:layer:id:)`

Creates a hatch-fill annotation.

```swift
public init(boundary: [SIMD2<Double>],
            angle: Double = .pi / 4,
            spacing: Double = 3.0,
            islands: [[SIMD2<Double>]] = [],
            layer: String = "HATCH",
            id: String? = nil)
```

- **Parameters:**
  - `boundary`: outer polygon vertices (closed, first ≠ last).
  - `angle`: hatch angle in radians (default `π/4`).
  - `spacing`: line spacing in drawing units (default `3.0`).
  - `islands`: inner hole polygons (default `[]`).
  - `layer`: DXF layer name (default `"HATCH"`).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let hatch = DrawingAnnotation.hatch(
      DrawingAnnotation.Hatch(
          boundary: [
              SIMD2(0, 0), SIMD2(60, 0),
              SIMD2(60, 40), SIMD2(0, 40)
          ],
          angle: .pi / 4,
          spacing: 2.5
      )
  )
  ```

---

## DrawingAnnotation.Balloon

### `DrawingAnnotation.Balloon`

An assembly-drawing balloon callout: a numbered circle placed near a part, with an optional leader line. The `itemNumber` is expected to match a row in the drawing's `BillOfMaterials`.

```swift
public struct Balloon: Sendable, Hashable {
    public var itemNumber: Int
    public var centre: SIMD2<Double>
    public var radius: Double
    public var leaderTo: SIMD2<Double>?
    public var id: String?
}
```

- `itemNumber`: BOM row number shown inside the balloon circle.
- `centre`: centre of the balloon circle.
- `radius`: radius of the balloon circle (drawing units).
- `leaderTo`: optional target point for the leader line pointing from the balloon to the referenced part.
- `id`: optional identifier.

---

#### `DrawingAnnotation.Balloon.itemNumber`

BOM row number shown inside the balloon circle.

#### `DrawingAnnotation.Balloon.centre`

Centre of the balloon circle.

#### `DrawingAnnotation.Balloon.leaderTo`

Optional target point for the leader line pointing from the balloon to the referenced part; `nil` for no leader.

---

### `DrawingAnnotation.Balloon.init(itemNumber:centre:radius:leaderTo:id:)`

Creates a balloon callout annotation.

```swift
public init(itemNumber: Int,
            centre: SIMD2<Double>,
            radius: Double = 5,
            leaderTo: SIMD2<Double>? = nil,
            id: String? = nil)
```

- **Parameters:**
  - `itemNumber`: BOM item number (rendered as text inside the circle).
  - `centre`: balloon centre position.
  - `radius`: balloon circle radius (default `5` drawing units).
  - `leaderTo`: optional point the leader line points to; `nil` = no leader.
  - `id`: optional identifier.
- **Example:**
  ```swift
  let balloon = DrawingAnnotation.balloon(
      DrawingAnnotation.Balloon(
          itemNumber: 3,
          centre: SIMD2(120, 80),
          radius: 6,
          leaderTo: SIMD2(85, 60)
      )
  )
  ```

---

## DrawingAnnotation.Arc

### `DrawingAnnotation.Arc`

A single 2D arc primitive: centre, radius, start angle, end angle (radians), plus the DXF/PDF/SVG layer it renders to. General-purpose, unlike `centreline`/`centermark` (always the fixed `"CENTER"` layer); an arc's layer is caller-supplied. Used by `DrawingAnnotation.cosmeticThreadEndView(centre:majorDiameter:pitch:)` (`DrawingThreadAnnotation.swift`) for the ISO 6410 3/4 broken-arc thread end view (#1179).

```swift
public struct Arc: Sendable, Hashable {
    public var centre: SIMD2<Double>
    public var radius: Double
    public var startAngle: Double    // radians
    public var endAngle: Double      // radians
    public var layer: String
    public var id: String?
}
```

- `centre`: 2D arc centre.
- `radius`: arc radius.
- `startAngle`: start angle in radians.
- `endAngle`: end angle in radians.
- `layer`: DXF/PDF/SVG layer (default `"VISIBLE"`, matching `DrawingPrimitiveSink.addArc`'s own default).
- `id`: optional identifier.

---

### `DrawingAnnotation.Arc.init(centre:radius:startAngle:endAngle:layer:id:)`

Creates an arc annotation.

```swift
public init(centre: SIMD2<Double>,
            radius: Double,
            startAngle: Double,
            endAngle: Double,
            layer: String = "VISIBLE",
            id: String? = nil)
```

- **Parameters:**
  - `centre`: 2D arc centre.
  - `radius`: arc radius.
  - `startAngle`: start angle in radians.
  - `endAngle`: end angle in radians.
  - `layer`: DXF/PDF/SVG layer (default `"VISIBLE"`).
  - `id`: optional identifier.
- **Example:**
  ```swift
  let arc = DrawingAnnotation.arc(
      DrawingAnnotation.Arc(
          centre: SIMD2(30, 30), radius: 4,
          startAngle: 0, endAngle: .pi / 2,
          layer: "CENTER")
  )
  ```

---

## DrawingAnnotationStore

`internal final class DrawingAnnotationStore: @unchecked Sendable`, declared in this file. Not
part of the public API: `Drawing` holds one internally to accumulate the dimensions and
annotations added to it, guarded by an `NSLock` so the class can be marked `Sendable` despite its
mutable arrays. Read access is `dimensions`/`annotations` (both internal computed properties);
mutation goes through the three methods below.

```swift
```

```swift
```

```swift
```