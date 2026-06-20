---
title: Document — Math, Bounds, OSD & Conversions
parent: API Reference
---

# Document — Math, Bounds, OSD & Conversions

This page covers the math solvers, bounding-box types, quaternion/timer utilities, point classification, curve/surface conversion helpers, and OSD utilities found in lines 4959–6350 of `Document.swift`. For the core document lifecycle, shape tools, and XCAF I/O see the main [Document](Document.md) page.

## Topics

- [gp_Quaternion](#gp_quaternion) · [OSD_Timer](#osd_timer) · [Bnd_OBB](#bnd_obb) · [Bnd_Range](#bnd_range) · [BRepClass3d Point Classification](#brepclass3d-point-classification) · [TDataXtd_Constraint](#tdataxtd_constraint) · [OSD_MemInfo](#osd_meminfo) · [ShapeFix_EdgeProjAux](#shapefix_edgeprojaux) · [Geom2dAPI_Interpolate](#geom2dapi_interpolate) · [Geom2dAPI_PointsToBSpline](#geom2dapi_pointstobspline) · [TDataXtd_PatternStd](#tdataxtd_patternstd) · [BRepAlgo_FaceRestrictor](#brepalgo_facerestrictor) · [math_Matrix](#math_matrix) · [math_Gauss](#math_gauss) · [math_SVD](#math_svd) · [math_DirectPolynomialRoots](#math_directpolynomialroots) · [math_Jacobi](#math_jacobi) · [Convert_CircleToBSplineCurve](#convert_circletobsplinecurve) · [Convert_SphereToBSplineSurface](#convert_spheretobsplinesurface) · [Convert Conic Curves to BSpline](#convert-conic-curves-to-bspline) · [Convert Elementary Surfaces to BSpline](#convert-elementary-surfaces-to-bspline) · [math_Householder](#math_householder) · [math_Crout](#math_crout) · [ShapeFix_IntersectionTool](#shapefix_intersectiontool) · [XCAFDoc_AssemblyItemRef](#xcafdoc_assemblyitemref) · [BRepAlgo_Image](#brepalgo_image) · [OSD_Path](#osd_path) · [BRepClass_FClassifier](#brepclass_fclassifier) · [Bnd_BoundSortBox](#bnd_boundsortbox) · [TNaming_Naming](#tnaming_naming) · [Precision Constants](#precision-constants) · [IntAna Analytic Intersections](#intana-analytic-intersections) · [OSD_Chronometer](#osd_chronometer) · [OSD_Process](#osd_process) · [Draft_Modification](#draft_modification) · [Convert_CompBezierCurvesToBSplineCurve](#convert_compbezierperformancetobsplinecurve) · [Geom_OffsetSurface Extensions](#geom_offsetsurface-extensions)

---

## gp_Quaternion

Wraps `gp_Quaternion` — OCCT's unit-quaternion for representing 3D rotations. Obtain one via `init(x:y:z:w:)`, `fromAxisAngle`, or `fromVectors`.

### `Quaternion.init(x:y:z:w:)`

Create a quaternion from its four components.

```swift
public convenience init(x: Double = 0, y: Double = 0, z: Double = 0, w: Double = 1)
```

- **Parameters:** `x`, `y`, `z` — vector part; `w` — scalar part. Defaults to the identity quaternion (0, 0, 0, 1).
- **OCCT:** `gp_Quaternion(x, y, z, w)` (via `OCCTQuaternionCreate`).
- **Example:**
  ```swift
  let identity = Quaternion()
  let q = Quaternion(x: 0, y: 0, z: 0.7071, w: 0.7071)
  ```

---

### `Quaternion.fromAxisAngle(axis:angle:)`

Create a quaternion from an axis-angle rotation.

```swift
public static func fromAxisAngle(axis: SIMD3<Double>, angle: Double) -> Quaternion
```

- **Parameters:** `axis` — rotation axis (need not be normalized); `angle` — rotation angle in radians.
- **OCCT:** `gp_Quaternion::SetVectorAndAngle` (via `OCCTQuaternionCreateFromAxisAngle`).
- **Example:**
  ```swift
  let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 4)
  ```

---

### `Quaternion.fromVectors(from:to:)`

Create a quaternion representing the shortest-arc rotation from one vector to another.

```swift
public static func fromVectors(from: SIMD3<Double>, to: SIMD3<Double>) -> Quaternion
```

- **Parameters:** `from` — source direction; `to` — target direction.
- **OCCT:** `gp_Quaternion::SetRotation` (via `OCCTQuaternionCreateFromVectors`).
- **Example:**
  ```swift
  let q = Quaternion.fromVectors(from: SIMD3(1, 0, 0), to: SIMD3(0, 1, 0))
  ```

---

### `components`

The four quaternion components (x, y, z, w).

```swift
public var components: (x: Double, y: Double, z: Double, w: Double) { get }
```

- **OCCT:** `gp_Quaternion::X/Y/Z/W` (via `OCCTQuaternionGetComponents`).
- **Example:**
  ```swift
  let c = q.components
  print(c.w)  // scalar part
  ```

---

### `setEulerAngles(order:alpha:beta:gamma:)`

Set the quaternion from Euler angles.

```swift
public func setEulerAngles(order: Int32, alpha: Double, beta: Double, gamma: Double)
```

- **Parameters:** `order` — Euler convention index (0 = Intrinsic_XYZ, see `gp_EulerSequence`); `alpha`, `beta`, `gamma` — angles in radians.
- **OCCT:** `gp_Quaternion::SetEulerAngles` (via `OCCTQuaternionSetEulerAngles`).
- **Example:**
  ```swift
  q.setEulerAngles(order: 0, alpha: 0.1, beta: 0.2, gamma: 0.3)
  ```

---

### `getEulerAngles(order:)`

Get the Euler angle decomposition of this quaternion.

```swift
public func getEulerAngles(order: Int32) -> (alpha: Double, beta: Double, gamma: Double)
```

- **Parameters:** `order` — Euler convention index (same encoding as `setEulerAngles`).
- **Returns:** Tuple of three angles in radians.
- **OCCT:** `gp_Quaternion::GetEulerAngles` (via `OCCTQuaternionGetEulerAngles`).
- **Example:**
  ```swift
  let (a, b, g) = q.getEulerAngles(order: 0)
  ```

---

### `matrix`

The 3×3 rotation matrix represented by this quaternion, in row-major order (9 elements).

```swift
public var matrix: [Double] { get }
```

- **Returns:** A 9-element `[Double]` where `matrix[row*3 + col]` is `M[row][col]`.
- **OCCT:** `gp_Quaternion::GetVectorPart` / matrix conversion (via `OCCTQuaternionGetMatrix`).
- **Example:**
  ```swift
  let m = q.matrix
  // m[0] m[1] m[2]
  // m[3] m[4] m[5]
  // m[6] m[7] m[8]
  ```

---

### `rotate(_:)`

Rotate a 3D vector by this quaternion.

```swift
public func rotate(_ vector: SIMD3<Double>) -> SIMD3<Double>
```

- **Parameters:** `vector` — the vector to rotate.
- **Returns:** The rotated vector.
- **OCCT:** `gp_Quaternion::Multiply` with `gp_Vec` (via `OCCTQuaternionMultiplyVec`).
- **Example:**
  ```swift
  let rotated = q.rotate(SIMD3(1, 0, 0))
  ```

---

### `multiplied(by:)`

Hamilton product of two quaternions.

```swift
public func multiplied(by other: Quaternion) -> Quaternion
```

- **Parameters:** `other` — the right-hand quaternion.
- **Returns:** A new `Quaternion` representing the composed rotation.
- **OCCT:** `gp_Quaternion::Multiplied` (via `OCCTQuaternionMultiply`).
- **Example:**
  ```swift
  let composed = q1.multiplied(by: q2)
  ```

---

### `axisAngle`

Axis-angle representation of this quaternion.

```swift
public var axisAngle: (axis: SIMD3<Double>, angle: Double) { get }
```

- **Returns:** Tuple of the rotation axis and angle in radians.
- **OCCT:** `gp_Quaternion::GetVectorAndAngle` (via `OCCTQuaternionGetVectorAndAngle`).
- **Example:**
  ```swift
  let (axis, angle) = q.axisAngle
  ```

---

### `rotationAngle`

The rotation angle encoded in this quaternion.

```swift
public var rotationAngle: Double { get }
```

- **Returns:** Angle in radians.
- **OCCT:** `gp_Quaternion::GetRotationAngle` (via `OCCTQuaternionGetRotationAngle`).
- **Example:**
  ```swift
  print(q.rotationAngle)  // e.g. 0.7853...
  ```

---

### `normalize()`

Normalize this quaternion to unit length in-place.

```swift
public func normalize()
```

- **OCCT:** `gp_Quaternion::Normalize` (via `OCCTQuaternionNormalize`).
- **Example:**
  ```swift
  q.normalize()
  ```

---

## OSD_Timer

Wraps `OSD_Timer` — a high-resolution wall-clock timer suitable for profiling.

### `Timer.init()`

Create a new timer (initially stopped, elapsed = 0).

```swift
public init()
```

- **OCCT:** `OSD_Timer()` (via `OCCTTimerCreate`).
- **Example:**
  ```swift
  let t = Timer()
  ```

---

### `start()`

Start (or resume) the timer.

```swift
public func start()
```

- **OCCT:** `OSD_Timer::Start` (via `OCCTTimerStart`).
- **Example:**
  ```swift
  t.start()
  ```

---

### `stop()`

Stop the timer, preserving elapsed time.

```swift
public func stop()
```

- **OCCT:** `OSD_Timer::Stop` (via `OCCTTimerStop`).
- **Example:**
  ```swift
  t.stop()
  ```

---

### `reset()`

Reset elapsed time to zero.

```swift
public func reset()
```

- **OCCT:** `OSD_Timer::Reset` (via `OCCTTimerReset`).
- **Example:**
  ```swift
  t.reset()
  ```

---

### `elapsedTime`

Elapsed wall-clock time in seconds.

```swift
public var elapsedTime: Double { get }
```

- **OCCT:** `OSD_Timer::ElapsedTime` (via `OCCTTimerElapsedTime`).
- **Example:**
  ```swift
  t.start()
  // ... work ...
  t.stop()
  print(t.elapsedTime)
  ```

---

### `Timer.wallClockTime`

Current wall-clock time in seconds (static, absolute).

```swift
public static var wallClockTime: Double { get }
```

- **OCCT:** `OSD_Timer::GetWallClockTime` (via `OCCTTimerGetWallClockTime`).
- **Example:**
  ```swift
  let now = Timer.wallClockTime
  ```

---

## Bnd_OBB

Wraps `Bnd_OBB` — an oriented bounding box in 3D space defined by center, local axes, and half-sizes.

### `OBB.init(center:xDir:yDir:zDir:hx:hy:hz:)`

Create an OBB from explicit center, local axes, and half-extents.

```swift
public init(center: SIMD3<Double>, xDir: SIMD3<Double>, yDir: SIMD3<Double>, zDir: SIMD3<Double>,
            hx: Double, hy: Double, hz: Double)
```

- **Parameters:** `center` — center point; `xDir`/`yDir`/`zDir` — local orthonormal axes; `hx`/`hy`/`hz` — half-sizes along each axis.
- **OCCT:** `Bnd_OBB(center, xDir, yDir, zDir, hx, hy, hz)` (via `OCCTOBBCreate`).
- **Example:**
  ```swift
  let obb = OBB(center: SIMD3(0, 0, 0),
                xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0), zDir: SIMD3(0, 0, 1),
                hx: 1, hy: 2, hz: 0.5)
  ```

---

### `OBB.fromShape(_:)`

Compute the tightest OBB enclosing a shape.

```swift
public static func fromShape(_ shape: Shape) -> OBB?
```

- **Parameters:** `shape` — the source shape.
- **Returns:** The OBB, or `nil` if the shape has no computable bounds.
- **OCCT:** `BRepBndLib::AddOBB` (via `OCCTOBBCreateFromShape`).
- **Example:**
  ```swift
  if let obb = OBB.fromShape(myBox) {
      print(obb.halfSizes)
  }
  ```

---

### `isVoid`

Whether the OBB is empty (unset).

```swift
public var isVoid: Bool { get }
```

- **OCCT:** `Bnd_OBB::IsVoid` (via `OCCTOBBIsVoid`).

---

### `center`

Center of the OBB in world space.

```swift
public var center: SIMD3<Double> { get }
```

- **OCCT:** `Bnd_OBB::Center` (via `OCCTOBBGetCenter`).

---

### `halfSizes`

Half-extents along the OBB's local X, Y, Z axes.

```swift
public var halfSizes: SIMD3<Double> { get }
```

- **OCCT:** `Bnd_OBB::XHSize / YHSize / ZHSize` (via `OCCTOBBGetHalfSizes`).
- **Example:**
  ```swift
  let volume = obb.halfSizes.x * obb.halfSizes.y * obb.halfSizes.z * 8
  ```

---

### `isOut(point:)`

Check if a point lies outside the OBB.

```swift
public func isOut(point: SIMD3<Double>) -> Bool
```

- **Parameters:** `point` — the 3D point to test.
- **Returns:** `true` if the point is strictly outside.
- **OCCT:** `Bnd_OBB::IsOut(gp_Pnt)` (via `OCCTOBBIsOutPoint`).
- **Example:**
  ```swift
  if !obb.isOut(point: SIMD3(0, 0, 0)) { /* center is inside */ }
  ```

---

### `isOut(_:)` (OBB overload)

Check if another OBB has no overlap with this one.

```swift
public func isOut(_ other: OBB) -> Bool
```

- **Parameters:** `other` — OBB to test.
- **Returns:** `true` if the two OBBs are disjoint.
- **OCCT:** `Bnd_OBB::IsOut(Bnd_OBB)` (via `OCCTOBBIsOutOBB`).

---

### `enlarge(by:)`

Expand all half-extents by a gap value.

```swift
public func enlarge(by gap: Double)
```

- **Parameters:** `gap` — expansion amount on each side.
- **OCCT:** `Bnd_OBB::Enlarge` (via `OCCTOBBEnlarge`).

---

### `squareExtent`

Squared length of the OBB diagonal.

```swift
public var squareExtent: Double { get }
```

- **OCCT:** `Bnd_OBB::SquareExtent` (via `OCCTOBBSquareExtent`).

---

## Bnd_Range

Wraps `Bnd_Range` — a 1D interval [min, max] that also carries a "void" (empty) state.

### `Range.init(min:max:)`

Create a range with explicit bounds.

```swift
public init(min: Double, max: Double)
```

- **OCCT:** `Bnd_Range(min, max)` (via `OCCTRangeCreate`).
- **Example:**
  ```swift
  let r = Range(min: 0.0, max: 10.0)
  ```

---

### `Range.init()` (void)

Create a void (empty) range.

```swift
public init()
```

- **OCCT:** `Bnd_Range()` (via `OCCTRangeCreateVoid`).

---

### `isVoid`

Whether the range is empty.

```swift
public var isVoid: Bool { get }
```

- **OCCT:** `Bnd_Range::IsVoid` (via `OCCTRangeIsVoid`).

---

### `bounds`

Lower and upper bounds of the range.

```swift
public var bounds: (first: Double, last: Double)? { get }
```

- **Returns:** `nil` if the range is void.
- **OCCT:** `Bnd_Range::GetBounds` (via `OCCTRangeGetBounds`).
- **Example:**
  ```swift
  if let b = r.bounds {
      print(b.first, b.last)
  }
  ```

---

### `delta`

Length of the range (max − min).

```swift
public var delta: Double { get }
```

- **OCCT:** `Bnd_Range::Delta` (via `OCCTRangeDelta`).

---

### `contains(_:)`

Test whether a value falls within the range.

```swift
public func contains(_ value: Double) -> Bool
```

- **OCCT:** `Bnd_Range::IsIntersected` / point test (via `OCCTRangeContains`).

---

### `add(_:)` (value)

Extend the range to include a scalar value.

```swift
public func add(_ value: Double)
```

- **OCCT:** `Bnd_Range::Add(Standard_Real)` (via `OCCTRangeAddValue`).

---

### `add(_:)` (Range)

Extend the range to include another range.

```swift
public func add(_ other: Range)
```

- **OCCT:** `Bnd_Range::Add(Bnd_Range)` (via `OCCTRangeAddRange`).

---

### `common(_:)`

Intersect this range with another (retain overlap only).

```swift
public func common(_ other: Range)
```

- **OCCT:** `Bnd_Range::Common` (via `OCCTRangeCommon`).

---

### `enlarge(by:)`

Expand both boundaries outward by `delta`.

```swift
public func enlarge(by delta: Double)
```

- **OCCT:** `Bnd_Range::Enlarge` (via `OCCTRangeEnlarge`).

---

### `trimFrom(_:)`

Raise the lower boundary to at least `lower`.

```swift
public func trimFrom(_ lower: Double)
```

- **OCCT:** `Bnd_Range::TrimFrom` (via `OCCTRangeTrimFrom`).

---

### `trimTo(_:)`

Lower the upper boundary to at most `upper`.

```swift
public func trimTo(_ upper: Double)
```

- **OCCT:** `Bnd_Range::TrimTo` (via `OCCTRangeTrimTo`).

---

## BRepClass3d Point Classification

Extension on `Shape` wrapping `BRepClass3d_SolidClassifier`.

### `Shape.PointState`

Classification of a 3D point relative to a solid.

```swift
public enum PointState: Int32 {
    case inside = 0
    case outside = 1
    case on = 2
    case unknown = 3
}
```

---

### `classifyPoint(_:tolerance:)`

Classify a 3D point relative to this solid shape.

```swift
public func classifyPoint(_ point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointState
```

- **Parameters:** `point` — 3D point; `tolerance` — classification tolerance.
- **Returns:** `.inside`, `.outside`, `.on`, or `.unknown`.
- **OCCT:** `BRepClass3d_SolidClassifier::Perform` (via `OCCTShapeClassifyPoint`).
- **Example:**
  ```swift
  let box = Shape.box(dx: 10, dy: 10, dz: 10)!
  let state = box.classifyPoint(SIMD3(5, 5, 5))
  // state == .inside
  ```

---

## TDataXtd_Constraint

Extension on `Document` wrapping `TDataXtd_Constraint` — dimensional and geometric constraints stored as OCAF attributes.

### `Document.ConstraintType`

Constraint kind enumeration matching `TDataXtd_ConstraintEnum`.

```swift
public enum ConstraintType: Int32 {
    case radius = 0, diameter, minorRadius, majorRadius
    case tangent, parallel, perpendicular, concentric
    case coincident, distance, angle, equalRadius
    case symmetry, midPoint, equalDistance, fix
    case rigid, from
}
```

---

### `setConstraint(labelId:)`

Attach a `TDataXtd_Constraint` attribute to a label.

```swift
@discardableResult
public func setConstraint(labelId: Int64) -> Bool
```

- **Parameters:** `labelId` — target label identifier.
- **Returns:** `true` on success.
- **OCCT:** `TDataXtd_Constraint::Set` (via `OCCTDocumentSetConstraint`).
- **Example:**
  ```swift
  doc.setConstraint(labelId: labelId)
  ```

---

### `constraintSetType(labelId:type:)`

Set the constraint type on an existing constraint attribute.

```swift
@discardableResult
public func constraintSetType(labelId: Int64, type: ConstraintType) -> Bool
```

- **OCCT:** `TDataXtd_Constraint::SetType` (via `OCCTDocumentConstraintSetType`).

---

### `constraintGetType(labelId:)`

Retrieve the constraint type.

```swift
public func constraintGetType(labelId: Int64) -> ConstraintType?
```

- **Returns:** `nil` if no constraint attribute exists on the label.
- **OCCT:** `TDataXtd_Constraint::GetType` (via `OCCTDocumentConstraintGetType`).

---

### `constraintNbGeometries(labelId:)`

Number of geometry references attached to this constraint.

```swift
public func constraintNbGeometries(labelId: Int64) -> Int
```

- **OCCT:** `TDataXtd_Constraint::NbGeometries` (via `OCCTDocumentConstraintNbGeometries`).

---

### `constraintIsPlanar(labelId:)`

Whether the constraint is a planar (2D) constraint.

```swift
public func constraintIsPlanar(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_Constraint::IsPlanar` (via `OCCTDocumentConstraintIsPlanar`).

---

### `constraintIsDimension(labelId:)`

Whether the constraint carries a dimensional value.

```swift
public func constraintIsDimension(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_Constraint::IsDimension` (via `OCCTDocumentConstraintIsDimension`).

---

### `constraintSetVerified(labelId:verified:)`

Set the verified flag on a constraint.

```swift
@discardableResult
public func constraintSetVerified(labelId: Int64, verified: Bool) -> Bool
```

- **OCCT:** `TDataXtd_Constraint::Verified` (via `OCCTDocumentConstraintSetVerified`).

---

### `constraintGetVerified(labelId:)`

Get the verified flag of a constraint.

```swift
public func constraintGetVerified(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_Constraint::Verified` accessor (via `OCCTDocumentConstraintGetVerified`).

---

### `constraintClearGeometries(labelId:)`

Remove all geometry references from a constraint attribute.

```swift
@discardableResult
public func constraintClearGeometries(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_Constraint` geometry list clear (via `OCCTDocumentConstraintClearGeometries`).

---

## OSD_MemInfo

Namespace wrapping `OSD_MemInfo` — process memory statistics.

### `MemInfo.heapUsage`

Heap allocated bytes for the current process.

```swift
public static var heapUsage: Int64 { get }
```

- **OCCT:** `OSD_MemInfo::Value(OSD_MemInfo_Heap)` (via `OCCTMemInfoHeapUsage`).

---

### `MemInfo.workingSet`

Working set (resident memory) in bytes.

```swift
public static var workingSet: Int64 { get }
```

- **OCCT:** `OSD_MemInfo::Value(OSD_MemInfo_WSet)` (via `OCCTMemInfoWorkingSet`).

---

### `MemInfo.heapUsageMiB`

Heap usage as a precise `Double` in mebibytes.

```swift
public static var heapUsageMiB: Double { get }
```

- **OCCT:** `OSD_MemInfo::ValueMiB(OSD_MemInfo_Heap)` (via `OCCTMemInfoHeapUsageMiB`).

---

### `MemInfo.infoString`

Full formatted memory report string from OCCT.

```swift
public static var infoString: String? { get }
```

- **Returns:** A multi-line string with all tracked counters, or `nil` on error.
- **OCCT:** `OSD_MemInfo::ToString` (via `OCCTMemInfoString`).
- **Example:**
  ```swift
  if let info = MemInfo.infoString {
      print(info)
  }
  ```

---

## ShapeFix_EdgeProjAux

Extension on `Shape` wrapping `ShapeFix_EdgeProjAux` — projects edge endpoints back onto the 2D pcurve on a face.

### `edgeProjAux(faceIndex:edgeIndex:precision:)`

Project edge endpoints onto a face's 2D parameter space.

```swift
public func edgeProjAux(faceIndex: Int, edgeIndex: Int, precision: Double = 1e-6) -> (first: Double, last: Double)?
```

- **Parameters:** `faceIndex` — 0-based face index; `edgeIndex` — 0-based edge index within that face; `precision` — projection precision.
- **Returns:** `(firstParam, lastParam)` on the pcurve, or `nil` if projection fails.
- **OCCT:** `ShapeFix_EdgeProjAux::Compute` (via `OCCTShapeFixEdgeProjAux`).
- **Example:**
  ```swift
  if let (p1, p2) = shape.edgeProjAux(faceIndex: 0, edgeIndex: 0) {
      print("params:", p1, p2)
  }
  ```

---

## Geom2dAPI_Interpolate

Extension on `Curve2D` wrapping `Geom2dAPI_Interpolate` — exact interpolation through 2D points.

### `Curve2D.interpolate2D(points:periodic:tolerance:)`

Interpolate a 2D BSpline curve exactly through the given points.

```swift
public static func interpolate2D(points: [(Double, Double)], periodic: Bool = false, tolerance: Double = 1e-6) -> Curve2D?
```

- **Parameters:** `points` — ordered (x, y) pairs to pass through; `periodic` — if `true`, produce a closed periodic curve; `tolerance` — interpolation tolerance.
- **Returns:** The interpolated `Curve2D`, or `nil` on failure.
- **OCCT:** `Geom2dAPI_Interpolate::Perform` (via `OCCTCurve2DInterpolate2D`).
- **Example:**
  ```swift
  let pts = [(0.0, 0.0), (1.0, 1.0), (2.0, 0.0)]
  if let curve = Curve2D.interpolate2D(points: pts) {
      // curve passes exactly through all three points
  }
  ```

---

## Geom2dAPI_PointsToBSpline

Extension on `Curve2D` wrapping `Geom2dAPI_PointsToBSpline` — least-squares approximation through 2D points.

### `Curve2D.approximate2D(points:)`

Approximate a 2D BSpline curve through a set of points (least-squares fit).

```swift
public static func approximate2D(points: [(Double, Double)]) -> Curve2D?
```

- **Parameters:** `points` — ordered (x, y) pairs to approximate.
- **Returns:** The approximating `Curve2D`, or `nil` on failure.
- **OCCT:** `Geom2dAPI_PointsToBSpline::Curve` (via `OCCTCurve2DApproximate2D`).
- **Note:** Unlike `interpolate2D`, the curve does not pass exactly through all points; it minimises squared deviation.
- **Example:**
  ```swift
  let pts = [(0.0, 0.0), (0.5, 0.8), (1.0, 0.1), (1.5, 0.9), (2.0, 0.0)]
  if let approx = Curve2D.approximate2D(points: pts) {
      // smooth fit curve
  }
  ```

---

## TDataXtd_PatternStd

Extension on `Document` wrapping `TDataXtd_PatternStd` — pattern replication attributes stored in the OCAF document tree.

### `Document.PatternSignature`

Pattern type enumeration.

```swift
public enum PatternSignature: Int32 {
    case linear = 1
    case circular = 2
    case rectangular = 3
    case radialCircular = 4
    case mirror = 5
}
```

---

### `setPattern(labelId:)`

Attach a `TDataXtd_PatternStd` attribute to a label.

```swift
@discardableResult
public func setPattern(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_PatternStd::Set` (via `OCCTDocumentSetPatternStd`).

---

### `hasPattern(labelId:)`

Check whether a label carries a pattern attribute.

```swift
public func hasPattern(labelId: Int64) -> Bool
```

- **OCCT:** `TDataXtd_PatternStd::Find` (via `OCCTDocumentHasPattern`).

---

### `patternSetSignature(labelId:signature:)`

Set the pattern type.

```swift
@discardableResult
public func patternSetSignature(labelId: Int64, signature: PatternSignature) -> Bool
```

- **OCCT:** `TDataXtd_PatternStd::SetSignature` (via `OCCTDocumentPatternSetSignature`).

---

### `patternGetSignature(labelId:)`

Retrieve the pattern type.

```swift
public func patternGetSignature(labelId: Int64) -> PatternSignature?
```

- **Returns:** `nil` if no pattern attribute exists.
- **OCCT:** `TDataXtd_PatternStd::Signature` (via `OCCTDocumentPatternGetSignature`).

---

### `patternNbTrsfs(labelId:)`

Number of transforms (instances) defined by this pattern.

```swift
public func patternNbTrsfs(labelId: Int64) -> Int
```

- **OCCT:** `TDataXtd_PatternStd::NbTrsfs` (via `OCCTDocumentPatternNbTrsfs`).

---

## BRepAlgo_FaceRestrictor

Extension on `Shape` wrapping `BRepAlgo_FaceRestrictor` — rebuilds a face bounded by its wires.

### `faceRestrictAlgo(faceIndex:)`

Restrict a face to its wire boundaries and return the resulting face count.

```swift
public func faceRestrictAlgo(faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — 0-based index of the face to restrict.
- **Returns:** Number of result faces produced by the restrictor.
- **OCCT:** `BRepAlgo_FaceRestrictor::Perform / NbFaces` (via `OCCTShapeFaceRestrictAlgo`).
- **Example:**
  ```swift
  let n = shape.faceRestrictAlgo(faceIndex: 0)
  print("result faces:", n)
  ```

---

## math_Matrix

Wraps `math_Matrix` — a dense general matrix with **1-based** row and column indexing.

### `MathMatrix.init(rows:cols:initialValue:)`

Create a matrix of given dimensions, all cells initialised to `initialValue`.

```swift
public init(rows: Int, cols: Int, initialValue: Double = 0.0)
```

- **OCCT:** `math_Matrix(rows, cols, initialValue)` (via `OCCTMathMatrixCreate`).
- **Example:**
  ```swift
  let m = MathMatrix(rows: 3, cols: 3)
  ```

---

### `rows`, `cols`

Number of rows / columns.

```swift
public var rows: Int { get }
public var cols: Int { get }
```

- **OCCT:** `math_Matrix::RowNumber / ColNumber` (via `OCCTMathMatrixRows / OCCTMathMatrixCols`).

---

### `value(row:col:)`

Read the element at (row, col) — **1-based**.

```swift
public func value(row: Int, col: Int) -> Double
```

- **OCCT:** `math_Matrix::Value` (via `OCCTMathMatrixGetValue`).
- **Example:**
  ```swift
  let v = m.value(row: 1, col: 1)
  ```

---

### `setValue(row:col:value:)`

Write the element at (row, col) — **1-based**.

```swift
public func setValue(row: Int, col: Int, value: Double)
```

- **OCCT:** `math_Matrix::SetValue` (via `OCCTMathMatrixSetValue`).

---

### `determinant`

Determinant of the matrix.

```swift
public var determinant: Double { get }
```

- **OCCT:** `math_Matrix::Determinant` (via `OCCTMathMatrixDeterminant`).

---

### `invert()`

Invert the matrix in-place.

```swift
@discardableResult
public func invert() -> Bool
```

- **Returns:** `true` on success; `false` if the matrix is singular.
- **OCCT:** `math_Matrix::Invert` (via `OCCTMathMatrixInvert`).

---

### `multiply(by:)`

Scale all elements by a scalar in-place.

```swift
public func multiply(by scalar: Double)
```

- **OCCT:** `math_Matrix::Multiply(scalar)` (via `OCCTMathMatrixMultiplyScalar`).

---

### `transpose()`

Transpose the matrix in-place.

```swift
public func transpose()
```

- **OCCT:** `math_Matrix::Transpose` (via `OCCTMathMatrixTranspose`).

---

## math_Gauss

Namespace wrapping `math_Gauss` — direct Gaussian elimination for square linear systems.

### `MathGauss.solve(matrix:rhs:)`

Solve `Ax = b` using Gaussian elimination.

```swift
public static func solve(matrix: [Double], rhs: [Double]) -> [Double]?
```

- **Parameters:** `matrix` — row-major N×N coefficient matrix (N² elements); `rhs` — right-hand side vector (N elements).
- **Returns:** Solution vector of length N, or `nil` on failure (singular matrix).
- **OCCT:** `math_Gauss::Solve` (via `OCCTMathGaussSolve`).
- **Example:**
  ```swift
  // Solve 2x + y = 5, x + 3y = 10
  let A = [2.0, 1.0, 1.0, 3.0]
  let b = [5.0, 10.0]
  if let x = MathGauss.solve(matrix: A, rhs: b) {
      print(x)  // [1.0, 3.0]
  }
  ```

---

### `MathGauss.determinant(matrix:n:)`

Compute the determinant of an N×N matrix using Gaussian elimination.

```swift
public static func determinant(matrix: [Double], n: Int) -> Double
```

- **Parameters:** `matrix` — row-major N×N matrix; `n` — dimension.
- **OCCT:** `math_Gauss::Determinant` (via `OCCTMathGaussDeterminant`).

---

## math_SVD

Namespace wrapping `math_SVD` — Singular Value Decomposition for least-squares problems.

### `MathSVD.solve(matrix:rows:cols:rhs:)`

Solve the overdetermined or exactly determined system `Ax ≈ b` in the least-squares sense.

```swift
public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]?
```

- **Parameters:** `matrix` — row-major M×N matrix; `rows` — M; `cols` — N; `rhs` — right-hand side (length M).
- **Returns:** Solution vector of length N, or `nil` on failure.
- **OCCT:** `math_SVD::Solve` (via `OCCTMathSVDSolve`).
- **Example:**
  ```swift
  // Over-determined 3x2 system
  let A = [1.0, 0, 0, 1, 1, 1]
  let b = [1.0, 2.0, 3.0]
  if let x = MathSVD.solve(matrix: A, rows: 3, cols: 2, rhs: b) {
      print(x)
  }
  ```

---

## math_DirectPolynomialRoots

Namespace wrapping `math_DirectPolynomialRoots` — closed-form real root finding for polynomials of degree 1–4.

### `MathPolynomialRoots.solve(coefficients:)`

Find real roots of a polynomial `a·xⁿ + b·xⁿ⁻¹ + … = 0`.

```swift
public static func solve(coefficients: [Double]) -> [Double]?
```

- **Parameters:** `coefficients` — `[a, b, c, …]` with the leading coefficient first; must have 2–5 elements (degree 1–4).
- **Returns:** Array of real roots (possibly empty), or `nil` on error.
- **OCCT:** `math_DirectPolynomialRoots` (via `OCCTMathPolynomialRoots`).
- **Example:**
  ```swift
  // Solve x² - 5x + 6 = 0 → roots 2, 3
  if let roots = MathPolynomialRoots.solve(coefficients: [1.0, -5.0, 6.0]) {
      print(roots)  // [2.0, 3.0] (order may vary)
  }
  ```

---

## math_Jacobi

Namespace wrapping `math_Jacobi` — Jacobi iterative eigenvalue decomposition for symmetric matrices.

### `MathJacobi.eigenvalues(matrix:n:)`

Compute eigenvalues of an N×N symmetric matrix.

```swift
public static func eigenvalues(matrix: [Double], n: Int) -> [Double]?
```

- **Parameters:** `matrix` — row-major N×N symmetric matrix; `n` — dimension.
- **Returns:** Eigenvalue array of length N, or `nil` on failure.
- **OCCT:** `math_Jacobi::Values` (via `OCCTMathJacobiEigenvalues`).
- **Example:**
  ```swift
  let sym = [2.0, 1.0, 1.0, 2.0]  // 2x2 identity-ish
  if let ev = MathJacobi.eigenvalues(matrix: sym, n: 2) {
      print(ev)  // [1.0, 3.0]
  }
  ```

---

## Convert_CircleToBSplineCurve

Extension on `Curve2D` wrapping `Convert_CircleToBSplineCurve`.

### `Curve2D.fromCircleArc(centerX:centerY:radius:u1:u2:)`

Convert a 2D circular arc to a BSpline curve.

```swift
public static func fromCircleArc(centerX: Double, centerY: Double, radius: Double,
                                  u1: Double, u2: Double) -> Curve2D?
