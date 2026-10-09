import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all three nested their assertions two `if let`s deep, and `offset2DBasisCurve` asserted
// nothing (`let _ = basis.domain`). Values from Geom2d_OffsetCurve
// (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
@Suite("Geom2d_OffsetCurve Properties")
struct Geom2dOffsetTests {
    private func make() throws -> Curve2D {
        let base = try #require(Curve2D.line(through: .zero, direction: SIMD2(1, 0)))
        return try #require(base.offset(by: 3))
    }

    @Test func offset2DValue() throws {
        let oc = try make()
        #expect(abs(oc.offsetProperties.offset - 3) < 1e-12)
        #expect(simd_distance(oc.point(at: 0), SIMD2(0, -3)) < 1e-12)
    }

    @Test func offset2DSetValue() throws {
        let oc = try make()
        #expect(oc.offsetProperties.setOffset(5))
        #expect(abs(oc.offsetProperties.offset - 5) < 1e-12)
        #expect(simd_distance(oc.point(at: 0), SIMD2(0, -5)) < 1e-12)
    }

    @Test func offset2DBasisCurve() throws {
        // The basis is the original x-axis line.
        let oc = try make()
        let basis = try #require(oc.offsetProperties.basisCurve)
        #expect(simd_distance(basis.point(at: 2), SIMD2(2, 0)) < 1e-12)
    }
}
