import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2d_OffsetCurve Properties")
struct Geom2dOffsetTests {
    @Test func offset2DValue() {
        if let base = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
            if let oc = base.offset(by: 3) {
                #expect(abs(oc.offsetProperties.offset - 3) < 1e-6)
            }
        }
    }

    @Test func offset2DSetValue() {
        if let base = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
            if let oc = base.offset(by: 3) {
                #expect(oc.offsetProperties.setOffset(5))
                #expect(abs(oc.offsetProperties.offset - 5) < 1e-6)
            }
        }
    }

    @Test func offset2DBasisCurve() {
        if let base = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) {
            if let oc = base.offset(by: 3) {
                if let basis = oc.offsetProperties.basisCurve {
                    let _ = basis.domain
                }
            }
        }
    }
}
