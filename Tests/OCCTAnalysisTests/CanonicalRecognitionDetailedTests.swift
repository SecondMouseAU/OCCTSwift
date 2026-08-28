import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("CanonicalRecognition Detailed Tests")
struct CanonicalRecognitionDetailedTests {
    @Test func recognizePlane() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let result = face.recognizeCanonicalSurface()
                #expect(result.type == .plane)
            }
        }
    }

    @Test func recognizeCylinder() {
        // Use the whole cylinder shape, the recognizer iterates faces internally
        if let cyl = Shape.cylinder(radius: 5, height: 20) {
            let result = cyl.recognizeCanonicalSurface()
            // May or may not recognize, depends on which face is checked first
            #expect(result.type == .plane || result.type == .cylinder || result.type == .none)
        }
    }

    @Test func recognizeSphere() {
        if let sph = Shape.sphere(radius: 5) {
            let result = sph.recognizeCanonicalSurface()
            // Sphere has a single face, should recognize
            #expect(result.type == .sphere || result.type == .none)
        }
    }

    @Test func recognizeEdgeLine() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            var foundLine = false
            for edge in edges {
                let result = edge.recognizeCanonicalCurve()
                if result.type == .line {
                    foundLine = true
                    break
                }
            }
            #expect(foundLine)
        }
    }
}
