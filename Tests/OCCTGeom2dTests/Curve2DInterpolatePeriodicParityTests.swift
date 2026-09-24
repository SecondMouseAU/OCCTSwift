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

    @Test("Default tolerance: the two entry points produce the same curve")
    func defaultToleranceMatches() throws {
        let periodic = Curve2D.interpolatePeriodic(points: Self.square)
        expectSameCurve(periodic, Curve2D.interpolate(through: Self.square, closed: true))
        // #1979: agreement alone passed a curve both entry points got wrong. Geom2dAPI_Interpolate
        // gives a periodic curve on [0, 40] reaching (10, 10) at u = 20
        // (Scripts/repro/766-geom2d-interpolate-tangents-periodic/).
        let c = try #require(periodic)
        #expect(abs(c.domain.upperBound - 40) < 1e-12)
        #expect(simd_distance(c.point(at: 20), SIMD2(10, 10)) < 1e-9)
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
        // #1979: on the square the tolerance changes nothing (the probe gives the same curve at
        // 1e-3, 1e-4 and 1e-8), so the loop above passes with the tolerance dropped. Two points
        // 5e-5 apart make it matter: Geom2dAPI_Interpolate refuses them at 1e-4 and accepts them
        // at 1e-8 (Scripts/repro/766-geom2d-interpolate-tangents-periodic/).
        let near: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(10, 10.00005), SIMD2(0, 10),
        ]
        #expect(Curve2D.interpolatePeriodic(points: near, tolerance: 1e-4) == nil)
        #expect(Curve2D.interpolatePeriodic(points: near, tolerance: 1e-8) != nil)
    }

    /// The point-count floor the two had drifted apart on. OCCT accepts a 2-point periodic
    /// interpolation — it produces a valid out-and-back loop — and the general entry point always
    /// let it through; only the periodic wrapper rejected it at the bridge boundary.
    @Test("A 2-point periodic interpolation is accepted by both entry points")
    func twoPointFloorMatches() throws {
        let two: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let periodic = Curve2D.interpolatePeriodic(points: two)
        expectSameCurve(periodic, Curve2D.interpolate(through: two, closed: true))
        // #1979: `if let` let a nil pass; now required, with the out-and-back domain [0, 20].
        let c = try #require(periodic)
        #expect(c.isClosed)
        #expect(c.isPeriodic)
        #expect(abs(c.domain.upperBound - 20) < 1e-12)
    }

    @Test("Both entry points reject a single point")
    func singlePointRejectedByBoth() {
        let one: [SIMD2<Double>] = [SIMD2(1, 2)]
        #expect(Curve2D.interpolatePeriodic(points: one) == nil)
        #expect(Curve2D.interpolate(through: one, closed: true) == nil)
    }
}
