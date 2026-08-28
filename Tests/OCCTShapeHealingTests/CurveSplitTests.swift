import Foundation
import Testing
import simd

@testable import OCCTSwift

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
        let result = try #require(curve.splitAt(parameter: mid))
        #expect(result.first.handle != nil)
        #expect(result.second.handle != nil)
    }
}
