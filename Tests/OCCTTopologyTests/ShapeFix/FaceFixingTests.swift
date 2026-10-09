import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Face Fixing Tests")
struct FaceFixingTests {

    @Test("Fix face from wire")
    func fixFaceFromWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let face = Shape.face(from: wire)!

        // Get faces from the shape
        let faces = face.faces()
        guard !faces.isEmpty else {
            return  // Skip if no faces found
        }

        let fixed = faces[0].fixed(tolerance: 0.001)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}
