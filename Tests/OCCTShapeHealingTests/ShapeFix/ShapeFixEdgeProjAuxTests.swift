import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix EdgeProjAux Tests")
struct ShapeFixEdgeProjAuxTests {

    @Test func projectEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.edgeProjAux(faceIndex: 0, edgeIndex: 0) {
            #expect(result.last > result.first || result.last == result.first)
        }
    }
}
