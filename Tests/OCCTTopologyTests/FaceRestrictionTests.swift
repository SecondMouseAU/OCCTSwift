import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Face Restriction

@Suite("Face Restriction")
struct FaceRestrictionTests {
    @Test("Restrict face with outer wire")
    func restrictWithOuterWire() {
        let face = Shape.face(from: Wire.rectangle(width: 20, height: 20)!)!
        let outer = Wire.rectangle(width: 20, height: 20)!
        let inner = Wire.rectangle(width: 10, height: 10)!
        let result = face.faceRestricted(by: [outer, inner])
        #expect(result != nil)
        if let result {
            #expect(result.count >= 1)
        }
    }
}
