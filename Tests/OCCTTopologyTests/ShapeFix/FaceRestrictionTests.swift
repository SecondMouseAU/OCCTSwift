import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.41.0: Face Restriction

@Suite("Face Restriction")
struct FaceRestrictionTests {
    @Test("Restrict face with outer wire")
    func restrictWithOuterWire() throws {
        let outer = try #require(Wire.rectangle(width: 20, height: 20))
        let inner = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: outer))

        // 20-square with a 10-square hole: one face, area 400 - 100 = 300, eight edges.
        let result = try #require(face.faceRestricted(by: [outer, inner]))
        #expect(result.count == 1)
        if let restricted = result.first {
            #expect(restricted.shapeType == .face)
            #expect(restricted.edgeCount == 8)
            #expect(abs(try #require(restricted.surfaceArea) - 300) < 1e-6)
        }

        // Control: the outer wire alone leaves the whole 400.
        let whole = try #require(face.faceRestricted(by: [outer]))
        #expect(whole.count == 1)
        if let single = whole.first {
            #expect(single.edgeCount == 4)
            #expect(abs(try #require(single.surfaceArea) - 400) < 1e-6)
        }
    }
}
