import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.36.0. OCCT Test Suite Audit Round 5

@Suite("Conical Projection")
struct ConicalProjectionTests {
    // The earlier version ended in `_ = result` and could not fail (#766). BRepProj_Projection of
    // the same line onto the same box from the same eye gives four edges on the box's x <= 0
    // corner, x from -4.65 to 0 and z from -5.5 to -4.5
    // (Scripts/repro/766-curve-comp-conic-deflection/transcript.txt).
    @Test("Project wire onto box from eye point")
    func projectConical() {
        guard let line = Wire.line(from: SIMD3(-3, 0, 0), to: SIMD3(3, 0, 0)),
            let lineShape = Shape.fromWire(line),
            let box = Shape.box(width: 20, height: 20, depth: 1)?.translated(by: SIMD3(-10, -10, -5))
        else {
            Issue.record("fixtures not built")
            return
        }
        guard let result = Shape.projectWireConical(lineShape, onto: box, eye: SIMD3(0, 0, 10)) else {
            Issue.record("conical projection returned nil")
            return
        }
        #expect(result.subShapeCount(ofType: .edge) == 4)
        #expect(result.subShapeCount(ofType: .vertex) == 4)
        guard let b = result.bounds else {
            Issue.record("projection has no bounds")
            return
        }
        #expect(abs(b.min.x + 4.65) < 1e-6)
        #expect(abs(b.max.x) < 1e-6)
        #expect(abs(b.min.z + 5.5) < 1e-6)
        #expect(abs(b.max.z + 4.5) < 1e-6)
    }
}
