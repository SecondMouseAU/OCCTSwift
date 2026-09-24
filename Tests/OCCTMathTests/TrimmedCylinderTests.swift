import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCylinder")
struct TrimmedCylinderTests {
    @Test("Trimmed cylinder from axis, radius, height")
    func trimmedCylinder() throws {
        let surf = try #require(Surface.trimmedCylinder(radius: 4.0, height: 8.0))
        #expect(surf.handle != nil)
        // Probed (Scripts/repro/766-math-trimmed-trsf-extras): u spans [0, 2pi], v spans the
        // height [0, 8], and the seam runs from (4, 0, 0) to (4, 0, 8).
        let d = surf.domain
        #expect(abs(d.uMin) < 1e-12)
        #expect(abs(d.uMax - 2 * .pi) < 1e-12)
        #expect(abs(d.vMin) < 1e-12)
        #expect(abs(d.vMax - 8) < 1e-12)
        #expect(simd_distance(surf.point(atU: 0, v: d.vMin), SIMD3<Double>(4, 0, 0)) < 1e-12)
        #expect(simd_distance(surf.point(atU: 0, v: d.vMax), SIMD3<Double>(4, 0, 8)) < 1e-12)
    }
}

