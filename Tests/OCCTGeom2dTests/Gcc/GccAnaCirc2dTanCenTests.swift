import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both nested their only assertion in `if let r`, so a nil result passed.
@Suite("GccAna Circ2dTanCen Tests")
struct GccAnaCirc2dTanCenTests {
    @Test("circle through point centered")
    func pointCentered() throws {
        let r = try #require(circleThroughPointCentered(point: SIMD2(3, 0), center: SIMD2(0, 0)))
        #expect(abs(r.radius - 3.0) < 1e-6)
        #expect(simd_length(r.center) < 1e-12)
    }

    @Test("circle tangent to line centered")
    func lineCentered() throws {
        let r = try #require(
            circleTangentToLineCentered(
                lineOrigin: SIMD2(0, 5), lineDirection: SIMD2(1, 0),
                center: SIMD2(0, 0)))
        #expect(abs(r.radius - 5.0) < 1e-6)
        #expect(simd_length(r.center) < 1e-12)
    }
}
