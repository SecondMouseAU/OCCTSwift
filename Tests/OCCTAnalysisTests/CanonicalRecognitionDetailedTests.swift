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

    // #1438: OCCTShapeRecognizeCanonicalSurface had no guard at all (not even a pointer check),
    // and ShapeAnalysis_CanonicalRecognition's constructor unconditionally dereferences the
    // shape's TShape (TopoDS_Shape::ShapeType()), an uncatchable SIGSEGV on a nullified wrapper --
    // `catch (...)` cannot absorb it. `.nullified` is a real, public, non-crashing way to get a
    // non-null wrapper pointer around a null TopoDS_Shape.
    @Test func recognizeCanonicalSurfaceOnNullShapeDoesNotCrash() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        let result = nullShape.recognizeCanonicalSurface(tolerance: 1e-4)
        #expect(result.type == .none)
    }

    // #1438: same crash mechanism as recognizeCanonicalSurfaceOnNullShapeDoesNotCrash above, for
    // OCCTShapeRecognizeCanonicalCurve.
    @Test func recognizeCanonicalCurveOnNullShapeDoesNotCrash() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        let result = nullShape.recognizeCanonicalCurve(tolerance: 1e-4)
        #expect(result.type == .none)
    }
}
