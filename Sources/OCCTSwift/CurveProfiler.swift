import Foundation
import simd
import OCCTBridge

/// Homogenizes a set of curves to the same BSpline representation.
public final class CurveProfiler: @unchecked Sendable {
    let handle: OCCTGeomFillProfilerRef

    init(handle: OCCTGeomFillProfilerRef) {
        self.handle = handle
    }

    deinit {
        OCCTGeomFillProfilerRelease(handle)
    }

    /// Create a new curve profiler.
    public static func create() -> CurveProfiler {
        let ref = OCCTGeomFillProfilerCreate()!
        return CurveProfiler(handle: ref)
    }

    /// Add a curve to the profiler.
    public func addCurve(_ curve: Curve3D) {
        OCCTGeomFillProfilerAddCurve(handle, curve.handle)
    }

    /// Perform the homogenization. Returns true on success.
    @discardableResult
    public func perform(tolerance: Double = 1e-6) -> Bool {
        OCCTGeomFillProfilerPerform(handle, tolerance)
    }

    /// Degree of the homogenized curves.
    public var degree: Int { Int(OCCTGeomFillProfilerDegree(handle)) }

    /// Number of poles per curve.
    public var poleCount: Int { Int(OCCTGeomFillProfilerNbPoles(handle)) }

    /// Number of knots.
    public var knotCount: Int { Int(OCCTGeomFillProfilerNbKnots(handle)) }

    /// Whether the curves are periodic.
    public var isPeriodic: Bool { OCCTGeomFillProfilerIsPeriodic(handle) }

    /// Get poles for a curve at 1-based index.
    public func poles(curveIndex: Int) -> [SIMD3<Double>] {
        let n = poleCount
        guard n > 0 else { return [] }
        var xs = [Double](repeating: 0, count: n)
        var ys = [Double](repeating: 0, count: n)
        var zs = [Double](repeating: 0, count: n)
        guard OCCTGeomFillProfilerPoles(handle, Int32(curveIndex), &xs, &ys, &zs, Int32(n)) else { return [] }
        return (0..<n).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Get knots and multiplicities.
    public func knotsAndMults() -> (knots: [Double], mults: [Int]) {
        let n = knotCount
        guard n > 0 else { return ([], []) }
        var knots = [Double](repeating: 0, count: n)
        var mults = [Int32](repeating: 0, count: n)
        guard OCCTGeomFillProfilerKnotsAndMults(handle, &knots, &mults, Int32(n)) else { return ([], []) }
        return (knots, mults.map { Int($0) })
    }
}
