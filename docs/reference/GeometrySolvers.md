---
title: Geometry Solvers & Builders
parent: API Reference
---

# Geometry Solvers & Builders

Utility and solver types that sit alongside the primary geometry hierarchy: a B-spline curve fitter (`BSplineApproxInterp`), a thin-plate variational solver (`PlateSolver`), an N-sided surface-filling builder (`FillingSurface`), a parametric evolution law (`LawFunction`), closed-form polynomial root solvers (`PolynomialSolver` / `PolynomialRoots`), and a spatial KD-tree (`KDTree`). Each type is self-contained and constructed independently of `Shape` or `Surface`.

## Topics

- [BSplineApproxInterp](#bsplineapproxinterp) · [PlateSolver](#platesolver) · [FillingSurface](#fillingsurface) · [LawFunction](#lawfunction) · [PolynomialRoots](#polynomialroots) · [PolynomialSolver](#polynomialsolver) · [KDTree](#kdtree)

---

## BSplineApproxInterp

Least-squares B-spline curve approximation through a set of 3D points. Backed by `GeomAPI_PointsToBSpline` since OCCT 8.0.0p1 (the original `Approx_BSplineApproxInterp` was removed in that release). Inspect `maxError` for the worst-case residual after calling `perform()` or `performOptimal()`.

### `init?(points:nbControlPoints:degree:continuousIfClosed:)`

Creates a constrained B-spline approximation solver.

```swift
public init?(points: [SIMD3<Double>], nbControlPoints: Int,
             degree: Int = 3, continuousIfClosed: Bool = false)
```

Returns `nil` if `points.count < 2`.

- **Parameters:**
  - `points` — array of 3D points to fit.
  - `nbControlPoints` — advisory number of control points; the approximator chooses the pole count needed to meet tolerance.
  - `degree` — B-spline degree (default `3`).
  - `continuousIfClosed` — enforce C2 continuity when the curve is detected as closed (default `false`).
- **Returns:** A configured solver, or `nil` on invalid input.
- **OCCT:** `GeomAPI_PointsToBSpline` (replaces removed `Approx_BSplineApproxInterp`).
- **Example:**
  ```swift
  var pts: [SIMD3<Double>] = []
  for i in 0..<50 {
      let t = Double(i) / 49.0 * 2.0 * .pi
      pts.append(SIMD3(cos(t), sin(t), 0.1 * t))
  }
  if let solver = BSplineApproxInterp(points: pts, nbControlPoints: 20) {
      solver.perform()
      if solver.isDone, let curve = solver.curve {
          print("Max error:", solver.maxError)
      }
  }
  ```

---

### `interpolatePoint(_:withKink:)`

Mark a point to be exactly interpolated (0-based index).

```swift
public func interpolatePoint(_ index: Int, withKink: Bool = false)
```

> **Note:** No-op since OCCT 8.0.0p1 — `GeomAPI_PointsToBSpline` has no per-point exact interpolation. The approximation still passes near every point.

- **Parameters:**
  - `index` — 0-based index into the points array.
  - `withKink` — if `true`, inserts a C0 discontinuity at this parameter (also a no-op in the current backend).
- **OCCT:** Previously `Approx_BSplineApproxInterp::ChangeConstraints` (now inert).

---

### `perform()`

Perform the fit using automatically computed parameters.

```swift
public func perform()
```

- **OCCT:** `GeomAPI_PointsToBSpline` constructor (performs the fit on construction).
- **Example:**
  ```swift
  solver.perform()
  if solver.isDone { print(solver.maxError) }
  ```

---

### `performOptimal(maxIterations:)`

Perform the fit with iterative parameter optimization.

```swift
public func performOptimal(maxIterations: Int = 10)
```

- **Parameters:** `maxIterations` — maximum number of optimization iterations (default `10`).
- **OCCT:** `GeomAPI_PointsToBSpline` with iterative reparametrisation.

---

### `isDone`

Returns `true` if the fit was computed successfully.

```swift
public var isDone: Bool { get }
```

- **OCCT:** `GeomAPI_PointsToBSpline::IsDone`.

---

### `curve`

The resulting B-spline curve, or `nil` if not done.

```swift
public var curve: Curve3D? { get }
```

- **Returns:** The fitted `Curve3D`, or `nil` if `isDone` is `false`.
- **OCCT:** `GeomAPI_PointsToBSpline::Curve`.
- **Example:**
  ```swift
  if solver.isDone, let c = solver.curve {
      print(c.length())
  }
  ```

---

### `maxError`

The maximum approximation error.

```swift
public var maxError: Double { get }
```

- **Returns:** Worst-case 3D distance from any input point to the fitted curve.
- **OCCT:** `GeomAPI_PointsToBSpline::MaxError`.

---

### `setParametrizationAlpha(_:)`

Set parametrisation power: `0` = uniform, `0.5` = centripetal (default), `1` = chord-length.

```swift
public func setParametrizationAlpha(_ alpha: Double)
```

- **Parameters:** `alpha` — exponent in `[0, 1]`.
- **OCCT:** `GeomAPI_PointsToBSpline` parametrisation mode.

---

### `setMinPivot(_:)`

Set minimum pivot value for the Gauss solver (default `1e-20`).

```swift
public func setMinPivot(_ value: Double)
```

- **Parameters:** `value` — pivot threshold below which a column is considered singular.

---

### `setClosedTolerance(_:)`

Set relative tolerance for closed-curve detection (default `1e-12`).

```swift
public func setClosedTolerance(_ value: Double)
```

---

### `setKnotInsertionTolerance(_:)`

Set tolerance for knot insertion during kink handling (default `1e-4`).

```swift
public func setKnotInsertionTolerance(_ value: Double)
```

---

### `setConvergenceTolerance(_:)`

Set convergence tolerance for parameter optimization (default `1e-3`).

```swift
public func setConvergenceTolerance(_ value: Double)
```

Drive accuracy with this and `setProjectionTolerance` when the default fit is insufficient.

---

### `setProjectionTolerance(_:)`

Set projection tolerance for parameter optimization (default `1e-6`).

```swift
public func setProjectionTolerance(_ value: Double)
```

---

## PlateSolver

A thin-plate spline solver for smooth surface deformation. Wraps OCCT's `Plate_Plate` variational solver: load position and/or derivative pinpoint constraints, call `solve()`, then evaluate the resulting displacement field at any UV location.

Unlike the higher-level NLPlate methods on `Surface`, `PlateSolver` works directly in UV parameter space and returns raw XYZ displacements.

### Loading Constraints

#### `init()`

Create a new Plate solver.

```swift
public init()
```

- **OCCT:** `Plate_Plate` default constructor.
- **Example:**
  ```swift
  let solver = PlateSolver()
  solver.loadPinpoint(u: 0, v: 0, position: .zero)
  solver.loadPinpoint(u: 1, v: 1, position: SIMD3(1, 1, 0.5))
  ```

---

#### `loadPinpoint(u:v:position:)`

Load a pinpoint constraint (position at a UV point).

```swift
public func loadPinpoint(u: Double, v: Double, position: SIMD3<Double>)
```

- **Parameters:**
  - `u`, `v` — UV parameter coordinates.
  - `position` — target 3D position the surface must pass through.
- **OCCT:** `Plate_Plate::Load` with `Plate_PinpointConstraint`.

---

#### `loadDerivativeConstraint(u:v:value:derivativeOrderU:derivativeOrderV:)`

Load a derivative constraint at a UV point.

```swift
public func loadDerivativeConstraint(u: Double, v: Double, value: SIMD3<Double>,
                                      derivativeOrderU: Int, derivativeOrderV: Int)
```

- **Parameters:**
  - `u`, `v` — UV parameter coordinates.
  - `value` — target derivative value.
  - `derivativeOrderU` — U derivative order (`0` for position, `1+` for derivatives).
  - `derivativeOrderV` — V derivative order.
- **OCCT:** `Plate_Plate::Load` with `Plate_PinpointConstraint` at higher derivative order.

---

#### `loadGtoC(u:v:sourceD1:targetD1:)`

Load a geometric-to-continuity (GtoC) constraint at G1 level.

```swift
public func loadGtoC(u: Double, v: Double,
                      sourceD1: (tangentU: SIMD3<Double>, tangentV: SIMD3<Double>),
                      targetD1: (tangentU: SIMD3<Double>, tangentV: SIMD3<Double>))
```

Constrains the surface derivatives to transition from one tangent frame to another at a given UV point.

- **Parameters:**
  - `u`, `v` — UV parameter coordinates.
  - `sourceD1` — source surface first derivatives (tangentU, tangentV).
  - `targetD1` — target surface first derivatives.
- **OCCT:** `Plate_Plate::Load` with `Plate_GtoCConstraint`.

---

### Solving

#### `solve(order:anisotropy:)`

Solve the plate system.

```swift
@discardableResult
public func solve(order: Int = 4, anisotropy: Double = 1.0) -> Bool
```

- **Parameters:**
  - `order` — solution polynomial order (default `4`).
  - `anisotropy` — anisotropy parameter (default `1.0`).
- **Returns:** `true` if the solve succeeded.
- **OCCT:** `Plate_Plate::SolveTI`.
- **Example:**
  ```swift
  let solver = PlateSolver()
  solver.loadPinpoint(u: 0.5, v: 0.5, position: SIMD3(0.5, 0.5, 1.0))
  if solver.solve() {
      let pt = solver.evaluate(u: 0.5, v: 0.5)
  }
  ```

---

#### `isDone`

Check if the last solve succeeded.

```swift
public var isDone: Bool { get }
```

- **OCCT:** `Plate_Plate::IsDone`.

---

### Evaluation

#### `evaluate(u:v:)`

Evaluate the plate at a UV point.

```swift
public func evaluate(u: Double, v: Double) -> SIMD3<Double>
```

Returns the 3D displacement/position computed by the solver. Must call `solve()` first.

- **Parameters:** `u`, `v` — UV parameter coordinates.
- **Returns:** The 3D point on the solved plate surface.
- **OCCT:** `Plate_Plate::Evaluate`.

---

#### `evaluateDerivative(u:v:derivativeOrderU:derivativeOrderV:)`

Evaluate a derivative at a UV point.

```swift
public func evaluateDerivative(u: Double, v: Double,
                                derivativeOrderU: Int, derivativeOrderV: Int) -> SIMD3<Double>
```

- **Parameters:**
  - `u`, `v` — UV parameter coordinates.
  - `derivativeOrderU` — U derivative order.
  - `derivativeOrderV` — V derivative order.
- **Returns:** The requested partial derivative vector.
- **OCCT:** `Plate_Plate::EvaluateDerivative`.

---

#### `uvBox`

UV bounding box of the constraint points.

```swift
public var uvBox: (umin: Double, umax: Double, vmin: Double, vmax: Double) { get }
```

- **Returns:** A tuple describing the UV extent of all loaded constraints.
- **OCCT:** `Plate_Plate::UVBox`.

---

#### `continuity`

Continuity order of the plate solution.

```swift
public var continuity: Int { get }
```

- **Returns:** Integer continuity order of the computed surface.
- **OCCT:** `Plate_Plate::Continuity`.

---

## FillingSurface

Builder for N-sided surface filling using `BRepFill_Filling`. Creates a smooth surface that satisfies boundary edge constraints and optional interior point constraints. Useful for creating patches that fill holes or connect multiple surface boundaries.

### `FillingContinuity`

Continuity order for filling surface constraints.

```swift
public enum FillingContinuity: Int32, Sendable {
    case c0 = 0   // Positional continuity (G0)
    case c1 = 1   // Tangent continuity (C1)
    case c2 = 2   // Curvature continuity (C2)
}
```

---

### `init(degree:pointsOnCurve:maxDegree:maxSegments:tolerance:)`

Create a filling surface builder.

```swift
public init(degree: Int = 3, pointsOnCurve: Int = 15, maxDegree: Int = 8,
            maxSegments: Int = 9, tolerance: Double = 1e-4)
```

- **Parameters:**
  - `degree` — target polynomial degree (default `3`).
  - `pointsOnCurve` — number of discretisation points on each constraint curve (default `15`).
  - `maxDegree` — maximum polynomial degree (default `8`).
  - `maxSegments` — maximum number of segments (default `9`).
  - `tolerance` — 3D tolerance (default `1e-4`).
- **OCCT:** `BRepFill_Filling` constructor.
- **Example:**
  ```swift
  let filling = FillingSurface(degree: 3, tolerance: 1e-5)
  ```

---

### `add(edge:continuity:)`

Add a boundary edge constraint.

```swift
@discardableResult
public func add(edge: Edge, continuity: FillingContinuity = .c0) -> Bool
```

- **Parameters:**
  - `edge` — edge to add as a boundary constraint.
  - `continuity` — continuity order at this edge (default `.c0`).
- **Returns:** `true` if the edge was added successfully.
- **OCCT:** `BRepFill_Filling::Add` (boundary edge variant).
- **Example:**
  ```swift
  let filling = FillingSurface()
  for e in someWire.edges() {
      filling.add(edge: e, continuity: .c1)
  }
  if let face = filling.build() { print(face.isValid) }
  ```

---

### `add(freeEdge:continuity:)`

Add a free (non-boundary) edge constraint.

```swift
@discardableResult
public func add(freeEdge edge: Edge, continuity: FillingContinuity = .c0) -> Bool
```

Free edges are not required to be topologically connected to other boundary edges.

- **Parameters:**
  - `freeEdge` — edge to add as a free constraint.
  - `continuity` — continuity order (default `.c0`).
- **Returns:** `true` if the edge was added successfully.
- **OCCT:** `BRepFill_Filling::Add` (free edge variant).

---

### `add(point:)`

Add a point constraint that the filling surface must pass through.

```swift
@discardableResult
public func add(point: SIMD3<Double>) -> Bool
```

- **Parameters:** `point` — 3D point the surface must interpolate.
- **Returns:** `true` if the point was added successfully.
- **OCCT:** `BRepFill_Filling::Add` (point variant).

---

### `build()`

Build the filling surface and return the resulting shape.

```swift
public func build() -> Shape?
```

- **Returns:** The filled face as a `Shape`, or `nil` if building failed.
- **OCCT:** `BRepFill_Filling::Build`, `BRepFill_Filling::Face`.
- **Example:**
  ```swift
  let filling = FillingSurface()
  filling.add(edge: e0, continuity: .c0)
  filling.add(edge: e1, continuity: .c0)
  filling.add(edge: e2, continuity: .c0)
  filling.add(edge: e3, continuity: .c0)
  if let face = filling.build() {
      print("G0 error:", filling.g0Error ?? -1)
  }
  ```

---

### `isDone`

Whether the filling surface has been successfully built.

```swift
public var isDone: Bool { get }
```

- **OCCT:** `BRepFill_Filling::IsDone`.

---

### `g0Error`

Positional (G0) error of the built surface.

```swift
public var g0Error: Double? { get }
```

- **Returns:** Maximum distance from the surface to its constraints, or `nil` if not yet built.
- **OCCT:** `BRepFill_Filling::G0Error`.

---

### `g1Error`

Tangent (G1) error of the built surface.

```swift
public var g1Error: Double? { get }
```

- **Returns:** Maximum tangent deviation, or `nil` if not yet built.
- **OCCT:** `BRepFill_Filling::G1Error`.

---

### `g2Error`

Curvature (G2) error of the built surface.

```swift
public var g2Error: Double? { get }
```

- **Returns:** Maximum curvature deviation, or `nil` if not yet built.
- **OCCT:** `BRepFill_Filling::G2Error`.

---

## LawFunction

An evolution function defining how a scalar value varies along a parameter range. Used with `Shape.pipeShellWithLaw()` for variable-section sweeps where the cross-section scales smoothly along the spine path.

### Evaluation

#### `value(at:)`

Evaluate the law function at a given parameter.

```swift
public func value(at parameter: Double) -> Double
```

- **Parameters:** `parameter` — parameter value within `bounds`.
- **Returns:** The scalar value of the law at the given parameter.
- **OCCT:** `Law_Function::Value`.
- **Example:**
  ```swift
  if let law = LawFunction.linear(from: 1.0, to: 2.0) {
      print(law.value(at: 0.5))  // ≈ 1.5
  }
  ```

---

#### `bounds`

Parameter bounds of the law function.

```swift
public var bounds: ClosedRange<Double> { get }
```

- **Returns:** The `[first, last]` parameter range over which the law is defined.
- **OCCT:** `Law_Function::Bounds`.

---

### Factory Methods

#### `constant(_:from:to:)`

Create a constant law: the value is uniform over `[first, last]`.

```swift
public static func constant(_ value: Double, from first: Double = 0,
                            to last: Double = 1) -> LawFunction?
```

- **Parameters:**
  - `value` — the constant scalar output.
  - `first`, `last` — parameter range (default `0...1`).
- **Returns:** A `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_Constant`.

---

#### `linear(from:to:parameterRange:)`

Create a linear law: value ramps from `startValue` to `endValue`.

```swift
public static func linear(from startValue: Double, to endValue: Double,
                          parameterRange: ClosedRange<Double> = 0...1) -> LawFunction?
```

- **Parameters:**
  - `startValue` — value at `parameterRange.lowerBound`.
  - `endValue` — value at `parameterRange.upperBound`.
  - `parameterRange` — parametric domain (default `0...1`).
- **Returns:** A `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_Linear`.
- **Example:**
  ```swift
  // Scale profile from radius 1 to radius 3 along the sweep
  if let law = LawFunction.linear(from: 1.0, to: 3.0) {
      let shape = baseShape.pipeShellWithLaw(spine: spineCurve, law: law)
  }
  ```

---

#### `sCurve(from:to:parameterRange:)`

Create an S-curve law: smooth sigmoid transition between start and end values.

```swift
public static func sCurve(from startValue: Double, to endValue: Double,
                          parameterRange: ClosedRange<Double> = 0...1) -> LawFunction?
```

- **Parameters:**
  - `startValue` — value at the start of the range.
  - `endValue` — value at the end of the range.
  - `parameterRange` — parametric domain (default `0...1`).
- **Returns:** A `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_S`.

---

#### `interpolate(points:periodic:)`

Create an interpolated law from `(parameter, value)` pairs.

```swift
public static func interpolate(points: [(parameter: Double, value: Double)],
                               periodic: Bool = false) -> LawFunction?
```

- **Parameters:**
  - `points` — array of `(parameter, value)` tuples in ascending parameter order; must have at least 2 elements.
  - `periodic` — whether the law is periodic (default `false`).
- **Returns:** A `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_Interpol`.

---

#### `bspline(poles:knots:multiplicities:degree:)`

Create a BSpline law from control poles and knot vector.

```swift
public static func bspline(poles: [Double], knots: [Double],
                           multiplicities: [Int32],
                           degree: Int) -> LawFunction?
```

- **Parameters:**
  - `poles` — control point values (1D); at least 2 required.
  - `knots` — knot values; at least 2 required.
  - `multiplicities` — knot multiplicities matching `knots`.
  - `degree` — polynomial degree.
- **Returns:** A `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_BSpline`.

---

### v0.68.0: Composite Law and Knot Splitting

#### `composite(laws:range:)`

Create a composite law by stitching multiple sub-laws together.

```swift
public static func composite(laws: [LawFunction],
                             range: ClosedRange<Double> = 0...1) -> LawFunction?
```

- **Parameters:**
  - `laws` — array of sub-law functions in parameter order; at least 1 required.
  - `range` — overall parametric range (default `0...1`).
- **Returns:** A composite `LawFunction`, or `nil` on failure.
- **OCCT:** `Law_Composite`.

---

#### `knotSplitting(continuityOrder:)`

Find knot indices where a BSpline law drops below given continuity.

```swift
public func knotSplitting(continuityOrder: Int = 2) -> [Int]
```

Only works on BSpline-based law functions created via `bspline(poles:knots:multiplicities:degree:)`.

- **Parameters:** `continuityOrder` — continuity level to check (`0`=C0, `1`=C1, `2`=C2).
- **Returns:** Array of knot indices where continuity breaks, or empty array if none or if the function is not BSpline-based.
- **OCCT:** `Law_BSplineKnotSplitting`.

---

## PolynomialRoots

Results from polynomial root solving.

### `roots`

The real roots found, sorted ascending.

```swift
public let roots: [Double]
```

---

### `count`

Number of real roots found.

```swift
public var count: Int { get }
```

- **Returns:** `roots.count`.

---

## PolynomialSolver

Analytical polynomial solvers for degrees 2–4. Uses OCCT's numerically stable `math_DirectPolynomialRoots` implementation with Newton-Raphson refinement and degenerate-case handling. All methods are static; there is no instance to create.

### `quadratic(a:b:c:)`

Solve a quadratic equation: `ax² + bx + c = 0`.

```swift
public static func quadratic(a: Double, b: Double, c: Double) -> PolynomialRoots
```

- **Parameters:** `a`, `b`, `c` — coefficients (highest degree first).
- **Returns:** `PolynomialRoots` containing 0, 1, or 2 real roots sorted ascending.
- **OCCT:** `math_DirectPolynomialRoots` (degree-2 constructor).
- **Example:**
  ```swift
  // x² - 5x + 6 = 0  →  x = 2, 3
  let r = PolynomialSolver.quadratic(a: 1, b: -5, c: 6)
  print(r.roots)  // [2.0, 3.0]
  ```

---

### `cubic(a:b:c:d:)`

Solve a cubic equation: `ax³ + bx² + cx + d = 0`.

```swift
public static func cubic(a: Double, b: Double, c: Double, d: Double) -> PolynomialRoots
```

- **Parameters:** `a`, `b`, `c`, `d` — coefficients (highest degree first).
- **Returns:** `PolynomialRoots` containing 1, 2, or 3 real roots sorted ascending.
- **OCCT:** `math_DirectPolynomialRoots` (degree-3 constructor).
- **Example:**
  ```swift
  // x³ - 6x² + 11x - 6 = 0  →  x = 1, 2, 3
  let r = PolynomialSolver.cubic(a: 1, b: -6, c: 11, d: -6)
  print(r.roots)  // [1.0, 2.0, 3.0]
  ```

---

### `quartic(a:b:c:d:e:)`

Solve a quartic equation: `ax⁴ + bx³ + cx² + dx + e = 0`.

```swift
public static func quartic(a: Double, b: Double, c: Double, d: Double, e: Double) -> PolynomialRoots
```

- **Parameters:** `a`, `b`, `c`, `d`, `e` — coefficients (highest degree first).
- **Returns:** `PolynomialRoots` containing 0–4 real roots sorted ascending.
- **OCCT:** `math_DirectPolynomialRoots` (degree-4 constructor).
- **Example:**
  ```swift
  // x⁴ - 10x² + 9 = 0  →  x = -3, -1, 1, 3
  let r = PolynomialSolver.quartic(a: 1, b: 0, c: -10, d: 0, e: 9)
  print(r.roots)  // [-3.0, -1.0, 1.0, 3.0]
  ```

---

## KDTree

A KD-tree for fast spatial queries on 3D point sets. Wraps OCCT's `NCollection_KDTree` to provide efficient nearest-neighbor, k-nearest, range, and box queries. Build once from an array of points, then query repeatedly.

### `init?(points:)`

Build a KD-tree from an array of 3D points.

```swift
public init?(points: [SIMD3<Double>])
```

- **Parameters:** `points` — the points to index; must be non-empty.
- **Returns:** A KD-tree, or `nil` if the input is empty or construction fails.
- **OCCT:** `NCollection_KDTree<gp_Pnt, 3>`.
- **Example:**
  ```swift
  let pts: [SIMD3<Double>] = [
      SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)
  ]
  if let tree = KDTree(points: pts) {
      let nearest = tree.nearest(to: SIMD3(0.1, 0.1, 0))
  }
  ```

---

### Queries

#### `nearest(to:)`

Find the nearest point to a query location.

```swift
public func nearest(to point: SIMD3<Double>) -> (index: Int, distance: Double)?
```

- **Parameters:** `point` — the query point.
- **Returns:** A `(index, distance)` tuple where `index` is the 0-based index into the original `points` array and `distance` is the Euclidean distance, or `nil` on error.
- **OCCT:** `NCollection_KDTree::FindNearest`.
- **Example:**
  ```swift
  if let (idx, dist) = tree.nearest(to: SIMD3(0.4, 0.4, 0)) {
      print("Nearest index \(idx), distance \(dist)")
  }
  ```

---

#### `kNearest(to:k:)`

Find the K nearest points to a query location.

```swift
public func kNearest(to point: SIMD3<Double>, k: Int) -> [(index: Int, squaredDistance: Double)]
```

- **Parameters:**
  - `point` — the query point.
  - `k` — number of neighbors to find.
- **Returns:** Array of `(index, squaredDistance)` tuples sorted by distance. Note: distances are **squared**.
- **OCCT:** `NCollection_KDTree` k-nearest query.
- **Example:**
  ```swift
  let neighbors = tree.kNearest(to: SIMD3(0.5, 0.5, 0), k: 3)
  for (idx, sqDist) in neighbors {
      print("index \(idx), dist \(sqDist.squareRoot())")
  }
  ```

---

#### `rangeSearch(center:radius:maxResults:)`

Find all points within a sphere.

```swift
public func rangeSearch(center: SIMD3<Double>, radius: Double, maxResults: Int = 1000) -> [Int]
```

- **Parameters:**
  - `center` — center of the search sphere.
  - `radius` — radius of the search sphere.
  - `maxResults` — maximum number of results (default `1000`).
- **Returns:** Array of 0-based indices of points within the sphere.
- **OCCT:** `NCollection_KDTree` range query.
- **Example:**
  ```swift
  let nearby = tree.rangeSearch(center: .zero, radius: 1.5)
  print("\(nearby.count) points within radius 1.5")
  ```

---

#### `boxSearch(min:max:maxResults:)`

Find all points within an axis-aligned bounding box.

```swift
public func boxSearch(min: SIMD3<Double>, max: SIMD3<Double>, maxResults: Int = 1000) -> [Int]
```

- **Parameters:**
  - `min` — minimum corner of the box.
  - `max` — maximum corner of the box.
  - `maxResults` — maximum number of results (default `1000`).
- **Returns:** Array of 0-based indices of points within the box.
- **OCCT:** `NCollection_KDTree` box query.
- **Example:**
  ```swift
  let inBox = tree.boxSearch(min: SIMD3(0, 0, 0), max: SIMD3(1, 1, 1))
  ```
