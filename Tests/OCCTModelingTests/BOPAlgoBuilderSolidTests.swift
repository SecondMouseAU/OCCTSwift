import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_BuilderSolid Tests")
struct BOPAlgoBuilderSolidTests {
    @Test("Build solid from box faces")
    func buildSolidFromFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let result = Shape.buildSolids(from: faces)
            #expect(result != nil)
            if let r = result {
                #expect(r.count >= 1)
                if let solid = r.first {
                    #expect(solid.isValid)
                }
            }
        }
    }
}
