import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Face Fixing Tests")
struct FaceFixingTests {

    @Test("Fix face from wire")
    func fixFaceFromWire() throws {
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: wire))
        let faces = face.faces()
        #expect(faces.count == 1)
        let source = try #require(faces.first)

        let fixed = try #require(source.fixed(tolerance: 0.001))
        // The same 10 x 10 face comes back: valid, four edges, area 100.
        #expect(fixed.isValid)
        #expect(fixed.shapeType == .face)
        #expect(fixed.edgeCount == 4)
        #expect(abs(try #require(fixed.surfaceArea) - 100) < 1e-9)
    }
}
