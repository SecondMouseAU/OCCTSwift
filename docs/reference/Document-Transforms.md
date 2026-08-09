---
title: Document — Coordinate Systems, Transforms & Completions
parent: API Reference
---

# Document — Coordinate Systems, Transforms & Completions

This page covers the geometry, math, and completion APIs exposed in `Document.swift`: coordinate systems, 2D transforms, matrix math, quaternion interpolation, vector utilities, numeric solvers, unit conversion, local surface/curve properties, projection, bounding boxes, shape analysis, boolean checking, defeaturing, polynomial conversion, transform extras, topology extras, sewing extras, and BREP serialization. See the main [`Document`](Document.md) page for XCAF assembly, attribute, and STEP/OCAF I/O.

## Topics

- [CoordinateSystem3D (gp_Ax3)](#coordinatesystem3d-gpax3) · [GeneralTransform2D (gp_GTrsf2d)](#generaltransform2d-gpgtrsf2d) · [Matrix2D (gp_Mat2d)](#matrix2d-gpmat2d) · [Quaternion Interpolation](#quaternion-interpolation) · [XY/XYZ Utilities](#xyxyz-utilities) · [MathSolver Extensions](#mathsolver-extensions) · [PolynomialSolver rc4 Extensions](#polynomialsolver-rc4-extensions) · [MathInteg rc4 Extensions](#mathinteg-rc4-extensions) · [UnitsConversion](#unitsconversion) · [Curve3D LProp3d Extensions](#curve3d-lprop3d-extensions) · [Surface LProp3d Extensions](#surface-lprop3d-extensions) · [ProjLib](#projlib) · [BRepBndLib Extensions](#brepbndlib-extensions) · [ShapeAnalysis_ShapeTolerance Extensions](#shapeanalysis_shapetolerance-extensions) · [BRepAlgoAPI_Check Extensions](#brepalgoapi_check-extensions) · [BRepAlgoAPI_Defeaturing Extensions](#brepalgoapi_defeaturing-extensions) · [Convert_CompPolynomialToPoles](#convert_comppolynomialtopoles) · [gp_Trsf Extras](#gp_trsf-extras) · [TopExp Extras](#topexp-extras) · [BRep_Tool Extras](#brep_tool-extras) · [Sewing Extras](#sewing-extras) · [BREP Serialization / gp Distance & Contains / BezierSurface / Curve2D Extras / BSplineSurface Extras](#brep-serialization--gp-distance--contains--beziersurface--curve2d-extras--bsplinesurface-extras)

---

## CoordinateSystem3D (gp_Ax3)

A right- or left-handed 3D coordinate system (origin + main direction + X direction + computed Y direction), wrapping `gp_Ax3`.

### `CoordinateSystem3D.init(origin:direction:xDirection:)`

Create from origin, main direction, and explicit X direction.

```swift
public init(origin: SIMD3<Double>, direction: SIMD3<Double>, xDirection: SIMD3<Double>)
```

OCCT normalises and orthogonalises the input vectors; computed `xDirection`, `yDirection`, and `isDirect` are stored on the value.

- **Parameters:** `origin` — position; `direction` — main (Z) axis; `xDirection` — desired X axis (will be corrected to be orthogonal).
- **OCCT:** `OCCTAx3Create` → `gp_Ax3(gp_Pnt, gp_Dir, gp_Dir)`.
- **Example:**
  ```swift
  let cs = CoordinateSystem3D(
      origin: SIMD3(0, 0, 0),
      direction: SIMD3(0, 0, 1),
      xDirection: SIMD3(1, 0, 0))
  // cs.isDirect == true
  ```

---

### `CoordinateSystem3D.init(origin:direction:)`

Create from origin and main direction only; X/Y axes are auto-computed.

```swift
public init(origin: SIMD3<Double>, direction: SIMD3<Double>)
```

- **Parameters:** `origin` — position; `direction` — main (Z) axis. X and Y are chosen by OCCT.
- **OCCT:** `OCCTAx3CreateFromNormal` → `gp_Ax3(gp_Pnt, gp_Dir)`.
- **Example:**
  ```swift
  let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 1, 0))
  ```

---

### `CoordinateSystem3D.isDirect`

Whether this coordinate system is right-handed (direct).

```swift
public let isDirect: Bool
```

Computed by both initializers from the supplied direction(s) and stored on the value; `false` means
the system is left-handed (indirect).

- **OCCT:** `gp_Ax3::Direct()`.
- **Example:**
  ```swift
  let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
  print(cs.isDirect)   // true
  ```

---

### `CoordinateSystem3D.angle(to:)`

Angle in radians between this and another coordinate system.

```swift
public func angle(to other: CoordinateSystem3D) -> Double
```

- **Parameters:** `other` — the reference coordinate system.
- **Returns:** Angle in radians.
- **OCCT:** `OCCTAx3Angle` → `gp_Ax3::Angle`.

---

### `CoordinateSystem3D.isCoplanar(with:linearTolerance:angularTolerance:)`

Check if two coordinate systems are coplanar.

```swift
public func isCoplanar(
    with other: CoordinateSystem3D,
    linearTolerance: Double = 1e-6,
    angularTolerance: Double = 1e-6
) -> Bool
```

- **Parameters:** `other` — second coordinate system; `linearTolerance` — position tolerance; `angularTolerance` — angular tolerance.
- **Returns:** `true` when the two XY planes are coincident within tolerances.
- **OCCT:** `OCCTAx3IsCoplanar` → `gp_Ax3::IsCoplanar`.

---

### `CoordinateSystem3D.mirrored(about:)`

Mirror this coordinate system about a point.

```swift
public func mirrored(about point: SIMD3<Double>) -> CoordinateSystem3D
```

- **Parameters:** `point` — the mirror point.
- **Returns:** New mirrored coordinate system.
- **OCCT:** `OCCTAx3MirrorPoint` → `gp_Ax3::Mirror(gp_Pnt)`.

---

### `CoordinateSystem3D.rotated(about:axisDirection:angle:)`

Rotate about an arbitrary axis.

```swift
public func rotated(
    about axisOrigin: SIMD3<Double>,
    axisDirection: SIMD3<Double>,
    angle: Double
) -> CoordinateSystem3D
```

- **Parameters:** `axisOrigin` — axis origin point; `axisDirection` — axis direction; `angle` — angle in radians.
- **Returns:** New rotated coordinate system.
- **OCCT:** `OCCTAx3Rotate` → `gp_Ax3::Rotate`.

---

### `CoordinateSystem3D.translated(by:)`

Translate by a vector.

```swift
public func translated(by vector: SIMD3<Double>) -> CoordinateSystem3D
```

- **Parameters:** `vector` — translation delta.
- **Returns:** New coordinate system with shifted origin; direction and X direction unchanged.
- **OCCT:** `OCCTAx3Translate` → `gp_Ax3::Translate`.

---

## GeneralTransform2D (gp_GTrsf2d)

A general 2D transformation supporting affine maps (non-uniform scaling, shear, affinity), wrapping `gp_GTrsf2d`.

### `GeneralTransform2D.affinity(axisOrigin:axisDirection:ratio:)`

Create an affinity transformation about a 2D axis.

```swift
public static func affinity(
    axisOrigin: SIMD2<Double>,
    axisDirection: SIMD2<Double>,
    ratio: Double
) -> GeneralTransform2D
```

- **Parameters:** `axisOrigin` — axis pass-through point; `axisDirection` — axis direction; `ratio` — scale factor along the axis.
- **Returns:** A new `GeneralTransform2D`.
- **OCCT:** `OCCTGTrsf2dAffinity` → `gp_GTrsf2d::SetAffinity`.

---

### `GeneralTransform2D.multiplied(by:)`

Compose (multiply) this transform with another.

```swift
public func multiplied(by other: GeneralTransform2D) -> GeneralTransform2D
```

- **Returns:** The composed transform.
- **OCCT:** `OCCTGTrsf2dMultiply` → `gp_GTrsf2d::Multiply`.

---

### `GeneralTransform2D.inverted()`

Compute the inverse of this transform.

```swift
public func inverted() -> GeneralTransform2D?
```

- **Returns:** Inverted transform, or `nil` if the transform is singular (non-invertible).
- **OCCT:** `OCCTGTrsf2dInvert` → `gp_GTrsf2d::Invert`.

---

### `GeneralTransform2D.transformPoint(_:)`

Apply the transform to a 2D point.

```swift
public func transformPoint(_ point: SIMD2<Double>) -> SIMD2<Double>
```

- **Parameters:** `point` — input 2D point.
- **Returns:** Transformed 2D point.
- **OCCT:** `OCCTGTrsf2dTransformPoint` → `gp_GTrsf2d::Transforms`.

---

## Matrix2D (gp_Mat2d)

Static utility enum for 2×2 matrix operations wrapping `gp_Mat2d`. Matrices are represented as `[Double]` with 4 elements in row-major order: `[m11, m12, m21, m22]`.

### `Matrix2D.identity()`

Return the 2×2 identity matrix.

```swift
public static func identity() -> [Double]
```

- **OCCT:** `OCCTMat2dIdentity` → `gp_Mat2d` default identity constructor.
- **Example:**
  ```swift
  let I = Matrix2D.identity() // [1, 0, 0, 1]
  ```

---

### `Matrix2D.rotation(angle:)`

Return a 2×2 rotation matrix for the given angle.

```swift
public static func rotation(angle: Double) -> [Double]
```

- **Parameters:** `angle` — angle in radians.
- **OCCT:** `OCCTMat2dRotation` → `gp_Mat2d` rotation.

---

### `Matrix2D.scale(_:)`

Return a 2×2 uniform scale matrix.

```swift
public static func scale(_ s: Double) -> [Double]
```

- **Parameters:** `s` — scale factor.
- **OCCT:** `OCCTMat2dScale`.

---

### `Matrix2D.determinant(_:)`

Compute the determinant of a 2×2 matrix.

```swift
public static func determinant(_ mat: [Double]) -> Double
```

- **Parameters:** `mat` — 4-element row-major matrix.
- **OCCT:** `OCCTMat2dDeterminant` → `gp_Mat2d::Determinant`.

---

### `Matrix2D.invert(_:)`

Invert a 2×2 matrix.

```swift
public static func invert(_ mat: [Double]) -> [Double]?
```

- **Parameters:** `mat` — 4-element row-major matrix.
- **Returns:** Inverted matrix, or `nil` if singular.
- **OCCT:** `OCCTMat2dInvert` → `gp_Mat2d::Invert`.

---

### `Matrix2D.multiply(_:_:)`

Multiply two 2×2 matrices.

```swift
public static func multiply(_ a: [Double], _ b: [Double]) -> [Double]
```

- **OCCT:** `OCCTMat2dMultiply` → `gp_Mat2d::Multiply`.

---

### `Matrix2D.transpose(_:)`

Transpose a 2×2 matrix.

```swift
public static func transpose(_ mat: [Double]) -> [Double]
```

- **OCCT:** `OCCTMat2dTranspose` → `gp_Mat2d::Transpose`.

---

## Quaternion Interpolation

Extensions on `MathSolver` for quaternion interpolation and transform blending.

### `MathSolver.quaternionSlerp(from:to:t:)`

Spherical linear interpolation (SLERP) between two unit quaternions.

```swift
public static func quaternionSlerp(
    from q1: SIMD4<Double>, to q2: SIMD4<Double>, t: Double
) -> SIMD4<Double>
```

- **Parameters:** `q1` — start quaternion `(x, y, z, w)`; `q2` — end quaternion; `t` — blend parameter in `[0, 1]`.
- **Returns:** Interpolated unit quaternion.
- **OCCT:** `OCCTQuaternionSLerp` → `gp_QuaternionSLerp`.

---

### `MathSolver.quaternionNlerp(from:to:t:)`

Normalized linear interpolation (NLERP) between two quaternions.

```swift
public static func quaternionNlerp(
    from q1: SIMD4<Double>, to q2: SIMD4<Double>, t: Double
) -> SIMD4<Double>
```

- **Parameters:** `q1` — start; `q2` — end; `t` — blend `[0, 1]`.
- **Returns:** Normalized interpolated quaternion. Cheaper than SLERP but less constant-speed.
- **OCCT:** `OCCTQuaternionNLerp` → `gp_QuaternionNLerp`.

---

### `MathSolver.transformInterpolate(from:to:t:)`

Interpolate between two transforms (translation linearly, rotation via NLERP).

```swift
public static func transformInterpolate(
    from: (translation: SIMD3<Double>, quaternion: SIMD4<Double>),
    to: (translation: SIMD3<Double>, quaternion: SIMD4<Double>),
    t: Double
) -> (translation: SIMD3<Double>, quaternion: SIMD4<Double>)
```

- **Parameters:** `from` / `to` — transforms as (translation, quaternion) pairs; `t` — blend `[0, 1]`.
- **Returns:** Interpolated (translation, quaternion) pair.
- **OCCT:** `OCCTTrsfInterpolate`.

---

## XY/XYZ Utilities

### `Vector2DMath` — 2D vector math (gp_XY)

Static enum wrapping `gp_XY` operations.

#### `Vector2DMath.modulus(_:)`

Length of a 2D vector.

```swift
public static func modulus(_ v: SIMD2<Double>) -> Double
```

- **OCCT:** `OCCTXYModulus` → `gp_XY::Modulus`.

---

#### `Vector2DMath.cross(_:_:)`

2D cross product (scalar Z component).

```swift
public static func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double
```

- **OCCT:** `OCCTXYCrossed` → `gp_XY::Crossed`.

---

#### `Vector2DMath.dot(_:_:)`

2D dot product.

```swift
public static func dot(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double
```

- **OCCT:** `OCCTXYDot` → `gp_XY::Dot`.

---

#### `Vector2DMath.normalize(_:)`

Normalize a 2D vector.

```swift
public static func normalize(_ v: SIMD2<Double>) -> SIMD2<Double>?
```

- **Returns:** Normalized vector, or `nil` for zero-length input.
- **OCCT:** `OCCTXYNormalize` → `gp_XY::Normalize`.

---

### `Vector3DMath` — 3D vector math (gp_XYZ)

Static enum wrapping `gp_XYZ` operations.

#### `Vector3DMath.modulus(_:)`

Length of a 3D vector.

```swift
public static func modulus(_ v: SIMD3<Double>) -> Double
```

- **OCCT:** `OCCTXYZModulus` → `gp_XYZ::Modulus`.

---

#### `Vector3DMath.cross(_:_:)`

3D cross product.

```swift
public static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double>
```

- **OCCT:** `OCCTXYZCrossed` → `gp_XYZ::Crossed`.

---

#### `Vector3DMath.dot(_:_:)`

3D dot product.

```swift
public static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double
```

- **OCCT:** `OCCTXYZDot` → `gp_XYZ::Dot`.

---

#### `Vector3DMath.dotCross(_:_:_:)`

Scalar triple product: `a · (b × c)`.

```swift
public static func dotCross(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) -> Double
```

- **OCCT:** `OCCTXYZDotCross` → `gp_XYZ::DotCross`.

---

#### `Vector3DMath.normalize(_:)`

Normalize a 3D vector.

```swift
public static func normalize(_ v: SIMD3<Double>) -> SIMD3<Double>?
```

- **Returns:** Normalized vector, or `nil` for zero-length input.
- **OCCT:** `OCCTXYZNormalize` → `gp_XYZ::Normalize`.

---

## MathSolver Extensions

Numeric solver extensions on `MathSolver`, wrapping `math_BracketedRoot`, `math_FRPR`, `math_FunctionAllRoots`, `math_GaussLeastSquare`, `math_NewtonFunctionRoot`, `math_Uzawa`, `math_EigenVectors`, `math_KronrodSingleIntegration`, `math_GaussMultipleIntegration`, and `math_GaussSetIntegration`.

### `MathSolver.bracketedRoot(in:tolerance:maxIterations:function:)`

Find a root of f(x)=0 in a bracketed range using Brent's method.

```swift
public static func bracketedRoot(
    in range: ClosedRange<Double>,
    tolerance: Double = 1e-10,
    maxIterations: Int = 100,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> (root: Double, iterations: Int)?
```

- **Parameters:** `range` — bracket `[lower, upper]`; `tolerance` — convergence threshold; `function` — closure returning value and derivative at x.
- **Returns:** `(root, iterations)` if converged, `nil` otherwise.
- **OCCT:** `OCCTMathBracketedRoot` → `math_BracketedRoot`.
- **Example:**
  ```swift
  if let result = MathSolver.bracketedRoot(in: 0.0...3.14) { x in
      (value: sin(x), derivative: cos(x))
  } {
      print("root:", result.root) // ≈ π
  }
  ```

---

### `MathSolver.bracketMinimum(a:b:function:)`

Bracket a minimum of f(x) starting from two points.

```swift
public static func bracketMinimum(
    a: Double, b: Double,
    function: @escaping (Double) -> Double
) -> (a: Double, b: Double, c: Double, fa: Double, fb: Double, fc: Double)?
```

- **Parameters:** `a`, `b` — starting interval; `function` — scalar function.
- **Returns:** Three points `(a, b, c)` bracketing a minimum with their function values, or `nil` on failure.
- **OCCT:** `OCCTMathBracketMinimum` → `math_BracketMinimum`.

---

### `MathSolver.minimizeFRPR(startPoint:tolerance:maxIterations:function:)`

Multi-dimensional minimization via Fletcher-Reeves-Polak-Ribière conjugate gradient.

```swift
public static func minimizeFRPR(
    startPoint: [Double],
    tolerance: Double = 1e-8,
    maxIterations: Int = 200,
    function: @escaping ([Double]) -> (value: Double, gradient: [Double])
) -> (location: [Double], minimum: Double, iterations: Int)?
```

- **Parameters:** `startPoint` — initial guess (n-vector); `function` — closure returning scalar value and gradient.
- **Returns:** `(location, minimum, iterations)` at the optimum, or `nil` on failure.
- **OCCT:** `OCCTMathFRPR` → `math_FRPR`.

---

### `MathSolver.findAllRoots(in:samples:epsX:epsF:epsNul:function:)`

Find all roots of f(x)=0 in a range by sampling then refinement.

```swift
public static func findAllRoots(
    in range: ClosedRange<Double>,
    samples: Int = 100,
    epsX: Double = 1e-8,
    epsF: Double = 1e-8,
    epsNul: Double = 1e-8,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> [Double]
```

- **Parameters:** `range` — search interval; `samples` — number of sample points; `function` — value + derivative.
- **Returns:** Array of root locations (may be empty).
- **Bounds:** `samples` is bounded through `Sampling.requested` like the sibling
  `findAllRoots(in:samples:function:)` overload: outside `1...10,000,000` this returns `[]`
  instead of trapping `Int32(samples)` past `Int32.max` (#640).
- **OCCT:** `OCCTMathFunctionAllRoots` → `math_FunctionAllRoots`.

---

### `MathSolver.leastSquares(matrix:rows:cols:rhs:)`

Solve an overdetermined linear system Ax=b in the least-squares sense.

```swift
public static func leastSquares(
    matrix: [Double], rows: Int, cols: Int,
    rhs: [Double]
) -> [Double]?
```

- **Parameters:** `matrix` — row-major matrix of size `rows × cols`; `rhs` — right-hand side vector.
- **Returns:** Solution vector of length `cols`, or `nil` on failure.
- **Bounds:** `rows` and `cols` must both be positive, and `matrix.count == rows * cols` /
  `rhs.count == rows` must hold, or this returns `nil` (#640). Before this bound there was no
  consistency check at all: a positive `rows`/`cols` that did not match `matrix`/`rhs`'s real
  length reached the bridge's unconditional read loop and read out of bounds, rather than
  failing. `rows * cols` is itself checked for overflow, so a huge positive `rows`/`cols` is
  rejected rather than trapping the multiplication (#716's review finding 8).
- **OCCT:** `OCCTMathGaussLeastSquare` → `math_GaussLeastSquare`.

---

### `MathSolver.newtonRoot(guess:epsX:epsF:maxIterations:function:)`

Find a root using Newton's method from an initial guess.

```swift
public static func newtonRoot(
    guess: Double,
    epsX: Double = 1e-10,
    epsF: Double = 1e-10,
    maxIterations: Int = 100,
    function: @escaping (Double) -> (value: Double, derivative: Double)
) -> (root: Double, derivative: Double, iterations: Int)?
```

- **Parameters:** `guess` — starting x; `function` — value and derivative.
- **Returns:** `(root, derivative at root, iterations)` or `nil` if not converged.
- **OCCT:** `OCCTMathNewtonFunctionRoot` → `math_NewtonFunctionRoot`.

---

### `MathSolver.uzawa(constraintMatrix:nConstraints:nVars:constraintRHS:startPoint:epsLix:epsLic:maxIterations:)`

Constrained minimization via Uzawa method: minimize `‖x‖²` subject to `A·x = b`.

```swift
public static func uzawa(
    constraintMatrix: [Double], nConstraints: Int, nVars: Int,
    constraintRHS: [Double],
    startPoint: [Double],
    epsLix: Double = 1e-6, epsLic: Double = 1e-6,
    maxIterations: Int = 500
) -> (result: [Double], iterations: Int)?
```

- **Parameters:** `constraintMatrix` — row-major `nConstraints × nVars` matrix; `constraintRHS` — RHS vector; `startPoint` — initial guess.
- **Returns:** `(solution, iterations)` or `nil` on failure.
- **Bounds:** `nConstraints` and `nVars` must both be positive, and `constraintMatrix`/
  `constraintRHS`/`startPoint` must each match them exactly, or this returns `nil` (#640). None
  of this was checked before, so the bridge's unconditional read loops read out of bounds on any
  mismatch. `nConstraints * nVars` is itself checked for overflow (#716's review finding 8).
- **OCCT:** `OCCTMathUzawa` → `math_Uzawa`.

---

### `MathSolver.eigenvalues(diagonal:subdiagonal:)`

Find eigenvalues of a symmetric tridiagonal matrix.

```swift
public static func eigenvalues(
    diagonal: [Double], subdiagonal: [Double]
) -> [Double]?
```

- **Parameters:** `diagonal` — n diagonal entries; `subdiagonal` — n entries (last unused).
- **Returns:** Array of eigenvalues, or `nil` on failure.
- **Bounds:** `subdiagonal.count` must equal `diagonal.count` exactly, or this returns `nil`
  (#640). This "must be same length" was documentation only until #640: the bridge reads
  `subdiagonal[i]` for `i in 0..<diagonal.count` unconditionally, so a shorter `subdiagonal`
  used to read out of bounds rather than fail.
- **OCCT:** `OCCTMathEigenValues` → `math_EigenVectors`.

---

### `MathSolver.eigenvaluesAndVectors(diagonal:subdiagonal:)`

Find eigenvalues and eigenvectors of a symmetric tridiagonal matrix.

```swift
public static func eigenvaluesAndVectors(
    diagonal: [Double], subdiagonal: [Double]
) -> (eigenvalues: [Double], eigenvectors: [[Double]])?
```

- **Returns:** `(eigenvalues, eigenvectors)` where each eigenvector is a `[Double]` of length n, or `nil` on failure.
- **Bounds:** Same as `eigenvalues(diagonal:subdiagonal:)`: `subdiagonal.count` must equal
  `diagonal.count` exactly (#640).
- **OCCT:** `OCCTMathEigenValuesAndVectors` → `math_EigenVectors`.

---

### `MathSolver.kronrodIntegrate(over:points:function:)`

Gauss-Kronrod integration of f(x) over an interval.

```swift
public static func kronrodIntegrate(
    over range: ClosedRange<Double>,
    points: Int = 15,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double)?
```

- **Parameters:** `range` — integration interval; `points` — number of Kronrod points; `function` — integrand.
- **Returns:** `(value, error estimate)` or `nil` on failure.
- **OCCT:** `OCCTMathKronrodIntegration` → `math_KronrodSingleIntegration`.

---

### `MathSolver.kronrodIntegrateAdaptive(over:points:tolerance:maxIterations:function:)`

Adaptive Gauss-Kronrod integration with an error tolerance.

```swift
public static func kronrodIntegrateAdaptive(
    over range: ClosedRange<Double>,
    points: Int = 15,
    tolerance: Double = 1e-10,
    maxIterations: Int = 100,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double, iterations: Int)?
```

- **Returns:** `(value, error, iterations)` or `nil` on failure.
- **OCCT:** `OCCTMathKronrodIntegrationAdaptive`.

---

### `MathSolver.gaussMultipleIntegration(lower:upper:order:function:)`

Multi-dimensional Gauss-Legendre integration. Genuinely supports any number of variables:
`math_GaussMultipleIntegration` integrates recursively over every dimension.

```swift
public static func gaussMultipleIntegration(
    lower: [Double], upper: [Double], order: [Int],
    function: @escaping ([Double]) -> Double
) -> Double?
```

- **Parameters:** `lower`/`upper` — integration bounds per dimension; `order` — Gauss point counts per dimension; `function` — n-variate integrand.
- **Returns:** Integral value or `nil` on failure.
- **Bounds:** `upper` and `order` must have the same length as `lower`, or this returns `nil`
  (#640). The bridge derives the dimension count from `lower.count` alone and then reads
  `upper[i]`/`order[i]` up to it unconditionally, so a shorter `upper` or `order` used to read
  out of bounds.
- **OCCT:** `OCCTMathGaussMultipleIntegration` → `math_GaussMultipleIntegration`.
- **Example:**
  ```swift
  let integral = MathSolver.gaussMultipleIntegration(
      lower: [0, 0], upper: [1, 1], order: [10, 10]
  ) { x in x[0] * x[0] + x[1] * x[1] }   // 2/3
  ```

---

### `MathSolver.gaussSetIntegration(nEquations:lower:upper:order:function:)`

Gauss-Legendre integration for a **set of functions of one variable**, each integrated
separately. Unlike `gaussMultipleIntegration`, this does **not** support more than one
integration variable: `lower` must have exactly one element.

```swift
public static func gaussSetIntegration(
    nEquations: Int,
    lower: [Double], upper: [Double], order: [Int],
    function: @escaping ([Double]) -> [Double]
) -> [Double]?
```

- **Parameters:** `nEquations` — number of integrals; `function` — closure mapping input vector to `nEquations`-length output.
- **Returns:** Array of integral values (length `nEquations`), or `nil` on failure.
- **Bounds:** `nEquations` must be positive, and `upper`/`order` must have the same length as
  `lower`, or this returns `nil` (#640): the first was an `Array(repeating:count:)` trap on a
  negative `nEquations`, and the second is the same unguarded read as
  `gaussMultipleIntegration`. `function`'s own returned array is checked the same way as
  `solveSystem`'s (#716's review finding 6): a closure returning fewer than `nEquations`
  elements now fails the call (`nil`) instead of trapping.
- **`lower` must also have exactly one element (#716's review finding 2).**
  `math_GaussSetIntegration`'s own header documents "the case M>1 is not implemented": its
  constructor only ever varies the *first* integration variable, leaving every other component
  of its working vector unset. OCCT's own runtime check for this does not survive this
  project's `No_Exception` production kernel build, so a call with more than one variable used
  to silently succeed at the wrong answer instead of failing: measured directly,
  `gaussSetIntegration(nEquations: 1, lower: [0, 0], upper: [1, 1], order: [10, 10])`
  integrating `x + y` returned `0.5` (`∫x dx` over `[0, 1]` with `y` silently pinned at `0`), not
  the `1.0` a genuine double integral of `x + y` over the unit square would be. This now returns
  `nil` for `lower.count != 1` instead. For genuinely multi-variable integration, use
  `gaussMultipleIntegration`.
- **OCCT:** `OCCTMathGaussSetIntegration` → `math_GaussSetIntegration`.
- **Example:**
  ```swift
  // A "set" of two functions of the SAME one variable: integral of x and of x^2 over [0, 2].
  let integrals = MathSolver.gaussSetIntegration(
      nEquations: 2, lower: [0], upper: [2], order: [10]
  ) { x in [x[0], x[0] * x[0]] }   // [2.0, 8.0/3.0]
  ```

---

## PolynomialSolver rc4 Extensions

Extensions on `PolynomialSolver` wrapping the `math_Polynomial` rc4 solvers.

### `PolynomialSolver.linearRc4(a:b:)`

Solve `ax + b = 0`.

```swift
public static func linearRc4(a: Double, b: Double) -> [Double]?
```

- **Returns:** Array of roots (0 or 1 elements), or `nil` if degenerate.
- **OCCT:** `OCCTMathPolyLinear` → `math_Polynomial` rc4 linear.

---

### `PolynomialSolver.quadraticRc4(a:b:c:)`

Solve `ax² + bx + c = 0`.

```swift
public static func quadraticRc4(a: Double, b: Double, c: Double) -> [Double]?
```

- **Returns:** Up to 2 real roots, or `nil` if degenerate.
- **OCCT:** `OCCTMathPolyQuadratic` → `math_Polynomial` rc4 quadratic.

---

### `PolynomialSolver.cubicRc4(a:b:c:d:)`

Solve `ax³ + bx² + cx + d = 0`.

```swift
public static func cubicRc4(a: Double, b: Double, c: Double, d: Double) -> [Double]?
```

- **Returns:** Up to 3 real roots, or `nil` if degenerate.
- **OCCT:** `OCCTMathPolyCubic` → `math_Polynomial` rc4 cubic.

---

### `PolynomialSolver.quarticRc4(a:b:c:d:e:)`

Solve `ax⁴ + bx³ + cx² + dx + e = 0`.

```swift
public static func quarticRc4(a: Double, b: Double, c: Double, d: Double, e: Double) -> [Double]?
```

- **Returns:** Up to 4 real roots, or `nil` if degenerate.
- **OCCT:** `OCCTMathPolyQuartic` → `math_Polynomial` rc4 quartic.

---

## MathInteg rc4 Extensions

Extensions on `MathSolver` providing additional quadrature rules via rc4 `math_Integ` templates.

### `MathSolver.integGauss(over:points:function:)`

Gauss-Legendre quadrature.

```swift
public static func integGauss(
    over range: ClosedRange<Double>,
    points: Int = 15,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double)?
```

- **OCCT:** `OCCTMathIntegGauss` → rc4 `math_IntegGauss`.

---

### `MathSolver.integGaussAdaptive(over:tolerance:maxIterations:function:)`

Adaptive Gauss-Legendre quadrature.

```swift
public static func integGaussAdaptive(
    over range: ClosedRange<Double>,
    tolerance: Double = 1e-10,
    maxIterations: Int = 100,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double, iterations: Int)?
```

- **OCCT:** `OCCTMathIntegGaussAdaptive`.

---

### `MathSolver.integKronrod(over:gaussPoints:function:)`

Gauss-Kronrod rule via rc4 MathInteg templates.

```swift
public static func integKronrod(
    over range: ClosedRange<Double>,
    gaussPoints: Int = 7,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double)?
```

- **OCCT:** `OCCTMathIntegKronrod`.

---

### `MathSolver.integKronrodAdaptive(over:gaussPoints:tolerance:maxIterations:function:)`

Adaptive Gauss-Kronrod rule via rc4 MathInteg templates.

```swift
public static func integKronrodAdaptive(
    over range: ClosedRange<Double>,
    gaussPoints: Int = 7,
    tolerance: Double = 1e-10,
    maxIterations: Int = 100,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double, iterations: Int)?
```

- **OCCT:** `OCCTMathIntegKronrodAdaptive`.

---

### `MathSolver.integTanhSinh(over:tolerance:maxLevels:function:)`

Tanh-Sinh (double exponential) quadrature — excels at endpoint singularities.

```swift
public static func integTanhSinh(
    over range: ClosedRange<Double>,
    tolerance: Double = 1e-10,
    maxLevels: Int = 6,
    function: @escaping (Double) -> Double
) -> (value: Double, error: Double, iterations: Int)?
```

- **Returns:** `(value, error, iterations)` or `nil` on failure.
- **OCCT:** `OCCTMathIntegTanhSinh`.

---

## UnitsConversion

### `OCCTLengthUnit`

Length unit enum matching `UnitsMethods_LengthUnit`.

```swift
public enum OCCTLengthUnit: Int32, Sendable {
    case undefined, inch, millimeter, foot, mile, meter, kilometer, mil, micron, centimeter, microinch
}
```

Case meanings, from `UnitsMethods_LengthUnit`:

#### `OCCTLengthUnit.inch`

The inch (25.4 mm).

#### `OCCTLengthUnit.millimeter`

The millimetre.

#### `OCCTLengthUnit.foot`

The foot (12 inches, 304.8 mm).

#### `OCCTLengthUnit.mile`

The (statute) mile (5280 feet).

#### `OCCTLengthUnit.meter`

The metre.

#### `OCCTLengthUnit.kilometer`

The kilometre.

#### `OCCTLengthUnit.mil`

The thousandth of an inch (0.0254 mm), also called "thou".

#### `OCCTLengthUnit.micron`

The micrometre (1e-6 metre).

#### `OCCTLengthUnit.centimeter`

The centimetre.

#### `OCCTLengthUnit.microinch`

The millionth of an inch (1e-6 inch).

---

### `UnitsConversion.lengthFactor(igesUnit:)`

Get the length factor (in millimetres) for an IGES unit code.

```swift
public static func lengthFactor(igesUnit: Int) -> Double
```

- **Parameters:** `igesUnit` — IGES standard unit code.
- **OCCT:** `OCCTUnitsGetLengthFactor` → `UnitsMethods::GetLengthFactor`.

---

### `UnitsConversion.lengthUnitScale(from:to:)`

Scale factor to convert between two length units.

```swift
public static func lengthUnitScale(from: OCCTLengthUnit, to: OCCTLengthUnit) -> Double
```

- **Parameters:** `from` — source unit; `to` — target unit.
- **Returns:** Multiplicative scale factor.
- **OCCT:** `OCCTUnitsGetLengthUnitScale` → `UnitsMethods`.

---

### `UnitsConversion.dumpLengthUnit(_:)`

Get the string name of a length unit.

```swift
public static func dumpLengthUnit(_ unit: OCCTLengthUnit) -> String?
```

- **Returns:** Human-readable name, or `nil` if unknown.
- **OCCT:** `OCCTUnitsDumpLengthUnit` → `UnitsMethods`.

---

## Curve3D LProp3d Extensions

Extensions on `Curve3D` wrapping `LProp3d_CLProps` for local differential properties.

These are alternative spellings of `Curve3D.tangentDirection(at:)`, `normal(at:)` and
`centerOfCurvature(at:)` — same OCCT computation, same tolerance, differing only in shape. They are
guaranteed to agree with their counterparts for the same curve at the same parameter; before #494
they asked at a hardcoded `1e-10` resolution against the canonical family's `Precision::Confusion()`
(`1e-7`), and the two disagreed near a degeneracy.

There were originally four. `localCurvature(at:)` was deprecated as of #595 in favour of
`curvature(at:)` (once #494 gave the two the same resolution they were the same call line for
line, and measured over the same curves, degenerate rows included, they never disagreed on any row)
and removed at v2.0.0 (#784). The bridge function behind it, `OCCTCurve3DLocalCurvature`, was
already deleted at #595.

### `Curve3D.localTangent(at:)`

Tangent direction at a parameter value.

```swift
public func localTangent(at u: Double) -> SIMD3<Double>?
```

- **Returns:** Unit tangent vector, or `nil` where every derivative up to order 3 is null.
- **Equivalent to:** `Curve3D.tangentDirection(at:)`.
- **OCCT:** `OCCTCurve3DLocalTangent` → `LProp3d_CLProps::Tangent`.

---

### `Curve3D.localNormal(at:)`

Principal normal direction at a parameter value.

```swift
public func localNormal(at u: Double) -> SIMD3<Double>?
```

- **Returns:** Normal vector, or `nil` where the curvature is zero (straight or inflecting) or
  infinite (a cusp).
- **Equivalent to:** `Curve3D.normal(at:)`.
- **OCCT:** `OCCTCurve3DLocalNormal` → `LProp3d_CLProps::Normal`.

---

### `Curve3D.localCentreOfCurvature(at:)`

Centre of curvature at a parameter value.

```swift
public func localCentreOfCurvature(at u: Double) -> SIMD3<Double>?
```

- **Returns:** Centre of the osculating circle, or `nil` where the curvature cannot be inverted
  into a radius: zero (straight or inflecting) or infinite (a cusp). Both used to return a point
  built from `NaN` and infinity instead of `nil` (#494).
- **Equivalent to:** `Curve3D.centerOfCurvature(at:)`.
- **OCCT:** `OCCTCurve3DLocalCentreOfCurvature` → `LProp3d_CLProps::CentreOfCurvature`.

---

## Surface LProp3d Extensions

Extensions on `Surface` wrapping `LProp3d_SLProps` for local surface differential properties.

Both report quantities `Surface.curvatures(u:v:)`, `gaussianCurvature(atU:v:)`,
`meanCurvature(atU:v:)` and `principalCurvatures(atU:v:)` also report, at the same tolerance since
#494 and with the same optionality since #595 — they previously asked at a hardcoded `1e-10` against those entry points'
`Precision::Confusion()`, so they could report curvature at a point the rest called undefined. The
one remaining asymmetry is by design: `localCurvatureDirections` also returns `nil` at umbilic
points, where curvature is perfectly well defined but no principal direction is distinguished.

### `Surface.LocalCurvatures`

Result struct for surface curvature at a (u, v) point.

```swift
public struct LocalCurvatures: Sendable {
    public let gaussian: Double
    public let mean: Double
    public let maxCurvature: Double
    public let minCurvature: Double
}
```

| Field | Meaning |
|---|---|
| `gaussian` | Gaussian curvature (product of the two principal curvatures) at the point. |
| `mean` | Mean curvature (average of the two principal curvatures) at the point. |
| `maxCurvature` | The larger of the two principal curvatures at the point. |
| `minCurvature` | The smaller of the two principal curvatures at the point. |

#### `Surface.LocalCurvatures.minCurvature`

---

### `Surface.localCurvatures(u:v:)`

All principal curvatures at a surface point.

```swift
public func localCurvatures(u: Double, v: Double) -> LocalCurvatures?
```

- **Parameters:** `u`, `v` — surface parameters.
- **Returns:** Gaussian, mean, max and min curvatures, or `nil` where curvature is undefined — a
  cone's apex, a sphere's pole, or any point with no defined surface normal.
- **Agrees with:** `Surface.curvatures(u:v:)`, `gaussianCurvature(atU:v:)`,
  `meanCurvature(atU:v:)`, `principalCurvatures(atU:v:)`.
- **OCCT:** `OCCTSurfaceLocalCurvatures` → `LProp3d_SLProps`.

---

### `Surface.CurvatureDirections`

Result struct for principal curvature directions.

```swift
public struct CurvatureDirections: Sendable {
    public let maxDirection: SIMD3<Double>
    public let minDirection: SIMD3<Double>
}
```

---

#### `Surface.CurvatureDirections.maxDirection`

Unit tangent direction of maximum principal curvature at the surface point.

#### `Surface.CurvatureDirections.minDirection`

Unit tangent direction of minimum principal curvature at the surface point; perpendicular to `maxDirection`.

---

### `Surface.localCurvatureDirections(u:v:)`

Principal curvature directions at a surface point.

```swift
public func localCurvatureDirections(u: Double, v: Double) -> CurvatureDirections?
```

- **Returns:** Max and min curvature directions, or `nil` where curvature is undefined **or** the
  point is umbilic. OCCT's umbilic test is one ULP wide (`|maxCurv - minCurv| < Epsilon(maxCurv)`),
  not a geometric tolerance: a plane always qualifies, but an analytically-umbilic sphere qualifies
  only where the two computed curvatures round to the same `Double` — so a non-`nil` result on a
  sphere is expected, not a defect.
- **Agrees with:** `Surface.principalCurvatures(atU:v:)`, which returns the same two directions
  alongside their curvatures (and does not reject umbilic points).
- **OCCT:** `OCCTSurfaceLocalCurvatureDirections` → `LProp3d_SLProps`.

---

## ProjLib

Static utilities for projecting 3D geometry onto analytic surface parameter spaces, wrapping `ProjLib`.

### `ProjLib.Line2DResult`

2D line in a surface's parameter space.

```swift
public struct Line2DResult: Sendable {
    public let locationX: Double
    public let locationY: Double
    public let directionX: Double
    public let directionY: Double
}
```

| field | meaning |
|---|---|
| `locationX` | X coordinate of the projected line's location point, in the target surface's parameter space. |
| `locationY` | Y coordinate of the projected line's location point. |
| `directionX` | X component of the projected line's (unit) direction, in parameter space. |
| `directionY` | Y component of the projected line's (unit) direction. |

*(Per-field anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `directionY`

---

### `ProjLib.Circle2DResult`

2D circle in a surface's parameter space.

```swift
public struct Circle2DResult: Sendable {
    public let centerX: Double
    public let centerY: Double
    public let radius: Double
}
```

| Field | Meaning |
|---|---|
| `centerX` | U coordinate of the projected circle's center in the target surface's parameter space. |
| `centerY` | V coordinate of the projected circle's center in the target surface's parameter space. |

#### `ProjLib.Circle2DResult.centerY`

---

### `ProjLib.projectLineOnPlane(planePoint:planeNormal:linePoint:lineDirection:)`

Project a 3D line onto a plane, returning the 2D line in the plane's parameter space.

```swift
public static func projectLineOnPlane(
    planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
    linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>
) -> Line2DResult?
```

- **Returns:** 2D line result, or `nil` if projection is degenerate.
- **OCCT:** `OCCTProjLibPlaneProjectLine` → `ProjLib::Project`.

---

### `ProjLib.projectLineOnCylinder(cylinderPoint:cylinderAxis:cylinderRadius:linePoint:lineDirection:)`

Project a 3D line onto a cylinder's parameter space.

```swift
public static func projectLineOnCylinder(
    cylinderPoint: SIMD3<Double>, cylinderAxis: SIMD3<Double>, cylinderRadius: Double,
    linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>
) -> Line2DResult?
```

- **OCCT:** `OCCTProjLibCylinderProjectLine` → `ProjLib::Project`.

---

### `ProjLib.projectCircleOnPlane(planePoint:planeNormal:circleCenter:circleNormal:circleRadius:)`

Project a 3D circle onto a plane.

```swift
public static func projectCircleOnPlane(
    planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
    circleCenter: SIMD3<Double>, circleNormal: SIMD3<Double>, circleRadius: Double
) -> Circle2DResult?
```

- **Returns:** 2D circle in the plane's parameter space, or `nil` if degenerate.
- **OCCT:** `OCCTProjLibPlaneProjectCircle` → `ProjLib::Project`.

---

## BRepBndLib Extensions

Extensions on `Shape` for bounding-box computations.

### `Shape.boundingBox`

Axis-aligned bounding box of the shape.

```swift
public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)?
```

- **Returns:** `(min, max)` corner pair, or `nil` if the shape is empty.
- **OCCT:** `OCCTShapeBoundingBox` → `BRepBndLib::Add` / `Bnd_Box`.

---

### `Shape.boundingBoxOptimal(useShapeTolerance:)`

Optimal (tight) axis-aligned bounding box using precise geometry evaluation.

```swift
public func boundingBoxOptimal(useShapeTolerance: Bool = false) -> (min: SIMD3<Double>, max: SIMD3<Double>)?
```

- **Parameters:** `useShapeTolerance` — include shape tolerances in box inflation.
- **Returns:** `(min, max)` or `nil` for empty shapes.
- **OCCT:** `OCCTShapeBoundingBoxOptimal` → `BRepBndLib::AddOptimal`.

---

### `Shape.DetailedOBB`

Oriented bounding box with full axis and half-size information.

```swift
public struct DetailedOBB: Sendable {
    public let center: SIMD3<Double>
    public let xDirection: SIMD3<Double>
    public let yDirection: SIMD3<Double>
    public let zDirection: SIMD3<Double>
    public let xHalfSize: Double
    public let yHalfSize: Double
    public let zHalfSize: Double
}
```

| Field | Meaning |
|---|---|
| `zDirection` | Unit vector for the box's local Z axis. |
| `xHalfSize` | Half-extent of the box along `xDirection`. |
| `yHalfSize` | Half-extent of the box along `yDirection`. |
| `zHalfSize` | Half-extent of the box along `zDirection`. |

#### `Shape.DetailedOBB.zHalfSize`

---

### `Shape.orientedBoundingBoxDetailed(optimal:)`

Compute the oriented bounding box with full axis information.

```swift
public func orientedBoundingBoxDetailed(optimal: Bool = false) -> DetailedOBB?
```

- **Parameters:** `optimal` — use precise geometry when `true`.
- **Returns:** `DetailedOBB` or `nil` if the shape is void.
- **OCCT:** `OCCTShapeOrientedBoundingBoxDetailed` → `BRepBndLib::AddOBB`.

---

### `Shape.OrientedBoundingBox`

An oriented (rotated) bounding box that fits tightly around a shape. Unlike the flat
`DetailedOBB`, this value bundles the half-sizes as a single `SIMD3<Double>` and adds two
computed conveniences (`volume`, `dimensions`); it is the return type of
`orientedBoundingBox(optimal:)`.

```swift
public struct OrientedBoundingBox: Sendable {
    public var center: SIMD3<Double>        // box centre in world space
    public var xDirection: SIMD3<Double>    // unit axis directions of the box frame
    public var yDirection: SIMD3<Double>
    public var zDirection: SIMD3<Double>
    public var halfSizes: SIMD3<Double>     // half-extents along x/y/z axes
    public var volume: Double { get }       // 8 · hx · hy · hz
    public var dimensions: SIMD3<Double> { get }  // 2 · halfSizes (full edge lengths)
}
```

- **OCCT:** populated from `Bnd_OBB` (via `BRepBndLib::AddOBB`).

---

#### `zDirection`

Unit Z-axis direction of the box frame, alongside `xDirection`/`yDirection`; see the field comments
in the struct above.

---

### `Shape.orientedBoundingBox(optimal:)`

Compute the oriented (tight-fit, rotated) bounding box of the shape as an
`OrientedBoundingBox` value. Where the axis-aligned `boundingBox` is cheap but loose for
rotated geometry, the OBB rotates to hug the shape, so its `volume` is a far better proxy for
how much space the part actually occupies.

```swift
public func orientedBoundingBox(optimal: Bool = false) -> OrientedBoundingBox?
```

- **Parameters:** `optimal` — when `true`, compute a tighter box from precise geometry (slower);
  when `false` (default), use the triangulation/vertex-based fit.
- **Returns:** The `OrientedBoundingBox`, or `nil` if the shape is void.
- **OCCT:** `BRepBndLib::AddOBB` → `Bnd_OBB` (via `OCCTShapeOrientedBoundingBox`).
- **Example:**
  ```swift
  if let obb = shape.orientedBoundingBox() {
      print(obb.dimensions)  // full edge lengths of the tight box
      print(obb.volume)      // occupied volume, rotation-independent
  }
  ```

---

### `Shape.orientedBoundingBoxCorners(optimal:)`

Return the 8 corner points of the shape's oriented bounding box, ready for drawing a wireframe
box or feeding a collision/packing check.

```swift
public func orientedBoundingBoxCorners(optimal: Bool = false) -> [SIMD3<Double>]?
```

- **Parameters:** `optimal` — same tight-vs-fast trade-off as `orientedBoundingBox(optimal:)`.
- **Returns:** An array of exactly 8 corner points in world space, or `nil` if the shape is void.
- **OCCT:** `Bnd_OBB::GetVertex` over the box built by `BRepBndLib::AddOBB` (via
  `OCCTOrientedBoundingBoxCorners`).

---

## ShapeAnalysis_ShapeTolerance Extensions

Extensions on `Shape` for querying sub-shape tolerances.

### `Shape.ToleranceMode`

Tolerance aggregation mode.

```swift
public enum ToleranceMode: Int32, Sendable {
    case average = 0
    case maximum = 1
    case minimum = -1
}
```

| case | meaning |
|---|---|
| `.average` | Average tolerance over the queried sub-shapes. |
| `.maximum` | Largest tolerance among the queried sub-shapes. |
| `.minimum` | Smallest tolerance among the queried sub-shapes. |

*(Per-case anchors below, for cross-reference; the table above has the actual meaning of each.)*

#### `minimum`

---

### `Shape.toleranceValue(mode:subShapeType:)`

Tolerance value for the shape's sub-shapes.

```swift
public func toleranceValue(mode: ToleranceMode, subShapeType: Int32 = 8) -> Double
```

- **Parameters:** `mode` — aggregation mode; `subShapeType` — `8`=all, `7`=vertex, `6`=edge, `4`=face, `3`=shell.
- **OCCT:** `OCCTShapeToleranceValue` → `ShapeAnalysis_ShapeTolerance`.

---

### `Shape.toleranceOverCount(value:subShapeType:)`

Count of sub-shapes whose tolerance exceeds `value`.

```swift
public func toleranceOverCount(value: Double, subShapeType: Int32 = 8) -> Int
```

- **OCCT:** `OCCTShapeToleranceOverCount` → `ShapeAnalysis_ShapeTolerance::OverTolerance`.

---

### `Shape.toleranceInRangeCount(min:max:subShapeType:)`

Count of sub-shapes whose tolerance falls within `[min, max]`.

```swift
public func toleranceInRangeCount(min: Double, max: Double, subShapeType: Int32 = 8) -> Int
```

- **OCCT:** `OCCTShapeToleranceInRangeCount` → `ShapeAnalysis_ShapeTolerance::InTolerance`.

---

## BRepAlgoAPI_Check Extensions

Extensions on `Shape` for pre-checking validity before boolean operations.

### `Shape.isBooleanValid(testSmallEdges:testSelfInterference:)`

Check if this shape is individually valid for boolean operations.

```swift
public func isBooleanValid(testSmallEdges: Bool = true, testSelfInterference: Bool = true) -> Bool
```

- **Returns:** `true` if the shape passes all enabled checks.
- **OCCT:** `OCCTShapeBooleanCheckSingle` → `BRepAlgoAPI_Check`.
- **Example:**
  ```swift
  if let box = Shape.box(width: 10, height: 10, depth: 10) {
      let valid = box.isBooleanValid()
  }
  ```

---

### `Shape.isBooleanValidWith(_:operation:testSmallEdges:testSelfInterference:)`

Check if two shapes are valid for a specific boolean operation together.

```swift
public func isBooleanValidWith(
    _ other: Shape,
    operation: Int32 = 0,
    testSmallEdges: Bool = true,
    testSelfInterference: Bool = true
) -> Bool
```

- **Parameters:** `other` — second operand; `operation` — `0`=unknown, `1`=common, `2`=fuse, `3`=cut, `4`=section.
- **OCCT:** `OCCTShapeBooleanCheckPair` → `BRepAlgoAPI_Check`.

---

## BRepAlgoAPI_Defeaturing Extensions

### `Shape.defeature(faces:)`

Remove feature faces (fillets, holes, pockets) from a solid shape. The canonical defeaturing call.

```swift
public func defeature(faces: [Shape]) -> Shape?
```

- **Parameters:** `faces` — each element either a face of this shape, or a shape whose faces all
  belong to this shape.
- **Returns:** Defeatured shape, or `nil` on failure — including when `faces` is empty and when the
  request names a face this shape does not have.
- **OCCT:** `OCCTShapeDefeature` → `BRepAlgoAPI_Defeaturing`.
- **Example:**
  ```swift
  if let defeatured = solid.defeature(faces: filletFaces) {
      // fillets removed
  }
  ```

**What may be named, and what must belong.** Each element names faces rather than having to be one: a
compound of faces, a shell, or this whole shape all name the faces they contain, and naming a carrier
is the same request as naming the faces it holds. The rule every element must satisfy:

> Every element must name at least one face, and every face it names must be a face of this shape.
> Otherwise the whole call returns `nil` and nothing is removed.

So a request mixing this shape's faces with another shape's fails, as does one carrying an edge or a
vertex, which name no face at all. Membership is by identity, not geometry: the same face measured off
an identically-built shape is foreign, while the same face reversed is not.

Until #578 a foreign face was dropped from the request and the rest proceeded — OCCT's own documented
rule ("those that do not belong will be ignored"), which answered a silent success on a shape still
carrying the feature the caller asked to remove. The index-addressed `withoutFeatures(faces:)` has
failed the whole call on one bad index since #497; both spellings now agree. Measured in
[`Scripts/repro/578-defeature-face-membership/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/578-defeature-face-membership).

**The rest of the family.** Five Swift spellings reach the same `BRepAlgoAPI_Defeaturing`
operation, over one shared bridge path (#497, #536):

| Call | Addresses faces as | Notes |
|------|--------------------|-------|
| `defeature(faces:)` | `[Shape]` | this one |
| [`withoutFeatures(faces:)`](Shape-Features.md#withoutfeaturesfaces) | `[Face]` (by index) | same operation |
| `defeaturedWithFullHistory(faces:)` | `[Int]` (indices) | also returns the removal history |
| [`withoutSmallFaces(minArea:)`](Shape-Features.md) | picks its own | every face below an area threshold |
| [`removeFeatures(faces:)`](Shape-Builders-2.md#removefeaturesfaces--deprecated-536) | `[Shape]` | deprecated: this call, reached one OCCT layer down |

`defeature(faces:tolerance:)` is deprecated and forwards here: `BRepAlgoAPI_Defeaturing` has no
fuzzy tolerance to set, and never had — see
[`Scripts/repro/497-defeaturing-fuzzy-inert/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/497-defeaturing-fuzzy-inert).
`removeFeatures(faces:)` is deprecated too, and forwards here as well: it drove
`BOPAlgo_RemoveFeatures` directly, which is the algorithm `BRepAlgoAPI_Defeaturing::Build` forwards
to (#536).

---

## Convert_CompPolynomialToPoles

### `PolynomialConvert.PolesResult`

Result of a polynomial-to-BSpline conversion.

```swift
public struct PolesResult: Sendable {
    public let poles: [Double]   // dimension * poleCount values
    public let knots: [Double]
    public let degree: Int
}
```

---

### `PolynomialConvert.polynomialToPoles(dimension:maxDegree:degree:coefficients:polynomialInterval:trueInterval:)`

Convert polynomial coefficients to BSpline poles and knots.

```swift
public static func polynomialToPoles(
    dimension: Int, maxDegree: Int, degree: Int,
    coefficients: [Double],
    polynomialInterval: ClosedRange<Double>,
    trueInterval: ClosedRange<Double>
) -> PolesResult?
```

- **Parameters:** `dimension` — spatial dimension (1 for scalar, 3 for 3D); `maxDegree` — max BSpline degree; `degree` — polynomial degree; `coefficients` — polynomial coefficients in ascending order; `polynomialInterval` — source domain; `trueInterval` — target BSpline parameter domain.
- **Returns:** `PolesResult` or `nil` on failure.
- **OCCT:** `OCCTConvertPolynomialToPoles` → `Convert_CompPolynomialToPoles`.

---

## gp_Trsf Extras

### `Shape.transformed(byMatrix:)`

Apply a full 3×4 affine matrix to the shape.

```swift
public func transformed(byMatrix matrix: [Double]) -> Shape?
```

- **Parameters:** `matrix` — 12-element row-major array `[a11..a14, a21..a24, a31..a34]`.
- **Returns:** Transformed shape, or `nil` if `matrix.count != 12` or the operation fails.
- **OCCT:** `OCCTShapeTransformFromMatrix` → `gp_Trsf` matrix form.

---

### `Shape.isTransformNegative`

Whether the shape's location transform has a negative determinant (encodes a mirror/reflection).

```swift
public var isTransformNegative: Bool
```

- **OCCT:** `OCCTShapeTransformIsNegative` → `gp_Trsf::IsNegative`.

---

### `TransformUtils`

Utility enum for building transform matrices between coordinate systems.

#### `TransformUtils.Matrix3x4`

A 3×4 row-major transform matrix (12 `Double` elements).

```swift
public struct Matrix3x4: Sendable {
    public let values: [Double] // [a11,a12,a13,a14, a21,a22,a23,a24, a31,a32,a33,a34]
}
```

| Field | Meaning |
|---|---|
| `values` | The 12 matrix elements, row-major: rotation/scale in the first 3 columns of each row, translation in the 4th. |

#### `TransformUtils.Matrix3x4.values`

---

#### `TransformUtils.displacement(from:to:)`

Displacement transform mapping one coordinate system to another.

```swift
public static func displacement(
    from: (point: SIMD3<Double>, direction: SIMD3<Double>),
    to: (point: SIMD3<Double>, direction: SIMD3<Double>)
) -> Matrix3x4
```

- **OCCT:** `OCCTTrsfDisplacement` → `gp_Trsf::SetDisplacement`.

---

#### `TransformUtils.transformation(from:to:)`

Coordinate transformation between two axis systems.

```swift
public static func transformation(
    from: (point: SIMD3<Double>, direction: SIMD3<Double>),
    to: (point: SIMD3<Double>, direction: SIMD3<Double>)
) -> Matrix3x4
```

- **OCCT:** `OCCTTrsfTransformation` → `gp_Trsf::SetTransformation`.

---

## TopExp Extras

### `Shape.commonVertex(edge1:edge2:)`

Find the common vertex between two edges.

```swift
public static func commonVertex(edge1: Shape, edge2: Shape) -> SIMD3<Double>?
```

- **Returns:** Position of the shared vertex, or `nil` if the edges do not share a vertex.
- **OCCT:** `OCCTEdgesCommonVertex` → `TopExp::CommonVertex`.

---

## BRep_Tool Extras

Extensions on `Shape` exposing `BRep_Tool` flags for edges and faces.

### `Shape.edgeSameParameter`

Whether the edge has the SameParameter flag (3D curve matches all p-curves parametrically).

```swift
public var edgeSameParameter: Bool
```

- **OCCT:** `OCCTEdgeSameParameter` → `BRep_Tool::SameParameter`.

---

### `Shape.edgeSameRange`

Whether the edge has the SameRange flag (all curve representations share the same parameter range).

```swift
public var edgeSameRange: Bool
```

- **OCCT:** `OCCTEdgeSameRange` → `BRep_Tool::SameRange`.

---

### `Shape.faceNaturalRestriction`

Whether the face has the NaturalRestriction flag (bounded by its own parametric bounds).

```swift
public var faceNaturalRestriction: Bool
```

- **OCCT:** `OCCTFaceNaturalRestriction` → `BRep_Tool::NaturalRestriction`.

---

### `Shape.edgeIsGeometric`

Whether the edge has a geometric representation (3D curve or curve on surface).

```swift
public var edgeIsGeometric: Bool
```

- **OCCT:** `OCCTEdgeIsGeometric` → `BRep_Tool::IsGeometric`.

---

### `Shape.faceIsGeometric`

Whether the face has a geometric representation (underlying surface).

```swift
public var faceIsGeometric: Bool
```

- **OCCT:** `OCCTFaceIsGeometric` → `BRep_Tool::IsGeometric`.

---

## Sewing Extras

Extensions on `SewingBuilder`.

### `SewingBuilder.multipleEdgeCount`

Number of multiple edges (edges shared by more than two faces).

```swift
public var multipleEdgeCount: Int
```

- **OCCT:** `OCCTSewingNbMultipleEdges` → `BRepBuilderAPI_Sewing::NbMultipleEdges`.

---

### `SewingBuilder.multipleEdge(at:)`

Get a multiple edge by index (1-based).

```swift
public func multipleEdge(at index: Int) -> Shape?
```

- **Parameters:** `index` — 1-based edge index.
- **Returns:** Edge shape, or `nil` if index is out of range.
- **OCCT:** `OCCTSewingIsMultipleEdge` → `BRepBuilderAPI_Sewing::MultipleEdge`.

---

## BREP Serialization / gp Distance & Contains / BezierSurface / Curve2D Extras / BSplineSurface Extras

### `Shape.toBREPString()`

Serialize the shape to a BREP-format string.

```swift
public func toBREPString() -> String?
```

- **Returns:** BREP text, or `nil` on failure.
- **OCCT:** `OCCTShapeToBREPString` → `BRepTools::Write` to string stream.

---

### `Shape.fromBREPString(_:)`

Deserialize a shape from a BREP-format string.

```swift
public static func fromBREPString(_ brep: String) -> Shape?
```

- **Returns:** Deserialized shape, or `nil` if the string is invalid.
- **OCCT:** `OCCTShapeFromBREPString` → `BRepTools::Read` from string stream.
- **Example:**
  ```swift
  if let box = Shape.box(width: 5, height: 5, depth: 5),
     let brep = box.toBREPString(),
     let restored = Shape.fromBREPString(brep) {
      // restored is equivalent to box
  }
  ```

---

### `PlaneGeometry`

Static utilities for `gp_Pln` distance and containment queries.

#### `PlaneGeometry.distanceToPoint(planeOrigin:planeNormal:point:)`

Signed distance from a plane to a point.

```swift
public static func distanceToPoint(
    planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
    point: SIMD3<Double>
) -> Double
```

- **OCCT:** `OCCTPlaneDistanceToPoint` → `gp_Pln::Distance`.

---

#### `PlaneGeometry.distanceToLine(planeOrigin:planeNormal:linePoint:lineDirection:)`

Distance from a plane to a line.

```swift
public static func distanceToLine(
    planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
    linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>
) -> Double
```

- **OCCT:** `OCCTPlaneDistanceToLine` → `gp_Pln::Distance`.

---

#### `PlaneGeometry.containsPoint(planeOrigin:planeNormal:point:tolerance:)`

Check if a plane contains a point within tolerance.

```swift
public static func containsPoint(
    planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
    point: SIMD3<Double>,
    tolerance: Double = 1e-7
) -> Bool
```

- **OCCT:** `OCCTPlaneContainsPoint` → `gp_Pln::Contains`.

---

### `LineGeometry`

Static utilities for `gp_Lin` distance and containment queries.

#### `LineGeometry.distanceToPoint(linePoint:lineDirection:point:)`

Distance from a line to a point.

```swift
public static func distanceToPoint(
    linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>,
    point: SIMD3<Double>
) -> Double
```

- **OCCT:** `OCCTLineDistanceToPoint` → `gp_Lin::Distance`.

---

#### `LineGeometry.distanceToLine(line1Point:line1Direction:line2Point:line2Direction:)`

Distance between two lines.

```swift
public static func distanceToLine(
    line1Point: SIMD3<Double>, line1Direction: SIMD3<Double>,
    line2Point: SIMD3<Double>, line2Direction: SIMD3<Double>
) -> Double
```

- **OCCT:** `OCCTLineDistanceToLine` → `gp_Lin::Distance`.

---

#### `LineGeometry.containsPoint(linePoint:lineDirection:point:tolerance:)`

Check if a line contains a point within tolerance.

```swift
public static func containsPoint(
    linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>,
    point: SIMD3<Double>,
    tolerance: Double = 1e-7
) -> Bool
```

- **OCCT:** `OCCTLineContainsPoint` → `gp_Lin::Contains`.

---

### `Surface.BezierProperties`

Accessor struct for `Geom_BezierSurface`-specific properties (valid only when the underlying surface is a Bezier surface).

```swift
public struct BezierProperties: @unchecked Sendable
```

#### `BezierProperties.nbUPoles`

Number of poles in the U direction.

```swift
public var nbUPoles: Int
```

- **OCCT:** `OCCTSurfaceBezierNbUPoles` → `Geom_BezierSurface::NbUPoles`.

---

#### `BezierProperties.nbVPoles`

Number of poles in the V direction.

```swift
public var nbVPoles: Int
```

- **OCCT:** `OCCTSurfaceBezierNbVPoles` → `Geom_BezierSurface::NbVPoles`.

---

#### `BezierProperties.uDegree`

Polynomial degree in U.

```swift
public var uDegree: Int
```

- **OCCT:** `OCCTSurfaceBezierUDegree` → `Geom_BezierSurface::UDegree`.

---

#### `BezierProperties.vDegree`

Polynomial degree in V.

```swift
public var vDegree: Int
```

- **OCCT:** `OCCTSurfaceBezierVDegree` → `Geom_BezierSurface::VDegree`.

---

#### `BezierProperties.isURational`

Whether the surface is rational in U.

```swift
public var isURational: Bool
```

- **OCCT:** `OCCTSurfaceBezierIsURational` → `Geom_BezierSurface::IsURational`.

---

#### `BezierProperties.isVRational`

Whether the surface is rational in V.

```swift
public var isVRational: Bool
```

- **OCCT:** `OCCTSurfaceBezierIsVRational` → `Geom_BezierSurface::IsVRational`.

---

#### `BezierProperties.pole(uIndex:vIndex:)`

Get a control pole (1-based indices).

```swift
public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double>
```

- **OCCT:** `OCCTSurfaceBezierGetPole` → `Geom_BezierSurface::Pole`.

---

#### `BezierProperties.setPole(uIndex:vIndex:point:)`

Set a control pole (1-based indices).

```swift
@discardableResult
public func setPole(uIndex: Int, vIndex: Int, point: SIMD3<Double>) -> Bool
```

- **OCCT:** `OCCTSurfaceBezierSetPole` → `Geom_BezierSurface::SetPole`.

---

#### `BezierProperties.setWeight(uIndex:vIndex:weight:)`

Set a pole weight (1-based indices).

```swift
@discardableResult
public func setWeight(uIndex: Int, vIndex: Int, weight: Double) -> Bool
```

- **OCCT:** `OCCTSurfaceBezierSetWeight` → `Geom_BezierSurface::SetWeight`.

---

#### `BezierProperties.segment(u1:u2:v1:v2:)`

Extract a parametric segment of the Bezier surface.

```swift
@discardableResult
public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool
```

- **OCCT:** `OCCTSurfaceBezierSegment` → `Geom_BezierSurface::Segment`.

---

#### `BezierProperties.exchangeUV()`

Exchange the U and V parametric directions.

```swift
@discardableResult
public func exchangeUV() -> Bool
```

- **OCCT:** `OCCTSurfaceBezierExchangeUV` → `Geom_BezierSurface::ExchangeUV`.

---

### `Surface.bezierProperties`

Bezier-surface-specific accessor for a `Surface` instance.

```swift
public var bezierProperties: BezierProperties
```

---

### `Surface.bsplineResolution(tolerance3d:)`

Compute U and V parameter resolution for a given 3D tolerance (BSpline surface).

```swift
public func bsplineResolution(tolerance3d: Double) -> (uResolution: Double, vResolution: Double)
```

- **OCCT:** `OCCTSurfaceBSplineResolution` → `Geom_BSplineSurface::Resolution`.

---

### `Surface.bsplineSetUPeriodic(_:)`

Set or remove U periodicity on a BSpline surface.

```swift
@discardableResult
public func bsplineSetUPeriodic(_ periodic: Bool) -> Bool
```

- **OCCT:** `OCCTSurfaceBSplineSetUPeriodic` → `Geom_BSplineSurface::SetUPeriodic` / `SetUNotPeriodic`.

---

### `Surface.bsplineSetVPeriodic(_:)`

Set or remove V periodicity on a BSpline surface.

```swift
@discardableResult
public func bsplineSetVPeriodic(_ periodic: Bool) -> Bool
```

- **OCCT:** `OCCTSurfaceBSplineSetVPeriodic` → `Geom_BSplineSurface::SetVPeriodic` / `SetVNotPeriodic`.

---

### `Surface.bsplineWeight(uIndex:vIndex:)`

Get a pole weight from a BSpline surface (1-based indices).

```swift
public func bsplineWeight(uIndex: Int, vIndex: Int) -> Double
```

- **OCCT:** `OCCTSurfaceBSplineGetWeight` → `Geom_BSplineSurface::Weight`.

---

### `Curve2D.BezierProperties`

Accessor struct for `Geom2d_BezierCurve`-specific properties.

```swift
public struct BezierProperties: @unchecked Sendable
```

#### `Curve2D.BezierProperties.degree`

Polynomial degree.

```swift
public var degree: Int
```

- **OCCT:** `OCCTCurve2DBezierDegree` → `Geom2d_BezierCurve::Degree`.

---

#### `Curve2D.BezierProperties.poleCount`

Number of control poles.

```swift
public var poleCount: Int
```

- **OCCT:** `OCCTCurve2DBezierPoleCount` → `Geom2d_BezierCurve::NbPoles`.

---

#### `Curve2D.BezierProperties.isRational`

Whether the curve is rational.

```swift
public var isRational: Bool
```

- **OCCT:** `OCCTCurve2DBezierIsRational` → `Geom2d_BezierCurve::IsRational`.

---

#### `Curve2D.BezierProperties.pole(at:)`

Get a control pole (1-based index).

```swift
public func pole(at index: Int) -> SIMD2<Double>
```

- **OCCT:** `OCCTCurve2DBezierGetPole` → `Geom2d_BezierCurve::Pole`.

---

#### `Curve2D.BezierProperties.setPole(at:point:)`

Set a control pole (1-based index).

```swift
@discardableResult
public func setPole(at index: Int, point: SIMD2<Double>) -> Bool
```

- **OCCT:** `OCCTCurve2DBezierSetPole` → `Geom2d_BezierCurve::SetPole`.

---

#### `Curve2D.BezierProperties.setWeight(at:weight:)`

Set a pole weight (1-based index).

```swift
@discardableResult
public func setWeight(at index: Int, weight: Double) -> Bool
```

- **OCCT:** `OCCTCurve2DBezierSetWeight` → `Geom2d_BezierCurve::SetWeight`.

---

#### `Curve2D.BezierProperties.resolution(tolerance:)`

Compute parameter resolution from 2D tolerance.

```swift
public func resolution(tolerance: Double) -> Double
```

- **OCCT:** `OCCTCurve2DBezierResolution` → `Geom2d_BezierCurve::Resolution`.

---

### `Curve2D.bezierProperties`

2D Bezier curve-specific accessor.

```swift
public var bezierProperties: BezierProperties
```

---

### `Curve2D.bsplineSetPeriodic(_:)`

Set or remove periodicity on a 2D BSpline curve.

```swift
@discardableResult
public func bsplineSetPeriodic(_ periodic: Bool) -> Bool
```

- **OCCT:** `OCCTCurve2DBSplineSetPeriodic` → `Geom2d_BSplineCurve::SetPeriodic` / `SetNotPeriodic`.

---

### `Curve2D.bsplineWeight(at:)`

Get the weight at a pole index (1-based) from a 2D BSpline curve.

```swift
public func bsplineWeight(at index: Int) -> Double
```

- **OCCT:** `OCCTCurve2DBSplineGetWeight` → `Geom2d_BSplineCurve::Weight`.

---

### `Curve2D.bsplineWeights()`

Get all weights from a 2D BSpline curve.

```swift
public func bsplineWeights() -> [Double]
```

- **Returns:** Array of weights in pole order; empty if the curve has no poles.
- **OCCT:** `OCCTCurve2DBSplineGetWeights` → `Geom2d_BSplineCurve::Weights`.
