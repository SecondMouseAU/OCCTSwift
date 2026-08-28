import Testing

@testable import OCCTSwift

@Suite("GeomFill EvolvedSection")
struct GeomFillEvolvedSectionTests {
    @Test("Evolved section info on circle edge")
    func evolvedSectionInfo() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        for edge in edges {
            let info = edge.evolvedSectionInfo()
            if info.nbPoles > 0 {
                #expect(info.degree > 0)
                #expect(info.nbKnots > 0)
                return
            }
        }
    }
}
