import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Canonical Recognition")
struct CanonicalRecognitionTests {
    @Test("Canonical recognition callable on box")
    func recognizeCallableOnBox() {
        // ShapeAnalysis_CanonicalRecognition is designed to identify when
        // BSpline approximations can be converted to canonical forms (plane,
        // cylinder, etc). On already-canonical primitive shapes it may return nil.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let form = box.recognizeCanonical()
        // May be nil for primitive shapes, just verify no crash
        if let form {
            #expect(form.type == .plane)
        }
    }

    @Test("Canonical recognition callable on cylinder")
    func recognizeCallableOnCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        _ = cyl.recognizeCanonical()
        // Just verify no crash, whole-shape recognition often returns nil
    }
}
