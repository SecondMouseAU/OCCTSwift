import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib ToolTriangulatedShape")
struct BRepLibToolTriangulatedShapeTests {
    @Test("Compute normals on meshed shape")
    func computeNormals() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.1)
        let result = box.computeNormals()
        #expect(result == true)
    }
}
