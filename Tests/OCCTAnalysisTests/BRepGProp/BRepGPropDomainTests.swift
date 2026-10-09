import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Domain Tests")
struct BRepGPropDomainTests {

    @Test func faceEdgeCount() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let count = box.faceDomainEdgeCount(faceIndex: 0)
        #expect(count >= 3)  // rectangular face has 4 edges
    }
}
