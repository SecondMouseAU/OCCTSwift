import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #410: interpolate(points:startTangent:endTangent:) gains the tolerance its sibling had

/// `Curve2D.interpolate(points:startTangent:endTangent:)` and
/// `Curve2D.interpolate(through:startTangent:endTangent:tolerance:)` wrap the same
/// `Geom2dAPI_Interpolate` constructor with the same `Load()`/`Perform()`/`IsDone()`/`Curve()`
/// sequence. As two independent implementations, the `points:` spelling had drifted: it hardcoded
/// tolerance at `1e-6` with no parameter to change it. It now delegates.
@Suite("Curve2D tangent interpolation entry points agree (#410)")
struct Curve2DInterpolateTangentsParityTests {

    private static let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)]
    private static let startTangent = SIMD2<Double>(1, 1)
    private static let endTangent = SIMD2<Double>(1, -1)

    @Test("Default tolerance: the two entry points produce the same curve")
    func defaultToleranceMatches() throws {
        let a = Curve2D.interpolate(
            points: Self.points, startTangent: Self.startTangent,
            endTangent: Self.endTangent)
        expectSameCurve(
            a,
            Curve2D.interpolate(
                through: Self.points, startTangent: Self.startTangent,
                endTangent: Self.endTangent))
        // #1979: agreement alone passed a curve both spellings got wrong. Geom2dAPI_Interpolate
        // with these tangents gives 5 poles, (5, 5) mid-range and (1.8496, 2.0648) at u = 2
        // (Scripts/repro/766-geom2d-tangents-islinear-line/).
        let c = try #require(a)
        #expect(c.poleCount == 5)
        #expect(simd_distance(c.point(at: 2), SIMD2(1.84960461481, 2.06475180106)) < 1e-9)
    }

    /// The capability gap #410 found: previously `interpolate(points:...)` had no way to reach
    /// any tolerance other than the hardcoded `1e-6`.
    @Test("A non-default tolerance is now reachable through interpolate(points:...)")
    func customToleranceIsReachable() {
        for tolerance in [1e-3, 1e-4, 1e-8] {
            expectSameCurve(
                Curve2D.interpolate(
                    points: Self.points, startTangent: Self.startTangent,
                    endTangent: Self.endTangent, tolerance: tolerance),
                Curve2D.interpolate(
                    through: Self.points, startTangent: Self.startTangent,
                    endTangent: Self.endTangent, tolerance: tolerance),
                "tolerance=\(tolerance)")
        }
        // #1979: for these three points the tolerance changes nothing (the probe gives the same
        // curve at 1e-3, 1e-6 and 1e-8), so the loop passes with the tolerance dropped. Two points
        // 5e-5 apart make it matter: refused at 1e-4, accepted at 1e-8.
        let near: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 5), SIMD2(5, 5.00005), SIMD2(10, 0)]
        #expect(
            Curve2D.interpolate(
                points: near, startTangent: Self.startTangent, endTangent: Self.endTangent,
                tolerance: 1e-4) == nil)
        #expect(
            Curve2D.interpolate(
                points: near, startTangent: Self.startTangent, endTangent: Self.endTangent,
                tolerance: 1e-8) != nil)
    }

    @Test("Both entry points reject a single point")
    func singlePointRejectedByBoth() {
        let one: [SIMD2<Double>] = [SIMD2(1, 2)]
        #expect(
            Curve2D.interpolate(
                points: one, startTangent: Self.startTangent,
                endTangent: Self.endTangent) == nil)
        #expect(
            Curve2D.interpolate(
                through: one, startTangent: Self.startTangent,
                endTangent: Self.endTangent) == nil)
    }
}
