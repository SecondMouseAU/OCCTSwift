import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFeat_Gluer Tests")
struct BRepFeatGluerTests {
    @Test("glue two boxes at shared face")
    func glueTwoBoxes() {
        let box1 = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)
        guard let b1 = box1, let b2 = box2 else { return }
        // Shared face-pair search helper (also used by LocOpe_GluerTests)
        let result = tryGlueAllFacePairs(b1, b2, glue: { shape1, shape2, pairs in
            shape1.glue(shape2, facePairs: pairs)
        })
        guard let result else { return }
        let rFaces = result.subShapes(ofType: .face)
        let faces1 = b1.subShapes(ofType: .face)
        let faces2 = b2.subShapes(ofType: .face)
        #expect(rFaces.count < faces1.count + faces2.count)
    }
}
