import Foundation
import OCCTBridge
import simd

extension Shape {

    // MARK: - Surface Creation (v0.9.0)

    /// Create a B-spline surface from a grid of control points.
    ///
    /// The surface interpolates approximately through the control point grid.
    /// Control points are specified in row-major order (U varies fastest).
    ///
    /// - Parameters:
    ///   - poles: 2D array of control points [uIndex][vIndex]
    ///   - uDegree: Degree in U direction (default 3 for cubic)
    ///   - vDegree: Degree in V direction (default 3 for cubic)
    /// - Returns: A face shape from the B-spline surface, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a 4x4 control point grid for a curved surface
    /// let poles: [[SIMD3<Double>]] = [
    ///     [SIMD3(0, 0, 0), SIMD3(0, 10, 0), SIMD3(0, 20, 0), SIMD3(0, 30, 0)],
    ///     [SIMD3(10, 0, 2), SIMD3(10, 10, 2), SIMD3(10, 20, 2), SIMD3(10, 30, 2)],
    ///     [SIMD3(20, 0, 2), SIMD3(20, 10, 2), SIMD3(20, 20, 2), SIMD3(20, 30, 2)],
    ///     [SIMD3(30, 0, 0), SIMD3(30, 10, 0), SIMD3(30, 20, 0), SIMD3(30, 30, 0)]
    /// ]
    /// let surface = Shape.surface(poles: poles)
    /// ```
    public static func surface(
        poles: [[SIMD3<Double>]],
        uDegree: Int = 3,
        vDegree: Int = 3
    ) -> Shape? {
        guard !poles.isEmpty, let firstRow = poles.first, !firstRow.isEmpty else { return nil }

        let uCount = poles.count
        let vCount = firstRow.count

        // Verify all rows have the same count
        for row in poles {
            guard row.count == vCount else { return nil }
        }

        guard uCount >= uDegree + 1, vCount >= vDegree + 1 else { return nil }

        // Flatten to array of doubles in row-major order
        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(uCount * vCount * 3)

        for row in poles {
            for point in row {
                flatPoles.append(point.x)
                flatPoles.append(point.y)
                flatPoles.append(point.z)
            }
        }

        return flatPoles.withUnsafeBufferPointer { buffer in
            guard
                let result = OCCTShapeCreateBSplineSurface(
                    buffer.baseAddress,
                    Int32(uCount),
                    Int32(vCount),
                    Int32(uDegree),
                    Int32(vDegree)
                )
            else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Surface Filling (v0.14.0)

    // `SurfaceContinuity` (formerly declared in Shape.swift beside the blends and filling code,
    // alongside a second `PlateConstraintOrder` copy of the same vocabulary) now lives in
    // Continuity.swift. It is the vocabulary `fill` and `plateSurface` below take. See #398.

    /// Fill an N-sided boundary with a smooth surface.
    ///
    /// Creates a surface that passes through the given boundary wires
    /// with the specified continuity.
    ///
    /// Tangency (`.g1`) and curvature (`.g2`) continuity need a surface to be continuous
    /// *with*. This overload uses each boundary edge's own underlying surface, so any
    /// continuity above `.c0` requires every boundary edge to have been borrowed from an
    /// existing face; a boundary built from free-standing wires has nothing to match and
    /// returns nil. To fill an opening smoothly into the shape around it, use
    /// ``fill(boundaries:supportedBy:parameters:)``; to name the reference face per edge,
    /// use ``fill(constraints:parameters:)``.
    ///
    /// - Parameters:
    ///   - boundaries: Array of wires defining the boundary
    ///   - parameters: Filling parameters (continuity, tolerance, etc.)
    /// - Returns: Face shape covering the boundary, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fill a 4-sided boundary with a smooth surface
    /// let wire1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
    /// let wire2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5))
    /// let wire3 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 3))
    /// let wire4 = Wire.line(from: SIMD3(0, 10, 3), to: SIMD3(0, 0, 0))
    ///
    /// // Free-standing wires have no surface to be tangent to, so fill positionally.
    /// let patch = Shape.fill(
    ///     boundaries: [wire1, wire2, wire3, wire4],
    ///     parameters: FillingParameters(continuity: .g0)
    /// )
    /// ```
    public static func fill(
        boundaries: [Wire],
        parameters: FillingParameters = FillingParameters()
    ) -> Shape? {
        guard !boundaries.isEmpty else { return nil }

        var handles = boundaries.map { $0.handle as OCCTWireRef? }

        guard
            let result = handles.withUnsafeMutableBufferPointer({ buffer in
                OCCTShapeFill(buffer.baseAddress, Int32(boundaries.count), parameters.cParams)
            })
        else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Fill an N-sided boundary, continuous with the shape surrounding it.
    ///
    /// The "cap this opening" case: each boundary edge takes its tangency/curvature
    /// reference from that edge's own face in `support`, so a `.g1` fill leaves the
    /// boundary along the surrounding walls instead of flat across them. A boundary edge
    /// that isn't part of `support` falls back to its own underlying surface, and failing
    /// that is constrained positionally.
    ///
    /// - Parameters:
    ///   - boundaries: Array of wires defining the boundary
    ///   - support: Shape whose faces supply the continuity reference
    ///   - parameters: Filling parameters (continuity, tolerance, etc.)
    /// - Returns: Face shape covering the boundary, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Cap the open top of a truncated sphere, tangent to the spherical wall
    /// let bowl = Shape.sphere(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1),
    ///                         radius: 10, angle1: -.pi / 2, angle2: 50 * .pi / 180)!
    ///
    /// // the open rim is the topmost closed edge
    /// let rim = bowl.edges()
    ///     .filter { $0.isClosed3D }
    ///     .max(by: { $0.bounds.max.z < $1.bounds.max.z })!
    ///
    /// let cap = Shape.fill(
    ///     boundaries: [Wire.wireFromEdges([rim])!],
    ///     supportedBy: bowl,
    ///     parameters: FillingParameters(continuity: .g1)
    /// )
    /// // cap leaves the rim along the sphere instead of closing it with a flat disc
    /// ```
    public static func fill(
        boundaries: [Wire],
        supportedBy support: Shape,
        parameters: FillingParameters = FillingParameters()
    ) -> Shape? {
        guard !boundaries.isEmpty else { return nil }

        var handles = boundaries.map { $0.handle as OCCTWireRef? }

        guard
            let result = handles.withUnsafeMutableBufferPointer({ buffer in
                OCCTShapeFillWithSupport(
                    buffer.baseAddress, Int32(boundaries.count),
                    support.handle, parameters.cParams)
            })
        else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Fill a surface from explicit per-edge constraints.
    ///
    /// The precise form of ``fill(boundaries:parameters:)``: every edge names its own
    /// reference face and continuity order, and may bound the resulting face or act as an
    /// internal constraint the surface must also satisfy. `parameters.continuity` is
    /// ignored — each constraint carries its own.
    ///
    /// - Parameters:
    ///   - constraints: Edge constraints defining the surface
    ///   - parameters: Filling parameters (tolerance, degree, segments; continuity unused)
    /// - Returns: Face shape satisfying the constraints, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Curvature-continuous against the wall the rim came from, positional elsewhere
    /// let wall = rim.adjacentFaces(in: bowl)!.0
    ///
    /// let patch = Shape.fill(constraints: [
    ///     FillConstraint(edge: rim, support: wall, continuity: .g2),
    ///     FillConstraint(edge: freeEdge, continuity: .g0)
    /// ])
    /// ```
    public static func fill(
        constraints: [FillConstraint],
        parameters: FillingParameters = FillingParameters()
    ) -> Shape? {
        guard !constraints.isEmpty else { return nil }

        var cConstraints = constraints.map { constraint in
            OCCTFillConstraint(
                edge: constraint.edge.handle,
                support: constraint.support?.handle,
                continuity: constraint.continuity.rawValue,
                isBound: constraint.isBoundary ? 1 : 0
            )
        }

        // cConstraints holds raw handles owned by the Edge/Face objects in `constraints`;
        // withExtendedLifetime keeps those owners alive across the call rather than relying on
        // the optimiser not releasing them early.
        let handle = withExtendedLifetime(constraints) {
            cConstraints.withUnsafeMutableBufferPointer { buffer in
                OCCTShapeFillConstraints(
                    buffer.baseAddress, Int32(constraints.count),
                    parameters.cParams)
            }
        }

        guard let handle = handle else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Plate Surfaces (v0.14.0)

    /// Create a surface constrained to pass through specific points.
    ///
    /// Uses a plate surface algorithm to create a smooth surface
    /// that interpolates through all given points.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points the surface must pass through
    ///   - tolerance: Surface approximation tolerance
    /// - Returns: Surface face, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a surface through scattered points
    /// let surface = Shape.plateSurface(
    ///     through: [
    ///         SIMD3(0, 0, 0),
    ///         SIMD3(10, 0, 1),
    ///         SIMD3(10, 10, 2),
    ///         SIMD3(0, 10, 1),
    ///         SIMD3(5, 5, 3)  // Point in middle raises surface
    ///     ],
    ///     tolerance: 0.01
    /// )
    /// ```
    public static func plateSurface(
        through points: [SIMD3<Double>],
        tolerance: Double = 0.01
    ) -> Shape? {
        guard points.count >= 3 else { return nil }

        var flatPoints: [Double] = []
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        guard
            let result = OCCTShapePlatePoints(
                &flatPoints,
                Int32(points.count),
                tolerance
            )
        else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Create a surface constrained by boundary curves.
    ///
    /// Uses a plate surface algorithm to create a smooth surface
    /// that follows the given boundary curves with specified continuity.
    ///
    /// - Parameters:
    ///   - curves: Array of wires defining boundary constraints
    ///   - continuity: Continuity requirement at boundaries
    ///   - tolerance: Surface approximation tolerance
    /// - Returns: Surface face, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a surface bounded by curves
    /// let curve1 = Wire.bspline([...])
    /// let curve2 = Wire.bspline([...])
    ///
    /// let surface = Shape.plateSurface(
    ///     constrainedBy: [curve1, curve2],
    ///     continuity: .g1,
    ///     tolerance: 0.01
    /// )
    /// ```
    public static func plateSurface(
        constrainedBy curves: [Wire],
        continuity: SurfaceContinuity = .g1,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard !curves.isEmpty else { return nil }

        var handles = curves.map { $0.handle as OCCTWireRef? }

        guard
            let result = handles.withUnsafeMutableBufferPointer({ buffer in
                OCCTShapePlateCurves(
                    buffer.baseAddress,
                    Int32(curves.count),
                    continuity.rawValue,
                    tolerance
                )
            })
        else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Advanced Plate Surfaces (v0.23.0)

    /// Create a plate surface through points with specified constraint orders per point.
    ///
    /// Each point can independently specify G0 (position only) or G1 (position + tangent)
    /// continuity. **`.g2` always returns `nil`**: a bare point carries no curvature to match,
    /// so `GeomPlate_PointConstraint` rejects order 2 outright (#437). This is checked here,
    /// before any constraint is built; see ``SurfaceContinuity/isUnsupportedForPointConstraint``.
    ///
    /// ```swift
    /// // .g2 anywhere in `orders` is rejected up front; the call below is always nil.
    /// let rejected = Shape.plateSurface(through: points,
    ///                                    orders: Array(repeating: .g2, count: points.count))
    /// ```
    ///
    /// - Parameters:
    ///   - points: Array of 3D points the surface must satisfy
    ///   - orders: Constraint order per point (`.g0` or `.g1`; `.g2` is rejected, see above)
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - pointsOnCurves: Number of sample points on curves (default 15)
    ///   - iterations: Number of solver iterations (default 2)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: Surface face, or nil on failure
    public static func plateSurface(
        through points: [SIMD3<Double>],
        orders: [SurfaceContinuity],
        degree: Int = 3,
        pointsOnCurves: Int = 15,
        iterations: Int = 2,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard points.count >= 3, points.count == orders.count else { return nil }
        guard !Shape.plateRejectsPointOrders(orders) else { return nil }

        var flatPoints: [Double] = []
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }
        var rawOrders = orders.map { Int32($0.rawValue) }

        guard
            let result = OCCTShapePlatePointsAdvanced(
                &flatPoints, Int32(points.count),
                &rawOrders, Int32(degree),
                Int32(pointsOnCurves), Int32(iterations),
                tolerance
            )
        else { return nil }
        return Shape(handle: result)
    }

    /// Whether any order in a batch of *point* constraints would fail
    /// Checks if any order fails the point constraint domain check (#437).
    ///
    /// Tests whether any element is ``SurfaceContinuity/isUnsupportedForPointConstraint``.
    /// Shared implementation for both plate-point entry points' rejection guard:
    /// `plateSurface(through:orders:)` and, via ``plateMixedRejectsPointOrders(_:)``,
    /// `plateSurface(pointConstraints:curveConstraints:)`. Each passes its own `orders` shape
    /// (a flat array here, a `(point, order)` tuple array there), but both defer the actual
    /// domain question to this one function rather than each re-testing
    /// `isUnsupportedForPointConstraint` inline.
    static func plateRejectsPointOrders(_ orders: some Sequence<SurfaceContinuity>) -> Bool {
        orders.contains(where: \.isUnsupportedForPointConstraint)
    }

    /// Checks if any point constraint fails the point constraint domain check (#437).
    ///
    /// Thin adapter over ``plateRejectsPointOrders(_:)`` for the mixed overload's
    /// `(point, order)` tuple shape.
    /// Deliberately takes only `points`, not `curves`: `GeomPlate_CurveConstraint` has no such
    /// restriction, so curve orders must never be able to influence this decision. That is a
    /// property of this function's own *signature*, not just its body: there is no `curves`
    /// parameter for a future edit to reach for by mistake.
    static func plateMixedRejectsPointOrders(
        _ points: [(point: SIMD3<Double>, order: SurfaceContinuity)]
    ) -> Bool {
        plateRejectsPointOrders(points.map(\.order))
    }

    /// Create a plate surface with mixed point and curve constraints.
    ///
    /// Combines point constraints (each with its own continuity order) and
    /// curve constraints (wires with continuity orders) into a single plate surface.
    ///
    /// `.g2` is rejected up front for a **point** constraint (`GeomPlate_PointConstraint` rejects
    /// order 2 outright, #437) but is fine for a **curve** constraint (`GeomPlate_CurveConstraint`
    /// accepts order 2 directly); see ``SurfaceContinuity/isUnsupportedForPointConstraint``. Only
    /// `points`' orders are checked; `curves`' orders are not.
    ///
    /// ```swift
    /// // A point held to G0 alongside a rectangular boundary wire held to G0.
    /// // A .g2 point order here would make the whole call return nil (see above).
    /// let surface = Shape.plateSurface(
    ///     pointConstraints: [(point: SIMD3(5, 5, 3), order: .g0)],
    ///     curveConstraints: [(wire: boundaryWire, order: .g0)]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - points: Point constraints with positions and orders (`.g2` always rejected, see above)
    ///   - curves: Curve constraints with wires and orders
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: Surface face, or nil on failure
    public static func plateSurface(
        pointConstraints points: [(point: SIMD3<Double>, order: SurfaceContinuity)],
        curveConstraints curves: [(wire: Wire, order: SurfaceContinuity)],
        degree: Int = 3,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard !points.isEmpty || !curves.isEmpty else { return nil }
        guard !Shape.plateMixedRejectsPointOrders(points) else { return nil }

        var flatPoints: [Double] = []
        var pointOrders: [Int32] = []
        for (p, order) in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
            pointOrders.append(Int32(order.rawValue))
        }

        var wireHandles = curves.map { $0.wire.handle as OCCTWireRef? }
        var curveOrders = curves.map { Int32($0.order.rawValue) }

        let result: OCCTShapeRef? = flatPoints.withUnsafeMutableBufferPointer { ptBuf in
            pointOrders.withUnsafeMutableBufferPointer { ordBuf in
                wireHandles.withUnsafeMutableBufferPointer { wireBuf in
                    curveOrders.withUnsafeMutableBufferPointer { coBuf in
                        OCCTShapePlateMixed(
                            points.isEmpty ? nil : ptBuf.baseAddress,
                            points.isEmpty ? nil : ordBuf.baseAddress,
                            Int32(points.count),
                            curves.isEmpty ? nil : wireBuf.baseAddress,
                            curves.isEmpty ? nil : coBuf.baseAddress,
                            Int32(curves.count),
                            Int32(degree), tolerance
                        )
                    }
                }
            }
        }
        guard let result else { return nil }
        return Shape(handle: result)
    }
    /// Find the underlying surface of a shape (edges or wire).
    ///
    /// Determines the best-fit surface for a set of edges or a wire.
    /// Useful for reconstructing faces from imported wireframes.
    ///
    /// - Parameter tolerance: Surface fitting tolerance
    /// - Returns: The found surface, or nil
    public func findSurface(tolerance: Double = -1) -> Surface? {
        guard let h = OCCTShapeFindSurface(handle, tolerance) else { return nil }
        return Surface(handle: h)
    }
    /// Create a solid of revolution by revolving a meridian curve.
    ///
    /// Unlike `revolution(profile:...)` which takes a wire profile,
    /// this creates a revolution directly from a `Geom_Curve`.
    ///
    /// - Parameters:
    ///   - meridian: The curve to revolve
    ///   - axisOrigin: Origin point of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - angle: Revolution angle in radians (default: full revolution)
    /// - Returns: Revolved shape, or nil on failure
    public static func revolution(
        meridian: Curve3D,
        axisOrigin: SIMD3<Double> = .zero,
        axisDirection: SIMD3<Double> = SIMD3<Double>(0, 0, 1),
        angle: Double = 2 * .pi
    ) -> Shape? {
        guard
            let h = OCCTShapeCreateRevolutionFromCurve(
                meridian.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle)
        else { return nil }
        return Shape(handle: h)
    }
    /// Add a revolution form (revolved rib or groove) to a shape.
    ///
    /// Similar to `addingLinearRib`, but the rib follows a rotational
    /// path around the given axis.
    ///
    /// - Parameters:
    ///   - profile: Wire profile of the rib
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - height1: Height on one side
    ///   - height2: Height on the other side
    ///   - fuse: true for rib (add material), false for groove (remove material)
    /// - Returns: Shape with revolution form, or nil on failure
    public func addingRevolutionForm(
        profile: Wire,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        height1: Double, height2: Double,
        fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapeAddRevolutionForm(
                handle, profile.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                height1, height2, fuse)
        else { return nil }
        return Shape(handle: h)
    }
    /// Add a revolved feature (boss or pocket) to a shape.
    ///
    /// Revolves a profile around an axis to add or remove material.
    /// Commonly used for turned parts (lathe operations).
    ///
    /// - Parameters:
    ///   - profile: Wire profile to revolve
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - angle: Revolution angle in degrees
    ///   - fuse: true to add material (boss), false to cut (pocket)
    /// - Returns: Shape with revolved feature, or nil on failure
    public func addingRevolvedFeature(
        profile: Wire, sketchFaceIndex: Int,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double = 360,
        fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapeRevolFeature(
                handle, Int32(sketchFaceIndex),
                profile.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle, fuse)
        else { return nil }
        return Shape(handle: h)
    }

    /// Add a revolved feature that revolves through 360 degrees.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to revolve
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - fuse: true to add material, false to cut
    /// - Returns: Shape with revolved feature, or nil on failure
    public func addingRevolvedFeatureThruAll(
        profile: Wire, sketchFaceIndex: Int,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapeRevolFeatureThruAll(
                handle, Int32(sketchFaceIndex),
                profile.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                fuse)
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Pipe Feature (v0.39.0)

    /// Create a pipe feature by sweeping a profile along a spine, fused with or cut from this shape.
    ///
    /// - Parameters:
    ///   - profile: Profile shape (face) to sweep along the spine
    ///   - sketchFaceIndex: Index (0-based) of the face on this shape where the profile sits
    ///   - spine: Wire defining the sweep path
    ///   - fuse: If true, add material; if false, remove material
    /// - Returns: Modified shape, or nil on failure
    public func pipeFeature(
        profile: Shape, sketchFaceIndex: Int,
        spine: Wire, fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapePipeFeatureFromProfile(
                handle, profile.handle, Int32(sketchFaceIndex),
                spine.handle, fuse ? 1 : 0
            )
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Find Surface (v0.40.0)

    /// Find the underlying geometric surface of a shape (wire or edges).
    ///
    /// Analyzes the edges of a shape to determine if they lie on a common surface.
    /// - Parameters:
    ///   - tolerance: Tolerance for surface detection (default 1e-6)
    ///   - onlyPlane: If true, only look for planar surfaces (default false)
    /// - Returns: The underlying surface, or nil if none found
    public func findSurfaceEx(tolerance: Double = 1e-6, onlyPlane: Bool = false) -> Surface? {
        var found = false
        guard let surfHandle = OCCTShapeFindSurfaceEx(handle, tolerance, onlyPlane, &found),
            found
        else { return nil }
        return Surface(handle: surfHandle)
    }

    // MARK: - Curve-on-Surface Check

    /// Result of a curve-on-surface consistency check.
    public struct CurveOnSurfaceCheck {
        /// Maximum deviation between 3D edge curves and their pcurves on faces.
        public let maxDistance: Double
        /// Curve parameter where the maximum deviation occurs.
        public let maxParameter: Double
    }

    /// Check edge-on-surface consistency.
    ///
    /// Examines all edge-face pairs in the shape and reports the maximum deviation
    /// between each edge's 3D curve and its parametric curve (pcurve) on the face surface.
    /// Useful for validating imported geometry or checking repair results.
    ///
    /// - Returns: Check result with max distance and parameter, or nil if check fails
    public var curveOnSurfaceCheck: CurveOnSurfaceCheck? {
        var maxDist: Double = 0
        var maxParam: Double = 0
        guard OCCTShapeCheckCurveOnSurface(handle, &maxDist, &maxParam) else { return nil }
        return CurveOnSurfaceCheck(maxDistance: maxDist, maxParameter: maxParam)
    }
    /// Create a revolved shape by rotating a profile around an axis.
    ///
    /// Uses LocOpe_Revol for local revolution operations with shape tracking.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - angle: Rotation angle in radians
    /// - Returns: Revolved shape, or nil on failure
    public func localRevolution(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double
    ) -> Shape? {
        guard
            let ref = OCCTLocOpeRevol(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle)
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a revolved shape with angular offset.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - angle: Rotation angle in radians
    ///   - angularOffset: Angular offset for positioning in radians
    /// - Returns: Revolved shape, or nil on failure
    public func localRevolution(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double,
        angularOffset: Double
    ) -> Shape? {
        guard
            let ref = OCCTLocOpeRevolWithOffset(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle, angularOffset)
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - BRepGProp_Face integration (#266 follow-up)

    /// `BRepGProp_Face` Gauss-integration orders in U and V — the quadrature this face needs for exact surface integrals.
    ///
    /// Non-trivial only for BSpline faces; nil if the shape isn't a single face.
    public var faceIntegrationOrders: (u: Int, v: Int)? {
        var u: Int32 = 0
        var v: Int32 = 0
        guard OCCTBRepGPropFaceIntegrationOrders(handle, &u, &v) else { return nil }
        return (Int(u), Int(v))
    }

    /// `BRepGProp_Face` U-direction integration knots — the BSpline span boundaries used when
    /// integrating over the face's U range (just `[uMin, uMax]` for non-BSpline faces).
    public func faceIntegrationKnotsU() -> [Double] {
        var buffer = [Double](repeating: 0, count: 256)
        let n = OCCTBRepGPropFaceUKnots(handle, &buffer, 256)
        guard n > 0 else { return [] }
        return Array(buffer.prefix(Int(n)))
    }

    /// `BRepGProp_Face` V-direction integration knots — companion to ``faceIntegrationKnotsU()``.
    public func faceIntegrationKnotsV() -> [Double] {
        var buffer = [Double](repeating: 0, count: 256)
        let n = OCCTBRepGPropFaceVKnots(handle, &buffer, 256)
        guard n > 0 else { return [] }
        return Array(buffer.prefix(Int(n)))
    }

    /// `BRepGProp_Face` precision-driven surface integration parameters: the Gauss `order` (number of
    /// points) needed for tolerance `precision`, and the number of U / V subintervals. nil if the
    /// shape isn't a single face.
    public func faceSurfaceIntegration(precision: Double = 1e-6) -> (
        order: Int, uSubs: Int, vSubs: Int
    )? {
        var order: Int32 = 0
        var u: Int32 = 0
        var v: Int32 = 0
        guard OCCTBRepGPropFaceSurfaceIntegration(handle, precision, &order, &u, &v) else {
            return nil
        }
        return (Int(order), Int(u), Int(v))
    }

    /// `BRepGProp_Face` boundary integration: loads face edge `edgeIndex` as the boundary arc and
    /// returns its integration `order` (for `precision`), subinterval count, and knot values.
    /// nil if the shape isn't a face or the edge can't be loaded.
    public func faceBoundaryIntegration(edgeIndex: Int, precision: Double = 1e-6)
        -> (order: Int, subs: Int, knots: [Double])?
    {
        var order: Int32 = 0
        var subs: Int32 = 0
        var knotCount: Int32 = 0
        var buffer = [Double](repeating: 0, count: 256)
        guard
            OCCTBRepGPropFaceBoundaryIntegration(
                handle, Int32(edgeIndex), precision,
                &order, &subs, &buffer, 256, &knotCount)
        else { return nil }
        return (Int(order), Int(subs), Array(buffer.prefix(Int(knotCount))))
    }
    // MARK: - LocOpe_Pipe

    /// Perform a pipe sweep of this shape along a wire spine with shape tracking.
    ///
    /// Uses LocOpe_Pipe to sweep a face profile along a wire path.
    /// Unlike the regular pipe sweep, this tracks generated sub-shapes.
    ///
    /// - Parameter spine: Wire spine to sweep along
    /// - Returns: The swept shape, or nil on failure
    public func localPipe(along spine: Wire) -> Shape? {
        let spineShape = Shape(handle: OCCTShapeFromWire(spine.handle))
        guard let ref = OCCTLocOpePipe(handle, spineShape.handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_RevolutionForm

    /// Perform a revolution form of this shape with shape tracking.
    ///
    /// Uses LocOpe_RevolutionForm to revolve a face around an axis.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - angle: Rotation angle in radians
    /// - Returns: The revolved shape, or nil on failure
    public func localRevolutionForm(
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double
    ) -> Shape? {
        guard
            let ref = OCCTLocOpeRevolutionForm(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                angle)
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_ShapeDivideContinuity

    /// Continuity level for shape division.
    ///
    /// Deliberately kept separate from ``ParametricContinuity`` (#398): this is a strict
    /// superset, and `cn`, `g1` and `g2` are accepted only by
    /// ``divided(at:tolerance:)``. Every other continuity-floor call site silently defaults an
    /// unrecognised value, so widening them to this type would trade a compile error for a wrong
    /// answer.
    ///
    /// - Note: Used by ``divided(at:tolerance:)`` alone since #438 folded the narrower
    ///   ``dividedByContinuity(criterion:tolerance:)`` (now deprecated) into it.
    public enum ContinuityLevel: Int32, Sendable, CaseIterable {
        case c0 = 0
        case c1 = 1
        case c2 = 2
        case c3 = 3
        case cn = 4
        case g1 = 5
        case g2 = 6
    }

    // MARK: - BRepFill_Pipe

    /// Result of a pipe sweep operation.
    public struct PipeSweepResult {
        /// The swept pipe shape.
        public let shape: Shape
        /// Surface approximation error.
        public let errorOnSurface: Double
    }

    /// Create a pipe sweep of a profile along a spine with error reporting.
    ///
    /// Sweeps the profile wire along the spine wire using corrected Frenet trihedron.
    ///
    /// - Parameters:
    ///   - spine: Wire defining the sweep path
    ///   - profile: Wire defining the cross-section
    /// - Returns: Pipe result with shape and error metric, or nil on failure
    public static func pipeSweep(spine: Wire, profile: Wire) -> PipeSweepResult? {
        let r = OCCTBRepFillPipe(spine.handle, profile.handle)
        guard let s = r.shape else { return nil }
        return PipeSweepResult(
            shape: Shape(handle: s),
            errorOnSurface: r.errorOnSurface)
    }

    // MARK: - GeomPlate_Surface (v0.61.0)

    /// Build a plate surface through point constraints.
    ///
    /// Creates a smooth BSpline surface that passes through or near the given points.
    /// Useful for creating surfaces from scattered point data.
    ///
    /// The fit subdivides into more Bezier patches until it is within `tolerance` of the plate.
    /// `maxSegments` caps that subdivision; **1 is clamped to 2**, because a single patch cannot be
    /// cut and the approximator then ignores its own error criterion entirely, which makes
    /// `tolerance` unenforceable rather than merely coarse (#571).
    ///
    /// ```swift
    /// let points: [SIMD3<Double>] = [
    ///     SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(0, 10, -1), SIMD3(10, 10, 0.5),
    /// ]
    /// if let face = Shape.plateSurface(points: points, tolerance: 1e-3) {
    ///     print(face.surfaceArea ?? 0)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - points: Array of 3D points to fit the surface through
    ///   - tolerance: Approximation tolerance (default 1e-3)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    ///   - maxSegments: Maximum BSpline segments (default 20; values below 2 are clamped to 2)
    /// - Returns: Face with plate surface, or nil on failure
    public static func plateSurface(
        points: [SIMD3<Double>], tolerance: Double = 1e-3,
        maxDegree: Int = 8, maxSegments: Int = 20
    ) -> Shape? {
        var flatPoints = [Double]()
        flatPoints.reserveCapacity(points.count * 3)
        for pt in points {
            flatPoints.append(pt.x)
            flatPoints.append(pt.y)
            flatPoints.append(pt.z)
        }
        guard
            let h = OCCTGeomPlateSurface(
                flatPoints, Int32(points.count),
                tolerance, Int32(maxDegree), Int32(maxSegments))
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - GeomFill Trihedron Laws

    /// Shared unpacking for the `OCCTTrihedronFrame` raw struct every trihedron-law bridge call
    /// returns: a zero-length tangent means the law is degenerate at this parameter (#796).
    private static func trihedronFrame(from r: OCCTTrihedronFrame) -> TrihedronFrame? {
        let t = SIMD3(r.tx, r.ty, r.tz)
        guard simd_length(t) > 1e-10 else { return nil }
        return TrihedronFrame(
            tangent: t, normal: SIMD3(r.nx, r.ny, r.nz), binormal: SIMD3(r.bx, r.by, r.bz))
    }

    /// Evaluate draft trihedron frame on an edge at a parameter.
    public func draftTrihedron(at param: Double, biNormal: SIMD3<Double>, angle: Double)
        -> TrihedronFrame?
    {
        Shape.trihedronFrame(
            from: OCCTGeomFillDraftTrihedron(
                handle, param, biNormal.x, biNormal.y, biNormal.z, angle))
    }

    /// Evaluate discrete trihedron frame on an edge at a parameter.
    public func discreteTrihedron(at param: Double) -> TrihedronFrame? {
        Shape.trihedronFrame(from: OCCTGeomFillDiscreteTrihedron(handle, param))
    }

    /// Evaluate corrected Frenet frame on an edge at a parameter.
    public func correctedFrenet(at param: Double) -> TrihedronFrame? {
        Shape.trihedronFrame(from: OCCTGeomFillCorrectedFrenet(handle, param))
    }

    // MARK: - GeomFill_Coons / GeomFill_Curved

    /// Shared marshaling for `coonsFilling`/`curvedFilling`: both validate and flatten the same 4
    /// boundary-point arrays, size the same output buffer, and unflatten the same pole grid shape —
    /// they differ only in which bridge fill function computes the poles (#796).
    private static func fillPoleGrid(
        boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
        boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>],
        using bridgeCall: (
            UnsafePointer<Double>, UnsafePointer<Double>, UnsafePointer<Double>,
            UnsafePointer<Double>,
            Int32, UnsafeMutablePointer<Double>, Int32, UnsafeMutablePointer<Int32>,
            UnsafeMutablePointer<Int32>
        ) -> Int32
    ) -> FillingPoleGrid? {
        let n = boundary1.count
        guard n >= 2, boundary2.count == n, boundary3.count == n, boundary4.count == n else {
            return nil
        }
        let b1 = boundary1.flatMap { [$0.x, $0.y, $0.z] }
        let b2 = boundary2.flatMap { [$0.x, $0.y, $0.z] }
        let b3 = boundary3.flatMap { [$0.x, $0.y, $0.z] }
        let b4 = boundary4.flatMap { [$0.x, $0.y, $0.z] }
        let maxPoles = n * n * 4
        var outPoints = [Double](repeating: 0, count: maxPoles * 3)
        var nbU: Int32 = 0
        var nbV: Int32 = 0
        let count = Int(
            bridgeCall(b1, b2, b3, b4, Int32(n), &outPoints, Int32(maxPoles), &nbU, &nbV))
        guard count > 0 else { return nil }
        let poles = (0..<count).map { i in
            SIMD3(outPoints[i * 3], outPoints[i * 3 + 1], outPoints[i * 3 + 2])
        }
        return FillingPoleGrid(poles: poles, nbU: Int(nbU), nbV: Int(nbV))
    }

    /// Compute Coons filling pole grid from 4 boundary point arrays.
    public static func coonsFilling(
        boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
        boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>]
    ) -> FillingPoleGrid? {
        fillPoleGrid(
            boundary1: boundary1, boundary2: boundary2,
            boundary3: boundary3, boundary4: boundary4, using: OCCTGeomFillCoonsPoles)
    }

    /// Compute curved filling pole grid from 4 boundary point arrays.
    public static func curvedFilling(
        boundary1: [SIMD3<Double>], boundary2: [SIMD3<Double>],
        boundary3: [SIMD3<Double>], boundary4: [SIMD3<Double>]
    ) -> FillingPoleGrid? {
        fillPoleGrid(
            boundary1: boundary1, boundary2: boundary2,
            boundary3: boundary3, boundary4: boundary4, using: OCCTGeomFillCurvedPoles)
    }

    // MARK: - GeomFill_CoonsAlgPatch

    /// Evaluate Coons algorithmic patch from 4 boundary edges.
    ///
    /// - Parameters:
    ///   - edge1: First boundary edge.
    ///   - edge2: Second boundary edge.
    ///   - edge3: Third boundary edge.
    ///   - edge4: Fourth boundary edge.
    ///   - evalU: Evaluations in U, at least 1.
    ///   - evalV: Evaluations in V, at least 1.
    /// - Returns: The evaluated grid, or nil if the patch is degenerate or the grid cannot be
    ///   served: the bound is on the **product**, which must not exceed
    ///   ``Sampling/maximumSampleCount`` (#558).
    public static func coonsAlgPatch(
        edge1: Shape, edge2: Shape, edge3: Shape, edge4: Shape,
        evalU: Int = 10, evalV: Int = 10
    ) -> [SIMD3<Double>]? {
        guard let total = Sampling.gridTotal(evalU, evalV) else { return nil }
        var outPoints = [Double](repeating: 0, count: total * 3)
        OCCTGeomFillCoonsAlgPatchEval(
            edge1.handle, edge2.handle, edge3.handle, edge4.handle,
            Int32(evalU), Int32(evalV), &outPoints)
        let points: [SIMD3<Double>] = unpackSIMD3(outPoints, count: total)
        // Check if any non-zero points
        guard points.contains(where: { simd_length($0) > 1e-10 }) else { return nil }
        return points
    }

    // MARK: - GeomFill_Sweep

    /// Sweep a section edge along a path edge to create a surface face.
    public static func geomFillSweep(path: Shape, section: Shape) -> Shape? {
        guard let h = OCCTGeomFillSweep(path.handle, section.handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - GeomFill_EvolvedSection

    /// Get evolved section info for an edge curve.
    public func evolvedSectionInfo() -> EvolvedSectionInfo {
        let r = OCCTGeomFillEvolvedSectionInfo(handle)
        return EvolvedSectionInfo(
            nbPoles: Int(r.nbPoles), nbKnots: Int(r.nbKnots),
            degree: Int(r.degree), isRational: r.isRational)
    }

    // MARK: - TopTrans Surface Transition

    /// TopAbs_State values for surface transition analysis.
    public enum TopologicalState: Int32, Sendable {
        case `in` = 0
        case out = 1
        case on = 2
        case unknown = 3
    }

    /// Result of a surface transition analysis.
    public struct SurfaceTransitionResult: Sendable {
        /// State before crossing the surface.
        public let stateBefore: TopologicalState
        /// State after crossing the surface.
        public let stateAfter: TopologicalState
    }

    /// Analyze a surface transition along a curve crossing a surface boundary.
    ///
    /// Determines the topological state (IN/OUT) before and after crossing a surface,
    /// given the curve tangent, boundary normal, and surface normal at the crossing point.
    ///
    /// - Parameters:
    ///   - tangent: Tangent direction of the curve at the crossing
    ///   - normal: Normal of the boundary at the crossing
    ///   - surfaceNormal: Normal of the surface being crossed
    ///   - tolerance: Angular tolerance
    ///   - surfaceOrientation: Orientation of the surface (0=FORWARD, 1=REVERSED)
    ///   - boundaryOrientation: Orientation of the boundary (0=FORWARD, 1=REVERSED)
    /// - Returns: Transition result with states before and after
    public static func surfaceTransition(
        tangent: SIMD3<Double>, normal: SIMD3<Double>,
        surfaceNormal: SIMD3<Double>, tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3
        var after: Int32 = 3
        OCCTTopTransSurfaceTransition(
            tangent.x, tangent.y, tangent.z,
            normal.x, normal.y, normal.z,
            surfaceNormal.x, surfaceNormal.y, surfaceNormal.z,
            tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    /// Analyze a surface transition with curvature information.
    ///
    /// Extended version that accounts for surface curvature at the crossing point,
    /// providing more accurate transition analysis for curved surfaces.
    ///
    /// - Parameters:
    ///   - tangent: Tangent direction of the curve
    ///   - normal: Normal of the boundary
    ///   - maxDirection: Direction of maximum curvature of the boundary
    ///   - minDirection: Direction of minimum curvature of the boundary
    ///   - maxCurvature: Maximum curvature of the boundary
    ///   - minCurvature: Minimum curvature of the boundary
    ///   - surfaceNormal: Normal of the surface
    ///   - surfaceMaxDirection: Direction of maximum curvature of the surface
    ///   - surfaceMinDirection: Direction of minimum curvature of the surface
    ///   - surfaceMaxCurvature: Maximum curvature of the surface
    ///   - surfaceMinCurvature: Minimum curvature of the surface
    ///   - tolerance: Angular tolerance
    ///   - surfaceOrientation: Orientation of the surface
    ///   - boundaryOrientation: Orientation of the boundary
    /// - Returns: Transition result with states before and after
    public static func surfaceTransitionWithCurvature(
        tangent: SIMD3<Double>, normal: SIMD3<Double>,
        maxDirection: SIMD3<Double>, minDirection: SIMD3<Double>,
        maxCurvature: Double, minCurvature: Double,
        surfaceNormal: SIMD3<Double>,
        surfaceMaxDirection: SIMD3<Double>, surfaceMinDirection: SIMD3<Double>,
        surfaceMaxCurvature: Double, surfaceMinCurvature: Double,
        tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3
        var after: Int32 = 3
        OCCTTopTransSurfaceTransitionCurvature(
            tangent.x, tangent.y, tangent.z,
            normal.x, normal.y, normal.z,
            maxDirection.x, maxDirection.y, maxDirection.z,
            minDirection.x, minDirection.y, minDirection.z,
            maxCurvature, minCurvature,
            surfaceNormal.x, surfaceNormal.y, surfaceNormal.z,
            surfaceMaxDirection.x, surfaceMaxDirection.y, surfaceMaxDirection.z,
            surfaceMinDirection.x, surfaceMinDirection.y, surfaceMinDirection.z,
            surfaceMaxCurvature, surfaceMinCurvature,
            tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    // MARK: - GeomFill Trihedrons (v0.68.0)

    /// Evaluate a Frenet trihedron on an edge at a parameter.
    public func frenetTrihedron(at param: Double) -> (
        tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>
    )? {
        let f = OCCTGeomFillFrenetTrihedron(handle, param)
        if f.tx == 0 && f.ty == 0 && f.tz == 0 { return nil }
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Evaluate a constant-binormal trihedron on an edge at a parameter.
    public func constantBiNormalTrihedron(at param: Double, biNormal: SIMD3<Double>) -> (
        tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>
    )? {
        let f = OCCTGeomFillConstantBiNormalTrihedron(
            handle, param, biNormal.x, biNormal.y, biNormal.z)
        if f.tx == 0 && f.ty == 0 && f.tz == 0 { return nil }
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Evaluate a fixed (constant) trihedron at any parameter.
    public static func fixedTrihedron(
        tangent: SIMD3<Double>, normal: SIMD3<Double>, at param: Double = 0
    ) -> (tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>) {
        let f = OCCTGeomFillFixedTrihedron(
            tangent.x, tangent.y, tangent.z, normal.x, normal.y, normal.z, param)
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Evaluate a Darboux trihedron on an edge lying on a face.
    public func darbouxTrihedron(onFace face: Shape, at param: Double) -> (
        tangent: SIMD3<Double>, normal: SIMD3<Double>, binormal: SIMD3<Double>
    )? {
        let f = OCCTGeomFillDarbouxTrihedron(handle, face.handle, param)
        if f.tx == 0 && f.ty == 0 && f.tz == 0 { return nil }
        return (SIMD3(f.tx, f.ty, f.tz), SIMD3(f.nx, f.ny, f.nz), SIMD3(f.bx, f.by, f.bz))
    }

    /// Compute the section (intersection curves) of this shape with a plane.
    /// - Parameters:
    ///   - normal: Plane normal direction
    ///   - origin: A point on the plane
    /// - Returns: Shape containing section edges, or nil on failure
    public func sectionWithPlane(normal: SIMD3<Double>, origin: SIMD3<Double>) -> Shape? {
        guard
            let h = OCCTShapeSectionWithPlane(
                handle,
                normal.x, normal.y, normal.z,
                origin.x, origin.y, origin.z)
        else { return nil }
        return Shape(handle: h)
    }

    /// Compute the section (intersection curves) of this shape with a surface.
    /// - Parameter surface: The surface to intersect with
    /// - Returns: Shape containing section edges, or nil on failure
    public func sectionWithSurface(_ surface: Surface) -> Shape? {
        guard let h = OCCTShapeSectionWithSurface(handle, surface.handle) else { return nil }
        return Shape(handle: h)
    }
}

extension Shape {

    /// Find a surface (typically plane) through the edges of this shape.
    public func findSurface(tolerance: Double = -1, onlyPlane: Bool = false) -> Surface? {
        guard let ref = OCCTFindSurface(handle, tolerance, onlyPlane) else { return nil }
        return Surface(handle: ref)
    }

    /// Find surface tolerance reached.
    public func findSurfaceTolerance(tolerance: Double = -1, onlyPlane: Bool = false) -> Double? {
        let tol = OCCTFindSurfaceTolerance(handle, tolerance, onlyPlane)
        return tol >= 0 ? tol : nil
    }

    /// Check if a surface already existed on the shape edges.
    public func findSurfaceExisted(tolerance: Double = -1, onlyPlane: Bool = false) -> Bool {
        OCCTFindSurfaceExisted(handle, tolerance, onlyPlane)
    }
}

extension Shape {

    /// Get tangent in U direction on a face at (u, v).
    ///
    /// Returns nil if tangent is undefined.
    public func faceLPropTangentU(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0
        var dy = 0.0
        var dz = 0.0
        let ok = OCCTFaceLPropTangentU(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Get tangent in V direction on a face at (u, v) — the second axis of the tangent plane (companion to ``faceLPropTangentU(u:v:)``).
    ///
    /// Returns nil if the V tangent is undefined.
    public func faceLPropTangentV(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0
        var dy = 0.0
        var dz = 0.0
        let ok = OCCTFaceLPropTangentV(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }
}