```

- **Parameters:** `centerX`, `centerY` — arc centre; `radius` — circle radius; `u1`, `u2` — start and end parameter (in radians).
- **Returns:** The BSpline representation, or `nil` on failure.
- **OCCT:** `Convert_CircleToBSplineCurve` (via `OCCTConvertCircleToBSpline2D`).
- **Example:**
  ```swift
  // Half-circle
  if let arc = Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 1.0, u1: 0, u2: .pi) {
      print(arc.degree)
  }
  ```

---

## Convert_SphereToBSplineSurface

Extension on `Surface` wrapping `Convert_SphereToBSplineSurface`.

### `Surface.fromSphere(origin:axis:radius:)`

Convert a sphere to a BSpline surface.

```swift
public static func fromSphere(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double) -> Surface?
```

- **Parameters:** `origin` — sphere centre; `axis` — sphere axis direction; `radius` — radius.
- **Returns:** The BSpline surface, or `nil` on failure.
- **OCCT:** `Convert_SphereToBSplineSurface` (via `OCCTConvertSphereToBSplineSurface`).
- **Example:**
  ```swift
  if let bsp = Surface.fromSphere(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5.0) {
      print(bsp.surfaceKind)  // .bsplineSurface
  }
  ```

---

## Convert Conic Curves to BSpline

Extensions on `Curve2D` for exact BSpline representations of 2D conics.

### `Curve2D.fromEllipseArc(centerX:centerY:majorRadius:minorRadius:u1:u2:)`

Convert a 2D ellipse arc to a BSpline curve.

```swift
public static func fromEllipseArc(centerX: Double, centerY: Double,
                                   majorRadius: Double, minorRadius: Double,
                                   u1: Double, u2: Double) -> Curve2D?
