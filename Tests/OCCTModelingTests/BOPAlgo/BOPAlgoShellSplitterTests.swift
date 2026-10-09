import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_ShellSplitter Tests")
struct BOPAlgoShellSplitterTests {
    @Test("Split single box shell")
    func splitSingleShell() throws {
        // #766: every step used to sit in a nested `if let`, so a box or shell that failed to
        // build skipped all the assertions. The fixtures are now `try #require`.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shells = b.subShapes(ofType: .shell)
        let shell = try #require(shells.first)
        let r = try #require(shell.splitShell())
        // A single connected box shell has nothing to split apart: over-splitting
        // (e.g. one piece per face) would still satisfy `>= 1` and hide the defect
        // (#764).
        #expect(r.count == 1)
        let first = try #require(r.first)
        #expect(first.subShapes(ofType: .face).count == 6)
    }
}
