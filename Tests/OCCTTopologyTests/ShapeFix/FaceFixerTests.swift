import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.113.0 - FaceFixer")
struct FaceFixerTests {

    @Test func fixBoxFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let fixer = try #require(FaceFixer(face: faces[0]))
        // A healthy planar face has nothing to fix: every pass reports no change.
        #expect(!fixer.perform())
        #expect(!fixer.fixOrientation())
        #expect(!fixer.fixAddNaturalBound())
        #expect(!fixer.fixMissingSeam())
        #expect(!fixer.fixSmallAreaWire())

        // The face is still the same 10 x 10 plane, valid, with its four edges.
        let fixed = try #require(fixer.face)
        #expect(fixed.shapeType == .face)
        #expect(fixed.isValid)
        #expect(fixed.edgeCount == 4)
        #expect(abs(try #require(Face(fixed)).area() - 100) < 1e-9)
        let surface = try #require(fixed.extractFaceSurface())
        #expect(surface.isPlane)
    }
}
