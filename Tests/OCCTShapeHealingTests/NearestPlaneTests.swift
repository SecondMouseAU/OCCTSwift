import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-locations-nurbs-sameparam/probe.mm (transcript.txt beside it).
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
        // Kernel: maxDeviation 0.062505859, normal (0.002500313, 0.007500938, 0.999968742).
        #expect(abs(result.maxDeviation - 0.062505859) < 1e-8)
        #expect(simd_distance(result.normal, SIMD3(0.002500313, 0.007500938, 0.999968742)) < 1e-8)
    }
}
