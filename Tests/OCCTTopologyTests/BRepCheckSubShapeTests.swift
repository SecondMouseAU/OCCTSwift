import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepCheck SubShape Tests")
struct BRepCheckSubShapeTests {
    @Test("Check edge validity")
    func edgeValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkEdge(at: 0)
        #expect(result.isValid, "First edge should be valid")
    }

    @Test("Check wire validity")
    func wireValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkWire(at: 0)
        #expect(result.isValid, "First wire should be valid")
    }

    @Test("Check shell validity")
    func shellValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkShell(at: 0)
        #expect(result.isValid, "Shell should be valid")
    }

    @Test("Check vertex validity")
    func vertexValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.checkVertex(at: 0)
        #expect(result.isValid, "First vertex should be valid")
    }
}
