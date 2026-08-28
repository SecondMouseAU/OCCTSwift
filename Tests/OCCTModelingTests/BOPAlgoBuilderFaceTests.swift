import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_BuilderFace Tests")
struct BOPAlgoBuilderFaceTests {
    @Test("Build face from boundary edges")
    func buildFaceFromEdges() {
        // Create a face and rebuild it from its own edges
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: -5...5, vRange: -5...5)
            if let f = face {
                let edges = f.subShapes(ofType: .edge)
                let result = f.buildFaces(from: edges)
                #expect(result != nil)
                if let r = result {
                    #expect(r.count >= 1)
                }
            }
        }
    }
}
