import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Generator")
struct GeomFillGeneratorTests {
    @Test func twoCircles() throws {
        let c1Opt = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 1.0)
        let c2Opt = Curve3D.circle(center: SIMD3(0, 0, 2), normal: SIMD3(0, 0, 1), radius: 1.5)
        // #766: inside `if let` and `!= nil` only; a generator that ignored its second section
        // passed. GeomFill_Generator's ruled surface runs over [0, 2 pi] x [0, 1]; at the middle
        // it is on the radius-1.25 circle at z = 1, and (0, 1) is on the second circle, see
        // Scripts/repro/766-geomfill-b/.
        let c1 = try #require(c1Opt)
        let c2 = try #require(c2Opt)
        let surfOpt = Surface.generatedFromSections(curves: [c1, c2])
        let surf = try #require(surfOpt)
        #expect(simd_length(surf.point(atU: .pi, v: 0.5) - SIMD3(-1.25, 0, 1)) < 1e-6)
        #expect(simd_length(surf.point(atU: 0, v: 1) - SIMD3(1.5, 0, 2)) < 1e-9)
    }

    @Test func threeSections() throws {
        let c1Opt = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 1.0)
        let c2Opt = Curve3D.circle(center: SIMD3(0, 0, 2), normal: SIMD3(0, 0, 1), radius: 1.5)
        let c3Opt = Curve3D.circle(center: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1), radius: 0.5)
        // #766: as above. Three sections give v in [0, 2]; (pi, 1) is on the second circle and
        // (0, 2) on the third, see Scripts/repro/766-geomfill-b/.
        let c1 = try #require(c1Opt)
        let c2 = try #require(c2Opt)
        let c3 = try #require(c3Opt)
        let surfOpt = Surface.generatedFromSections(curves: [c1, c2, c3])
        let surf = try #require(surfOpt)
        #expect(simd_length(surf.point(atU: .pi, v: 1) - SIMD3(-1.5, 0, 2)) < 1e-6)
        #expect(simd_length(surf.point(atU: 0, v: 2) - SIMD3(0.5, 0, 4)) < 1e-9)
    }
}
