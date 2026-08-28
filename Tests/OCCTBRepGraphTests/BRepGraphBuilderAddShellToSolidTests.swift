import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddShellToSolid")
struct BRepGraphBuilderAddShellToSolidTests {
    @Test func linkShellToSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if let solidIdx = graph.addSolid(), let shellIdx = graph.addShell() {
                    let refIdx = graph.addShellToSolid(
                        solidIndex: solidIdx, shellIndex: shellIdx, orientation: 0)
                    #expect(refIdx != nil)
                }
            }
        }
    }
}
