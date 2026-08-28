import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib MakeFace")
struct BRepLibMakeFaceTests {
    @Test("Face from plane with UV bounds")
    func faceFromPlane() {
        let face = Shape.faceFromPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            uRange: 0...10,
            vRange: 0...10
        )
        #expect(face != nil)
        if let face = face { #expect(face.isValid) }
    }

    @Test("Face from cylinder with UV bounds")
    func faceFromCylinder() {
        let face = Shape.faceFromCylinder(
            origin: SIMD3(0, 0, 0),
            axis: SIMD3(0, 0, 1),
            radius: 5,
            uRange: 0...(.pi),
            vRange: 0...10
        )
        #expect(face != nil)
        if let face = face { #expect(face.isValid) }
    }
}
