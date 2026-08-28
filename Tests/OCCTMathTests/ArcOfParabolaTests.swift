import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeArcOfParabola")
struct ArcOfParabolaTests {
    @Test("Arc of parabola between parameters")
    func arcOfParabola() throws {
        let arc = try #require(
            Curve3D.arcOfParabola(
                focalDistance: 2.0,
                alpha1: -3.0, alpha2: 3.0))
        let mid = arc.point(at: 0.0)
        #expect(simd_length(mid) < 0.01)
    }
}

