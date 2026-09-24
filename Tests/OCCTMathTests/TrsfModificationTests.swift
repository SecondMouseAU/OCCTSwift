import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.78.0: Shape Modifications, Surface Recognition & Polygon Data

@Suite("BRepTools_TrsfModification")
struct TrsfModificationTests {
    @Test("apply translation via modifier")
    func applyTranslation() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("box setup nil")
            return
        }
        // Identity rotation + translation (100, 200, 300)
        guard
            let result = Shape.trsfModification(
                box,
                a11: 1, a12: 0, a13: 0, a14: 100,
                a21: 0, a22: 1, a23: 0, a24: 200,
                a31: 0, a32: 0, a33: 1, a34: 300)
        else {
            Issue.record("trsfModification returned nil")
            return
        }
        #expect(result.isValid)
        if let v = result.volume {
            #expect(abs(v - 6000) < 1.0)
        }
        // A translation leaves the volume alone, so the volume alone could not see it. Probed
        // (Scripts/repro/766-math-trsfmod-uzawa-vector2d): the centred box moves to
        // (95..105, 190..210, 285..315), each face widened by the 1e-7 vertex tolerance.
        let bounds = result.bounds
        #expect(bounds != nil)
        if let bb = bounds {
            #expect(simd_distance(bb.min, SIMD3<Double>(95, 190, 285)) < 1e-6)
            #expect(simd_distance(bb.max, SIMD3<Double>(105, 210, 315)) < 1e-6)
        }
    }

    @Test("apply rotation via modifier")
    func applyRotation() {
        // A cube centred on the Z axis is its own image under any quarter turn about Z, so a
        // wrong rotation reproduced it. This box is off the axis and not square in XY.
        guard let box = Shape.box(origin: SIMD3(1, 0, 0), width: 10, height: 20, depth: 30) else {
            Issue.record("box setup nil")
            return
        }
        // 90° rotation around Z: (cos90, -sin90, 0) = (0, -1, 0), (sin90, cos90, 0) = (1, 0, 0)
        guard
            let result = Shape.trsfModification(
                box,
                a11: 0, a12: -1, a13: 0, a14: 0,
                a21: 1, a22: 0, a23: 0, a24: 0,
                a31: 0, a32: 0, a33: 1, a34: 0)
        else {
            Issue.record("trsfModification returned nil")
            return
        }
        #expect(result.isValid)
        // Probed (Scripts/repro/766-math-trsfmod-uzawa-vector2d): (x, y) -> (-y, x) takes
        // (1..11, 0..20) to (-20..0, 1..11); z stays 0..30.
        let bounds = result.bounds
        #expect(bounds != nil)
        if let bb = bounds {
            #expect(simd_distance(bb.min, SIMD3<Double>(-20, 1, 0)) < 1e-6)
            #expect(simd_distance(bb.max, SIMD3<Double>(0, 11, 30)) < 1e-6)
        }
    }
}

