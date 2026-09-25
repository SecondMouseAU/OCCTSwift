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
        // The trimmed ends are the parabola at alpha1/alpha2: (t^2 / 4f, t, 0), so (1.125, -3, 0)
        // and (1.125, 3, 0) for f = 2. Kernel values from
        // Scripts/repro/766-math-arcs-axes/transcript.txt. Without these the test passed with the
        // wrong focal distance, since every parabola has its vertex at the origin.
        let dom = arc.domain
        #expect(abs(dom.lowerBound + 3.0) < 1e-12)
        #expect(abs(dom.upperBound - 3.0) < 1e-12)
        let start = arc.point(at: dom.lowerBound)
        let end = arc.point(at: dom.upperBound)
        #expect(simd_length(start - SIMD3(1.125, -3, 0)) < 1e-9)
        #expect(simd_length(end - SIMD3(1.125, 3, 0)) < 1e-9)
    }
}

