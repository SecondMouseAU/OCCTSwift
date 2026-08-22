import Foundation
import OCCTBridge
import simd

extension Shape {

    /// Get full mass properties of the shape.
    ///
    /// These are *volume* mass properties (`BRepGProp::VolumeProperties`), so the shape must
    /// enclose a volume: a solid, or a closed shell. A face, wire, edge, vertex or **open shell**
    /// has no mass, no centre of mass and no inertia tensor, and this returns nil rather than an
    /// answer derived from nothing. To measure an open shell, close it first (for example with
    /// ``sew(shapes:tolerance:)``); which closure you want is your choice to make, not one this
    /// method should guess. Use ``surfaceArea`` or ``surfaceInertia`` for an area measure and
    /// ``linearProperties()`` for a length measure.
    ///
    /// ```swift
    /// let cone = Shape.cone(bottomRadius: 10, topRadius: 0, height: 20)!
    /// if let p = cone.properties(density: 2.7) {
    ///     print(p.volume)        // 2094.395
    ///     print(p.mass)          // 5654.867  (volume x density)
    ///     print(p.centerOfMass)  // (0, 0, 5)  a cone's centroid sits at h/4, not h/2
    /// }
    ///
    /// let face = Shape.fromFace(cone.faces()[0])!
    /// face.properties()          // nil: a face encloses no volume
    /// ```
    ///
    /// - Parameter density: Material density for mass calculation (default 1.0)
    /// - Returns: Properties including volume, surface area, center of mass, and inertia tensor,
    ///            or nil if the shape encloses no volume or the calculation fails.
    public func properties(density: Double = 1.0) -> ShapeProperties? {
        let result = OCCTShapeGetProperties(handle, density)
        guard result.isValid else { return nil }

        let inertia = simd_double3x3(
            SIMD3<Double>(result.ixx, result.iyx, result.izx),
            SIMD3<Double>(result.ixy, result.iyy, result.izy),
            SIMD3<Double>(result.ixz, result.iyz, result.izz)
        )

        return ShapeProperties(
            volume: result.volume,
            surfaceArea: result.surfaceArea,
            mass: result.mass,
            centerOfMass: SIMD3<Double>(result.centerX, result.centerY, result.centerZ),
            momentOfInertia: inertia
        )
    }

    /// Volume of the shape in cubic units, or nil when the shape encloses no volume.
    ///
    /// Only a closed shell has a volume. A face, wire, edge, vertex or **open shell** returns nil
    /// rather than the number `BRepGProp`'s divergence integral produces over a surface that
    /// encloses nothing (measured: 4800 for five faces of a 10x20x30 box, whose real volume is
    /// 6000). A reversed solid returns nil too; ask ``signedVolume`` for that case.
    ///
    /// Closedness is topological, so geometry that merely looks watertight is not enough. Six
    /// coincident faces assembled without sewing have no volume; sew them first.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// box.volume                                       // 6000
    /// Shape.fromFace(box.faces()[0])?.volume           // nil, a face encloses nothing
    ///
    /// let loose = box.faces().compactMap { Shape.fromFace($0) }
    /// Shape.compound(loose)?.volume                    // nil, unsewn faces are not a closed shell
    /// Shape.sew(shapes: loose)?.volume                 // 6000, once the faces share their edges
    /// ```
    public var volume: Double? {
        var v = 0.0
        guard OCCTShapeGetVolume(handle, &v), v >= 0 else { return nil }
        return v
    }

    /// Signed volume of the shape in cubic units.
    ///
    /// Unlike ``volume``, this preserves the sign that `BRepGProp` reports: a
    /// reversed-orientation solid (faces pointing inward) returns a **negative**
    /// value. Use this to detect orientation problems; use ``orientedForward()``
    /// to fix them.
    ///
    /// **This is an orientation signal, not a measurement.** It is the divergence integral over the
    /// shape's faces, so its magnitude is a volume only when the surface is closed. An open shell
    /// gets a number here where ``volume`` correctly returns nil, and that number is not a volume.
    /// Use ``volume`` to measure; use this to ask which way the faces point.
    ///
    /// The sign is sound for any orientable surface, closed or not, because reversing a surface
    /// negates the flux. That is why ``sweep(profile:along:)`` can still normalise a pipe whose
    /// faces point inward even though the pipe it builds is an open shell (#170, #609).
    ///
    /// Returns `0` on an internal error. It used to return `-1` there, which ``orientedForward()``
    /// read as "reverse me".
    ///
    /// ```swift
    /// let solid = Shape.box(width: 10, height: 10, depth: 10)!
    /// solid.signedVolume            //  1000, and here it IS the volume
    /// solid.reversed?.signedVolume  // -1000
    ///
    /// // Five of the six faces, sewn: closed everywhere except one opening.
    /// let open = Shape.sew(shapes: solid.faces().dropLast().compactMap { Shape.fromFace($0) })!
    /// open.signedVolume             //  a signed number that is not a volume
    /// open.volume                   //  nil, which is the measurement answer
    /// ```
    public var signedVolume: Double {
        var v = 0.0
        guard OCCTShapeSignedVolumeFlux(handle, &v) else { return 0 }
        return v
    }

    /// Surface area of the shape in square units.
    ///
    /// One `BRepGProp::SurfaceProperties` integration over the whole shape at once, the same
    /// call ``surfaceInertiaProperties()`` `.mass` and ``surfaceInertia`` `.area` share, so all
    /// three agree with each other exactly. Unlike ``ShapeMeasurements/totalFaceArea`` (N
    /// separately-toleranced per-face integrals, summed) this one takes no tolerance parameter:
    /// see ``Shape/measure(linearTolerance:)`` for the measured gap between the two and which to
    /// reach for (#885). This is the canonical explanation of that divergence; the other
    /// area-measure properties below point back here instead of restating it.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// box.surfaceArea                        // 2200, one whole-shape integral
    /// box.surfaceInertiaProperties()?.mass   // 2200, the identical call in disguise
    /// box.surfaceInertia?.area               // 2200, likewise
    /// box.measure().totalFaceArea            // a *different*, tolerance-controlled sum,
    ///                                         // usually agrees closely, not guaranteed to (#885)
    /// ```
    public var surfaceArea: Double? {
        let a = OCCTShapeGetSurfaceArea(handle)
        return a >= 0 ? a : nil
    }

    /// Centre of mass of the volume this shape encloses.
    ///
    /// This is `BRepGProp::VolumeProperties`, so it is a *volume* measure and it is not the centre
    /// of the bounding box: a cone's centre of mass sits at a quarter of its height, and a shape
    /// built from parts of unequal size sits near the heavy one. It is nil for anything that
    /// encloses no volume, which is a face, wire, edge, vertex or **open shell**. Close an open
    /// shell first if you need a figure for it; picking a closure is your decision.
    ///
    /// For the other two measures OCCT offers, use ``surfaceInertia`` (area) or
    /// ``linearProperties()`` (length). For a vertex's position use ``vertices()``.
    ///
    /// ```swift
    /// let big = Shape.box(width: 10, height: 10, depth: 10)!
    /// let small = Shape.box(width: 2, height: 2, depth: 2)!.translated(by: SIMD3(20, 0, 0))!
    /// let part = big.union(small)!
    ///
    /// part.centerOfMass       // (0.1587, 0, 0)   the small cube barely shifts it
    /// part.boundingBox!.min   // x = -5, max x = 21, so the box centre would be 8: not this
    ///
    /// Shape.fromFace(part.faces()[0])!.centerOfMass   // nil: a face encloses no volume
    /// ```
    public var centerOfMass: SIMD3<Double>? {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        guard OCCTShapeGetCenterOfMass(handle, &x, &y, &z) else { return nil }
        return SIMD3<Double>(x, y, z)
    }

    /// Compute minimum distance between this shape and another.
    ///
    /// - Parameters:
    ///   - other: The other shape to measure distance to
    ///   - deflection: Tolerance for curved geometry (default 1e-6)
    /// - Returns: Distance result with closest points, or nil if calculation fails
    public func distance(to other: Shape, deflection: Double = 1e-6) -> DistanceResult? {
        let result = OCCTShapeDistance(handle, other.handle, deflection)
        guard result.isValid else { return nil }

        return DistanceResult(
            distance: result.distance,
            pointOnShape1: SIMD3<Double>(result.p1x, result.p1y, result.p1z),
            pointOnShape2: SIMD3<Double>(result.p2x, result.p2y, result.p2z),
            solutionCount: Int(result.solutionCount)
        )
    }

    /// Get minimum distance between this shape and another.
    ///
    /// - Parameter other: The other shape
    /// - Returns: Minimum distance, or nil if calculation fails
    public func minDistance(to other: Shape) -> Double? {
        distance(to: other)?.distance
    }

    /// Check if this shape intersects (overlaps or touches) another shape.
    ///
    /// - Parameters:
    ///   - other: The other shape to test
    ///   - tolerance: Distance threshold for intersection (default 1e-6)
    /// - Returns: true if shapes intersect or touch within tolerance
    public func intersects(_ other: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTShapeIntersects(handle, other.handle, tolerance)
    }

    // MARK: - Wire/Edge/Face Convenience Overloads

    /// Get minimum distance between this shape and a wire.
    public func distance(to wire: Wire, deflection: Double = 1e-6) -> DistanceResult? {
        guard let s = Shape.fromWire(wire) else { return nil }
        return distance(to: s, deflection: deflection)
    }

    /// Get minimum distance between this shape and an edge.
    public func distance(to edge: Edge, deflection: Double = 1e-6) -> DistanceResult? {
        guard let s = Shape.fromEdge(edge) else { return nil }
        return distance(to: s, deflection: deflection)
    }

    /// Get minimum distance between this shape and a face.
    public func distance(to face: Face, deflection: Double = 1e-6) -> DistanceResult? {
        guard let s = Shape.fromFace(face) else { return nil }
        return distance(to: s, deflection: deflection)
    }

    /// Check if this shape intersects a wire.
    public func intersects(_ wire: Wire, tolerance: Double = 1e-6) -> Bool {
        guard let s = Shape.fromWire(wire) else { return false }
        return intersects(s, tolerance: tolerance)
    }

    /// Check if this shape intersects an edge.
    public func intersects(_ edge: Edge, tolerance: Double = 1e-6) -> Bool {
        guard let s = Shape.fromEdge(edge) else { return false }
        return intersects(s, tolerance: tolerance)
    }

    /// Check if this shape intersects a face.
    public func intersects(_ face: Face, tolerance: Double = 1e-6) -> Bool {
        guard let s = Shape.fromFace(face) else { return false }
        return intersects(s, tolerance: tolerance)
    }

    // MARK: - Shape Analysis (v0.13.0)

