import Testing
import simd

@testable import OCCTSwift

@Suite("BOPTools_AlgoTools Tests")
struct BOPToolsAlgoToolsTests {
    @Test("IsOpenShell - closed box shell")
    func closedShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let shells = b.subShapes(ofType: .shell)
            if let shell = shells.first {
                #expect(!shell.isOpenShell)
            }
        }
    }
}
