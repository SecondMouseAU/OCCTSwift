import Testing

@testable import OCCTSwift

@Suite("GeomFill CoonsAlgPatch")
struct GeomFillCoonsAlgPatchTests {
    @Test("Coons algorithmic patch from edges")
    func coonsAlgPatch() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard edges.count >= 4 else { return }
        let result = Shape.coonsAlgPatch(
            edge1: edges[0], edge2: edges[1],
            edge3: edges[2], edge4: edges[3],
            evalU: 5, evalV: 5
        )
        #expect(result != nil)
        if let result = result {
            #expect(result.count == 25)  // 5x5 grid
        }
    }
}
