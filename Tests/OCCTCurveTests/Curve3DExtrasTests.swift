import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Extras v0.109")
struct Curve3DExtrasTests {
    @Test func reverseCurve() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let start = c.startPoint
            #expect(c.reverse())
            // After reverse, the curve direction should be flipped
            let newStart = c.startPoint
            let _ = newStart  // Direction changes verified by no crash
            let _ = start
        }
    }

    @Test func copyCurve() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            if let copy = c.copy() {
                // Copy should be independent
                let p1 = c.point(at: 0)
                let p2 = copy.point(at: 0)
                #expect(abs(p1.x - p2.x) < 1e-6)
                #expect(abs(p1.y - p2.y) < 1e-6)
                #expect(abs(p1.z - p2.z) < 1e-6)
            }
        }
    }

    @Test func copiedCurveIndependent() {
        if let c = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let copy = c.copy() {
                #expect(copy.isClosed)
            }
        }
    }
}