    /// Analyze a shape for problems such as small edges, gaps, and invalid topology.
    ///
    /// - Note: This never reports self-intersection unless asked to (the `selfIntersectionCount`
    ///   field that used to sit here was always 0, never computed, and was removed in #763).
    ///   `freeEdgeCount`/`freeFaceCount` were also hardcoded to 0 for every shape before #702; a
    ///   demoted or otherwise open shell now reports its actual gap correctly. A "clean" result
    ///   here has never meant "this is a solid": check `shapeType` or ``isValidSolid`` for that.
    ///
    /// - Important: Passing `selfIntersectionTimeout` makes this call **synchronously block the
    ///   calling thread** for up to that many seconds (more, if OCCT never reaches a checkpoint to
    ///   poll: see ``isSelfIntersecting(timeout:)``'s own `- Important` note, which this inherits
    ///   unchanged). Do not pass it from a UI/main thread without accepting that stall; the
    ///   `tolerance`-only call has no such risk.
    ///
    /// - Parameters:
    ///   - tolerance: Size threshold for detecting small features.
    ///   - selfIntersectionTimeout: `nil` (the default) skips the self-intersection check
    ///     entirely and leaves ``ShapeAnalysisResult/hasSelfIntersection`` `nil`. A non-`nil`
    ///     value opts in, forwarded as the `timeout:` to ``isSelfIntersecting(timeout:)`` (the
    ///     cooperative-timeout check, not the ``isSelfIntersecting(hardTimeout:)`` background-
    ///     thread variant: see "Why `timeout:`, not `hardTimeout:`" below). There is no way to
    ///     supply a timeout that does not enable the check: the two used to be separate
    ///     parameters (`checkSelfIntersection: Bool`, `hardTimeout: Double`) until review found
    ///     that shape silently discarded a caller's `hardTimeout` whenever they forgot
    ///     `checkSelfIntersection: true`, compiling and running with no signal at all (#772).
    ///     Collapsing them into one optional makes that mistake unrepresentable.
    ///
    ///     This check is orders of magnitude more expensive than the rest of this scan, and on
    ///     pathological input the gap is not small: measured on the #319 artifact, ~3000x-4000x
    ///     the cost of the rest of the scan combined (a few ms vs 30s at a 30s timeout). On
    ///     ordinary shapes, including a real 662-face mesh-sewn import, the measured overhead was
    ///     1x-3x, cheap enough to opt into whenever a caller actually wants the answer. See
    ///     `Scripts/repro/772-analyze-self-intersection/` for the full measurement across a
    ///     spread of shapes, from a primitive to that pathological artifact (#772).
    /// - Returns: Analysis result with problem counts, or nil on failure.
    ///
    /// ### Why `timeout:`, not `hardTimeout:`
    ///
    /// `isSelfIntersecting(hardTimeout:)` looks like the safer choice (a true wall-clock
    /// guarantee), but measuring both on every fixture, not just the pathological one, found it
    /// is not a strict improvement here: its `deepCopy()` step is cheap (under 1ms on every
    /// fixture measured, including the 662-face import), but its internal
    /// `OCCTShapeSelfIntersectsBounded` call passes **0 (unbounded)**, so the only bound left is
    /// a `DispatchSemaphore.wait` racing a computation with no cooperative deadline of its own.
    /// `analyze()` is already a fully synchronous call with no async variant, so a caller here has
    /// already committed to blocking, and `hardTimeout:`'s wall-clock guarantee buys nothing over
    /// `timeout:` in that context while leaving an abandoned, still-unbounded background
    /// computation running afterwards (``isSelfIntersecting(hardTimeout:)``'s own documented
    /// trade). A caller that genuinely needs the hard guarantee (e.g. no process/subprocess
    /// isolation available) should call ``isSelfIntersecting(hardTimeout:)`` directly and accept
    /// its documented trade-offs; `analyze()` does not make that call for you.
    ///
    /// **#772's fourth argument for `timeout:` is withdrawn (#1054).** It was that on the #319
    /// pathological artifact `timeout:` returned a conclusive "self-intersects" at ~30.1s where
    /// `hardTimeout:` returned `nil`, so the same budget bought a real answer through one
    /// mechanism and a shrug through the other. That "conclusive" answer was
    /// `BOPAlgo_OperationAborted`, the fault OCCT records when the watchdog stops the analysis,
    /// which `HasFaulty()` could not tell from a self-interference; #772 was reading the defect
    /// #1054 fixed. On that artifact both mechanisms now answer `nil` at a 30s bound, which is
    /// the correct answer for an analysis that did not finish. The choice of `timeout:` stands on
    /// the reasons above, which were never about the artifact.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let shape = Shape.load(from: stepURL)!
    /// if let analysis = shape.analyze(tolerance: 0.001) {
    ///     print("Found \(analysis.totalProblems) problems")   // self-intersection not included
    ///     if analysis.hasInvalidTopology {
    ///         print("Shape has invalid topology!")
    ///     }
    /// }
    ///
    /// // Opt into the expensive, thread-blocking check when it's actually needed:
    /// if let analysis = shape.analyze(tolerance: 0.001, selfIntersectionTimeout: 30) {
    ///     switch analysis.hasSelfIntersection {
    ///     case .some(true):  print("self-intersects")
    ///     case .some(false): print("clean")
    ///     case nil:          print("indeterminate: not resolved, never \"clean\"")
    ///     }
    /// }
    /// ```
    public func analyze(tolerance: Double = 1e-6, selfIntersectionTimeout: Double? = nil)
        -> ShapeAnalysisResult?
    {
        let result = OCCTShapeAnalyze(handle, tolerance)
        guard result.isValid else { return nil }

        let hasSelfIntersection: Bool? = selfIntersectionTimeout.flatMap {
            isSelfIntersecting(timeout: $0)
        }

        return ShapeAnalysisResult(
            smallEdgeCount: Int(result.smallEdgeCount),
            smallFaceCount: Int(result.smallFaceCount),
            gapCount: Int(result.gapCount),
            hasSelfIntersection: hasSelfIntersection,
            freeEdgeCount: Int(result.freeEdgeCount),
            freeFaceCount: Int(result.freeFaceCount),
            hasInvalidTopology: result.hasInvalidTopology
        )
    }

