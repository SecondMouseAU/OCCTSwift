import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCone")
struct TrimmedConeTests {
    @Test("Trimmed cone from endpoints and radii")
    func trimmedCone() throws {
        let surf = try #require(
            Surface.trimmedCone(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
                r1: 5.0, r2: 2.0))
        #expect(surf.handle != nil)
        // Probed (Scripts/repro/766-math-trimmed-trsf-extras): u spans [0, 2pi]; v runs along the
        // slant from 0 to sqrt(3^2 + 10^2) = 10.4403..., radius 5 at point1 and 2 at point2.
        let d = surf.domain
        #expect(abs(d.uMin) < 1e-12)
        #expect(abs(d.uMax - 2 * .pi) < 1e-12)
        #expect(abs(d.vMin) < 1e-12)
        #expect(abs(d.vMax - 109.0.squareRoot()) < 1e-9)
        #expect(simd_distance(surf.point(atU: 0, v: d.vMin), SIMD3<Double>(5, 0, 0)) < 1e-9)
        #expect(simd_distance(surf.point(atU: 0, v: d.vMax), SIMD3<Double>(2, 0, 10)) < 1e-9)
    }
}

