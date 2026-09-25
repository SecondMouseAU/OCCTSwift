import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill CorrectedFrenet")
struct GeomFillCorrectedFrenetTests {
    @Test("Corrected Frenet on edge")
    func correctedFrenetEdge() throws {
        // #766: this looped over edges until one answered and checked only |T| > 0.1, and its
        // guards returned silently. Edge 0 is the top circle; GeomFill_CorrectedFrenet at 0 gives
        // T (0, 1, 0), N (-1, 0, 0), B (0, 0, 1), see Scripts/repro/766-geomfill-a/.
        let cyl = try #require(Shape.cylinder(radius: 10, height: 5))
        let edge = try #require(cyl.subShapes(ofType: .edge).first)
        let frame = try #require(edge.correctedFrenet(at: 0))
        #expect(simd_length(frame.tangent - SIMD3(0, 1, 0)) < 1e-9)
        #expect(simd_length(frame.normal - SIMD3(-1, 0, 0)) < 1e-9)
        #expect(simd_length(frame.binormal - SIMD3(0, 0, 1)) < 1e-9)
    }
}
