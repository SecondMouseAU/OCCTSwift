import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_Geom NearestPlane")
struct NearestPlaneTests {
    @Test("Fit plane to nearly-coplanar points")
    func nearestPlane() throws {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0.1),
            SIMD3(10, 10, -0.1),
            SIMD3(0, 10, 0.05),
        ]
        let result = try #require(Shape.nearestPlane(to: points))
        #expect(result.maxDeviation < 0.2)
        #expect(abs(result.normal.z) > 0.9)
    }
}
