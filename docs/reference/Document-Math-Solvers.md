---
title: Document — Math Solvers & Local Properties
parent: API Reference
---

# Document — Math Solvers & Local Properties

This page covers `Document.swift` lines 9930–11123: 2D conic utilities, normal projection, disk/shared-library/message system helpers, `PlateSolver` constraint extensions, extra methods on `Shape`, `Curve3D`, `Curve2D`, and `Surface`, the full `MathSolver` numerical toolkit, `PolynomialSolver` Laguerre extensions, `BRepLProp` edge/face local properties, `GeomGridEval` batch evaluators, single-parameter curve/surface evaluators, and the Newton-Hessian minimizer.

> See also the main **[Document](Document.md)** page for the `Document` class itself and the other chunk pages.

## Topics

- [IntAna2d\_Conic — 2D Conics](#intana2d_conic--2d-conics) · [BRepAlgo\_NormalProjection](#brepalgo_normalprojection) · [OSD\_Disk](#osd_disk) · [OSD\_SharedLibrary](#osd_sharedlibrary) · [Message\_Msg](#message_msg) · [Plate Constraint Extensions](#plate-constraint-extensions) · [Shape Topology Extras](#shape-topology-extras) · [Curve3D Extras](#curve3d-extras) · [Curve2D Extras](#curve2d-extras) · [Surface Extras](#surface-extras) · [Math Solvers](#math-solvers) · [PolynomialSolver Laguerre Extensions](#polynomialsolver-laguerre-extensions) · [BRepLProp Edge Extensions](#breplprop-edge-extensions) · [BRepLProp Face Extensions](#breplprop-face-extensions) · [GridEval Curve3D Extensions](#grideval-curve3d-extensions) · [GridEval Curve2D Extensions](#grideval-curve2d-extensions) · [GridEval Surface Extensions](#grideval-surface-extensions) · [Curve3D Evaluation](#curve3d-evaluation) · [Curve2D Evaluation](#curve2d-evaluation) · [Surface Evaluation](#surface-evaluation) · [math\_NewtonMinimum](#math_newtonminimum)

---

## IntAna2d\_Conic — 2D Conics

`Conic2D` is a value type holding the six implicit coefficients of a 2D conic
`A·x² + B·x·y + C·y² + D·x + E·y + F = 0`, plus static factories and a line-circle
intersection query. Wraps `IntAna2d_Conic` / `IntAna2d_AnaIntersection`.

### `Conic2D`

Coefficients of a 2D implicit conic `A·x² + B·x·y + C·y² + D·x + E·y + F = 0`.

```swift
public struct Conic2D: Sendable {
    public let a, b, c, d, e, f: Double
}
```

---

### `Conic2D.fromCircle(center:direction:radius:)`

Create `Conic2D` coefficients from a 2D circle.

```swift
public static func fromCircle(
    center: SIMD2<Double>, direction: SIMD2<Double>, radius: Double
) -> Conic2D
```

- **Parameters:** `center` — circle centre; `direction` — local X axis direction; `radius` — circle radius.
- **Returns:** `Conic2D` with the six implicit coefficients.
- **OCCT:** `IntAna2d_Conic` (circle constructor) via `OCCTConic2dFromCircle`.
- **Example:**
  ```swift
  let c = Conic2D.fromCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 3)
  // c.a == 1, c.c == 1, c.f == -9  (approximate unit-circle form scaled by r²)
  ```

---

### `Conic2D.fromLine(point:direction:)`

Create `Conic2D` coefficients from a 2D line.

```swift
public static func fromLine(
    point: SIMD2<Double>, direction: SIMD2<Double>
) -> Conic2D
```

- **Parameters:** `point` — any point on the line; `direction` — line direction vector.
- **Returns:** `Conic2D` whose non-zero linear coefficients describe the line.
- **OCCT:** `IntAna2d_Conic` (line constructor) via `OCCTConic2dFromLine`.
- **Example:**
  ```swift
  let l = Conic2D.fromLine(point: .zero, direction: SIMD2(1, 0))
  ```

---

### `Conic2D.fromEllipse(center:direction:majorRadius:minorRadius:)`

Create `Conic2D` coefficients from a 2D ellipse.

```swift
public static func fromEllipse(
    center: SIMD2<Double>, direction: SIMD2<Double>,
    majorRadius: Double, minorRadius: Double
) -> Conic2D
```

- **Parameters:** `center` — ellipse centre; `direction` — local X axis; `majorRadius` / `minorRadius` — semi-axes.
- **Returns:** `Conic2D` with the six implicit conic coefficients.
- **OCCT:** `IntAna2d_Conic` (ellipse constructor) via `OCCTConic2dFromEllipse`.
- **Example:**
  ```swift
  let e = Conic2D.fromEllipse(center: .zero, direction: SIMD2(1, 0),
                               majorRadius: 5, minorRadius: 3)
  ```

---

### `Conic2D.lineCircleIntersection(linePoint:lineDir:circleCenter:circleDir:radius:)`

Intersect a 2D line with a 2D circle, returning all intersection points.

```swift
public static func lineCircleIntersection(
    linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
    circleCenter: SIMD2<Double>, circleDir: SIMD2<Double>, radius: Double
) -> [SIMD2<Double>]
```

- **Returns:** 0, 1, or 2 intersection points. Empty array when the line misses the circle.
- **OCCT:** `IntAna2d_AnaIntersection` via `OCCTConic2dLineCircleIntersect`.
- **Example:**
  ```swift
  let pts = Conic2D.lineCircleIntersection(
      linePoint: SIMD2(-5, 0), lineDir: SIMD2(1, 0),
      circleCenter: .zero, circleDir: SIMD2(1, 0), radius: 3)
  // pts.count == 2 → [-3,0] and [3,0]
  ```

---

## BRepAlgo\_NormalProjection

`NormalProjection` projects wires or edges onto a shape by shooting normals. Wraps `BRepAlgo_NormalProjection`.

### `NormalProjection.init(target:)`

Create a normal-projection builder targeting the given shape.

```swift
public init?(target: Shape)
```

- **Parameters:** `target` — the shape that wires/edges will be projected onto.
- **Returns:** `nil` if the internal object could not be created.
- **OCCT:** `BRepAlgo_NormalProjection` constructor via `OCCTNormalProjectionCreate`.
- **Example:**
  ```swift
  guard let proj = NormalProjection(target: face) else { return }
  ```

---

### `NormalProjection.add(_:)`

Add a wire or edge shape to be projected.

```swift
public func add(_ shape: Shape)
```

- **Parameters:** `shape` — a wire or edge to project.
- **OCCT:** `BRepAlgo_NormalProjection::Add` via `OCCTNormalProjectionAdd`.
- **Example:**
  ```swift
  proj.add(wireShape)
  ```

---

### `NormalProjection.build()`

Build the projection. Returns `true` on success.

```swift
@discardableResult
public func build() -> Bool
```

- **Returns:** `true` if projection succeeded; `false` on geometry failure.
- **OCCT:** `BRepAlgo_NormalProjection::Build` via `OCCTNormalProjectionBuild`.
- **Example:**
  ```swift
  if proj.build() {
      let result = proj.result
  }
  ```

---

### `NormalProjection.result`

The projected shape after a successful `build()`.

```swift
public var result: Shape? { get }
```

- **Returns:** The resulting projected wire/edge compound, or `nil` if not built or failed.
- **OCCT:** `BRepAlgo_NormalProjection::Projection` via `OCCTNormalProjectionResult`.
- **Example:**
  ```swift
  if let projected = proj.result {
      // use projected shape
  }
  ```

---

## OSD\_Disk

`DiskInfo` is a namespace for disk/volume introspection utilities. Wraps `OSD_Disk`.

### `DiskInfo.size(path:)`

Get the total disk size in kilobytes for the given path.

```swift
public static func size(path: String = "/") -> Int64
```

- **Parameters:** `path` — filesystem path; defaults to root `/`.
- **Returns:** Total disk capacity in KB.
- **OCCT:** `OSD_Disk::DiskSize` via `OCCTDiskSize`.
- **Example:**
  ```swift
  let totalKB = DiskInfo.size()
  ```

---

### `DiskInfo.freeSpace(path:)`

Get the free space in kilobytes for the given path.

```swift
public static func freeSpace(path: String = "/") -> Int64
```

- **Returns:** Available free space in KB.
- **OCCT:** `OSD_Disk::DiskFree` via `OCCTDiskFree`.
- **Example:**
  ```swift
  let freeKB = DiskInfo.freeSpace(path: "/tmp")
  ```

---

### `DiskInfo.isValid(path:)`

Check whether a disk path is accessible.

```swift
public static func isValid(path: String) -> Bool
```

- **Returns:** `true` if the path names a mounted, accessible volume.
- **OCCT:** `OSD_Disk` validity check via `OCCTDiskIsValid`.
- **Example:**
  ```swift
  if DiskInfo.isValid(path: "/Volumes/Data") { ... }
  ```

---

### `DiskInfo.name(path:)`

Get the volume name for a given path.

```swift
public static func name(path: String = "/") -> String?
```

- **Returns:** Volume label string, or `nil` if unavailable.
- **OCCT:** `OSD_Disk` name query via `OCCTDiskName`.
- **Example:**
  ```swift
  if let vol = DiskInfo.name() { print(vol) }
  ```

---

## OSD\_SharedLibrary

`SharedLibrary` wraps a handle to a dynamically loaded library. Wraps `OSD_SharedLibrary`.

### `SharedLibrary.init(name:)`

Create a shared-library handle for the given name or path.

```swift
public init?(name: String)
```

- **Parameters:** `name` — library filename or full path (e.g. `"libFoo.dylib"`).
- **Returns:** `nil` if the handle cannot be created.
- **OCCT:** `OSD_SharedLibrary` constructor via `OCCTSharedLibCreate`.
- **Example:**
  ```swift
  guard let lib = SharedLibrary(name: "libFoo.dylib") else { return }
  ```

---

### `SharedLibrary.open()`

Load the shared library.

```swift
@discardableResult
public func open() -> Bool
```

- **Returns:** `true` if the library was successfully opened.
- **OCCT:** `OSD_SharedLibrary::DlOpen` via `OCCTSharedLibOpen`.
- **Example:**
  ```swift
  if lib.open() { print("loaded") }
  ```

---

### `SharedLibrary.close()`

Unload the shared library.

```swift
public func close()
```

- **OCCT:** `OSD_SharedLibrary::DlClose` via `OCCTSharedLibClose`.

---

### `SharedLibrary.name`

The name or path of the shared library.

```swift
public var name: String? { get }
```

- **Returns:** Library name, or `nil` if unavailable.
- **OCCT:** `OSD_SharedLibrary::Name` via `OCCTSharedLibName`.

---

## Message\_Msg

`MessageSystem` provides access to OCCT's string-keyed message catalogue. Wraps `Message_Msg` / `Message_MsgFile`.

### `MessageSystem.message(forKey:)`

Get the localized message text for a catalogue key.

```swift
public static func message(forKey key: String) -> String?
```

- **Returns:** The message string, or `nil` if the key is not registered.
- **OCCT:** `Message_Msg` look-up via `OCCTMessageMsgGet`.
- **Example:**
  ```swift
  if let text = MessageSystem.message(forKey: "BRep_API.NoFace") {
      print(text)
  }
  ```

---

### `MessageSystem.loadFile(_:)`

Load message definitions from a `.msg` file.

```swift
@discardableResult
public static func loadFile(_ path: String) -> Bool
```

- **Returns:** `true` if the file was parsed successfully.
- **OCCT:** `Message_MsgFile::LoadFile` via `OCCTMessageMsgFileLoad`.

---

### `MessageSystem.loadDefault()`

Load the default OCCT message file bundled with the framework.

```swift
@discardableResult
public static func loadDefault() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Message_MsgFile::LoadFile` (default path) via `OCCTMessageMsgFileLoadDefault`.

---

### `MessageSystem.hasMessage(forKey:)`

Check whether a message key is registered.

```swift
public static func hasMessage(forKey key: String) -> Bool
```

- **Returns:** `true` if the key exists in the currently loaded catalogues.
- **OCCT:** `Message_MsgFile::HasMsg` via `OCCTMessageMsgHasMsg`.

---

## Plate Constraint Extensions

Extension on `PlateSolver` adding advanced constraint types. See the main `PlateSolver` page for the core solver.

### `PlateSolver.loadGlobalTranslation(uvPoints:)`

Load a global translation constraint — all sample UV points are constrained to shift by the same unknown rigid displacement.

```swift
@discardableResult
public func loadGlobalTranslation(uvPoints: [SIMD2<Double>]) -> Bool
```

- **Parameters:** `uvPoints` — UV parameter points where the constraint is sampled.
- **Returns:** `true` if the constraint was accepted.
- **OCCT:** `Plate_GlobalTranslationConstraint` via `OCCTPlateLoadGlobalTranslation`.
- **Example:**
  ```swift
  let uvs: [SIMD2<Double>] = [SIMD2(0.5, 0.5)]
  plate.loadGlobalTranslation(uvPoints: uvs)
  ```

---

### `PlateSolver.loadLinearXYZ(uvPoints:targets:coefficients:)`

Load a linear XYZ constraint — a weighted linear combination of UV-sample positions must match the target.

```swift
@discardableResult
public func loadLinearXYZ(
    uvPoints: [SIMD2<Double>],
    targets: [SIMD3<Double>],
    coefficients: [Double]
) -> Bool
```

- **Parameters:** `uvPoints` — UV parameter points; `targets` — target XYZ positions; `coefficients` — scalar weights.
- **Returns:** `true` if the constraint was accepted.
- **OCCT:** `Plate_LinearXYZConstraint` via `OCCTPlateLoadLinearXYZ`.

---

## Shape Topology Extras

Extension on `Shape`.

### `Shape.shapeTypeString`

The topology type of the shape as a lowercase string (`"compound"`, `"solid"`, `"face"`, etc.).

```swift
public var shapeTypeString: String { get }
```

- **Returns:** Type name string; `"unknown"` if the handle is invalid.
- **OCCT:** `BRep_Builder` / `TopAbs_ShapeEnum` via `OCCTShapeTypeString`.
- **Example:**
  ```swift
  let box = Shape.box(dx: 1, dy: 1, dz: 1)!
  print(box.shapeTypeString)  // "solid"
  ```

---

## Curve3D Extras

Extension on `Curve3D`.

### `Curve3D.reverse()`

Reverse the orientation of the curve in-place.

```swift
@discardableResult
public func reverse() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Geom_Curve::Reverse` via `OCCTCurve3DReverse`.
- **Example:**
  ```swift
  let ok = myCurve.reverse()
  ```

---

### `Curve3D.copy()`

Create a deep copy of this curve.

```swift
public func copy() -> Curve3D?
```

- **Returns:** A new independent `Curve3D`, or `nil` on failure.
- **OCCT:** `Geom_Geometry::Copy` via `OCCTCurve3DCopy`.
- **Example:**
  ```swift
  if let clone = myCurve.copy() {
      clone.reverse()
  }
  ```

---

## Curve2D Extras

Extension on `Curve2D`.

### `Curve2D.reverse()`

Reverse the orientation of the 2D curve in-place.

```swift
@discardableResult
public func reverse() -> Bool
```

- **Returns:** `true` on success.
- **OCCT:** `Geom2d_Curve::Reverse` via `OCCTCurve2DReverse`.

---

### `Curve2D.copy()`

Create a deep copy of this 2D curve.

```swift
public func copy() -> Curve2D?
```

- **Returns:** A new independent `Curve2D`, or `nil` on failure.
- **OCCT:** `Geom2d_Geometry::Copy` via `OCCTCurve2DCopy`.

---

## Surface Extras

Extension on `Surface`.

### `Surface.parameterBounds`

The (u, v) parameter domain of the surface.

```swift
public var parameterBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) { get }
```

- **OCCT:** `Geom_Surface::Bounds` via `OCCTSurfaceBounds`.
- **Example:**
  ```swift
  let s = Surface.cylinder(axis: .zero, direction: SIMD3(0,0,1), radius: 5)!
  let b = s.parameterBounds
  print(b.uMin, b.uMax)  // 0.0, 2π
  ```

---

### `Surface.surfaceContinuityOrder`

Continuity order as an integer: 0=C0, 1=C1, 2=C2, 3=C3, 99=CN.

```swift
public var surfaceContinuityOrder: Int { get }
```

- **OCCT:** `Geom_Surface::Continuity` via `OCCTSurfaceContinuity`.

---

### `Surface.copy()`

Create a deep copy of this surface.

```swift
public func copy() -> Surface?
```

- **Returns:** A new independent `Surface`, or `nil` on failure.
- **OCCT:** `Geom_Geometry::Copy` via `OCCTSurfaceCopy`.

---

## Math Solvers

`MathSolver` is a Swift namespace (`enum`) exposing OCCT's `math` library via Swift closure callbacks. All closures are bridged through C `void*` context pointers using `ClosureBox<T>`. Introduced v0.110.0 / v0.111.0.

### 1D Root Finding

#### `MathSolver.findRoot(near:tolerance:maxIterations:function:)`

Find a root of `f(x)=0` near `guess` using Newton-Raphson.

```swift
public static func findRoot(
    near guess: Double,
    tolerance: Double = 1e-8,
    maxIterations: Int = 100,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> Double?
```

- **Parameters:** `guess` — starting estimate; `tolerance` — convergence criterion; `function` — closure returning `(f(x), f'(x))`.
- **Returns:** Root value, or `nil` if the solver did not converge within `maxIterations`.
- **OCCT:** `math_FunctionRoot` via `OCCTMathFunctionRoot`.
- **Example:**
  ```swift
  // Find root of x² - 2 = 0 near 1
  if let root = MathSolver.findRoot(near: 1.0) { x in
      (x * x - 2, 2 * x)
  } {
      print(root)  // ≈ 1.41421356
  }
  ```

---

#### `MathSolver.findRoot(near:in:tolerance:maxIterations:function:)`

Find a root of `f(x)=0` near `guess` restricted to the closed range `[a, b]`.

```swift
public static func findRoot(
    near guess: Double,
    in range: ClosedRange<Double>,
    tolerance: Double = 1e-8,
    maxIterations: Int = 100,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> Double?
```

- **Parameters:** `range` — hard bounds for the search; other parameters as above.
- **Returns:** Root within `range`, or `nil` if not converged.
- **OCCT:** `math_FunctionRoots` (bounded) via `OCCTMathFunctionRootBounded`.
- **Example:**
  ```swift
  let root = MathSolver.findRoot(near: 1.2, in: 1.0...2.0) { x in
      (x * x - 2, 2 * x)
  }
  ```

---

#### `MathSolver.findRootBisection(in:tolerance:maxIterations:function:)`

Find a root of `f(x)=0` in `[a, b]` using a bisection + Newton hybrid.

```swift
public static func findRootBisection(
    in range: ClosedRange<Double>,
    tolerance: Double = 1e-8,
    maxIterations: Int = 100,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> Double?
```

- **Returns:** Root within `range`, or `nil` if not converged.
- **OCCT:** `math_BissecNewton` via `OCCTMathBissecNewton`.
- **Note:** More robust than pure Newton when the function is not smooth near the root; the bracket `[a, b]` must bracket a sign change.

---

### System of Equations

#### `MathSolver.solveSystem(variables:equations:startPoint:tolerance:maxIterations:values:jacobian:)`

Solve a system of non-linear equations using Newton's method.

```swift
public static func solveSystem(
    variables: Int,
    equations: Int,
    startPoint: [Double],
    tolerance: Double = 1e-8,
    maxIterations: Int = 100,
    values: @escaping ([Double]) -> [Double],
    jacobian: @escaping ([Double]) -> [Double]
) -> [Double]?
```

- **Parameters:**
  - `variables` — number of unknowns.
  - `equations` — number of equations (may differ from `variables` for over/under-determined systems).
  - `startPoint` — initial guess array of length `variables`.
  - `values` — closure returning equation values `F(x)`, length `equations`.
  - `jacobian` — closure returning the row-major Jacobian `J(x)`, length `equations × variables`.
- **Returns:** Solution point array of length `variables`, or `nil` if not converged.
- **OCCT:** `math_FunctionSetRoot` via `OCCTMathFunctionSetRoot`.
- **Example:**
  ```swift
  // Solve x² + y² = 1, x - y = 0 (roots at ±1/√2)
  let sol = MathSolver.solveSystem(
      variables: 2, equations: 2, startPoint: [0.5, 0.5],
      values: { x in [x[0]*x[0] + x[1]*x[1] - 1, x[0] - x[1]] },
      jacobian: { x in [2*x[0], 2*x[1], 1, -1] }
  )
  ```

---

### BFGS Minimization

#### `MathSolver.minimize(variables:startPoint:tolerance:maxIterations:function:)`

Minimize a multivariate function using the BFGS quasi-Newton method (requires gradient).

```swift
public static func minimize(
    variables: Int,
    startPoint: [Double],
    tolerance: Double = 1e-8,
    maxIterations: Int = 200,
    function: @escaping ([Double]) -> (value: Double, gradient: [Double])
) -> (point: [Double], minimum: Double)?
```

- **Parameters:** `function` — closure returning `(f(x), ∇f(x))`.
- **Returns:** `(minimizer, f(minimizer))`, or `nil` if not converged.
- **OCCT:** `math_BFGS` via `OCCTMathBFGS`.
- **Example:**
  ```swift
  // Minimize (x-1)² + (y-2)²
  if let res = MathSolver.minimize(variables: 2, startPoint: [0, 0]) { x in
      let v = (x[0]-1)*(x[0]-1) + (x[1]-2)*(x[1]-2)
      return (v, [2*(x[0]-1), 2*(x[1]-2)])
  } {
      print(res.point)    // ≈ [1, 2]
      print(res.minimum)  // ≈ 0
  }
  ```

---

### Powell Minimization

#### `MathSolver.minimizePowell(variables:startPoint:tolerance:maxIterations:function:)`

Minimize a multivariate function using Powell's direction-set method (derivative-free).

```swift
public static func minimizePowell(
    variables: Int,
    startPoint: [Double],
    tolerance: Double = 1e-8,
    maxIterations: Int = 200,
    function: @escaping ([Double]) -> Double
) -> (point: [Double], minimum: Double)?
```

- **Parameters:** `function` — closure returning a scalar value `f(x)`.
- **Returns:** `(minimizer, f(minimizer))`, or `nil` if not converged.
- **OCCT:** `math_Powell` via `OCCTMathPowell`.
- **Note:** Preferred when derivatives are unavailable or expensive; generally slower than BFGS for smooth functions.

---

### Brent Minimization

#### `MathSolver.minimizeBrent(ax:bx:cx:tolerance:maxIterations:function:)`

Minimize a 1D function over a bracketed interval using Brent's method.

```swift
public static func minimizeBrent(
    ax: Double, bx: Double, cx: Double,
    tolerance: Double = 1e-8,
    maxIterations: Int = 100,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> (location: Double, minimum: Double)?
```

- **Parameters:** `ax`, `bx`, `cx` — bracket triplet with `ax < bx < cx` and `f(bx) < f(ax)`, `f(bx) < f(cx)`; `function` — closure returning `(f(x), f'(x))`.
- **Returns:** `(x_min, f(x_min))`, or `nil` if not converged.
- **OCCT:** `math_BrentMinimum` via `OCCTMathBrentMinimum`.
- **Example:**
  ```swift
  // Minimize x² in [-2, 2]
  if let res = MathSolver.minimizeBrent(ax: -2, bx: 0.1, cx: 2) { x in
      (x * x, 2 * x)
  } {
      print(res.location)  // ≈ 0
  }
  ```

---

### Particle Swarm Optimization

#### `MathSolver.particleSwarm(variables:lower:upper:steps:particles:iterations:function:)`

Minimize a multivariate function using Particle Swarm Optimization (PSO), a stochastic, derivative-free global search.

```swift
public static func particleSwarm(
    variables: Int,
    lower: [Double],
    upper: [Double],
    steps: [Double],
    particles: Int = 64,
    iterations: Int = 100,
    function: @escaping ([Double]) -> Double
) -> (point: [Double], minimum: Double)?
```

- **Parameters:** `lower` / `upper` — per-variable bounds; `steps` — initial step sizes; `particles` — swarm size; `iterations` — number of swarm iterations.
- **Returns:** `(minimizer, f(minimizer))`, or `nil` on failure.
- **OCCT:** `math_PSO` via `OCCTMathPSO`.
- **Note:** Good for highly multimodal or discontinuous objectives; does not require derivatives. Use `globalMinimize` for a deterministic alternative.

---

### Global Minimization

#### `MathSolver.globalMinimize(variables:lower:upper:function:)`

Find the global minimum of a multivariate function using Lipschitz-based optimization.

```swift
public static func globalMinimize(
    variables: Int,
    lower: [Double],
    upper: [Double],
    function: @escaping ([Double]) -> Double
) -> (point: [Double], minimum: Double)?
```

- **Parameters:** `lower` / `upper` — search domain bounds per variable; `function` — objective.
- **Returns:** `(global minimizer, f(minimizer))`, or `nil` on failure.
- **OCCT:** `math_GlobOptMin` via `OCCTMathGlobOptMin`.
- **Example:**
  ```swift
  if let res = MathSolver.globalMinimize(
      variables: 2, lower: [-5, -5], upper: [5, 5]
  ) { x in x[0]*x[0] + x[1]*x[1] } {
      print(res.minimum)  // ≈ 0
  }
  ```

---

### Find All Roots

#### `MathSolver.findAllRoots(in:samples:function:)`

Find all roots of `f(x)=0` in a given interval using a subdivision-plus-Newton strategy.

```swift
public static func findAllRoots(
    in range: ClosedRange<Double>,
    samples: Int = 20,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> [Double]
```

- **Parameters:** `samples` — number of sub-intervals for sign-change detection (more samples finds more roots but is slower).
- **Returns:** Array of root values (may be empty). Up to 100 roots are returned.
- **OCCT:** `math_FunctionRoots` via `OCCTMathFunctionRoots`.
- **Example:**
  ```swift
  // Find all roots of sin(x) in [0, 4π]
  let roots = MathSolver.findAllRoots(in: 0...4*.pi, samples: 40) { x in
      (sin(x), cos(x))
  }
  ```

---

### Gauss Integration

#### `MathSolver.integrate(from:to:order:function:)`

Integrate a function over `[lower, upper]` using Gauss-Legendre quadrature.

```swift
public static func integrate(
    from lower: Double,
    to upper: Double,
    order: Int = 10,
    function: @escaping (Double) -> Double
) -> Double
```

- **Parameters:** `order` — number of Gauss quadrature points (higher = more accurate for smooth functions).
- **Returns:** Numerical integral value.
- **OCCT:** `math_GaussSingleIntegration` via `OCCTMathGaussIntegrate`.
- **Example:**
  ```swift
  let area = MathSolver.integrate(from: 0, to: .pi) { x in sin(x) }
  // ≈ 2.0
  ```

---

### Newton System Solver

#### `MathSolver.solveSystemNewton(variables:equations:startPoint:tolerance:maxIterations:values:jacobian:)`

Solve a system of equations using Newton's method (`NewtonFunctionSetRoot` variant, stricter convergence criterion than `solveSystem`).

```swift
public static func solveSystemNewton(
    variables: Int,
    equations: Int,
    startPoint: [Double],
    tolerance: Double = 1e-8,
    maxIterations: Int = 100,
    values: @escaping ([Double]) -> [Double],
    jacobian: @escaping ([Double]) -> [Double]
) -> [Double]?
```

- **Parameters:** Same interface as `solveSystem`; internally uses `math_NewtonFunctionSetRoot`.
- **Returns:** Solution array of length `variables`, or `nil`.
- **OCCT:** `math_NewtonFunctionSetRoot` via `OCCTMathNewtonFuncSetRoot`.
- **Note:** More aggressive damping than `solveSystem`; prefer when starting close to the solution.

---

## PolynomialSolver Laguerre Extensions

Extension on `PolynomialSolver` adding Laguerre iteration for general-degree polynomials. Wraps OCCT's `math_Laguerre`.

### `PolynomialSolver.laguerreRoots(coefficients:)`

Find all real roots of a polynomial using Laguerre's method.

```swift
public static func laguerreRoots(coefficients: [Double]) -> [Double]
```

- **Parameters:** `coefficients` — polynomial coefficients in ascending power order: `[a0, a1, …, an]` for `a0 + a1·x + … + an·xⁿ`.
- **Returns:** Sorted array of real roots (up to 20).
- **OCCT:** `math_Laguerre` / `math_DirectPolynomialRoots` via `OCCTPolyLaguerreRoots`.
- **Example:**
  ```swift
  // Roots of x³ - 6x² + 11x - 6 = 0  →  [1, 2, 3]
  let r = PolynomialSolver.laguerreRoots(coefficients: [-6, 11, -6, 1])
  ```

---

### `PolynomialSolver.laguerreComplexRoots(coefficients:)`

Find all (possibly complex) roots using Laguerre's method.

```swift
public static func laguerreComplexRoots(coefficients: [Double]) -> [(real: Double, imaginary: Double)]
```

- **Parameters:** Same ascending-order convention as `laguerreRoots`.
- **Returns:** Array of `(real, imaginary)` pairs (up to 20 roots).
- **OCCT:** `math_Laguerre` complex variant via `OCCTPolyLaguerreComplexRoots`.
- **Example:**
  ```swift
  // Roots of x² + 1 = 0  →  [(0, 1), (0, -1)]
  let r = PolynomialSolver.laguerreComplexRoots(coefficients: [1, 0, 1])
  ```

---

### `PolynomialSolver.quinticRoots(a:b:c:d:e:f:)`

Find real roots of the quintic `a·x⁵ + b·x⁴ + c·x³ + d·x² + e·x + f = 0`.

```swift
public static func quinticRoots(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) -> [Double]
```

- **Returns:** Up to 5 real roots (sorted).
- **OCCT:** `math_DirectPolynomialRoots` (degree 5) via `OCCTPolyQuinticRoots`.
- **Example:**
  ```swift
  let r = PolynomialSolver.quinticRoots(a: 1, b: 0, c: 0, d: 0, e: 0, f: -32)
  // root of x⁵ - 32 = 0 → [2]
  ```

---

## BRepLProp Edge Extensions

Extension on `Shape` for edge-level local geometric properties using `BRepLProp_CLProps`.

### `Shape.edgeLPropValue(at:)`

Evaluate the 3D point on an edge at the given parameter.

```swift
public func edgeLPropValue(at param: Double) -> SIMD3<Double>?
```

- **Returns:** Point on the edge curve at `param`.
- **OCCT:** `BRepLProp_CLProps::Value` via `OCCTEdgeLPropValue`.

---

### `Shape.edgeTangent(at:)`

Tangent direction on an edge at the given parameter.

```swift
public func edgeTangent(at param: Double) -> SIMD3<Double>?
```

- **Returns:** Unit tangent vector, or `nil` if the tangent is not defined (e.g. at a cusp).
- **OCCT:** `BRepLProp_CLProps::Tangent` via `OCCTEdgeLPropTangent`.

---

### `Shape.edgeCurvatureLP(at:)`

Scalar curvature on an edge at the given parameter.

```swift
public func edgeCurvatureLP(at param: Double) -> Double
```

- **Returns:** Signed curvature value (0 for a straight edge).
- **OCCT:** `BRepLProp_CLProps::Curvature` via `OCCTEdgeLPropCurvature`.

---

### `Shape.edgeNormalLP(at:)`

Normal direction on an edge at the given parameter.

```swift
public func edgeNormalLP(at param: Double) -> SIMD3<Double>
```

- **Returns:** Normal vector in the osculating plane.
- **OCCT:** `BRepLProp_CLProps::Normal` via `OCCTEdgeLPropNormal`.

---

### `Shape.edgeCentreOfCurvature(at:)`

Centre of curvature on an edge at the given parameter.

```swift
public func edgeCentreOfCurvature(at param: Double) -> SIMD3<Double>
```

- **Returns:** The centre of the osculating circle at `param`.
- **OCCT:** `BRepLProp_CLProps::CentreOfCurvature` via `OCCTEdgeLPropCentreOfCurvature`.

---

### `Shape.edgeLPropD1(at:)`

First derivative vector on an edge at the given parameter.

```swift
public func edgeLPropD1(at param: Double) -> SIMD3<Double>
```

- **Returns:** The first derivative `C'(param)`.
- **OCCT:** `BRepLProp_CLProps::D1` via `OCCTEdgeLPropD1`.
- **Example:**
  ```swift
  let edge: Shape = ...  // an edge shape
  let tangent = edge.edgeTangent(at: 0.5)
  let curv    = edge.edgeCurvatureLP(at: 0.5)
  ```

---

## BRepLProp Face Extensions

Extension on `Shape` for face-level local surface properties using `BRepLProp_SLProps`.

### `Shape.faceLPropValue(u:v:)`

Evaluate the 3D point on a face at the given `(u, v)` parameter.

```swift
public func faceLPropValue(u: Double, v: Double) -> SIMD3<Double>
```

- **OCCT:** `BRepLProp_SLProps::Value` via `OCCTFaceLPropValue`.

---

### `Shape.faceLPropNormal(u:v:)`

Surface normal on a face at `(u, v)`.

```swift
public func faceLPropNormal(u: Double, v: Double) -> SIMD3<Double>?
```

- **Returns:** Unit normal, or `nil` if the normal is undefined (e.g. at a singular point).
- **OCCT:** `BRepLProp_SLProps::Normal` via `OCCTFaceLPropNormal`.

---

### `Shape.faceLPropMaxCurvature(u:v:)`

Maximum principal curvature on a face at `(u, v)`.

```swift
public func faceLPropMaxCurvature(u: Double, v: Double) -> Double
```

- **OCCT:** `BRepLProp_SLProps::MaxCurvature` via `OCCTFaceLPropMaxCurvature`.

---

### `Shape.faceLPropMinCurvature(u:v:)`

Minimum principal curvature on a face at `(u, v)`.

```swift
public func faceLPropMinCurvature(u: Double, v: Double) -> Double
```

- **OCCT:** `BRepLProp_SLProps::MinCurvature` via `OCCTFaceLPropMinCurvature`.

---

### `Shape.faceLPropMeanCurvature(u:v:)`

Mean curvature `(κ₁ + κ₂) / 2` on a face at `(u, v)`.

```swift
public func faceLPropMeanCurvature(u: Double, v: Double) -> Double
```

- **OCCT:** `BRepLProp_SLProps::MeanCurvature` via `OCCTFaceLPropMeanCurvature`.

---

### `Shape.faceLPropGaussianCurvature(u:v:)`

Gaussian curvature `κ₁ · κ₂` on a face at `(u, v)`.

```swift
public func faceLPropGaussianCurvature(u: Double, v: Double) -> Double
```

- **OCCT:** `BRepLProp_SLProps::GaussianCurvature` via `OCCTFaceLPropGaussianCurvature`.

---

### `Shape.faceLPropIsUmbilic(u:v:)`

Test whether a face is umbilic at `(u, v)` — both principal curvatures are equal.

```swift
public func faceLPropIsUmbilic(u: Double, v: Double) -> Bool
```

- **OCCT:** `BRepLProp_SLProps::IsUmbilic` via `OCCTFaceLPropIsUmbilic`.

---

### `Shape.faceLPropTangentU(u:v:)`

Tangent in the U direction on a face at `(u, v)`.

```swift
public func faceLPropTangentU(u: Double, v: Double) -> SIMD3<Double>?
```

- **Returns:** U tangent, or `nil` if not defined.
- **OCCT:** `BRepLProp_SLProps::TangentU` via `OCCTFaceLPropTangentU`.
- **Example:**
  ```swift
  let face: Shape = ...
  if let n = face.faceLPropNormal(u: 0.5, v: 0.5) {
      print("normal:", n)
  }
  let gauss = face.faceLPropGaussianCurvature(u: 0.5, v: 0.5)
  ```

---

## GridEval Curve3D Extensions

Extension on `Curve3D` for optimized batch evaluation using `GeomGridEval_Curve`. Preferred over calling `evalD0` / `evalD1` in a loop for large parameter sets.

### `Curve3D.gridEvalD0(params:)`

Batch-evaluate 3D curve positions at multiple parameters (D0).

```swift
public func gridEvalD0(params: [Double]) -> [SIMD3<Double>]
```

- **Returns:** Point for each input parameter, in the same order.
- **OCCT:** `GeomGridEval_Curve` D0 via `OCCTGridEvalCurveD0`.
- **Example:**
  ```swift
  let pts = myCurve.gridEvalD0(params: stride(from: 0, through: 1, by: 0.1).map { $0 })
  ```

---

### `Curve3D.gridEvalD1(params:)`

Batch-evaluate 3D curve positions and first derivatives at multiple parameters.

```swift
public func gridEvalD1(params: [Double]) -> [(point: SIMD3<Double>, d1: SIMD3<Double>)]
```

- **Returns:** `(point, first derivative)` tuples in input order.
- **OCCT:** `GeomGridEval_Curve` D1 via `OCCTGridEvalCurveD1`.

---

## GridEval Curve2D Extensions

Extension on `Curve2D` for optimized batch evaluation using `Geom2dGridEval_Curve`.

### `Curve2D.gridEvalD0(params:)`

Batch-evaluate 2D curve positions at multiple parameters.

```swift
public func gridEvalD0(params: [Double]) -> [SIMD2<Double>]
```

- **OCCT:** `Geom2dGridEval_Curve` D0 via `OCCTGridEvalCurve2dD0`.

---

### `Curve2D.gridEvalD1(params:)`

Batch-evaluate 2D curve positions and first derivatives.

```swift
public func gridEvalD1(params: [Double]) -> [(point: SIMD2<Double>, d1: SIMD2<Double>)]
```

- **OCCT:** `Geom2dGridEval_Curve` D1 via `OCCTGridEvalCurve2dD1`.

---

## GridEval Surface Extensions

Extension on `Surface` for optimized grid evaluation using `GeomGridEval_Surface`. Output is row-major with dimensions `[uParams.count × vParams.count]`.

### `Surface.gridEvalD0(uParams:vParams:)`

Batch-evaluate surface positions at a UV grid.

```swift
public func gridEvalD0(uParams: [Double], vParams: [Double]) -> [SIMD3<Double>]
```

- **Returns:** Row-major point array, length `uParams.count × vParams.count`.
- **OCCT:** `GeomGridEval_Surface` D0 via `OCCTGridEvalSurfaceD0`.
- **Example:**
  ```swift
  let us = [0.0, 0.5, 1.0]
  let vs = [0.0, 0.5, 1.0]
  let pts = mySurface.gridEvalD0(uParams: us, vParams: vs)
  // pts[row * vs.count + col] = point at (us[row], vs[col])
  ```

---

### `Surface.gridEvalD1(uParams:vParams:)`

Batch-evaluate surface positions and first partial derivatives at a UV grid.

```swift
public func gridEvalD1(uParams: [Double], vParams: [Double]) -> [(point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)]
```

- **Returns:** Row-major array of `(point, ∂/∂u, ∂/∂v)` tuples.
- **OCCT:** `GeomGridEval_Surface` D1 via `OCCTGridEvalSurfaceD1`.

---

## Curve3D Evaluation

Extension on `Curve3D` for single-parameter evaluation at up to D3. These complement the `gridEval*` batch methods for scalar queries.

### `Curve3D.evalD0(at:)`

Evaluate curve position at parameter `u`.

```swift
public func evalD0(at u: Double) -> SIMD3<Double>
```

- **OCCT:** `Geom_Curve::D0` via `OCCTCurve3DEvalD0`.

---

### `Curve3D.evalD1(at:)`

Evaluate curve position and first derivative at `u`.

```swift
public func evalD1(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>)
```

- **OCCT:** `Geom_Curve::D1` via `OCCTCurve3DEvalD1`.

---

### `Curve3D.evalD2(at:)`

Evaluate curve position and first and second derivatives at `u`.

```swift
public func evalD2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>)
```

- **OCCT:** `Geom_Curve::D2` via `OCCTCurve3DEvalD2`.

---

### `Curve3D.evalD3(at:)`

Evaluate curve position and first, second, and third derivatives at `u`.

```swift
public func evalD3(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>)
```

- **OCCT:** `Geom_Curve::D3` via `OCCTCurve3DEvalD3`.
- **Example:**
  ```swift
  let (pt, d1, d2, d3) = myCurve.evalD3(at: 0.5)
  ```

---

### `Curve3D.evalBatchD0(params:)`

Evaluate positions at multiple parameters (batch D0).

```swift
public func evalBatchD0(params: [Double]) -> [SIMD3<Double>]
```

- **OCCT:** `Geom_Curve::D0` (batch) via `OCCTCurve3DEvalBatchD0`.

---

### `Curve3D.evalBatchD1(params:)`

Evaluate positions and first derivatives at multiple parameters (batch D1).

```swift
public func evalBatchD1(params: [Double]) -> [(point: SIMD3<Double>, d1: SIMD3<Double>)]
```

- **OCCT:** `Geom_Curve::D1` (batch) via `OCCTCurve3DEvalBatchD1`.

---

## Curve2D Evaluation

Extension on `Curve2D` for single-parameter evaluation at up to D2.

### `Curve2D.evalD0(at:)`

Evaluate 2D curve position at parameter `u`.

```swift
public func evalD0(at u: Double) -> SIMD2<Double>
```

- **OCCT:** `Geom2d_Curve::D0` via `OCCTCurve2DEvalD0`.

---

### `Curve2D.evalD1(at:)`

Evaluate 2D curve position and first derivative at `u`.

```swift
public func evalD1(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>)
```

- **OCCT:** `Geom2d_Curve::D1` via `OCCTCurve2DEvalD1`.

---

### `Curve2D.evalD2(at:)`

Evaluate 2D curve position and first and second derivatives at `u`.

```swift
public func evalD2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>)
```

- **OCCT:** `Geom2d_Curve::D2` via `OCCTCurve2DEvalD2`.

---

### `Curve2D.evalBatchD0(params:)`

Evaluate 2D positions at multiple parameters (batch D0).

```swift
public func evalBatchD0(params: [Double]) -> [SIMD2<Double>]
```

- **OCCT:** `Geom2d_Curve::D0` (batch) via `OCCTCurve2DEvalBatchD0`.

---

### `Curve2D.evalBatchD1(params:)`

Evaluate 2D positions and first derivatives at multiple parameters (batch D1).

```swift
public func evalBatchD1(params: [Double]) -> [(point: SIMD2<Double>, d1: SIMD2<Double>)]
```

- **OCCT:** `Geom2d_Curve::D1` (batch) via `OCCTCurve2DEvalBatchD1`.

---

## Surface Evaluation

Extension on `Surface` for single `(u, v)` evaluation at up to D2.

### `Surface.evalD0(u:v:)`

Evaluate surface position at `(u, v)`.

```swift
public func evalD0(u: Double, v: Double) -> SIMD3<Double>
```

- **OCCT:** `Geom_Surface::D0` via `OCCTSurfaceEvalD0`.

---

### `Surface.evalD1(u:v:)`

Evaluate surface position and first partial derivatives at `(u, v)`.

```swift
public func evalD1(u: Double, v: Double) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)
```

- **OCCT:** `Geom_Surface::D1` via `OCCTSurfaceEvalD1`.

---

### `Surface.evalD2(u:v:)`

Evaluate surface position, first and second partial derivatives at `(u, v)`.

```swift
public func evalD2(u: Double, v: Double) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>, d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>)
```

- **OCCT:** `Geom_Surface::D2` via `OCCTSurfaceEvalD2`.
- **Example:**
  ```swift
  let (pt, du, dv, d2u, d2v, d2uv) = mySurface.evalD2(u: 0.5, v: 0.5)
  let normal = (du.cross(dv)).normalized
  ```

---

## math\_NewtonMinimum

Extension on `MathSolver` adding Newton's Hessian-based minimizer. Introduced v0.111.1.

### `MathSolver.minimizeNewton(variables:startPoint:tolerance:maxIterations:function:)`

Minimize a multivariate function using Newton's method with analytical Hessian — the most precise local minimizer when second derivatives are available.

```swift
public static func minimizeNewton(
    variables n: Int,
    startPoint: [Double],
    tolerance: Double = 1e-8,
    maxIterations: Int = 40,
    function: @escaping ([Double]) -> (value: Double, gradient: [Double], hessian: [Double])
) -> (point: [Double], minimum: Double)?
```

- **Parameters:**
  - `n` — number of variables.
  - `startPoint` — initial guess, length `n`.
  - `function` — closure returning `(f(x), ∇f(x)[n], H(x)[n×n] row-major)`.
- **Returns:** `(minimizer, f(minimizer))`, or `nil` if not converged.
- **OCCT:** `math_NewtonMinimum` via `OCCTMathNewtonMinimum`.
- **Note:** Quadratic convergence near the minimum; requires a positive-definite Hessian. Falls back gracefully but may not converge if the Hessian is indefinite away from the minimum — in that case, prefer `minimize` (BFGS).
- **Example:**
  ```swift
  // Minimize f(x,y) = x² + y²  (minimum at origin)
  if let res = MathSolver.minimizeNewton(variables: 2, startPoint: [1.0, 1.0]) { x in
      let v = x[0]*x[0] + x[1]*x[1]
      let g = [2*x[0], 2*x[1]]
      let h = [2.0, 0.0, 0.0, 2.0]  // row-major 2×2 identity * 2
      return (v, g, h)
  } {
      print(res.point)    // ≈ [0, 0]
      print(res.minimum)  // ≈ 0
  }
  ```
