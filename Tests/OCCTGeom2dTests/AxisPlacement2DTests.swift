import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("AxisPlacement2D")
struct AxisPlacement2DTests {
    @Test func createAxis() {
        let axis = AxisPlacement2D(origin: SIMD2(1, 2), direction: SIMD2(0, 1))
        #expect(axis != nil)
        if let axis = axis {
            #expect(abs(axis.origin.x - 1.0) < 1e-10)
            #expect(abs(axis.origin.y - 2.0) < 1e-10)
            #expect(abs(axis.direction.x) < 1e-10)
            #expect(abs(axis.direction.y - 1.0) < 1e-10)
        }
    }

    @Test func reversed() {
        guard let axis = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)),
            let rev = axis.reversed()
        else { return }
        #expect(abs(rev.direction.x + 1.0) < 1e-10)
        #expect(abs(rev.origin.x) < 1e-10)
    }

    @Test func angle() {
        guard let a1 = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(1, 0)),
            let a2 = AxisPlacement2D(origin: SIMD2(0, 0), direction: SIMD2(0, 1))
        else { return }
        let angle = a1.angle(to: a2)
        #expect(abs(angle - .pi / 2) < 1e-10)
    }
}
