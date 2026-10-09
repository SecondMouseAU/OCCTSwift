import Testing
import simd

@testable import OCCTSwift

@Suite("Split Shape by Wire")
struct SplitByWireTests {
    @Test("Split box face with diagonal wire")
    func splitBoxFace() {
        // Box is centered: (-5,-5,-5) to (5,5,5)
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Top face is at z=5, index 5 (0-based). Wire must lie ON the face.
        let wire = Wire.line(from: SIMD3(-5, -5, 5), to: SIMD3(5, 5, 5))
        #expect(wire != nil)
        let result = box.splittingFace(with: wire!, faceIndex: 5)
        #expect(result != nil)
        if let r = result {
            // Splitting one face should produce 7 faces (6 original - 1 split + 2 halves)
            #expect(r.faces().count > box.faces().count)
        }
    }

    @Test("Split with invalid face index returns nil")
    func splitInvalidFaceIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let wire = Wire.line(from: SIMD3(-5, -5, 5), to: SIMD3(5, 5, 5))!
        let result = box.splittingFace(with: wire, faceIndex: 999)
        #expect(result == nil)
    }
}
