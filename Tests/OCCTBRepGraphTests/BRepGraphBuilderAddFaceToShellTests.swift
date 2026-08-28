import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddFaceToShell")
struct BRepGraphBuilderAddFaceToShellTests {
    @Test func linkFaceToShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // Add a new shell, then link existing face 0 to it
                if let shellIdx = graph.addShell() {
                    let refIdx = graph.addFaceToShell(
                        shellIndex: shellIdx, faceIndex: 0, orientation: 0)
                    #expect(refIdx != nil)
                }
            }
        }
    }
}
