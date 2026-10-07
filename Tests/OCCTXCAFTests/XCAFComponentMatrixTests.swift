import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("XCAF full-matrix component placement (#174)")
struct XCAFComponentMatrixTests {
    private func placement(
        _ doc: Document, _ componentLabelId: Int64
    ) throws -> (min: SIMD3<Double>, max: SIMD3<Double>) {
        let node = try #require(doc.node(at: componentLabelId), "component \(componentLabelId)")
        let shape = try #require(node.shape, "component \(componentLabelId) carries no shape")
        return try #require(shape.boundingBox, "component \(componentLabelId) has no bounds")
    }

    @Test("Full 4x4 places components (rotation + reflection) under an assembly")
    func matrixComponentPlacement() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 4, height: 2, depth: 1))
        let asmShape = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let part = doc.addShape(box, makeAssembly: false)
        let asm = doc.addShape(asmShape, makeAssembly: true)
        // Rigid: 90° about Z + translation (10,20,30), row-major [r00..r22, tx,ty,tz].
        let rigid: [Double] = [0, -1, 0, 1, 0, 0, 0, 0, 1, 10, 20, 30]
        let rigidId = doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: rigid)
        #expect(rigidId >= 0)
        // Reflection (det −1, mirror X), gp_Trsf accepts it as a negative-scale location, so a
        // mirrored occurrence can be placed directly without baking a separate mirrored product.
        let reflect: [Double] = [-1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0]
        let reflectId = doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: reflect)
        #expect(reflectId >= 0)
        #expect(reflectId != rigidId)
        #expect(doc.componentCount(assemblyLabelId: asm) == 2)

        // A malformed matrix is rejected, whatever its length, and adds nothing.
        #expect(
            doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: [1, 2, 3]) == -1)
        #expect(
            doc.addComponent(
                assemblyLabelId: asm, shapeLabelId: part,
                matrix: [Double](repeating: 0, count: 11)) == -1)
        #expect(
            doc.addComponent(
                assemblyLabelId: asm, shapeLabelId: part,
                matrix: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0]) == -1)
        #expect(doc.componentCount(assemblyLabelId: asm) == 2)

        // Both occurrences are of the part, in the order they were added.
        #expect(doc.componentLabelId(assemblyLabelId: asm, at: 0) == rigidId)
        #expect(doc.componentLabelId(assemblyLabelId: asm, at: 1) == reflectId)
        #expect(doc.componentReferredLabelId(rigidId) == part)
        #expect(doc.componentReferredLabelId(reflectId) == part)

        // Where each one landed. The part is a 4 x 2 x 1 box centred on the origin, so it spans
        // x +-2, y +-1, z +-0.5. The rigid matrix sends (x, y, z) to (-y + 10, x + 20, z + 30):
        // x 9...11, y 18...22, z 29.5...30.5. The reflection sends it to (-x + 5, y, z):
        // x 3...7, y +-1, z +-0.5. A rotation read transposed, a dropped translation or a dropped
        // reflection each moves one of these. The bounding box is padded by about 1e-7.
        func expectBounds(
            _ b: (min: SIMD3<Double>, max: SIMD3<Double>), _ lo: SIMD3<Double>,
            _ hi: SIMD3<Double>, _ what: String
        ) {
            #expect(simd_length(b.min - lo) < 1e-5, "\(what): min \(b.min), expected \(lo)")
            #expect(simd_length(b.max - hi) < 1e-5, "\(what): max \(b.max), expected \(hi)")
        }
        expectBounds(
            try placement(doc, rigidId), SIMD3(9, 18, 29.5), SIMD3(11, 22, 30.5), "rigid")
        expectBounds(
            try placement(doc, reflectId), SIMD3(3, -1, -0.5), SIMD3(7, 1, 0.5), "reflection")
    }
}
