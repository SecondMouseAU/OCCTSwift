import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill EvolvedSection")
struct GeomFillEvolvedSectionTests {
    @Test("Evolved section info on circle edge")
    func evolvedSectionInfo() throws {
        // #766: this looped until an edge answered, checked only `> 0`, and its guards returned
        // silently. Edge 0 is a Geom_Circle; GeomFill_EvolvedSection's SectionShape gives 6 poles,
        // 2 knots, degree 6, rational, see Scripts/repro/766-geomfill-a/.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let edge = try #require(cyl.subShapes(ofType: .edge).first)
        // Edge indices may vary across runs (CLAUDE.md, Test Conventions), so pin which edge this
        // is before pinning its section shape. A kernel that reorders the shape map then fails on
        // the edge's identity, not with a message about a wrong section shape. Same transcript:
        // edge 0 is a Geom_Circle of radius 5 centred at (0, 0, 10), the top circle.
        let asEdge = try #require(Edge(edge))
        #expect(asEdge.curveType == .circle)
        let circle = try #require(asEdge.circleProperties)
        #expect(abs(circle.radius - 5) < 1e-9)
        #expect(simd_length(circle.center - SIMD3(0, 0, 10)) < 1e-9)
        #expect(circle.isFullCircle)
        let info = edge.evolvedSectionInfo()
        #expect(info.nbPoles == 6)
        #expect(info.nbKnots == 2)
        #expect(info.degree == 6)
        #expect(info.isRational)
    }
}
