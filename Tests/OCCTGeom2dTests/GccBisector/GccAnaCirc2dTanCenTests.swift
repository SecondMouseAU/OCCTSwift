import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GccAna Circ2dTanCen Tests")
struct GccAnaCirc2dTanCenTests {
    @Test("circle through point centered")
    func pointCentered() {
        let result = circleThroughPointCentered(point: SIMD2(3, 0), center: SIMD2(0, 0))
        if let r = result { #expect(abs(r.radius - 3.0) < 1e-6) }
    }

    @Test("circle tangent to line centered")
    func lineCentered() {
        let result = circleTangentToLineCentered(
            lineOrigin: SIMD2(0, 5), lineDirection: SIMD2(1, 0),
            center: SIMD2(0, 0))
        if let r = result { #expect(abs(r.radius - 5.0) < 1e-6) }
    }
}
