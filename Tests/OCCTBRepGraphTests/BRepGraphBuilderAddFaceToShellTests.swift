import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddFaceToShell")
struct BRepGraphBuilderAddFaceToShellTests {
    // The box already holds 6 face refs (indices 0-5), so linking face 0 to the new shell 1
    // yields ref 6, per the kernel probe. The shell add is required rather than wrapped in
    // `if let`, which let a failing addShell skip the assertion (#1986).
    @Test func linkFaceToShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let shellIdx = try #require(graph.addShell())
        #expect(shellIdx == 1)
        let refIdx = try #require(graph.addFaceToShell(
            shellIndex: shellIdx, faceIndex: 0, orientation: 0))
        #expect(refIdx == 6)
    }
}
