import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAF full-matrix component placement (#174)")
struct XCAFComponentMatrixTests {
    @Test("Full 4x4 places components (rotation + reflection) under an assembly")
    func matrixComponentPlacement() throws {
        guard let doc = Document.create(), let box = Shape.box(width: 4, height: 2, depth: 1),
            let asmShape = Shape.box(width: 1, height: 1, depth: 1)
        else {
            Issue.record("no doc/box")
            return
        }
        let part = doc.addShape(box, makeAssembly: false)
        let asm = doc.addShape(asmShape, makeAssembly: true)
        // Rigid: 90° about Z + translation (10,20,30), row-major [r00..r22, tx,ty,tz].
        let rigid: [Double] = [0, -1, 0, 1, 0, 0, 0, 0, 1, 10, 20, 30]
        #expect(doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: rigid) >= 0)
        // Reflection (det −1, mirror X), gp_Trsf accepts it as a negative-scale location, so a
        // mirrored occurrence can be placed directly without baking a separate mirrored product.
        let reflect: [Double] = [-1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0]
        #expect(doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: reflect) >= 0)
        // A malformed matrix is rejected.
        #expect(
            doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: [1, 2, 3]) == -1)
        #expect(doc.componentCount(assemblyLabelId: asm) == 2)
    }
}
