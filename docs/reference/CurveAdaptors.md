---
title: Curve Adaptors & Wire Ordering
parent: API Reference
---

# Curve Adaptors & Wire Ordering

`WireCurve` and `EdgeCurve` wrap `BRepAdaptor_CompCurve` and `BRepAdaptor_Curve` respectively, exposing arc-length parameterization and uniform sampling over a multi-edge wire or a single edge. `WireOrder` wraps `ShapeAnalysis_WireOrder` to determine the connection order and required reversals for a set of disconnected edges.

## Topics

- [WireCurve](#wirecurve) · [EdgeCurve](#edgecurve) · [WireOrder](#wireorder)

---

## WireCurve

A multi-edge `Wire` treated as a single continuously-parameterized curve (`BRepAdaptor_CompCurve`). Provides total arc length and arc-length-based point/tangent sampling that walks across edge boundaries seamlessly.

```swift
public final class WireCurve: @unchecked Sendable
```

---

### `WireCurve.init?(_:)`

Builds an arc-length adaptor over a wire. Returns `nil` if the wire is empty or invalid.

```swift
public init?(_ wire: Wire)
```

- **Parameters:** `wire` — the wire to adapt.
- **Returns:** A `WireCurve` instance, or `nil` if the wire is empty/invalid.
- **OCCT:** `BRepAdaptor_CompCurve(const TopoDS_Wire&)` — constructs the composite-curve adaptor over the wire's edge sequence.
- **Example:**
  ```swift
  let rect = Wire.rectangle(width: 40, height: 20)!
  guard let wc = WireCurve(rect) else { return }
  print(wc.length)  // perimeter of the rectangle: 120
  ```

---

### `length`

Total arc length of the wire.

```swift
public var length: Double { get }
```

- **Returns:** Arc length in model units; `-1.0` on error.
- **OCCT:** `GCPnts_AbscissaPoint::Length(BRepAdaptor_CompCurve&)`.
- **Example:**
  ```swift
  let wc = WireCurve(Wire.rectangle(width: 10, height: 5)!)!
  print(wc.length)  // 30.0
  ```

---

### `parameterRange`

The native parameter range `[first, last]` of the composite curve.

```swift
public var parameterRange: (first: Double, last: Double) { get }
```

Use this range when calling `point(atParameter:)` or `tangent(atParameter:)`. The native parameter is not arc length — use `parameter(atAbscissa:)` to convert.

- **Returns:** Tuple of the adaptor's first and last native parameters.
- **OCCT:** `BRepAdaptor_CompCurve::FirstParameter()` / `LastParameter()`.
- **Example:**
  ```swift
  let wc = WireCurve(wire)!
  let (t0, t1) = wc.parameterRange
  let startPt = wc.point(atParameter: t0)
  let endPt   = wc.point(atParameter: t1)
  ```

---

### `point(atParameter:)`

3D point at a native curve parameter `u`.

```swift
public func point(atParameter u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — native parameter within `parameterRange`.
- **Returns:** 3D point, or `nil` on error (e.g. `u` out of range).
- **OCCT:** `BRepAdaptor_CompCurve::Value(u)`.
- **Example:**
  ```swift
  let wc = WireCurve(wire)!
  let (t0, _) = wc.parameterRange
  if let pt = wc.point(atParameter: t0) {
      print(pt)  // start vertex of the wire
  }
  ```

---

### `tangent(atParameter:)`

Unit tangent (first derivative, normalized) at a native parameter `u`.

```swift
public func tangent(atParameter u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — native parameter within `parameterRange`.
- **Returns:** Unit tangent vector, or `nil` at a degenerate point where the derivative magnitude is below 1e-12.
- **OCCT:** `BRepAdaptor_CompCurve::D1(u, point, d1)` then normalized via `gp_Dir`.
- **Example:**
  ```swift
  let wc = WireCurve(wire)!
  if let t = wc.tangent(atParameter: wc.parameterRange.first) {
      print(t)  // unit direction at the wire start
  }
  ```

---

### `parameter(atAbscissa:)`

Native parameter at arc length `s` measured from the start of the wire.

```swift
public func parameter(atAbscissa s: Double) -> Double?
```

- **Parameters:** `s` — arc length from the wire start (0...`length`).
- **Returns:** Native parameter `u`, or `nil` if `GCPnts_AbscissaPoint` does not converge.
- **OCCT:** `GCPnts_AbscissaPoint(BRepAdaptor_CompCurve&, s, FirstParameter())`.
- **Example:**
  ```swift
  let wc = WireCurve(wire)!
  if let u = wc.parameter(atAbscissa: wc.length / 2) {
      print(u)  // native parameter at the midpoint by arc length
  }
  ```

---

### `point(atAbscissa:)`

3D point at arc length `s` from the start of the wire.

```swift
public func point(atAbscissa s: Double) -> SIMD3<Double>?
```

Pure-Swift: calls `parameter(atAbscissa:)` then `point(atParameter:)`.

- **Parameters:** `s` — arc length offset (0...`length`).
- **Returns:** 3D point, or `nil` if the abscissa conversion or point evaluation fails.
- **Example:**
  ```swift
  let wc = WireCurve(Wire.rectangle(width: 40, height: 20)!)!
  let mid = wc.point(atAbscissa: wc.length / 2)
  ```

---

### `tangent(atAbscissa:)`

Unit tangent at arc length `s` from the start of the wire.

```swift
public func tangent(atAbscissa s: Double) -> SIMD3<Double>?
```

Pure-Swift: calls `parameter(atAbscissa:)` then `tangent(atParameter:)`.

- **Parameters:** `s` — arc length offset (0...`length`).
- **Returns:** Unit tangent vector, or `nil` if conversion or evaluation fails.
- **Example:**
  ```swift
  let wc = WireCurve(wire)!
  let quarterTangent = wc.tangent(atAbscissa: wc.length / 4)
  ```

---

### `points(count:)`

`count` points spaced equally by arc length along the wire, including both endpoints.

```swift
public func points(count: Int) -> [SIMD3<Double>]
```

One bridge call — cheaper than calling `point(atAbscissa:)` in a loop.

- **Parameters:** `count` — number of sample points (must be ≥ 2; returns `[]` if less).
- **Returns:** Array of `count` evenly-spaced 3D points; fewer if the bridge yields fewer results.
- **OCCT:** `GCPnts_UniformAbscissa(BRepAdaptor_CompCurve&, count)`.
- **Example:**
  ```swift
  let wc = WireCurve(profileWire)!
  let pts = wc.points(count: 21)  // 21 points including both endpoints
  ```

---

### `points(spacing:)`

Points spaced approximately `spacing` apart along the wire by arc length.

```swift
public func points(spacing: Double) -> [SIMD3<Double>]
```

Pure-Swift: computes `count = max(2, round(length / spacing) + 1)` then delegates to `points(count:)`. The exact step is adjusted so samples divide the wire evenly end-to-end.

- **Parameters:** `spacing` — target arc-length step in model units.
- **Returns:** Evenly-spaced points; empty array if `spacing <= 0` or `length == 0`.
- **Example:**
  ```swift
  let wc = WireCurve(wire)!
  let pts = wc.points(spacing: 5.0)  // one point every ~5 units
  ```

---

## EdgeCurve

A single `Edge` as an arc-length-parameterized curve (`BRepAdaptor_Curve`). Mirrors `WireCurve`'s API for a single edge — adds arc-length sampling (`length`, `point(atAbscissa:)`, `points(count:)`) on top of the edge's native parameter space.

```swift
public final class EdgeCurve: @unchecked Sendable
```

---

### `EdgeCurve.init?(_:)`

Builds an arc-length adaptor over an edge. Returns `nil` if the edge has no 3D curve or is otherwise invalid.

```swift
public init?(_ edge: Edge)
```

- **Parameters:** `edge` — the edge to adapt.
- **Returns:** An `EdgeCurve` instance, or `nil` if the edge is invalid.
- **OCCT:** `BRepAdaptor_Curve(const TopoDS_Edge&)` — initializes the curve adaptor from the edge's 3D geometry.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  let edges = box.edges()
  if let ec = EdgeCurve(edges[0]) {
      print(ec.length)
  }
  ```

---

### `length`

Arc length of the edge.

```swift
public var length: Double { get }
```

- **Returns:** Arc length in model units; `-1.0` on error.
- **OCCT:** `GCPnts_AbscissaPoint::Length(BRepAdaptor_Curve&)`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  print(ec.length)  // e.g. 10.0 for a unit-length straight edge
  ```

---

### `parameterRange`

The native parameter range `[first, last]` of the edge curve.

```swift
public var parameterRange: (first: Double, last: Double) { get }
```

- **Returns:** Tuple of the adaptor's first and last native parameters.
- **OCCT:** `BRepAdaptor_Curve::FirstParameter()` / `LastParameter()`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  let (t0, t1) = ec.parameterRange
  ```

---

### `point(atParameter:)`

3D point at a native curve parameter `u`.

```swift
public func point(atParameter u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — native parameter within `parameterRange`.
- **Returns:** 3D point, or `nil` on error.
- **OCCT:** `BRepAdaptor_Curve::Value(u)` → `gp_Pnt`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  if let pt = ec.point(atParameter: ec.parameterRange.first) {
      print(pt)
  }
  ```

---

### `tangent(atParameter:)`

Unit tangent at a native parameter `u`. Returns `nil` at a degenerate point.

```swift
public func tangent(atParameter u: Double) -> SIMD3<Double>?
```

- **Parameters:** `u` — native parameter within `parameterRange`.
- **Returns:** Unit tangent vector, or `nil` if the derivative magnitude is below 1e-12.
- **OCCT:** `BRepAdaptor_Curve::D1(u, point, d1)` then normalized via `gp_Dir`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  if let t = ec.tangent(atParameter: ec.parameterRange.first) {
      print(t)
  }
  ```

---

### `parameter(atAbscissa:)`

Native parameter at arc length `s` from the start of the edge.

```swift
public func parameter(atAbscissa s: Double) -> Double?
```

- **Parameters:** `s` — arc length offset (0...`length`).
- **Returns:** Native parameter `u`, or `nil` if the solver does not converge.
- **OCCT:** `GCPnts_AbscissaPoint(BRepAdaptor_Curve&, s, FirstParameter())`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  if let u = ec.parameter(atAbscissa: ec.length / 2) {
      print(u)
  }
  ```

---

### `point(atAbscissa:)`

3D point at arc length `s` from the start of the edge.

```swift
public func point(atAbscissa s: Double) -> SIMD3<Double>?
```

Pure-Swift: calls `parameter(atAbscissa:)` then `point(atParameter:)`.

- **Parameters:** `s` — arc length offset (0...`length`).
- **Returns:** 3D point, or `nil` if conversion or evaluation fails.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  let half = ec.point(atAbscissa: ec.length / 2)
  ```

---

### `tangent(atAbscissa:)`

Unit tangent at arc length `s` from the start of the edge.

```swift
public func tangent(atAbscissa s: Double) -> SIMD3<Double>?
```

Pure-Swift: calls `parameter(atAbscissa:)` then `tangent(atParameter:)`.

- **Parameters:** `s` — arc length offset (0...`length`).
- **Returns:** Unit tangent vector, or `nil` on failure.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  let t = ec.tangent(atAbscissa: 0)  // tangent at the start
  ```

---

### `points(count:)`

`count` points spaced equally by arc length along the edge, including both endpoints.

```swift
public func points(count: Int) -> [SIMD3<Double>]
```

One bridge call — cheaper than calling `point(atAbscissa:)` in a loop.

- **Parameters:** `count` — number of sample points (must be ≥ 2; returns `[]` if less).
- **Returns:** Array of up to `count` evenly-spaced 3D points.
- **OCCT:** `GCPnts_UniformAbscissa(BRepAdaptor_Curve&, count)`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  let pts = ec.points(count: 11)  // 11 equally-spaced points
  ```

---

### `points(spacing:)`

Points spaced approximately `spacing` apart along the edge by arc length.

```swift
public func points(spacing: Double) -> [SIMD3<Double>]
```

Pure-Swift: computes `count = max(2, round(length / spacing) + 1)` then delegates to `points(count:)`.

- **Parameters:** `spacing` — target arc-length step in model units.
- **Returns:** Evenly-spaced points; empty array if `spacing <= 0` or `length == 0`.
- **Example:**
  ```swift
  let ec = EdgeCurve(edge)!
  let pts = ec.points(spacing: 1.0)  // sample every ~1 unit
  ```

---

## WireOrder

Analyzes a set of edges — defined by their endpoint 3D coordinates — and determines the order and orientation in which they should be chained to form a continuous wire. Wraps `ShapeAnalysis_WireOrder`.

```swift
public struct WireOrder: Sendable
```

---

### `Status`

Classification of the edge-ordering analysis result.

```swift
public enum Status: Sendable {
    case closed
    case open
    case gaps
    case failed
}
```

- `.closed` — the edges form a closed loop (all endpoints connected, OCCT status 0).
- `.open` — the edges form an open chain (status 1).
- `.gaps` — at least one gap remains between edges after ordering (status 2).
- `.failed` — analysis could not complete (OCCT status < 0).

---

### `OrderedEdge`

A single entry in the ordered edge sequence returned by `WireOrder`.

```swift
public struct OrderedEdge: Sendable {
    public let originalIndex: Int
    public let isReversed: Bool
}
```

- `originalIndex` — 0-based index into the input `edges` array.
- `isReversed` — `true` if the edge must be traversed in the opposite direction to maintain continuity.

---

### `status`

Status of the ordering analysis.

```swift
public let status: Status
```

Check this before consuming `orderedEdges`; if `.failed`, the array is empty.

- **Example:**
  ```swift
  if let wo = WireOrder.analyze(edges: edges) {
      guard wo.status != .gaps else { print("wire has gaps"); return }
  }
  ```

---

### `orderedEdges`

The ordered sequence of edges forming the continuous chain.

```swift
public let orderedEdges: [OrderedEdge]
```

Each entry carries the `originalIndex` into the input array and whether the edge must be reversed. Empty if `status == .failed`.

- **Example:**
  ```swift
  if let wo = WireOrder.analyze(edges: rawEdges) {
      for e in wo.orderedEdges {
          print("edge \(e.originalIndex), reversed: \(e.isReversed)")
      }
  }
  ```

---

### `WireOrder.analyze(edges:tolerance:)`

Analyzes the ordering of edges defined by their start/end 3D points.

```swift
public static func analyze(edges: [(start: SIMD3<Double>, end: SIMD3<Double>)],
                            tolerance: Double = 1e-3) -> WireOrder?
```

Passes endpoint coordinates to the bridge, which populates a `ShapeAnalysis_WireOrder` instance and reads back the ordered edge list (OCCT returns 1-based, signed indices — negative means reversed; the Swift layer converts to 0-based).

- **Parameters:**
  - `edges` — array of `(start, end)` point pairs defining each edge.
  - `tolerance` — connection tolerance in model units (default 1e-3); endpoints within this distance are considered connected.
- **Returns:** A `WireOrder` value, or `nil` if `edges` is empty or the bridge fails entirely.
- **OCCT:** `ShapeAnalysis_WireOrder(true, tolerance)` — analycts the point sequence, then reads ordered indices via `IOrder(i)`.
- **Example:**
  ```swift
  let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
      (SIMD3(0, 0, 0),  SIMD3(10, 0, 0)),
      (SIMD3(10, 10, 0), SIMD3(0, 10, 0)),
      (SIMD3(0, 10, 0),  SIMD3(0, 0, 0)),
      (SIMD3(10, 0, 0),  SIMD3(10, 10, 0)),
  ]
  if let wo = WireOrder.analyze(edges: edges) {
      print(wo.status)          // .closed
      print(wo.orderedEdges)    // correct traversal order
  }
  ```

---

### `WireOrder.analyze(wire:tolerance:)`

Analyzes the edge ordering of an existing `Wire`.

```swift
public static func analyze(wire: Wire, tolerance: Double = 1e-3) -> WireOrder?
```

Extracts edge endpoint coordinates from the wire via the bridge (up to 1000 edges) and performs the same ordering analysis as `analyze(edges:tolerance:)`.

- **Parameters:**
  - `wire` — the wire whose edge ordering to analyze.
  - `tolerance` — connection tolerance in model units (default 1e-3).
- **Returns:** A `WireOrder` value, or `nil` if the bridge fails.
- **OCCT:** `ShapeAnalysis_WireOrder(true, tolerance)` — bridge extracts endpoints from each `TopoDS_Edge` in the wire before analysis.
- **Example:**
  ```swift
  let wire = Wire.polygon(points: [
      SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0)
  ])!
  if let wo = WireOrder.analyze(wire: wire) {
      print(wo.status)       // .closed or .open depending on wire
  }
  ```
