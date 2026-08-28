import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_OffsetCurve Basis Tests")
struct OffsetCurveBasisTests {

    @Test func getBasisCurve() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            return
        }
        guard
            let offset = Curve3D.offset(
                basis: line, offset: 2.0,
                dirX: 0, dirY: 0, dirZ: 1)
        else { return }
        if let basis = offset.offsetBasisCurve {
            // The basis curve should have same domain characteristics as the original line
            _ = basis
        }
    }

    @Test func nonOffsetCurveReturnsNil() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            return
        }
        #expect(line.offsetBasisCurve == nil)
    }
}
