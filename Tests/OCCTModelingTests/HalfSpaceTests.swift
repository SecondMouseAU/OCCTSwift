import Testing
import simd

@testable import OCCTSwift

@Suite("Half-Space")
struct HalfSpaceTests {
    @Test("Create half-space from face")
    func halfSpaceFromFace() {
        // Create a planar face to use as the dividing surface
        let rect = Wire.rectangle(width: 20, height: 20)!
        let faceShape = Shape.face(from: rect)!
        let halfSpace = Shape.halfSpace(face: faceShape, referencePoint: SIMD3(0, 0, 5))
        #expect(halfSpace != nil)
    }
}
