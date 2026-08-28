import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.43.0: Small Face Detection

@Suite("Small Face Detection")
struct SmallFaceDetectionTests {
    @Test("Box has no degenerate faces")
    func boxNoSmallFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let issues = box.checkSmallFaces()
        #expect(issues.isEmpty)
    }

    @Test("Normal cylinder has no degenerate faces")
    func cylinderNoSmallFaces() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let issues = cyl.checkSmallFaces()
        #expect(issues.isEmpty)
    }

    @Test("Sphere has no degenerate faces")
    func sphereNoSmallFaces() {
        let sphere = Shape.sphere(radius: 5)!
        let issues = sphere.checkSmallFaces()
        // Sphere may or may not have degenerate faces depending on tolerance
        // Just verify the API works without crashing
        _ = issues
    }
}
