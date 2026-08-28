import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Continuity Tests")
struct Curve3DContinuityTests {

    @Test func lineContinuity() {
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            let c = line.continuity
            // Lines have infinite continuity (CN = 4)
            #expect(c >= 0)
        }
    }

    @Test func bsplineContinuity() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0),
            SIMD3(2, 0, 0), SIMD3(3, 1, 0),
        ]) {
            let c = bsp.continuity
            #expect(c >= 0)
        }
    }
}
