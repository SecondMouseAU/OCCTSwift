import Foundation
import simd
import OCCTBridge

extension Shape {


    // MARK: - Bezier Conversion

    /// Convert all curves and surfaces in the shape to Bezier representations.
    ///
    /// Uses ShapeUpgrade_ShapeConvertToBezier to replace BSpline curves and surfaces
    /// with their Bezier equivalents. Converts 2D/3D curves, surfaces, lines, circles,
    /// conics, planes, revolutions, extrusions, and BSpline entities.
    ///
    /// - Returns: Shape with Bezier geometry, or nil on failure
    public var convertedToBezier: Shape? {
        guard let ref = OCCTShapeConvertToBezier(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: LocOpe_CurveShapeIntersector

    /// Intersect a line with this shape and return parameter values.
    ///
    /// Parameters only: the underlying bridge call already builds a `LocOpe_PntFace` per hit
    /// (which also carries the 3D point, the face, its orientation, and its U/V parameters) but
    /// reads only `.Parameter()` before discarding it. If you need the point or face struck, use
    /// ``ShapeRayIntersection`` instead — a separate, richer line/curve–shape intersector wrapping
    /// `BRepIntCurveSurface_Inter`, added independently and not a drop-in replacement (it's an
    /// iterator, not a one-shot array, and does not support the `gp_Circ` axis this one's
    /// underlying OCCT class also accepts but this wrapper does not yet expose) (#852).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let params = box.curveShapeIntersect(origin: SIMD3(5, 5, -10), direction: SIMD3(0, 0, 1))
    /// ```
    public func curveShapeIntersect(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> [Double]? {
        var outParams: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTLocOpeCurveShapeIntersectLine(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            &outParams, &outCount
        ) else { return nil }
        guard let params = outParams else { return [] }
        defer { free(params) }
        return Array(UnsafeBufferPointer(start: params, count: Int(outCount)))
    }

    // Note: ShapeUpgrade_ClosedFaceDivide, SplitSurfaceAngle, SplitSurfaceArea
    // already wrapped as dividedClosedFaces, splitByAngle, dividedByParts

    // MARK: CPnts_UniformDeflection

    /// Discretization result with parameters and 3D points.
    public struct DeflectionResult: Sendable {
        public let parameters: [Double]
        public let points: [SIMD3<Double>]
    }

    /// Unpacks the malloc'd `(params, points)` buffer pair both `uniformDeflection` overloads
    /// receive, freeing both regardless of outcome (#853).
    ///
    /// `CPnts_UniformDeflection`'s point count is driven by chordal deflection against curve
    /// curvature, with no documented ceiling either — the same *class* of exposure as
    /// `uniformAbscissa(distance:)` above, which has one now. Unlike that pair, the buffers here
    /// are already malloc'd C-side by the single bridge call before this ever runs, so bounding
    /// the count here would only save the Swift-side unpack, not the C-side cost of producing the
    /// buffers in the first place — closing that needs a cap inside the bridge's own accumulation
    /// loop (`OCCTCPntsUniformDeflection`/`Range` in `OCCTBridge_Curve3D.mm`), a different fix in
    /// a different place, deliberately left for a follow-up rather than folded in here.
    private func unpackDeflectionResult(
        outParams: UnsafeMutablePointer<Double>?,
        outPoints: UnsafeMutablePointer<Double>?,
        outCount: Int32
    ) -> DeflectionResult? {
        guard let params = outParams, let pts = outPoints, outCount > 0 else { return nil }
        defer { free(params); free(pts) }
        var points = [SIMD3<Double>]()
        points.reserveCapacity(Int(outCount))
        for i in 0..<Int(outCount) {
            points.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
        }
        return DeflectionResult(
            parameters: Array(UnsafeBufferPointer(start: params, count: Int(outCount))),
            points: points
        )
    }

    /// Discretize an edge by uniform deflection.
    public func uniformDeflection(_ deflection: Double) -> DeflectionResult? {
        var outParams: UnsafeMutablePointer<Double>?
        var outPoints: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTCPntsUniformDeflection(handle, deflection, &outParams, &outPoints, &outCount)
        else { return nil }
        return unpackDeflectionResult(outParams: outParams, outPoints: outPoints, outCount: outCount)
    }

    /// Discretize an edge by uniform deflection within a parameter range.
    public func uniformDeflection(_ deflection: Double, range: ClosedRange<Double>) -> DeflectionResult? {
        var outParams: UnsafeMutablePointer<Double>?
        var outPoints: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTCPntsUniformDeflectionRange(
            handle, deflection,
            range.lowerBound, range.upperBound,
            &outParams, &outPoints, &outCount
        ) else { return nil }
        return unpackDeflectionResult(outParams: outParams, outPoints: outPoints, outCount: outCount)
    }

    // MARK: - Approx_CurvilinearParameter

    /// Reparameterize an edge curve by arc length, returning a BSpline edge
    public func curvilinearParameter(tolerance: Double = 1e-3, maxDegree: Int = 8, maxSegments: Int = 50) -> Shape? {
        guard let h = OCCTApproxCurvilinearParameter(handle, tolerance, Int32(maxDegree), Int32(maxSegments)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Adaptor3d_IsoCurve

    /// Evaluate points along a U-iso curve on a face at given U parameter.
    ///
    /// - Parameter count: Desired number of evaluations, honoured within `1...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty (#558).
    public func uIsoCurvePoints(u: Double, count: Int = 20) -> [SIMD3<Double>] {
        guard let count = Sampling.requested(count, atLeast: 1) else { return [] }
        var outPoints = [Double](repeating: 0, count: count * 3)
        OCCTAdaptor3dIsoCurveEval(handle, 0, u, Int32(count), &outPoints)
        return unpackSIMD3(outPoints, count: count)
    }

    /// Evaluate points along a V-iso curve on a face at given V parameter.
    ///
    /// - Parameter count: Desired number of evaluations, honoured within `1...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty (#558).
    public func vIsoCurvePoints(v: Double, count: Int = 20) -> [SIMD3<Double>] {
        guard let count = Sampling.requested(count, atLeast: 1) else { return [] }
        var outPoints = [Double](repeating: 0, count: count * 3)
        OCCTAdaptor3dIsoCurveEval(handle, 1, v, Int32(count), &outPoints)
        return unpackSIMD3(outPoints, count: count)
    }

    /// Extract a U-iso curve from a face as an edge
    public func uIsoCurveEdge(u: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let h = OCCTAdaptor3dIsoCurveEdge(handle, 0, u, vMin, vMax) else { return nil }
        return Shape(handle: h)
    }

    /// Extract a V-iso curve from a face as an edge
    public func vIsoCurveEdge(v: Double, uMin: Double, uMax: Double) -> Shape? {
        guard let h = OCCTAdaptor3dIsoCurveEdge(handle, 1, v, uMin, uMax) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - TopTrans Curve Transition

    /// Analyze a curve transition at a boundary crossing.
    ///
    /// Determines the topological state (IN/OUT) before and after a curve crosses
    /// a boundary element, given directions and curvature.
    ///
    /// - Parameters:
    ///   - tangent: Tangent of the curve at the crossing
    ///   - boundaryTangent: Tangent of the boundary element
    ///   - boundaryNormal: Normal of the boundary element
    ///   - curvature: Curvature of the boundary at the crossing
    ///   - tolerance: Angular tolerance
    ///   - surfaceOrientation: Orientation of the surface (0=FORWARD, 1=REVERSED)
    ///   - boundaryOrientation: Orientation of the boundary
    /// - Returns: Transition result with states before and after
    public static func curveTransition(
        tangent: SIMD3<Double>,
        boundaryTangent: SIMD3<Double>, boundaryNormal: SIMD3<Double>,
        curvature: Double = 0.0, tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3, after: Int32 = 3
        OCCTTopTransCurveTransition(
            tangent.x, tangent.y, tangent.z,
            boundaryTangent.x, boundaryTangent.y, boundaryTangent.z,
            boundaryNormal.x, boundaryNormal.y, boundaryNormal.z,
            curvature, tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    /// Analyze a curve transition with curvature on the boundary curve.
    public static func curveTransitionWithCurvature(
        tangent: SIMD3<Double>,
        curveNormal: SIMD3<Double>, curveCurvature: Double,
        boundaryTangent: SIMD3<Double>, boundaryNormal: SIMD3<Double>,
        surfaceCurvature: Double, tolerance: Double = 1e-6,
        surfaceOrientation: Int = 0, boundaryOrientation: Int = 0
    ) -> SurfaceTransitionResult {
        var before: Int32 = 3, after: Int32 = 3
        OCCTTopTransCurveTransitionWithCurvature(
            tangent.x, tangent.y, tangent.z,
            curveNormal.x, curveNormal.y, curveNormal.z,
            curveCurvature,
            boundaryTangent.x, boundaryTangent.y, boundaryTangent.z,
            boundaryNormal.x, boundaryNormal.y, boundaryNormal.z,
            surfaceCurvature, tolerance,
            Int32(surfaceOrientation), Int32(boundaryOrientation),
            &before, &after)
        return SurfaceTransitionResult(
            stateBefore: TopologicalState(rawValue: before) ?? .unknown,
            stateAfter: TopologicalState(rawValue: after) ?? .unknown)
    }

    // --- GCPnts_AbscissaPoint expansion ---

    /// Find parameter on an edge at a given arc length from startParam.
    ///
    /// Shares the subdivided measurement with ``Shape/edgeArcLength``, so the two agree on the
    /// same edge: OCCT's own root finder inverts one Gauss quadrature over `[startParam, u]`,
    /// which on an elliptical edge disagreed with an accurate length by up to 1% in arc (#603).
    ///
    /// ```swift
    /// let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))!
    /// let mid = edge.edgeParameterAtArcLength(5, from: edge.edgeAdaptorDomain.lowerBound)
    /// ```
    public func edgeParameterAtArcLength(_ arcLength: Double, from startParam: Double) -> Double {
        OCCTEdgeParameterAtArcLength(handle, arcLength, startParam)
    }

    /// Compute total arc length of this edge.
    ///
    /// Returns `-1.0` if the computation fails — arc length is otherwise always non-negative, so
    /// this is an unambiguous failure sentinel, matching ``Curve3D/totalArcLength``. It used to
    /// return `0`, which a genuinely zero-length edge also measures (#548).
    ///
    /// Measured per `GeomAbs_CN` interval and subdivided until two successive levels agree to
    /// 1e-9 relative. An elliptical edge measured 1.485% long before that (#603); a straight or
    /// circular edge is unaffected, since those have an exact closed form.
    ///
    /// ```swift
    /// let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))!
    /// let total = edge.edgeArcLength   // 10.0
    /// ```
    public var edgeArcLength: Double {
        OCCTEdgeArcLength(handle)
    }

    /// Compute arc length between two parameters on this edge.
    ///
    /// Both bounds must be finite. `.nan` and `±.infinity` return `-1.0` rather than reaching
    /// OCCT's integrator, which answered them per curve type: a NaN bound on a straight edge came
    /// back as NaN itself, and on a multi-span edge as `0` (a NaN upper bound) or the edge's whole
    /// length (a NaN lower one). `-1.0` is also the sentinel for any other failure, replacing the
    /// `0` this returned before — that value is what a genuine zero-width interval measures (#548).
    ///
    /// A range reaching outside the edge's parameter domain measures the part of it that lies on
    /// the edge, so a range wholly outside measures `0`; a closed periodic edge (a full circle, a
    /// closed spline) covers a whole period and so measures the whole range, winding (#600). The
    /// answer matches ``Curve3D/length(from:to:)`` on the curve the edge was built from.
    ///
    /// ```swift
    /// let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))!
    /// let d = edge.edgeAdaptorDomain
    /// let half = edge.edgeArcLength(from: d.lowerBound, to: (d.lowerBound + d.upperBound) / 2)
    /// let bad = edge.edgeArcLength(from: d.lowerBound, to: .nan)   // -1.0
    /// let clipped = edge.edgeArcLength(from: 0, to: 20)            // 10, the edge's own length
    /// ```
    public func edgeArcLength(from u1: Double, to u2: Double) -> Double {
        OCCTEdgeArcLengthBetween(handle, u1, u2)
    }

    /// Find parameter at a fraction (0..1) of total edge length.
    ///
    /// Both halves — the total and the walk along it — use the subdivided measurement (#603).
    /// They were biased by the same single quadrature before, and the two errors cancelled; both
    /// are accurate now, so `edgeParameterAtFraction(1.0)` still lands on the edge's last
    /// parameter and `0.5` genuinely halves the arc (it split an elliptical edge 0.74% off).
    ///
    /// ```swift
    /// let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))!
    /// let quarter = edge.edgeParameterAtFraction(0.25)
    /// ```
    public func edgeParameterAtFraction(_ fraction: Double) -> Double {
        OCCTEdgeParameterAtFraction(handle, fraction)
    }

    // --- BRepAdaptor exposure ---

    /// Get the parameter domain of an edge curve.
    public var edgeAdaptorDomain: ClosedRange<Double> {
        var first = 0.0, last = 0.0
        OCCTEdgeAdaptorDomain(handle, &first, &last)
        return first...last
    }
}

extension Shape {
    /// Runs the "call once with `nil` to learn the count, allocate, call again to fill" idiom
    /// shared by every `uniformAbscissa` overload below, applying the one bound all four need
    /// before ever allocating: the sizing call's own answer, bounded by
    /// ``Sampling/maximumSampleCount`` (#853).
    ///
    /// `uniformAbscissa(pointCount:)` and its `u1:u2:` range sibling already bound their
    /// *request* through ``Sampling/requested(_:atLeast:)`` before the bridge is called at all,
    /// and `GCPnts_UniformAbscissa`'s count constructor returns exactly the requested count, so
    /// the check here is a no-op for those two. The `distance:` pair has no caller-supplied count
    /// to pre-check that way — each bounds its own *implied* count from the curve length before
    /// calling this (mirroring ``ArcLengthCurveAdaptor/points(spacing:)``, #479) — so this is the
    /// backstop for both, catching anything that estimate undershot.
    private func sizeAndFillUniformAbscissa(
        _ bridgeCall: (UnsafeMutablePointer<Double>?) -> Int32
    ) -> [Double]? {
        let n = Int(bridgeCall(nil))
        guard n > 0, n <= Sampling.maximumSampleCount else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = bridgeCall(&params)
        return params
    }

    /// Uniformly sample an edge by point count. Returns parameter values.
    ///
    /// - Parameter pointCount: Desired number of samples, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``, else `nil`. OCCT's sampler documents the lower bound but
    ///   cannot enforce it in a Release kernel, and used to answer a request for zero with five
    ///   parameters (#501); the upper bound is this layer's, since `pointCount` is cast to the
    ///   bridge's `int32_t` and used to abort the process past it (#558).
    public func uniformAbscissa(pointCount: Int) -> [Double]? {
        guard let pointCount = Sampling.requested(pointCount) else { return nil }
        return sizeAndFillUniformAbscissa { OCCTUniformAbscissaByCount(handle, Int32(pointCount), $0) }
    }

    /// Uniformly sample an edge by arc distance. Returns parameter values.
    ///
    /// - Parameter distance: Arc-length spacing between samples, greater than 0. A spacing small
    ///   enough that it implies more than ``Sampling/maximumSampleCount`` points is rejected
    ///   before OCCT's sampler ever runs, the same way ``ArcLengthCurveAdaptor/points(spacing:)``
    ///   derives and bounds its own implied count (#479) — this overload had no ceiling of any
    ///   kind before, unlike its `pointCount:` sibling above (#853).
    public func uniformAbscissa(distance: Double) -> [Double]? {
        let len = edgeArcLength
        guard distance > 0, len > 0 else { return nil }
        let implied = (len / distance).rounded() + 1
        guard implied <= Double(Sampling.maximumSampleCount) else { return nil }
        return sizeAndFillUniformAbscissa { OCCTUniformAbscissaByDistance(handle, distance, $0) }
    }

    /// Uniformly sample an edge by point count within parameter range.
    ///
    /// - Parameter pointCount: Desired number of samples, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``, else `nil` (#501, #558).
    public func uniformAbscissa(pointCount: Int, u1: Double, u2: Double) -> [Double]? {
        guard let pointCount = Sampling.requested(pointCount) else { return nil }
        return sizeAndFillUniformAbscissa {
            OCCTUniformAbscissaByCountRange(handle, Int32(pointCount), u1, u2, $0)
        }
    }

    /// Uniformly sample an edge by arc distance within parameter range.
    ///
    /// - Parameter distance: see ``uniformAbscissa(distance:)`` — the same ceiling, measured over
    ///   `[u1, u2]` instead of the whole edge (#853).
    public func uniformAbscissa(distance: Double, u1: Double, u2: Double) -> [Double]? {
        let len = edgeArcLength(from: u1, to: u2)
        guard distance > 0, len > 0 else { return nil }
        let implied = (len / distance).rounded() + 1
        guard implied <= Double(Sampling.maximumSampleCount) else { return nil }
        return sizeAndFillUniformAbscissa {
            OCCTUniformAbscissaByDistanceRange(handle, distance, u1, u2, $0)
        }
    }
}