```

- **Parameters:** `centerX`, `centerY` — ellipse centre; `majorRadius`, `minorRadius` — semi-axes; `u1`, `u2` — parameter range.
- **Returns:** BSpline curve, or `nil` on failure.
- **OCCT:** `Convert_EllipseToBSplineCurve` (via `OCCTConvertEllipseToBSpline2D`).
- **Example:**
  ```swift
  if let e = Curve2D.fromEllipseArc(centerX: 0, centerY: 0,
                                     majorRadius: 3.0, minorRadius: 1.5,
                                     u1: 0, u2: .pi) { }
  ```

---

### `Curve2D.fromHyperbolaArc(centerX:centerY:majorRadius:minorRadius:u1:u2:)`

Convert a 2D hyperbola arc to a BSpline curve.

```swift
public static func fromHyperbolaArc(centerX: Double, centerY: Double,
                                     majorRadius: Double, minorRadius: Double,
                                     u1: Double, u2: Double) -> Curve2D?
```

- **OCCT:** `Convert_HyperbolaToBSplineCurve` (via `OCCTConvertHyperbolaToBSpline2D`).

---

### `Curve2D.fromParabolaArc(centerX:centerY:focal:u1:u2:)`

Convert a 2D parabola arc to a BSpline curve.

```swift
public static func fromParabolaArc(centerX: Double, centerY: Double, focal: Double,
                                    u1: Double, u2: Double) -> Curve2D?
