import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe BuildWires")
struct LocOpeBuildWiresTests {
    @Test("Build wires from face edges")
    func buildWiresFromFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let wires = box.buildWires(faceIndex: 1)
        #expect(wires != nil)
        if let wires = wires {
            #expect(wires.count > 0)
        }
    }
}
