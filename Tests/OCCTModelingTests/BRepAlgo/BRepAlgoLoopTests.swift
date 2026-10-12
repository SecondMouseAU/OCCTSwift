import Testing

@testable import OCCTSwift

// MARK: - v0.97.0 Tests

@Suite("BRepAlgo Loop Tests")
struct BRepAlgoLoopTests {

    // #3332: the old test was `guard ... else { return }` and `wires >= 1` on face 0 of a plain box.
    // BRepAlgo_Loop builds the wires of a face from its edges, so a face's count is its number of
    // closed loops: 1 for every face of a box, and 2 for a face with one hole (outer boundary plus
    // the hole's circle). Measured on the pinned kernel: the drilled cube's two planar faces with
    // the hole are the two-loop faces, and the hole's cylinder wall answers 0, because its seam
    // edge occurs twice in the face and BRepAlgo_Loop pairs it off rather than closing a wire.
    @Test func buildLoops() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in 0..<6 {
            #expect(box.buildLoops(faceIndex: face) == 1, "plain box face \(face)")
        }

        let drilled = try #require(
            box.drilled(at: SIMD3(0, 0, 8), direction: SIMD3(0, 0, -1), radius: 2, depth: 0))
        var counts: [Int] = []
        for face in 0..<drilled.faceCount {
            counts.append(drilled.buildLoops(faceIndex: face))
        }
        #expect(counts.count == 7)
        #expect(counts.sorted() == [0, 1, 1, 1, 1, 2, 2])

        // A face index that is not there is refused with -1.
        #expect(box.buildLoops(faceIndex: 99) == -1)
    }
}
