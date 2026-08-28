import Testing
import simd

@testable import OCCTSwift

@Suite("Boolean with History")
struct BooleanHistoryTests {
    @Test("Fuse with history tracks modified faces")
    func fuseWithHistory() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 0, 0))!
        let result = box1.fuseWithHistory(box2)
        #expect(result != nil)
        if let r = result {
            #expect(r.shape.volume! > 0)
            // Should have some modified faces from the intersection
            #expect(r.modifiedFaces.count > 0)
        }
    }

    @Test("Fuse non-overlapping with history")
    func fuseNonOverlappingHistory() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 0, 0))!
        let result = box1.fuseWithHistory(box2)
        #expect(result != nil)
        if let r = result {
            // Non-overlapping fuse should have no modified faces (faces are unchanged)
            #expect(r.modifiedFaces.count == 0)
        }
    }
}
