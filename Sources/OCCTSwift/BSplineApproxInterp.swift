import Foundation
import simd
import OCCTBridge

/// Least-squares B-spline curve approximation through a set of 3D points.
///
/// Fits a B-spline curve to the points, minimising the 3D deviation. Inspect
/// ``maxError`` for the worst-case residual.
///
/// > Note: OCCT 8.0.0p1 removed the `Approx_BSplineApproxInterp` solver this type
/// > originally wrapped, so it is now backed by `GeomAPI_PointsToBSpline`. As a result
/// > `nbControlPoints` is **advisory** (the approximator chooses the pole count needed to
/// > meet the tolerance) and the per-point ``interpolatePoint(_:withKink:)`` constraints
/// > are **no-ops** — the fit still passes close to every point. Drive accuracy with
/// > ``setConvergenceTolerance(_:)`` / ``setProjectionTolerance(_:)``.
///
/// ## Example
///
/// ```swift
/// // Sample a helix
/// var points: [SIMD3<Double>] = []
/// for i in 0..<50 {
///     let t = Double(i) / 49.0 * 2.0 * .pi
///     points.append(SIMD3(cos(t), sin(t), 0.1 * t))
/// }
///
/// // Fit with 20 control points, interpolating endpoints
/// let solver = BSplineApproxInterp(points: points, nbControlPoints: 20)!
/// solver.interpolatePoint(0)    // first point exact
/// solver.interpolatePoint(49)   // last point exact
/// solver.perform()
///
/// if solver.isDone, let curve = solver.curve {
///     print("Max error: \(solver.maxError)")
/// }
/// ```
public final class BSplineApproxInterp: @unchecked Sendable {
    internal let handle: OCCTBSplineApproxInterpRef

    /// Creates a constrained B-spline approximation solver.
    /// - Parameters:
    ///   - points: array of 3D points to fit
    ///   - nbControlPoints: desired number of control points
    ///   - degree: B-spline degree (default 3)
    ///   - continuousIfClosed: enforce C2 continuity if curve is detected as closed (default false)
    public init?(points: [SIMD3<Double>], nbControlPoints: Int,
                 degree: Int = 3, continuousIfClosed: Bool = false) {
        guard points.count >= 2 else { return nil }
        var flat = [Double](repeating: 0, count: points.count * 3)
        for (i, p) in points.enumerated() {
            flat[i * 3] = p.x
            flat[i * 3 + 1] = p.y
            flat[i * 3 + 2] = p.z
        }
        guard let ref = OCCTBSplineApproxInterpCreate(
            &flat, Int32(points.count),
            Int32(nbControlPoints), Int32(degree), continuousIfClosed
        ) else { return nil }
        self.handle = ref
    }

    deinit {
        OCCTBSplineApproxInterpRelease(handle)
    }

    /// Mark a point to be exactly interpolated (0-based index).
    ///
    /// > Note: No-op since OCCT 8.0.0p1 — `GeomAPI_PointsToBSpline` has no per-point exact
    /// > interpolation or C0-break control. The approximation still passes near every point.
    /// - Parameters:
    ///   - index: 0-based point index
    ///   - withKink: if true, inserts a C0 discontinuity at this parameter
    public func interpolatePoint(_ index: Int, withKink: Bool = false) {
        OCCTBSplineApproxInterpInterpolatePoint(handle, Int32(index), withKink)
    }

    /// Perform the fit using automatically computed parameters.
    public func perform() {
        OCCTBSplineApproxInterpPerform(handle)
    }

    /// Perform the fit with iterative parameter optimization.
    /// - Parameter maxIterations: maximum number of optimization iterations
    public func performOptimal(maxIterations: Int = 10) {
        OCCTBSplineApproxInterpPerformOptimal(handle, Int32(maxIterations))
    }

    /// Returns true if the fit was computed successfully.
    public var isDone: Bool {
        OCCTBSplineApproxInterpIsDone(handle)
    }

    /// Returns the resulting B-spline curve, or nil if not done.
    public var curve: Curve3D? {
        guard let ref = OCCTBSplineApproxInterpCurve(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Returns the maximum approximation error.
    public var maxError: Double {
        OCCTBSplineApproxInterpMaxError(handle)
    }

    /// Set parametrization power: 0=uniform, 0.5=centripetal (default), 1=chord-length.
    public func setParametrizationAlpha(_ alpha: Double) {
        OCCTBSplineApproxInterpSetAlpha(handle, alpha)
    }

    /// Set minimum pivot value for the Gauss solver (default 1e-20).
    public func setMinPivot(_ value: Double) {
        OCCTBSplineApproxInterpSetMinPivot(handle, value)
    }

    /// Set relative tolerance for closed-curve detection (default 1e-12).
    public func setClosedTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetClosedTol(handle, value)
    }

    /// Set tolerance for knot insertion during kink handling (default 1e-4).
    public func setKnotInsertionTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetKnotTol(handle, value)
    }

    /// Set convergence tolerance for parameter optimization (default 1e-3).
    public func setConvergenceTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetConvergenceTol(handle, value)
    }

    /// Set projection tolerance for parameter optimization (default 1e-6).
    public func setProjectionTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetProjectionTol(handle, value)
    }
}
