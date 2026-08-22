import Foundation
import OCCTBridge
import simd

/// Least-squares B-spline curve approximation through a set of 3D points.
///
/// Fits a B-spline curve to the points, minimising the 3D deviation. Inspect
/// ``maxError`` for the worst-case residual.
///
/// > Note: OCCT 8.0.0p1 removed the `Approx_BSplineApproxInterp` solver this type
/// > originally wrapped, so it is now backed by `GeomAPI_PointsToBSpline`. The API is kept
/// > source-compatible, but several controls the old solver offered have no equivalent and
/// > are now **no-ops**: ``interpolatePoint(_:withKink:)``,
/// > ``setParametrizationAlpha(_:)``, ``setMinPivot(_:)``, ``setClosedTolerance(_:)`` and
/// > ``setKnotInsertionTolerance(_:)``. `nbControlPoints` and `continuousIfClosed` are
/// > **advisory** (the approximator chooses the pole count needed to meet the tolerance),
/// > and ``performOptimal(maxIterations:)`` is identical to ``perform()``. The two knobs
/// > that do still bite are ``setConvergenceTolerance(_:)`` and
/// > ``setProjectionTolerance(_:)``, which drive one shared 3D fit tolerance.
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
/// // nbControlPoints is advisory: the fit uses as many poles as the tolerance needs
/// let solver = BSplineApproxInterp(points: points, nbControlPoints: 20)!
/// solver.setConvergenceTolerance(1e-4)   // tighten the 3D fit tolerance
/// solver.perform()
///
/// if solver.isDone, let curve = solver.curve {
///     print("Max error: \(solver.maxError)")
/// }
/// ```
public final class BSplineApproxInterp: @unchecked Sendable {
    internal let handle: OCCTBSplineApproxInterpRef

    /// Creates a least-squares B-spline approximation solver.
    /// - Parameters:
    ///   - points: array of 3D points to fit
    ///   - nbControlPoints: desired number of control points, **advisory**; see the type note
    ///   - degree: B-spline degree (default 3); widens the fit's degree range to
    ///     `[min(3, degree), max(degree, 8)]`
    ///   - continuousIfClosed: **advisory and currently ignored**, see the type note
    public init?(
        points: [SIMD3<Double>], nbControlPoints: Int,
        degree: Int = 3, continuousIfClosed: Bool = false
    ) {
        guard points.count >= 2 else { return nil }
        var flat = [Double](repeating: 0, count: points.count * 3)
        for (i, p) in points.enumerated() {
            flat[i * 3] = p.x
            flat[i * 3 + 1] = p.y
            flat[i * 3 + 2] = p.z
        }
        guard
            let ref = OCCTBSplineApproxInterpCreate(
                &flat, Int32(points.count),
                Int32(nbControlPoints), Int32(degree), continuousIfClosed
            )
        else { return nil }
        self.handle = ref
    }

    deinit {
        OCCTBSplineApproxInterpRelease(handle)
    }

    /// No-op. Originally marked a point to be exactly interpolated (0-based index).
    ///
    /// > Note: No-op since OCCT 8.0.0p1. `GeomAPI_PointsToBSpline` has no per-point exact
    /// > interpolation or C0-break control. The approximation still passes near every point.
    /// - Parameters:
    ///   - index: 0-based point index
    ///   - withKink: if true, would insert a C0 discontinuity at this parameter
    public func interpolatePoint(_ index: Int, withKink: Bool = false) {
        OCCTBSplineApproxInterpInterpolatePoint(handle, Int32(index), withKink)
    }

    /// Perform the fit using automatically computed parameters.
    public func perform() {
        OCCTBSplineApproxInterpPerform(handle)
    }

    /// Perform the fit. Identical to ``perform()``: `GeomAPI_PointsToBSpline` has no
    /// iterative parameter-optimization mode, so `maxIterations` is ignored.
    /// - Parameter maxIterations: ignored, kept for source compatibility
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

    /// The maximum approximation error: the largest distance from an input point to its
    /// projection on the fitted curve. `-1` if the fit has not run or did not succeed.
    public var maxError: Double {
        OCCTBSplineApproxInterpMaxError(handle)
    }

    /// No-op. Originally set the parametrization power (0=uniform, 0.5=centripetal,
    /// 1=chord-length). `GeomAPI_PointsToBSpline` takes an `Approx_ParametrizationType`
    /// rather than an alpha, and the bridge does not currently forward one.
    public func setParametrizationAlpha(_ alpha: Double) {
        OCCTBSplineApproxInterpSetAlpha(handle, alpha)
    }

    /// No-op. Originally set the minimum pivot value for the Gauss solver (default 1e-20).
    /// `GeomAPI_PointsToBSpline` exposes no solver internals.
    public func setMinPivot(_ value: Double) {
        OCCTBSplineApproxInterpSetMinPivot(handle, value)
    }

    /// No-op. Originally set the relative tolerance for closed-curve detection
    /// (default 1e-12). `GeomAPI_PointsToBSpline` has no closed-curve detection to tune.
    public func setClosedTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetClosedTol(handle, value)
    }

    /// No-op. Originally set the tolerance for knot insertion during kink handling
    /// (default 1e-4); kink handling belonged to the removed solver.
    public func setKnotInsertionTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetKnotTol(handle, value)
    }

    /// Sets the 3D fit tolerance (default 1e-3). Values `<= 0` are ignored.
    public func setConvergenceTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetConvergenceTol(handle, value)
    }

    /// Tightens the 3D fit tolerance to `min(current, value)` (default 1e-6). Values `<= 0`
    /// are ignored. This shares one tolerance with ``setConvergenceTolerance(_:)``, so the two
    /// are not independent knobs.
    public func setProjectionTolerance(_ value: Double) {
        OCCTBSplineApproxInterpSetProjectionTol(handle, value)
    }
}
