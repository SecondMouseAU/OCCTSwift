import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_ShellSplitter Tests")
struct BOPAlgoShellSplitterTests {
    @Test("Split single box shell")
    func splitSingleShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let shells = b.subShapes(ofType: .shell)
            if let shell = shells.first {
                let result = shell.splitShell()
                #expect(result != nil)
                if let r = result {
                    // A single connected box shell has nothing to split apart: over-splitting
                    // (e.g. one piece per face) would still satisfy `>= 1` and hide the defect
                    // (#764).
                    #expect(r.count == 1)
                    if let first = r.first {
                        #expect(first.subShapes(ofType: .face).count == 6)
                    }
                }
            }
        }
    }
}