```

- **Parameters:** `focal` — focal distance of the parabola.
- **OCCT:** `Convert_ParabolaToBSplineCurve` (via `OCCTConvertParabolaToBSpline2D`).

---

## Convert Elementary Surfaces to BSpline

Extensions on `Surface` for exact BSpline representations of analytic surfaces.

### `Surface.fromCylinder(origin:axis:radius:u1:u2:v1:v2:)`

Convert a cylinder patch to a BSpline surface.

```swift
public static func fromCylinder(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
                                 u1: Double, u2: Double, v1: Double, v2: Double) -> Surface?
```

- **Parameters:** `origin`, `axis` — cylinder position and orientation; `radius` — cylinder radius; `u1`/`u2` — angular range (radians); `v1`/`v2` — axial parameter range.
- **OCCT:** `Convert_CylinderToBSplineSurface` (via `OCCTConvertCylinderToBSplineSurface`).
- **Example:**
  ```swift
  if let cyl = Surface.fromCylinder(origin: .zero, axis: SIMD3(0, 0, 1),
                                     radius: 2.0, u1: 0, u2: 2 * .pi,
                                     v1: 0, v2: 5.0) { }
  ```

---

### `Surface.fromCone(origin:axis:semiAngle:refRadius:u1:u2:v1:v2:)`

Convert a cone patch to a BSpline surface.

```swift
public static func fromCone(origin: SIMD3<Double>, axis: SIMD3<Double>,
                             semiAngle: Double, refRadius: Double,
                             u1: Double, u2: Double, v1: Double, v2: Double) -> Surface?
