import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #412: interpolatePeriodic is interpolate(closed: true)

/// `Curve2D.interpolatePeriodic(points:)` and `Curve2D.interpolate(through:closed:tolerance:)`
/// wrap the same `Geom2dAPI_Interpolate` constructor with the same `Perform()`/`IsDone()`/
/// `Curve()` sequence. As two independent implementations they had already drifted: the periodic
/// one pinned the tolerance at `1e-6` with no way to reach it, and rejected `count < 3` where the
/// general one rejects only `count < 2`. It now delegates.
@Suite("Curve2D periodic interpolation delegates (#412)")
struct Curve2DInterpolatePeriodicParityTests {

    private static let square: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
    ]

    private func expectSameCurve(
        _ a: Curve2D?, _ b: Curve2D?,
        _ comment: Comment? = nil
    ) {
        #expect(a != nil, comment)
        #expect(b != nil, comment)
        guard let a, let b else { return }
        #expect(a.isClosed == b.isClosed, comment)
        #expect(a.isPeriodic == b.isPeriodic, comment)
        #expect(abs(a.domain.lowerBound - b.domain.lowerBound) < 1e-12, comment)
        #expect(abs(a.domain.upperBound - b.domain.upperBound) < 1e-12, comment)
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            let ua = a.domain.lowerBound + t * (a.domain.upperBound - a.domain.lowerBound)
            let ub = b.domain.lowerBound + t * (b.domain.upperBound - b.domain.lowerBound)
            let pa = a.point(at: ua)
            let pb = b.point(at: ub)
            #expect(abs(pa.x - pb.x) < 1e-9, comment)
            #expect(abs(pa.y - pb.y) < 1e-9, comment)
        }
    }

    @Test("Default tolerance: the two entry points produce the same curve")
    func defaultToleranceMatches() {
        expectSameCurve(
            Curve2D.interpolatePeriodic(points: Self.square),
            Curve2D.interpolate(through: Self.square, closed: true))
    }

    @Test("A non-default tolerance is now reachable through interpolatePeriodic")
    func customToleranceIsReachable() {
        for tolerance in [1e-3, 1e-4, 1e-8] {
            expectSameCurve(
                Curve2D.interpolatePeriodic(points: Self.square, tolerance: tolerance),
                Curve2D.interpolate(
                    through: Self.square, closed: true,
                    tolerance: tolerance),
                "tolerance=\(tolerance)")
        }
    }

    /// The point-count floor the two had drifted apart on. OCCT accepts a 2-point periodic
    /// interpolation — it produces a valid out-and-back loop — and the general entry point always
    /// let it through; only the periodic wrapper rejected it at the bridge boundary.
    @Test("A 2-point periodic interpolation is accepted by both entry points")
    func twoPointFloorMatches() {
        let two: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let periodic = Curve2D.interpolatePeriodic(points: two)
        expectSameCurve(periodic, Curve2D.interpolate(through: two, closed: true))
        if let c = periodic {
            #expect(c.isClosed)
            #expect(c.isPeriodic)
        }
    }

    @Test("Both entry points reject a single point")
    func singlePointRejectedByBoth() {
        let one: [SIMD2<Double>] = [SIMD2(1, 2)]
        #expect(Curve2D.interpolatePeriodic(points: one) == nil)
        #expect(Curve2D.interpolate(through: one, closed: true) == nil)
    }
}
