import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `ShapeUpgrade_SplitCurve3d`, asserted on where the split landed.
///
/// The two assertions used to be `#expect(result.first.handle != nil)` and the same on `.second`,
/// always true for a non-optional `OCCTCurve3DRef` (#3018). A split that returned the whole curve
/// twice, or swapped the halves, satisfied both. What a split owes its caller is three things: the
/// two parameter ranges meet at the split parameter and cover the original between them, the two
/// pieces meet at the same point in space, and the outer ends are the original's outer ends.
@Suite("ShapeUpgrade_SplitCurve3d")
struct CurveSplitTests {
    @Test("Split curve at midpoint")
    func splitCurve() throws {
        let curve = try #require(
            Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(2, 5, 0),
                SIMD3(5, 3, 0), SIMD3(8, 7, 0),
                SIMD3(10, 0, 0),
            ]))
        let dom = curve.domain
        let mid = (dom.lowerBound + dom.upperBound) / 2.0
        let seam = curve.point(at: mid)
        let result = try #require(curve.splitAt(parameter: mid))

        // The parameter ranges partition the original at `mid`.
        #expect(abs(result.first.domain.lowerBound - dom.lowerBound) < 1e-9)
        #expect(abs(result.first.domain.upperBound - mid) < 1e-9)
        #expect(abs(result.second.domain.lowerBound - mid) < 1e-9)
        #expect(abs(result.second.domain.upperBound - dom.upperBound) < 1e-9)

        // The pieces are the right way round and meet where the split was asked for.
        #expect(simd_distance(result.first.startPoint, curve.startPoint) < 1e-9)
        #expect(simd_distance(result.first.endPoint, seam) < 1e-9)
        #expect(simd_distance(result.second.startPoint, seam) < 1e-9)
        #expect(simd_distance(result.second.endPoint, curve.endPoint) < 1e-9)

        // The control: the two halves are different curves, so "split" is not "copied twice". The
        // fixture's start and end are 10 apart, so the seam cannot coincide with either.
        #expect(simd_distance(curve.startPoint, seam) > 1.0)
        #expect(simd_distance(curve.endPoint, seam) > 1.0)
    }
}
