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
        // Edge indices may vary across runs (CLAUDE.md, Test Conventions), so pin which edge this
        // is before pinning its trihedron. A kernel that reorders the shape map then fails on
        // the edge's identity, not with a message about a wrong trihedron. Same transcript:
        // edge 0 is a Geom_Circle of radius 10 centred at (0, 0, 5), the top circle.
        let asEdge = try #require(Edge(edge))
        #expect(asEdge.curveType == .circle)
        let circle = try #require(asEdge.circleProperties)
        #expect(abs(circle.radius - 10) < 1e-9)
        #expect(simd_length(circle.center - SIMD3(0, 0, 5)) < 1e-9)
        #expect(circle.isFullCircle)
        let frame = try #require(edge.correctedFrenet(at: 0))
        #expect(simd_length(frame.tangent - SIMD3(0, 1, 0)) < 1e-9)
        #expect(simd_length(frame.normal - SIMD3(-1, 0, 0)) < 1e-9)
        #expect(simd_length(frame.binormal - SIMD3(0, 0, 1)) < 1e-9)
    }
}
