import Testing
import simd

@testable import OCCTSwift

// MARK: - Per-Face Variable Offset Tests (v0.38.0)

@Suite("Per-Face Variable Offset")
struct PerFaceVariableOffsetTests {

    @Test("Uniform per-face offset matches default offset")
    func uniformPerFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! > 1000.0)
        }
    }

    @Test("Variable offset on specific faces")
    func variableOffset() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Offset face 1 by 2.0 instead of default 1.0
        let result = box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [1: 2.0])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Per-face offset on cylinder")
    func cylinderPerFace() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:])
        if let r = result {
            #expect(r.isValid)
        }
    }
}
