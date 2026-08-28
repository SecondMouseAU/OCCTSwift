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
    func defaultToleranceMatches() {
        expectSameCurve(
            Curve2D.interpolate(
                points: Self.points, startTangent: Self.startTangent,
                endTangent: Self.endTangent),
            Curve2D.interpolate(
                through: Self.points, startTangent: Self.startTangent,
                endTangent: Self.endTangent))
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
