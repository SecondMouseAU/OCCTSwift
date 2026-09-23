import Testing

@testable import OCCTSwift

@Suite("GeomFill EvolvedSection")
struct GeomFillEvolvedSectionTests {
    @Test("Evolved section info on circle edge")
    func evolvedSectionInfo() {
        // #766: this looped until an edge answered, checked only `> 0`, and its guards returned
        // silently. Edge 0 is a Geom_Circle; GeomFill_EvolvedSection's SectionShape gives 6 poles,
        // 2 knots, degree 6, rational, see Scripts/repro/766-geomfill-a/.
        let cyl = Shape.cylinder(radius: 5, height: 10)
        #expect(cyl != nil)
        guard let edge = cyl?.subShapes(ofType: .edge).first else { return }
        let info = edge.evolvedSectionInfo()
        #expect(info.nbPoles == 6)
        #expect(info.nbKnots == 2)
        #expect(info.degree == 6)
        #expect(info.isRational)
    }
}