    /// Classify a point relative to this solid.
    ///
    /// Determines whether a 3D point is inside, outside, or on the boundary of
    /// this shape. The shape should be a solid for reliable results.
    ///
    /// - Note: ``Shape/classifyPoint(_:tolerance:)`` (`Shape+Topology.swift`) answers the
    ///   identical question via the same `BRepClass3d_SolidClassifier` mechanism (#851), returning
    ///   ``Shape/PointState`` instead of ``PointClassification``. See that method's doc comment
    ///   for why the two result enums are kept separate rather than unified into one.
    ///
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointInSolid(handle, point.x, point.y, point.z, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }
    /// Create a solid volume from a set of overlapping faces/shells.
    ///
    /// Useful for closing open geometry or creating solids from imported face soups.
    ///
    /// - Parameter shapes: Array of face/shell shapes
    /// - Returns: A solid shape, or nil on failure
    public static func makeVolume(from shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeMakeVolume(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
    /// Recognize canonical geometric forms in this shape.
    ///
    /// Identifies whether the shape's geometry matches a canonical
    /// form (plane, cylinder, cone, sphere, line, circle, ellipse).
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The recognized form, or nil if no canonical form found
    public func recognizeCanonical(tolerance: Double = 1e-4) -> CanonicalForm? {
        let r = OCCTShapeRecognizeCanonical(handle, tolerance)
        guard let formType = CanonicalForm.FormType(rawValue: r.type), formType != .unknown else {
            return nil
        }
        return CanonicalForm(
            type: formType,
            origin: SIMD3(r.origin.0, r.origin.1, r.origin.2),
            direction: SIMD3(r.direction.0, r.direction.1, r.direction.2),
            radius: r.radius, radius2: r.radius2, gap: r.gap
        )
    }
    /// Compute an oriented (tight-fit, rotated) bounding box.
    ///
    /// - Parameter optimal: If true, compute a tighter OBB (slower). Default is false.
    /// - Returns: The oriented bounding box, or nil on failure.
    public func orientedBoundingBox(optimal: Bool = false) -> OrientedBoundingBox? {
        var result = OCCTOrientedBoundingBox()
        guard OCCTShapeOrientedBoundingBox(handle, optimal, &result) else { return nil }
        return OrientedBoundingBox(
            center: SIMD3(result.centerX, result.centerY, result.centerZ),
            xDirection: SIMD3(result.xDirX, result.xDirY, result.xDirZ),
            yDirection: SIMD3(result.yDirX, result.yDirY, result.yDirZ),
            zDirection: SIMD3(result.zDirX, result.zDirY, result.zDirZ),
            halfSizes: SIMD3(result.halfX, result.halfY, result.halfZ)
        )
    }

    /// Get the 8 corners of the oriented bounding box.
    ///
    /// - Parameter optimal: If true, compute a tighter OBB. Default is false.
    /// - Returns: Array of 8 corner points, or nil on failure.
    public func orientedBoundingBoxCorners(optimal: Bool = false) -> [SIMD3<Double>]? {
        var obb = OCCTOrientedBoundingBox()
        guard OCCTShapeOrientedBoundingBox(handle, optimal, &obb) else { return nil }
        var corners = [Double](repeating: 0, count: 24)
        OCCTOrientedBoundingBoxCorners(&obb, &corners)
        var result = [SIMD3<Double>]()
        result.reserveCapacity(8)
        for i in stride(from: 0, to: 24, by: 3) {
            result.append(SIMD3(corners[i], corners[i + 1], corners[i + 2]))
        }
        return result
    }

    // MARK: - Inertia Properties (v0.40.0)

    /// Volume-based inertia properties (volume, center of mass, inertia tensor, principal moments).
    public struct InertiaProperties {
        /// Volume (for volume properties) or surface area (for surface properties).
        public let mass: Double
        /// Center of mass.
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia matrix (row-major: [Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz]).
        public let inertiaMatrix: [Double]
        /// Principal moments of inertia (Ix, Iy, Iz).
        public let principalMoments: SIMD3<Double>
        /// Principal axes of inertia (three unit vectors).
        public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        /// Whether the shape has a symmetry axis.
        public let hasSymmetryAxis: Bool
        /// Whether the shape has a symmetry point.
        public let hasSymmetryPoint: Bool
    }

    /// Compute volume-based inertia properties.
    ///
    /// Returns volume, center of mass, 3x3 inertia tensor, principal moments,
    /// and principal axes of inertia.
    ///
    /// Nil for any shape with no closed volume: a face, wire, edge, vertex or open shell. Every
    /// field of the result is meaningless there, not merely zero. The centre of mass is the
    /// shape's location origin, the principal axes are the identity basis that `math_Jacobi`
    /// returns for a zero matrix, and both symmetry flags read true (#609). Use
    /// ``surfaceInertiaProperties()`` for an area-based answer on a sheet body.
    ///
    /// ```swift
    /// let cone = Shape.cone(bottomRadius: 10, topRadius: 0, height: 20)!
    /// if let i = cone.inertiaProperties() {
    ///     i.mass                // 2094.4, the volume
    ///     i.centerOfMass        // (0, 0, 5), a quarter of the way up from the base
    ///     i.hasSymmetryAxis     // true
    /// }
    /// Shape.fromFace(cone.faces()[0])?.inertiaProperties()   // nil
    /// ```
    /// - Returns: Inertia properties, or nil when the shape has no volume or computation fails
    public func inertiaProperties() -> InertiaProperties? {
        var props = OCCTInertiaProperties()
        guard OCCTShapeInertiaProperties(handle, &props) else { return nil }
        let mat = withUnsafeBytes(of: &props.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }
        return InertiaProperties(
            mass: props.volume,
            centerOfMass: SIMD3(props.centerX, props.centerY, props.centerZ),
            inertiaMatrix: mat,
            principalMoments: SIMD3(props.principalIx, props.principalIy, props.principalIz),
            principalAxes: (
                SIMD3(props.principalAxes.0, props.principalAxes.1, props.principalAxes.2),
                SIMD3(props.principalAxes.3, props.principalAxes.4, props.principalAxes.5),
                SIMD3(props.principalAxes.6, props.principalAxes.7, props.principalAxes.8)
            ),
            hasSymmetryAxis: props.hasSymmetryAxis,
            hasSymmetryPoint: props.hasSymmetryPoint
        )
    }

    /// Compute surface-area-based inertia properties.
    ///
    /// Similar to `inertiaProperties()` but uses surface area instead of volume.
    /// The `mass` field contains surface area.
    ///
    /// Unlike the volume sibling this works for a face or an open shell, since an area integral is
    /// well defined over any set of faces. It is nil for a shape with no faces at all (a wire,
    /// edge or vertex), where the reported centroid would be the shape's location origin (#609).
    ///
    /// `.mass` here is ``Shape/surfaceArea`` in disguise, the identical call, down to the same
    /// #885 divergence from ``ShapeMeasurements/totalFaceArea``; see ``Shape/surfaceArea`` for the
    /// explanation.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// let sheet = Shape.fromFace(box.faces()[0])!
    /// sheet.surfaceInertiaProperties()?.mass   // 600, the face area
    /// sheet.inertiaProperties()                // nil, a face has no volume
    ///
    /// let edge = Shape.fromEdge(box.edges()[0])!
    /// edge.surfaceInertiaProperties()          // nil, no faces
    /// ```
    /// - Returns: Inertia properties, or nil when the shape has no area or computation fails
    public func surfaceInertiaProperties() -> InertiaProperties? {
        var props = OCCTInertiaProperties()
        guard OCCTShapeSurfaceInertiaProperties(handle, &props) else { return nil }
        let mat = withUnsafeBytes(of: &props.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }
        return InertiaProperties(
            mass: props.volume,
            centerOfMass: SIMD3(props.centerX, props.centerY, props.centerZ),
            inertiaMatrix: mat,
            principalMoments: SIMD3(props.principalIx, props.principalIy, props.principalIz),
            principalAxes: (
                SIMD3(props.principalAxes.0, props.principalAxes.1, props.principalAxes.2),
                SIMD3(props.principalAxes.3, props.principalAxes.4, props.principalAxes.5),
                SIMD3(props.principalAxes.6, props.principalAxes.7, props.principalAxes.8)
            ),
            hasSymmetryAxis: props.hasSymmetryAxis,
            hasSymmetryPoint: props.hasSymmetryPoint
        )
    }

    // MARK: - Extended Distance (v0.40.0)

    /// A distance solution between two shapes.
    public struct DistanceSolution {
        /// Closest point on the first shape.
        public let point1: SIMD3<Double>
        /// Closest point on the second shape.
        public let point2: SIMD3<Double>
        /// Distance between the two points.
        public let distance: Double
    }

    /// Compute all distance solutions between this shape and another.
    ///
    /// Returns all extremal point pairs, not just the minimum distance.
    /// Useful for finding multiple closest/farthest point pairs.
    /// - Parameters:
    ///   - other: The other shape
    ///   - maxSolutions: Output *capacity* (default 32), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns an empty array (**not** `nil`, as
    ///     it did before #622, the bridge answers -1 for a non-positive capacity and that was
    ///     being reported as a failed measurement rather than as no room offered).
    /// - Returns: Array of distance solutions, or `nil` on failure. No capacity is not a
    ///   failure: it returns `[]`.
    public func allDistanceSolutions(to other: Shape, maxSolutions: Int = 32) -> [DistanceSolution]?
    {
        let maxSolutions = Sampling.capacity(maxSolutions)
        guard maxSolutions > 0 else { return [] }
        var buffer = [OCCTDistanceSolution](repeating: OCCTDistanceSolution(), count: maxSolutions)
        let count = OCCTShapeAllDistanceSolutions(
            handle, other.handle, &buffer, Int32(maxSolutions))
        guard count >= 0 else { return nil }
        return (0..<min(Int(count), maxSolutions)).map { i in
            DistanceSolution(
                point1: SIMD3(buffer[i].point1X, buffer[i].point1Y, buffer[i].point1Z),
                point2: SIMD3(buffer[i].point2X, buffer[i].point2Y, buffer[i].point2Z),
                distance: buffer[i].distance
            )
        }
    }

    /// Check if this shape is fully contained inside another shape.
    ///
    /// Uses BRepExtrema_DistShapeShape inner solution detection.
    /// - Parameter container: The potential container shape
    /// - Returns: true if this shape is inside the container, nil on failure
    public func isInside(_ container: Shape) -> Bool? {
        let result = OCCTShapeIsInnerDistance(handle, container.handle)
        guard result >= 0 else { return nil }
        return result == 1
    }

    /// Support type for a distance solution point.
    public enum DistanceSupportType: Int32, Sendable {
        case vertex = 0
        case onEdge = 1
        case inFace = 2
    }

    /// Detailed parametric info for a distance solution.
    public struct DistanceSolutionDetail: Sendable {
        public let supportType1: DistanceSupportType
        public let supportType2: DistanceSupportType
        public let paramEdge1: Double
        public let paramEdge2: Double
        public let paramFaceUV1: (u: Double, v: Double)
        public let paramFaceUV2: (u: Double, v: Double)
    }

    /// Get detailed parametric info for a specific distance solution.
    ///
    /// Returns the support type (vertex/edge/face) and parametric location
    /// for each closest point. Use with `allDistanceSolutions(to:)` to get
    /// the solution index.
    public func distanceSolutionDetail(to other: Shape, solutionIndex: Int)
        -> DistanceSolutionDetail?
    {
        var detail = OCCTDistanceSolutionDetail()
        guard OCCTShapeDistanceSolutionDetail(handle, other.handle, Int32(solutionIndex), &detail)
        else { return nil }
        return DistanceSolutionDetail(
            supportType1: DistanceSupportType(rawValue: detail.supportType1) ?? .vertex,
            supportType2: DistanceSupportType(rawValue: detail.supportType2) ?? .vertex,
            paramEdge1: detail.paramEdge1,
            paramEdge2: detail.paramEdge2,
            paramFaceUV1: (u: detail.paramFaceU1, v: detail.paramFaceV1),
            paramFaceUV2: (u: detail.paramFaceU2, v: detail.paramFaceV2)
        )
    }

    // MARK: - Plane Detection (v0.41.0)

    /// Result of plane detection.
    public struct DetectedPlane {
        /// Plane normal direction.
        public let normal: SIMD3<Double>
        /// Plane origin point.
        public let origin: SIMD3<Double>
    }

    /// Find if this shape's edges lie in a plane.
    ///
    /// Uses BRepBuilderAPI_FindPlane to detect if a wire, edge set, or shape
    /// lies in a single geometric plane.
    /// - Parameter tolerance: Tolerance for planarity check (default 1e-6)
    /// - Returns: Detected plane, or nil if shape is not planar
    public func findPlane(tolerance: Double = 1e-6) -> DetectedPlane? {
        var nx = 0.0
        var ny = 0.0
        var nz = 0.0
        var ox = 0.0
        var oy = 0.0
        var oz = 0.0
        guard OCCTShapeFindPlane(handle, tolerance, &nx, &ny, &nz, &ox, &oy, &oz) else {
            return nil
        }
        return DetectedPlane(normal: SIMD3(nx, ny, nz), origin: SIMD3(ox, oy, oz))
    }

    /// Result of point cloud geometry analysis.
    public enum PointCloudGeometry {
        /// All points are coincident (within tolerance)
        case point(SIMD3<Double>)
        /// Points are collinear, fit a line
        case linear(origin: SIMD3<Double>, direction: SIMD3<Double>)
        /// Points are coplanar, fit a plane
        case planar(origin: SIMD3<Double>, normal: SIMD3<Double>)
        /// Points are dispersed in 3D space
        case space
    }

    /// Analyze a set of 3D points to determine their geometric arrangement.
    ///
    /// Uses GProp_PEquation to classify points as coincident, collinear, coplanar,
    /// or dispersed in 3D space. Useful for determining degeneracy of point sets
    /// before constructing geometry.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 1)
    ///   - tolerance: Tolerance for classification
    /// - Returns: Classification result, or nil on failure
    public static func analyzePointCloud(_ points: [SIMD3<Double>], tolerance: Double = 1e-6)
        -> PointCloudGeometry?
    {
        guard !points.isEmpty else { return nil }
        var coords: [Double] = []
        coords.reserveCapacity(points.count * 3)
        for p in points {
            coords.append(p.x)
            coords.append(p.y)
            coords.append(p.z)
        }
        var result = OCCTPointCloudGeometry()
        let ok = coords.withUnsafeBufferPointer { buffer in
            OCCTAnalyzePointCloud(buffer.baseAddress, Int32(points.count), tolerance, &result)
        }
        guard ok else { return nil }
        switch result.type {
        case 0:
            return .point(SIMD3(result.pointX, result.pointY, result.pointZ))
        case 1:
            return .linear(
                origin: SIMD3(result.pointX, result.pointY, result.pointZ),
                direction: SIMD3(result.dirX, result.dirY, result.dirZ)
            )
        case 2:
            return .planar(
                origin: SIMD3(result.pointX, result.pointY, result.pointZ),
                normal: SIMD3(result.normalX, result.normalY, result.normalZ)
            )
        case 3:
            return .space
        default:
            return nil
        }
    }

    // MARK: - Self-Intersection Detection (v0.45.0)

    /// Result of a self-intersection check (mesh-based, using BRepExtrema_SelfIntersection).
    public struct SelfIntersectionResult: Sendable {
        /// Number of overlapping triangle pairs found.
        public let overlapCount: Int
        /// Whether the check completed successfully.
        public let isDone: Bool
    }

    /// Result of a detailed self-intersection check (BOPAlgo-based, using ArgumentAnalyzer).
    public struct SelfIntersectionDetailedResult: Sendable {
        /// Status of the self-intersection check.
        public enum Status: Sendable, Equatable {
            /// The shape self-intersects (conclusive).
            case intersects
            /// The shape is clean (no self-intersection, conclusive).
            case clean
            /// The check timed out and the OCCT progress breaker was tripped (analysis was running).
            /// A longer timeout may yield a conclusive result.
            case indeterminateBreakerTripped
            /// The check timed out and the OCCT progress breaker was NOT tripped (analysis made no progress).
            /// The shape may be too complex for this check to complete in reasonable time.
            case indeterminateBreakerNotTripped
            /// An error occurred during analysis.
            case error
        }

        /// The status of the check.
        public let status: Status
        /// Number of face pairs checked before completion/timeout.
        /// NOTE: BOPAlgo_ArgumentAnalyzer does not expose a progress counter; this is always 0.
        public let facesChecked: Int
        /// Estimated total face pairs to check.
        public let totalFacePairs: Int
        /// Actual time spent in seconds.
        public let timeSpent: Double

        init(code: Int32, facesChecked: Int, totalFacePairs: Int, timeSpent: Double) {
            self.facesChecked = facesChecked
            self.totalFacePairs = totalFacePairs
            self.timeSpent = timeSpent
            switch code {
            case 1: self.status = .intersects
            case 0: self.status = .clean
            case -1: self.status = .indeterminateBreakerTripped
            case -2: self.status = .indeterminateBreakerNotTripped
            default: self.status = .error
            }
        }
    }

    /// Cost estimate for a BOPAlgo-based self-intersection check.
    public struct SelfIntersectionCostEstimate: Sendable {
        /// Total number of faces in the shape.
        public let numFaces: Int
        /// Number of B-spline faces (most expensive to check).
        public let numBSplineFaces: Int
        /// Number of planar faces (cheapest to check).
        public let numPlaneFaces: Int
        /// Relative cost estimate (higher = more expensive).
        /// Cost model: B-spline = 10x, other analytical = 3x, plane = 1x.
        public let estimatedCost: Double
    }

    /// Check the shape for self-intersection using BVH-accelerated triangle mesh overlap.
    ///
    /// Meshes the shape and uses BRepExtrema_SelfIntersection to detect overlapping
    /// triangle pairs, which indicate self-intersection.
    ///
    /// - Parameters:
    ///   - tolerance: Tolerance for detecting intersections (default 0.001)
    ///   - meshDeflection: Mesh deflection for triangulation (default 0.5)
    /// - Returns: Self-intersection result, or nil if the check failed
    public func selfIntersection(
        tolerance: Double = 0.001,
        meshDeflection: Double = 0.5
    ) -> SelfIntersectionResult? {
        let result = OCCTShapeSelfIntersection(handle, tolerance, meshDeflection)
        guard result.isDone else { return nil }
        return SelfIntersectionResult(overlapCount: Int(result.overlapCount), isDone: true)
    }

    // MARK: - Volume Inertia Properties (v0.46.0)

    /// Volume inertia properties of a solid shape.
    public struct VolumeInertia: Sendable {
        /// Volume of the shape.
        public let volume: Double
        /// Center of mass.
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia tensor (row-major).
        public let inertiaTensor: [Double]
        /// Principal moments of inertia (sorted).
        public let principalMoments: SIMD3<Double>
        /// Principal axes of inertia (3 unit vectors).
        public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        /// Radii of gyration about principal axes.
        public let gyrationRadii: SIMD3<Double>
        /// Whether the shape has a symmetry axis (#848: added to match ``InertiaProperties``,
        /// which has always had this field, both read it off the same `GProp_PrincipalProps`).
        public let hasSymmetryAxis: Bool
        /// Whether the shape has a symmetry point.
        public let hasSymmetryPoint: Bool
    }

    /// Compute volume inertia properties of this shape.
    ///
    /// Returns volume, center of mass, inertia tensor, principal moments and axes of inertia,
    /// radii of gyration, and (#848) the two symmetry flags ``inertiaProperties()`` has always
    /// had, all read off the same `GProp_PrincipalProps` computation, so there is no extra cost
    /// to having both here.
    ///
    /// Nil for any shape with no closed volume: a face, wire, edge, vertex or open shell. See
    /// ``inertiaProperties()`` for why every field is an artefact there rather than a zero (#609).
    ///
    /// ```swift
    /// let cyl = Shape.cylinder(radius: 3, height: 10)!
    /// cyl.volumeInertia?.volume            // 282.7
    /// cyl.volumeInertia?.centerOfMass      // (0, 0, 5)
    /// cyl.volumeInertia?.hasSymmetryAxis   // true
    ///
    /// // A closed shell still answers: the key is closedness, not `ShapeType() == SOLID`.
    /// cyl.subShapes(ofType: .shell).first?.volumeInertia?.volume   // 282.7
    /// ```
    ///
    /// - Returns: Volume inertia result, or nil when the shape has no volume or on error
    public var volumeInertia: VolumeInertia? {
        var result = OCCTVolumeInertiaResult()
        guard OCCTShapeVolumeInertia(handle, &result) else { return nil }

        let tensor = withUnsafeBytes(of: &result.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }

        return VolumeInertia(
            volume: result.volume,
            centerOfMass: SIMD3(result.centerX, result.centerY, result.centerZ),
            inertiaTensor: tensor,
            principalMoments: SIMD3(
                result.principalMoment1, result.principalMoment2, result.principalMoment3),
            principalAxes: (
                SIMD3(result.axis1X, result.axis1Y, result.axis1Z),
                SIMD3(result.axis2X, result.axis2Y, result.axis2Z),
                SIMD3(result.axis3X, result.axis3Y, result.axis3Z)
            ),
            gyrationRadii: SIMD3(
                result.gyrationRadius1, result.gyrationRadius2, result.gyrationRadius3),
            hasSymmetryAxis: result.hasSymmetryAxis,
            hasSymmetryPoint: result.hasSymmetryPoint
        )
    }

    /// Surface inertia properties of a shape.
    public struct SurfaceInertia: Sendable {
        /// Total surface area.
        public let area: Double
        /// Center of mass of the surface.
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia tensor (row-major).
        public let inertiaTensor: [Double]
        /// Principal moments of inertia.
        public let principalMoments: SIMD3<Double>
        /// Whether the shape has a symmetry axis (#848: added to match the result of
        /// ``surfaceInertiaProperties()``, which has always had this field, both read
        /// it off the same `GProp_PrincipalProps`).
        public let hasSymmetryAxis: Bool
        /// Whether the shape has a symmetry point.
        public let hasSymmetryPoint: Bool
    }

    /// Compute surface (area) inertia properties of this shape.
    ///
    /// Works for a face or an open shell, and is nil for a shape with no faces at all, where the
    /// reported centroid would be the shape's location origin rather than a recognisable zero
    /// (#609). Also reports the two symmetry flags ``surfaceInertiaProperties()`` has always had
    /// (#848), read off the same `GProp_PrincipalProps` as ``principalMoments``.
    ///
    /// `.area` is the same call as ``Shape/surfaceArea`` and ``surfaceInertiaProperties()`` `.mass`
    ///, see ``Shape/surfaceArea`` for the #885 divergence from
    /// ``ShapeMeasurements/totalFaceArea``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// let sheet = Shape.fromFace(box.faces()[0])!
    /// sheet.surfaceInertia?.area           // 600
    /// sheet.surfaceInertia?.centerOfMass   // the face's area centroid
    /// ```
    ///
    /// - Returns: Surface inertia result, or nil when the shape has no area or on error
    public var surfaceInertia: SurfaceInertia? {
        var result = OCCTSurfaceInertiaResult()
        guard OCCTShapeSurfaceInertia(handle, &result) else { return nil }

        let tensor = withUnsafeBytes(of: &result.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }

        return SurfaceInertia(
            area: result.area,
            centerOfMass: SIMD3(result.centerX, result.centerY, result.centerZ),
            inertiaTensor: tensor,
            principalMoments: SIMD3(
                result.principalMoment1, result.principalMoment2, result.principalMoment3),
            hasSymmetryAxis: result.hasSymmetryAxis,
            hasSymmetryPoint: result.hasSymmetryPoint
        )
    }

    // MARK: - LocOpe_CSIntersector

    /// Result of a curve-shape intersection.
    public struct CSIntersection: Sendable {
        /// Intersection point.
        public let point: SIMD3<Double>
        /// Parameter on the curve.
        public let parameter: Double
        /// UV parameters on the intersected face.
        public let faceUV: SIMD2<Double>
    }

    /// Intersect a line with this shape to find intersection points.
    ///
    /// Uses LocOpe_CSIntersector to find where a line penetrates the shape.
    ///
    /// - Parameters:
    ///   - origin: Line origin
    ///   - direction: Line direction
    /// - Returns: Array of intersection points
    public func intersectLine(origin: SIMD3<Double>, direction: SIMD3<Double>) -> [CSIntersection] {
        var buffer = [OCCTCSIntersectionPoint](repeating: OCCTCSIntersectionPoint(), count: 100)
        let count = OCCTLocOpeCSIntersectLine(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            &buffer, 100)
        var results = [CSIntersection]()
        results.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            let pt = buffer[i]
            results.append(
                CSIntersection(
                    point: SIMD3(pt.px, pt.py, pt.pz),
                    parameter: pt.parameter,
                    faceUV: SIMD2(pt.uOnFace, pt.vOnFace)
                ))
        }
        return results
    }

    // MARK: - BRepCheck_Analyzer

    /// Perform comprehensive validity analysis on this shape.
    ///
    /// Uses BRepCheck_Analyzer for full topology + geometry validation.
    /// More thorough than `isValid` as it can include geometry checks.
    ///
    /// - Parameter geometryChecks: Whether to include geometry-level checks (default: true)
    /// - Returns: true if the shape is valid
    public func analyzeValidity(geometryChecks: Bool = true) -> Bool {
        OCCTBRepCheckAnalyzerIsValid(handle, geometryChecks)
    }

    /// Compute distance extrema between two edges by index.
    ///
    /// Uses BRepExtrema_ExtCC for edge-edge distance computation.
    ///
    /// - Parameters:
    ///   - edgeIndex1: Index of first edge in this shape (0-based)
    ///   - other: Shape containing the second edge
    ///   - edgeIndex2: Index of second edge in other shape (0-based)
    /// - Returns: Edge-edge extrema result, or nil on failure
    public func edgeEdgeExtrema(edgeIndex1: Int, other: Shape, edgeIndex2: Int) -> EdgeEdgeExtrema?
    {
        let result = OCCTBRepExtremaExtCC(
            handle, Int32(edgeIndex1), other.handle, Int32(edgeIndex2))
        guard result.solutionCount > 0 else { return nil }
        return EdgeEdgeExtrema(
            distance: result.distance,
            paramOnEdge1: result.paramOnE1,
            paramOnEdge2: result.paramOnE2,
            pointOnEdge1: SIMD3(result.pt1x, result.pt1y, result.pt1z),
            pointOnEdge2: SIMD3(result.pt2x, result.pt2y, result.pt2z),
            isParallel: result.isParallel,
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtPF (Point-Face Extrema)

    /// Result of point-face distance extrema computation.
    public struct PointFaceExtrema: Sendable {
        /// Minimum distance from point to face.
        public let distance: Double
        /// UV parameters on the face at closest point.
        public let faceUV: SIMD2<Double>
        /// Closest point on the face.
        public let pointOnFace: SIMD3<Double>
        /// Number of extrema solutions.
        public let solutionCount: Int
    }

    /// Compute distance from a point to a face.
    ///
    /// Uses BRepExtrema_ExtPF for point-face distance computation.
    ///
    /// - Parameters:
    ///   - point: 3D point
    ///   - faceIndex: Index of face in this shape (0-based)
    /// - Returns: Point-face extrema result, or nil on failure
    public func pointFaceExtrema(point: SIMD3<Double>, faceIndex: Int) -> PointFaceExtrema? {
        let result = OCCTBRepExtremaExtPF(point.x, point.y, point.z, handle, Int32(faceIndex))
        guard result.solutionCount > 0 else { return nil }
        return PointFaceExtrema(
            distance: result.distance,
            faceUV: SIMD2(result.u, result.v),
            pointOnFace: SIMD3(result.ptx, result.pty, result.ptz),
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtFF (Face-Face Extrema)

    /// Result of face-face distance extrema computation.
    public struct FaceFaceExtrema: Sendable {
        /// Minimum distance between faces.
        public let distance: Double
        /// UV parameters on face 1.
        public let face1UV: SIMD2<Double>
        /// UV parameters on face 2.
        public let face2UV: SIMD2<Double>
        /// Closest point on face 1.
        public let pointOnFace1: SIMD3<Double>
        /// Closest point on face 2.
        public let pointOnFace2: SIMD3<Double>
        /// Number of extrema solutions.
        public let solutionCount: Int
    }

    /// Compute distance extrema between two faces.
    ///
    /// Uses BRepExtrema_ExtFF for face-face distance computation.
    ///
    /// - Parameters:
    ///   - faceIndex1: Index of first face in this shape (0-based)
    ///   - other: Shape containing the second face
    ///   - faceIndex2: Index of second face in other shape (0-based)
    /// - Returns: Face-face extrema result, or nil on failure
    public func faceFaceExtrema(faceIndex1: Int, other: Shape, faceIndex2: Int) -> FaceFaceExtrema?
    {
        let result = OCCTBRepExtremaExtFF(
            handle, Int32(faceIndex1), other.handle, Int32(faceIndex2))
        guard result.solutionCount > 0 else { return nil }
        return FaceFaceExtrema(
            distance: result.distance,
            face1UV: SIMD2(result.u1, result.v1),
            face2UV: SIMD2(result.u2, result.v2),
            pointOnFace1: SIMD3(result.pt1x, result.pt1y, result.pt1z),
            pointOnFace2: SIMD3(result.pt2x, result.pt2y, result.pt2z),
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtPC (Point-Edge Extrema)

    /// Result of point-edge distance extrema computation.
    public struct PointEdgeExtrema: Sendable {
        /// Minimum distance from the point to the edge, over the whole edge including its ends.
        public let distance: Double
        /// Parameter on the edge at the nearest point.
        public let parameter: Double
        /// The nearest point on the edge.
        public let pointOnEdge: SIMD3<Double>
        /// Number of `BRepExtrema_ExtPC` extrema (perpendicular feet) the point has on this edge.
        ///
        /// Zero is an ordinary, informative answer rather than a failure: it means the nearest
        /// point is one of the edge's two ends. A non-zero count does *not* mean the nearest point
        /// is one of those feet, an extremum can be a maximum, so read `distance`, `parameter`
        /// and `pointOnEdge` for the answer and this only for the count.
        public let solutionCount: Int
    }

    /// Compute the minimum distance from a point to an edge of this shape.
    ///
    /// The answer is the nearest point over the whole edge, its two ends included, and matches
    /// ``Edge/project(point:)`` on the same edge and the same point, both take a minimum over
    /// `ShapeAnalysis_Curve`, `GeomAPI_ProjectPointOnCurve` and the edge's ends.
    ///
    /// ```swift
    /// let arc = Shape.fromWire(Wire.arc(
    ///     center: SIMD3(0, 0, 0), radius: 5, startAngle: 0, endAngle: .pi)!)!
    ///
    /// // Below the arc, the nearest point is an end, the only extremum is the far side of it.
    /// if let hit = arc.pointEdgeExtrema(point: SIMD3(0, -6, 0), edgeIndex: 0) {
    ///     print(hit.distance)       // 7.81, to the end at (5, 0, 0). Was 11, the far side.
    ///     print(hit.solutionCount)  // 1, and that one extremum is a maximum
    /// }
    ///
    /// let segment = Shape.fromWire(Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(8, 0, 0))!)!
    /// if let hit = segment.pointEdgeExtrema(point: SIMD3(100, 0, 0), edgeIndex: 0) {
    ///     print(hit.distance)       // 92. Was nil: no extremum exists past the end.
    ///     print(hit.solutionCount)  // 0, no perpendicular foot, not a failure
    /// }
    /// ```
    ///
    /// Before #580 this reported the smallest of `BRepExtrema_ExtPC`'s extrema, which excludes the
    /// edge's ends and can be a single *maximum*: the arc above answered 11 (the far side), and a
    /// point beyond the end of a trimmed segment answered `nil`.
    ///
    /// - Parameters:
    ///   - point: 3D point
    ///   - edgeIndex: 0-based edge index, in the enumeration ``edges()`` reads
    /// - Returns: The nearest-point result, or nil if there is no such edge index or that edge has
    ///   no 3D curve.
    public func pointEdgeExtrema(point: SIMD3<Double>, edgeIndex: Int) -> PointEdgeExtrema? {
        let result = OCCTBRepExtremaExtPC(point.x, point.y, point.z, handle, Int32(edgeIndex))
        guard result.isValid else { return nil }
        return PointEdgeExtrema(
            distance: result.distance,
            parameter: result.parameter,
            pointOnEdge: SIMD3(result.ptx, result.pty, result.ptz),
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - BRepExtrema_ExtCF (Edge-Face Extrema)

    /// Result of edge-face distance extrema computation.
    public struct EdgeFaceExtrema: Sendable {
        /// Minimum distance between edge and face.
        public let distance: Double
        /// Parameter on edge at closest point.
        public let paramOnEdge: Double
        /// UV parameters on face at closest point.
        public let faceUV: SIMD2<Double>
        /// Closest point on edge.
        public let pointOnEdge: SIMD3<Double>
        /// Closest point on face.
        public let pointOnFace: SIMD3<Double>
        /// Whether edge and face are parallel.
        public let isParallel: Bool
        /// Number of extrema solutions found.
        public let solutionCount: Int
    }

    /// Compute distance extrema between an edge and a face.
    ///
    /// Uses BRepExtrema_ExtCF to find the closest points between
    /// the specified edge of this shape and a face of another shape.
    ///
    /// - Parameters:
    ///   - edgeIndex: 0-based edge index in this shape
    ///   - other: Shape containing the face
    ///   - faceIndex: 0-based face index in the other shape
    /// - Returns: Extrema result, or nil if parallel or computation fails
    public func edgeFaceExtrema(edgeIndex: Int, other: Shape, faceIndex: Int) -> EdgeFaceExtrema? {
        let result = OCCTBRepExtremaExtCF(handle, Int32(edgeIndex), other.handle, Int32(faceIndex))
        if result.isParallel {
            return EdgeFaceExtrema(
                distance: 0, paramOnEdge: 0, faceUV: .zero,
                pointOnEdge: .zero, pointOnFace: .zero,
                isParallel: true, solutionCount: 0
            )
        }
        guard result.solutionCount > 0 else { return nil }
        return EdgeFaceExtrema(
            distance: result.distance,
            paramOnEdge: result.paramOnEdge,
            faceUV: SIMD2(result.uOnFace, result.vOnFace),
            pointOnEdge: SIMD3(result.edgePtx, result.edgePty, result.edgePtz),
            pointOnFace: SIMD3(result.facePtx, result.facePty, result.facePtz),
            isParallel: false,
            solutionCount: Int(result.solutionCount)
        )
    }

    // MARK: - ShapeAnalysis_FreeBoundsProperties

    /// Properties of a single free bound (boundary wire).
    public struct FreeBoundInfo: Sendable {
        /// Area enclosed by the bound.
        public let area: Double
        /// Perimeter length.
        public let perimeter: Double
        /// Aspect ratio: contour length divided by contour width. 1 for a square-ish bound, 10 for
        /// a 100×10 one.
        ///
        /// OCCT solves this from `area` and `perimeter` and leaves both this and ``width`` at 0
        /// when that solve has no real root, which an exactly square bound hits by one ulp, since
        /// it sits precisely on the boundary between the two branches. So 0 means "not solvable
        /// here", not "degenerate contour"; `area` and `perimeter` are still good in that case.
        public let ratio: Double
        /// Average width, on the same "0 means unsolved" contract as ``ratio``.
        public let width: Double
        /// Number of notches (narrow 'V'-like sub-contours) found on the bound.
        public let notchCount: Int
    }

    // MARK: - v0.50.0: Polyhedral distance, history tracking, wire vertex analysis, nearest plane

    /// Result of a polyhedral (approximate) distance computation.
    public struct PolyhedralDistance {
        /// Approximate distance between the two shapes.
        public let distance: Double
        /// Closest point on the first shape.
        public let point1: SIMD3<Double>
        /// Closest point on the second shape.
        public let point2: SIMD3<Double>
    }

    /// Compute fast polyhedral (approximate) distance to another shape.
    ///
    /// Both shapes must be meshed (have triangulation). This is faster than exact
    /// distance but less precise.
    ///
    /// - Parameter other: The other shape
    /// - Returns: Distance result, or nil if computation fails
    public func polyhedralDistance(to other: Shape) -> PolyhedralDistance? {
        let result = OCCTShapePolyhedralDistance(handle, other.handle)
        guard result.success else { return nil }
        return PolyhedralDistance(
            distance: result.distance,
            point1: SIMD3(result.p1x, result.p1y, result.p1z),
            point2: SIMD3(result.p2x, result.p2y, result.p2z))
    }

    // MARK: - IntCurvesFace Intersection (v0.61.0)

    /// Result of a line-face intersection.
    public struct LineFaceIntersection {
        /// 3D intersection point.
        public let point: SIMD3<Double>
        /// Parameter on the line.
        public let parameter: Double
    }

    /// Intersect a line with this shape (must be a face).
    ///
    /// - Parameters:
    ///   - origin: Line origin point
    ///   - direction: Line direction
    ///   - paramRange: Parameter range on the line (default -1000...1000)
    /// - Returns: Array of intersection results
    public func intersectLine(
        origin: SIMD3<Double>, direction: SIMD3<Double>,
        paramRange: ClosedRange<Double> = -1000...1000
    ) -> [LineFaceIntersection] {
        let maxPts: Int32 = 100
        var outPoints = [Double](repeating: 0, count: Int(maxPts) * 3)
        var outParams = [Double](repeating: 0, count: Int(maxPts))
        let count = OCCTIntersectLineFace(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            paramRange.lowerBound, paramRange.upperBound,
            &outPoints, &outParams, maxPts)
        var results: [LineFaceIntersection] = []
        for i in 0..<Int(count) {
            results.append(
                LineFaceIntersection(
                    point: SIMD3(outPoints[i * 3], outPoints[i * 3 + 1], outPoints[i * 3 + 2]),
                    parameter: outParams[i]))
        }
        return results
    }

    // MARK: - Contap Contour Analysis (v0.61.0)

    /// Contour type from analytical contour computation.
    public enum ContourType: Int32 {
        case line = 0
        case circle = 1
        case other = 2
    }

    /// Result of an analytical contour computation.
    public struct ContourResult {
        /// Type of contour.
        public let type: ContourType
        /// Number of contours found.
        public let count: Int
        /// Circle: center and radius; line: location and direction.
        public let data: [Double]
    }

    /// Compute analytical contours on a sphere with a view direction.
    ///
    /// Returns the silhouette contour of a sphere viewed from a given direction.
    /// For orthographic projection, this is typically a great circle.
    ///
    /// - Parameters:
    ///   - center: Sphere center
    ///   - radius: Sphere radius
    ///   - direction: View direction
    /// - Returns: Contour result, or nil on failure
    public static func contourSphereDir(
        center: SIMD3<Double>, radius: Double,
        direction: SIMD3<Double>
    ) -> ContourResult? {
        var outType: Int32 = 0
        var outData = [Double](repeating: 0, count: 8)
        let count = OCCTContapSphereDir(
            center.x, center.y, center.z, radius,
            direction.x, direction.y, direction.z,
            &outType, &outData)
        if count < 0 { return nil }
        return ContourResult(
            type: ContourType(rawValue: outType) ?? .other,
            count: Int(count), data: outData)
    }

    /// Compute analytical contours on a cylinder with a view direction.
    ///
    /// - Parameters:
    ///   - origin: Cylinder axis origin
    ///   - axis: Cylinder axis direction
    ///   - radius: Cylinder radius
    ///   - direction: View direction
    /// - Returns: Contour result, or nil on failure
    public static func contourCylinderDir(
        origin: SIMD3<Double>, axis: SIMD3<Double>,
        radius: Double, direction: SIMD3<Double>
    ) -> ContourResult? {
        var outType: Int32 = 0
        var outData = [Double](repeating: 0, count: 8)
        let count = OCCTContapCylinderDir(
            origin.x, origin.y, origin.z,
            axis.x, axis.y, axis.z, radius,
            direction.x, direction.y, direction.z,
            &outType, &outData)
        if count < 0 { return nil }
        return ContourResult(
            type: ContourType(rawValue: outType) ?? .other,
            count: Int(count), data: outData)
    }

    /// Compute analytical contours on a sphere with a perspective eye point.
    ///
    /// - Parameters:
    ///   - center: Sphere center
    ///   - radius: Sphere radius
    ///   - eye: Eye point for perspective projection
    /// - Returns: Contour result, or nil on failure
    public static func contourSphereEye(
        center: SIMD3<Double>, radius: Double,
        eye: SIMD3<Double>
    ) -> ContourResult? {
        var outType: Int32 = 0
        var outData = [Double](repeating: 0, count: 8)
        let count = OCCTContapSphereEye(
            center.x, center.y, center.z, radius,
            eye.x, eye.y, eye.z,
            &outType, &outData)
        if count < 0 { return nil }
        return ContourResult(
            type: ContourType(rawValue: outType) ?? .other,
            count: Int(count), data: outData)
    }

    // MARK: IntCurvesFace_ShapeIntersector

    /// Ray intersection result.
    public struct RayIntersection: Sendable {
        public let point: SIMD3<Double>
        public let parameter: Double
    }

    /// Intersect a ray with all faces of this shape.
    public func rayIntersect(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> [RayIntersection]? {
        var outPoints: UnsafeMutablePointer<Double>?
        var outParams: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard
            OCCTIntCurvesFaceShapeIntersect(
                handle,
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                &outPoints, &outParams, &outCount
            ), let pts = outPoints, let params = outParams, outCount > 0
        else { return nil }
        defer {
            free(pts)
            free(params)
        }
        var results = [RayIntersection]()
        for i in 0..<Int(outCount) {
            results.append(
                RayIntersection(
                    point: SIMD3(pts[i * 3], pts[i * 3 + 1], pts[i * 3 + 2]),
                    parameter: params[i]
                ))
        }
        return results
    }

    /// Find the nearest intersection of a ray with this shape.
    public func rayIntersectNearest(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> RayIntersection? {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        var param: Double = 0
        guard
            OCCTIntCurvesFaceShapeIntersectNearest(
                handle,
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                &x, &y, &z, &param
            )
        else { return nil }
        return RayIntersection(point: SIMD3(x, y, z), parameter: param)
    }

    // MARK: - GeomLProp_CLProps

    /// Compute curve local properties at a parameter on an edge.
    public func curveLocalProps(at param: Double) -> CurveLocalProperties {
        let r = OCCTGeomLPropCLProps(handle, param)
        let point = SIMD3(r.px, r.py, r.pz)
        let tangent: SIMD3<Double>? = r.tangentDefined ? SIMD3(r.tx, r.ty, r.tz) : nil
        // #494: was `r.tangentDefined && r.curvature > 1e-10` here, a Swift-side copy of a
        // bridge-side literal. The bridge now reports whether it filled these in, so the threshold
        // lives in exactly one place and the two sides cannot drift apart.
        let normal: SIMD3<Double>? = r.curvatureInvertible ? SIMD3(r.nx, r.ny, r.nz) : nil
        let center: SIMD3<Double>? = r.curvatureInvertible ? SIMD3(r.cx, r.cy, r.cz) : nil
        return CurveLocalProperties(
            point: point, tangent: tangent, normal: normal,
            centerOfCurvature: center, curvature: r.curvature)
    }

    // MARK: - GeomLProp_SLProps

    /// Compute surface local properties at (U,V) on a face.
    public func surfaceLocalProps(u: Double, v: Double) -> SurfaceLocalProperties {
        let r = OCCTGeomLPropSLProps(handle, u, v)
        let point = SIMD3(r.px, r.py, r.pz)
        let normal: SIMD3<Double>? = r.normalDefined ? SIMD3(r.nx, r.ny, r.nz) : nil
        let tu: SIMD3<Double>? =
            (r.tuX != 0 || r.tuY != 0 || r.tuZ != 0) ? SIMD3(r.tuX, r.tuY, r.tuZ) : nil
        let tv: SIMD3<Double>? =
            (r.tvX != 0 || r.tvY != 0 || r.tvZ != 0) ? SIMD3(r.tvX, r.tvY, r.tvZ) : nil
        return SurfaceLocalProperties(
            point: point, normal: normal, tangentU: tu, tangentV: tv,
            maxCurvature: r.maxCurvature, minCurvature: r.minCurvature,
            meanCurvature: r.meanCurvature, gaussianCurvature: r.gaussianCurvature,
            curvatureDefined: r.curvatureDefined, isUmbilic: r.isUmbilic)
    }

    // MARK: - GeomInt_IntSS

    /// Compute surface-surface intersection between two faces.
    public static func surfaceSurfaceIntersection(
        face1: Shape, face2: Shape, tolerance: Double = 1e-6
    ) -> SurfaceIntersectionResult? {
        guard let ref = OCCTGeomIntSSCreate(face1.handle, face2.handle, tolerance) else {
            return nil
        }
        return SurfaceIntersectionResult(ref)
    }

    // MARK: - Contap_Contour

    /// Compute contour lines on a face with a projection direction (orthographic).
    public func contapContourDirection(_ direction: SIMD3<Double>) -> ContapContourResult? {
        guard let ref = OCCTContapContourDirection(handle, direction.x, direction.y, direction.z)
        else { return nil }
        let result = ContapContourResult(ref)
        return result.lineCount > 0 ? result : nil
    }

    /// Compute contour lines on a face with an eye point (perspective).
    public func contapContourEye(_ eye: SIMD3<Double>) -> ContapContourResult? {
        guard let ref = OCCTContapContourEye(handle, eye.x, eye.y, eye.z) else { return nil }
        let result = ContapContourResult(ref)
        return result.lineCount > 0 ? result : nil
    }

    /// Curvature special point type from LProp analysis.
    public enum CurvaturePointType: Int32 {
        case inflection = 0
        case minimumCurvature = 1
        case maximumCurvature = 2
    }

    /// Result of LProp analytic curve inflection analysis.
    public struct CurvatureSpecialPoint {
        /// Parameter on the curve.
        public let parameter: Double
        /// Type of special point.
        public let type: CurvaturePointType
    }

    /// Compute curvature special points for analytic curve types using LProp.
    /// - Parameters:
    ///   - curveType: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola
    ///   - first: First parameter of domain
    ///   - last: Last parameter of domain
    /// - Returns: Array of special points (inflections, min/max curvature)
    public static func analyticCurvaturePoints(
        curveType: Int32, first: Double,
        last: Double
    ) -> [CurvatureSpecialPoint] {
        let maxResults: Int32 = 100
        var params = [Double](repeating: 0, count: Int(maxResults))
        var types = [Int32](repeating: 0, count: Int(maxResults))
        let count = OCCTLPropAnalyticCurInf(curveType, first, last, &params, &types, maxResults)
        var results: [CurvatureSpecialPoint] = []
        for i in 0..<Int(count) {
            if let t = CurvaturePointType(rawValue: types[i]) {
                results.append(CurvatureSpecialPoint(parameter: params[i], type: t))
            }
        }
        return results
    }

    // MARK: - Polygon Interference (v0.68.0)

    /// Result of 2D polygon interference (intersection).
    public struct PolygonIntersection: Sendable {
        /// Intersection point coordinates.
        public let points: [SIMD2<Double>]
    }

    /// Compute interference (intersection) between two 2D polylines.
    ///
    /// - Parameters:
    ///   - poly1: Array of 2D points forming first polyline
    ///   - poly2: Array of 2D points forming second polyline
    /// - Returns: Intersection result with points
    public static func polygonInterference(
        poly1: [SIMD2<Double>], poly2: [SIMD2<Double>]
    ) -> PolygonIntersection {
        let flat1 = poly1.flatMap { [$0.x, $0.y] }
        let flat2 = poly2.flatMap { [$0.x, $0.y] }
        let maxPts: Int32 = 100
        var outPts = [OCCTIntfPoint2D](repeating: OCCTIntfPoint2D(x: 0, y: 0), count: Int(maxPts))
        let count = flat1.withUnsafeBufferPointer { p1 in
            flat2.withUnsafeBufferPointer { p2 in
                OCCTIntfInterferencePolygon2d(
                    p1.baseAddress!, Int32(poly1.count),
                    p2.baseAddress!, Int32(poly2.count),
                    &outPts, maxPts)
            }
        }
        var points: [SIMD2<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD2(outPts[i].x, outPts[i].y))
        }
        return PolygonIntersection(points: points)
    }

    /// Compute self-interference of a 2D polyline.
    public static func polygonSelfInterference(
        polygon: [SIMD2<Double>]
    ) -> PolygonIntersection {
        let flat = polygon.flatMap { [$0.x, $0.y] }
        let maxPts: Int32 = 100
        var outPts = [OCCTIntfPoint2D](repeating: OCCTIntfPoint2D(x: 0, y: 0), count: Int(maxPts))
        let count = flat.withUnsafeBufferPointer { p in
            OCCTIntfSelfInterferencePolygon2d(
                p.baseAddress!, Int32(polygon.count),
                &outPts, maxPts)
        }
        var points: [SIMD2<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD2(outPts[i].x, outPts[i].y))
        }
        return PolygonIntersection(points: points)
    }

    // MARK: - IntTools (v0.70.0)

    /// Type of intersection common part.
    public enum CommonPartType: Int32, Sendable {
        case vertex = 0
        case edge = 1
    }

    /// Result of an edge-edge or edge-face intersection.
    public struct CommonPart: Sendable {
        /// Type of intersection (vertex or edge overlap).
        public let type: CommonPartType
        /// Parameter range on edge 1 (first, last), same for vertex type.
        public let param1Range: (first: Double, last: Double)
        /// Parameter range on edge 2 (first, last), same for vertex type.
        public let param2Range: (first: Double, last: Double)
        /// Representative 3D point of the intersection.
        public let point: SIMD3<Double>
    }

    /// Intersect two edges to find common vertices and edge overlaps.
    ///
    /// Uses IntTools_EdgeEdge to compute precise intersections.
    ///
    /// - Parameter other: Edge to intersect with
    /// - Returns: Array of common parts, or nil if intersection failed
    public func edgeEdgeIntersection(with other: Shape) -> [CommonPart]? {
        var parts: UnsafeMutablePointer<OCCTCommonPart>?
        var count: Int32 = 0
        guard OCCTIntToolsEdgeEdge(handle, other.handle, &parts, &count) else { return nil }
        defer { parts?.deallocate() }
        return (0..<Int(count)).map { i in
            let p = parts![i]
            return CommonPart(
                type: CommonPartType(rawValue: p.type) ?? .vertex,
                param1Range: (p.param1First, p.param1Last),
                param2Range: (p.param2First, p.param2Last),
                point: SIMD3(p.pointX, p.pointY, p.pointZ)
            )
        }
    }

    /// Intersect an edge with a face to find common vertices and edge overlaps.
    ///
    /// Uses IntTools_EdgeFace to compute edge-face intersections.
    ///
    /// - Parameter face: Face to intersect with
    /// - Returns: Array of common parts, or nil if intersection failed
    public func edgeFaceIntersection(with face: Shape) -> [CommonPart]? {
        var parts: UnsafeMutablePointer<OCCTCommonPart>?
        var count: Int32 = 0
        guard OCCTIntToolsEdgeFace(handle, face.handle, &parts, &count) else { return nil }
        defer { parts?.deallocate() }
        return (0..<Int(count)).map { i in
            let p = parts![i]
            return CommonPart(
                type: CommonPartType(rawValue: p.type) ?? .vertex,
                param1Range: (p.param1First, p.param1Last),
                param2Range: (p.param2First, p.param2Last),
                point: SIMD3(p.pointX, p.pointY, p.pointZ)
            )
        }
    }

    /// Result of a face-face intersection curve.
    public struct FaceFaceCurve: Sendable {
        /// Start point of the intersection curve (if bounded).
        public let start: SIMD3<Double>?
        /// End point of the intersection curve (if bounded).
        public let end: SIMD3<Double>?
    }

    /// Result of a face-face intersection point.
    public struct FaceFacePoint: Sendable {
        /// Point on face 1.
        public let pointOnFace1: SIMD3<Double>
        /// Point on face 2.
        public let pointOnFace2: SIMD3<Double>
    }

    /// Result of face-face intersection.
    public struct FaceFaceResult: Sendable {
        /// Intersection curves.
        public let curves: [FaceFaceCurve]
        /// Intersection points.
        public let points: [FaceFacePoint]
        /// Whether the faces are tangent.
        public let isTangent: Bool
    }

    /// Intersect two faces to find intersection curves and points.
    ///
    /// Uses IntTools_FaceFace with full approximation.
    ///
    /// - Parameters:
    ///   - other: Face to intersect with
    ///   - tolerance: Approximation tolerance (default 1e-7)
    /// - Returns: Face-face intersection result, or nil if failed
    public func faceFaceIntersection(with other: Shape, tolerance: Double = 1e-7) -> FaceFaceResult?
    {
        var curves: UnsafeMutablePointer<OCCTFaceFaceCurve>?
        var curveCount: Int32 = 0
        var points: UnsafeMutablePointer<OCCTFaceFacePoint>?
        var pointCount: Int32 = 0
        var tangent = false
        guard
            OCCTIntToolsFaceFace(
                handle, other.handle, tolerance,
                &curves, &curveCount,
                &points, &pointCount,
                &tangent)
        else { return nil }
        defer {
            curves?.deallocate()
            points?.deallocate()
        }

        let curveArray = (0..<Int(curveCount)).map { i in
            let c = curves![i]
            return FaceFaceCurve(
                start: c.hasStart ? SIMD3(c.startX, c.startY, c.startZ) : nil,
                end: c.hasEnd ? SIMD3(c.endX, c.endY, c.endZ) : nil
            )
        }

        let pointArray = (0..<Int(pointCount)).map { i in
            let p = points![i]
            return FaceFacePoint(
                pointOnFace1: SIMD3(p.x1, p.y1, p.z1),
                pointOnFace2: SIMD3(p.x2, p.y2, p.z2)
            )
        }

        return FaceFaceResult(curves: curveArray, points: pointArray, isTangent: tangent)
    }

    // MARK: - IntTools_BeanFaceIntersector (v0.71.0)

    /// Result of edge-face intersection using IntTools_BeanFaceIntersector.
    public struct BeanFaceIntersection: Sendable {
        /// Coincident parameter ranges on the edge curve.
        public let ranges: [(first: Double, last: Double)]
        /// Minimum square distance between edge and face.
        public let minSquareDistance: Double
    }

    /// Intersect an edge curve with a face surface to find coincident ranges.
    ///
    /// Uses IntTools_BeanFaceIntersector to find where the edge lies on the face.
    /// - Parameters:
    ///   - edge: Edge shape to test.
    ///   - face: Face shape to test against.
    /// - Returns: Intersection result with ranges and minimum distance, or nil on failure.
    public static func beanFaceIntersect(edge: Shape, face: Shape) -> BeanFaceIntersection? {
        var ranges: UnsafeMutablePointer<OCCTParameterRange>?
        var count: Int32 = 0
        var minDist: Double = 0
        guard OCCTIntToolsBeanFaceIntersect(edge.handle, face.handle, &ranges, &count, &minDist)
        else {
            return nil
        }
        var result: [(first: Double, last: Double)] = []
        if let ranges = ranges {
            for i in 0..<Int(count) {
                result.append((first: ranges[i].first, last: ranges[i].last))
            }
            free(ranges)
        }
        return BeanFaceIntersection(ranges: result, minSquareDistance: minDist)
    }
    /// Result of shape-to-shape distance computation.
    public struct DistanceSSResult {
        public let distance: Double
        public let point1: SIMD3<Double>
        public let point2: SIMD3<Double>
        public let solutionCount: Int
        public let isDone: Bool
    }

    /// Compute the minimum distance between two sub-shapes using BRepExtrema_DistanceSS.
    public func distanceSS(to other: Shape, deflection: Double = 100.0) -> DistanceSSResult {
        let r = OCCTBRepExtremaDistanceSS(handle, other.handle, deflection)
        return DistanceSSResult(
            distance: r.distance,
            point1: SIMD3(r.point1X, r.point1Y, r.point1Z),
            point2: SIMD3(r.point2X, r.point2Y, r.point2Z),
            solutionCount: Int(r.solutionCount),
            isDone: r.isDone)
    }
    /// Result of Gauss-Kronrod volume integration on a face.
    ///
    /// ``center`` is nil when ``mass`` is 0, and also when `computeCG` was false, since no centre
    /// was asked for. Both used to report (0,0,0), which is indistinguishable from a real centroid
    /// at the origin (#609).
    ///
    /// ``errorReached`` is `BRepGProp_VinertGK::GetErrorReached()`. It used to be hardcoded to `0.0`
    /// on every call. `GetErrorReached()` is defined inline in the OCCT header, which is why it has
    /// no linkable symbol, not evidence it is unusable (#732). There is no paired absolute-error
    /// field: `BRepGProp_VinertGK::GetAbsolutError()` is declared in the same header but has no
    /// definition anywhere in the OCCT 8.0.1 sources, so calling it fails at link time, confirmed by
    /// compiling against it.
    ///
    /// **``errorReached`` is not unconditionally relative.** Reading `BRepGProp_VinertGK.cxx` (around
    /// line 492) shows two branches: the raw quadrature residual is divided by `|mass|` to produce a
    /// relative fraction only when `|mass|` clears an internal floor (`Epsilon()` of the residual
    /// itself, i.e. its own floating-point ULP, on the order of `1e-19` to `1e-25` for a realistic
    /// residual); below that floor, division is skipped and the undivided absolute residual is
    /// returned instead, with no signal in the return value distinguishing which branch ran.
    /// Multiplying ``errorReached`` by ``mass`` to recover an absolute figure is correspondingly
    /// unsound in that second branch (the un-normalized value is kept as-is, not divided), which is
    /// why that derivation was rejected rather than shipped as a second field.
    ///
    /// **That second branch could not be exercised through the public API to pin its behaviour
    /// directly** (measured for the PR #738 review): the floor is set relative to the residual's own
    /// ULP, so triggering it needs `|mass|` to underflow to essentially bit-exact `0.0`, not merely
    /// small. Driving a genuinely curved face's mass toward zero, using a half-cylinder lateral face
    /// (`u` spanning less than a full period, whose mass is provably affine in a location offset,
    /// solved for its exact root from two measurements), bottoms out around `1e-14`, the
    /// double-precision noise floor for an integral at this scale, five to ten orders of magnitude
    /// short of the threshold. The only realistic way to force literal-zero mass is a face whose
    /// integrand is identically zero pointwise (e.g. a planar face exactly coplanar with
    /// `location`), and that same degeneracy makes the residual identically zero too, so the two
    /// branches are observably indistinguishable in every case this API can actually construct.
    ///
    /// What **is** observable, and is what the regression test below pins: short of that
    /// unreachable branch, ``errorReached`` keeps behaving as a genuine relative fraction as `mass`
    /// shrinks. It grows, staying finite and non-negative, rather than quietly staying small or
    /// misreporting high confidence right where a caller most needs a reliable number. Treat a large
    /// (or growing) ``errorReached`` as a signal to distrust ``mass``, not the reverse.
    public struct VinertGKResult {
        public let mass: Double
        public let errorReached: Double
        public let center: SIMD3<Double>?
    }

    /// Compute volume properties of a face using Gauss-Kronrod integration.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let r = Shape.fromFace(box.faces()[0])!.vinertGK(tolerance: 1e-4)
    /// r.mass          // this face's volume contribution about the location point
    /// r.errorReached  // the relative integration error reached, nonzero on curved faces
    /// r.center        // its centroid, nil when the contribution is 0 or computeCG was false
    /// ```
    public func vinertGK(
        location: SIMD3<Double> = SIMD3(0, 0, 0),
        tolerance: Double = 0.001, computeCG: Bool = true
    ) -> VinertGKResult {
        let r = OCCTBRepGPropVinertGK(
            handle, location.x, location.y, location.z,
            tolerance, computeCG)
        return VinertGKResult(
            mass: r.mass, errorReached: r.errorReached,
            center: (computeCG && r.mass != 0) ? SIMD3(r.centerX, r.centerY, r.centerZ) : nil)
    }

    /// Volumetric centroid of this shape, or nil when the shape encloses no volume.
    ///
    /// Nil for a face, wire, edge, vertex or open shell. It used to return the shape's **location
    /// origin** in those cases: a face moved to (100,200,300) reported exactly that, and moved
    /// again reported (200,400,600), so the wrong answer tracked the part around and no caller
    /// could recognise it (#609). For a sheet body use ``surfaceInertia``; for a wire or edge use
    /// ``linearProperties()``; for a vertex position use `vertices().first`.
    ///
    /// ```swift
    /// let cone = Shape.cone(bottomRadius: 10, topRadius: 0, height: 20)!
    /// cone.centroid                               // (0, 0, 5), a quarter of the way up
    /// Shape.fromFace(cone.faces()[0])?.centroid   // nil, was the location origin
    /// ```
    public var centroid: SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        guard OCCTShapeCentroid(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Total length of all edges in this shape.
    public var totalEdgeLength: Double {
        OCCTShapeTotalEdgeLength(handle)
    }
}

extension Shape {
    /// Canonical geometry type for detailed recognition.
    public enum CanonicalGeometryType: Int, Sendable {
        case none = 0
        case plane = 1
        case cylinder = 2
        case cone = 3
        case sphere = 4
        case line = 5
        case circle = 6
        case ellipse = 7
    }

    /// Detailed canonical recognition result with geometry parameters.
    public struct CanonicalRecognitionResult: Sendable {
        public let type: CanonicalGeometryType
        public let gap: Double
        public let origin: (x: Double, y: Double, z: Double)
        public let direction: (x: Double, y: Double, z: Double)
        public let param1: Double
        public let param2: Double
    }

    /// Shared field-by-field unmarshaling for ``recognizeCanonicalSurface(tolerance:)`` and
    /// ``recognizeCanonicalCurve(tolerance:)`` (#796): the two differ only in which bridge call
    /// produces the raw `OCCTCanonicalResult`, not in how it's decoded.
    private static func canonicalRecognitionResult(from r: OCCTCanonicalResult)
        -> CanonicalRecognitionResult
    {
        CanonicalRecognitionResult(
            type: CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none,
            gap: r.gap,
            origin: (r.originX, r.originY, r.originZ),
            direction: (r.dirX, r.dirY, r.dirZ),
            param1: r.param1,
            param2: r.param2
        )
    }

    /// Recognize canonical surface geometry from a face with detailed parameters.
    public func recognizeCanonicalSurface(tolerance: Double = 0.01) -> CanonicalRecognitionResult {
        Shape.canonicalRecognitionResult(
            from: OCCTShapeRecognizeCanonicalSurface(handle, tolerance))
    }

    /// Recognize canonical curve geometry from an edge with detailed parameters.
    public func recognizeCanonicalCurve(tolerance: Double = 0.01) -> CanonicalRecognitionResult {
        Shape.canonicalRecognitionResult(from: OCCTShapeRecognizeCanonicalCurve(handle, tolerance))
    }
}

extension Shape {

    /// Count boundary edges of a face using BRepGProp_Domain.
    public func faceDomainEdgeCount(faceIndex: Int) -> Int {
        Int(OCCTShapeFaceDomainEdgeCount(handle, Int32(faceIndex)))
    }
}

extension Shape {

    /// A pair of overlapping face indices detected by self-intersection analysis.
    public struct OverlapPair: Sendable {
        public let faceIndex1: Int
        public let faceIndex2: Int
    }

    /// Detect self-intersecting face pairs in this shape.
    ///
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - tolerance: Overlap tolerance (default: 0.0).
    ///   - maxPairs: Output *capacity* (default: 100), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    ///   - deflection: Linear mesh deflection (mm) for the detection triangulation. Default `0.1`.
    /// - Returns: Array of overlapping face index pairs, empty if none found.
    public func selfIntersectionPairs(
        tolerance: Double = 0.0,
        maxPairs: Int = 100,
        deflection: Double = 0.1
    ) -> [OverlapPair] {
        let maxPairs = Sampling.capacity(maxPairs)
        guard maxPairs > 0 else { return [] }
        var idx1 = [Int32](repeating: 0, count: maxPairs)
        var idx2 = [Int32](repeating: 0, count: maxPairs)
        let count = OCCTShapeSelfIntersectionPairs(
            handle, tolerance, &idx1, &idx2, Int32(maxPairs), deflection)
        guard count > 0 else { return [] }
        return (0..<Int(count)).map {
            OverlapPair(faceIndex1: Int(idx1[$0]), faceIndex2: Int(idx2[$0]))
        }
    }
}

// MARK: - BRepLProp Edge Extensions (v0.111.0)
//
// These read an edge through a `BRepAdaptor_Curve`, where `Curve3D.localCurvature` and friends read
// the curve underneath directly. Since #529 both spellings decide whether a quantity exists at the
// same resolution (`Precision::Confusion()`), so they agree about definedness at every parameter of
// every edge; they still differ in the last bits of the values themselves, because the adaptor
// evaluates a Bezier or BSpline through a cache the raw handle does not use.

extension Shape {

    /// Point on an edge at `param`, through the edge's own adaptor (`BRepLProp_CLProps`).
    ///
    /// Returns nil for a parameter the edge cannot be evaluated at. Before #529 it returned
    /// `(0, 0, 0)` there, wrapped in a non-nil optional.
    ///
    /// ```swift
    /// let edge = Shape.box(width: 10, height: 10, depth: 10)!.subShapes(ofType: .edge)[0]
    /// if let p = edge.edgeLPropValue(at: 5.0) {
    ///     print("point at t=5: \(p)")
    /// }
    /// ```
    public func edgeLPropValue(at param: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        let ok = OCCTEdgeLPropValue(handle, param, &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// Get tangent direction on an edge at parameter.
    ///
    /// Returns nil if tangent is undefined.
    public func edgeTangent(at param: Double) -> SIMD3<Double>? {
        var dx = 0.0
        var dy = 0.0
        var dz = 0.0
        let ok = OCCTEdgeLPropTangent(handle, param, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Curvature on an edge at `param`, through the edge's own adaptor.
    ///
    /// - Parameter param: Parameter on the edge's curve.
    /// - Returns: The curvature, or `nil` where this `Shape` is not an edge, the parameter cannot
    ///   be evaluated, or the tangent is undefined there. That last case used to be `0`, which is
    ///   also a straight edge's real curvature (#595). It is not exotic: a sphere carries a
    ///   **degenerate edge at each pole**, with no 3D curve at all, and edge traversal does not
    ///   skip them.
    ///
    /// `Double.greatestFiniteMagnitude` (OCCT's `RealLast()`, meaning infinite curvature) is still
    /// reported at a cusp, an answer, not an absence, matching ``Curve3D/curvature(at:)`` on the
    /// curve underneath.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4)!
    /// let edge = Shape.edgeFromCurve(arc)!
    /// let k = edge.edgeCurvatureLP(at: 0.5)   // 0.25, the reciprocal of the radius
    /// ```
    public func edgeCurvatureLP(at param: Double) -> Double? {
        var k = 0.0
        guard OCCTEdgeLPropCurvature(handle, param, &k) else { return nil }
        return k
    }

    /// Normal direction on an edge at `param`.
    ///
    /// Returns nil where the curvature cannot be inverted into a direction: a straight stretch has
    /// no normal, and neither does a cusp. Before #529 both cases returned `(0, 0, 0)`, which is
    /// not a direction.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4)!
    /// let edge = Shape.edgeFromCurve(arc)!
    /// if let n = edge.edgeNormalLP(at: 0) { print("points at the centre: \(n)") }
    /// ```
    public func edgeNormalLP(at param: Double) -> SIMD3<Double>? {
        var dx = 0.0
        var dy = 0.0
        var dz = 0.0
        let ok = OCCTEdgeLPropNormal(handle, param, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Centre of curvature on an edge at `param`, the centre of the circle that osculates the edge
    /// there.
    ///
    /// Returns nil wherever there is no such circle, on the same terms as ``edgeNormalLP(at:)``.
    /// Before #529 a near-cusp returned `(nan, inf, nan)` as though it were a point.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: SIMD3(1, 2, 0), normal: SIMD3(0, 0, 1), radius: 4)!
    /// let edge = Shape.edgeFromCurve(arc)!
    /// if let c = edge.edgeCentreOfCurvature(at: 0) { print(c) }   // ~ (1, 2, 0)
    /// ```
    public func edgeCentreOfCurvature(at param: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        let ok = OCCTEdgeLPropCentreOfCurvature(handle, param, &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// First derivative on an edge at `param`.
    ///
    /// Returns nil for a parameter the edge cannot be evaluated at.
    public func edgeLPropD1(at param: Double) -> SIMD3<Double>? {
        var d1x = 0.0
        var d1y = 0.0
        var d1z = 0.0
        let ok = OCCTEdgeLPropD1(handle, param, &d1x, &d1y, &d1z)
        return ok ? SIMD3(d1x, d1y, d1z) : nil
    }
}

extension Shape {

    /// Point on a face at (u, v), through the face's own adaptor (`BRepLProp_SLProps`).
    ///
    /// Returns nil if the receiver is not a single face, the same contract
    /// ``faceLPropMeanCurvature(u:v:)`` and its siblings use, except that the point does not depend
    /// on the curvature gate, so it is still reported at a cone apex or a sphere pole. Before #583
    /// a non-face `Shape` came back as `(0, 0, 0)`, which is a real point of most surfaces.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!
    /// if let p = cylinder.subShapes(ofType: .face)[0].faceLPropValue(u: 1.1, v: 6) {
    ///     print(p)
    /// }
    /// ```
    public func faceLPropValue(u: Double, v: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        let ok = OCCTFaceLPropValue(handle, u, v, &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// Get normal on a face at (u, v).
    ///
    /// Returns nil if normal is undefined.
    public func faceLPropNormal(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0
        var dy = 0.0
        var dz = 0.0
        let ok = OCCTFaceLPropNormal(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Maximum principal curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// Nil is a cone apex, a sphere pole, or a receiver that is not a face. `0` is a value in its
    /// own right: it is the maximum curvature at every point of a cylinder or a cone. Before #583
    /// the two were the same answer.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// let kMax = cylinder.faceLPropMaxCurvature(u: 1.1, v: 6)   // 0, along the axis, not nil
    /// ```
    public func faceLPropMaxCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropMaxCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Minimum principal curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// Nil on the same terms as ``faceLPropMaxCurvature(u:v:)``.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// let kMin = cylinder.faceLPropMinCurvature(u: 1.1, v: 6)   // -1/3, the reciprocal radius
    /// ```
    public func faceLPropMinCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropMinCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Mean curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// The adaptor-backed counterpart of ``Face/meanCurvature(atU:v:)``, which has always been
    /// optional; since #529 the two agree about where curvature exists, and since #583 both can
    /// say so.
    ///
    /// ```swift
    /// let sphere = Shape.sphere(radius: 5)!.subShapes(ofType: .face)[0]
    /// if let h = sphere.faceLPropMeanCurvature(u: 0, v: 0) { print(h) }   // -0.2, i.e. -1/r
    /// ```
    public func faceLPropMeanCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropMeanCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Gaussian curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// The adaptor-backed counterpart of ``Face/gaussianCurvature(atU:v:)``. `0` is the answer at
    /// every point of any developable surface (a cylinder, a cone, a plane), so this getter
    /// returned the pre-#583 "undefined" sentinel for whole faces at a time.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// #expect(cylinder.faceLPropGaussianCurvature(u: 1.1, v: 6) == 0)   // defined, and zero
    /// ```
    public func faceLPropGaussianCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropGaussianCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Whether a face is umbilic at (u, v), meaning both principal curvatures are equal, or nil
    /// where there are no principal curvatures to compare.
    ///
    /// OCCT's test is one ULP wide rather than a geometric tolerance, so a plane qualifies
    /// everywhere but an analytically-umbilic sphere qualifies only where the two computed values
    /// round to the same `Double`. Before #583 a cone apex answered `false`, claiming the two
    /// curvatures differ there.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// #expect(cylinder.faceLPropIsUmbilic(u: 1.1, v: 6) == false)   // defined, and not umbilic
    /// ```
    public func faceLPropIsUmbilic(u: Double, v: Double) -> Bool? {
        var isUmbilic = false
        let ok = OCCTFaceLPropIsUmbilic(handle, u, v, &isUmbilic)
        return ok ? isUmbilic : nil
    }
}

extension Shape {

    /// Linear properties result (length + center of mass).
    public struct LinearProperties: Sendable {
        public let length: Double
        public let centerOfMass: SIMD3<Double>
    }

    /// Get linear properties (total length and center of mass) for edges/wires.
    ///
    /// Nil for a shape with no edges, such as a lone vertex. The centre of mass reported there was
    /// the shape's location origin, not a recognisable zero (#609).
    ///
    /// - Warning: `length` here comes from `BRepGProp::LinearProperties`, which runs its own
    ///   integrator, one fixed-order Gauss rule per span, the defect #603 fixed everywhere else.
    ///   On an elliptical edge it reports 41.243158 against a true 40.639742 (+1.485%) and so
    ///   **disagrees with ``Shape/edgeArcLength``**, which measures 40.639742. Before #603 both
    ///   were wrong together. Use ``Shape/edgeArcLength`` or ``Wire/length`` when you want the
    ///   length; this call remains the way to get the centre of mass.
    ///
    /// ```swift
    /// let wire = Shape.fromWire(Wire.rectangle(width: 10, height: 20)!)!
    /// wire.linearProperties()?.length   // 60
    ///
    /// let vertex = Shape.box(width: 10, height: 10, depth: 10)!.subShapes(ofType: .vertex)[0]
    /// vertex.linearProperties()         // nil, a vertex has no length and no centroid
    /// ```
    public func linearProperties() -> LinearProperties? {
        var length = 0.0
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        guard OCCTShapeLinearProperties(handle, &length, &cx, &cy, &cz) else { return nil }
        return LinearProperties(length: length, centerOfMass: SIMD3(cx, cy, cz))
    }

    /// Inertia tensor result.
    public struct InertiaTensor: Sendable {
        public let ixx: Double, iyy: Double, izz: Double
        public let ixy: Double, ixz: Double, iyz: Double
    }

    /// Get the inertia tensor (moment of inertia matrix) for a volumetric shape.
    ///
    /// Nil for a shape with no closed volume, where the tensor is identically zero and
    /// indistinguishable from a real answer for a shape that happens to have no moments (#609).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// box.momentOfInertia()?.ixx                          // 650000
    /// Shape.fromFace(box.faces()[0])?.momentOfInertia()   // nil, a face has no volume
    /// ```
    public func momentOfInertia() -> InertiaTensor? {
        var ixx = 0.0
        var iyy = 0.0
        var izz = 0.0
        var ixy = 0.0
        var ixz = 0.0
        var iyz = 0.0
        guard OCCTShapeMomentOfInertia(handle, &ixx, &iyy, &izz, &ixy, &ixz, &iyz) else {
            return nil
        }
        return InertiaTensor(ixx: ixx, iyy: iyy, izz: izz, ixy: ixy, ixz: ixz, iyz: iyz)
    }

    /// Principal axes of inertia (3 direction vectors).
    public struct PrincipalAxes: Sendable {
        public let axis1: SIMD3<Double>
        public let axis2: SIMD3<Double>
        public let axis3: SIMD3<Double>
    }

    /// Get the principal axes of inertia.
    ///
    /// Nil for a shape with no closed volume. It used to return three orthonormal unit vectors
    /// there, which look like a real answer but are just the identity basis that OCCT's Jacobi
    /// eigensolver returns for the zero inertia matrix (#609).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// box.principalAxes()?.axis1                       // a real principal direction
    /// Shape.fromFace(box.faces()[0])?.principalAxes()  // nil, was (0,0,1)/(1,0,0)/(0,1,0)
    /// ```
    public func principalAxes() -> PrincipalAxes? {
        var axes = [Double](repeating: 0, count: 9)
        guard OCCTShapePrincipalAxes(handle, &axes) else { return nil }
        return PrincipalAxes(
            axis1: SIMD3(axes[0], axes[1], axes[2]),
            axis2: SIMD3(axes[3], axes[4], axes[5]),
            axis3: SIMD3(axes[6], axes[7], axes[8])
        )
    }

    /// Get the radius of gyration about an axis defined by a point and direction.
    ///
    /// Nil for a shape with no closed volume. OCCT computes this as `sqrt(momentOfInertia / mass)`
    /// with no guard, so it used to return **NaN** there, which propagates silently through any
    /// arithmetic that consumes it (#609).
    ///
    /// ```swift
    /// let cyl = Shape.cylinder(radius: 3, height: 10)!
    /// cyl.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0, 0, 1))   // 2.12
    ///
    /// let sheet = Shape.fromFace(cyl.faces()[0])!
    /// sheet.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0, 0, 1)) // nil, was NaN
    /// ```
    public func radiusOfGyration(axisOrigin: SIMD3<Double>, direction: SIMD3<Double>) -> Double? {
        var radius = 0.0
        guard
            OCCTShapeRadiusOfGyration(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                direction.x, direction.y, direction.z,
                &radius)
        else { return nil }
        return radius
    }
}

extension Shape {
    /// Axis-aligned bounding box of the shape.
    ///
    /// Returns `nil` only when the box is void (e.g. an empty shape), a genuinely
    /// degenerate/point shape at the world origin legitimately returns `(min: .zero, max: .zero)`
    /// rather than `nil` (#900).
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        unwrapAxisComponentsIfSuccessful { OCCTShapeBoundingBox(handle, $0, $1, $2, $3, $4, $5) }
    }

    /// Optimal (tight) axis-aligned bounding box using precise geometry.
    ///
    /// Returns `nil` only when the box is void (e.g. an empty shape), see ``boundingBox`` (#900).
    public func boundingBoxOptimal(useShapeTolerance: Bool = false) -> (
        min: SIMD3<Double>, max: SIMD3<Double>
    )? {
        unwrapAxisComponentsIfSuccessful {
            OCCTShapeBoundingBoxOptimal(handle, useShapeTolerance, $0, $1, $2, $3, $4, $5)
        }
    }

    /// Oriented bounding box with axes and half-sizes as three separate scalars.
    ///
    /// Same underlying `Bnd_OBB` as ``OrientedBoundingBox`` (#847), prefer
    /// ``orientedBoundingBox(optimal:)`` for the packed ``SIMD3<Double>`` half-sizes and the
    /// computed ``OrientedBoundingBox/volume``/``OrientedBoundingBox/dimensions`` it offers; this
    /// type exists for callers that specifically want the half-sizes as individual `Double`s.
    public struct DetailedOBB: Sendable {
        /// Center of the oriented bounding box.
        public let center: SIMD3<Double>
        /// Local X axis direction.
        public let xDirection: SIMD3<Double>
        /// Local Y axis direction.
        public let yDirection: SIMD3<Double>
        /// Local Z axis direction.
        public let zDirection: SIMD3<Double>
        /// Half-extent along ``xDirection``.
        public let xHalfSize: Double
        /// Half-extent along ``yDirection``.
        public let yHalfSize: Double
        /// Half-extent along ``zDirection``.
        public let zHalfSize: Double
    }

    /// Compute oriented bounding box with detailed axis information.
    ///
    /// Computes the identical `Bnd_OBB` as ``orientedBoundingBox(optimal:)`` (#847), the two
    /// never disagree for the same shape and `optimal` value, but returns the half-sizes as
    /// three separate `Double`s instead of one packed `SIMD3<Double>`, and has no `volume`,
    /// `dimensions` or corners equivalent. Use ``orientedBoundingBox(optimal:)`` unless you
    /// specifically need the half-sizes unpacked this way.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// let obb = box.orientedBoundingBoxDetailed()!
    /// obb.xHalfSize   // half the box's extent along the OBB's local X axis
    /// ```
    ///
    /// - Parameter optimal: If true, compute a tighter OBB (slower). Default is false.
    /// - Returns: The oriented bounding box, or nil on failure.
    public func orientedBoundingBoxDetailed(optimal: Bool = false) -> DetailedOBB? {
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        var xDx = 0.0
        var xDy = 0.0
        var xDz = 0.0
        var yDx = 0.0
        var yDy = 0.0
        var yDz = 0.0
        var zDx = 0.0
        var zDy = 0.0
        var zDz = 0.0
        var xHS = 0.0
        var yHS = 0.0
        var zHS = 0.0
        var isVoid = false
        OCCTShapeOrientedBoundingBoxDetailed(
            handle, optimal,
            &cx, &cy, &cz,
            &xDx, &xDy, &xDz,
            &yDx, &yDy, &yDz,
            &zDx, &zDy, &zDz,
            &xHS, &yHS, &zHS,
            &isVoid)
        if isVoid { return nil }
        return DetailedOBB(
            center: SIMD3(cx, cy, cz),
            xDirection: SIMD3(xDx, xDy, xDz),
            yDirection: SIMD3(yDx, yDy, yDz),
            zDirection: SIMD3(zDx, zDy, zDz),
            xHalfSize: xHS, yHalfSize: yHS, zHalfSize: zHS)
    }
}
