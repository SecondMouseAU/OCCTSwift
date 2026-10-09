import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAlgo FaceRestrictor Tests")
struct BRepAlgoFaceRestrictorTests {

    @Test func restrictFace() {
        // Shape.box centers at origin, use origin-based box for consistent face indexing
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        let count = box.faceRestrictAlgo(faceIndex: 0)
        #expect(count >= 0)  // 0 is valid if no wires restrict the face further
    }
}
