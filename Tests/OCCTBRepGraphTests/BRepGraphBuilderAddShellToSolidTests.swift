import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddShellToSolid")
struct BRepGraphBuilderAddShellToSolidTests {
    // New solid 1 and new shell 1; the box's own solid already holds shell ref 0, so the
    // link is ref 1, per the kernel probe. Both adds are required rather than wrapped in
    // `if let`, which let a failing addSolid/addShell skip the assertion (#1986).
    @Test func linkShellToSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let solidIdx = try #require(graph.addSolid())
        let shellIdx = try #require(graph.addShell())
        #expect(solidIdx == 1)
        #expect(shellIdx == 1)
        let refIdx = graph.addShellToSolid(
            solidIndex: solidIdx, shellIndex: shellIdx, orientation: 0)
        #expect(refIdx == 1)
    }
}
