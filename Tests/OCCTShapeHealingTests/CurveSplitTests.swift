import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
// Before #766 the test asserted `handle != nil` on both halves, which no split can fail.
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
        #expect(abs(mid - 10.635412986) < 1e-6)
        let result = try #require(curve.splitAt(parameter: mid))
        #expect(abs(result.first.domain.lowerBound - dom.lowerBound) < 1e-9)
        #expect(abs(result.first.domain.upperBound - mid) < 1e-9)
        #expect(abs(result.second.domain.lowerBound - mid) < 1e-9)
        #expect(abs(result.second.domain.upperBound - dom.upperBound) < 1e-9)
        let joint = SIMD3(6.176464924, 3.684166024, 0.0)
        #expect(simd_distance(result.first.point(at: mid), joint) < 1e-6)
        #expect(simd_distance(result.second.point(at: mid), joint) < 1e-6)
        #expect(simd_distance(result.first.point(at: dom.lowerBound), SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(result.second.point(at: dom.upperBound), SIMD3(10, 0, 0)) < 1e-9)
    }
}
