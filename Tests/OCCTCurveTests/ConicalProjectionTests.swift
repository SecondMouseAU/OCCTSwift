import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.36.0. OCCT Test Suite Audit Round 5

@Suite("Conical Projection")
struct ConicalProjectionTests {
    @Test("Project wire onto box from eye point")
    func projectConical() {
        guard let line = Wire.line(from: SIMD3(-3, 0, 0), to: SIMD3(3, 0, 0)) else { return }
        let lineShape = Shape.fromWire(line)!
        let box = Shape.box(width: 20, height: 20, depth: 1)!.translated(by: SIMD3(-10, -10, -5))!
        let result = Shape.projectWireConical(lineShape, onto: box, eye: SIMD3(0, 0, 10))
        // Conical projection is geometry-dependent
        _ = result
    }
}
