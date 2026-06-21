---
title: FeatureReconstructor
parent: API Reference
---

# FeatureReconstructor

`FeatureReconstructor` is a declarative feature-spec dispatcher: it consumes a sequence of typed `FeatureSpec` entries and produces a `Shape` via staged evaluation — additive (revolve, extrude, boolean union) → subtractive (hole, boolean subtract/intersect) → finishing (fillet, chamfer) → annotation (thread). Features are accumulated into a single evolving body; failures accumulate in `BuildResult.skipped` rather than aborting the build. Thread specs are emitted as metadata annotations rather than geometry.

Obtain a result by calling `FeatureReconstructor.build(from:inputBody:)` or the JSON variant `buildJSON(_:inputBody:)`. The returned `BuildResult` carries the final shape, fulfilled/skipped lists, thread annotations, and per-feature `ShapeHistoryRef` handles for downstream selection remapping.

## Topics

- [FeatureSpec](#featurespec) · [FeatureSpec.Revolve](#featurespecrevolve) · [FeatureSpec.Extrude](#featurespecextrude) · [FeatureSpec.Hole](#featurespechole) · [FeatureSpec.Thread](#featurespecthread) · [FeatureSpec.EdgeSelector](#featurespecedgeselector) · [FeatureSpec.Fillet](#featurespecfillet) · [FeatureSpec.Chamfer](#featurespecchamfer) · [FeatureSpec.Boolean](#featurespecboolean) · [FeatureReconstructor — Entry point](#featurereconstructor--entry-point) · [BuildResult](#buildresult) · [Skipped](#skipped) · [Annotation](#annotation) · [JSON front end](#json-front-end)

---

## FeatureSpec

### `FeatureSpec`

Discriminated union of every feature kind that `FeatureReconstructor` can dispatch.

```swift
public enum FeatureSpec: Sendable, Hashable, Codable {
    case revolve(Revolve)
    case extrude(Extrude)
    case hole(Hole)
    case thread(Thread)
    case fillet(Fillet)
    case chamfer(Chamfer)
    case boolean(Boolean)
}
```

Each case wraps a typed payload struct. The enum is `Codable` via the JSON front end.

---

### `FeatureSpec.id`

The optional user-supplied identifier for this feature.

```swift
public var id: String? { get }
```

Dispatches to the nested struct's `id` property. Features with a non-nil `id` are listed in `BuildResult.fulfilled` on success, in `BuildResult.skipped` on failure, and their output shapes are registered in the named-shape registry for downstream reference by boolean and fillet/chamfer `EdgeSelector.onFeature` selectors.

- **Returns:** `id` from the wrapped payload struct, or `nil` if none was supplied.
- **Example:**
  ```swift
  let spec = FeatureSpec.extrude(.init(
      profilePoints2D: pts,
      planeOrigin: .zero,
      planeNormal: SIMD3(0, 0, 1),
      length: 10,
      id: "base"))
  print(spec.id)  // "base"
  ```

---

## FeatureSpec.Revolve

### `FeatureSpec.Revolve`

Parameters for a revolve (lathe) operation: a 2D profile swept around an axis.

```swift
public struct Revolve: Sendable, Hashable, Codable {
    public var profilePoints2D: [SIMD2<Double>]
    public var axisOrigin: SIMD3<Double>
    public var axisDirection: SIMD3<Double>
    public var angleDeg: Double
    public var id: String?
}
```

The 2D profile is interpreted in the XZ half-plane: each `SIMD2<Double>` point `(x, y)` maps to 3D `(x, 0, y)`. The profile must have at least 3 points.

---

### `FeatureSpec.Revolve.init(profilePoints2D:axisOrigin:axisDirection:angleDeg:id:)`

Creates a revolve specification.

```swift
public init(profilePoints2D: [SIMD2<Double>],
            axisOrigin: SIMD3<Double>,
            axisDirection: SIMD3<Double>,
            angleDeg: Double = 360,
            id: String? = nil)
```

- **Parameters:**
  - `profilePoints2D` — profile polygon in the XZ half-plane (minimum 3 points).
  - `axisOrigin` — a point on the revolution axis.
  - `axisDirection` — unit vector defining the revolution axis direction.
  - `angleDeg` — sweep angle in degrees (default `360` for a full revolution).
  - `id` — optional feature identifier; used to track the feature in `BuildResult`.
- **OCCT:** Dispatched to `Shape.revolve(profile:axisOrigin:axisDirection:angle:)` → `BRepPrimAPI_MakeRevol`.
- **Example:**
  ```swift
  let profile: [SIMD2<Double>] = [.init(0, 0), .init(5, 0), .init(5, 10), .init(0, 10)]
  let rev = FeatureSpec.Revolve(
      profilePoints2D: profile,
      axisOrigin: .zero,
      axisDirection: SIMD3(0, 0, 1),
      angleDeg: 360,
      id: "rotor")
  ```

---

## FeatureSpec.Extrude

### `FeatureSpec.Extrude`

Parameters for a linear extrusion: a 2D profile lifted off a plane by a given length.

```swift
public struct Extrude: Sendable, Hashable, Codable {
    public var profilePoints2D: [SIMD2<Double>]
    public var planeOrigin: SIMD3<Double>
    public var planeNormal: SIMD3<Double>
    public var length: Double
    public var id: String?
}
```

The 2D profile is projected into 3D using a `Placement` derived from `planeOrigin` and `planeNormal`. The profile must have at least 3 points.

---

### `FeatureSpec.Extrude.init(profilePoints2D:planeOrigin:planeNormal:length:id:)`

Creates an extrude specification.

```swift
public init(profilePoints2D: [SIMD2<Double>],
            planeOrigin: SIMD3<Double>,
            planeNormal: SIMD3<Double>,
            length: Double,
            id: String? = nil)
```

- **Parameters:**
  - `profilePoints2D` — profile polygon in the plane's local 2D coordinate system (minimum 3 points).
  - `planeOrigin` — origin of the sketch plane in 3D.
  - `planeNormal` — unit normal of the sketch plane; also the extrusion direction.
  - `length` — extrusion distance in model units.
  - `id` — optional feature identifier.
- **OCCT:** Dispatched to `Shape.extrude(profile:direction:length:)` → `BRepPrimAPI_MakePrism`.
- **Example:**
  ```swift
  let pts: [SIMD2<Double>] = [.init(-5, -5), .init(5, -5), .init(5, 5), .init(-5, 5)]
  let ext = FeatureSpec.Extrude(
      profilePoints2D: pts,
      planeOrigin: .zero,
      planeNormal: SIMD3(0, 0, 1),
      length: 20,
      id: "block")
  ```

---

## FeatureSpec.Hole

### `FeatureSpec.Hole`

Parameters for a drilled hole: a cylindrical cutter subtracted from the current body.

```swift
public struct Hole: Sendable, Hashable, Codable {
    public var axisPoint: SIMD3<Double>
    public var axisDirection: SIMD3<Double>
    public var diameter: Double
    public var depth: Double?
    public var id: String?
}
```

When `depth` is `nil`, a through-hole cutter of depth `100.0` is used (sufficient for most models). Supply an explicit `depth` to limit the cutter.

---

### `FeatureSpec.Hole.init(axisPoint:axisDirection:diameter:depth:id:)`

Creates a hole specification.

```swift
public init(axisPoint: SIMD3<Double>,
            axisDirection: SIMD3<Double>,
            diameter: Double,
            depth: Double? = nil,
            id: String? = nil)
```

- **Parameters:**
  - `axisPoint` — a point on the hole axis (typically the centre of the entry face).
  - `axisDirection` — unit vector pointing into the material along the hole axis.
  - `diameter` — hole diameter in model units; the cutter radius is `diameter / 2`.
  - `depth` — axial depth of the cutter (default: `100.0` — effectively a through-hole).
  - `id` — optional feature identifier; when set, the result's `ShapeHistoryRef` is stored in `BuildResult.histories` for selection remapping.
- **OCCT:** `Shape.cylinder(at:direction:radius:height:)` → `BRepPrimAPI_MakeCylinder`, then `Shape.subtractedWithFullHistory(_:)` → `BRepAlgoAPI_Cut` with history recording.
- **Example:**
  ```swift
  let hole = FeatureSpec.Hole(
      axisPoint: SIMD3(5, 5, 10),
      axisDirection: SIMD3(0, 0, -1),
      diameter: 6,
      depth: 12,
      id: "m6-hole")
  ```

---

## FeatureSpec.Thread

### `FeatureSpec.Thread`

Annotation spec that records a thread callout referencing a named hole feature.

```swift
public struct Thread: Sendable, Hashable, Codable {
    public var holeRef: String
    public var spec: String    // "M5x0.8", "1/4-20 UNC"
    public var length: Double?
    public var id: String?
}
```

Thread specs produce `Annotation` entries in `BuildResult.annotations` rather than actual thread geometry. To produce real thread geometry, call `Shape.threadedHole(...)` or `Shape.threadedShaft(...)` directly.

---

### `FeatureSpec.Thread.init(holeRef:spec:length:id:)`

Creates a thread annotation specification.

```swift
public init(holeRef: String, spec: String, length: Double? = nil, id: String? = nil)
```

- **Parameters:**
  - `holeRef` — the `id` of the `FeatureSpec.Hole` this thread annotates; must match a feature id in the same spec array.
  - `spec` — thread designation string such as `"M5x0.8"` or `"1/4-20 UNC"`. Not parsed — stored verbatim in the annotation.
  - `length` — threaded engagement length; `nil` means unspecified.
  - `id` — optional feature identifier for the annotation itself.
- **Example:**
  ```swift
  let thread = FeatureSpec.Thread(
      holeRef: "m6-hole",
      spec: "M6x1",
      length: 10,
      id: "m6-thread")
  ```

---

## FeatureSpec.EdgeSelector

### `FeatureSpec.EdgeSelector`

Selects which edges of the current body to fillet or chamfer.

```swift
public enum EdgeSelector: Sendable, Hashable, Codable {
    case all
    case nearPoint(SIMD3<Double>, tolerance: Double)
    case onFeature(String)
}
```

- `.all` — selects every edge of the current body via `Shape.subShapes(ofType: .edge)`.
- `.nearPoint(point, tolerance:)` — selects edges whose midpoint lies within `tolerance` of the given 3D point.
- `.onFeature(id)` — selects edges of the current body whose midpoints coincide (within 1e-4) with edge midpoints of the named feature's output shape. Requires the referenced feature id to be registered in the named-shape registry.

---

## FeatureSpec.Fillet

### `FeatureSpec.Fillet`

Parameters for a constant-radius fillet applied to selected edges.

```swift
public struct Fillet: Sendable, Hashable, Codable {
    public var edgeSelector: EdgeSelector
    public var radius: Double
    public var id: String?
}
```

The fillet stage runs after all additive and subtractive features. History recording is used when `id` is set.

---

### `FeatureSpec.Fillet.init(edgeSelector:radius:id:)`

Creates a fillet specification.

```swift
public init(edgeSelector: EdgeSelector, radius: Double, id: String? = nil)
```

- **Parameters:**
  - `edgeSelector` — which edges to fillet (see `EdgeSelector`).
  - `radius` — fillet radius in model units.
  - `id` — optional feature identifier; the `ShapeHistoryRef` is stored in `BuildResult.histories` when set.
- **OCCT:** `Shape.filletedWithFullHistory(radius:edges:)` → `BRepFilletAPI_MakeFillet` with history recording; falls back to `Shape.filleted(radius:)` or `Shape.filleted(edges:radius:)`.
- **Example:**
  ```swift
  let fillet = FeatureSpec.Fillet(
      edgeSelector: .nearPoint(SIMD3(0, 0, 20), tolerance: 1.0),
      radius: 2.0,
      id: "top-fillet")
  ```

---

## FeatureSpec.Chamfer

### `FeatureSpec.Chamfer`

Parameters for a constant-distance chamfer applied to selected edges.

```swift
public struct Chamfer: Sendable, Hashable, Codable {
    public var edgeSelector: EdgeSelector
    public var distance: Double
    public var id: String?
}
```

The chamfer stage runs after all additive and subtractive features, alongside fillet. History recording is used when `id` is set.

---

### `FeatureSpec.Chamfer.init(edgeSelector:distance:id:)`

Creates a chamfer specification.

```swift
public init(edgeSelector: EdgeSelector, distance: Double, id: String? = nil)
```

- **Parameters:**
  - `edgeSelector` — which edges to chamfer (see `EdgeSelector`).
  - `distance` — chamfer distance in model units.
  - `id` — optional feature identifier; the `ShapeHistoryRef` is stored in `BuildResult.histories` when set.
- **OCCT:** `Shape.chamferedWithFullHistory(distance:edges:)` → `BRepFilletAPI_MakeChamfer` with history recording; falls back to `Shape.chamfered(distance:)` for the `.all` case.
- **Example:**
  ```swift
  let chamfer = FeatureSpec.Chamfer(
      edgeSelector: .all,
      distance: 1.0,
      id: "all-chamfer")
  ```

---

## FeatureSpec.Boolean

### `FeatureSpec.Boolean`

Parameters for a binary boolean operation between two named shapes.

```swift
public struct Boolean: Sendable, Hashable, Codable {
    public enum Op: String, Sendable, Codable { case union, subtract, intersect }
    public var op: Op
    public var leftID: String
    public var rightID: String
    public var id: String?
}
```

Both `leftID` and `rightID` must reference feature ids already registered in the named-shape registry. Union booleans run in the additive stage; subtract and intersect run in the subtractive stage. The result is registered under `id` if set.

---

### `FeatureSpec.Boolean.init(op:leftID:rightID:id:)`

Creates a boolean specification.

```swift
public init(op: Op, leftID: String, rightID: String, id: String? = nil)
```

- **Parameters:**
  - `op` — the boolean operation: `.union`, `.subtract`, or `.intersect`.
  - `leftID` — feature id of the left (base) operand.
  - `rightID` — feature id of the right (tool) operand.
  - `id` — optional feature identifier for the result.
- **OCCT:** `Shape.unionWithFullHistory(_:)` → `BRepAlgoAPI_Fuse`; `Shape.subtractedWithFullHistory(_:)` → `BRepAlgoAPI_Cut`; `Shape.intersectionWithFullHistory(_:)` → `BRepAlgoAPI_Common`. All with history recording when `id` is set.
- **Example:**
  ```swift
  let merge = FeatureSpec.Boolean(
      op: .union,
      leftID: "block",
      rightID: "boss",
      id: "merged")
  ```

---

## FeatureReconstructor — Entry point

### `FeatureReconstructor.inputBodySentinel`

Sentinel key under which an `inputBody` is registered in the named-shape registry.

```swift
public static let inputBodySentinel = "@input"
```

Boolean operands, `EdgeSelector.onFeature` selectors, and any other feature spec that references a named shape can use this key (the literal string `"@input"`) to address the starting body supplied to `build(from:inputBody:)`. The leading `@` keeps it disjoint from typical feature ids; a feature with `id: "@input"` shadows it.

---

### `FeatureReconstructor.build(from:inputBody:)`

Dispatches a sequence of feature specs and returns the assembled shape.

```swift
public static func build(
    from specs: [FeatureSpec],
    inputBody: Shape? = nil
) -> BuildResult
```

Processes `specs` in four fixed stages, iterating the full array once per stage:
1. **Additive** — revolve, extrude, boolean union.
2. **Subtractive** — hole, boolean subtract/intersect.
3. **Finishing** — fillet, chamfer.
4. **Annotation** — thread (metadata only, no geometry).

Within each stage, features are processed in array order. Failures append to `BuildResult.skipped` rather than aborting remaining specs. The first additive feature seeds `current`; subsequent additive features are unioned into it via `Shape.unionWithFullHistory` or `Shape.union`.

- **Parameters:**
  - `specs` — ordered array of `FeatureSpec` values to dispatch.
  - `inputBody` — optional starting body; registered under `inputBodySentinel` and used as `current` before any additive features run.
- **Returns:** `BuildResult` with the final shape, fulfilled/skipped lists, annotations, and per-feature history refs.
- **Example:**
  ```swift
  let specs: [FeatureSpec] = [
      .extrude(.init(profilePoints2D: [.init(-10,-10), .init(10,-10),
                                       .init(10,10), .init(-10,10)],
                     planeOrigin: .zero, planeNormal: SIMD3(0,0,1),
                     length: 20, id: "block")),
      .hole(.init(axisPoint: .zero, axisDirection: SIMD3(0,0,-1),
                  diameter: 8, id: "center-hole")),
      .fillet(.init(edgeSelector: .all, radius: 1.5))
  ]
  let result = FeatureReconstructor.build(from: specs)
  if let shape = result.shape {
      print("built \(result.fulfilled.count) features")
  }
  if !result.skipped.isEmpty {
      print("skipped: \(result.skipped.map { $0.featureID })")
  }
  ```

---

## BuildResult

### `FeatureReconstructor.BuildResult`

The outcome of a `build` or `buildJSON` call.

```swift
public struct BuildResult: Sendable {
    public let shape: Shape?
    public let fulfilled: [String]
    public let skipped: [Skipped]
    public let annotations: [Annotation]
    public let histories: [String: ShapeHistoryRef]
}
```

- `shape` — the assembled body, or `nil` if no additive or subtractive feature succeeded (e.g. every spec failed or the input was empty).
- `fulfilled` — ids of features that completed successfully, in dispatch order.
- `skipped` — diagnostics for features that failed (see `Skipped`).
- `annotations` — thread callout metadata from `.thread` specs.
- `histories` — per-feature `ShapeHistoryRef` keyed by feature id. Only features with a non-nil id that used a history-recording builder are present. Use `histories["id"]?.record(of: face)` to walk selection ids across chained operations.

---

## Skipped

### `FeatureReconstructor.Skipped`

Diagnostic entry for a feature that could not be applied.

```swift
public struct Skipped: Sendable {
    public let featureID: String
    public let reason: Reason
    public let stage: Stage
}
```

Only features with a non-nil `id` produce a `Skipped` entry; anonymous features fail silently (their shape contribution is lost but no diagnostic is emitted).

---

### `FeatureReconstructor.Skipped.Reason`

Why a feature was skipped.

```swift
public enum Reason: Sendable {
    case underDetermined(String)
    case occtFailure(String)
    case unresolvedRef(String)
    case unsupported(String)
}
```

- `.underDetermined(message)` — the spec is geometrically incomplete (e.g. fewer than 3 profile points, or no current body exists for a subtractive or finishing op).
- `.occtFailure(message)` — the OCCT builder returned `nil` or failed (wire construction, revolve, extrude, boolean, fillet, chamfer).
- `.unresolvedRef(message)` — a `leftID`, `rightID`, or `EdgeSelector.onFeature` id was not found in the named-shape registry.
- `.unsupported(message)` — the JSON front end encountered an unknown `kind` string or unrecognised boolean op.

---

### `FeatureReconstructor.Skipped.Stage`

The build stage in which the feature was skipped.

```swift
public enum Stage: String, Sendable { case additive, subtractive, finishing, annotation }
```

Mirrors the four evaluation stages: `additive`, `subtractive`, `finishing`, `annotation`.

---

## Annotation

### `FeatureReconstructor.Annotation`

A metadata annotation emitted by a `.thread` spec.

```swift
public struct Annotation: Sendable {
    public let kind: Kind
    public let featureID: String
}
```

Annotations carry no geometry — they describe intent (e.g. "this hole has an M6×1 thread"). Generate actual thread geometry by calling `Shape.threadedHole` or `Shape.threadedShaft` separately.

---

### `FeatureReconstructor.Annotation.Kind`

The annotation's content.

```swift
public enum Kind: Sendable {
    case thread(spec: String, holeRef: String, length: Double?)
}
```

Currently the only case is `.thread`:
- `spec` — verbatim thread designation string (`"M6x1"`, `"1/4-20 UNC"`, etc.).
- `holeRef` — the feature id of the associated hole.
- `length` — engagement length, if specified.

---

## JSON front end

### `FeatureReconstructor.buildJSON(_:inputBody:)`

Parses a JSON feature list and dispatches it, reporting unknown `kind` values as skipped entries.

```swift
public static func buildJSON(
    _ data: Data,
    inputBody: Shape? = nil
) throws -> BuildResult
```

Expects a top-level JSON object with a `"features"` array of `kind`-discriminated objects. Recognised kinds: `"revolve"`, `"extrude"`, `"hole"`, `"thread"`, `"fillet"`, `"chamfer"`, `"boolean"`. Unknown `kind` values are surfaced as `Skipped` entries with reason `.unsupported("unknown JSON kind: <kind>")` rather than silently dropped — callers can detect typos and schema drift.

JSON field names use snake_case: `profile_points_2d`, `axis_origin`, `axis_direction`, `plane_origin`, `plane_normal`, `angle_deg`, `axis_point`, `hole_ref`, `thread_spec` (for the thread spec string), `left`, `right`.

- **Parameters:**
  - `data` — UTF-8 JSON data conforming to the `{"features": [...]}` envelope.
  - `inputBody` — optional starting body (same semantics as `build(from:inputBody:)`).
- **Returns:** `BuildResult` with augmented skipped list for unknown kinds.
- **Throws:** `DecodingError` if the JSON envelope is malformed or a recognised kind is missing required fields.
- **Example:**
  ```swift
  let json = """
  {
    "features": [
      {
        "kind": "extrude",
        "profile_points_2d": [[-5,-5],[5,-5],[5,5],[-5,5]],
        "plane_origin": [0,0,0],
        "plane_normal": [0,0,1],
        "length": 20,
        "id": "block"
      },
      {
        "kind": "hole",
        "axis_point": [0,0,20],
        "axis_direction": [0,0,-1],
        "diameter": 6,
        "id": "bore"
      }
    ]
  }
  """.data(using: .utf8)!
  if let result = try? FeatureReconstructor.buildJSON(json),
     let shape = result.shape {
      print(shape.isValid)
  }
  ```
- **Note:** The JSON `fillet` and `chamfer` entries decoded by this front end always use `EdgeSelector.all` — there is no JSON syntax for `.nearPoint` or `.onFeature` in the current schema.
