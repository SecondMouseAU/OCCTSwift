import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepAlgo FaceRestrictor Tests")
struct BRepAlgoFaceRestrictorTests {

    // The raw bridge entry point with a real output buffer: one result face per face of a box,
    // and for a face that has a hole (one outer wire, one inner wire, still ONE face).
    private func restrictedCount(_ shape: Shape, face: Int) -> Int32 {
        var out = [OCCTShapeRef?](repeating: nil, count: 4)
        let count = out.withUnsafeMutableBufferPointer {
            OCCTBridge.OCCTShapeFaceRestrictAlgo(shape.handle, Int32(face), $0.baseAddress, 4)
        }
        for ref in out { if let ref { OCCTBridge.OCCTShapeRelease(ref) } }
        return count
    }

    // The old test asserted `count >= 0` and said "0 is valid if no wires restrict the face
    // further". 0 is not a valid answer for a box face: one wire restricts it to exactly one face.
    // The Swift wrapper hands the bridge a nil buffer with capacity 0, and the bridge used to count
    // only inside `count < maxFaces`, so `faceRestrictAlgo` answered 0 for every valid face (#3361).
    @Test func restrictFace() throws {
        let box = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        for face in 0..<6 {
            #expect(restrictedCount(box, face: face) == 1, "bridge, box face \(face)")
            #expect(box.faceRestrictAlgo(faceIndex: face) == 1, "wrapper, box face \(face)")
        }

        let drilled = try #require(
            box.drilled(at: SIMD3(5, 5, 12), direction: SIMD3(0, 0, -1), radius: 2, depth: 0))
        #expect(drilled.faceCount > 6)
        for face in 0..<drilled.faceCount {
            #expect(restrictedCount(drilled, face: face) == 1, "bridge, drilled face \(face)")
            #expect(
                drilled.faceRestrictAlgo(faceIndex: face) == 1, "wrapper, drilled face \(face)")
        }

        // The count is not capped by the buffer: a buffer of capacity 0 still answers 1 and
        // stores nothing.
        var out = [OCCTShapeRef?](repeating: nil, count: 1)
        let uncapped = out.withUnsafeMutableBufferPointer {
            OCCTBridge.OCCTShapeFaceRestrictAlgo(box.handle, 0, $0.baseAddress, 0)
        }
        #expect(uncapped == 1)
        #expect(out[0] == nil)

        // A face index that is not there is refused with -1, by the wrapper as well.
        #expect(box.faceRestrictAlgo(faceIndex: -1) == -1)
        #expect(box.faceRestrictAlgo(faceIndex: 99) == -1)
    }
}
