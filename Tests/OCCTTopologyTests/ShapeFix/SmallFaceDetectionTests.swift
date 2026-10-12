import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.43.0: Small Face Detection

@Suite("Small Face Detection")
struct SmallFaceDetectionTests {
    @Test("Box has no degenerate faces")
    func boxNoSmallFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.checkSmallFaces().isEmpty)
        #expect(box.checkSmallFaces(tolerance: 1e-3).isEmpty)

        // Control: the same call on a spot face finds it, so "empty" is not the only answer
        // this method can give.
        let tinyWire = try #require(Wire.rectangle(width: 1e-5, height: 1e-5))
        let spot = try #require(Shape.face(from: tinyWire))
        #expect(spot.checkSmallFaces(tolerance: 1e-3).count == 1)
    }

    @Test("Normal cylinder has no degenerate faces")
    func cylinderNoSmallFaces() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.faceCount == 3)
        #expect(cyl.checkSmallFaces().isEmpty)
        #expect(cyl.checkSmallFaces(tolerance: 1e-3).isEmpty)

        // Control: a spot face is found at a tolerance above its size and not below it.
        let tinyWire = try #require(Wire.rectangle(width: 1e-5, height: 1e-5))
        let spot = try #require(Shape.face(from: tinyWire))
        #expect(spot.checkSmallFaces(tolerance: 1e-3).count == 1)
        #expect(spot.checkSmallFaces(tolerance: 1e-9).isEmpty)
    }

    @Test("Sphere has no degenerate faces")
    func sphereNoSmallFaces() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.checkSmallFaces().isEmpty)
        #expect(sphere.checkSmallFaces(tolerance: 1e-3).isEmpty)

        // Control: a 1e-5 square is a spot face at tolerance 1e-3, located at its centre, so
        // an implementation that reports nothing for every shape cannot pass.
        let tinyWire = try #require(Wire.rectangle(width: 1e-5, height: 1e-5))
        let spot = try #require(Shape.face(from: tinyWire))
        let issues = spot.checkSmallFaces(tolerance: 1e-3)
        #expect(issues.count == 1)
        if let issue = issues.first {
            #expect(issue.isSpotFace)
            #expect(!issue.isStripFace)
            #expect(!issue.isTwisted)
            let location = try #require(issue.spotLocation)
            #expect(vectorDistance(location, .zero) < 1e-6)
        }
    }
}
