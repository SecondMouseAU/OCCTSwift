import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.78.0: Shape Modifications, Surface Recognition & Polygon Data

@Suite("BRepTools_TrsfModification")
struct TrsfModificationTests {
    @Test("apply translation via modifier")
    func applyTranslation() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            // Identity rotation + translation (100, 200, 300)
            if let result = Shape.trsfModification(
                box,
                a11: 1, a12: 0, a13: 0, a14: 100,
                a21: 0, a22: 1, a23: 0, a24: 200,
                a31: 0, a32: 0, a33: 1, a34: 300)
            {
                #expect(result.isValid)
                if let v = result.volume {
                    #expect(abs(v - 6000) < 1.0)
                }
            }
        }
    }

    @Test("apply rotation via modifier")
    func applyRotation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // 90° rotation around Z: (cos90, -sin90, 0) = (0, -1, 0), (sin90, cos90, 0) = (1, 0, 0)
            if let result = Shape.trsfModification(
                box,
                a11: 0, a12: -1, a13: 0, a14: 0,
                a21: 1, a22: 0, a23: 0, a24: 0,
                a31: 0, a32: 0, a33: 1, a34: 0)
            {
                #expect(result.isValid)
            }
        }
    }
}

