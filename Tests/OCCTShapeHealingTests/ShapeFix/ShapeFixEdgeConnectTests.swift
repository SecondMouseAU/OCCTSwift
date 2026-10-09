import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix EdgeConnect Tests")
struct ShapeFixEdgeConnectTests {
    @Test func fixEdgeConnect() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let fixed = box.fixEdgeConnect()
            #expect(fixed != nil)
        }
    }
}
