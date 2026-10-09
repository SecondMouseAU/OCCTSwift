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
        guard let halfSpace = Shape.halfSpace(face: faceShape, referencePoint: SIMD3(0, 0, 5))
        else {
            Issue.record("halfSpace(face:referencePoint:) returned nil")
            return
        }
        // #766: this was `#expect(halfSpace != nil)` alone, which OCCTShapeCreateHalfSpace passes
        // for a null solid (it wraps BRepPrimAPI_MakeHalfSpace::Solid() without a null check) and
        // for a half-space on the wrong side of the face. Pinned to the kernel
        // (Scripts/repro/766-modeling-half-space): a solid whose material lies on the reference
        // point's side, so (0, 0, 5) is inside and (0, 0, -5) outside.
        #expect(halfSpace.shapeType == .solid)
        #expect(halfSpace.classify(point: SIMD3(0, 0, 5)) == .inside)
        #expect(halfSpace.classify(point: SIMD3(0, 0, -5)) == .outside)
    }
}