```

- **Parameters:** `semiAngle` — half-angle in radians; `refRadius` — reference radius at the base.
- **OCCT:** `Convert_ConeToBSplineSurface` (via `OCCTConvertConeToBSplineSurface`).

---

### `Surface.fromTorus(origin:axis:majorRadius:minorRadius:)`

Convert a full torus to a BSpline surface.

```swift
public static func fromTorus(origin: SIMD3<Double>, axis: SIMD3<Double>,
                              majorRadius: Double, minorRadius: Double) -> Surface?
```

- **OCCT:** `Convert_TorusToBSplineSurface` (via `OCCTConvertTorusToBSplineSurface`).
- **Example:**
  ```swift
  if let t = Surface.fromTorus(origin: .zero, axis: SIMD3(0, 0, 1),
                                majorRadius: 5.0, minorRadius: 1.5) { }
  ```

---

## math_Householder

Namespace wrapping `math_Householder` — QR decomposition via Householder reflections for overdetermined systems.

### `MathHouseholder.solve(matrix:rows:cols:rhs:)`

Solve `Ax ≈ b` (M ≥ N) using Householder QR.

```swift
public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]?
```

- **Parameters:** `matrix` — row-major M×N matrix; `rows` — M (must be ≥ `cols`); `cols` — N; `rhs` — right-hand side (length M).
- **Returns:** Solution vector of length N, or `nil` on failure or under-determined input.
- **OCCT:** `math_Householder::Solve` (via `OCCTMathHouseholderSolve`).
- **Example:**
  ```swift
  let A = [1.0, 1, 1, 2, 1, 3]  // 3x2
  let b = [6.0, 5.0, 7.0]
  if let x = MathHouseholder.solve(matrix: A, rows: 3, cols: 2, rhs: b) {
      print(x)
  }
  ```

---

## math_Crout

Namespace wrapping `math_Crout` — LDLᵀ Crout decomposition for symmetric positive-definite systems.

### `MathCrout.solve(matrix:rhs:)`

Solve symmetric `Ax = b` using Crout decomposition.

```swift
public static func solve(matrix: [Double], rhs: [Double]) -> [Double]?
```

- **Parameters:** `matrix` — row-major N×N symmetric matrix; `rhs` — right-hand side (length N).
- **Returns:** Solution vector of length N, or `nil` on failure.
- **OCCT:** `math_Crout::Solve` (via `OCCTMathCroutSolve`).
- **Example:**
  ```swift
  let A = [4.0, 2, 2, 3]  // 2x2 SPD
  let b = [8.0, 5.0]
  if let x = MathCrout.solve(matrix: A, rhs: b) {
      print(x)  // [1.8571..., 0.4285...]
  }
  ```

---

### `MathCrout.determinant(matrix:n:)`

Compute the determinant of a symmetric matrix via Crout factorisation.

```swift
public static func determinant(matrix: [Double], n: Int) -> Double
```

- **OCCT:** `math_Crout::Determinant` (via `OCCTMathCroutDeterminant`).

---

## ShapeFix_IntersectionTool

Extension on `Shape` wrapping `ShapeFix_IntersectionTool` — repairs self-intersecting wires on a face.

### `fixIntersectingWires(faceIndex:precision:)`

Fix intersecting wires on a face of this shape.

```swift
@discardableResult
public func fixIntersectingWires(faceIndex: Int, precision: Double = 1e-6) -> Bool
```

- **Parameters:** `faceIndex` — 0-based face index; `precision` — fix tolerance.
- **Returns:** `true` if any fixes were applied.
- **OCCT:** `ShapeFix_IntersectionTool::FixSelfIntersectWire` (via `OCCTShapeFixIntersectingWires`).
- **Example:**
  ```swift
  shape.fixIntersectingWires(faceIndex: 0)
  ```

---

## XCAFDoc_AssemblyItemRef

Extension on `Document` wrapping `XCAFDoc_AssemblyItemRef` — a persistent reference to a specific item (and optionally a subshape) within an assembly hierarchy.

### `setAssemblyItemRef(labelId:itemPath:)`

Attach an assembly item reference attribute to a label.

```swift
@discardableResult
public func setAssemblyItemRef(labelId: Int64, itemPath: String) -> Bool
```

- **Parameters:** `labelId` — target label; `itemPath` — colon-separated label-entry path string.
- **OCCT:** `XCAFDoc_AssemblyItemRef::Set` (via `OCCTDocumentSetAssemblyItemRef`).

---

### `assemblyItemRefPath(labelId:)`

Get the assembly item reference path string.

```swift
public func assemblyItemRefPath(labelId: Int64) -> String?
```

- **Returns:** Path string, or `nil` if no attribute exists.
- **OCCT:** `XCAFDoc_AssemblyItemRef::GetPath` (via `OCCTDocumentGetAssemblyItemRef`).

---

### `assemblyItemRefSetSubshape(labelId:index:)`

Set a subshape index on an assembly item reference.

```swift
@discardableResult
public func assemblyItemRefSetSubshape(labelId: Int64, index: Int32) -> Bool
```

- **OCCT:** `XCAFDoc_AssemblyItemRef::SetSubshapeIndex` (via `OCCTDocumentAssemblyItemRefSetSubshape`).

---

### `assemblyItemRefGetSubshape(labelId:)`

Get the subshape index, if set.

```swift
public func assemblyItemRefGetSubshape(labelId: Int64) -> Int32?
```

- **Returns:** The subshape index, or `nil` if not set (raw value < 0).
- **OCCT:** `XCAFDoc_AssemblyItemRef::GetSubshapeIndex` (via `OCCTDocumentAssemblyItemRefGetSubshape`).

---

### `assemblyItemRefHasExtra(labelId:)`

Check whether the assembly item reference carries an extra attribute reference.

```swift
public func assemblyItemRefHasExtra(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_AssemblyItemRef::HasExtraRef` (via `OCCTDocumentAssemblyItemRefHasExtra`).

---

### `assemblyItemRefClearExtra(labelId:)`

Remove the extra attribute reference from an assembly item ref.

```swift
@discardableResult
public func assemblyItemRefClearExtra(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_AssemblyItemRef::RemoveExtraRef` (via `OCCTDocumentAssemblyItemRefClearExtra`).

---

### `assemblyItemRefIsOrphan(labelId:)`

Whether the assembly item reference points to a label that no longer exists.

```swift
public func assemblyItemRefIsOrphan(labelId: Int64) -> Bool
```

- **OCCT:** `XCAFDoc_AssemblyItemRef::IsOrphan` (via `OCCTDocumentAssemblyItemRefIsOrphan`).

---

## BRepAlgo_Image

Wraps `BRepAlgo_Image` — a bidirectional mapping that tracks how shapes evolve through Boolean or healing operations (shape history).

### `ShapeImage.init()`

Create an empty shape image map.

```swift
public init()
```

- **OCCT:** `BRepAlgo_Image()` (via `OCCTBRepAlgoImageCreate`).

---

### `setRoot(_:)`

Record the root (input) shape of the mapping.

```swift
public func setRoot(_ shape: Shape)
```

- **OCCT:** `BRepAlgo_Image::SetRoot` (via `OCCTBRepAlgoImageSetRoot`).

---

### `bind(old:new:)`

Record that `old` was replaced by `new`.

```swift
public func bind(old: Shape, new: Shape)
```

- **OCCT:** `BRepAlgo_Image::Bind` (via `OCCTBRepAlgoImageBind`).

---

### `hasImage(_:)`

Check if a shape has a recorded replacement image.

```swift
public func hasImage(_ shape: Shape) -> Bool
```

- **OCCT:** `BRepAlgo_Image::HasImage` (via `OCCTBRepAlgoImageHasImage`).

---

### `isImage(_:)`

Check if a shape is itself a recorded image of some root shape.

```swift
public func isImage(_ shape: Shape) -> Bool
```

- **OCCT:** `BRepAlgo_Image::IsImage` (via `OCCTBRepAlgoImageIsImage`).

---

### `clear()`

Clear all recorded mappings.

```swift
public func clear()
```

- **OCCT:** `BRepAlgo_Image::Clear` (via `OCCTBRepAlgoImageClear`).

---

## OSD_Path

Namespace wrapping `OSD_Path` — platform-independent file path parsing.

### `OSDPath.name(_:)`

Extract the filename (without extension) from a path string.

```swift
public static func name(_ path: String) -> String?
```

- **OCCT:** `OSD_Path::Name` (via `OCCTOSDPathName`).
- **Example:**
  ```swift
  OSDPath.name("/tmp/part.stp")  // "part"
  ```

---

### `OSDPath.fileExtension(_:)`

Extract the file extension (with leading dot) from a path string.

```swift
public static func fileExtension(_ path: String) -> String?
```

- **OCCT:** `OSD_Path::Extension` (via `OCCTOSDPathExtension`).
- **Example:**
  ```swift
  OSDPath.fileExtension("/tmp/part.stp")  // ".stp"
  ```

---

### `OSDPath.trek(_:)`

Extract the directory trek portion of a path.

```swift
public static func trek(_ path: String) -> String?
```

- **OCCT:** `OSD_Path::Trek` (via `OCCTOSDPathTrek`).

---

### `OSDPath.systemName(_:)`

Get the system-formatted (OS-native) path string.

```swift
public static func systemName(_ path: String) -> String?
```

- **OCCT:** `OSD_Path::SystemName` (via `OCCTOSDPathSystemName`).

---

### `OSDPath.folderAndFile(_:)`

Split a path into its folder and filename components.

```swift
public static func folderAndFile(_ path: String) -> (folder: String, file: String)?
```

- **Returns:** Tuple of folder and filename strings, or `nil` if splitting fails.
- **OCCT:** `OSD_Path` trek/name split (via `OCCTOSDPathFolderAndFile`).
- **Example:**
  ```swift
  if let (folder, file) = OSDPath.folderAndFile("/tmp/parts/bolt.stp") {
      print(folder, file)
  }
  ```

---

### `OSDPath.isValid(_:)`

Whether the path string is syntactically valid.

```swift
public static func isValid(_ path: String) -> Bool
```

- **OCCT:** `OSD_Path::IsValid` (via `OCCTOSDPathIsValid`).

---

### `OSDPath.isUnixPath(_:)`

Whether the path uses Unix conventions.

```swift
public static func isUnixPath(_ path: String) -> Bool
```

- **OCCT:** `OSD_Path` system type check (via `OCCTOSDPathIsUnixPath`).

---

### `OSDPath.isRelative(_:)`

Whether the path is relative (does not start at the filesystem root).

```swift
public static func isRelative(_ path: String) -> Bool
```

- **OCCT:** `OSD_Path::IsRelative` (via `OCCTOSDPathIsRelative`).

---

### `OSDPath.isAbsolute(_:)`

Whether the path is absolute.

```swift
public static func isAbsolute(_ path: String) -> Bool
```

- **OCCT:** `OSD_Path::IsAbsolute` (via `OCCTOSDPathIsAbsolute`).

---

## BRepClass_FClassifier

Extension on `Shape` providing 2D face-parameter-space classification and loop building.

### `classifyPoint2D(faceIndex:u:v:tolerance:)`

Classify a UV parameter-space point on a face.

```swift
public func classifyPoint2D(faceIndex: Int, u: Double, v: Double, tolerance: Double = 1e-6) -> PointState
```

- **Parameters:** `faceIndex` — 0-based face index; `u`, `v` — UV parameters on the face; `tolerance` — classification tolerance.
- **Returns:** `.inside`, `.outside`, `.on`, or `.unknown` (same `PointState` enum as `classifyPoint`).
- **OCCT:** `BRepClass_FClassifier::Perform` (via `OCCTShapeClassifyPoint2D`).
- **Example:**
  ```swift
  let state = shape.classifyPoint2D(faceIndex: 0, u: 0.5, v: 0.5)
  ```

---

### `buildLoops(faceIndex:)`

Build edge loops (wires) from the free edges on a face.

```swift
public func buildLoops(faceIndex: Int) -> Int
```

- **Parameters:** `faceIndex` — 0-based face index.
- **Returns:** Number of loops built, or -1 on error.
- **OCCT:** `BRepAlgo_Loop` (via `OCCTShapeBuildLoops`).

---

### `faceDomainEdgeCount(faceIndex:)`

Count the boundary edges of a face using `BRepGProp_Domain`.

```swift
public func faceDomainEdgeCount(faceIndex: Int) -> Int
```

- **OCCT:** `BRepGProp_Domain::NbEdges` (via `OCCTShapeFaceDomainEdgeCount`).

---

## Bnd_BoundSortBox

Wraps `Bnd_BoundSortBox` — a spatial index for fast AABB-vs-AABB intersection queries.

### `BoundSortBox.init(boxes:)`

Create a sort box from an array of axis-aligned bounding boxes.

```swift
public init(boxes: [[Double]])
```

- **Parameters:** `boxes` — each element is `[xmin, ymin, zmin, xmax, ymax, zmax]`.
- **OCCT:** `Bnd_BoundSortBox::Initialize` (via `OCCTBoundSortBoxCreate`).
- **Example:**
  ```swift
  let bsb = BoundSortBox(boxes: [
      [0, 0, 0, 1, 1, 1],
      [2, 2, 2, 3, 3, 3],
  ])
  ```

---

### `compare(xmin:ymin:zmin:xmax:ymax:zmax:)`

Find the 0-based indices of stored boxes that intersect a query box.

```swift
public func compare(xmin: Double, ymin: Double, zmin: Double,
                    xmax: Double, ymax: Double, zmax: Double) -> [Int]
```

- **Returns:** Array of 0-based indices into the array supplied at construction.
- **OCCT:** `Bnd_BoundSortBox::Compare` (via `OCCTBoundSortBoxCompare`).
- **Example:**
  ```swift
  let hits = bsb.compare(xmin: 0.5, ymin: 0.5, zmin: 0.5,
                          xmax: 1.5, ymax: 1.5, zmax: 1.5)
  // hits == [0]
  ```

---

## TNaming_Naming

Extension on `Document` wrapping `TNaming_Naming` — persistent topological naming that survives shape modifications.

### `insertNaming(labelId:)`

Insert a `TNaming_Naming` attribute on a label.

```swift
@discardableResult
public func insertNaming(labelId: Int64) -> Bool
```

- **OCCT:** `TNaming_Naming::Insert` (via `OCCTDocumentInsertNaming`).
- **Example:**
  ```swift
  doc.insertNaming(labelId: shapeLabel)
  ```

---

### `namingIsDefined(labelId:)`

Check whether a naming attribute is defined and valid on a label.

```swift
public func namingIsDefined(labelId: Int64) -> Bool
```

- **OCCT:** `TNaming_Naming::IsDefined` (via `OCCTDocumentNamingIsDefined`).

---

## Precision Constants

Namespace exposing OCCT's global precision tolerances from `Precision.hxx`.

### `OCCTPrecision.confusion`

General positional/distance confusion tolerance (1×10⁻⁷ by default).

```swift
public static var confusion: Double { get }
```

- **OCCT:** `Precision::Confusion()` (via `OCCTPrecisionConfusion`).

---

### `OCCTPrecision.angular`

Angular direction comparison tolerance (1×10⁻¹² by default).

```swift
public static var angular: Double { get }
```

- **OCCT:** `Precision::Angular()` (via `OCCTPrecisionAngular`).

---

### `OCCTPrecision.intersection`

Tolerance used by intersection algorithms.

```swift
public static var intersection: Double { get }
```

- **OCCT:** `Precision::Intersection()` (via `OCCTPrecisionIntersection`).

---

### `OCCTPrecision.approximation`

Tolerance used by approximation algorithms.

```swift
public static var approximation: Double { get }
```

- **OCCT:** `Precision::Approximation()` (via `OCCTPrecisionApproximation`).

---

### `OCCTPrecision.infinite`

Sentinel value representing "infinite" (2×10¹⁰⁰).

```swift
public static var infinite: Double { get }
```

- **OCCT:** `Precision::Infinite()` (via `OCCTPrecisionInfinite`).

---

### `OCCTPrecision.pConfusion`

Parametric-space confusion tolerance (scaled by curve-space bounds).

```swift
public static var pConfusion: Double { get }
```

- **OCCT:** `Precision::PConfusion()` (via `OCCTPrecisionPConfusion`).

---

### `OCCTPrecision.isInfinite(_:)`

Test whether a value should be treated as infinite.

```swift
public static func isInfinite(_ value: Double) -> Bool
```

- **OCCT:** `Precision::IsInfinite` (via `OCCTPrecisionIsInfinite`).
- **Example:**
  ```swift
  OCCTPrecision.isInfinite(1e200)  // true
  OCCTPrecision.isInfinite(10.0)   // false
  ```

---

## IntAna Analytic Intersections

Namespace of static methods wrapping OCCT's `IntAna` package — closed-form intersections between lines, planes, spheres, and tori.

### `IntAna.ConicQuadResult`

Result of a line-with-quadric intersection.

```swift
public struct ConicQuadResult {
    public let points: [SIMD3<Double>]
    public let params: [Double]
    public let isParallel: Bool
}
```

- `points` — intersection points in 3D; `params` — corresponding parameters on the line; `isParallel` — the line is parallel to the quadric surface.

---

### `IntAna.linePlane(lineOrigin:lineDir:planeOrigin:planeNormal:)`

Intersect a parametric line with a plane.

```swift
public static func linePlane(lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
                              planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>) -> ConicQuadResult
```

- **Returns:** Up to 1 intersection point; `isParallel` is `true` when the line lies in or is parallel to the plane.
- **OCCT:** `IntAna_IntConicQuad` (via `OCCTIntAnaLineQuad`).
- **Example:**
  ```swift
  let r = IntAna.linePlane(lineOrigin: SIMD3(0, 0, 5), lineDir: SIMD3(0, 0, -1),
                            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1))
  // r.points[0] ≈ (0, 0, 0)
  ```

---

### `IntAna.lineSphere(lineOrigin:lineDir:sphereCenter:sphereAxis:radius:)`

Intersect a parametric line with a sphere.

```swift
public static func lineSphere(lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
                               sphereCenter: SIMD3<Double>, sphereAxis: SIMD3<Double>,
                               radius: Double) -> ConicQuadResult
```

- **Returns:** Up to 2 intersection points.
- **OCCT:** `IntAna_IntConicQuad` with sphere quadric (via `OCCTIntAnaLineSphere`).

---

### `IntAna.QuadQuadResult`

Result of a quadric-quadric intersection.

```swift
public struct QuadQuadResult {
    public let count: Int
    public let lines: [(origin: SIMD3<Double>, direction: SIMD3<Double>)]
    public let points: [SIMD3<Double>]
}
```

---

### `IntAna.planePlane(p1Origin:p1Normal:p2Origin:p2Normal:)`

Intersect two planes — result is typically a line.

```swift
public static func planePlane(p1Origin: SIMD3<Double>, p1Normal: SIMD3<Double>,
                               p2Origin: SIMD3<Double>, p2Normal: SIMD3<Double>) -> QuadQuadResult
```

- **OCCT:** `IntAna_QuadQuadGeo` plane-plane (via `OCCTIntAnaPlanePlane`).
- **Example:**
  ```swift
  let r = IntAna.planePlane(p1Origin: .zero, p1Normal: SIMD3(0, 0, 1),
                             p2Origin: .zero, p2Normal: SIMD3(0, 1, 0))
  // r.lines[0] is the X-axis intersection line
  ```

---

### `IntAna.planeSphere(planeOrigin:planeNormal:sphereCenter:sphereAxis:radius:)`

Intersect a plane with a sphere — result is typically a circle.

```swift
public static func planeSphere(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
                                sphereCenter: SIMD3<Double>, sphereAxis: SIMD3<Double>,
                                radius: Double) -> QuadQuadResult
```

- **OCCT:** `IntAna_QuadQuadGeo` plane-sphere (via `OCCTIntAnaPlaneSphere`).

---

### `IntAna.threePlanes(p1Origin:p1Normal:p2Origin:p2Normal:p3Origin:p3Normal:)`

Compute the unique intersection point of three planes.

```swift
public static func threePlanes(p1Origin: SIMD3<Double>, p1Normal: SIMD3<Double>,
                                p2Origin: SIMD3<Double>, p2Normal: SIMD3<Double>,
                                p3Origin: SIMD3<Double>, p3Normal: SIMD3<Double>) -> SIMD3<Double>?
```

- **Returns:** The point, or `nil` if the planes are not in general position.
- **OCCT:** `IntAna_Int3Pln` (via `OCCTIntAna3Planes`).

---

### `IntAna.lineTorus(lineOrigin:lineDir:torusCenter:torusAxis:majorRadius:minorRadius:)`

Intersect a parametric line with a torus (up to 4 points).

```swift
public static func lineTorus(lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
                              torusCenter: SIMD3<Double>, torusAxis: SIMD3<Double>,
                              majorRadius: Double, minorRadius: Double) -> [SIMD3<Double>]
```

- **Returns:** Array of 0–4 intersection points.
- **OCCT:** `IntAna_IntLinTorus` (via `OCCTIntAnaLineTorus`).

---

## OSD_Chronometer

Namespace wrapping `OSD_Chronometer` — per-process and per-thread CPU time measurement.

### `CPUTime.processCPU()`

Get total process CPU time split into user and system seconds.

```swift
public static func processCPU() -> (user: Double, system: Double)
```

- **OCCT:** `OSD_Chronometer::GetProcessCPU` (via `OCCTGetProcessCPU`).
- **Example:**
  ```swift
  let (user, sys) = CPUTime.processCPU()
  ```

---

### `CPUTime.threadCPU()`

Get current thread CPU time split into user and system seconds.

```swift
public static func threadCPU() -> (user: Double, system: Double)
```

- **OCCT:** `OSD_Chronometer::GetThreadCPU` (via `OCCTGetThreadCPU`).

---

## OSD_Process

Namespace wrapping `OSD_Process` — process identification and path utilities.

### `ProcessInfo.processId`

Current process identifier.

```swift
public static var processId: Int { get }
```

- **OCCT:** `OSD_Process::ProcessId` (via `OCCTProcessId`).

---

### `ProcessInfo.userName`

Login name of the process owner.

```swift
public static var userName: String? { get }
```

- **OCCT:** `OSD_Process::UserName` (via `OCCTProcessUserName`).

---

### `ProcessInfo.executablePath`

Full path to the running executable.

```swift
public static var executablePath: String? { get }
```

- **OCCT:** `OSD_Process::ExecutablePath` (via `OCCTProcessExecutablePath`).

---

### `ProcessInfo.executableFolder`

Folder containing the running executable.

```swift
public static var executableFolder: String? { get }
```

- **OCCT:** `OSD_Process::ExecutableFolder` (via `OCCTProcessExecutableFolder`).

---

## Draft_Modification

Extension on `Shape` wrapping `Draft_Modification` — applies a draft angle to a face, tapering it toward a neutral plane.

### `draftModification(faceIndex:direction:angle:neutralPlaneOrigin:neutralPlaneNormal:)`

Apply a draft angle modification to a face of this shape.

```swift
public func draftModification(faceIndex: Int, direction: SIMD3<Double>, angle: Double,
                               neutralPlaneOrigin: SIMD3<Double>,
                               neutralPlaneNormal: SIMD3<Double>) -> Shape?
```

- **Parameters:** `faceIndex` — 0-based index of the face to draft; `direction` — pull direction for demoulding; `angle` — draft angle in radians; `neutralPlaneOrigin` / `neutralPlaneNormal` — the plane that stays fixed during drafting.
- **Returns:** The modified shape, or `nil` on failure (incompatible geometry).
- **OCCT:** `Draft_Modification::Add / Perform` (via `OCCTShapeDraftModification`).
- **Example:**
  ```swift
  if let drafted = shape.draftModification(faceIndex: 0,
                                            direction: SIMD3(0, 0, 1),
                                            angle: 0.05,
                                            neutralPlaneOrigin: .zero,
                                            neutralPlaneNormal: SIMD3(0, 0, 1)) {
      // drafted face tapers at 0.05 rad ≈ 2.86°
  }
  ```

---

## Convert_CompBezierCurvesToBSplineCurve

Structures and namespace for converting multi-segment Bezier curves to a single BSpline curve.

### `BezierToBSplineResult`

Result of a 3D composite Bezier → BSpline conversion.

```swift
public struct BezierToBSplineResult {
    public let degree: Int
    public let poles: [SIMD3<Double>]
    public let knots: [Double]
    public let multiplicities: [Int]
}
```

---

### `BezierToBSpline2dResult`

Result of a 2D composite Bezier → BSpline conversion.

```swift
public struct BezierToBSpline2dResult {
    public let degree: Int
    public let poles: [SIMD2<Double>]
    public let knots: [Double]
    public let multiplicities: [Int]
}
```

---

### `CompBezierConverter.toBSpline(segments:)`

Convert a sequence of connected 3D Bezier segments to a single BSpline curve.

```swift
public static func toBSpline(segments: [[SIMD3<Double>]]) -> BezierToBSplineResult?
```

- **Parameters:** `segments` — each element is the ordered control points of one Bezier segment; all segments must have the same number of control points.
- **Returns:** The merged BSpline data, or `nil` on failure.
- **OCCT:** `Convert_CompBezierCurvesToBSplineCurve` (via `OCCTConvertCompBezierToBSpline`).
- **Example:**
  ```swift
  let seg1: [SIMD3<Double>] = [SIMD3(0,0,0), SIMD3(1,1,0), SIMD3(2,0,0)]
  let seg2: [SIMD3<Double>] = [SIMD3(2,0,0), SIMD3(3,-1,0), SIMD3(4,0,0)]
  if let result = CompBezierConverter.toBSpline(segments: [seg1, seg2]) {
      print("degree:", result.degree, "poles:", result.poles.count)
  }
  ```

---

### `CompBezierConverter.toBSpline2d(segments:)`

Convert a sequence of connected 2D Bezier segments to a single BSpline curve.

```swift
public static func toBSpline2d(segments: [[SIMD2<Double>]]) -> BezierToBSpline2dResult?
```

- **Parameters:** `segments` — each element is the ordered 2D control points of one Bezier segment; all segments must have the same number of control points.
- **Returns:** The merged 2D BSpline data, or `nil` on failure.
- **OCCT:** `Convert_CompPolynomialToPoles` / `Convert_CompBezierCurves2dToBSplineCurve2d` (via `OCCTConvertCompBezier2dToBSpline2d`).

---

## Geom_OffsetSurface Extensions

Extensions on `Surface` for querying and modifying offset surface parameters.

### `offsetValue`

The offset distance of this surface (only meaningful for offset surfaces).

```swift
public var offsetValue: Double { get }
```

- **Returns:** Offset distance; returns 0 for non-offset surfaces.
- **OCCT:** `Geom_OffsetSurface::Offset` (via `OCCTSurfaceOffsetValue`).
- **Example:**
  ```swift
  if surface.isOffsetSurface {
      print("offset:", surface.offsetValue)
  }
  ```

---

### `setOffsetValue(_:)`

Change the offset distance of an offset surface.

```swift
public func setOffsetValue(_ value: Double)
```

- **Note:** No-op on non-offset surfaces.
- **OCCT:** `Geom_OffsetSurface::SetOffsetValue` (via `OCCTSurfaceSetOffsetValue`).
- **Example:**
  ```swift
  surface.setOffsetValue(2.0)
  ```

---

### `offsetBasis`

The underlying basis surface of an offset surface.

```swift
public var offsetBasis: Surface? { get }
```

- **Returns:** The basis `Surface`, or `nil` if this surface is not an offset surface.
- **OCCT:** `Geom_OffsetSurface::BasisSurface` (via `OCCTSurfaceOffsetBasis`).
- **Example:**
  ```swift
  if let basis = surface.offsetBasis {
      print("basis kind:", basis.surfaceKind)
  }
  ```
