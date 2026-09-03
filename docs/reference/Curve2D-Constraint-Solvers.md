---
title: Curve2D. Constraint Solvers
parent: API Reference
---

# Curve2D. Constraint Solvers

These APIs implement 2D geometric-constraint solving: qualifier-based circle and line construction (the GCC/Geom2dGcc tangency families), analytical and approximate bisector curves, and parallel hatch generation. For the core `Curve2D` type (primitive curves, BSpline/Bezier, evaluation, local properties), see the main `Curve2D` pages.

## Topics

- [Bisector (Geom2d)](#bisector-geom2d) · [Result Types](#result-types) · [Gcc Constraint Solver, Enums and Solution Types](#gcc-constraint-solver--enums-and-solution-types) · [Circle Construction (Geom2dGcc)](#circle-construction-geom2dgcc) · [Line Construction (Geom2dGcc)](#line-construction-geom2dgcc) · [Hatching](#hatching) · [GccAna Bisectors](#gccana-bisectors) · [GccAna Line Solvers](#gccana-line-solvers) · [GccAna Circle On-Constraint Solvers](#gccana-circle-on-constraint-solvers) · [Geom2dGcc Circle On-Constraint Solvers](#geom2dgcc-circle-on-constraint-solvers) · [Bisector_BisecAna](#bisector_bisecana)

---

## Bisector (Geom2d)

These members live on `Curve2D` (instance methods) and wrap the approximate `Bisector_BisecCC` / `Bisector_BisecPC` classes. For the analytical counterpart see [Bisector_BisecAna](#bisector_bisecana) below.

### `bisector(with:origin:side:)`

Computes the approximate bisector curve between this curve and another.

```swift
public func bisector(with other: Curve2D, origin: SIMD2<Double>,
                     side: Bool = true) -> Curve2D?
```

The bisector is the locus of points equidistant from both curves. `origin` steers which branch is returned; `side` controls orientation sense.

- **Parameters:** `other`, the second curve; `origin`, point near the desired branch; `side`, orientation sense.
- **Returns:** Bisector as a `Curve2D`, or `nil` on failure.
- **OCCT:** `Bisector_BisecCC`.
- **Example:**
  ```swift
  let c1 = Curve2D.circle(center: .zero, radius: 3)!
  let c2 = Curve2D.circle(center: SIMD2(6, 0), radius: 2)!
  if let bis = c1.bisector(with: c2, origin: SIMD2(3, 0)) {
      let pt = bis.point(at: bis.parameterRange!.lowerBound)
  }
  ```

---

### `bisector(withPoint:maxDistance:side:)`

Computes the approximate bisector curve between a point and this curve.

```swift
public func bisector(withPoint point: SIMD2<Double>, maxDistance: Double = 500,
                     side: Bool = true) -> Curve2D?
```

There is no `origin`, unlike the curve-to-curve sibling above: `Bisector_BisecPC::Perform` takes `(Cu, P, Side, DistMax)` and no origin at all. The signature had been copied from `Bisector_BisecCC::Perform`, where the origin is real.

- **Parameters:** `point`, the fixed point; `maxDistance`, trims the bisector so no point on it lies further than this from the curve, 500 being OCCT's own default; `side`, orientation sense.
- **Returns:** Bisector as a `Curve2D`, or `nil` when nothing lies within `maxDistance`.
- **OCCT:** `Bisector_BisecPC`.
- **Example:**
  ```swift
  let line = Curve2D.line(through: .zero, direction: SIMD2(1, 0))!
  line.bisector(withPoint: SIMD2(0, 4), maxDistance: 10)    // parametrised over [-8, 8]
  line.bisector(withPoint: SIMD2(0, 4), maxDistance: 100)   // parametrised over [-28, 28]
  line.bisector(withPoint: SIMD2(0, 4), maxDistance: 1)     // nil, nothing lies that close
  ```

---

## Result Types

Shared value types used by the constraint-solver and analysis APIs.

### `Curve2DIntersection`

An intersection point between two 2D curves.

```swift
public struct Curve2DIntersection: Sendable {
    public let point: SIMD2<Double>
    public let parameter1: Double
    public let parameter2: Double
}
```

- `point`: the 2D intersection point.
- `parameter1`: curve parameter on the first curve.
- `parameter2`: curve parameter on the second curve.

---

### `Curve2DProjection`

A projection of a point onto a 2D curve.

```swift
public struct Curve2DProjection: Sendable {
    public let point: SIMD2<Double>
    public let parameter: Double
    public let distance: Double
}
```

- `point`: projected point on the curve.
- `parameter`: curve parameter at the projected point.
- `distance`: distance from the original point to the curve.

---

### `Curve2DExtremaResult`

A distance extremum between two 2D curves.

```swift
public struct Curve2DExtremaResult: Sendable {
    public let pointOnCurve1: SIMD2<Double>
    public let pointOnCurve2: SIMD2<Double>
    public let parameter1: Double
    public let parameter2: Double
    public let distance: Double
}
```

---

### `Curve2DSpecialPointType`

Type of a special point on a curve.

```swift
public enum Curve2DSpecialPointType: Int32, Sendable {
    case inflection    = 0
    case minCurvature  = 1
    case maxCurvature  = 2
}
```

---

### `Curve2DSpecialPoint`

A special point (inflection or curvature extremum) on a 2D curve.

```swift
public struct Curve2DSpecialPoint: Sendable {
    public let parameter: Double
    public let type: Curve2DSpecialPointType
}
```

---

## Gcc Constraint Solver. Enums and Solution Types

Types used throughout both the `Geom2dGcc` and `GccAna` solver families.

### `Curve2DQualifier`

Qualifier for how a curve participates in a geometric constraint.

```swift
public enum Curve2DQualifier: Int32, Sendable {
    case unqualified = 0
    case enclosing   = 1
    case enclosed    = 2
    case outside     = 3
}
```

- `unqualified`: solution position relative to the curve is unconstrained.
- `enclosing`: the solution circle encloses the qualified curve.
- `enclosed`: the solution circle is enclosed by the qualified curve.
- `outside`: the solution circle is outside the qualified curve.

Pass these alongside curves in every `Curve2DGcc` solver call.

---

#### `Curve2DQualifier.outside`

The solution circle is outside the qualified curve.

---

### `Curve2DCircleSolution`

A circle solution from the Gcc constraint solver.

```swift
public struct Curve2DCircleSolution: Sendable {
    public let center: SIMD2<Double>
    public let radius: Double
}
```

---

### `Curve2DLineSolution`

A line solution from the Gcc constraint solver.

```swift
public struct Curve2DLineSolution: Sendable {
    public let point: SIMD2<Double>
    public let direction: SIMD2<Double>
}
```

- `point`: a point on the line.
- `direction`: unit direction vector of the line.

---

### `Curve2DHatchSegment`

A hatch segment produced by the hatching algorithm.

```swift
public struct Curve2DHatchSegment: Sendable {
    public let start: SIMD2<Double>
    public let end: SIMD2<Double>
}
```

- `start`: start point of the hatch line segment.
- `end`: end point of the hatch line segment.

#### `Curve2DHatchSegment.end`

---

### `HatchSegment`

A line segment in the general-purpose 2D hatch pattern generator, `HatchPattern.generate(boundary:direction:spacing:offset:islands:maxSegments:)` (`Sources/OCCTSwift/HatchPattern.swift`). Structurally identical to `Curve2DHatchSegment` above but produced by the polygon-boundary hatcher rather than the `Geom2dHatch_Hatcher`-backed `Curve2DGcc.hatch(boundaries:...)`.

```swift
public struct HatchSegment: Sendable {
    public let start: SIMD2<Double>
    public let end: SIMD2<Double>
}
```

- `start`: start point of the hatch line segment.
- `end`: end point of the hatch line segment.

#### `HatchSegment.end`

---

## Circle Construction (Geom2dGcc)

Members of `Curve2DGcc` that find circles satisfying tangency, point, and radius constraints using the `Geom2dGcc` package. All return an array of solutions (may be empty if no solution exists).

### `Curve2DGcc.circlesTangentTo(_:_:_:_:_:_:tolerance:)`

Finds circles tangent to three curves.

```swift
public static func circlesTangentTo(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    _ c3: Curve2D, _ q3: Curve2DQualifier = .unqualified,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

Up to 8 solutions (Apollonius problem for general curves).

- **Parameters:** `c1`–`c3`, three curves; `q1`–`q3`, qualifiers for each; `tolerance`, solver tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2d3Tan`.
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentTo(
      arcA, .outside, arcB, .outside, arcC, .outside)
  for sol in circles {
      print("center:", sol.center, "radius:", sol.radius)
  }
  ```

---

### `Curve2DGcc.circlesTangentToTwoCurvesAndPoint(_:_:_:_:point:tolerance:)`

Finds circles tangent to two curves and passing through a point.

```swift
public static func circlesTangentToTwoCurvesAndPoint(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    point: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `c1`, `c2`, curves; `q1`, `q2`, qualifiers; `point`, pass-through point; `tolerance`, tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2d3Tan` (two-curve + point variant).
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentToTwoCurvesAndPoint(
      c1, .unqualified, c2, .unqualified, point: SIMD2(5, 0))
  ```

---

### `Curve2DGcc.circlesTangentWithCenter(_:_:center:tolerance:)`

Finds circles tangent to a curve with a given center point.

```swift
public static func circlesTangentWithCenter(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    center: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

The center is fixed; the radius is determined by the tangency condition.

- **Parameters:** `curve`, the curve; `qualifier`, qualifier; `center`, fixed center; `tolerance`, tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2dTanCen`.
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentWithCenter(
      ellipse, .outside, center: SIMD2(0, 8))
  ```

---

### `Curve2DGcc.circlesTangentToTwoCurves(_:_:_:_:radius:tolerance:)`

Finds circles tangent to two curves with a given radius.

```swift
public static func circlesTangentToTwoCurves(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    radius: Double,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `c1`, `c2`, curves; `q1`, `q2`, qualifiers; `radius`, fixed radius; `tolerance`, tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2d2TanRad`.
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentToTwoCurves(
      c1, .unqualified, c2, .unqualified, radius: 3)
  for sol in circles {
      print(sol.center, sol.radius)
  }
  ```

---

### `Curve2DGcc.circlesTangentToPointWithRadius(_:_:point:radius:tolerance:)`

Finds circles tangent to a curve, passing through a point, with a given radius.

```swift
public static func circlesTangentToPointWithRadius(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    point: SIMD2<Double>, radius: Double,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `curve`, tangent curve; `qualifier`, qualifier; `point`, pass-through point; `radius`, fixed radius; `tolerance`, tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2d2TanRad` (curve + point variant).
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentToPointWithRadius(
      arc, .outside, point: SIMD2(10, 0), radius: 2)
  ```

---

### `Curve2DGcc.circlesThroughTwoPoints(_:_:radius:tolerance:)`

Finds circles through two points with a given radius.

```swift
public static func circlesThroughTwoPoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
    radius: Double,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `p1`, `p2`, two pass-through points; `radius`, fixed radius; `tolerance`, tolerance.
- **Returns:** Array of circle solutions (0, 1, or 2).
- **OCCT:** `Geom2dGcc_Circ2d2TanRad` (point + point variant).
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesThroughTwoPoints(
      SIMD2(0, 0), SIMD2(4, 0), radius: 3)
  ```

---

### `Curve2DGcc.circleThroughThreePoints(_:_:_:tolerance:)`

Finds the circle through three points.

```swift
public static func circleThroughThreePoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>, _ p3: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

Returns at most one solution (the circumscribed circle of the three points).

- **Parameters:** `p1`, `p2`, `p3`, three non-collinear points; `tolerance`, tolerance.
- **Returns:** Array with 0 or 1 solution.
- **OCCT:** `Geom2dGcc_Circ2d3Tan` (three-point variant).
- **Example:**
  ```swift
  let circles = Curve2DGcc.circleThroughThreePoints(
      SIMD2(0, 0), SIMD2(4, 0), SIMD2(2, 3))
  if let c = circles.first {
      print("circumcircle radius:", c.radius)
  }
  ```

---

## Line Construction (Geom2dGcc)

### `Curve2DGcc.linesTangentTo(_:_:_:_:tolerance:)`

Finds lines tangent to two curves.

```swift
public static func linesTangentTo(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    tolerance: Double = 1e-6
) -> [Curve2DLineSolution]
```

- **Parameters:** `c1`, `c2`, curves; `q1`, `q2`, qualifiers; `tolerance`, tolerance.
- **Returns:** Array of line solutions.
- **OCCT:** `Geom2dGcc_Lin2d2Tan`.
- **Example:**
  ```swift
  let lines = Curve2DGcc.linesTangentTo(circleA, .outside, circleB, .outside)
  for l in lines {
      print("through:", l.point, "dir:", l.direction)
  }
  ```

---

### `Curve2DGcc.linesTangentToPoint(_:_:point:tolerance:)`

Finds lines tangent to a curve and passing through a point.

```swift
public static func linesTangentToPoint(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    point: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DLineSolution]
```

- **Parameters:** `curve`, the curve; `qualifier`, qualifier; `point`, pass-through point; `tolerance`, tolerance.
- **Returns:** Array of line solutions (typically 0 or 2 for a circle).
- **OCCT:** `Geom2dGcc_Lin2d2Tan` (curve + point variant).
- **Example:**
  ```swift
  let circle = Curve2D.circle(center: .zero, radius: 4)!
  let tangents = Curve2DGcc.linesTangentToPoint(circle, .outside, point: SIMD2(10, 0))
  ```

---

## Hatching

### `Curve2DGcc.hatch(boundaries:origin:direction:spacing:tolerance:)`

Generates parallel hatch lines clipped to a region bounded by curves.

```swift
public static func hatch(boundaries: [Curve2D],
                         origin: SIMD2<Double> = .zero,
                         direction: SIMD2<Double> = SIMD2(1, 0),
                         spacing: Double,
                         tolerance: Double = 1e-6) -> [Curve2DHatchSegment]
```

Each `Curve2DHatchSegment` is a line segment clipped to lie inside the boundary region. The boundary curves must form a single closed region, walked in the order given; they may wind either clockwise or counter-clockwise, the winding sense is detected from the geometry and does not need to be specified (#1496). The algorithm uses `Geom2dHatch_Hatcher` internally.

- **Parameters:** `boundaries`, closed boundary curves defining the hatch region, in order around the loop; `origin`, origin point of the hatch pattern; `direction`, hatch line direction (unit vector); `spacing`, distance between hatch lines; `tolerance`, intersection tolerance.
- **Returns:** Array of hatch segments inside the boundary.
- **OCCT:** `Geom2dHatch_Hatcher` + `Geom2dHatch_Intersector`.
- **Example:**
  ```swift
  // A rectangle boundary is 4 segments; there is no single Curve2D rectangle factory.
  let boundary = [
      Curve2D.segment(from: SIMD2(-5, -4), to: SIMD2(5, -4))!,
      Curve2D.segment(from: SIMD2(5, -4), to: SIMD2(5, 4))!,
      Curve2D.segment(from: SIMD2(5, 4), to: SIMD2(-5, 4))!,
      Curve2D.segment(from: SIMD2(-5, 4), to: SIMD2(-5, -4))!
  ]
  let hatches = Curve2DGcc.hatch(
      boundaries: boundary,
      direction: SIMD2(1, 1) / sqrt(2),
      spacing: 1.0)
  for seg in hatches {
      print(seg.start, "→", seg.end)
  }
  ```

---

## GccAna Bisectors

`GccAnaBisector` provides closed-form (exact) bisectors between elementary 2D shapes: points, lines (as point+direction), and circles (as center+radius). Results use `Curve2DLineSolution` for line bisectors and `BisecSolution` for conic bisectors.

### `BisecType`

Classification of a bisector curve type.

```swift
public enum BisecType: Int32, Sendable {
    case line      = 0
    case circle    = 1
    case ellipse   = 2
    case hyperbola = 3
    case parabola  = 4
    case point     = 5
}
```

---

### `BisecSolution`

A bisector solution from an analytical bisector computation.

```swift
public struct BisecSolution: Sendable {
    public let type: BisecType
    public let position: SIMD2<Double>
    public let secondary: SIMD2<Double>
    public let radius: Double
}
```

- `type`: geometric type of the bisector curve.
- `position`: primary position: center for circles, a point on the line for lines, focus for conics.
- `secondary`: secondary values: direction for lines, semi-axes for conics.
- `radius`: radius for circle-type bisectors; 0 otherwise.

*(Per-field anchor below, for cross-reference; the list above has the actual meaning of each.)*

#### `BisecSolution.secondary`

---

### `GccAnaBisector.ofPoints(_:_:)`

Computes the perpendicular bisector of two points.

```swift
public static func ofPoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>
) -> Curve2DLineSolution?
```

Returns the line equidistant from both points.

- **Parameters:** `p1`, `p2`, the two points.
- **Returns:** A `Curve2DLineSolution` for the perpendicular bisector line, or `nil` on failure.
- **OCCT:** `GccAna_Pnt2dBisec`.
- **Example:**
  ```swift
  if let bis = GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(4, 0)) {
      print("midpoint on bisector:", bis.point) // (2, 0)
  }
  ```

---

### `GccAnaBisector.ofLines(line1Point:line1Dir:line2Point:line2Dir:)`

Computes the angle bisectors of two lines.

```swift
public static func ofLines(
    line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
    line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>
) -> [Curve2DLineSolution]
```

Two intersecting lines have two angle bisectors (interior and exterior). Returns up to 2 solutions.

- **Parameters:** `line1Point`, `line1Dir`, point and direction of line 1; `line2Point`, `line2Dir`, point and direction of line 2.
- **Returns:** Array of up to 2 bisector lines.
- **OCCT:** `GccAna_Lin2dBisec`.
- **Example:**
  ```swift
  let bisectors = GccAnaBisector.ofLines(
      line1Point: .zero, line1Dir: SIMD2(1, 0),
      line2Point: .zero, line2Dir: SIMD2(0, 1))
  // Two bisectors at 45° and 135°
  ```

---

### `GccAnaBisector.ofLineAndPoint(linePoint:lineDir:point:)`

Computes the bisector between a line and a point.

```swift
public static func ofLineAndPoint(
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    point: SIMD2<Double>
) -> BisecSolution?
```

The bisector is typically a parabola with the point as focus and the line as directrix.

- **Parameters:** `linePoint`, `lineDir`, point and direction of the line; `point`, the fixed point.
- **Returns:** A `BisecSolution` (usually `type == .parabola`), or `nil` on failure.
- **OCCT:** `GccAna_LinPnt2dBisec`.
- **Example:**
  ```swift
  if let sol = GccAnaBisector.ofLineAndPoint(
      linePoint: SIMD2(0, -2), lineDir: SIMD2(1, 0),
      point: SIMD2(0, 2)
  ) {
      print("bisector type:", sol.type) // .parabola
  }
  ```

---

### `GccAnaBisector.ofCircles(center1:radius1:center2:radius2:)`

Computes bisectors between two circles (up to 4 solutions).

```swift
public static func ofCircles(
    center1: SIMD2<Double>, radius1: Double,
    center2: SIMD2<Double>, radius2: Double
) -> [BisecSolution]
```

- **Parameters:** `center1`, `radius1`, first circle; `center2`, `radius2`, second circle.
- **Returns:** Array of up to 4 bisector curves.
- **OCCT:** `GccAna_Circ2dBisec`.
- **Note:** both radii must be positive (#553). A radius of zero describes a point, and this solver
  does not answer the point question when it is given one: measured, it returns each solution twice,
  and with both radii zero two of the three solutions are hyperbolas of major radius zero, a conic
  this API refuses to construct. Use `ofPoints(_:_:)` or `ofCircleAndPoint(center:radius:point:)`.
  A non-positive radius returns an empty array; a negative one always did, through `gp_Circ2d`'s own
  header check.
- **Example:**
  ```swift
  let bisectors = GccAnaBisector.ofCircles(
      center1: .zero, radius1: 3,
      center2: SIMD2(8, 0), radius2: 2)
  for b in bisectors { print(b.type, b.position) }
  ```

---

### `GccAnaBisector.ofCircleAndLine(center:radius:linePoint:lineDir:)`

Computes bisectors between a circle and a line.

```swift
public static func ofCircleAndLine(
    center: SIMD2<Double>, radius: Double,
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
) -> [BisecSolution]
```

- **Parameters:** `center`, `radius`, the circle; `linePoint`, `lineDir`, point and direction of the line.
- **Returns:** Array of bisector curve solutions.
- **OCCT:** `GccAna_CircLin2dBisec`.
- **Note:** the radius must be positive (#553). With a radius of zero the solver returns the
  point/line parabola twice rather than once; `ofLineAndPoint(linePoint:lineDir:point:)` is the
  entry point for that question. A non-positive radius returns an empty array.
- **Example:**
  ```swift
  let bisectors = GccAnaBisector.ofCircleAndLine(
      center: SIMD2(5, 0), radius: 2,
      linePoint: .zero, lineDir: SIMD2(0, 1))
  ```

---

### `GccAnaBisector.ofCircleAndPoint(center:radius:point:)`

Computes bisectors between a circle and a point.

```swift
public static func ofCircleAndPoint(
    center: SIMD2<Double>, radius: Double,
    point: SIMD2<Double>
) -> [BisecSolution]
```

- **Parameters:** `center`, `radius`, the circle; `point`, the fixed point.
- **Returns:** Array of bisector curve solutions.
- **OCCT:** `GccAna_CircPnt2dBisec`.
- **Note:** the radius must be positive (#553). This is the family where a zero radius is furthest
  from the point reading: measured, it returns two hyperbolas of major radius zero, where the
  bisector of two points is a straight line. Use `ofPoints(_:_:)` for that. A non-positive radius
  returns an empty array.
- **Example:**
  ```swift
  let bisectors = GccAnaBisector.ofCircleAndPoint(
      center: .zero, radius: 4, point: SIMD2(10, 0))
  ```

---

## GccAna Line Solvers

Extensions on `Curve2DGcc` that use the analytical `GccAna` package for exact line construction between elementary shapes (points and circles represented as scalars, not `Curve2D` handles).

### `Curve2DGcc.lineParallelThrough(point:parallelTo:lineDir:)`

Line through a point parallel to a reference line.

```swift
public static func lineParallelThrough(
    point: SIMD2<Double>,
    parallelTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
) -> [Curve2DLineSolution]
```

- **Parameters:** `point`, the pass-through point; `linePoint`, `lineDir`, reference line.
- **Returns:** Array with one solution (the unique parallel line through the point).
- **OCCT:** `GccAna_Lin2dTanPar`.
- **Example:**
  ```swift
  let lines = Curve2DGcc.lineParallelThrough(
      point: SIMD2(0, 3),
      parallelTo: .zero, lineDir: SIMD2(1, 0))
  ```

---

### `Curve2DGcc.linesTangentParallel(circleCenter:circleRadius:qualifier:parallelTo:lineDir:)`

Lines tangent to a circle, parallel to a reference line.

```swift
public static func linesTangentParallel(
    circleCenter: SIMD2<Double>, circleRadius: Double,
    qualifier: Curve2DQualifier = .unqualified,
    parallelTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
) -> [Curve2DLineSolution]
```

- **Parameters:** `circleCenter`, `circleRadius`, the circle; `qualifier`, qualifier; `linePoint`, `lineDir`, reference line direction.
- **Returns:** Array of parallel tangent lines (0 or 2 solutions).
- **OCCT:** `GccAna_Lin2dTanPar`.
- **Note:** `circleRadius` must be positive (#553). With a radius of zero the solver returns the
  single line through the centre twice; `lineParallelThrough(point:parallelTo:lineDir:)` answers
  that question and returns it once. A non-positive radius returns an empty array.
- **Example:**
  ```swift
  let lines = Curve2DGcc.linesTangentParallel(
      circleCenter: .zero, circleRadius: 3, qualifier: .outside,
      parallelTo: .zero, lineDir: SIMD2(1, 0))
  ```

---

### `Curve2DGcc.linePerpendicularThrough(point:perpendicularTo:lineDir:)`

Line through a point perpendicular to a reference line.

```swift
public static func linePerpendicularThrough(
    point: SIMD2<Double>,
    perpendicularTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
) -> [Curve2DLineSolution]
```

- **Parameters:** `point`, the pass-through point; `linePoint`, `lineDir`, reference line.
- **Returns:** Array with one solution.
- **OCCT:** `GccAna_Lin2dTanPer`.
- **Example:**
  ```swift
  let lines = Curve2DGcc.linePerpendicularThrough(
      point: SIMD2(3, 5),
      perpendicularTo: .zero, lineDir: SIMD2(1, 0))
  ```

---

### `Curve2DGcc.linesTangentPerpendicular(circleCenter:circleRadius:qualifier:perpendicularTo:lineDir:)`

Lines tangent to a circle, perpendicular to a reference line.

```swift
public static func linesTangentPerpendicular(
    circleCenter: SIMD2<Double>, circleRadius: Double,
    qualifier: Curve2DQualifier = .unqualified,
    perpendicularTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
) -> [Curve2DLineSolution]
```

- **Parameters:** `circleCenter`, `circleRadius`, the circle; `qualifier`, qualifier; `linePoint`, `lineDir`, reference line direction.
- **Returns:** Array of perpendicular tangent lines.
- **OCCT:** `GccAna_Lin2dTanPer`.
- **Note:** `circleRadius` must be positive (#553). With a radius of zero the solver returns the
  single line through the centre twice; use
  `linePerpendicularThrough(point:perpendicularTo:lineDir:)` for the point question. A non-positive
  radius returns an empty array.
- **Example:**
  ```swift
  let lines = Curve2DGcc.linesTangentPerpendicular(
      circleCenter: .zero, circleRadius: 3,
      perpendicularTo: .zero, lineDir: SIMD2(1, 0))
  ```

---

### `Curve2DGcc.lineAtAngleThrough(point:referenceLine:lineDir:angle:)`

Line through a point at a given angle to a reference line.

```swift
public static func lineAtAngleThrough(
    point: SIMD2<Double>,
    referenceLine linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    angle: Double
) -> [Curve2DLineSolution]
```

- **Parameters:** `point`, pass-through point; `linePoint`, `lineDir`, reference line; `angle`, angle in radians from the reference line.
- **Returns:** Array of line solutions.
- **OCCT:** `GccAna_Lin2dTanObl`.
- **Example:**
  ```swift
  let lines = Curve2DGcc.lineAtAngleThrough(
      point: SIMD2(0, 4),
      referenceLine: .zero, lineDir: SIMD2(1, 0),
      angle: .pi / 4)
  ```

---

### `Curve2DGcc.linesTangentAtAngle(_:_:referenceLine:lineDir:angle:tolerance:)`

Lines tangent to a curve at a given angle to a reference line (Geom2dGcc iterative solver).

```swift
public static func linesTangentAtAngle(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    referenceLine linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    angle: Double, tolerance: Double = 1e-6
) -> [Curve2DLineSolution]
```

Unlike `lineAtAngleThrough`, this accepts an arbitrary `Curve2D` (not just a point) and uses the iterative `Geom2dGcc` solver.

- **Parameters:** `curve`, the tangent curve; `qualifier`, qualifier; `linePoint`, `lineDir`, reference line; `angle`, angle in radians; `tolerance`, solver tolerance.
- **Returns:** Array of line solutions.
- **OCCT:** `Geom2dGcc_Lin2dTanObl`.
- **Example:**
  ```swift
  let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 5, minorRadius: 3)!
  let lines = Curve2DGcc.linesTangentAtAngle(
      ellipse, .outside,
      referenceLine: .zero, lineDir: SIMD2(1, 0),
      angle: .pi / 3)
  ```

---

## GccAna Circle On-Constraint Solvers

Extensions on `Curve2DGcc` that constrain the circle center to lie on an additional line or circle.

### `Curve2DGcc.circlesTangentToTwoLinesOnLine(line1Point:line1Dir:q1:line2Point:line2Dir:q2:centerOnPoint:centerOnDir:tolerance:)`

Finds circles tangent to two lines with center constrained to a third line.

```swift
public static func circlesTangentToTwoLinesOnLine(
    line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>, q1: Curve2DQualifier = .unqualified,
    line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>, q2: Curve2DQualifier = .unqualified,
    centerOnPoint: SIMD2<Double>, centerOnDir: SIMD2<Double>,
    tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `line1Point`, `line1Dir`, `q1`, first tangent line and qualifier; `line2Point`, `line2Dir`, `q2`, second tangent line and qualifier; `centerOnPoint`, `centerOnDir`, center-constraint line; `tolerance`, tolerance.
- **Returns:** Array of circle solutions with center on the specified line.
- **OCCT:** `GccAna_Circ2d2TanOn`.
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentToTwoLinesOnLine(
      line1Point: .zero, line1Dir: SIMD2(1, 0), q1: .unqualified,
      line2Point: .zero, line2Dir: SIMD2(0, 1), q2: .unqualified,
      centerOnPoint: SIMD2(2, 0), centerOnDir: SIMD2(0, 1))
  ```

---

### `Curve2DGcc.circlesTangentToLineOnLineWithRadius(linePoint:lineDir:qualifier:centerOnPoint:centerOnDir:radius:tolerance:)`

Finds circles tangent to a line, with center on a second line, and a given radius.

```swift
public static func circlesTangentToLineOnLineWithRadius(
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    qualifier: Curve2DQualifier = .unqualified,
    centerOnPoint: SIMD2<Double>, centerOnDir: SIMD2<Double>,
    radius: Double, tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `linePoint`, `lineDir`, tangent line; `qualifier`, qualifier; `centerOnPoint`, `centerOnDir`, center-constraint line; `radius`, fixed radius; `tolerance`, tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `GccAna_Circ2dTanOnRad`.
- **Note:** `radius` is the radius of the circles to find, and it must be positive (#553). Asked
  for zero, `GccAna_Circ2dTanOnRad` obliges and returns solution circles of radius zero. A
  non-positive radius returns an empty array.
- **Example:**
  ```swift
  let circles = Curve2DGcc.circlesTangentToLineOnLineWithRadius(
      linePoint: .zero, lineDir: SIMD2(1, 0),
      centerOnPoint: SIMD2(0, 3), centerOnDir: SIMD2(1, 0),
      radius: 3)
  ```

---

## Geom2dGcc Circle On-Constraint Solvers

Iterative on-constraint solvers that accept arbitrary `Curve2D` objects (not restricted to lines/circles).

### `Curve2DGcc.circlesTangentToTwoCurvesOnCurve(_:_:_:_:centerOn:tolerance:initParam1:initParam2:initParamOn:)`

Finds circles tangent to two curves with the center constrained to a third curve.

```swift
public static func circlesTangentToTwoCurvesOnCurve(
    _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
    _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
    centerOn: Curve2D,
    tolerance: Double = 1e-6,
    initParam1: Double = 0, initParam2: Double = 0, initParamOn: Double = 0
) -> [Curve2DCircleSolution]
```

The iterative solver uses starting parameters `initParam1`, `initParam2`, `initParamOn` for convergence near a desired solution.

- **Parameters:** `c1`, `c2`, tangent curves; `q1`, `q2`, qualifiers; `centerOn`, center-constraint curve; `tolerance`, solver tolerance; `initParam1`, `initParam2`, `initParamOn`, initial parameter guesses.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2d2TanOn`.
- **Example:**
  ```swift
  let rail = Curve2D.interpolate(
      points: [SIMD2(0,5), SIMD2(5,5), SIMD2(10,5)])!
  let circles = Curve2DGcc.circlesTangentToTwoCurvesOnCurve(
      arcA, .outside, arcB, .outside, centerOn: rail)
  ```

---

### `Curve2DGcc.circlesTangentOnCurveWithRadius(_:_:centerOn:radius:tolerance:)`

Finds circles tangent to a curve, with the center on a second curve, and a given radius.

```swift
public static func circlesTangentOnCurveWithRadius(
    _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
    centerOn: Curve2D,
    radius: Double, tolerance: Double = 1e-6
) -> [Curve2DCircleSolution]
```

- **Parameters:** `curve`, tangent curve; `qualifier`, qualifier; `centerOn`, center-constraint curve; `radius`, fixed radius; `tolerance`, tolerance.
- **Returns:** Array of circle solutions.
- **OCCT:** `Geom2dGcc_Circ2dTanOnRad`.
- **Note:** `radius` is the radius of the circles to find, and it must be positive; zero would ask
  for a solution circle that is a point (#553). A non-positive radius returns an empty array.
- **Example:**
  ```swift
  let spine = Curve2D.interpolate(
      points: [SIMD2(0, 4), SIMD2(5, 4), SIMD2(10, 4)])!
  let circles = Curve2DGcc.circlesTangentOnCurveWithRadius(
      arc, .outside, centerOn: spine, radius: 2)
  ```

---

## Bisector_BisecAna

Instance methods on `Curve2D` that compute exact analytical bisectors via the OCCT `Bisector_BisecAna` class. Unlike the approximate `Bisector_BisecCC`/`BisecPC` methods above, these produce analytical conic curves.

### `bisector(with:referencePoint:direction1:direction2:sense:tolerance:)`

Computes the analytical bisector between this curve and another.

```swift
public func bisector(
    with other: Curve2D,
    referencePoint: SIMD2<Double>,
    direction1: SIMD2<Double>, direction2: SIMD2<Double>,
    sense: Double = 1.0, tolerance: Double = 1e-6
) -> Curve2D?
```

The bisector is the locus of points equidistant from both curves. `referencePoint` steers the solver toward a specific branch; `direction1` and `direction2` are tangent directions of each curve at the reference.

- **Parameters:** `other`, second curve; `referencePoint`, point near the desired branch; `direction1`, tangent of this curve at reference; `direction2`, tangent of `other` at reference; `sense`, orientation sense (1.0 or -1.0); `tolerance`, geometric tolerance.
- **Returns:** Bisector as a `Curve2D` (analytical conic), or `nil` on failure.
- **OCCT:** `Bisector_BisecAna` (curve–curve constructor).
- **Example:**
  ```swift
  let c1 = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))!
  let c2 = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1))!
  if let bis = c1.bisector(
      with: c2,
      referencePoint: SIMD2(1, 1),
      direction1: SIMD2(1, 0), direction2: SIMD2(0, 1)
  ) {
      let pt = bis.point(at: bis.parameterRange!.lowerBound)
  }
  ```
- **Note:** This overload's label set (`with:referencePoint:direction1:direction2:`) distinguishes it from the approximate `bisector(with:origin:side:)` overload.

---

### `bisector(withPoint:referencePoint:direction1:direction2:sense:tolerance:)`

Computes the analytical bisector between this curve and a point.

```swift
public func bisector(
    withPoint point: SIMD2<Double>,
    referencePoint: SIMD2<Double>,
    direction1: SIMD2<Double>, direction2: SIMD2<Double>,
    sense: Double = 1.0, tolerance: Double = 1e-6
) -> Curve2D?
```

- **Parameters:** `point`, the fixed point; `referencePoint`, steering point; `direction1`, curve tangent at reference; `direction2`, direction from `point` at reference; `sense`, orientation sense; `tolerance`, tolerance.
- **Returns:** Bisector as a `Curve2D`, or `nil` on failure.
- **OCCT:** `Bisector_BisecAna` (curve–point constructor).
- **Example:**
  ```swift
  let arc = Curve2D.circle(center: .zero, radius: 3)!
  if let bis = arc.bisector(
      withPoint: SIMD2(8, 0),
      referencePoint: SIMD2(4, 0),
      direction1: SIMD2(0, 1), direction2: SIMD2(-1, 0)
  ) {
      let range = bis.parameterRange
  }
  ```

---

### `Curve2D.bisectorBetweenPoints(_:_:referencePoint:direction1:direction2:sense:tolerance:)`

Computes the analytical perpendicular bisector between two points (result is a line).

```swift
public static func bisectorBetweenPoints(
    _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
    referencePoint: SIMD2<Double>,
    direction1: SIMD2<Double>, direction2: SIMD2<Double>,
    sense: Double = 1.0, tolerance: Double = 1e-6
) -> Curve2D?
```

- **Parameters:** `p1`, `p2`, the two points; `referencePoint`, steering point; `direction1`, direction from `p1` at reference; `direction2`, direction from `p2` at reference; `sense`, orientation sense; `tolerance`, tolerance.
- **Returns:** Bisector (line) as a `Curve2D`, or `nil` on failure.
- **OCCT:** `Bisector_BisecAna` (point–point constructor).
- **Example:**
  ```swift
  if let bis = Curve2D.bisectorBetweenPoints(
      SIMD2(0, 0), SIMD2(6, 0),
      referencePoint: SIMD2(3, 1),
      direction1: SIMD2(1, 0), direction2: SIMD2(-1, 0)
  ) {
      let pt = bis.point(at: bis.parameterRange!.lowerBound)
  }
  ```
