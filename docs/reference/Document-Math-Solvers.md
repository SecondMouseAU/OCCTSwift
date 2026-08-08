---
title: Document — Math Solvers & Local Properties
parent: API Reference
---

# Document — Math Solvers & Local Properties

This page covers `Document.swift`'s Math Solvers & Local Properties additions: 2D conic utilities, normal projection, disk/shared-library/message system helpers, `PlateSolver` constraint extensions, extra methods on `Shape`, `Curve3D`, `Curve2D`, and `Surface`, the full `MathSolver` numerical toolkit, `PolynomialSolver` Laguerre extensions, `BRepLProp` edge/face local properties, the deprecated `GeomGridEval` batch-evaluation spellings (#486), single-parameter curve/surface evaluators, and the Newton-Hessian minimizer.

> See also the main **[Document](Document.md)** page for the `Document` class itself and the other chunk pages.

## Topics

- [IntAna2d\_Conic — 2D Conics](#intana2d_conic--2d-conics) · [BRepAlgo\_NormalProjection](#brepalgo_normalprojection) · [OSD\_Disk](#osd_disk) · [OSD\_SharedLibrary](#osd_sharedlibrary) · [Message\_Msg](#message_msg) · [Plate Constraint Extensions](#plate-constraint-extensions) · [Shape Topology Extras](#shape-topology-extras) · [Curve3D Extras](#curve3d-extras) · [Curve2D Extras](#curve2d-extras) · [Surface Extras](#surface-extras) · [Math Solvers](#math-solvers) · [PolynomialSolver Laguerre Extensions](#polynomialsolver-laguerre-extensions) · [BRepLProp Edge Extensions](#breplprop-edge-extensions) · [BRepLProp Face Extensions](#breplprop-face-extensions) · [GridEval Extensions, deprecated](#grideval-extensions-deprecated-486) · [Curve3D Evaluation](#curve3d-evaluation) · [Curve2D Evaluation](#curve2d-evaluation) · [Surface Evaluation](#surface-evaluation) · [math\_NewtonMinimum](#math_newtonminimum)

---

## IntAna2d\_Conic — 2D Conics

`Conic2D` is a value type holding the six implicit coefficients of a 2D conic
`a·x² + b·y² + 2c·x·y + 2d·x + 2e·y + f = 0`, plus static factories and a line-circle
intersection query. Wraps `IntAna2d_Conic` / `IntAna2d_AnaIntersection`.

### `Conic2D`

Coefficients of a 2D implicit conic `a·x² + b·y² + 2c·x·y + 2d·x + 2e·y + f = 0`.

```swift
public struct Conic2D: Sendable {
    public let a, b, c, d, e, f: Double
}
```

The coefficients are OCCT's, in OCCT's order: the conic is the point set satisfying

```
a·x² + b·y² + 2c·x·y + 2d·x + 2e·y + f = 0
```

`b` is the `y²` coefficient and `c` the `x·y` one, and the cross and linear terms carry a factor
of 2. (Through v1.17.0 the doc comment named `a·x² + b·x·y + c·y² + d·x + e·y + f = 0`, which swaps
the roles of `b` and `c` and drops the factor; the values themselves never changed. #514)

Every factory returns `nil` rather than a conic when a dimension is degenerate. There is no
in-band way to say it: all-zero coefficients are the equation `0 = 0`, which holds at every point
of the plane, so they read as a conic rather than as no answer.

---

### `Conic2D.circle(center:direction:radius:)`

The implicit conic of a 2D circle.

```swift
public static func circle(
    center: SIMD2<Double>, direction: SIMD2<Double>, radius: Double
) -> Conic2D?
```

- **Parameters:** `center`: circle centre; `direction`: local X axis direction, must be non-zero; `radius`: circle radius, must be greater than zero.
- **Returns:** the six implicit coefficients, or `nil` when a dimension is degenerate.
- **OCCT:** `IntAna2d_Conic` (circle constructor) via `OCCTConic2dFromCircle`.
- **Example:**
  ```swift
  if let c = Conic2D.circle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 3) {
      print(c.a, c.b, c.f)   // 1.0 1.0 -9.0   (x² + y² - 9 = 0)
  }
  ```

---

### `Conic2D.line(point:direction:)`

The implicit conic of a 2D line.

```swift
public static func line(
    point: SIMD2<Double>, direction: SIMD2<Double>
) -> Conic2D?
```

- **Parameters:** `point`: any point on the line; `direction`: line direction vector, must be non-zero.
- **Returns:** the coefficients, whose non-zero linear terms describe the line, or `nil` for a zero direction.
- **OCCT:** `IntAna2d_Conic` (line constructor) via `OCCTConic2dFromLine`.
- **Example:**
  ```swift
  if let l = Conic2D.line(point: .zero, direction: SIMD2(1, 0)) {
      print(l.e)   // non-zero: the y term of the line y = 0
  }
  ```

---

### `Conic2D.ellipse(center:direction:majorRadius:minorRadius:)`

The implicit conic of a 2D ellipse.

```swift
public static func ellipse(
    center: SIMD2<Double>, direction: SIMD2<Double>,
    majorRadius: Double, minorRadius: Double
) -> Conic2D?
```

- **Parameters:** `center`: ellipse centre; `direction`: local X axis, must be non-zero; `majorRadius` / `minorRadius`: semi-axes, both greater than zero with `minorRadius <= majorRadius`. Equal radii are a circle and are valid.
- **Returns:** the six implicit conic coefficients, or `nil` when a dimension is degenerate.
- **OCCT:** `IntAna2d_Conic` (ellipse constructor) via `OCCTConic2dFromEllipse`.
- **Example:**
  ```swift
  if let e = Conic2D.ellipse(center: .zero, direction: SIMD2(1, 0),
                             majorRadius: 5, minorRadius: 3) {
      print(e.a, e.b, e.f)   // 0.04 0.111… -1.0   (x²/25 + y²/9 - 1 = 0)
  }
  ```

---

### Deprecated: `Conic2D.fromCircle` / `fromLine` / `fromEllipse`

The three original spellings return a non-optional `Conic2D`, so their only way to report a
degenerate input is the all-zero struct, which describes no conic. They remain, deprecated,
forwarding to the factories above and returning all zeros where those return `nil`.

```swift
// before
let e = Conic2D.fromEllipse(center: .zero, direction: SIMD2(1, 0),
                            majorRadius: 5, minorRadius: 3)

// after
if let e = Conic2D.ellipse(center: .zero, direction: SIMD2(1, 0),
                           majorRadius: 5, minorRadius: 3) { … }
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

- **Parameters:** `radius` must be greater than zero. Intersecting against a radius-0 circle is a point-on-line test, not an intersection, and returns an empty array.
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

**Unavailable** (#619) — use `Surface.continuityClass`, or `Surface.continuity` for a raw ordinal.
Any use is a compile error.

```swift
@available(*, unavailable, message: "...")
public var surfaceContinuityOrder: Int { get }
```

This page previously documented the encoding as `0=C0, 1=C1, 2=C2, 3=C3, 99=CN`. That was the
hand-invented scheme #485 replaced with the real `GeomAbs_Shape` ordinal (`0=C0, 1=G1, 2=C1, 3=G2,
4=C2, 5=C3, 6=CN`); the page was not updated at the time, so it went on describing retired numbers.
Because the type and name were unchanged, `surfaceContinuityOrder >= 2` kept compiling and went from
meaning "at least C2" to meaning "at least C1". #619 retires the spelling so that becomes an error.

```swift
// A continuity floor — takes the request vocabulary by type, so the wrong
// constant cannot be written at all.
if surface.continuityClass.satisfies(.c2) { offsetSafely() }

// The analytic fast path that `== 99` used to express.
if surface.continuityClass == .cN { useAnalyticFastPath() }
```

- **OCCT:** `Geom_Surface::Continuity` via `OCCTSurfaceGetContinuity`.
- **No error sentinel.** The retired encoding returned `-1` for a null or unreadable handle and from its `default:` branch; `continuity` returns `0`, which is an ordinary C0. A migrated `< 0` error check can never fire (#619).

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
- **Bounds:** `variables` and `equations` must both be positive, and `startPoint.count` must
  equal `variables`, or this returns `nil` (#640). None of this was checked before: a negative
  `variables` reached `Array(repeating:count:)` and trapped, and a positive `variables` that did
  not match `startPoint`'s real length reached the bridge's unconditional `startPoint[i]` loop
  and read out of bounds. `values`/`jacobian`'s own returned arrays are checked the same way
  (#716's review findings 3/4): a `values` closure returning fewer than `equations` elements, or
  a `jacobian` closure returning fewer than `equations * variables`, now fails the call (`nil`)
  instead of indexing the short array and trapping.
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
- **Bounds:** `variables` must be positive and equal `startPoint.count`, or this returns `nil`
  (#640): a mismatched positive `variables` used to reach the bridge's unconditional
  `startPoint[i]` loop and read out of bounds. `function`'s own returned `gradient` is checked
  the same way (#716's review finding 5): a closure returning fewer than `variables` gradient
  components now fails the call (`nil`) instead of trapping.
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
- **Bounds:** Same as `minimize`: `variables` must be positive and equal `startPoint.count`
  (#640).
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
- **Bounds:** `variables` must be positive, and `lower`/`upper`/`steps` must each have
  `variables` elements, or this returns `nil` (#640): none of this was checked before, so the
  bridge's unconditional `lower[i]`/`upper[i]`/`steps[i]` loop read out of bounds on a mismatch.
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
- **Bounds:** `variables` must be positive, and `lower`/`upper` must each have `variables`
  elements, or this returns `nil` (#640), for the same reason as `particleSwarm`.
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
- **Bounds:** `samples` is a sampler by name and by role, not a problem dimension, so it is
  bounded through `Sampling.requested` like every other subdivision count in this library:
  outside `1...10,000,000` this returns `[]` instead of trapping `Int32(samples)` past
  `Int32.max` (#640).
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
- **Bounds:** Same as `solveSystem`: `variables` and `equations` must both be positive, and
  `startPoint.count` must equal `variables`, or this returns `nil` (#640), including the
  `values`/`jacobian` closure-length check (#716's review finding 3/4).
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

These read an edge through a `BRepAdaptor_Curve`; [`Edge.curvature(at:)`](Edge.md) and its siblings
read the curve underneath directly. Since #529 both decide whether a quantity exists at the same
resolution (`Precision::Confusion()`), so the two spellings agree about definedness at every
parameter of every edge. The values themselves can still differ in the last bits, because the
adaptor evaluates a Bezier or B-spline through a cache the raw handle does not use.

### `Shape.edgeLPropValue(at:)`

Evaluate the 3D point on an edge at the given parameter.

```swift
public func edgeLPropValue(at param: Double) -> SIMD3<Double>?
```

- **Returns:** Point on the edge curve at `param`, or `nil` for a parameter the edge cannot be
  evaluated at. Before #529 the failure case returned `(0, 0, 0)` inside a non-`nil` optional.
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
public func edgeCurvatureLP(at param: Double) -> Double?
```

- **Returns:** Curvature magnitude: `0` for a straight edge, which is a real answer, and `nil` where
  there is none — this `Shape` is not an edge, the parameter cannot be evaluated, or the tangent is
  undefined there. Those were the same `0` until #595, and the degeneracy is not exotic: a sphere
  carries a **degenerate edge at each pole**, with no 3D curve at all, and edge traversal does not
  skip them. `Double.greatestFiniteMagnitude` (OCCT's `RealLast()`, meaning infinite curvature) is
  still reported at a cusp, matching [`Edge.curvature(at:)`](Edge.md) on the curve underneath.
- **OCCT:** `BRepLProp_CLProps::Curvature` via `OCCTEdgeLPropCurvature`.

---

### `Shape.edgeNormalLP(at:)`

Normal direction on an edge at the given parameter.

```swift
public func edgeNormalLP(at param: Double) -> SIMD3<Double>?
```

- **Returns:** Unit normal in the osculating plane, or `nil` where the curvature cannot be inverted
  into a direction — a straight stretch has no normal, and neither does a cusp. Before #529 both
  cases returned `(0, 0, 0)`, which is not a direction (#529, source-breaking).
- **OCCT:** `BRepLProp_CLProps::Normal` via `OCCTEdgeLPropNormal`.

---

### `Shape.edgeCentreOfCurvature(at:)`

Centre of curvature on an edge at the given parameter.

```swift
public func edgeCentreOfCurvature(at param: Double) -> SIMD3<Double>?
```

- **Returns:** The centre of the osculating circle at `param`, or `nil` where there is no such
  circle (a straight stretch, or a cusp). Before #529 a near-cusp returned `(nan, inf, nan)` as
  though it were a point: `CentreOfCurvature()` tests only `|Curvature()| <= resolution`, which
  OCCT's infinite-curvature sentinel passes, and then divides by a field that path never assigned
  (#529, source-breaking).
- **OCCT:** `BRepLProp_CLProps::CentreOfCurvature` via `OCCTEdgeLPropCentreOfCurvature`.

---

### `Shape.edgeLPropD1(at:)`

First derivative vector on an edge at the given parameter.

```swift
public func edgeLPropD1(at param: Double) -> SIMD3<Double>?
```

- **Returns:** The first derivative `C'(param)`, or `nil` for a parameter the edge cannot be
  evaluated at (#529, source-breaking).
- **OCCT:** `BRepLProp_CLProps::D1` via `OCCTEdgeLPropD1`.
- **Example:**
  ```swift
  let edge: Shape = ...  // an edge shape
  let tangent = edge.edgeTangent(at: 0.5)
  let curv    = edge.edgeCurvatureLP(at: 0.5)   // Double?
  ```

---

## BRepLProp Face Extensions

Extension on `Shape` for face-level local surface properties using `BRepLProp_SLProps`.

The `Face` counterparts ([`Face.meanCurvature(atU:v:)`](Face.md) and siblings) read the surface
under the face directly rather than through a `BRepAdaptor_Surface`. Since #529 both use the same
resolution, so they agree about whether a curvature exists at a given `(u, v)`, and since #583 both
can say so: the getters here return an optional rather than spelling "undefined" as `0`. One
contract difference is deliberate: `faceLPropNormal(u:v:)` reports the *surface* normal, while
[`Face.normal(atU:v:)`](Face.md) applies the face's orientation, so the two agree up to sign.

`nil` from any of them means one of: the curvature is undefined at that point (a cone apex, a sphere
pole), or the receiver is not a single face. It never means "flat here", because `0` is a value these
getters produce at every point of any developable surface, which is what made the old encoding
lossy. Migration from the pre-#583 signatures is `if let`, or `?? 0` for the previous behaviour.

### `Shape.faceLPropValue(u:v:)`

Evaluate the 3D point on a face at the given `(u, v)` parameter.

```swift
public func faceLPropValue(u: Double, v: Double) -> SIMD3<Double>?
```

- **Returns:** The point, or `nil` if the receiver is not a single face. Unlike the curvature
  getters this does not depend on the curvature gate, so a cone apex and a sphere pole still report
  a point.
- **OCCT:** `BRepLProp_SLProps::Value` via `OCCTFaceLPropValue`.
- **Example:**
  ```swift
  let cylinder = Shape.cylinder(radius: 3, height: 12)!
  if let p = cylinder.subShapes(ofType: .face)[0].faceLPropValue(u: 1.1, v: 6) {
      print("point:", p)
  }
  ```

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
public func faceLPropMaxCurvature(u: Double, v: Double) -> Double?
```

- **Returns:** The curvature, or `nil` where it is undefined. On a cylinder or a cone the answer is
  exactly `0` (the direction along the axis) at every point, and that is a value, not an absence.
- **OCCT:** `BRepLProp_SLProps::MaxCurvature` via `OCCTFaceLPropMaxCurvature`.
- **Example:**
  ```swift
  let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
  #expect(cylinder.faceLPropMaxCurvature(u: 1.1, v: 6) == 0)   // defined, and zero
  ```

---

### `Shape.faceLPropMinCurvature(u:v:)`

Minimum principal curvature on a face at `(u, v)`.

```swift
public func faceLPropMinCurvature(u: Double, v: Double) -> Double?
```

- **Returns:** The curvature, or `nil` where it is undefined.
- **OCCT:** `BRepLProp_SLProps::MinCurvature` via `OCCTFaceLPropMinCurvature`.
- **Example:**
  ```swift
  let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
  if let kMin = cylinder.faceLPropMinCurvature(u: 1.1, v: 6) { print(kMin) }   // -1/3
  ```

---

### `Shape.faceLPropMeanCurvature(u:v:)`

Mean curvature `(κ₁ + κ₂) / 2` on a face at `(u, v)`.

```swift
public func faceLPropMeanCurvature(u: Double, v: Double) -> Double?
```

- **Returns:** The curvature, or `nil` where it is undefined. The adaptor-backed counterpart of
  [`Face.meanCurvature(atU:v:)`](Face.md), which the two now agree with exactly about.
- **OCCT:** `BRepLProp_SLProps::MeanCurvature` via `OCCTFaceLPropMeanCurvature`.
- **Example:**
  ```swift
  let sphere = Shape.sphere(radius: 5)!.subShapes(ofType: .face)[0]
  if let h = sphere.faceLPropMeanCurvature(u: 0, v: 0) { print(h) }   // -0.2, i.e. -1/r
  ```

---

### `Shape.faceLPropGaussianCurvature(u:v:)`

Gaussian curvature `κ₁ · κ₂` on a face at `(u, v)`.

```swift
public func faceLPropGaussianCurvature(u: Double, v: Double) -> Double?
```

- **Returns:** The curvature, or `nil` where it is undefined. Every developable surface (a
  cylinder, a cone, a plane) has Gaussian curvature `0` everywhere, so this getter returned the
  pre-#583 "undefined" sentinel for whole faces at a time.
- **OCCT:** `BRepLProp_SLProps::GaussianCurvature` via `OCCTFaceLPropGaussianCurvature`.
- **Example:**
  ```swift
  let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
  #expect(cylinder.faceLPropGaussianCurvature(u: 1.1, v: 6) == 0)   // defined, and zero
  ```

---

### `Shape.faceLPropIsUmbilic(u:v:)`

Test whether a face is umbilic at `(u, v)` — both principal curvatures are equal.

```swift
public func faceLPropIsUmbilic(u: Double, v: Double) -> Bool?
```

- **Returns:** The answer, or `nil` where there are no principal curvatures to compare. OCCT's test
  is one ULP wide rather than a geometric tolerance, so a plane qualifies everywhere but an
  analytically-umbilic sphere qualifies only where the two computed values round to the same
  `Double` (#494).
- **OCCT:** `BRepLProp_SLProps::IsUmbilic` via `OCCTFaceLPropIsUmbilic`.
- **Example:**
  ```swift
  let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
  #expect(cylinder.faceLPropIsUmbilic(u: 1.1, v: 6) == false)   // defined, and not umbilic
  ```

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

## GridEval Extensions, removed at v2.0.0 (#784)

`Curve3D`/`Curve2D`/`Surface` each carried a third spelling of batch evaluation
(`gridEvalD0`/`D1`, deprecated by #486 in favour of `evaluateGrid`/`evaluateGridD1`), over a third
generation of bridge functions (`OCCTGridEvalCurveD0`/`D1`, `OCCTGridEvalCurve2dD0`/`D1`,
`OCCTGridEvalSurfaceD0`/`D1`) that called exactly the same OCCT evaluators as the v0.28.0/v0.29.0
ones already did. Worse, the Surface pair wrote the *opposite* UV layout from
`OCCTSurfaceEvaluateGrid` while both header comments described their own layout as "row-major".

#486 removed that bridge generation and pointed the six deprecated methods at their canonical
sibling; #784 removed the six methods themselves. Use
[`Curve3D.evaluateGrid(_:)`](Curve3D-Analysis.md)/`evaluateGridD1(_:)`,
`Curve2D.evaluateGrid(_:)`/`evaluateGridD1(_:)` (both label the derivative `tangent`, not `d1`), or
[`Surface.evaluateGrid(uParameters:vParameters:)`](Surface-Analysis.md#evaluategriduparametersvparameters)/[`evaluateGridD1(uParameters:vParameters:)`](Surface-Analysis.md#evaluategridd1uparametersvparameters),
which return a `SurfaceGrid`/`SurfaceGridD1` indexed `.at(u:v:)` instead of a flat array whose
major order the caller had to know:

```swift
// Before (removed)
let pts = mySurface.gridEvalD0(uParams: us, vParams: vs)
let p = pts[u * vs.count + v]

// Now
let grid = mySurface.evaluateGrid(uParameters: us, vParameters: vs)
let p = grid.at(u: u, v: v)
```

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

`Curve3D.evalBatchD0(params:)`/`evalBatchD1(params:)`, deprecated by #486 in favour of
`Curve3D.evaluateGrid(_:)`/`evaluateGridD1(_:)`, were removed at v2.0.0 (#784). They had called
`Geom_Curve::EvalD0`/`EvalD1` once per parameter, bypassing the batch `GeomGridEval_Curve`
evaluator `evaluateGrid` had already been using since v0.29.0; #486 pointed them at the batch path
instead (results can differ from the old per-point loop by ~1e-13 on a BSpline), and `evaluateGridD1`
labels the derivative `tangent`, not `d1`.

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

`Curve2D.evalBatchD0(params:)`/`evalBatchD1(params:)` were the 2D counterpart, same story as the 3D
pair above, and were also removed at v2.0.0 (#784). Use `Curve2D.evaluateGrid(_:)`/`evaluateGridD1(_:)`.

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
- **Bounds:** `n` must be positive and equal `startPoint.count`, or this returns `nil` (#640),
  for the same reason as `minimize`. `function`'s own returned `gradient` and `hessian` are
  checked the same way (#716's review finding 5): a closure returning fewer than `n` gradient
  components, or fewer than `n * n` Hessian components, now fails the call (`nil`) instead of
  trapping.
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
