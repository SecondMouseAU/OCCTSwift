import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.97.0 Tests

@Suite("BRepAlgo Loop Tests")
struct BRepAlgoLoopTests {

    @Test func buildLoops() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let wires = box.buildLoops(faceIndex: 0)
        #expect(wires >= 1)
    }
}
