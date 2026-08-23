import Foundation
import OCCTBridge
import simd

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
    ///
    /// If curve wraps a null Geom_Curve handle, the curve is silently dropped instead of.
    /// being added: `GeomFill_Profiler::AddCurve` dereferences it unconditionally, so passing
    /// a null handle through uncatchably crashes the process (#710).
    ///
    /// No public Curve3D factory.
    /// can currently produce that state, so this is defensive hardening rather than a documented.
    /// live failure mode; it is called out here because a drop has no signal at the call site.
    /// itself.
    ///
    /// It only shows up indirectly: the profiler ends up holding one fewer curve than the
    /// caller believes, so a curveIndex passed to `poles(curveIndex:)` that counted the dropped
    /// curve addresses the wrong curve (or falls out of range and returns `[]`).
    ///
    /// ```swift.
    /// let profiler = CurveProfiler.create().
    /// profiler.addCurve(curve1).
    /// profiler.addCurve(curve2).
    /// ```.
    public func addCurve(_ curve: Curve3D) {
        OCCTGeomFillProfilerAddCurve(handle, curve.handle)
    }

    /// Perform the homogenization.
    ///
    /// Returns true on success.
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
        guard OCCTGeomFillProfilerPoles(handle, Int32(curveIndex), &xs, &ys, &zs, Int32(n)) else {
            return []
        }
        return (0..<n).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Get knots and multiplicities.
    public func knotsAndMults() -> (knots: [Double], mults: [Int]) {
        let n = knotCount
        guard n > 0 else { return ([], []) }
        var knots = [Double](repeating: 0, count: n)
        var mults = [Int32](repeating: 0, count: n)
        guard OCCTGeomFillProfilerKnotsAndMults(handle, &knots, &mults, Int32(n)) else {
            return ([], [])
        }
        return (knots, mults.map { Int($0) })
    }
}
