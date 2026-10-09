import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Audit Fix Tests

@Suite("Shape.fromFace conversion") struct ShapeFromFaceTests {
    @Test("Shape.fromFace converts face to shape")
    func faceToShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let faces = box.faces()
            #expect(faces.count > 0)
            if let face = faces.first {
                let shape = Shape.fromFace(face)
                #expect(shape != nil)
                if let shape {
                    #expect(shape.isValid)
                }
            }
        }
    }
}
